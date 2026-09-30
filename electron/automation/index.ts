/* ============================================================
   AXIOM Bot Manager — жизненный цикл mineflayer-ботов:
   подключение, автопереподключение, очередь задач, телеметрия.
   ============================================================ */

import { EventEmitter } from 'node:events';
import { JsonStore, uid } from '../services/store';
import { paths, ensureDir } from '../services/paths';
import { logger } from '../services/logger';
import { accounts } from '../services/accounts';
import { TASKS, load, sleepRaw, autoEat, type TaskContext } from './tasks';
import type { AxiomEvent, BotProfile, BotRuntime, BotStats, ItemStack, TaskDef, TaskKind } from '../../shared/types';

const nodeRequire: NodeRequire = require as NodeRequire;

function emptyStats(): BotStats {
  return { blocksMined: 0, oresFound: {}, itemsCollected: 0, brewsMade: 0, fishCaught: 0, deaths: 0, distance: 0, sessionMs: 0 };
}

function defaultProfileFields(): Omit<BotProfile, 'id' | 'name' | 'host' | 'port' | 'version' | 'accountId'> {
  return {
    autoReconnect: true,
    antiAfk: true,
    autoEat: true,
    tasks: [
      { id: uid('task'), kind: 'mine', name: 'Автошахта', enabled: true, options: { mode: 'ores', radius: 48 } },
      { id: uid('task'), kind: 'stash', name: 'Автосклад', enabled: false, options: { keep: 'sword,pickaxe,food,coal', radius: 24 } },
      { id: uid('task'), kind: 'afk', name: 'Анти-AFK', enabled: true, options: {} },
    ],
    createdAt: Date.now(),
    totalRuntimeMs: 0,
    stats: emptyStats(),
  };
}

export function createDefaultProfile(partial: Partial<BotProfile>): BotProfile {
  return {
    id: uid('bot'),
    name: partial.name ?? 'AXIOM-бот',
    host: partial.host ?? 'localhost',
    port: partial.port ?? 25565,
    version: partial.version ?? '1.20.1',
    accountId: partial.accountId ?? '',
    ...defaultProfileFields(),
    ...partial,
    stats: { ...emptyStats(), ...(partial.stats ?? {}) },
  };
}

const ORE_TINT: Record<string, string> = {
  diamond: '#5eead4',
  emerald: '#6ee7b7',
  gold: '#fbbf24',
  iron: '#e2e8f0',
  copper: '#fb923c',
  coal: '#64748b',
  redstone: '#f87171',
  lapis: '#60a5fa',
  quartz: '#f1f5f9',
  debris: '#a855f7',
};

function tintFor(itemName: string): string {
  for (const [key, color] of Object.entries(ORE_TINT)) if (itemName.includes(key)) return color;
  if (/(sword|axe|pickaxe|shovel|hoe|helmet|chestplate|leggings|boots)/.test(itemName)) return '#93c5fd';
  if (/(potion|brewing|wart|blaze|ghast|melon)/.test(itemName)) return '#f472b6';
  if (/(apple|bread|beef|cooked|carrot|potato|wheat|fish|cod|salmon)/.test(itemName)) return '#fcd34d';
  if (/(log|planks|wood|sapling|leaves)/.test(itemName)) return '#a16207';
  if (/(stone|cobble|deepslate|gravel|dirt|sand)/.test(itemName)) return '#94a3b8';
  return '#cbd5e1';
}

class BotSession {
  bot: any = null;
  profile: BotProfile;
  runtime: BotRuntime;
  private tasks: TaskDef[];
  private queue: BotRuntime['taskQueue'] = [];
  private running = false;
  private stopped = false;
  private paused = false;
  private currentIndex = 0;
  private cancelToken = false;
  private lastEmit = 0;
  private sessionStart = 0;
  private positionSamples: { t: number; d: number }[] = [];
  private lastPos: any = null;
  private throughputSamples: number[] = [];
  private lastThroughputBase = 0;
  private lastThroughputAt = Date.now();
  private reconnectTimer: NodeJS.Timeout | null = null;
  private reconnectAttempts = 0;

