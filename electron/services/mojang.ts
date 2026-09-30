import fs from 'node:fs';
import path from 'node:path';
import { paths, ensureDir } from './paths';
import { logger } from './logger';
import type { Loader, VersionSummary } from '../../shared/types';

const UA = 'AXIOM-Launcher/1.0 (+https://github.com/axiom-launcher)';

export async function fetchJson<T = any>(url: string, init?: RequestInit & { timeoutMs?: number }): Promise<T> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), init?.timeoutMs ?? 20000);
  try {
    const res = await fetch(url, {
      ...init,
      signal: ctrl.signal,
      headers: { 'User-Agent': UA, 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText} — ${url}`);
    return (await res.json()) as T;
  } finally {
    clearTimeout(timer);
  }
}

/* ─────────────────────────── Манифест версий Mojang ─────────────────────────── */

export interface RawVersionManifest {
  latest: { release: string; snapshot: string };
  versions: { id: string; type: VersionSummary['type']; url: string; releaseTime: string; sha1: string }[];
}

const MANIFEST_URL = 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json';
const META_TTL = 1000 * 60 * 30; // 30 минут

export async function getVersionManifest(force = false): Promise<RawVersionManifest> {
  const cacheFile = path.join(paths.meta, 'version_manifest_v2.json');
  if (!force && fs.existsSync(cacheFile)) {
    const age = Date.now() - fs.statSync(cacheFile).mtimeMs;
    if (age < META_TTL) {
      try {
        return JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
      } catch {
        /* перекачаем */
      }
    }
  }
  try {
    const data = await fetchJson<RawVersionManifest>(MANIFEST_URL);
    ensureDir(paths.meta);
    fs.writeFileSync(cacheFile, JSON.stringify(data));
    logger.info(`Манифест версий обновлён: ${data.versions.length} версий, latest=${data.latest.release}`, 'network');
    return data;
  } catch (e) {
    if (fs.existsSync(cacheFile)) {
      logger.warn(`Не удалось обновить манифест (${(e as Error).message}), использую кэш`, 'network');
      return JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
    }
    throw e;
  }
}

export function localVersions(): string[] {
  try {
    return fs
      .readdirSync(paths.versions, { withFileTypes: true })
      .filter((d) => d.isDirectory() && fs.existsSync(path.join(paths.versions, d.name, `${d.name}.json`)))
      .map((d) => d.name);
  } catch {
    return [];
  }
}

export function isInstalled(versionId: string) {
  return localVersions().includes(versionId);
}

/* ─────────────────────────── Version JSON ─────────────────────────── */

export interface LibraryDownload {
  path?: string;
  url?: string;
  sha1?: string;
  size?: number;
}
export interface RawLibrary {
  name: string;
  downloads?: {
    artifact?: LibraryDownload;
    classifiers?: Record<string, LibraryDownload>;
  };
  natives?: Record<string, string>;
  rules?: Rule[];
  extract?: { exclude?: string[] };
  url?: string;
  checksums?: string[];
  clientreq?: boolean;
  serverreq?: boolean;
}
export interface Rule {
  action: 'allow' | 'disallow';
  os?: { name?: string; version?: string; arch?: string };
  features?: Record<string, boolean>;
}
export interface VersionJson {
  id: string;
  type?: string;
  inheritsFrom?: string;
  mainClass: string;
  assets?: string;
  assetIndex?: { id: string; url: string; sha1?: string; size?: number; totalSize?: number };
  downloads?: { client?: LibraryDownload; server?: LibraryDownload };
  libraries: RawLibrary[];
  javaVersion?: { component: string; majorVersion: number };
  arguments?: { game: (string | { rules?: Rule[]; value: string | string[] })[]; jvm: (string | { rules?: Rule[]; value: string | string[] })[] };
  minecraftArguments?: string;
  releaseTime?: string;
  time?: string;
  complianceLevel?: number;
  logging?: unknown;
}

export async function getVersionJson(versionId: string, url?: string): Promise<VersionJson> {
  const localDir = path.join(paths.versions, versionId);
  const localFile = path.join(localDir, `${versionId}.json`);
  if (fs.existsSync(localFile)) {
    try {
      return JSON.parse(fs.readFileSync(localFile, 'utf8'));
    } catch {
      /* битый json — перекачаем */
    }
  }
  const manifest = await getVersionManifest();
  const entry = manifest.versions.find((v) => v.id === versionId);
  const target = url ?? entry?.url;
  if (!target) throw new Error(`Версия ${versionId} не найдена в манифесте Mojang`);
  const json = await fetchJson<VersionJson>(target);
  ensureDir(localDir);
  fs.writeFileSync(localFile, JSON.stringify(json, null, 2));
  return json;
}

/** Разворачивает цепочку inheritsFrom: родительские библиотеки и аргументы первыми. */
export async function resolveVersion(versionId: string): Promise<VersionJson> {
  const chain: VersionJson[] = [];
  let current = await getVersionJson(versionId);
  let guard = 0;
  chain.unshift(current);
  while (current.inheritsFrom && guard++ < 8) {
    current = await getVersionJson(current.inheritsFrom);
    chain.unshift(current);
  }
  const base = chain[0];
  const merged: VersionJson = {
    ...base,
    id: versionId,
    libraries: chain.flatMap((c) => c.libraries ?? []),
    mainClass: chain[chain.length - 1].mainClass ?? base.mainClass,
    arguments: chain.reduce<VersionJson['arguments']>(
      (acc, c) => {
        if (!c.arguments) return acc;
        return {
          game: [...(acc?.game ?? []), ...(c.arguments.game ?? [])],
          jvm: [...(acc?.jvm ?? []), ...(c.arguments.jvm ?? [])],
        };
      },
      { game: [], jvm: [] },
    ),
  };
  // Дедупликация библиотек по координатам (младшие перекрывают старших)
  const seen = new Map<string, RawLibrary>();
  for (const lib of merged.libraries) seen.set(lib.name, lib);
  merged.libraries = [...seen.values()];
  if (chain.length > 1 && !merged.arguments?.game?.length) {
    merged.minecraftArguments = chain[chain.length - 1].minecraftArguments ?? base.minecraftArguments;
    merged.assets = chain[chain.length - 1].assets ?? base.assets;
  }
  return merged;
}

/* ─────────────────────────── Загрузчики ─────────────────────────── */

export interface LoaderVersionOption {
  version: string;
  stable: boolean;
}

export async function getLoaderOptions(mcVersion: string, loader: Loader): Promise<LoaderVersionOption[]> {
  try {
    if (loader === 'fabric') {
      const list = await fetchJson<any[]>(`https://meta.fabricmc.net/v2/versions/loader/${mcVersion}`);
      return list.map((l) => ({ version: l.loader.version, stable: !!l.loader.stable }));
    }
    if (loader === 'quilt') {
      const list = await fetchJson<any[]>(`https://meta.quiltmc.org/v3/versions/loader/${mcVersion}`);
      return list.slice(0, 40).map((l) => ({ version: l.loader.version, stable: !!l.loader.stable }));
    }
    if (loader === 'forge' || loader === 'neoforge') {
      const url =
        loader === 'forge'
          ? 'https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json'
          : 'https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge';
      const data = await fetchJson<any>(url);
      if (loader === 'forge') {
        const promos: Record<string, string> = data.promos ?? {};
        const versions: LoaderVersionOption[] = [];
        for (const [key, ver] of Object.entries(promos)) {
          if (!key.startsWith(`${mcVersion}-`)) continue;
          versions.push({ version: String(ver), stable: key.endsWith('-recommended') });
        }
        return versions;
      }
      const all: string[] = data.versions ?? [];
      const prefix = mcVersion.startsWith('1.') ? mcVersion.split('.').slice(1).join('.') : mcVersion;
      return all
        .filter((v) => v.startsWith(`${prefix}.`) || v.startsWith(`${prefix}-`))
        .reverse()
        .slice(0, 40)
        .map((v) => ({ version: v, stable: !v.includes('beta') }));
    }
  } catch (e) {
    logger.warn(`Не удалось получить список версий ${loader}: ${(e as Error).message}`, 'network');
  }
  return [];
}

