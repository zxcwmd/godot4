import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import AdmZip from 'adm-zip';
import { paths, ensureDir } from './paths';
import { logger } from './logger';
import { fetchJson, resolveVersion, type RawLibrary, type Rule, type VersionJson } from './mojang';
import type { DownloadProgress } from '../../shared/types';

const UA = 'AXIOM-Launcher/1.0';
const RESOURCES = 'https://resources.download.minecraft.net';

export type EmitFn = (p: Partial<DownloadProgress> & { taskId: string }) => void;

export interface InstallCtx {
  taskId: string;
  emit: EmitFn;
  concurrency?: number;
}

/* ─────────────────────────── Правила совместимости ─────────────────────────── */

export const OS_NAME = process.platform === 'win32' ? 'windows' : process.platform === 'darwin' ? 'osx' : 'linux';

export function ruleAllows(rules: Rule[] | undefined, features: Record<string, boolean> = {}): boolean {
  if (!rules?.length) return true;
  let allowed = false;
  for (const rule of rules) {
    let matches = true;
    if (rule.os?.name && rule.os.name !== OS_NAME) matches = false;
    if (rule.os?.arch && rule.os.arch !== (process.arch === 'x64' ? 'x86_64' : process.arch)) matches = false;
    if (rule.features) {
      for (const [key, val] of Object.entries(rule.features)) {
        if (!!features[key] !== !!val) matches = false;
      }
    }
    if (matches) allowed = rule.action === 'allow';
  }
  return allowed;
}

/* ─────────────────────────── Скачивание ─────────────────────────── */

interface QueueItem {
  url: string;
  dest: string;
  size?: number;
  sha1?: string;
  skipIfExists?: boolean;
}

async function downloadOne(item: QueueItem): Promise<number> {
  if (item.skipIfExists !== false && fs.existsSync(item.dest)) {
    const st = fs.statSync(item.dest);
    if (!item.size || st.size === item.size) return 0;
  }
  ensureDir(path.dirname(item.dest));
  let lastError: Error | null = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await fetch(item.url, { headers: { 'User-Agent': UA } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const buf = Buffer.from(await res.arrayBuffer());
      const tmp = `${item.dest}.part`;
      fs.writeFileSync(tmp, buf);
      fs.renameSync(tmp, item.dest);
      return buf.length;
    } catch (e) {
      lastError = e as Error;
      await new Promise((r) => setTimeout(r, 350 * (attempt + 1)));
    }
  }
  throw new Error(`${lastError?.message} — ${item.url}`);
}

/** Пул загрузок с прогрессом, поддержкой докачки-пропуска существующих файлов. */
export async function downloadQueue(
  items: QueueItem[],
  ctx: InstallCtx,
  stage: DownloadProgress['stage'],
  label: string,
) {
  const concurrency = Math.max(2, Math.min(32, ctx.concurrency ?? 12));
  const totalBytes = items.reduce((s, i) => s + (i.size ?? 0), 0) || 1;
  let done = 0;
  let bytes = 0;
  let idx = 0;
  const startedAt = Date.now();
  let speed = 0;

  const tick = () => {
    const elapsed = Math.max(0.25, (Date.now() - startedAt) / 1000);
    speed = bytes / elapsed;
    ctx.emit({
      taskId: ctx.taskId,
      label,
      stage,
      current: done,
      total: items.length,
      bytesDone: bytes,
      bytesTotal: totalBytes,
      speed,
    });
  };

  tick();
  const worker = async () => {
    while (idx < items.length) {
      const item = items[idx++];
      try {
        const n = await downloadOne(item);
        bytes += n || item.size || 0;
      } catch (e) {
        logger.warn(`Файл пропущен: ${(e as Error).message}`, 'installer');
      }
      done++;
      if (done % 5 === 0 || done === items.length) tick();
    }
  };
  await Promise.all(Array.from({ length: Math.min(concurrency, items.length || 1) }, worker));
  tick();
}

