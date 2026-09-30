/* ============================================================
   Демо-ядро для запуска интерфейса в браузере (веб-превью).
   Полностью повторяет контракт electron-моста: те же каналы,
   те же события — UI не знает, где он работает.
   ============================================================ */

import type {
  Account,
  InstalledMod,
  Loader,
  AxiomEvent,
  BotProfile,
  BotRuntime,
  DownloadProgress,
  Instance,
  LogEntry,
  ModSearchResult,
  Settings,
  TaskDef,
  VersionSummary,
} from '@shared/types';

/* ─────────────── Сиды данных ─────────────── */

const now = Date.now();

function iso(daysAgo: number) {
  return new Date(now - daysAgo * 86400000).toISOString();
}

const RELEASES: [string, number][] = [
  ['1.21.4', 3], ['1.21.3', 40], ['1.21.1', 90], ['1.21', 130], ['1.20.6', 180], ['1.20.4', 260],
  ['1.20.1', 420], ['1.19.4', 600], ['1.19.2', 700], ['1.18.2', 900], ['1.17.1', 1100],
  ['1.16.5', 1400], ['1.15.2', 1700], ['1.14.4', 2000], ['1.12.2', 2400], ['1.8.9', 3300],
];

const SNAPSHOTS = ['25w03a', '24w45a', '24w33a', '24w21a', '24w14a'];

export const MOCK_VERSIONS: VersionSummary[] = [
  ...RELEASES.map(([id, days]) => ({
    id,
    type: 'release' as const,
    releaseTime: iso(days),
    url: '',
    installed: ['1.21.4', '1.21.1', '1.20.1', '1.12.2'].includes(id),
    loaders: (id === '1.21.1' ? ['fabric'] : id === '1.20.1' ? ['fabric', 'forge'] : []) as Loader[],
  })),
  ...SNAPSHOTS.map((id, i) => ({
    id,
    type: 'snapshot' as const,
    releaseTime: iso(20 + i * 12),
    url: '',
    installed: false,
    loaders: [] as Loader[],
  })),
  { id: 'b1.7.3', type: 'old_beta' as const, releaseTime: iso(5000), url: '', installed: false, loaders: [] as Loader[] },
];

export const MOCK_INSTANCES: Instance[] = [
  {
    id: 'inst_axiom_main',
    name: 'AXIOM · основной мир',
    versionId: '1.21.4',
    loader: 'fabric',
    loaderVersion: '0.16.9',
    ramMb: 6144,
    minRamMb: 512,
    jvmArgs: '',
    gameArgs: '',
    createdAt: now - 86400000 * 42,
    lastPlayed: now - 3600_000,
    playtimeMs: 86_400_000 * 3 + 5_400_000,
    accent: 'violet',
    icon: 'Sparkles',
    installed: true,
    favorited: true,
  },
  {
    id: 'inst_tech',
    name: 'Мегабаза · автоматизация',
    versionId: '1.20.1',
    loader: 'fabric',
    loaderVersion: '0.15.11',
    ramMb: 8192,
    minRamMb: 1024,
    jvmArgs: '-XX:+UseZGC',
    gameArgs: '',
    createdAt: now - 86400000 * 120,
    lastPlayed: now - 86400000 * 2,
    playtimeMs: 86_400_000 * 11,
    accent: 'cyan',
    icon: 'Cpu',
    installed: true,
  },
  {
    id: 'inst_forge',
    name: 'Forge · модпак',
    versionId: '1.20.1',
    loader: 'forge',
    loaderVersion: '47.2.20',
    ramMb: 8192,
    minRamMb: 1024,
    jvmArgs: '',
    gameArgs: '',
    createdAt: now - 86400000 * 200,
    lastPlayed: now - 86400000 * 9,
    playtimeMs: 86_400_000 * 20,
    accent: 'amber',
    icon: 'Wrench',
    installed: true,
  },
  {
    id: 'inst_old',
    name: 'Ностольжи · 1.8.9 PvP',
    versionId: '1.8.9',
    loader: 'vanilla',
    ramMb: 2048,
    minRamMb: 512,
    jvmArgs: '',
    gameArgs: '',
    createdAt: now - 86400000 * 300,
    lastPlayed: now - 86400000 * 40,
    playtimeMs: 3_600_000 * 26,
    accent: 'rose',
    icon: 'Swords',
    installed: true,
  },
];

export const MOCK_ACCOUNTS: Account[] = [
  { id: 'acc_main', type: 'microsoft', name: 'AxiomRunner', uuid: '069a79f444e94726a5befca90e38aaf5', addedAt: now - 86400000 * 80, lastUsed: now - 3600_000, avatar: 'https://crafatar.com/avatars/069a79f444e94726a5befca90e38aaf5?size=96&overlay', valid: true },
  { id: 'acc_alt', type: 'offline', name: 'FarmBot', uuid: 'c9b2e0b0-5b1f-3c9a-9b1e-2f6c8d3a7e11', addedAt: now - 86400000 * 12, avatar: 'https://minotar.net/helm/FarmBot/96.png', valid: true },
];

function task(partial: Partial<TaskDef> & { kind: TaskDef['kind']; name: string }): TaskDef {
  return { id: `task_${partial.kind}_${Math.random().toString(36).slice(2, 7)}`, enabled: true, options: {}, ...partial } as TaskDef;
}

