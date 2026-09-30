import { create } from 'zustand';
import { api, isElectron } from '@/lib/api';
import type {
  Account,
  AxiomEvent,
  BotProfile,
  BotRuntime,
  BootstrapState,
  DownloadProgress,
  Instance,
  InstalledMod,
  LogEntry,
  ModProjectType,
  ModSearchResult,
  Settings,
  TaskDef,
  VersionSummary,
} from '@shared/types';

export type View = 'play' | 'instances' | 'versions' | 'mods' | 'automation' | 'accounts' | 'console' | 'settings';

export interface Toast {
  id: string;
  kind: 'info' | 'good' | 'warn' | 'bad';
  title: string;
  text?: string;
}

interface ModSearchState {
  query: string;
  projectType: ModProjectType | 'all';
  loader: string;
  sort: 'relevance' | 'downloads' | 'newest';
  results: ModSearchResult[];
  loading: boolean;
}

interface State {
  ready: boolean;
  view: View;
  settings: Settings;
  instances: Instance[];
  accounts: Account[];
  bots: BotProfile[];
  versions: VersionSummary[];
  javaDetected: BootstrapState['javaDetected'];
  logs: LogEntry[];
  runtimes: Record<string, BotRuntime>;
  progress: Record<string, DownloadProgress>;
  installedMods: InstalledMod[];
  modSearch: ModSearchState;
  toasts: Toast[];
  launchState: { state: 'idle' | 'preparing' | 'running' | 'exited'; instanceId?: string; pid?: number; code?: number };
  selectedInstanceId: string | null;
  selectedBotId: string | null;
  msaCode: { code: string; url: string } | null;
  searchOpen: boolean;
  platform: string;
  version: string;
  systemInfo: { userData?: string; totalMemoryMb?: number; electron?: string; node?: string } | null;
  actions: Actions;
}

interface Actions {
  init: () => Promise<void>;
  setView: (v: View) => void;
  applyEvent: (e: AxiomEvent) => void;
  updateSettings: (partial: Partial<Settings>) => Promise<void>;
  installVersion: (versionId: string) => Promise<void>;
  launch: (instanceId: string, accountId?: string) => Promise<void>;
  kill: (instanceId: string) => Promise<void>;
  createInstance: (partial: Partial<Instance>) => Promise<void>;
  updateInstance: (id: string, partial: Partial<Instance>) => Promise<void>;
  removeInstance: (id: string, deleteFiles?: boolean) => Promise<void>;
  selectInstance: (id: string | null) => void;
  selectBot: (id: string | null) => void;
  loadMods: (instanceId: string) => Promise<void>;
  toggleMod: (instanceId: string, fileName: string) => Promise<void>;
  removeMod: (instanceId: string, fileName: string) => Promise<void>;
  searchMods: (partial?: Partial<ModSearchState>) => Promise<void>;
  installProject: (instanceId: string, project: ModSearchResult) => Promise<void>;
  addOfflineAccount: (name: string) => Promise<void>;
  loginMicrosoft: (username: string) => Promise<void>;
  removeAccount: (id: string) => Promise<void>;
  createBot: (partial: Partial<BotProfile>) => Promise<void>;
  updateBot: (id: string, partial: Partial<BotProfile>) => Promise<void>;
  removeBot: (id: string) => Promise<void>;
  startBot: (id: string) => Promise<void>;
  stopBot: (id: string) => Promise<void>;
  pauseBot: (id: string) => Promise<void>;
  resumeBot: (id: string) => Promise<void>;
  setBotTasks: (id: string, tasks: TaskDef[]) => Promise<void>;
  toast: (t: Omit<Toast, 'id'>) => void;
  dismissToast: (id: string) => void;
  setSearchOpen: (v: boolean) => void;
  clearConsole: () => void;
  loadSystemInfo: () => Promise<void>;
  openPath: (target: string) => Promise<void>;
  openExternal: (url: string) => Promise<void>;
  launchLoaderOptions: (mcVersion: string, loader: string) => Promise<{ version: string; stable: boolean }[]>;
}

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

export const ACCENTS: { id: Settings['accent']; label: string; from: string; to: string }[] = [
  { id: 'violet', label: 'Фиолет', from: '#8b5cf6', to: '#22d3ee' },
  { id: 'cyan', label: 'Циан', from: '#22d3ee', to: '#8b5cf6' },
  { id: 'emerald', label: 'Изумруд', from: '#34d399', to: '#a3e635' },
  { id: 'amber', label: 'Янтарь', from: '#fbbf24', to: '#fb7185' },
  { id: 'rose', label: 'Роза', from: '#fb7185', to: '#a78bfa' },
  { id: 'blue', label: 'Индиго', from: '#60a5fa', to: '#22d3ee' },
];

