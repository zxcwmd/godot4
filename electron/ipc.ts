import { ipcMain, shell, app, dialog } from 'electron';
import fs from 'node:fs';
import path from 'node:path';
import { paths, ensureBaseDirs, ensureDir } from './services/paths';
import { JsonStore, uid } from './services/store';
import { logger } from './services/logger';
import { getLoaderOptions, getVersionManifest, localVersions, resolveVersion } from './services/mojang';
import { installVersion, type InstallCtx } from './services/installer';
import { buildLaunchPlan, spawnMinecraft, type LaunchHandle } from './services/launcher';
import { accounts } from './services/accounts';
import { detectJava, downloadRuntime } from './services/java';
import * as modrinth from './services/modrinth';
import { BotManager, createDefaultProfile } from './automation';
import { TASK_CATALOG } from './automation/tasks';
import type { AxiomEvent, BootstrapState, Instance, Loader, Settings, VersionSummary } from '../shared/types';

/** Ответ на запрос запуска игры (для UI-статуса и отладки). */
export interface LaunchPlanLike {
  ok: true;
  pid?: number;
  java: string;
  version: string;
  classpath: number;
}

const APP_VERSION = '1.0.0';

const defaultSettings: Settings = {
  accent: 'violet',
  animations: true,
  reduceTransparency: false,
  language: 'ru',
  ramMb: 4096,
  jvmArgs: '',
  gameArgs: '',
  closeOnLaunch: false,
  autoUpdateMods: false,
  discordRpc: false,
  showSnapshots: false,
  concurrency: 12,
  gameDir: '',
  telemetryEnabled: false,
};

export interface Core {
  settings: JsonStore<Settings>;
  instances: JsonStore<{ instances: Instance[] }>;
  bots: BotManager;
  broadcast: (e: AxiomEvent) => void;
  running: Map<string, LaunchHandle>;
  installCtxFor: (taskId: string, label: string) => InstallCtx;
}

export function createCore(broadcast: (e: AxiomEvent) => void): Core {
  ensureBaseDirs();
  const settings = new JsonStore<Settings>(paths.config, defaultSettings);
  const instances = new JsonStore<{ instances: Instance[] }>(paths.instancesFile, { instances: [] });
  const bots = new BotManager(broadcast);
  const running = new Map<string, LaunchHandle>();

  const installCtxFor = (taskId: string, label: string): InstallCtx => ({
    taskId,
    concurrency: settings.get().concurrency,
    emit: (p) =>
      broadcast({
        type: 'progress',
        payload: {
          taskId,
          label: p.label ?? label,
          stage: p.stage ?? 'prepare',
          current: p.current ?? 0,
          total: p.total ?? 1,
          bytesDone: p.bytesDone ?? 0,
          bytesTotal: p.bytesTotal ?? 1,
          speed: p.speed ?? 0,
        },
      }),
  });

  return { settings, instances, bots, broadcast, running, installCtxFor };
}

