import fs from 'node:fs';
import path from 'node:path';
import { paths, ensureDir } from './paths';
import { logger } from './logger';
import { detectJava, downloadRuntime, findSuitableJava, requiredJavaMajor, runJava } from './java';
import type { Loader } from '../../shared/types';
import type { VersionJson } from './mojang';

/** Скачивание и запуск официального инсталлятора Forge/NeoForge в общую папку лаунчера. */
export async function installForge(mcVersion: string, loader: Loader, loaderVersion: string): Promise<VersionJson | null> {
  const isNeo = loader === 'neoforge';
  const fullVersion = isNeo ? loaderVersion : `${mcVersion}-${loaderVersion}`;
  const fileName = isNeo ? `neoforge-${loaderVersion}-installer.jar` : `forge-${fullVersion}-installer.jar`;
  const url = isNeo
    ? `https://maven.neoforged.net/releases/net/neoforged/neoforge/${loaderVersion}/${fileName}`
    : `https://maven.minecraftforge.net/net/minecraftforge/forge/${fullVersion}/${fileName}`;

  const installerDir = path.join(paths.modloaders, 'installers');
  ensureDir(installerDir);
  const installerPath = path.join(installerDir, fileName);

  if (!fs.existsSync(installerPath)) {
    logger.info(`Скачиваю инсталлятор ${loader} ${fullVersion}…`, 'installer');
    const res = await fetch(url, { headers: { 'User-Agent': 'AXIOM-Launcher/1.0' } });
    if (!res.ok) {
      logger.error(`Инсталлятор ${loader} ${fullVersion} недоступен (HTTP ${res.status})`, 'installer');
      return null;
    }
    fs.writeFileSync(installerPath, Buffer.from(await res.arrayBuffer()));
  }

  // Forge-инсталлятору нужна совместимая Java (<=1.16 — восьмёрка, дальше — свежее)
  const needMajor = requiredJavaMajor(mcVersion);
  const detected = detectJava();
  let java = findSuitableJava(detected, needMajor);
  if (!java || java.major < needMajor) java = await downloadRuntime(Math.max(needMajor, 8));

  const target = paths.shared; // --installClient <dir>: <dir>/versions, <dir>/libraries
  logger.info(`Запускаю инсталлятор ${loader}: ${path.basename(installerPath)} → ${target}`, 'installer');
  const res = await runJava(java.path, ['-jar', installerPath, '--installClient', target], paths.shared);
  const combined = `${res.stdout}\n${res.stderr}`;
  if (res.code !== 0) {
    logger.error(`Инсталлятор ${loader} завершился с кодом ${res.code}`, 'installer');
    logger.debug(combined.slice(-2000), 'installer');
    return null;
  }

  // Ищем созданный профиль версии
  const expectedIds = isNeo
    ? [loaderVersion, `neoforge-${loaderVersion}`]
    : [`${mcVersion}-forge-${loaderVersion}`, `${mcVersion}-forge${loaderVersion}`, fullVersion];
  for (const id of expectedIds) {
    const file = path.join(paths.versions, id, `${id}.json`);
    if (fs.existsSync(file)) {
      logger.success(`${loader} ${loaderVersion} установлен (профиль ${id})`, 'installer');
      const json = JSON.parse(fs.readFileSync(file, 'utf8')) as VersionJson;
      json.inheritsFrom = json.inheritsFrom ?? mcVersion;
      return json;
    }
  }
  // Fallback: последняя изменённая версия с forge в названии
  try {
    const dirs = fs
      .readdirSync(paths.versions, { withFileTypes: true })
      .filter((d) => d.isDirectory() && d.name.toLowerCase().includes(isNeo ? 'neoforge' : 'forge'))
      .map((d) => ({ name: d.name, mtime: fs.statSync(path.join(paths.versions, d.name)).mtimeMs }))
      .sort((a, b) => b.mtime - a.mtime);
    for (const d of dirs) {
      const file = path.join(paths.versions, d.name, `${d.name}.json`);
      if (fs.existsSync(file)) {
        const json = JSON.parse(fs.readFileSync(file, 'utf8')) as VersionJson;
        json.inheritsFrom = json.inheritsFrom ?? mcVersion;
        return json;
      }
    }
  } catch {
    /* ignore */
  }
  logger.error(`Профиль ${loader} не найден после установки`, 'installer');
  return null;
}
