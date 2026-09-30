import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execFile, execFileSync } from 'node:child_process';
import { paths, ensureDir } from './paths';
import { logger } from './logger';

export interface JavaInfo {
  path: string;
  version: string;
  major: number;
  vendor: string;
}

function parseJavaVersion(output: string): { version: string; major: number } {
  const m = output.match(/version "([^"]+)"/) ?? output.match(/openjdk (\S+)/);
  const raw = m?.[1] ?? '0';
  let major = 0;
  if (raw.startsWith('1.')) major = parseInt(raw.split('.')[1], 10);
  else if (/^\d+/.test(raw)) major = parseInt(raw.split(/[.\-+]/)[0], 10);
  return { version: raw, major };
}

export function probeJava(binPath: string): JavaInfo | null {
  try {
    const out = execFileSync(binPath, ['-version'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 10000 });
    const { version, major } = parseJavaVersion(out);
    return { path: binPath, version, major, vendor: /temurin|adoptium/i.test(out) ? 'Temurin' : /oracle/i.test(out) ? 'Oracle' : /zulu/i.test(out) ? 'Zulu' : /graal/i.test(out) ? 'GraalVM' : 'OpenJDK' };
  } catch (e) {
    const err = e as { stderr?: string; stdout?: string };
    const text = `${err.stdout ?? ''}${err.stderr ?? ''}`;
    if (text) {
      const { version, major } = parseJavaVersion(text);
      if (major) return { path: binPath, version, major, vendor: 'OpenJDK' };
    }
    return null;
  }
}

const JAVA_HOME_CANDIDATES: Record<string, string[]> = {
  linux: [
    '/usr/lib/jvm',
    '/usr/java',
    '/opt/java',
    '/opt/jdk',
    `${os.homedir()}/.sdkman/candidates/java`,
    '/snap/jdk/current',
  ],
  darwin: ['/Library/Java/JavaVirtualMachines', '/System/Library/Java/JavaVirtualMachines', `${os.homedir()}/Library/Java/JavaVirtualMachines`],
  win32: [
    'C:\\Program Files\\Java',
    'C:\\Program Files\\Eclipse Adoptium',
    'C:\\Program Files\\Microsoft\\jdk',
    'C:\\Program Files\\Zulu',
    'C:\\Program Files\\Amazon Corretto',
    'C:\\Program Files (x86)\\Java',
  ],
};

const JAVA_BIN = process.platform === 'win32' ? 'java.exe' : 'java';

/** Разворачиваем возможные вложенные каталоги (например /usr/lib/jvm/java-17-openjdk-amd64/bin/java). */
function expandJavaHome(root: string): string[] {
  const out: string[] = [];
  const push = (dir: string, depth = 0) => {
    const bin = path.join(dir, 'bin', JAVA_BIN);
    if (fs.existsSync(bin)) out.push(bin);
    if (depth > 2) return;
    try {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (!entry.isDirectory() && !entry.isSymbolicLink()) continue;
        if (['bin', 'lib', 'jre', 'legal', 'conf', 'man', 'include'].includes(entry.name)) continue;
        const child = path.join(dir, entry.name);
        if (fs.existsSync(path.join(child, 'bin', JAVA_BIN))) out.push(path.join(child, 'bin', JAVA_BIN));
        else if (depth < 1) push(child, depth + 1);
      }
    } catch {
      /* нет доступа — пропускаем */
    }
  };
  push(root);
  return out;
}

export function detectJava(): JavaInfo[] {
  const found = new Map<string, JavaInfo>();
  const add = (p: string) => {
    if (!p || found.has(p) || !fs.existsSync(p)) return;
    const info = probeJava(p);
    if (info) found.set(p, info);
  };

  // 1. JAVA_HOME
  if (process.env.JAVA_HOME) add(path.join(process.env.JAVA_HOME, 'bin', JAVA_BIN));
  // 2. java из PATH
  try {
    const which = process.platform === 'win32' ? 'where' : 'which';
    const out = execFileSync(which, ['java'], { encoding: 'utf8' }).split(/\r?\n/)[0].trim();
    add(out);
  } catch {
    /* нет java в PATH */
  }
  // 3. Стандартные каталоги JDK
  for (const root of JAVA_HOME_CANDIDATES[process.platform] ?? []) {
    if (!fs.existsSync(root)) continue;
    for (const p of expandJavaHome(root)) add(p);
  }
  // 4. Рантаймы, скачанные самим лаунчером
  try {
    for (const dir of fs.readdirSync(paths.runtime, { withFileTypes: true })) {
      if (!dir.isDirectory()) continue;
      for (const p of expandJavaHome(path.join(paths.runtime, dir.name))) add(p);
    }
  } catch {
    /* runtime пуст */
  }

  const list = [...found.values()].sort((a, b) => b.major - a.major);
  logger.info(`Найдено Java: ${list.map((j) => `${j.major} (${j.vendor})`).join(', ') || 'ничего'}`, 'launcher');
  return list;
}

