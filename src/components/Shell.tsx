import { useEffect, useMemo, useState } from 'react';
import clsx from 'clsx';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Play, Layers, Boxes, Puzzle, Bot, Users, TerminalSquare, Settings as SettingsIcon, Search, Minus, Square, X,
  ChevronDown, Sparkles, ServerCog, CircleAlert, CheckCircle2, Info, TriangleAlert, Command, Cpu, Gauge, Zap,
} from 'lucide-react';
import { useStore, type View } from '@/store/useStore';
import { api, isElectron } from '@/lib/api';
import { Badge, Dot, IconButton, ProgressBar, Tooltip } from './ui';
import { formatBytes, formatSpeed } from '@/lib/format';

const NAV: { id: View; label: string; icon: React.ReactNode; hint: string }[] = [
  { id: 'play', label: 'Играть', icon: <Play size={18} />, hint: 'Запуск сборок' },
  { id: 'instances', label: 'Сборки', icon: <Layers size={18} />, hint: 'Профили и их настройки' },
  { id: 'versions', label: 'Версии', icon: <Boxes size={18} />, hint: 'Ванила, Fabric, Forge' },
  { id: 'mods', label: 'Моды', icon: <Puzzle size={18} />, hint: 'Modrinth-каталог' },
  { id: 'automation', label: 'Автоматизация', icon: <Bot size={18} />, hint: 'Боты: шахта, зелья, ферма' },
  { id: 'accounts', label: 'Аккаунты', icon: <Users size={18} />, hint: 'Microsoft и офлайн' },
  { id: 'console', label: 'Консоль', icon: <TerminalSquare size={18} />, hint: 'Логи ядра и игры' },
  { id: 'settings', label: 'Настройки', icon: <SettingsIcon size={18} />, hint: 'Java, ОЗУ, внешний вид' },
];