/* ─────────────────────────── Библиотеки и нативы ─────────────────────────── */

export function nativeClassifierFor(lib: RawLibrary): string | undefined {
  if (!lib.natives) return undefined;
  const key = lib.natives[OS_NAME] ?? (OS_NAME === 'osx' ? lib.natives['osx'] : undefined);
  return key?.replace('${arch}', process.arch === 'ia32' ? '32' : '64');
}

export function nativesDirFor(versionId: string) {
  return path.join(paths.versions, versionId, 'natives');
}

export function extractNatives(zipPath: string, destDir: string, exclude: string[] = ['META-INF/']) {
  ensureDir(destDir);
  const zip = new AdmZip(zipPath);
  for (const entry of zip.getEntries()) {
    if (entry.isDirectory) continue;
    if (exclude.some((ex) => entry.entryName.startsWith(ex))) continue;
    const out = path.join(destDir, path.basename(entry.entryName));
    if (fs.existsSync(out)) continue;
    fs.writeFileSync(out, entry.getData());
  }
}

/* ─────────────────────────── Установка версии ─────────────────────────── */

export interface InstallResult {
  versionId: string;
  json: VersionJson;
  classpath: string[];
  nativesDir: string;
}

export async function installVersion(versionId: string, ctx: InstallCtx): Promise<InstallResult> {
  const emit = ctx.emit;
  emit({ taskId: ctx.taskId, stage: 'prepare', label: `Подготовка ${versionId}`, current: 0, total: 1 });
  const json = await resolveVersion(versionId);
  logger.info(`Установка версии ${versionId} (${json.libraries.length} библиотек)`, 'installer');

  /* 1. Клиент */
  const client = json.downloads?.client;
  if (client?.url) {
    await downloadQueue(
      [{ url: client.url, dest: path.join(paths.versions, versionId, `${versionId}.jar`), size: client.size, sha1: client.sha1 }],
      ctx,
      'client',
      `Клиент ${versionId}`,
    );
  }

  /* 2. Библиотеки + нативы */
  const libItems: QueueItem[] = [];
  const nativeZips: { lib: RawLibrary; file: string }[] = [];
  for (const lib of json.libraries) {
    if (!ruleAllows(lib.rules)) continue;
    const artifact = lib.downloads?.artifact;
    if (artifact?.url && artifact.path) {
      libItems.push({
        url: artifact.url,
        dest: path.join(paths.libraries, artifact.path),
        size: artifact.size,
        sha1: artifact.sha1,
      });
    } else if (!lib.downloads && lib.url) {
      // старые версии: maven-координаты вручную
      const [group, artifactName, version] = lib.name.split(':');
      const p = `${group.replace(/\./g, '/')}/${artifactName}/${version}/${artifactName}-${version}.jar`;
      libItems.push({ url: `${lib.url}${p}`, dest: path.join(paths.libraries, p) });
    }
    const classifier = nativeClassifierFor(lib);
    const cls = classifier ? lib.downloads?.classifiers?.[classifier] : undefined;
    if (cls?.url && cls.path) {
      const dest = path.join(paths.libraries, cls.path);
      libItems.push({ url: cls.url, dest, size: cls.size, sha1: cls.sha1 });
      nativeZips.push({ lib, file: dest });
    }
  }
  const concurrency = Math.max(2, Math.min(32, ctx.concurrency ?? 12));
  await downloadQueue(libItems, { ...ctx, concurrency }, 'libraries', `Библиотеки (${libItems.length})`);

  const nativesDir = nativesDirFor(versionId);
  fs.rmSync(nativesDir, { recursive: true, force: true });
  for (const nz of nativeZips) {
    try {
      extractNatives(nz.file, nativesDir, nz.lib.extract?.exclude);
    } catch (e) {
      logger.warn(`Не удалось распаковать нативы ${nz.lib.name}: ${(e as Error).message}`, 'installer');
    }
  }
  emit({ taskId: ctx.taskId, stage: 'natives', label: 'Нативные библиотеки', current: 1, total: 1 });

  /* 3. Ассеты */
  const assetIndex = json.assetIndex ?? (json.assets ? { id: json.assets, url: legacyAssetUrl(json.assets) } : undefined);
  if (assetIndex?.url) {
    const indexPath = path.join(paths.assets, 'indexes', `${assetIndex.id}.json`);
    if (!fs.existsSync(indexPath)) {
      ensureDir(path.dirname(indexPath));
      const data = await fetchJson<any>(assetIndex.url);
      fs.writeFileSync(indexPath, JSON.stringify(data));
    }
    const index = JSON.parse(fs.readFileSync(indexPath, 'utf8')) as { objects: Record<string, { hash: string; size: number }> };
    const objects = Object.values(index.objects ?? {});
    const assetItems: QueueItem[] = objects.map((o) => {
      const sub = o.hash.slice(0, 2);
      return { url: `${RESOURCES}/${sub}/${o.hash}`, dest: path.join(paths.assets, 'objects', sub, o.hash), size: o.size, sha1: o.hash };
    });
    logger.info(`Ассеты: ${assetItems.length} объектов (${(assetIndex.totalSize ?? assetIndex.size ?? 0 / 1) } )`, 'installer');
    const missing = assetItems.filter((a) => !fs.existsSync(a.dest));
    emit({
      taskId: ctx.taskId,
      stage: 'assets',
      label: `Ресурсы игры (${missing.length} из ${assetItems.length} новых)`,
      current: assetItems.length - missing.length,
      total: assetItems.length,
      bytesDone: 0,
      bytesTotal: missing.reduce((s, m) => s + (m.size ?? 0), 0) || 1,
    });
    await downloadQueue(missing, ctx, 'assets', `Ресурсы (${missing.length})`);
  }

  /* 4. Финализация — сохраняем развёрнутый json профиля */
  const finalJsonPath = path.join(paths.versions, versionId, `${versionId}.json`);
  ensureDir(path.dirname(finalJsonPath));
  fs.writeFileSync(finalJsonPath, JSON.stringify({ ...json, resolvedAt: Date.now() }, null, 2));

  emit({
    taskId: ctx.taskId,
    stage: 'done',
    label: `${versionId} готова к запуску`,
    current: 1,
    total: 1,
    bytesDone: 1,
    bytesTotal: 1,
  });
  logger.success(`Версия ${versionId} установлена`, 'installer');

  return { versionId, json, classpath: [], nativesDir };
}