  constructor(
    profile: BotProfile,
    private onEvent: (e: AxiomEvent) => void,
    private persist: (p: BotProfile) => void,
  ) {
    this.profile = profile;
    this.tasks = profile.tasks.map((t) => ({ ...t, options: { ...t.options } }));
    this.runtime = {
      profileId: profile.id,
      status: 'offline',
      statusText: 'Не подключён',
      position: { x: 0, y: 0, z: 0 },
      dimension: 'overworld',
      health: 20,
      food: 20,
      ping: 0,
      uptimeMs: 0,
      taskQueue: [],
      stats: { ...emptyStats(), ...profile.stats },
      inventory: [],
      activity: [],
      throughput: [],
      nearbyPlayers: [],
    };
    this.buildQueue();
  }

  /* ─────────── Журнал активности бота ─────────── */
  private activity(text: string, level: BotRuntime['activity'][number]['level'] = 'info', kind?: TaskKind) {
    this.runtime.activity = [
      { id: uid('act'), ts: Date.now(), level, text, taskKind: kind },
      ...this.runtime.activity,
    ].slice(0, 120);
    const logLevel = level === 'bad' ? 'error' : level === 'warn' ? 'warn' : level === 'good' ? 'success' : 'info';
    logger.log(logLevel as never, 'bot', `[${this.profile.name}] ${text}`);
    this.emit(true);
  }

  private emit(force = false) {
    const now = Date.now();
    if (!force && now - this.lastEmit < 700) return;
    this.lastEmit = now;
    this.runtime.stats.sessionMs = this.sessionStart ? Date.now() - this.sessionStart : 0;
    this.runtime.uptimeMs = this.runtime.stats.sessionMs;
    this.emitSnapshot();
  }

  private emitSnapshot() {
    this.onEvent({ type: 'runtime', payload: { ...this.runtime, taskQueue: [...this.queue] } });
  }

  private buildQueue() {
    this.queue = this.tasks
      .filter((t) => t.enabled)
      .map((t) => ({ id: t.id, name: t.name, kind: t.kind, progress: 0, state: 'pending' as const }));
    this.runtime.taskQueue = [...this.queue];
  }