export const useStore = create<State>((set, get) => {
  const actions: Actions = {
    init: async () => {
      const boot = await api.invoke<BootstrapState>('axiom:bootstrap');
      set({
        ready: true,
        settings: boot.settings ?? defaultSettings,
        instances: boot.instances ?? [],
        accounts: boot.accounts ?? [],
        bots: boot.bots ?? [],
        versions: boot.versions ?? [],
        javaDetected: boot.javaDetected ?? [],
        platform: boot.platform,
        version: boot.version,
        selectedInstanceId: boot.instances?.[0]?.id ?? null,
        selectedBotId: boot.bots?.[0]?.id ?? null,
      });
      applyAccent(boot.settings?.accent ?? 'violet');
      const [logs] = await Promise.all([api.invoke<LogEntry[]>('axiom:logs:history')]);
      set({ logs: logs ?? [] });
      void actions.loadSystemInfo();
      // Версии подтягиваются в фоне — UI не блокируется
      api.invoke<VersionSummary[]>('axiom:versions:list').then((versions) => set({ versions })).catch(() => undefined);
      if (boot.instances?.[0]) void actions.loadMods(boot.instances[0].id);
    },

    setView: (v) => set({ view: v }),

    applyEvent: (e) => {
      switch (e.type) {
        case 'log':
          set((s) => ({ logs: [...s.logs, e.payload].slice(-1200) }));
          break;
        case 'progress': {
          const next = { ...get().progress, [e.payload.taskId]: e.payload };
          if (e.payload.stage === 'done' || e.payload.stage === 'error') {
            setTimeout(() => {
              const p = { ...get().progress };
              delete p[e.payload.taskId];
              set({ progress: p });
            }, 1600);
          }
          set({ progress: next });
          break;
        }
        case 'instances':
          set({ instances: e.payload });
          break;
        case 'accounts':
          set({ accounts: e.payload });
          break;
        case 'bots':
          set({ bots: e.payload });
          break;
        case 'runtime':
          set((s) => ({ runtimes: { ...s.runtimes, [e.payload.profileId]: e.payload } }));
          break;
        case 'launch-state':
          set({ launchState: e.payload });
          break;
        case 'msa-code':
          set({ msaCode: { code: e.payload.code, url: e.payload.url } });
          break;
        case 'toast':
          actions.toast(e.payload);
          break;
      }
    },

    updateSettings: async (partial) => {
      const next = await api.invoke<Settings>('axiom:settings:set', partial);
      set({ settings: next });
      if (partial.accent) applyAccent(partial.accent);
    },

    installVersion: async (versionId) => {
      const res = await api.invoke<{ ok: boolean }>('axiom:versions:install', { versionId });
      const versions = await api.invoke<VersionSummary[]>('axiom:versions:list');
      if (res?.ok) set({ versions: versions.map((v) => (v.id === versionId ? { ...v, installed: true } : v)) });
    },

    launch: async (instanceId, accountId) => {
      const inst = get().instances.find((i) => i.id === instanceId);
      set({ launchState: { state: 'preparing', instanceId } });
      const res = await api.invoke<{ ok: boolean; error?: string; version?: string; classpath?: number }>('axiom:instances:launch', { id: instanceId, accountId });
      if (!res?.ok) {
        set({ launchState: { state: 'idle' } });
        actions.toast({ kind: 'bad', title: 'Запуск не удался', text: res?.error });
      } else if (inst) {
        actions.toast({ kind: 'info', title: `${inst.name} запускается`, text: res.version ? `Профиль ${res.version} · ${res.classpath} библиотек` : undefined });
      }
    },

    kill: async (instanceId) => {
      await api.invoke('axiom:instances:kill', { id: instanceId });
      set({ launchState: { state: 'idle' } });
    },

    createInstance: async (partial) => {
      const instances = await api.invoke<Instance[]>('axiom:instances:create', partial);
      set({ instances, selectedInstanceId: instances[instances.length - 1]?.id ?? null });
    },

    updateInstance: async (id, partial) => {
      const instances = await api.invoke<Instance[]>('axiom:instances:update', { id, partial });
      set({ instances });
    },

    removeInstance: async (id, deleteFiles) => {
      const instances = await api.invoke<Instance[]>('axiom:instances:remove', { id, deleteFiles });
      set({ instances, selectedInstanceId: instances[0]?.id ?? null });
    },

    selectInstance: (id) => {
      set({ selectedInstanceId: id });
      if (id) void actions.loadMods(id);
    },

    selectBot: (id) => set({ selectedBotId: id }),

    loadMods: async (instanceId) => {
      const mods = await api.invoke<InstalledMod[]>('axiom:mods:list', { instanceId });
      set({ installedMods: mods ?? [] });
    },

    toggleMod: async (instanceId, fileName) => {
      const res = await api.invoke<{ mods: InstalledMod[] }>('axiom:mods:toggle', { instanceId, fileName });
      set({ installedMods: res?.mods ?? [] });
    },

    removeMod: async (instanceId, fileName) => {
      const mods = await api.invoke<InstalledMod[]>('axiom:mods:remove', { instanceId, fileName });
      set({ installedMods: mods ?? [] });
    },

    searchMods: async (partial) => {
      const current = get().modSearch;
      const next = { ...current, ...partial };
      set({ modSearch: { ...next, loading: true } });
      const results = await api.invoke<ModSearchResult[]>('axiom:modrinth:search', {
        query: next.query,
        projectType: next.projectType,
        loader: next.loader,
        sort: next.sort,
        limit: 24,
      });
      set({ modSearch: { ...next, results: results ?? [], loading: false } });
    },

    installProject: async (instanceId, project) => {
      const inst = get().instances.find((i) => i.id === instanceId);
      await api.invoke('axiom:modrinth:install', {
        instanceId,
        project,
        loader: inst?.loader !== 'vanilla' ? inst?.loader : undefined,
        gameVersion: inst?.versionId,
      });
      void actions.loadMods(instanceId);
    },

    addOfflineAccount: async (name) => {
      await api.invoke('axiom:accounts:add-offline', { name });
      const accounts = await api.invoke<Account[]>('axiom:accounts:list');
      set({ accounts });
      actions.toast({ kind: 'good', title: `Аккаунт «${name}» добавлен`, text: 'Режим офлайн-игры (только для серверов без проверки)' });
    },

    loginMicrosoft: async (username) => {
      set({ msaCode: null });
      const res = await api.invoke<{ ok: boolean; account?: Account; error?: string }>('axiom:accounts:login-microsoft', { username });
      if (res?.ok && res.account) {
        const accounts = await api.invoke<Account[]>('axiom:accounts:list');
        set({ accounts, msaCode: null });
        actions.toast({ kind: 'good', title: `Вход выполнен: ${res.account.name}` });
      } else {
        actions.toast({ kind: 'bad', title: 'Вход Microsoft не удался', text: res?.error });
      }
    },

    removeAccount: async (id) => {
      const accounts = await api.invoke<Account[]>('axiom:accounts:remove', { id });
      set({ accounts: accounts ?? [] });
    },

    createBot: async (partial) => {
      const bot = await api.invoke<BotProfile>('axiom:bots:create', partial);
      const bots = await api.invoke<BotProfile[]>('axiom:bots:list');
      set({ bots, selectedBotId: bot?.id ?? get().selectedBotId });
      actions.toast({ kind: 'good', title: `Профиль автоматизации создан`, text: bot?.name });
    },

    updateBot: async (id, partial) => {
      const bots = await api.invoke<BotProfile[]>('axiom:bots:list');
      set({ bots: bots.map((b) => (b.id === id ? { ...b, ...partial } : b)) });
      await api.invoke('axiom:bots:update', { id, partial });
    },

    removeBot: async (id) => {
      const bots = await api.invoke<BotProfile[]>('axiom:bots:remove', { id });
      set({ bots: bots ?? [], selectedBotId: bots?.[0]?.id ?? null });
    },

    startBot: async (id) => {
      await api.invoke('axiom:bots:start', { id });
    },

    stopBot: async (id) => {
      await api.invoke('axiom:bots:stop', { id });
    },

    pauseBot: async (id) => {
      await api.invoke('axiom:bots:pause', { id });
    },

    resumeBot: async (id) => {
      await api.invoke('axiom:bots:resume', { id });
    },

    setBotTasks: async (id, tasks) => {
      set({ bots: get().bots.map((b) => (b.id === id ? { ...b, tasks } : b)) });
      await api.invoke('axiom:bots:tasks', { id, tasks });
    },

    toast: (t) => {
      const id = `toast_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
      set((s) => ({ toasts: [...s.toasts, { ...t, id }] }));
      setTimeout(() => get().actions.dismissToast(id), 6200);
    },

    dismissToast: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),

    setSearchOpen: (v) => set({ searchOpen: v }),

    clearConsole: () => set({ logs: [] }),

    loadSystemInfo: async () => {
      const info = await api.invoke<{ userData: string; totalMemoryMb: number; electron: string; node: string }>('axiom:system:info');
      set({ systemInfo: info ?? null });
    },

    openPath: async (target) => {
      await api.invoke('axiom:system:open-path', { target });
    },

    openExternal: async (url) => {
      await api.invoke('axiom:system:open-external', { url });
    },

    launchLoaderOptions: async (mcVersion, loader) => {
      const res = await api.invoke<{ version: string; stable: boolean }[]>('axiom:versions:loader-options', { mcVersion, loader });
      return res ?? [];
    },
  };

  return {
    ready: false,
    view: 'play',
    settings: defaultSettings,
    instances: [],
    accounts: [],
    bots: [],
    versions: [],
    javaDetected: [],
    logs: [],
    runtimes: {},
    progress: {},
    installedMods: [],
    modSearch: { query: '', projectType: 'all', loader: 'any', sort: 'relevance', results: [], loading: false },
    toasts: [],
    launchState: { state: 'idle' },
    selectedInstanceId: null,
    selectedBotId: null,
    msaCode: null,
    searchOpen: false,
    platform: 'linux',
    version: '1.0.0',
    systemInfo: null,
    actions,
  };
});

function applyAccent(accent: Settings['accent']) {
  document.documentElement.dataset.accent = accent;
}

/** Подписка на события ядра (один раз на всё приложение). */
export function subscribeToCore() {
  return api.on((event) => useStore.getState().actions.applyEvent(event));
}

export const isDemo = !isElectron;