function legacyAssetUrl(assets: string) {
  return `https://piston-meta.mojang.com/v1/packages/${assets}/${assets}.json`;
}

/** Путь к jar-файлу библиотеки по maven-координатам. */
export function libraryPathFromName(name: string): string | null {
  const parts = name.split(':');
  if (parts.length < 3) return null;
  const [group, artifact, version] = parts;
  const classifier = parts[3];
  const file = classifier ? `${artifact}-${version}-${classifier}.jar` : `${artifact}-${version}.jar`;
  return path.join(paths.libraries, group.replace(/\./g, '/'), artifact, version, file);
}

export function buildClasspath(json: VersionJson, versionId: string): string[] {
  const cp: string[] = [];
  for (const lib of json.libraries) {
    if (!ruleAllows(lib.rules)) continue;
    const artifact = lib.downloads?.artifact;
    const p = artifact?.path ? path.join(paths.libraries, artifact.path) : libraryPathFromName(lib.name);
    if (p && fs.existsSync(p)) cp.push(p);
  }
  const clientJar = path.join(paths.versions, versionId, `${versionId}.jar`);
  if (fs.existsSync(clientJar)) cp.push(clientJar);
  return cp;
}

export function freeMemoryMb() {
  return Math.round(os.freemem() / 1024 / 1024);
}

export function totalMemoryMb() {
  return Math.round(os.totalmem() / 1024 / 1024);
}