export function requiredJavaMajor(mcVersion: string, jsonMajor?: number): number {
  if (jsonMajor && jsonMajor > 8) return jsonMajor;
  const [a, b] = mcVersion.replace(/[^\d.]/g, '').split('.').map((n) => parseInt(n, 10) || 0);
  if (mcVersion.includes('1.21') || mcVersion.includes('1.20')) return 21;
  if (a === 1 && b >= 18) return 17;
  if (a === 1 && b === 17) return 16;
  if (a === 1 && b >= 12) return 8;
  return 8;
}

export function findSuitableJava(list: JavaInfo[], major: number): JavaInfo | undefined {
  return list.find((j) => j.major === major) ?? list.find((j) => j.major > major && j.major <= major + 8) ?? list[0];
}

/** Скачивание Eclipse Temurin JDK, если подходящей Java в системе нет. */
export async function downloadRuntime(major: number, onProgress?: (done: number, total: number) => void): Promise<JavaInfo> {
  const archMap: Record<string, string> = { x64: 'x64', arm64: 'aarch64', ia32: 'x32' };
  const arch = archMap[process.arch] ?? 'x64';
  const osName = process.platform === 'win32' ? 'windows' : process.platform === 'darwin' ? 'mac' : 'linux';
  const ext = osName === 'windows' ? 'zip' : 'tar.gz';
  const url = `https://api.adoptium.net/v3/binary/latest/${major}/ga/${osName}/${arch}/jdk/hotspot/normal/eclipse?project=jdk`;
  const targetDir = path.join(paths.runtime, `temurin-${major}`);
  if (fs.existsSync(targetDir)) {
    const existing = detectJava().find((j) => j.path.startsWith(targetDir));
    if (existing) return existing;
  }
  ensureDir(paths.runtime);
  const archive = path.join(paths.runtime, `temurin-${major}.${ext}`);
  logger.info(`Скачиваю Eclipse Temurin ${major} (${osName}/${arch})…`, 'installer');
  const res = await fetch(url, { headers: { 'User-Agent': 'AXIOM-Launcher/1.0' } });
  if (!res.ok) throw new Error(`Не удалось скачать JDK ${major}: HTTP ${res.status}`);
  const total = Number(res.headers.get('content-length') ?? 0);
  const fileStream = fs.createWriteStream(archive);
  let done = 0;
  // @ts-expect-error web stream → node
  for await (const chunk of res.body) {
    fileStream.write(chunk);
    done += chunk.length;
    onProgress?.(done, total);
  }
  await new Promise<void>((r) => fileStream.end(r));

  fs.rmSync(targetDir, { recursive: true, force: true });
  ensureDir(targetDir);
  if (ext === 'zip') {
    const AdmZip = (await import('adm-zip')).default;
    new AdmZip(archive).extractAllTo(targetDir, true);
  } else {
    execFileSync('tar', ['-xzf', archive, '-C', targetDir], { stdio: 'ignore' });
  }
  fs.rmSync(archive, { force: true });
  const list = expandJavaHome(targetDir);
  if (!list.length) throw new Error('Не удалось распаковать JDK');
  const info = probeJava(list[0]);
  if (!info) throw new Error('Скачанный JDK не запускается');
  logger.success(`JDK ${info.major} (${info.vendor}) установлен в ${targetDir}`, 'installer');
  return info;
}

export function runJava(javaBin: string, args: string[], cwd: string) {
  return new Promise<{ code: number; stdout: string; stderr: string }>((resolve) => {
    execFile(javaBin, args, { cwd, maxBuffer: 1024 * 1024 * 32 }, (err, stdout, stderr) => {
      resolve({ code: err ? ((err as { code?: number }).code ?? 1) : 0, stdout, stderr });
    });
  });
}