export const MOCK_BOTS: BotProfile[] = [
  {
    id: 'bot_mine',
    name: 'Шахтёр-01',
    host: 'play.axiom-craft.ru',
    port: 25565,
    version: '1.20.1',
    accountId: 'acc_alt',
    autoReconnect: true,
    antiAfk: true,
    autoEat: true,
    tasks: [
      task({ kind: 'mine', name: 'Автошахта', options: { mode: 'ores', radius: 64 } }),
      task({ kind: 'smelt', name: 'Автоплавка', options: { radius: 24 }, enabled: false }),
      task({ kind: 'stash', name: 'Автосклад', options: { keep: 'sword,pickaxe,torch,coal', radius: 32 } }),
      task({ kind: 'afk', name: 'Анти-AFK', options: {} }),
    ],
    createdAt: now - 86400000 * 30,
    lastRunAt: now - 600000,
    totalRuntimeMs: 86_400_000 * 4 + 7_200_000,
    stats: { blocksMined: 148_320, oresFound: { diamond_ore: 412, deepslate_diamond_ore: 289, iron_ore: 9012, gold_ore: 2140, redstone_ore: 6120, coal_ore: 18400, ancient_debris: 14 }, itemsCollected: 92_400, brewsMade: 0, fishCaught: 0, deaths: 3, distance: 148_000, sessionMs: 0 },
  },
  {
    id: 'bot_brew',
    name: 'Алхимик',
    host: 'play.axiom-craft.ru',
    port: 25565,
    version: '1.20.1',
    accountId: 'acc_alt',
    autoReconnect: true,
    antiAfk: true,
    autoEat: true,
    tasks: [
      task({ kind: 'brew', name: 'Автоварка зелий', options: { recipe: 'strength', radius: 24 } }),
      task({ kind: 'fish', name: 'Авторыбалка', options: {}, enabled: false }),
      task({ kind: 'afk', name: 'Анти-AFK', options: {} }),
    ],
    createdAt: now - 86400000 * 18,
    lastRunAt: now - 3600_000,
    totalRuntimeMs: 86_400_000 * 2 + 3_600_000,
    stats: { blocksMined: 1204, oresFound: { nether_wart: 340, blaze_rod: 88 }, itemsCollected: 5120, brewsMade: 846, fishCaught: 0, deaths: 1, distance: 12_400, sessionMs: 0 },
  },
  {
    id: 'bot_farm',
    name: 'Фермер-02',
    host: 'localhost',
    port: 25566,
    version: '1.21.4',
    accountId: 'acc_alt',
    autoReconnect: false,
    antiAfk: true,
    autoEat: true,
    tasks: [
      task({ kind: 'farm', name: 'Автоферма', options: { radius: 48 } }),
      task({ kind: 'shop', name: 'Автоторговля', options: { item: 'emerald', times: 4, radius: 24 } }),
      task({ kind: 'guard', name: 'Охрана базы', options: { radius: 16 } }),
    ],
    createdAt: now - 86400000 * 6,
    lastRunAt: now - 86400000 * 1,
    totalRuntimeMs: 86_400_000 + 43_200_000,
    stats: { blocksMined: 22_140, oresFound: { wheat: 4120, carrots: 2210 }, itemsCollected: 41_000, brewsMade: 0, fishCaught: 1180, deaths: 0, distance: 42_600, sessionMs: 0 },
  },
];