  /* ─────────── Подключение ─────────── */
  async connect() {
    if (this.bot || this.stopped) return;
    this.runtime.status = 'connecting';
    this.runtime.statusText = `Подключаюсь к ${this.profile.host}:${this.profile.port}…`;
    this.activity(`Подключение к ${this.profile.host}:${this.profile.port} (${this.profile.version})`, 'info');

    const account = accounts.get(this.profile.accountId);
    const mineflayer = nodeRequire('mineflayer');
    const { pathfinder, Movements } = nodeRequire('mineflayer-pathfinder');

    const options: any = {
      host: this.profile.host,
      port: Number(this.profile.port) || 25565,
      username: account?.name ?? this.profile.name,
      version: this.profile.version || undefined,
      auth: account?.type === 'microsoft' ? 'microsoft' : 'offline',
      hideErrors: false,
      checkTimeoutInterval: 60000,
      chat: 'enabled',
    };
    if (account?.type === 'microsoft') {
      options.profilesFolder = ensureDir(account.cacheDir ?? paths.accountCache(account.name));
      options.onMsaCode = (code: any) => {
        this.activity(`Microsoft просит код ${code.user_code} — введите на ${code.verification_uri}`, 'warn');
      };
    }

    try {
      const bot = mineflayer.createBot(options);
      this.bot = bot;
      bot.loadPlugin(pathfinder);

      bot.once('spawn', () => {
        this.runtime.status = 'online';
        this.runtime.statusText = 'В игре';
        this.sessionStart = Date.now();
        this.reconnectAttempts = 0;
        this.activity(`Бот вошёл в игру как ${account?.name ?? this.profile.name}`, 'good');
        try {
          const movements = new Movements(bot);
          movements.canDig = true;
          movements.allow1by1towers = false;
          movements.allowParkour = false;
          bot.pathfinder.setMovements(movements);
        } catch {
          /* дефолтные настройки пути */
        }
        this.startTasks();
      });

      bot.on('kicked', (reason: unknown) => {
        this.activity(`Кикнут: ${typeof reason === 'string' ? reason : JSON.stringify(reason).slice(0, 300)}`, 'bad');
      });
      bot.on('error', (err: Error) => {
        this.activity(`Ошибка соединения: ${err.message}`, 'bad');
        this.runtime.status = 'error';
        this.runtime.statusText = err.message;
        this.emit(true);
      });
      bot.on('end', (reason: string) => {
        this.activity(`Соединение закрыто (${reason})`, 'warn');
        this.runtime.status = 'offline';
        this.runtime.statusText = `Отключён: ${reason}`;
        this.bot = null;
        this.running = false;
        this.emit(true);
        if (!this.stopped && this.profile.autoReconnect) this.scheduleReconnect();
      });
      bot.on('death', () => {
        this.runtime.stats.deaths++;
        this.activity('Бот погиб — возрождаюсь и продолжаю работу', 'bad');
      });
      bot.on('health', () => {
        this.runtime.health = bot.health;
        this.runtime.food = bot.food;
      });
      bot.on('playerJoined', (p: any) => this.activity(`В игру зашёл ${p.username}`, 'info'));
      bot.on('playerLeft', (p: any) => this.activity(`${p.username} вышел`, 'info'));
      bot.on('messagestr', (msg: string) => {
        if (/^\s*$/.test(msg)) return;
        this.activity(`Чат: ${msg.slice(0, 160)}`, 'info');
      });
      bot.on('whisper', (username: string, message: string) => {
        this.activity(`ЛС от ${username}: ${message.slice(0, 120)}`, 'info');
      });

      /* Телеметрия: позиция, инвентарь, метрики, дистанция */
      const telemetry = setInterval(() => {
        if (!this.bot || this.stopped) return;
        const b = this.bot;
        try {
          if (b.entity?.position) {
            const p = b.entity.position;
            if (this.lastPos) {
              this.runtime.stats.distance += p.distanceTo(this.lastPos);
            }
            this.lastPos = p.clone();
            this.runtime.position = { x: +p.x.toFixed(1), y: +p.y.toFixed(1), z: +p.z.toFixed(1) };
          }
          this.runtime.health = Math.round(b.health ?? 20);
          this.runtime.food = Math.round(b.food ?? 20);
          this.runtime.ping = b.player?.ping ?? 0;
          this.runtime.dimension = b.game?.dimension ?? 'overworld';
          this.runtime.nearbyPlayers = Object.values(b.players ?? {})
            .filter((pl: any) => pl.username !== b.username)
            .slice(0, 8)
            .map((pl: any) => pl.username);
          this.runtime.inventory = this.readInventory(b);
          const minedNow = this.runtime.stats.blocksMined;
          if (Date.now() - this.lastThroughputAt > 15000) {
            const delta = minedNow - this.lastThroughputBase;
            this.throughputSamples = [...this.throughputSamples, delta].slice(-40);
            this.runtime.throughput = this.throughputSamples;
            this.lastThroughputBase = minedNow;
            this.lastThroughputAt = Date.now();
          }
        } catch {
          /* бот может быть в переходном состоянии */
        }
        this.emit();
      }, 1200);
      bot.once('end', () => clearInterval(telemetry));

      /* Авто-еда как фоновая страховка */
      const eatLoop = setInterval(async () => {
        if (!this.bot || this.stopped) return;
        if (this.profile.autoEat) await autoEat(this.bot);
      }, 5000);
      bot.once('end', () => clearInterval(eatLoop));
    } catch (e) {
      this.runtime.status = 'error';
      this.runtime.statusText = (e as Error).message;
      this.activity(`Не удалось создать бота: ${(e as Error).message}`, 'bad');
    }
  }

