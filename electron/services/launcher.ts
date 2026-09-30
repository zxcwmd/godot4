import fs from 'node:fs';
import path from 'node:path';
import { ChildProcess, spawn } from 'node:child_process';
import { paths, ensureDir } from './paths';
import { logger } from './logger';
import { buildClasspath, installVersion, nativesDirFor, ruleAllows, type InstallCtx } from './installer';
import { getLoaderProfile, isInstalled, resolveVersion, type VersionJson } from './mojang';
import { detectJava, downloadRuntime, findSuitableJava, requiredJavaMajor, type JavaInfo } from './java';
import type { Account, Instance, Settings } from '../../shared/types';

export interface LaunchHandle {
  process: ChildProcess;
  stop: () => void;
}

type GameArg = string | { rules?: { action: 'allow' | 'disallow'; os?: { name?: string }; features?: Record<string, boolean> }[]; value: string | string[] };

function expandArg(arg: GameArg, features: Record<string, boolean>): string[] {
  if (typeof arg === 'string') return [arg];
  if (!ruleAllows(arg.rules as never, features)) return [];
  return Array.isArray(arg.value) ? arg.value : [arg.value];
}

export interface LaunchPlan {
  java: JavaInfo;
  args: string[];
  cwd: string;
  versionId: string;
  classpathCount: number;
}

/**
 * Собирает команду запуска: клиент + библиотеки + профиль загрузчика + аргументы JVM/игры.
 * Полностью повторяет логику официального лаунчера (подстановка плейсхолдеров, правила ОС/фич).
 */
export async function buildLaunchPlan(
  instance: Instance,
  account: Account,
  settings: Settings,
  ctx: InstallCtx,
): Promise<LaunchPlan> {
  const versionId = instance.versionId;
  if (!isInstalled(versionId)) {
    await installVersion(versionId, ctx);
  }

  let profile: VersionJson;
  let effectiveId = versionId;

  if (instance.loader !== 'vanilla' && instance.loaderVersion) {
    const loaderJson = await getLoaderProfile(versionId, instance.loader, instance.loaderVersion);
    effectiveId = loaderJson.id ?? `${instance.loader}-${instance.loaderVersion}-${versionId}`;
    // Устанавливаем и базовую версию — загрузчик наследуется от неё
    if (!isInstalled(loaderJson.inheritsFrom ?? versionId)) {
      await installVersion(loaderJson.inheritsFrom ?? versionId, ctx);
    }
    profile = await resolveVersion(effectiveId);
    if (!profile.mainClass) profile.mainClass = loaderJson.mainClass;
  } else {
    profile = await resolveVersion(versionId);
  }

  /* ───── Java ───── */
  const needMajor = requiredJavaMajor(versionId, profile.javaVersion?.majorVersion);
  let java: JavaInfo | undefined;
  if (instance.javaPath && fs.existsSync(instance.javaPath)) {
    const detected = detectJava().find((j) => j.path === instance.javaPath);
    java = detected ?? { path: instance.javaPath, version: 'unknown', major: needMajor, vendor: 'custom' };
  }
  if (!java) java = findSuitableJava(detectJava(), needMajor);
  if (!java || (java.major < needMajor && needMajor > 8)) {
    logger.warn(`Нет Java ${needMajor} — скачиваю автоматически`, 'installer');
    java = await downloadRuntime(needMajor);
  }
  logger.info(`Запуск на Java ${java.major} (${java.vendor})`, 'game');

  /* ───── Каталоги ───── */
  const gameDir = paths.instance(instance.id);
  ensureDir(gameDir);
  ensureDir(path.join(gameDir, 'mods'));
  ensureDir(path.join(gameDir, 'logs'));
  const nativesDir = nativesDirFor(profile.inheritsFrom ?? effectiveId);
  ensureDir(nativesDir);

  /* ───── Classpath ───── */
  const classpath = buildClasspath(profile, effectiveId);
  const classpathStr = classpath.join(path.delimiter);

  /* ───── Подстановки ───── */
  const features = {
    is_demo_user: false,
    has_custom_resolution: false,
    has_quick_plays_support: false,
    is_quick_play_singleplayer: false,
    is_quick_play_multiplayer: false,
    is_quick_play_realms: false,
  };
  const replacements: Record<string, string> = {
    auth_player_name: account.name,
    version_name: effectiveId,
    game_directory: gameDir,
    assets_root: paths.assets,
    game_assets: path.join(paths.assets, 'virtual', 'legacy'),
    assets_index_name: profile.assetIndex?.id ?? profile.assets ?? 'legacy',
    auth_uuid: account.uuid.replace(/-/g, ''),
    auth_access_token: account.type === 'microsoft' ? (account as never as { accessToken?: string }).accessToken ?? '0' : '0',
    auth_session: account.type === 'microsoft' ? (account as never as { accessToken?: string }).accessToken ?? '0' : '0',
    user_type: account.type === 'microsoft' ? 'msa' : 'legacy',
    version_type: profile.type ?? 'release',
    natives_directory: nativesDir,
    launcher_name: 'AXIOM',
    launcher_version: '1.0.0',
    classpath: classpathStr,
    classpath_separator: path.delimiter,
    library_directory: paths.libraries,
    user_properties: '{}',
    clientid: '00000000402b5328',
    auth_xuid: '0',
    resolution_width: '1280',
    resolution_height: '720',
  };

  const apply = (s: string) => s.replace(/\$\{([a-zA-Z_0-9]+)\}/g, (_, key: string) => replacements[key] ?? '');

  const jvmArgs: string[] = [];
  if (profile.arguments?.jvm?.length) {
    for (const a of profile.arguments.jvm) {
      for (const v of expandArg(a as GameArg, features)) jvmArgs.push(apply(v));
    }
  } else {
    jvmArgs.push('-Djava.library.path=' + nativesDir, '-cp', classpathStr);
  }

  const ram = Math.max(1024, Math.min(settings.ramMb || instance.ramMb, 65536));
  const memArgs = [
    `-Xmx${ram}M`,
    `-Xms${Math.max(512, Math.round(ram / 4))}M`,
    '-XX:+UnlockExperimentalVMOptions',
    '-XX:+UseG1GC',
    '-XX:G1NewSizePercent=20',
    '-XX:G1ReservePercent=20',
    '-XX:MaxGCPauseMillis=50',
    '-XX:G1HeapRegionSize=32M',
    '-Dfile.encoding=UTF-8',
    `-Dminecraft.launcher.brand=AXIOM`,
    `-Dminecraft.launcher.version=1.0.0`,
  ];
  const extraJvm = (settings.jvmArgs || instance.jvmArgs || '')
    .split(/\s+/)
    .filter(Boolean);

  const gameArgs: string[] = [];
  if (profile.arguments?.game?.length) {
    for (const a of profile.arguments.game) {
      for (const v of expandArg(a as GameArg, features)) gameArgs.push(apply(v));
    }
  } else if (profile.minecraftArguments) {
    gameArgs.push(...profile.minecraftArguments.split(/\s+/).filter(Boolean).map(apply));
  }

  const extraGame = (settings.gameArgs || '').split(/\s+/).filter(Boolean);

  const args = [...memArgs, ...extraJvm, ...jvmArgs, profile.mainClass, ...gameArgs, ...instance.gameArgs.split(/\s+/).filter(Boolean), ...extraGame];

  logger.info(`План запуска: ${effectiveId} · ${classpath.length} jar · ${ram} МБ ОЗУ · главный класс ${profile.mainClass}`, 'launcher');

  return { java, args, cwd: gameDir, versionId: effectiveId, classpathCount: classpath.length };
}