export const MOCK_MODS: ModSearchResult[] = [
  { id: 'sodium', slug: 'sodium', title: 'Sodium', description: 'Переписанный рендерер: в 3–5 раз больше FPS и стабильный фреймтайм даже на слабых ПК.', author: 'CaffeineMC', downloads: 42_100_000, follows: 21_400, categories: ['optimization'], loaders: ['fabric', 'quilt'], gameVersions: ['1.21.4', '1.21.1', '1.20.1'], projectType: 'mod', updated: iso(2) },
  { id: 'iris', slug: 'iris', title: 'Iris Shaders', description: 'Шейдерпаки формата OptiFine поверх Sodium — максимальная картинка без потери FPS.', author: 'IrisShaders', downloads: 18_600_000, follows: 12_800, categories: ['optimization', 'decoration'], loaders: ['fabric', 'quilt'], gameVersions: ['1.21.4', '1.21.1'], projectType: 'mod', updated: iso(4) },
  { id: 'lithium', slug: 'lithium', title: 'Lithium', description: 'Оптимизация игровой логики: тики, физика, ИИ мобов. Полностью прозрачно для геймплея.', author: 'CaffeineMC', downloads: 26_300_000, follows: 15_100, categories: ['optimization'], loaders: ['fabric', 'quilt', 'neoforge'], gameVersions: ['1.21.4', '1.21.1', '1.20.1'], projectType: 'mod', updated: iso(1) },
  { id: 'jei', slug: 'jei', title: 'Just Enough Items', description: 'Все рецепты крафта и переплавки под рукой — незаменимо для автоматизации.', author: 'mezz', downloads: 121_000_000, follows: 41_000, categories: ['utility'], loaders: ['fabric', 'forge', 'neoforge'], gameVersions: ['1.21.4', '1.20.1'], projectType: 'mod', updated: iso(12) },
  { id: 'ae2', slug: 'applied-energistics-2', title: 'Applied Energistics 2', description: 'Цифровое хранилище и авто-крафт на энергии: ME-сеть, интерфейсы, «умные» шины.', author: 'AlgorithmX2', downloads: 38_400_000, follows: 19_200, categories: ['technology'], loaders: ['forge', 'fabric', 'neoforge'], gameVersions: ['1.20.1', '1.21.1'], projectType: 'mod', updated: iso(6) },
  { id: 'create', slug: 'create', title: 'Create', description: 'Механическая инженерия с шестерёнками, конвейерами и поездами — лучший мод про автоматизацию.', author: 'simibubi', downloads: 55_200_000, follows: 44_000, categories: ['technology', 'decoration'], loaders: ['forge', 'fabric', 'neoforge'], gameVersions: ['1.20.1', '1.21.1'], projectType: 'mod', updated: iso(3) },
  { id: 'mekanism', slug: 'mekanism', title: 'Mekanism', description: 'Продвинутая технологическая ветка: от рудо-обработки до реакторов и телепортеров.', author: 'bradyaidanc', downloads: 30_100_000, follows: 16_400, categories: ['technology', 'energy'], loaders: ['forge', 'neoforge'], gameVersions: ['1.20.1'], projectType: 'mod', updated: iso(30) },
  { id: 'shader_comp', slug: 'complementary-reimagined', title: 'Complementary Reimagined', description: 'Кинематографичные шейдеры: объёмный свет, мягкие тени, живая вода с преломлением.', author: 'Complementary', downloads: 31_200_000, follows: 33_500, categories: ['shaders'], loaders: ['irisshaders', 'optifine'], gameVersions: ['1.21.4', '1.20.1'], projectType: 'shader', updated: iso(8) },
  { id: 'shader_bsl', slug: 'bsl-shaders', title: 'BSL Shaders', description: 'Классика: тёплая атмосфера, туман, детальные отражения. Хорошо идёт даже на средних сборках.', author: 'capttatsu', downloads: 29_800_000, follows: 27_100, categories: ['shaders'], loaders: ['irisshaders', 'optifine'], gameVersions: ['1.21.4', '1.20.1'], projectType: 'shader', updated: iso(15) },
  { id: 'rp_faithful', slug: 'faithful', title: 'Faithful 32x', description: 'Улучшенные текстуры в ванильном стиле — 32×32 без потери узнаваемости.', author: 'Faithful Team', downloads: 44_000_000, follows: 18_800, categories: ['resourcepacks'], loaders: ['minecraft'], gameVersions: ['1.21.4', '1.20.1'], projectType: 'resourcepack', updated: iso(21) },
  { id: 'xray', slug: 'freecam', title: 'Freecam', description: 'Свободная камера для съёмки баз и строительства — удобно проверять автоматизацию.', author: 'hastebrot', downloads: 6_400_000, follows: 5_100, categories: ['utility'], loaders: ['fabric'], gameVersions: ['1.21.4'], projectType: 'mod', updated: iso(5) },
  { id: 'distanthorizons', slug: 'distanthorizons', title: 'Distant Horizons', description: 'Дальность прорисовки в сотни чанков без просадки FPS — вид на весь мир.', author: 'jeseibel', downloads: 9_800_000, follows: 8_400, categories: ['optimization'], loaders: ['fabric', 'neoforge'], gameVersions: ['1.21.4', '1.20.1'], projectType: 'mod', updated: iso(2) },
];

const MOCK_INSTALLED: InstalledMod[] = [
  { fileName: 'sodium-fabric-0.6.9.jar', title: 'Sodium', projectId: 'sodium', version: '0.6.9', sizeBytes: 1_248_000, installedAt: now - 86400000 * 5, type: 'mod' as const, enabled: true, iconUrl: '' },
  { fileName: 'lithium-fabric-0.14.3.jar', title: 'Lithium', projectId: 'lithium', version: '0.14.3', sizeBytes: 986_000, installedAt: now - 86400000 * 5, type: 'mod' as const, enabled: true, iconUrl: '' },
  { fileName: 'iris-1.8.1.jar', title: 'Iris Shaders', projectId: 'iris', version: '1.8.1', sizeBytes: 2_640_000, installedAt: now - 86400000 * 4, type: 'mod' as const, enabled: true, iconUrl: '' },
  { fileName: 'jei-1.21.4.jar', title: 'Just Enough Items', projectId: 'jei', version: '18.0.0', sizeBytes: 1_180_000, installedAt: now - 86400000 * 3, type: 'mod' as const, enabled: false, iconUrl: '' },
  { fileName: 'ComplementaryReimagined_r5.3.zip', title: 'Complementary Reimagined', projectId: 'complementary', version: 'r5.3', sizeBytes: 8_400_000, installedAt: now - 86400000 * 2, type: 'shader' as const, enabled: true, iconUrl: '' },
];

/* ─────────────── Симуляция живого бота ─────────────── */

const ITEMS = [
  ['diamond', 'Алмаз', '#5eead4'], ['iron_ingot', 'Железный слиток', '#e2e8f0'], ['gold_ingot', 'Золотой слиток', '#fbbf24'],
  ['redstone', 'Редстоун', '#f87171'], ['coal', 'Уголь', '#64748b'], ['cobblestone', 'Булыжник', '#94a3b8'],
  ['oak_log', 'Дуб', '#a16207'], ['potion', 'Зелье силы', '#f472b6'], ['nether_wart', 'Адский нарост', '#be123c'],
  ['blaze_rod', 'Огненный стержень', '#fbbf24'], ['wheat', 'Пшеница', '#fcd34d'], ['cod', 'Треска', '#93c5fd'],
];