  private scheduleReconnect() {
    if (this.reconnectTimer) return;
    this.reconnectAttempts++;
    const delay = Math.min(30000, 3000 * this.reconnectAttempts);
    this.runtime.statusText = `Переподключение через ${Math.round(delay / 1000)} с…`;
    this.emit(true);
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      if (!this.stopped) void this.connect();
    }, delay);
  }

  private readInventory(bot: any): ItemStack[] {
    try {
      const items = bot.inventory.items() as any[];
      let mcData: any = null;
      try {
        mcData = load('minecraft-data')(bot.version);
      } catch {
        /* данных нет */
      }
      return items.slice(0, 36).map((i) => ({
        name: i.name,
        displayName: mcData?.items?.[i.type]?.displayName ?? i.displayName ?? i.name,
        count: i.count,
        slot: i.slot,
        tint: tintFor(i.name),
      }));
    } catch {
      return [];
    }
  }

  /* ─────────── Очередь задач ─────────── */
  private async startTasks() {
    if (this.running || !this.bot) return;
    this.running = true;
    this.buildQueue();
    this.currentIndex = 0;
    void this.runLoop();
  }

  private async runLoop() {
    while (this.running && !this.cancelToken && this.bot) {
      const tasks = this.tasks.filter((t) => t.enabled);
      if (!tasks.length) {
        this.runtime.currentTaskText = 'Задачи не выбраны — включите хотя бы одну в панели автоматизации';
        this.runtime.status = 'paused';
        await sleepRaw(2000);
        continue;
      }
      if (this.paused) {
        await sleepRaw(500);
        continue;
      }
      const def = tasks[this.currentIndex % tasks.length];
      this.currentIndex++;
      const task = TASKS[def.kind];
      if (!task) continue;

      const qIndex = this.queue.findIndex((q) => q.id === def.id);
      if (qIndex >= 0) this.queue[qIndex] = { ...this.queue[qIndex], state: 'active', progress: 0 };
      this.runtime.currentTaskId = def.id;
      this.runtime.currentTaskText = `${def.name}: запуск`;
      this.runtime.status = 'online';
      this.emit(true);

      const ctx: TaskContext = {
        bot: this.bot,
        options: def.options,
        stats: this.runtime.stats,
        log: (text, level = 'info') => this.activity(`${def.name}: ${text}`, level, def.kind),
        progress: (value, text) => {
          if (qIndex >= 0) this.queue[qIndex] = { ...this.queue[qIndex], progress: Math.max(0, Math.min(100, value)) };
          if (text) this.runtime.currentTaskText = `${def.name}: ${text}`;
          this.emit();
        },
        cancelled: () => this.cancelToken || !this.running || !this.bot,
        waitWhilePaused: async () => {
          while (this.paused && this.running && !this.cancelToken) await sleepRaw(400);
        },
        sleep: async (ms: number) => {
          const step = 250;
          let waited = 0;
          while (waited < ms) {
            if (this.cancelToken || !this.running || !this.bot) return false;
            await sleepRaw(Math.min(step, ms - waited));
            waited += step;
          }
          return true;
        },
      };

      try {
        await task.run(ctx);
        if (qIndex >= 0) this.queue[qIndex] = { ...this.queue[qIndex], state: 'done', progress: 100 };
      } catch (e) {
        if (qIndex >= 0) this.queue[qIndex] = { ...this.queue[qIndex], state: 'failed', progress: 0 };
        this.activity(`${def.name}: ошибка — ${(e as Error).message}`, 'bad', def.kind);
        await sleepRaw(1500);
      }
      this.runtime.currentTaskId = undefined;
      this.emit(true);
    }
  }

  pause() {
    this.paused = true;
    this.runtime.status = 'paused';
    this.runtime.statusText = 'Задачи приостановлены';
    this.activity('Выполнение задач приостановлено', 'warn');
    this.emit(true);
  }

  resume() {
    this.paused = false;
    this.runtime.status = this.bot ? 'online' : 'offline';
    this.runtime.statusText = this.bot ? 'В игре' : 'Не подключён';
    this.activity('Задачи возобновлены', 'good');
    this.emit(true);
  }

  updateTasks(tasks: TaskDef[]) {
    this.tasks = tasks;
    this.profile.tasks = tasks;
    this.persist(this.profile);
    this.buildQueue();
    this.currentIndex = 0;
    this.activity('Список задач обновлён', 'info');
    this.emit(true);
  }

  updateProfile(partial: Partial<BotProfile>) {
    this.profile = { ...this.profile, ...partial };
    if (partial.tasks) this.tasks = partial.tasks;
    this.persist(this.profile);
    this.buildQueue();
    this.emit(true);
  }

  async disconnect() {
    this.cancelToken = true;
    this.running = false;
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.profile.totalRuntimeMs !== undefined && this.sessionStart) {
      this.profile.totalRuntimeMs += Date.now() - this.sessionStart;
      this.profile.stats = this.runtime.stats;
      this.profile.lastRunAt = Date.now();
      this.persist(this.profile);
    }
    try {
      this.bot?.quit('AXIOM: остановка бота');
    } catch {
      /* уже отключён */
    }
    this.bot = null;
    this.sessionStart = 0;
    this.runtime.status = 'offline';
    this.runtime.statusText = 'Остановлен';
    this.runtime.currentTaskText = undefined;
    this.activity('Бот остановлен', 'warn');
    this.emit(true);
  }
}