/** Профиль загрузчика (JSON версии), который умеет запускать vanilla-клиент поверх базы. */
export async function getLoaderProfile(mcVersion: string, loader: Loader, loaderVersion: string): Promise<VersionJson> {
  const profileId = `${loader}-${loaderVersion}-${mcVersion}`;
  const cacheFile = path.join(paths.modloaders, `${profileId}.json`);
  if (fs.existsSync(cacheFile)) {
    try {
      return JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
    } catch {
      /* ignore */
    }
  }
  let json: VersionJson | null = null;
  if (loader === 'fabric') {
    json = await fetchJson<VersionJson>(
      `https://meta.fabricmc.net/v2/versions/loader/${mcVersion}/${loaderVersion}/profile/json`,
    );
  } else if (loader === 'quilt') {
    json = await fetchJson<VersionJson>(
      `https://meta.quiltmc.org/v3/versions/loader/${mcVersion}/${loaderVersion}/profile/json`,
    );
  } else {
    // Forge/NeoForge: официальный инсталлятор создаёт версию локально — запускаем его.
    const { installForge } = await import('./forge');
    json = await installForge(mcVersion, loader, loaderVersion);
  }
  if (!json) throw new Error(`Загрузчик ${loader} ${loaderVersion} для ${mcVersion} недоступен`);
  ensureDir(paths.modloaders);
  fs.writeFileSync(cacheFile, JSON.stringify(json));
  ensureDir(path.join(paths.versions, json.id ?? profileId));
  fs.writeFileSync(path.join(paths.versions, json.id ?? profileId, `${json.id ?? profileId}.json`), JSON.stringify(json, null, 2));
  return json;
}