const ACTIVITY_TEMPLATES = [
  ['Автошахта: добыто 24 блока в цикле', 'info'],
  ['Автошахта: ⛏ Найдена руда: diamond_ore (413 всего)', 'good'],
  ['Автошахта: выбросил 64× cobblestone (инвентарь переполнен)', 'warn'],
  ['Автосклад: 📦 Сложено на склад: 812 предметов', 'good'],
  ['Анти-AFK: имитирую активность', 'task'],
  ['Автоварка зелий: 🍶 Готово: 3× Зелье силы', 'good'],
  ['Чат: <Steve> бот, вернись на базу', 'info'],
  ['Охрана базы: противник zombie нейтрализован', 'good'],
  ['Автоторговля: 💱 Обменяно 4× (wheat → emerald)', 'good'],
  ['Автоферма: 🌾 Собрано 38 растений', 'good'],
] as const;

export class MockBackend {
  private listeners = new Set<(e: AxiomEvent) => void>();
  private settings: Settings = {
    accent: 'violet',
    animations: true,
    reduceTransparency: false,
    language: 'ru',
    ramMb: 6144,
    jvmArgs: '',
    gameArgs: '',
    closeOnLaunch: false,
    autoUpdateMods: true,
    discordRpc: true,
    showSnapshots: false,
    concurrency: 12,
    gameDir: '',
    telemetryEnabled: false,
  };
  private instances = structuredClone(MOCK_INSTANCES);
  private accounts = structuredClone(MOCK_ACCOUNTS);
  private bots = structuredClone(MOCK_BOTS);
  private runtimes = new Map<string, BotRuntime>();
  private logs: LogEntry[] = [];
  private timers = new Map<string, ReturnType<typeof setInterval>>();
  private installedMods = structuredClone(MOCK_INSTALLED);
  private seq = 0;

  constructor() {
    this.seedLogs();
    // два бота запущены «из коробки», чтобы превью сразу выглядело живым
    this.startBot('bot_mine', true);
    this.startBot('bot_brew', true);
  }

  on(handler: (e: AxiomEvent) => void) {
    this.listeners.add(handler);
    return () => this.listeners.delete(handler);
  }

  private emit(e: AxiomEvent) {
    if (e.type === 'log') {
      this.logs.push(e.payload);
      if (this.logs.length > 800) this.logs.splice(0, this.logs.length - 800);
    }
    for (const l of this.listeners) l(e);
  }

  private seedLogs() {
    const messages: [LogEntry['level'], LogEntry['source'], string][] = [
      ['success', 'launcher', 'AXIOM 1.0.0 запущен (веб-превью, демо-ядро)'],
      ['info', 'network', 'Манифест версий обновлён: 918 версий, latest=1.21.4'],
      ['info', 'launcher', 'Найдено Java: 21 (Temurin), 17 (OpenJDK)'],
      ['info', 'installer', 'Ассеты: 3 812 объектов (2 104 уже в кэше)'],
      ['success', 'installer', 'Версия 1.21.4 установлена'],
      ['info', 'bot', '[Шахтёр-01] Подключение к play.axiom-craft.ru:25565 (1.20.1)'],
      ['success', 'bot', '[Шахтёр-01] Бот вошёл в игру как FarmBot'],
      ['info', 'bot', '[Алхимик] Автоварка зелий стартовала'],
      ['success', 'bot', '[Алхимик] 🍶 Готово: 3× Зелье силы'],
      ['warn', 'bot', '[Шахтёр-01] Инвентарь почти полон — раскладываю в сундук'],
      ['success', 'bot', '[Шахтёр-01] 📦 Сложено на склад: 1 284 предмета'],
      ['info', 'game', '[Render thread/INFO]: Backend library: LWJGL version 3.3.3+5'],
      ['info', 'game', '[Render thread/INFO]: OpenGL 4.6 · NVIDIA GeForce RTX 4060'],
      ['success', 'game', 'Done (3.412s)! For help, type "help"'],
      ['info', 'game', '[Worker-Main-1/INFO]: Preparing spawn area: 94%'],
      ['warn', 'game', '[Render thread/WARN]: Texture atlases are getting full'],
      ['info', 'network', 'Modrinth: 24 проекта по запросу «optimization»'],
    ];
    let t = now - 1000 * 60 * 12;
    for (const [level, source, message] of messages) {
      t += 1500 + Math.random() * 6000;
      this.emit({ type: 'log', payload: { id: `log_${++this.seq}`, ts: Math.min(t, now), level: level as LogEntry['level'], source, message } });
    }
  }

  private rt(id: string): BotRuntime {
    let rt = this.runtimes.get(id);
    if (!rt) {
      rt = {
        profileId: id,
        status: 'offline',
        statusText: 'Не подключён',
        position: { x: 128, y: 64, z: -420 },
        dimension: 'overworld',
        health: 20,
        food: 20,
        ping: 42,
        uptimeMs: 0,
        taskQueue: [],
        stats: { blocksMined: 0, oresFound: {}, itemsCollected: 0, brewsMade: 0, fishCaught: 0, deaths: 0, distance: 0, sessionMs: 0 },
        inventory: [],
        activity: [],
        throughput: [],
        nearbyPlayers: ['Steve', 'Alex'],
      };
      this.runtimes.set(id, rt);
    }
    return rt;
  }

