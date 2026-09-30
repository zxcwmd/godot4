/* ============================================================
   AXIOM — общие типы для главного процесса (Electron) и UI.
   ============================================================ */

export type Loader = 'vanilla' | 'fabric' | 'quilt' | 'forge' | 'neoforge';
export type VersionType = 'release' | 'snapshot' | 'old_beta' | 'old_alpha';

export interface VersionSummary {
  id: string;
  type: VersionType;
  releaseTime: string;
  url: string;
  /** Уже полностью установлена в библиотеку лаунчера */
  installed?: boolean;
  /** Есть ли готовый профиль загрузчика (Fabric/Quilt/Forge) */
  loaders?: Loader[];
}

export interface Instance {
  id: string;
  name: string;
  versionId: string;
  loader: Loader;
  loaderVersion?: string;
  /** Профиль-«родитель» для загрузчиков (версия, поверх которой ставим) */
  ramMb: number;
  minRamMb: number;
  jvmArgs: string;
  gameArgs: string;
  javaPath?: string;
  createdAt: number;
  lastPlayed?: number;
  playtimeMs: number;
  accent?: string;
  icon: string;
  favorited?: boolean;
  installed: boolean;
}

export interface Account {
  id: string;
  type: 'offline' | 'microsoft';
  name: string;
  uuid: string;
  /** Папка кэша токенов (для microsoft) */
  cacheDir?: string;
  avatar?: string;
  addedAt: number;
  lastUsed?: number;
  valid?: boolean;
}

export type ModProjectType = 'mod' | 'shader' | 'resourcepack' | 'datapack';

export interface ModSearchResult {
  id: string;
  slug: string;
  title: string;
  description: string;
  author: string;
  downloads: number;
  follows: number;
  iconUrl?: string;
  categories: string[];
  loaders: string[];
  gameVersions: string[];
  versions?: string[];
  projectType: ModProjectType;
  updated: string;
}

export interface InstalledMod {
  fileName: string;
  title: string;
  projectId?: string;
  iconUrl?: string;
  version?: string;
  sizeBytes: number;
  installedAt: number;
  type: ModProjectType | 'unknown';
  enabled: boolean;
}

/* ------------------------ Автоматизация ------------------------ */

export type TaskKind =
  | 'mine'
  | 'brew'
  | 'fish'
  | 'farm'
  | 'smelt'
  | 'guard'
  | 'shop'
  | 'stash'
  | 'afk';

export interface TaskDef {
  id: string;
  kind: TaskKind;
  name: string;
  enabled: boolean;
  /** Свободные параметры задачи — зависят от kind */
  options: Record<string, unknown>;
}

export interface BotProfile {
  id: string;
  name: string;
  host: string;
  port: number;
  version: string;
  accountId: string;
  /** Автопереподключение при потере связи */
  autoReconnect: boolean;
  /** Обход AFK-кика: случайные микродвижения */
  antiAfk: boolean;
  /** Автоеда из инвентаря */
  autoEat: boolean;
  tasks: TaskDef[];
  createdAt: number;
  lastRunAt?: number;
  totalRuntimeMs: number;
  stats: BotStats;
}

export interface BotStats {
  blocksMined: number;
  oresFound: Record<string, number>;
  itemsCollected: number;
  brewsMade: number;
  fishCaught: number;
  deaths: number;
  distance: number;
  sessionMs: number;
}

export interface ItemStack {
  name: string;
  displayName: string;
  count: number;
  slot: number;
  /** Символический цвет иконки для UI */
  tint: string;
}

export interface ActivityItem {
  id: string;
  ts: number;
  level: 'info' | 'good' | 'warn' | 'bad' | 'task';
  text: string;
  taskKind?: TaskKind;
}

export interface BotRuntime {
  profileId: string;
  status: 'offline' | 'connecting' | 'online' | 'paused' | 'error';
  statusText: string;
  position: { x: number; y: number; z: number };
  dimension: string;
  health: number;
  food: number;
  ping: number;
  uptimeMs: number;
  currentTaskId?: string;
  currentTaskText?: string;
  taskQueue: { id: string; name: string; kind: TaskKind; progress: number; state: 'pending' | 'active' | 'done' | 'failed' }[];
  stats: BotStats;
  inventory: ItemStack[];
  activity: ActivityItem[];
  /** Последние N значений «добыто в минуту» для графика */
  throughput: number[];
  nearbyPlayers: string[];
}

export interface LogEntry {
  id: string;
  ts: number;
  level: 'debug' | 'info' | 'warn' | 'error' | 'success';
  source: 'launcher' | 'game' | 'bot' | 'installer' | 'network';
  message: string;
}

/* ------------------------ Прогресс/события ------------------------ */

export interface DownloadProgress {
  taskId: string;
  label: string;
  stage: 'prepare' | 'client' | 'libraries' | 'assets' | 'natives' | 'loader' | 'done' | 'error';
  current: number;
  total: number;
  bytesDone: number;
  bytesTotal: number;
  speed: number;
}

export interface Settings {
  accent: 'violet' | 'cyan' | 'emerald' | 'amber' | 'rose' | 'blue';
  animations: boolean;
  reduceTransparency: boolean;
  language: 'ru' | 'en';
  ramMb: number;
  jvmArgs: string;
  gameArgs: string;
  closeOnLaunch: boolean;
  autoUpdateMods: boolean;
  discordRpc: boolean;
  showSnapshots: boolean;
  concurrency: number;
  gameDir: string;
  javaPath?: string;
  telemetryEnabled: boolean;
}

export type AxiomEvent =
  | { type: 'log'; payload: LogEntry }
  | { type: 'progress'; payload: DownloadProgress }
  | { type: 'instances'; payload: Instance[] }
  | { type: 'accounts'; payload: Account[] }
  | { type: 'bots'; payload: BotProfile[] }
  | { type: 'runtime'; payload: BotRuntime }
  | { type: 'msa-code'; payload: { accountId: string; code: string; url: string; expiresIn: number } }
  | { type: 'launch-state'; payload: { state: 'idle' | 'preparing' | 'running' | 'exited'; instanceId?: string; pid?: number; code?: number } }
  | { type: 'toast'; payload: { kind: 'info' | 'good' | 'warn' | 'bad'; title: string; text?: string } };

export interface BootstrapState {
  settings: Settings;
  instances: Instance[];
  accounts: Account[];
  bots: BotProfile[];
  versions: VersionSummary[];
  versionsFetchedAt?: number;
  javaDetected: { path: string; version: string; major: number; vendor: string }[];
  platform: string;
  version: string;
  /** false — приложение открыто в браузере (демо-режим) */
  electron: boolean;
}
