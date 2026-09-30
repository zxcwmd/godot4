import fs from 'node:fs';
import path from 'node:path';
import { paths, ensureDir } from './paths';
import { logger } from './logger';
import { fetchJson } from './mojang';
import type { InstalledMod, ModProjectType, ModSearchResult } from '../../shared/types';

const API = 'https://api.modrinth.com/v2';
const UA = 'AXIOM-Launcher/1.0 (minecraft-launcher)';

export interface SearchParams {
  query: string;
  projectType?: ModProjectType | 'all';
  loader?: string;
  gameVersion?: string;
  sort?: 'relevance' | 'downloads' | 'follows' | 'newest' | 'updated';
  limit?: number;
  offset?: number;
}

const FALLBACK: ModSearchResult[] = [
  {
    id: 'sodium',
    slug: 'sodium',
    title: 'Sodium',
    description: 'Современный рендер-движок: кратный рост FPS и плавности без потери картинки.',
    author: 'CaffeineMC',
    downloads: 42_000_000,
    follows: 21000,
    categories: ['optimization'],
    loaders: ['fabric', 'quilt'],
    gameVersions: ['1.20.1', '1.20.4', '1.21'],
    projectType: 'mod',
    updated: new Date().toISOString(),
  },
  {
    id: 'iris',
    slug: 'iris',
    title: 'Iris Shaders',
    description: 'Полная поддержка шейдеров OptiFine-формата поверх Sodium.',
    author: 'IrisShaders',
    downloads: 18_500_000,
    follows: 12000,
    categories: ['shaders'],
    loaders: ['fabric', 'quilt'],
    gameVersions: ['1.20.1', '1.21'],
    projectType: 'mod',
    updated: new Date().toISOString(),
  },
  {
    id: 'lithium',
    slug: 'lithium',
    title: 'Lithium',
    description: 'Оптимизация игровой логики: тики, ИИ мобов, физика — без изменения геймплея.',
    author: 'CaffeineMC',
    downloads: 26_300_000,
    follows: 15000,
    categories: ['optimization'],
    loaders: ['fabric', 'quilt', 'neoforge'],
    gameVersions: ['1.20.1', '1.21'],
    projectType: 'mod',
    updated: new Date().toISOString(),
  },
  {
    id: 'jei',
    slug: 'jei',
    title: 'Just Enough Items',
    description: 'Просмотр рецептов и предметов — маст-хэв для автоматизации крафта.',
    author: 'mezz',
    downloads: 120_000_000,
    follows: 40000,
    categories: ['utility'],
    loaders: ['fabric', 'forge', 'neoforge'],
    gameVersions: ['1.20.1', '1.21'],
    projectType: 'mod',
    updated: new Date().toISOString(),
  },
  {
    id: 'complementary',
    slug: 'complementary-reimagined',
    title: 'Complementary Reimagined',
    description: 'Кинематографичные шейдеры: мягкий свет, объёмный туман, вода с преломлением.',
    author: 'Complementary',
    downloads: 31_000_000,
    follows: 33000,
    categories: ['shaders'],
    loaders: ['irisshaders', 'optifine'],
    gameVersions: ['1.20.1', '1.21'],
    projectType: 'shader',
    updated: new Date().toISOString(),
  },
];

export async function searchProjects(p: SearchParams): Promise<ModSearchResult[]> {
  const facets: string[][] = [];
  const type = !p.projectType || p.projectType === 'all' ? undefined : p.projectType;
  facets.push([`project_type:${type ?? 'mod'}`]);
  if (p.loader && p.loader !== 'any') facets.push([`categories:${p.loader}`]);
  if (p.gameVersion && p.gameVersion !== 'any') facets.push([`versions:${p.gameVersion}`]);

  const url = `${API}/search?query=${encodeURIComponent(p.query)}&limit=${p.limit ?? 24}&offset=${p.offset ?? 0}&index=${p.sort ?? 'relevance'}&facets=${encodeURIComponent(JSON.stringify(facets))}`;
  try {
    const data = await fetchJson<{ hits: any[] }>(url, { headers: { 'User-Agent': UA } });
    return (data.hits ?? []).map(mapHit);
  } catch (e) {
    logger.warn(`Modrinth недоступен (${(e as Error).message}) — показываю демо-каталог`, 'network');
    if (!p.query) return FALLBACK;
    const q = p.query.toLowerCase();
    return FALLBACK.filter((f) => `${f.title} ${f.description} ${f.author}`.toLowerCase().includes(q));
  }
}

function mapHit(h: any): ModSearchResult {
  return {
    id: h.project_id ?? h.id,
    slug: h.slug,
    title: h.title,
    description: h.description,
    author: h.author,
    downloads: h.downloads ?? 0,
    follows: h.follows ?? 0,
    iconUrl: h.icon_url ?? undefined,
    categories: h.categories ?? [],
    loaders: h.loaders ?? [],
    gameVersions: h.versions ?? [],
    versions: h.versions ?? [],
    projectType: (h.project_type as ModProjectType) ?? 'mod',
    updated: h.date_modified ?? new Date().toISOString(),
  };
}

export async function projectVersions(projectId: string, loader?: string, gameVersion?: string) {
  const params = new URLSearchParams();
  if (loader && loader !== 'any') params.set('loaders', JSON.stringify([loader]));
  if (gameVersion && gameVersion !== 'any') params.set('game_versions', JSON.stringify([gameVersion]));
  const url = `${API}/project/${projectId}/version?${params.toString()}`;
  const list = await fetchJson<any[]>(url, { headers: { 'User-Agent': UA } });
  return list.map((v) => ({
    id: v.id as string,
    name: v.name as string,
    versionNumber: v.version_number as string,
    gameVersions: v.game_versions as string[],
    loaders: v.loaders as string[],
    datePublished: v.date_published as string,
    downloads: v.downloads as number,
    files: (v.files ?? []).map((f: any) => ({
      url: f.url as string,
      filename: f.filename as string,
      size: f.size as number,
      primary: !!f.primary,
    })),
  }));
}