export function registerIpc(core: Core) {
  const { settings, instances, bots, broadcast, running, installCtxFor } = core;

  /* ─────────────── Bootstrap ─────────────── */
  ipcMain.handle('axiom:bootstrap', async (): Promise<BootstrapState> => {
    return {
      settings: settings.get(),
      instances: instances.get().instances,
      accounts: accounts.list().map((a) => ({ ...a, avatar: accounts.avatarUrl(a) })),
      bots: bots.list(),
      versions: versionListFromCache(),
      javaDetected: detectJava().slice(0, 8),
      platform: process.platform,
      version: APP_VERSION,
      electron: true,
    };
  });

  ipcMain.handle('axiom:task-catalog', () => TASK_CATALOG);

  /* ─────────────── Настройки ─────────────── */
  ipcMain.handle('axiom:settings:set', (_e, partial: Partial<Settings>) => {
    settings.patch(partial);
    return settings.get();
  });

  /* ─────────────── Версии ─────────────── */
  ipcMain.handle('axiom:versions:list', async (_e, force?: boolean) => {
    const manifest = await getVersionManifest(!!force);
    const installed = new Set(localVersions());
    return manifest.versions.map<VersionSummary>((v) => ({
      id: v.id,
      type: v.type,
      releaseTime: v.releaseTime,
      url: v.url,
      installed: installed.has(v.id),
      loaders: loaderProfilesFor(v.id),
    }));
  });

  ipcMain.handle('axiom:versions:loader-options', async (_e, { mcVersion, loader }) => {
    return getLoaderOptions(mcVersion, loader);
  });

  ipcMain.handle('axiom:versions:install', async (event, { versionId }) => {
    const taskId = uid('install');
    try {
      await installVersion(versionId, installCtxFor(taskId, `Установка ${versionId}`));
      const list = versionListFromCache();
      broadcast({ type: 'toast', payload: { kind: 'good', title: `${versionId} установлена`, text: 'Версия готова к запуску' } });
      return { ok: true, versions: list };
    } catch (e) {
      logger.error(`Установка ${versionId} провалилась: ${(e as Error).message}`, 'installer');
      broadcast({ type: 'toast', payload: { kind: 'bad', title: `Ошибка установки ${versionId}`, text: (e as Error).message } });
      return { ok: false, error: (e as Error).message };
    }
  });

  ipcMain.handle('axiom:java:detect', () => detectJava());
  ipcMain.handle('axiom:java:download', async (_e, { major }) => {
    const info = await downloadRuntime(major, (done, total) =>
      broadcast({
        type: 'progress',
        payload: { taskId: 'java', label: `Java ${major}`, stage: 'loader', current: done, total: total || 1, bytesDone: done, bytesTotal: total || 1, speed: 0 },
      }),
    );
    return info;
  });

  /* ─────────────── Сборки ─────────────── */
  ipcMain.handle('axiom:instances:list', () => instances.get().instances);

  ipcMain.handle('axiom:instances:create', (_e, partial: Partial<Instance>) => {
    const list = instances.get().instances;
    const instance: Instance = {
      id: partial.id ?? uid('inst'),
      name: partial.name ?? `Сборка ${list.length + 1}`,
      versionId: partial.versionId ?? '1.21.4',
      loader: partial.loader ?? 'vanilla',
      loaderVersion: partial.loaderVersion,
      ramMb: partial.ramMb ?? settings.get().ramMb,
      minRamMb: partial.minRamMb ?? 512,
      jvmArgs: partial.jvmArgs ?? '',
      gameArgs: partial.gameArgs ?? '',
      javaPath: partial.javaPath,
      createdAt: Date.now(),
      playtimeMs: 0,
      accent: partial.accent ?? 'violet',
      icon: partial.icon ?? 'Package',
      installed: false,
      favorited: false,
    };
    const next = [...list, instance];
    instances.set({ instances: next });
    ensureDir(paths.instance(instance.id));
    ensureDir(path.join(paths.instance(instance.id), 'mods'));
    logger.success(`Создана сборка «${instance.name}» (${instance.versionId}${instance.loader !== 'vanilla' ? ` + ${instance.loader}` : ''})`, 'launcher');
    broadcast({ type: 'instances', payload: next });
    return next;
  });

  ipcMain.handle('axiom:instances:update', (_e, { id, partial }: { id: string; partial: Partial<Instance> }) => {
    const next = instances.get().instances.map((i) => (i.id === id ? { ...i, ...partial } : i));
    instances.set({ instances: next });
    broadcast({ type: 'instances', payload: next });
    return next;
  });

  ipcMain.handle('axiom:instances:remove', async (_e, { id, deleteFiles }: { id: string; deleteFiles?: boolean }) => {
    await running.get(id)?.stop();
    running.delete(id);
    const next = instances.get().instances.filter((i) => i.id !== id);
    instances.set({ instances: next });
    if (deleteFiles) {
      try {
        fs.rmSync(paths.instance(id), { recursive: true, force: true });
      } catch (e) {
        logger.warn(`Не удалось удалить файлы сборки: ${(e as Error).message}`);
      }
    }
    broadcast({ type: 'instances', payload: next });
    return next;
  });

  /* ─────────────── Моды ─────────────── */
  ipcMain.handle('axiom:mods:list', (_e, { instanceId }) => modrinth.listInstalled(instanceId));
  ipcMain.handle('axiom:mods:toggle', (_e, { instanceId, fileName }) => {
    const enabled = modrinth.toggleMod(instanceId, fileName);
    return { enabled, mods: modrinth.listInstalled(instanceId) };
  });
  ipcMain.handle('axiom:mods:remove', (_e, { instanceId, fileName }) => {
    modrinth.removeMod(instanceId, fileName);
    return modrinth.listInstalled(instanceId);
  });
  ipcMain.handle('axiom:modrinth:search', async (_e, params: modrinth.SearchParams) => modrinth.searchProjects(params));
  ipcMain.handle('axiom:modrinth:install', async (_e, { instanceId, project, loader, gameVersion }) => {
    try {
      const mod = await modrinth.installProject(instanceId, project, loader, gameVersion);
      broadcast({ type: 'toast', payload: { kind: 'good', title: `Установлено: ${project.title}`, text: mod.version ? `Версия ${mod.version}` : undefined } });
      return { ok: true, mod };
    } catch (e) {
      broadcast({ type: 'toast', payload: { kind: 'bad', title: `Не удалось установить ${project.title}`, text: (e as Error).message } });
      return { ok: false, error: (e as Error).message };
    }
  });

  /* ─────────────── Аккаунты ─────────────── */
  ipcMain.handle('axiom:accounts:list', () => accounts.list().map((a) => ({ ...a, avatar: accounts.avatarUrl(a) })));
  ipcMain.handle('axiom:accounts:add-offline', (_e, { name }) => accounts.addOffline(name));
  ipcMain.handle('axiom:accounts:remove', (_e, { id }) => {
    accounts.remove(id);
    return accounts.list();
  });
  ipcMain.handle('axiom:accounts:login-microsoft', async (_e, { username }: { username: string }) => {
    try {
      const account = await accounts.loginMicrosoft(username || 'AXIOM', (info) => {
        broadcast({ type: 'msa-code', payload: { accountId: username, code: info.code, url: info.url, expiresIn: info.expiresIn } });
      });
      return { ok: true, account: { ...account, avatar: accounts.avatarUrl(account) } };
    } catch (e) {
      logger.error(`Вход Microsoft не удался: ${(e as Error).message}`, 'network');
      return { ok: false, error: (e as Error).message };
    }
  });

  /* ─────────────── Запуск игры ─────────────── */
  ipcMain.handle('axiom:instances:launch', async (_e, { id, accountId }: { id: string; accountId?: string }) => {
    const instance = instances.get().instances.find((i) => i.id === id);
    if (!instance) return { ok: false, error: 'Сборка не найдена' };
    const account = (accountId ? accounts.get(accountId) : null) ?? accounts.list()[0] ?? accounts.addOffline('AXIOM');
    accounts.markUsed(account.id);
    const s = settings.get();
    const taskId = uid('launch');

    // Обновляем токен Microsoft, если он нужен
    if (account.type === 'microsoft') await accounts.refresh(account);

    try {
      broadcast({ type: 'launch-state', payload: { state: 'preparing', instanceId: id } });
      const plan = await buildLaunchPlan(instance, account, s, installCtxFor(taskId, `Запуск ${instance.name}`));
      const startAt = Date.now();
      const handle = spawnMinecraft(plan, {
        onLog: (line) => {
          const { level, text } = classify(line);
          broadcast({ type: 'log', payload: { id: uid('log'), ts: Date.now(), level, source: 'game', message: text } });
        },
        onExit: (code) => {
          running.delete(id);
          const list = instances.get().instances.map((i) => (i.id === id ? { ...i, playtimeMs: (i.playtimeMs ?? 0) + Date.now() - startAt } : i));
          instances.set({ instances: list });
          broadcast({ type: 'instances', payload: list });
          broadcast({ type: 'launch-state', payload: { state: 'exited', instanceId: id, code: code ?? 0 } });
          broadcast({
            type: 'toast',
            payload: code === 0 ? { kind: 'info', title: 'Игра закрыта', text: `${instance.name} · выход с кодом 0` } : { kind: 'warn', title: 'Игра завершилась', text: `Код выхода: ${code}` },
          });
        },
      });
      running.set(id, handle);
      broadcast({ type: 'launch-state', payload: { state: 'running', instanceId: id, pid: handle.process.pid } });
      return { ok: true, pid: handle.process.pid, java: plan.java.path, version: plan.versionId, classpath: plan.classpathCount } satisfies LaunchPlanLike;
    } catch (e) {
      logger.error(`Запуск не удался: ${(e as Error).message}`, 'launcher');
      broadcast({ type: 'launch-state', payload: { state: 'idle', instanceId: id } });
      broadcast({ type: 'toast', payload: { kind: 'bad', title: 'Не удалось запустить игру', text: (e as Error).message } });
      return { ok: false, error: (e as Error).message };
    }
  });

  ipcMain.handle('axiom:instances:kill', async (_e, { id }) => {
    running.get(id)?.stop();
    return true;
  });

  /* ─────────────── Автоматизация ─────────────── */
  ipcMain.handle('axiom:bots:list', () => bots.list());
  ipcMain.handle('axiom:bots:create', (_e, partial) => {
    const profile = createDefaultProfile(partial);
    bots.save(profile);
    logger.success(`Создан профиль автоматизации «${profile.name}»`, 'bot');
    return profile;
  });
  ipcMain.handle('axiom:bots:update', (_e, { id, partial }) => bots.updateProfile(id, partial));
  ipcMain.handle('axiom:bots:remove', (_e, { id }) => {
    bots.remove(id);
    return bots.list();
  });
  ipcMain.handle('axiom:bots:start', async (_e, { id }) => {
    await bots.start(id);
    return true;
  });
  ipcMain.handle('axiom:bots:stop', async (_e, { id }) => {
    await bots.stop(id);
    return true;
  });
  ipcMain.handle('axiom:bots:pause', (_e, { id }) => {
    bots.pause(id);
    return true;
  });
  ipcMain.handle('axiom:bots:resume', (_e, { id }) => {
    bots.resume(id);
    return true;
  });
  ipcMain.handle('axiom:bots:tasks', (_e, { id, tasks }) => {
    bots.updateTasks(id, tasks);
    return bots.list();
  });
  ipcMain.handle('axiom:bots:runtime', (_e, { id }) => bots.runtimeOf(id));

  /* ─────────────── Системное ─────────────── */
  ipcMain.handle('axiom:logs:history', () => logger.history());
  ipcMain.handle('axiom:system:open-path', async (_e, { target }: { target: string }) => {
    const resolved = target === 'root' ? paths.root : target === 'shared' ? paths.shared : path.resolve(target);
    ensureDir(resolved);
    await shell.openPath(resolved);
    return resolved;
  });
  ipcMain.handle('axiom:system:open-external', async (_e, { url }) => {
    if (/^https?:\/\//.test(url)) await shell.openExternal(url);
    return true;
  });
  ipcMain.handle('axiom:system:pick-folder', async () => {
    const res = await dialog.showOpenDialog({ properties: ['openDirectory', 'createDirectory'] });
    return res.canceled ? null : res.filePaths[0];
  });
  ipcMain.handle('axiom:system:info', () => ({
    platform: process.platform,
    version: APP_VERSION,
    electron: process.versions.electron,
    node: process.versions.node,
    userData: paths.root,
    installedVersions: localVersions(),
    totalMemoryMb: Math.round(require('node:os').totalmem() / 1024 / 1024),
  }));
  ipcMain.handle('axiom:app:quit', () => app.quit());
  ipcMain.handle('axiom:app:version', () => app.getVersion() ?? APP_VERSION);
}

function classify(line: string): { level: 'info' | 'warn' | 'error' | 'success' | 'debug'; text: string } {
  if (/Exception|Caused by|FATAL|\/ERROR]/.test(line)) return { level: 'error', text: line };
  if (/\/WARN]/.test(line)) return { level: 'warn', text: line };
  if (/Done \(|Sound engine started|Stopping!/.test(line)) return { level: 'success', text: line };
  if (/\/DEBUG]/.test(line)) return { level: 'debug', text: line };
  return { level: 'info', text: line };
}

function versionListFromCache(): VersionSummary[] {
  const installed = new Set(localVersions());
  try {
    const file = path.join(paths.meta, 'version_manifest_v2.json');
    if (!fs.existsSync(file)) return [];
    const data = JSON.parse(fs.readFileSync(file, 'utf8'));
    return (data.versions ?? []).map((v: { id: string; type: VersionSummary['type']; releaseTime: string; url: string }) => ({
      id: v.id,
      type: v.type,
      releaseTime: v.releaseTime,
      url: v.url,
      installed: installed.has(v.id),
      loaders: loaderProfilesFor(v.id),
    }));
  } catch {
    return [];
  }
}

function loaderProfilesFor(mcVersion: string): Loader[] {
  const result: Loader[] = [];
  try {
    for (const dir of fs.readdirSync(paths.modloaders)) {
      if (!dir.endsWith(`${mcVersion}.json`)) continue;
      for (const loader of ['fabric', 'quilt', 'forge', 'neoforge'] as Loader[]) if (dir.startsWith(`${loader}-`)) result.push(loader);
    }
  } catch {
    /* кэша нет */
  }
  return [...new Set(result)];
}

export { APP_VERSION };