  private startBot(id: string, silent = false) {
    const profile = this.bots.find((b) => b.id === id);
    if (!profile) return;
    const rt = this.rt(id);
    const enabled = profile.tasks.filter((t) => t.enabled);
    rt.status = 'connecting';
    rt.statusText = `Подключаюсь к ${profile.host}:${profile.port}…`;
    rt.taskQueue = enabled.map((t, i) => ({ id: t.id, name: t.name, kind: t.kind, progress: 0, state: i === 0 ? 'active' : 'pending' }));
    rt.stats = { ...profile.stats };
    rt.stats.sessionMs = 0;
    rt.activity = [
      { id: `act_${Date.now()}`, ts: Date.now(), level: 'good', text: `Бот вошёл в игру как ${this.accounts.find((a) => a.id === profile.accountId)?.name ?? 'AxiomBot'}`, taskKind: undefined },
      { id: `act_${Date.now() + 1}`, ts: Date.now(), level: 'info', text: `Подключение к ${profile.host}:${profile.port} (${profile.version})` },
    ];
    rt.inventory = this.randInventory();
    rt.throughput = Array.from({ length: 24 }, () => Math.floor(Math.random() * 30) + 8);
    this.emit({ type: 'runtime', payload: rt });
    if (!silent) this.log('info', 'bot', `[${profile.name}] Подключение к ${profile.host}:${profile.port}`);

    setTimeout(() => {
      if (rt.status !== 'connecting') return;
      rt.status = 'online';
      rt.statusText = 'В игре';
      rt.taskQueue = rt.taskQueue.map((q, i) => ({ ...q, state: i === 0 ? 'active' : 'pending' }));
      this.emit({ type: 'runtime', payload: rt });
      this.log('success', 'bot', `[${profile.name}] Бот вошёл в игру как ${this.accounts.find((a) => a.id === profile.accountId)?.name ?? 'AxiomBot'}`);
    }, silent ? 300 : 2400);

    const timer = setInterval(() => this.tick(id), 1100);
    this.timers.set(id, timer);
  }

  private randInventory() {
    const count = 12 + Math.floor(Math.random() * 12);
    return Array.from({ length: count }, (_, i) => {
      const [name, displayName, tint] = ITEMS[Math.floor(Math.random() * ITEMS.length)];
      return { name, displayName, count: 1 + Math.floor(Math.random() * 64), slot: i, tint };
    });
  }

  private tick(id: string) {
    const profile = this.bots.find((b) => b.id === id);
    const rt = this.runtimes.get(id);
    if (!profile || !rt || rt.status === 'offline' || rt.status === 'paused') return;

    const active = profile.tasks.find((t) => t.enabled);
    const mining = profile.tasks.some((t) => t.enabled && t.kind === 'mine');
    const farming = profile.tasks.some((t) => t.enabled && t.kind === 'farm');
    const brewing = profile.tasks.some((t) => t.enabled && t.kind === 'brew');
    const fishing = profile.tasks.some((t) => t.enabled && t.kind === 'fish');

    if (mining) {
      const got = Math.floor(Math.random() * 5) + 1;
      rt.stats.blocksMined += got;
      if (Math.random() < 0.18) {
        const ore = ['diamond_ore', 'deepslate_diamond_ore', 'iron_ore', 'gold_ore', 'coal_ore', 'redstone_ore', 'ancient_debris'][Math.floor(Math.random() * 7)];
        rt.stats.oresFound[ore] = (rt.stats.oresFound[ore] ?? 0) + 1;
      }
    }
    if (farming) rt.stats.blocksMined += Math.floor(Math.random() * 3);
    if (brewing && Math.random() < 0.1) {
      rt.stats.brewsMade += 3;
      rt.stats.itemsCollected += 3;
    }
    if (fishing && Math.random() < 0.14) {
      rt.stats.fishCaught += 1;
      rt.stats.itemsCollected += 1;
    }
    rt.stats.itemsCollected += Math.floor(Math.random() * 3);
    rt.stats.distance += Math.random() * 4;
    rt.stats.sessionMs += 1100;
    rt.uptimeMs = rt.stats.sessionMs;

    rt.position = {
      x: +(rt.position.x + (Math.random() - 0.5) * 3).toFixed(1),
      y: +(rt.position.y + (Math.random() - 0.45) * 1.2).toFixed(1),
      z: +(rt.position.z + (Math.random() - 0.5) * 3).toFixed(1),
    };
    rt.health = Math.max(4, Math.min(20, rt.health + (Math.random() < 0.1 ? -1 : Math.random() < 0.3 ? 1 : 0)));
    rt.food = Math.max(3, Math.min(20, rt.food + (Math.random() < 0.25 ? -1 : Math.random() < 0.3 ? 1 : 0)));
    rt.ping = Math.max(12, Math.round(rt.ping + (Math.random() - 0.5) * 14));

    if (Math.random() < 0.16) {
      const [text, level] = ACTIVITY_TEMPLATES[Math.floor(Math.random() * ACTIVITY_TEMPLATES.length)];
      rt.activity = [{ id: `act_${Date.now()}_${Math.random()}`, ts: Date.now(), level: level as never, text: `${active?.name ?? 'Задача'}: ${text.split(': ').slice(1).join(': ') || text}` }, ...rt.activity].slice(0, 80);
      this.log(level === 'good' ? 'success' : (level as LogEntry['level']) === 'warn' ? 'warn' : 'info', 'bot', `[${profile.name}] ${text}`);
    }

    if (Math.random() < 0.12) rt.inventory = this.randInventory();
    if (Math.random() < 0.06) {
      rt.throughput = [...rt.throughput.slice(-39), Math.floor(Math.random() * 32) + 6];
    }
    if (rt.taskQueue.length) {
      const idx = rt.taskQueue.findIndex((q) => q.state === 'active');
      if (idx >= 0) {
        rt.taskQueue[idx].progress = Math.min(100, rt.taskQueue[idx].progress + Math.random() * 12);
        if (rt.taskQueue[idx].progress >= 100) rt.taskQueue[idx].progress = 0;
      }
    }
    // редкие события в общем логе
    if (Math.random() < 0.05) {
      const lines = [
        ['info', 'game', '[Render thread/INFO]: Time elapsed: 4120 ms'],
        ['info', 'network', 'Modrinth: каталог синхронизирован'],
        ['debug', 'launcher', 'Проверка целостности библиотек: всё на месте'],
      ] as const;
      const [level, source, message] = lines[Math.floor(Math.random() * lines.length)];
      this.log(level, source, message);
    }
    this.emit({ type: 'runtime', payload: rt });
  }