function instanceModsDir(instanceId: string, type: ModProjectType) {
  const base = paths.instance(instanceId);
  if (type === 'shader') return path.join(base, 'shaderpacks');
  if (type === 'resourcepack') return path.join(base, 'resourcepacks');
  if (type === 'datapack') return path.join(base, 'datapacks');
  return path.join(base, 'mods');
}

export async function installProject(
  instanceId: string,
  project: { id: string; slug: string; title: string; iconUrl?: string; projectType: ModProjectType },
  loader: string | undefined,
  gameVersion: string | undefined,
): Promise<InstalledMod> {
  const versions = await projectVersions(project.id, project.projectType === 'mod' ? loader : undefined, gameVersion);
  const target = versions[0];
  if (!target) throw new Error('Нет подходящей версии для этой сборки');
  const file = target.files.find((f: { primary: boolean }) => f.primary) ?? target.files[0];
  if (!file) throw new Error('У версии нет файлов');

  const dir = instanceModsDir(instanceId, project.projectType);
  ensureDir(dir);
  const dest = path.join(dir, file.filename);
  const res = await fetch(file.url, { headers: { 'User-Agent': UA } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  fs.writeFileSync(dest, Buffer.from(await res.arrayBuffer()));

  const meta: InstalledMod = {
    fileName: file.filename,
    title: project.title,
    projectId: project.id,
    iconUrl: project.iconUrl,
    version: target.versionNumber,
    sizeBytes: file.size,
    installedAt: Date.now(),
    type: project.projectType,
    enabled: true,
  };
  saveModMeta(instanceId, meta);
  logger.success(`Установлен «${project.title}» ${target.versionNumber} → ${path.basename(dir)}`, 'installer');
  return meta;
}

function metaFile(instanceId: string) {
  return path.join(paths.instance(instanceId), 'axiom-mods.json');
}

export function loadModMeta(instanceId: string): Record<string, InstalledMod> {
  try {
    return JSON.parse(fs.readFileSync(metaFile(instanceId), 'utf8'));
  } catch {
    return {};
  }
}

export function saveModMeta(instanceId: string, mod: InstalledMod) {
  const meta = loadModMeta(instanceId);
  meta[mod.fileName] = mod;
  ensureDir(paths.instance(instanceId));
  fs.writeFileSync(metaFile(instanceId), JSON.stringify(meta, null, 2));
}

export function listInstalled(instanceId: string): InstalledMod[] {
  const meta = loadModMeta(instanceId);
  const dirs: { dir: string; type: InstalledMod['type'] }[] = [
    { dir: path.join(paths.instance(instanceId), 'mods'), type: 'mod' },
    { dir: path.join(paths.instance(instanceId), 'shaderpacks'), type: 'shader' },
    { dir: path.join(paths.instance(instanceId), 'resourcepacks'), type: 'resourcepack' },
    { dir: path.join(paths.instance(instanceId), 'datapacks'), type: 'datapack' },
  ];
  const out: InstalledMod[] = [];
  for (const { dir, type } of dirs) {
    if (!fs.existsSync(dir)) continue;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (!entry.isFile()) continue;
      const disabled = entry.name.endsWith('.disabled');
      if (!/\.(jar|zip)$|\.jar\.disabled$|\.zip\.disabled$/.test(entry.name)) continue;
      const cleanName = disabled ? entry.name.replace(/\.disabled$/, '') : entry.name;
      const known = meta[cleanName];
      out.push(
        known
          ? { ...known, enabled: !disabled, fileName: entry.name }
          : {
              fileName: entry.name,
              title: cleanName.replace(/\.(jar|zip)$/, ''),
              sizeBytes: fs.statSync(path.join(dir, entry.name)).size,
              installedAt: fs.statSync(path.join(dir, entry.name)).mtimeMs,
              type,
              enabled: !disabled,
            },
      );
    }
  }
  return out.sort((a, b) => b.installedAt - a.installedAt);
}

export function toggleMod(instanceId: string, fileName: string) {
  const candidates = [
    path.join(paths.instance(instanceId), 'mods'),
    path.join(paths.instance(instanceId), 'shaderpacks'),
    path.join(paths.instance(instanceId), 'resourcepacks'),
    path.join(paths.instance(instanceId), 'datapacks'),
  ];
  for (const dir of candidates) {
    const enabled = path.join(dir, fileName.replace(/\.disabled$/, ''));
    const disabled = `${enabled}.disabled`;
    if (fs.existsSync(enabled)) {
      fs.renameSync(enabled, disabled);
      return false;
    }
    if (fs.existsSync(disabled)) {
      fs.renameSync(disabled, enabled);
      return true;
    }
  }
  return false;
}

export function removeMod(instanceId: string, fileName: string) {
  const candidates = [
    path.join(paths.instance(instanceId), 'mods'),
    path.join(paths.instance(instanceId), 'shaderpacks'),
    path.join(paths.instance(instanceId), 'resourcepacks'),
    path.join(paths.instance(instanceId), 'datapacks'),
  ];
  for (const dir of candidates) {
    for (const name of [fileName, `${fileName}.disabled`]) {
      const p = path.join(dir, name);
      if (fs.existsSync(p)) {
        fs.unlinkSync(p);
        return true;
      }
    }
  }
  return false;
}