export interface SpawnHandlers {
  onLog: (line: string) => void;
  onExit: (code: number | null) => void;
}

export function spawnMinecraft(plan: LaunchPlan, handlers: SpawnHandlers): LaunchHandle {
  const child = spawn(plan.java.path, plan.args, {
    cwd: plan.cwd,
    env: {
      ...process.env,
      APPDATA: paths.root,
      // важно: некоторые версии ищут assets по относительным путям
      MODRINTH_DISABLE_TELEMETRY: '1',
    },
    stdio: ['pipe', 'pipe', 'pipe'],
    windowsHide: true,
  });

  const handleLine = (line: string) => {
    const clean = line.replace(/\x1b\[[0-9;]*m/g, '').trimEnd();
    if (!clean) return;
    handlers.onLog(clean);
  };

  let buf = '';
  child.stdout?.on('data', (d: Buffer) => {
    buf += d.toString('utf8');
    const lines = buf.split(/\r?\n/);
    buf = lines.pop() ?? '';
    lines.forEach(handleLine);
  });
  let ebuf = '';
  child.stderr?.on('data', (d: Buffer) => {
    ebuf += d.toString('utf8');
    const lines = ebuf.split(/\r?\n/);
    ebuf = lines.pop() ?? '';
    lines.forEach(handleLine);
  });

  child.on('exit', (code) => {
    logger.info(`Игра завершилась с кодом ${code ?? 0}`, 'game');
    handlers.onExit(code);
  });
  child.on('error', (err) => {
    logger.error(`Ошибка запуска процесса: ${err.message}`, 'game');
    handlers.onExit(-1);
  });

  return {
    process: child,
    stop: () => {
      try {
        child.kill('SIGTERM');
      } catch {
        /* уже мёртв */
      }
    },
  };
}

/** Разбор строк лога Minecraft для красивого вывода в консоли лаунчера. */
export function classifyGameLine(line: string): { level: 'info' | 'warn' | 'error' | 'success' | 'debug'; text: string } {
  if (/^\s*\[[\d:]+]\s*\[.*\/ERROR]/i.test(line) || /Exception|Caused by|FATAL/i.test(line)) return { level: 'error', text: line };
  if (/\/WARN]/.test(line)) return { level: 'warn', text: line };
  if (/Stopping!|Shutting down|Sound engine started|Backend library:/.test(line)) return { level: 'success', text: line };
  if (/^\s*\[[\d:]+]\s*\[.*\/DEBUG]/i.test(line)) return { level: 'debug', text: line };
  return { level: 'info', text: line };
}