  private stopBot(id: string) {
    const timer = this.timers.get(id);
    if (timer) clearInterval(timer);
    this.timers.delete(id);
    const rt = this.rt(id);
    rt.status = 'offline';
    rt.statusText = 'Остановлен';
    rt.currentTaskId = undefined;
    this.emit({ type: 'runtime', payload: rt });
  }

  private log(level: LogEntry['level'], source: LogEntry['source'], message: string) {
    this.emit({ type: 'log', payload: { id: `log_${++this.seq}_${Math.random().toString(36).slice(2, 6)}`, ts: Date.now(), level, source, message } });
  }

  /* ─────────────── Контракт моста ─────────────── */

  async invoke(channel: string, payload?: any): Promise<any> {
    switch (channel) {
      case 'axiom:bootstrap':
        return {
          settings: this.settings,
          instances: this.instances,
          accounts: this.accounts,
          bots: this.bots,
          versions: MOCK_VERSIONS.map((v) => ({ ...v, installed: this.instances.some((i) => i.versionId === v.id) || v.installed })),
          javaDetected: [
            { path: '/usr/lib/jvm/temurin-21/bin/java', version: '21.0.4', major: 21, vendor: 'Temurin' },
            { path: '/usr/lib/jvm/java-17-openjdk/bin/java', version: '17.0.11', major: 17, vendor: 'OpenJDK' },
          ],
          platform: 'linux',
          version: '1.0.0',
          electron: false,
        };
      case 'axiom:task-catalog':
        return null;
      case 'axiom:versions:list':
        return MOCK_VERSIONS.map((v) => ({ ...v, installed: v.installed || Math.random() < 0 }));
      case 'axiom:versions:loader-options':
        return paddingLoaderOptions(payload?.loader);
      case 'axiom:versions:install': {
        const versionId = payload?.versionId as string;
        await this.simulateInstall(versionId);
        return { ok: true };
      }
      case 'axiom:java:detect':
        return [
          { path: '/usr/lib/jvm/temurin-21/bin/java', version: '21.0.4', major: 21, vendor: 'Temurin' },
          { path: '/usr/lib/jvm/java-17-openjdk/bin/java', version: '17.0.11', major: 17, vendor: 'OpenJDK' },
        ];
      case 'axiom:instances:list':
        return this.instances;
      case 'axiom:instances:create': {
        const inst: Instance = {
          id: `inst_${Math.random().toString(36).slice(2, 8)}`,
          name: payload?.name ?? 'Новая сборка',
          versionId: payload?.versionId ?? '1.21.4',
          loader: payload?.loader ?? 'vanilla',
          loaderVersion: payload?.loaderVersion,
          ramMb: payload?.ramMb ?? 4096,
          minRamMb: 512,
          jvmArgs: '',
          gameArgs: '',
          createdAt: Date.now(),
          playtimeMs: 0,
          accent: payload?.accent ?? 'violet',
          icon: payload?.icon ?? 'Package',
          installed: true,
        };
        this.instances = [...this.instances, inst];
        this.emit({ type: 'instances', payload: this.instances });
        this.log('success', 'launcher', `Создана сборка «${inst.name}» (${inst.versionId}${inst.loader !== 'vanilla' ? ` + ${inst.loader}` : ''})`);
        return this.instances;
      }
      case 'axiom:instances:update': {
        this.instances = this.instances.map((i) => (i.id === payload.id ? { ...i, ...payload.partial } : i));
        this.emit({ type: 'instances', payload: this.instances });
        return this.instances;
      }
      case 'axiom:instances:remove': {
        this.instances = this.instances.filter((i) => i.id !== payload.id);
        this.emit({ type: 'instances', payload: this.instances });
        return this.instances;
      }
      case 'axiom:instances:launch': {
        const inst = this.instances.find((i) => i.id === payload?.id);
        if (!inst) return { ok: false, error: 'Сборка не найдена' };
        this.emit({ type: 'launch-state', payload: { state: 'preparing', instanceId: inst.id } });
        await this.runLaunchSimulation(inst);
        return { ok: true, version: inst.versionId, classpath: 84, java: '/usr/lib/jvm/temurin-21/bin/java' };
      }
      case 'axiom:instances:kill':
        this.emit({ type: 'launch-state', payload: { state: 'exited', instanceId: payload?.id, code: 0 } });
        return true;
      case 'axiom:mods:list':
        return this.installedMods;
      case 'axiom:mods:toggle': {
        this.installedMods = this.installedMods.map((m) => (m.fileName === payload.fileName ? { ...m, enabled: !m.enabled } : m));
        return { enabled: this.installedMods.find((m) => m.fileName === payload.fileName)?.enabled ?? false, mods: this.installedMods };
      }
      case 'axiom:mods:remove': {
        this.installedMods = this.installedMods.filter((m) => m.fileName !== payload.fileName);
        this.log('warn', 'installer', `Удалён файл ${payload.fileName}`);
        return this.installedMods;
      }
      case 'axiom:modrinth:search': {
        const { query, projectType, loader, sort, limit } = payload ?? {};
        let items = MOCK_MODS.filter((m) => (!projectType || projectType === 'all' ? true : m.projectType === projectType));
        if (loader && loader !== 'any') items = items.filter((m) => m.loaders.includes(loader));
        if (query) {
          const q = String(query).toLowerCase();
          items = items.filter((m) => `${m.title} ${m.description} ${m.author} ${m.categories.join(' ')}`.toLowerCase().includes(q));
        }
        if (sort === 'downloads') items = [...items].sort((a, b) => b.downloads - a.downloads);
        if (sort === 'newest') items = [...items].sort((a, b) => +new Date(b.updated) - +new Date(a.updated));
        return items.slice(0, limit ?? 24);
      }
      case 'axiom:modrinth:install': {
        const project = payload.project as ModSearchResult;
        const mod = {
          fileName: `${project.slug}-${Date.now() % 1000}.jar`,
          title: project.title,
          projectId: project.id,
          version: 'последняя',
          sizeBytes: 1_200_000 + Math.random() * 3_000_000,
          installedAt: Date.now(),
          type: project.projectType,
          enabled: true,
          iconUrl: project.iconUrl,
        };
        this.installedMods = [mod, ...this.installedMods];
        this.log('success', 'installer', `Установлен «${project.title}» → mods/`);
        this.emit({ type: 'toast', payload: { kind: 'good', title: `Установлено: ${project.title}`, text: 'Файл загружен в сборку' } });
        return { ok: true, mod };
      }
      case 'axiom:accounts:list':
        return this.accounts;
      case 'axiom:accounts:add-offline': {
        const name = String(payload?.name ?? 'Player').slice(0, 16);
        const acc: Account = { id: `acc_${Math.random().toString(36).slice(2, 8)}`, type: 'offline', name, uuid: crypto.randomUUID?.() ?? name, addedAt: Date.now(), avatar: `https://minotar.net/helm/${name}/96.png`, valid: true };
        this.accounts = [...this.accounts, acc];
        this.emit({ type: 'accounts', payload: this.accounts });
        this.emit({ type: 'toast', payload: { kind: 'good', title: `Офлайн-аккаунт «${name}» добавлен` } });
        return acc;
      }
      case 'axiom:accounts:remove': {
        this.accounts = this.accounts.filter((a) => a.id !== payload.id);
        this.emit({ type: 'accounts', payload: this.accounts });
        return this.accounts;
      }
      case 'axiom:accounts:login-microsoft': {
        const code = `${Math.floor(Math.random() * 9000000 + 1000000)}`;
        this.emit({ type: 'msa-code', payload: { accountId: payload.username, code, url: 'https://www.microsoft.com/link', expiresIn: 900 } });
        await new Promise((r) => setTimeout(r, 2600));
        const acc: Account = {
          id: `acc_${Math.random().toString(36).slice(2, 8)}`,
          type: 'microsoft',
          name: payload.username || 'AxiomPlayer',
          uuid: '069a79f444e94726a5befca90e38aaf5',
          addedAt: Date.now(),
          lastUsed: Date.now(),
          avatar: 'https://crafatar.com/avatars/069a79f444e94726a5befca90e38aaf5?size=96&overlay',
          valid: true,
        };
        this.accounts = [...this.accounts.filter((a) => a.name !== acc.name), acc];
        this.emit({ type: 'accounts', payload: this.accounts });
        this.log('success', 'network', `Аккаунт Minecraft «${acc.name}» авторизован`);
        return { ok: true, account: acc };
      }
      case 'axiom:bots:list':
        return this.bots;
      case 'axiom:bots:create': {
        const profile: BotProfile = {
          id: `bot_${Math.random().toString(36).slice(2, 8)}`,
          name: payload?.name ?? 'AXIOM-бот',
          host: payload?.host ?? 'localhost',
          port: payload?.port ?? 25565,
          version: payload?.version ?? '1.20.1',
          accountId: payload?.accountId ?? this.accounts[0]?.id ?? '',
          autoReconnect: true,
          antiAfk: true,
          autoEat: true,
          tasks: [
            { id: `task_${Date.now()}`, kind: 'mine', name: 'Автошахта', enabled: true, options: { mode: 'ores', radius: 48 } },
            { id: `task_${Date.now() + 1}`, kind: 'stash', name: 'Автосклад', enabled: false, options: { keep: 'sword,pickaxe,food', radius: 24 } },
            { id: `task_${Date.now() + 2}`, kind: 'afk', name: 'Анти-AFK', enabled: true, options: {} },
          ],
          createdAt: Date.now(),
          totalRuntimeMs: 0,
          stats: { blocksMined: 0, oresFound: {}, itemsCollected: 0, brewsMade: 0, fishCaught: 0, deaths: 0, distance: 0, sessionMs: 0 },
        };
        this.bots = [...this.bots, profile];
        this.emit({ type: 'bots', payload: this.bots });
        return profile;
      }
      case 'axiom:bots:update': {
        this.bots = this.bots.map((b) => (b.id === payload.id ? { ...b, ...payload.partial } : b));
        this.emit({ type: 'bots', payload: this.bots });
        return this.bots.find((b) => b.id === payload.id);
      }
      case 'axiom:bots:remove': {
        this.stopBot(payload.id);
        this.bots = this.bots.filter((b) => b.id !== payload.id);
        this.emit({ type: 'bots', payload: this.bots });
        return this.bots;
      }
      case 'axiom:bots:start':
        this.startBot(payload.id);
        return true;
      case 'axiom:bots:stop':
        this.stopBot(payload.id);
        return true;
      case 'axiom:bots:pause': {
        const rt = this.rt(payload.id);
        rt.status = 'paused';
        rt.statusText = 'Задачи приостановлены';
        this.emit({ type: 'runtime', payload: rt });
        return true;
      }
      case 'axiom:bots:resume': {
        const rt = this.rt(payload.id);
        rt.status = 'online';
        rt.statusText = 'В игре';
        this.emit({ type: 'runtime', payload: rt });
        return true;
      }
      case 'axiom:bots:tasks': {
        this.bots = this.bots.map((b) => (b.id === payload.id ? { ...b, tasks: payload.tasks as TaskDef[] } : b));
        const rt = this.rt(payload.id);
        rt.taskQueue = (payload.tasks as TaskDef[]).filter((t) => t.enabled).map((t, i) => ({ id: t.id, name: t.name, kind: t.kind, progress: 0, state: i === 0 ? 'active' : 'pending' }));
        this.emit({ type: 'bots', payload: this.bots });
        this.emit({ type: 'runtime', payload: rt });
        return this.bots;
      }
      case 'axiom:logs:history':
        return this.logs;
      case 'axiom:settings:set':
        this.settings = { ...this.settings, ...payload };
        return this.settings;
      case 'axiom:system:info':
        return { platform: 'linux', version: '1.0.0', electron: 'демо', node: 'демо', userData: '~/.config/AXIOM', installedVersions: ['1.21.4', '1.21.1', '1.20.1', '1.12.2'], totalMemoryMb: 32768 };
      case 'axiom:system:open-path':
      case 'axiom:system:open-external':
      case 'axiom:system:pick-folder':
        this.emit({ type: 'toast', payload: { kind: 'info', title: 'Демо-режим', text: 'В браузере системные действия недоступны — запустите Electron-версию' } });
        return null;
      case 'axiom:app:quit':
        return null;
      case 'axiom:window:minimize':
      case 'axiom:window:maximize':
      case 'axiom:window:close':
      case 'axiom:window:is-maximized':
        return false;
      default:
        return null;
    }
  }