export class BotManager extends EventEmitter {
  private store: JsonStore<{ bots: BotProfile[] }>;
  private sessions = new Map<string, BotSession>();
  constructor(private onEvent: (e: AxiomEvent) => void) {
    super();
    this.store = new JsonStore(paths.botsFile, { bots: [] });
  }

  list(): BotProfile[] {
    return this.store.get().bots;
  }

  get(id: string) {
    return this.list().find((b) => b.id === id);
  }

  save(profile: BotProfile) {
    const bots = this.list();
    const idx = bots.findIndex((b) => b.id === profile.id);
    if (idx >= 0) bots[idx] = profile;
    else bots.push(profile);
    this.store.set({ bots });
    this.onEvent({ type: 'bots', payload: bots });
    return profile;
  }

  remove(id: string) {
    void this.sessions.get(id)?.disconnect();
    this.sessions.delete(id);
    const bots = this.list().filter((b) => b.id !== id);
    this.store.set({ bots });
    this.onEvent({ type: 'bots', payload: bots });
  }

  private session(id: string): BotSession | null {
    const profile = this.get(id);
    if (!profile) return null;
    let s = this.sessions.get(id);
    if (!s) {
      s = new BotSession(profile, this.onEvent, (p) => this.save(p));
      this.sessions.set(id, s);
    }
    return s;
  }

  async start(id: string) {
    const s = this.session(id);
    if (!s) return;
    s.profile.lastRunAt = Date.now();
    this.save(s.profile);
    await s.connect();
  }

  async stop(id: string) {
    await this.sessions.get(id)?.disconnect();
  }

  pause(id: string) {
    this.sessions.get(id)?.pause();
  }

  resume(id: string) {
    this.sessions.get(id)?.resume();
  }

  updateTasks(id: string, tasks: TaskDef[]) {
    const s = this.session(id);
    s?.updateTasks(tasks);
    const profile = this.get(id);
    if (profile) this.save({ ...profile, tasks });
  }

  updateProfile(id: string, partial: Partial<BotProfile>) {
    const profile = { ...(this.get(id) as BotProfile), ...partial };
    this.save(profile);
    this.sessions.get(id)?.updateProfile(partial);
    return profile;
  }

  runtimeOf(id: string): BotRuntime | null {
    return this.sessions.get(id)?.runtime ?? null;
  }

  runtimes(): BotRuntime[] {
    return [...this.sessions.values()].map((s) => s.runtime);
  }

  async stopAll() {
    await Promise.all([...this.sessions.values()].map((s) => s.disconnect()));
  }
}