export function Shell({ children }: { children: React.ReactNode }) {
  const view = useStore((s) => s.view);
  const setView = useStore((s) => s.actions.setView);
  const accounts = useStore((s) => s.accounts);
  const [accountOpen, setAccountOpen] = useState(false);

  // Хоткеи навигации (1..8) и поиск (Ctrl+K)
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        useStore.getState().actions.setSearchOpen(true);
      }
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      const idx = Number(e.key) - 1;
      if (idx >= 0 && idx < NAV.length) setView(NAV[idx].id);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [setView]);

  return (
    <div className="relative z-10 flex h-full flex-col">
      <TitleBar />
      <div className="flex min-h-0 flex-1">
        <Sidebar view={view} onNavigate={setView} />
        <main className="scroll-thin relative min-w-0 flex-1 overflow-y-auto">
          <div className="mx-auto max-w-[1500px] px-7 pb-16 pt-5">{children}</div>
        </main>
      </div>
      <GlobalProgress />
      <Toasts />

      {/* Панель аккаунта (выпадающая из шапки) */}
      <AnimatePresence>
        {accountOpen && (
          <motion.div initial={{ opacity: 0, y: -8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -8 }} className="fixed right-8 top-[92px] z-50 w-[330px]">
            <div className="glass rounded-3xl p-4">
              <div className="mb-3 flex items-center justify-between">
                <p className="text-[13px] font-bold">Быстрый выбор аккаунта</p>
                <button className="text-[12px] accent-text font-semibold" onClick={() => { setView('accounts'); setAccountOpen(false); }}>
                  Управлять
                </button>
              </div>
              <div className="space-y-1.5">
                {accounts.map((a) => (
                  <AccountRow key={a.id} account={a} onSelect={() => setAccountOpen(false)} />
                ))}
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
      <AccountChipToggle open={accountOpen} onToggle={() => setAccountOpen((v) => !v)} />
    </div>
  );
}

function AccountChipToggle({ open, onToggle }: { open: boolean; onToggle: () => void }) {
  const accounts = useStore((s) => s.accounts);
  const current = accounts[0];
  return (
    <button
      onClick={onToggle}
      className={clsx('glass no-drag fixed right-8 top-[52px] z-[51] flex items-center gap-2.5 rounded-2xl px-3 py-1.5 transition-all hover:border-[var(--accent-ring)]', open && 'border-[var(--accent-ring)]')}
    >
      <img src={current?.avatar} alt="" className="h-6 w-6 rounded-lg bg-white/10 object-cover" onError={(e) => ((e.target as HTMLImageElement).style.opacity = '0')} />
      <span className="max-w-[140px] truncate text-[12.5px] font-bold">{current?.name ?? 'Нет аккаунта'}</span>
      {current?.type === 'microsoft' ? <Badge tone="accent">Live</Badge> : <Badge>Офлайн</Badge>}
      <ChevronDown size={14} className={clsx('text-mist-400 transition-transform', open && 'rotate-180')} />
    </button>
  );
}

function AccountRow({ account, onSelect }: { account: { id: string; name: string; type: string; avatar?: string; uuid: string }; onSelect: () => void }) {
  const [busy, setBusy] = useState(false);
  return (
    <button
      onClick={async () => {
        setBusy(true);
        const accounts = useStore.getState().accounts;
        const reordered = [account, ...accounts.filter((a) => a.id !== account.id)];
        // «Основной аккаунт» — первый в списке
        await api.invoke('axiom:accounts:list');
        useStore.setState({ accounts: reordered as never });
        setBusy(false);
        onSelect();
      }}
      className="flex w-full items-center gap-3 rounded-2xl px-2.5 py-2 text-left transition-colors hover:bg-white/[0.06]"
    >
      <img src={account.avatar} alt="" className="h-8 w-8 rounded-xl bg-white/10 object-cover" />
      <div className="min-w-0 flex-1">
        <p className="truncate text-[13px] font-bold">{account.name}</p>
        <p className="truncate font-mono text-[10.5px] text-mist-400">{account.uuid.slice(0, 18)}…</p>
      </div>
      {busy ? <Dot tone="warn" pulse /> : <Badge tone={account.type === 'microsoft' ? 'accent' : 'neutral'}>{account.type === 'microsoft' ? 'MS' : 'OFF'}</Badge>}
    </button>
  );
}

/* ─────────────────────────── Заголовок окна ─────────────────────────── */

function TitleBar() {
  const [maximized, setMaximized] = useState(false);
  const platform = useStore((s) => s.platform);
  const searchOpen = useStore((s) => s.searchOpen);
  const setSearchOpen = useStore((s) => s.actions.setSearchOpen);
  const version = useStore((s) => s.version);

  return (
    <header className="drag-region relative z-30 flex h-12 shrink-0 items-center justify-between border-b border-white/[0.06] px-4">
      <div className="flex items-center gap-3">
        <div className={clsx('flex items-center gap-2.5', platform === 'darwin' && 'pl-16')}>
          <Logo />
          <div className="leading-none">
            <p className="text-[13.5px] font-extrabold tracking-tight">
              AXIOM <span className="accent-grad-text">Launcher</span>
            </p>
            <p className="mt-0.5 text-[10.5px] font-medium text-mist-400">
              v{version} {!isElectron && <span className="accent-text">· веб-превью</span>}
            </p>
          </div>
        </div>
      </div>

      <button
        onClick={() => setSearchOpen(!searchOpen)}
        className="no-drag glass-soft group flex h-8 w-[300px] items-center gap-2 rounded-xl px-3 text-[12.5px] text-mist-400 transition-colors hover:text-mist-200"
      >
        <Search size={14} />
        <span className="flex-1 text-left">Поиск: сборки, версии, моды, боты…</span>
        <kbd className="flex items-center gap-0.5 rounded-md border border-white/10 bg-white/[0.06] px-1.5 py-0.5 font-mono text-[10px]">
          <Command size={9} />K
        </kbd>
      </button>

      {platform !== 'darwin' ? (
        <div className="no-drag flex items-center gap-1">
          <IconButton size={30} onClick={() => api.window.minimize()}>
            <Minus size={14} />
          </IconButton>
          <IconButton
            size={30}
            onClick={async () => setMaximized(await api.window.maximize())}
          >
            <Square size={12} className={maximized ? 'opacity-60' : ''} />
          </IconButton>
          <IconButton size={30} className="hover:!bg-rose-500/80 hover:!text-white" onClick={() => api.window.close()}>
            <X size={14} />
          </IconButton>
        </div>
      ) : (
        <div className="w-[150px]" />
      )}
    </header>
  );
}

export function Logo({ size = 30 }: { size?: number }) {
  return (
    <div className="relative grid place-items-center" style={{ width: size, height: size }}>
      <div className="absolute inset-0 rounded-xl accent-bg opacity-90 blur-[10px]" />
      <div className="relative grid h-full w-full place-items-center rounded-xl border border-white/20 bg-ink-900/80">
        <svg viewBox="0 0 32 32" width={size * 0.62} height={size * 0.62} className="accent-text">
          <path d="M16 3l11 6.4v12.8L16 29 5 22.2V9.4z" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinejoin="round" />
          <circle cx="16" cy="15.6" r="3.4" fill="currentColor" />
        </svg>
      </div>
    </div>
  );
}

/* ─────────────────────────── Сайдбар ─────────────────────────── */

function Sidebar({ view, onNavigate }: { view: View; onNavigate: (v: View) => void }) {
  const runtimes = useStore((s) => s.runtimes);
  const bots = useStore((s) => s.bots);
  const launchState = useStore((s) => s.launchState);
  const onlineBots = Object.values(runtimes).filter((r) => r.status === 'online' || r.status === 'connecting').length;
  const badges: Partial<Record<View, React.ReactNode>> = {
    automation: bots.length ? <span className="ml-auto flex items-center gap-1 text-[11px] font-bold text-emerald-300"><Dot tone={onlineBots ? 'good' : 'idle'} pulse={!!onlineBots} />{onlineBots}/{bots.length}</span> : null,
    play: launchState.state === 'running' ? <span className="ml-auto text-[11px] font-bold text-emerald-300">в игре</span> : null,
  };

  return (
    <aside className="relative z-20 flex w-[248px] shrink-0 flex-col gap-1 border-r border-white/[0.06] px-3.5 py-4">
      <nav className="space-y-1">
        {NAV.map((item, i) => {
          const active = view === item.id;
          return (
            <button
              key={item.id}
              onClick={() => onNavigate(item.id)}
              className={clsx(
                'group relative flex w-full items-center gap-3 rounded-2xl px-3.5 py-2.5 text-left transition-all duration-200',
                active ? 'text-white' : 'text-mist-300 hover:bg-white/[0.05] hover:text-white',
              )}
            >
              {active && (
                <motion.span layoutId="nav-active" className="absolute inset-0 rounded-2xl border border-white/10 accent-soft-bg" transition={{ type: 'spring', stiffness: 480, damping: 36 }} />
              )}
              <span className={clsx('relative z-10 transition-colors', active ? 'accent-text' : 'text-mist-400 group-hover:text-mist-200')}>{item.icon}</span>
              <span className="relative z-10 text-[13.5px] font-bold tracking-tight">{item.label}</span>
              <span className="relative z-10">{badges[item.id]}</span>
              <span className="absolute right-3 top-1/2 hidden -translate-y-1/2 font-mono text-[10px] text-mist-400/60 group-hover:block">{i + 1}</span>
            </button>
          );
        })}
      </nav>

      <div className="mt-auto space-y-3">
        <QuickStats />
        <div className="glass-soft rounded-2xl p-3">
          <div className="flex items-center gap-2 text-[11.5px] text-mist-400">
            <ServerCog size={13} className="accent-text" />
            <span className="font-semibold">Ядро автоматизации</span>
          </div>
          <p className="mt-1.5 text-[11.5px] leading-snug text-mist-400">
            Реальные боты mineflayer: автошахта, варка зелий, ферма, рыбалка, торговля, охрана базы.
          </p>
          <button onClick={() => onNavigate('automation')} className="mt-2.5 inline-flex items-center gap-1 text-[11.5px] font-bold accent-text">
            <Zap size={12} /> Настроить процессы
          </button>
        </div>
      </div>
    </aside>
  );
}

function QuickStats() {
  const runtimes = useStore((s) => s.runtimes);
  const instances = useStore((s) => s.instances);
  const stats = useMemo(() => {
    const all = Object.values(runtimes);
    const mined = all.reduce((s, r) => s + (r.stats?.blocksMined ?? 0), 0);
    const items = all.reduce((s, r) => s + (r.stats?.itemsCollected ?? 0), 0);
    const brews = all.reduce((s, r) => s + (r.stats?.brewsMade ?? 0), 0);
    return { mined, items, brews };
  }, [runtimes]);
  return (
    <div className="glass-soft grid grid-cols-2 gap-2 rounded-2xl p-3">
      <MiniStat icon={<Cpu size={12} />} label="Добыто" value={stats.mined.toLocaleString('ru-RU')} />
      <MiniStat icon={<Gauge size={12} />} label="Сборок" value={String(instances.length)} />
      <MiniStat icon={<Sparkles size={12} />} label="Собрано" value={stats.items.toLocaleString('ru-RU')} />
      <MiniStat icon={<Bot size={12} />} label="Зелий" value={stats.brews.toLocaleString('ru-RU')} />
    </div>
  );
}

function MiniStat({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div>
      <div className="flex items-center gap-1 text-[10px] font-bold uppercase tracking-wide text-mist-400">
        <span className="accent-text">{icon}</span>
        {label}
      </div>
      <div className="mt-0.5 truncate text-[13px] font-extrabold text-mist-100">{value}</div>
    </div>
  );
}

/* ─────────────────────────── Глобальный прогресс ─────────────────────────── */

function GlobalProgress() {
  const progress = useStore((s) => s.progress);
  const launch = useStore((s) => s.launchState);
  const tasks = Object.values(progress);
  const active = tasks.find((t) => t.stage !== 'done');
  if (!active && launch.state !== 'preparing') return null;

  const isLaunch = launch.state === 'preparing' && !active;
  const pct = active ? (active.bytesTotal > 0 ? (active.bytesDone / active.bytesTotal) * 100 : (active.current / Math.max(1, active.total)) * 100) : 12;

  return (
    <motion.div initial={{ y: 60, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 60, opacity: 0 }} className="pointer-events-none fixed bottom-5 left-1/2 z-[60] w-[520px] max-w-[92vw] -translate-x-1/2">
      <div className="glass pointer-events-auto rounded-2xl px-4 py-3">
        <div className="flex items-center justify-between gap-3">
          <div className="flex min-w-0 items-center gap-2.5">
            <span className="grid h-7 w-7 shrink-0 place-items-center rounded-lg accent-soft-bg accent-text">
              <Cpu size={14} className="animate-pulse" />
            </span>
            <div className="min-w-0">
              <p className="truncate text-[12.5px] font-bold">{active ? active.label : isLaunch ? 'Подготовка запуска игры' : 'Загрузка'}</p>
              <p className="text-[11px] text-mist-400">
                {active
                  ? `${active.current} / ${active.total}${active.speed > 0 ? ` · ${formatSpeed(active.speed)}` : ''}${active.bytesTotal > 1 ? ` · ${formatBytes(active.bytesDone)} из ${formatBytes(active.bytesTotal)}` : ''}`
                  : 'Проверяю целостность библиотек и ресурсов…'}
              </p>
            </div>
          </div>
          <span className="accent-text shrink-0 font-mono text-[13px] font-extrabold">{Math.round(pct)}%</span>
        </div>
        <ProgressBar className="mt-2.5" value={pct} height={5} glow />
      </div>
    </motion.div>
  );
}

/* ─────────────────────────── Уведомления ─────────────────────────── */

function Toasts() {
  const toasts = useStore((s) => s.toasts);
  const dismiss = useStore((s) => s.actions.dismissToast);
  const icons = {
    good: <CheckCircle2 size={17} className="text-emerald-400" />,
    bad: <CircleAlert size={17} className="text-rose-400" />,
    warn: <TriangleAlert size={17} className="text-amber-400" />,
    info: <Info size={17} className="accent-text" />,
  };
  return (
    <div className="pointer-events-none fixed right-5 top-[100px] z-[70] flex w-[360px] flex-col gap-2.5">
      <AnimatePresence>
        {toasts.map((t) => (
          <motion.div
            key={t.id}
            layout
            initial={{ opacity: 0, x: 40, scale: 0.97 }}
            animate={{ opacity: 1, x: 0, scale: 1 }}
            exit={{ opacity: 0, x: 40, scale: 0.97 }}
            transition={{ type: 'spring', stiffness: 420, damping: 34 }}
            className="glass pointer-events-auto flex items-start gap-3 rounded-2xl p-3.5"
          >
            <span className="mt-0.5">{icons[t.kind]}</span>
            <div className="min-w-0 flex-1">
              <p className="text-[13px] font-bold leading-snug">{t.title}</p>
              {t.text && <p className="mt-0.5 text-[12px] leading-snug text-mist-400">{t.text}</p>}
            </div>
            <IconButton size={26} onClick={() => dismiss(t.id)}>
              <X size={13} />
            </IconButton>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}

export { NAV };
export type { View };