  private async simulateInstall(versionId: string) {
    const taskId = `install_${versionId}`;
    const stages: [DownloadProgress['stage'], string, number][] = [
      ['prepare', 'Подготовка профиля версии', 0.05],
      ['client', 'Клиент', 0.2],
      ['libraries', 'Библиотеки', 0.5],
      ['natives', 'Нативные библиотеки', 0.62],
      ['assets', 'Ресурсы игры', 0.95],
      ['done', 'Готово', 1],
    ];
    const total = 380 * 1024 * 1024;
    for (const [stage, label, part] of stages) {
      const steps = 8;
      for (let i = 0; i < steps; i++) {
        const progress = part - (1 - (i + 1) / steps) * 0.12;
        this.emit({
          type: 'progress',
          payload: {
            taskId,
            label: `${label} ${versionId}`,
            stage,
            current: Math.round(progress * 1000),
            total: 1000,
            bytesDone: total * progress,
            bytesTotal: total,
            speed: 4_200_000 + Math.random() * 6_000_000,
          },
        });
        await new Promise((r) => setTimeout(r, 120));
      }
    }
    this.log('success', 'installer', `Версия ${versionId} установлена`);
    this.emit({ type: 'toast', payload: { kind: 'good', title: `${versionId} установлена`, text: 'Можно запускать' } });
  }

  private async runLaunchSimulation(inst: Instance) {
    const taskId = `launch_${inst.id}`;
    const lines = [
      'Проверка целостности библиотек…',
      'Обновление ресурсов игры…',
      `Сборка команды запуска (${inst.loader === 'vanilla' ? 'vanilla' : inst.loader})…`,
      `Выделено ${inst.ramMb} МБ ОЗУ, Java 21 (Temurin)`,
    ];
    for (let i = 0; i < lines.length; i++) {
      this.emit({ type: 'progress', payload: { taskId, label: lines[i], stage: 'prepare', current: i + 1, total: lines.length * 2, bytesDone: 0, bytesTotal: 1, speed: 0 } });
      await new Promise((r) => setTimeout(r, 450));
    }
    this.log('info', 'launcher', `Запуск ${inst.name}: ${inst.versionId}${inst.loader !== 'vanilla' ? ` + ${inst.loader}` : ''}, ${inst.ramMb} МБ`);
    this.emit({ type: 'launch-state', payload: { state: 'running', instanceId: inst.id, pid: Math.floor(Math.random() * 30000) + 4000 } });
    this.log('info', 'game', '[main/INFO]: Launching target \'fabricclient\' with arguments …');
    setTimeout(() => this.log('info', 'game', '[Render thread/INFO]: Backend library: LWJGL version 3.3.3+5'), 500);
    setTimeout(() => this.log('success', 'game', 'Done (3.412s)! For help, type "help"'), 1800);
  }
}

function paddingLoaderOptions(loader?: string) {
  const versions = loader === 'forge'
    ? ['47.2.20', '47.2.18', '47.1.0']
    : loader === 'neoforge'
      ? ['21.4.10-beta', '21.1.72']
      : loader === 'quilt'
        ? ['0.26.4', '0.26.0']
        : ['0.16.9', '0.16.5', '0.15.11', '0.14.25'];
  return versions.map((version, i) => ({ version, stable: i < 2 }));
}

export const mockBackend = new MockBackend();
