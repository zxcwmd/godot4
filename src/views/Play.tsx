import { useMemo, useState } from 'react';
import clsx from 'clsx';
import { motion } from 'framer-motion';
import {
  Play as PlayIcon, Square, Sparkles, Cpu, MemoryStick, HardDrive, Clock3, ChevronRight, Bot, Pickaxe,
  Package, Flame, Fish, Sprout, TrendingUp, Radio, Zap, Layers, Star, Gauge,
} from 'lucide-react';
import { useStore } from '@/store/useStore';
import { Badge, Button, Card, Dot, IconButton, ProgressBar, RingProgress, SectionTitle, Sparkline, StatCard, Tooltip } from '@/components/ui';
import { formatDuration, formatNumber, timeAgo } from '@/lib/format';
import { coverFor, HERO_COVER } from '@/lib/covers';
import { isElectron } from '@/lib/api';

const LOADER_LABEL: Record<string, string> = {
  vanilla: 'Vanilla',
  fabric: 'Fabric',
  quilt: 'Quilt',
  forge: 'Forge',
  neoforge: 'NeoForge',
};

export function Play() {
  const instances = useStore((s) => s.instances);
  const accounts = useStore((s) => s.accounts);
  const launchState = useStore((s) => s.launchState);
  const runtimes = useStore((s) => s.runtimes);
  const bots = useStore((s) => s.bots);
  const settings = useStore((s) => s.settings);
  const selectedId = useStore((s) => s.selectedInstanceId);
  const selectInstance = useStore((s) => s.actions.selectInstance);
  const launch = useStore((s) => s.actions.launch);
  const kill = useStore((s) => s.actions.kill);
  const setView = useStore((s) => s.actions.setView);
  const updateSettings = useStore((s) => s.actions.updateSettings);
  const [accountId, setAccountId] = useState<string | null>(null);

  const instance = instances.find((i) => i.id === selectedId) ?? instances[0];
  const account = accounts.find((a) => a.id === accountId) ?? accounts[0];
  const isRunning = launchState.state === 'running' && launchState.instanceId === instance?.id;
  const isPreparing = launchState.state === 'preparing' && launchState.instanceId === instance?.id;

  const totals = useMemo(() => {
    const all = Object.values(runtimes);
    return {
      mined: all.reduce((s, r) => s + (r.stats?.blocksMined ?? 0), 0),
      ores: Object.values(all.reduce<Record<string, number>>((acc, r) => {
        for (const [k, v] of Object.entries(r.stats?.oresFound ?? {})) acc[k] = (acc[k] ?? 0) + v;
        return acc;
      }, {})).reduce((s, v) => s + v, 0),
      brews: all.reduce((s, r) => s + (r.stats?.brewsMade ?? 0), 0),
      fish: all.reduce((s, r) => s + (r.stats?.fishCaught ?? 0), 0),
      online: all.filter((r) => r.status === 'online').length,
    };
  }, [runtimes]);

  if (!instance) {
    return (
      <div className="page-enter">
        <SectionTitle title="Добро пожаловать в AXIOM" subtitle="Создайте первую сборку, чтобы начать" />
        <Card className="grid place-items-center py-16 text-center">
          <Layers size={40} className="accent-text" />
          <p className="mt-4 text-[16px] font-bold">Сборок пока нет</p>
          <p className="mt-1 max-w-sm text-[13px] text-mist-400">Выберите версию Minecraft, загрузчик (Fabric/Forge) и запускайте — лаунчер сам скачает всё нужное.</p>
          <Button variant="primary" size="lg" className="mt-5" icon={<Sparkles size={17} />} onClick={() => setView('versions')}>
            Перейти к версиям
          </Button>
        </Card>
      </div>
    );
  }

  return (
    <div className="page-enter space-y-6">
      {/* ─────────── Hero-карточка запуска ─────────── */}
      <div className="grid grid-cols-1 gap-5 xl:grid-cols-[1.65fr_1fr]">
        <Card padded={false} className="relative overflow-hidden">
          <img src={HERO_COVER} alt="" className="absolute inset-0 h-full w-full object-cover object-center opacity-45" />
          <div className="absolute inset-0 bg-gradient-to-r from-ink-950/95 via-ink-950/80 to-ink-950/35" />
          <div className="absolute inset-0 bg-gradient-to-t from-ink-950 via-transparent to-transparent" />
          <div className="absolute inset-0 opacity-70" style={{ background: 'radial-gradient(ellipse 80% 120% at 15% 0%, var(--accent-soft), transparent 60%)' }} />
          <div className="relative p-6">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <Badge tone="accent">
                    <Sparkles size={11} /> {LOADER_LABEL[instance.loader] ?? instance.loader}
                  </Badge>
                  <Badge>{instance.versionId}</Badge>
                  {instance.favorited && <Badge tone="warn"><Star size={11} /> избранное</Badge>}
                  {isRunning && (
                    <Badge tone="good">
                      <Dot tone="good" pulse /> запущено
                    </Badge>
                  )}
                </div>
                <h1 className="mt-3 text-[34px] font-extrabold leading-none tracking-tight">{instance.name}</h1>
                <p className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-[12.5px] text-mist-400">
                  <span className="inline-flex items-center gap-1.5">
                    <Cpu size={13} /> {isElectron ? `Java ${instance.javaPath ? 'своя' : 'авто'}` : 'Java 21 · Temurin'}
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <MemoryStick size={13} /> {instance.ramMb} МБ ОЗУ
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <Clock3 size={13} /> {formatDuration(instance.playtimeMs)} в игре
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <HardDrive size={13} /> {timeAgo(instance.lastPlayed)}
                  </span>
                </p>
              </div>
              <div className="flex items-center gap-2">
                {isRunning ? (
                  <Button variant="danger" size="xl" icon={<Square size={18} />} onClick={() => kill(instance.id)}>
                    Остановить
                  </Button>
                ) : (
                  <Button variant="primary" size="xl" icon={<PlayIcon size={19} />} loading={isPreparing} onClick={() => launch(instance.id, account?.id)}>
                    {isPreparing ? 'Готовлю запуск…' : 'Играть'}
                  </Button>
                )}
              </div>
            </div>

            {isPreparing && (
              <div className="mt-5">
                <ProgressBar value={42} indeterminate glow height={6} />
                <p className="mt-2 text-[12px] text-mist-400">Проверяю библиотеки, собираю classpath, выбираю Java…</p>
              </div>
            )}

            <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
              <HeroStat label="Добыто блоков" value={formatNumber(instance.playtimeMs / 60000 * 4 + 1240 | 0)} icon={<Pickaxe size={14} />} />
              <HeroStat label="Мод-файлов" value={String(loadersMods(instance.loader))} icon={<Package size={14} />} />
              <HeroStat label="Рекоменд. ОЗУ" value={`${Math.max(2048, instance.ramMb)} МБ`} icon={<MemoryStick size={14} />} />
              <HeroStat label="Готовность" value="100%" icon={<Zap size={14} />} tone="ok" />
            </div>

            <div className="mt-5 flex flex-wrap items-center gap-2">
              <span className="text-[12px] font-semibold text-mist-400">Аккаунт:</span>
              {accounts.slice(0, 4).map((a) => (
                <button
                  key={a.id}
                  onClick={() => setAccountId(a.id)}
                  className={clsx('flex items-center gap-2 rounded-xl border px-2.5 py-1.5 text-[12px] font-semibold transition-all', account?.id === a.id ? 'border-[var(--accent-ring)] accent-soft-bg text-white' : 'border-white/10 bg-white/[0.03] text-mist-300 hover:text-white')}
                >
                  <img src={a.avatar} alt="" className="h-5 w-5 rounded-md bg-white/10 object-cover" />
                  {a.name}
                  {a.type === 'microsoft' && <Badge tone="accent" className="!px-1.5 !py-0 !text-[9px]">live</Badge>}
                </button>
              ))}
              <Button size="sm" variant="subtle" icon={<ChevronRight size={14} />} onClick={() => setView('accounts')}>
                Добавить
              </Button>
            </div>
          </div>
        </Card>

        {/* ─────────── Панель автоматизации (быстрый обзор) ─────────── */}
        <Card className="flex flex-col">
          <SectionTitle
            icon={<Bot size={16} />}
            title="Автоматизация"
            subtitle={totals.online ? `${totals.online} бот(ов) в игре прямо сейчас` : 'Боты не запущены'}
            action={
              <Button size="sm" variant="subtle" onClick={() => setView('automation')} iconRight={<ChevronRight size={13} />}>
                Панель
              </Button>
            }
          />
          <div className="space-y-2.5">
            {bots.slice(0, 3).map((bot) => {
              const rt = runtimes[bot.id];
              const status = rt?.status ?? 'offline';
              const tone = status === 'online' ? 'good' : status === 'paused' ? 'warn' : status === 'connecting' ? 'warn' : 'idle';
              return (
                <div key={bot.id} className="glass-soft rounded-2xl p-3">
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex min-w-0 items-center gap-2">
                      <Dot tone={tone as never} pulse={status === 'online' || status === 'connecting'} />
                      <span className="truncate text-[13px] font-bold">{bot.name}</span>
                    </div>
                    <span className="shrink-0 font-mono text-[11px] text-mist-400">{formatDuration(rt?.stats?.sessionMs ?? 0)}</span>
                  </div>
                  <p className="mt-1.5 truncate text-[11.5px] text-mist-400">{rt?.currentTaskText ?? rt?.statusText ?? 'Не подключён'}</p>
                  {rt?.currentTaskText && <ProgressBar className="mt-2" value={rt.taskQueue?.find((q) => q.state === 'active')?.progress ?? 0} height={4} />}
                </div>
              );
            })}
            {!bots.length && (
              <button onClick={() => setView('automation')} className="grid w-full place-items-center rounded-2xl border border-dashed border-white/12 py-8 text-center transition-colors hover:border-[var(--accent-ring)]">
                <Bot size={26} className="accent-text" />
                <p className="mt-2 text-[13px] font-bold">Создать первого бота</p>
                <p className="mt-0.5 text-[11.5px] text-mist-400">Автошахта, варка зелий, ферма, рыбалка</p>
              </button>
            )}
          </div>

          <div className="mt-4 grid grid-cols-2 gap-2">
            <QuickAction icon={<Pickaxe size={14} />} label="Автошахта" value={formatNumber(totals.mined)} onClick={() => setView('automation')} />
            <QuickAction icon={<FlaskIcon />} label="Зелий сварено" value={formatNumber(totals.brews)} onClick={() => setView('automation')} />
            <QuickAction icon={<Sprout size={14} />} label="Руд найдено" value={formatNumber(totals.ores)} onClick={() => setView('automation')} />
            <QuickAction icon={<Fish size={14} />} label="Рыбы поймано" value={formatNumber(totals.fish)} onClick={() => setView('automation')} />
          </div>
        </Card>
      </div>

      {/* ─────────── Переключатель сборок ─────────── */}
      <div>
        <SectionTitle
          icon={<Layers size={16} />}
          title="Мои сборки"
          subtitle="Выберите профиль для запуска — параметры ОЗУ и загрузчика подтянутся автоматически"
          action={
            <Button size="sm" variant="outline" onClick={() => setView('instances')}>
              Управлять сборками
            </Button>
          }
        />
        <div className="stagger grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {instances.map((inst, i) => {
            const active = inst.id === instance.id;
            return (
              <button key={inst.id} onClick={() => selectInstance(inst.id)} className="group text-left">
                <Card hover padded={false} className={clsx('relative h-full overflow-hidden', active && 'border-[var(--accent-ring)] shadow-glow')}>
                  <div className="relative h-[112px] overflow-hidden">
                    <img
                      src={coverFor(inst, i)}
                      alt=""
                      className="h-full w-full object-cover transition-transform duration-700 group-hover:scale-[1.06]"
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-ink-900 via-ink-900/35 to-transparent" />
                    {active && <motion.div layoutId="inst-active" className="absolute inset-x-0 top-0 h-[2px] accent-bg" />}
                    <div className="absolute right-3 top-3">
                      <RingProgress value={inst.installed ? 100 : 35} size={36} stroke={3.5}>
                        <span className="text-[9.5px] font-bold text-white">{inst.installed ? '✓' : '%'}</span>
                      </RingProgress>
                    </div>
                  </div>
                  <div className="p-4 pt-3">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="truncate text-[14.5px] font-extrabold tracking-tight">{inst.name}</p>
                      <p className="mt-1 text-[11.5px] text-mist-400">
                        {inst.versionId} {inst.loader !== 'vanilla' && `· ${LOADER_LABEL[inst.loader]}`}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="truncate text-[14.5px] font-extrabold tracking-tight">{inst.name}</p>
                      <p className="mt-1 text-[11.5px] text-mist-400">
                        {inst.versionId} {inst.loader !== 'vanilla' && `· ${LOADER_LABEL[inst.loader]}`}
                      </p>
                    </div>
                    <RingProgress value={inst.installed ? 100 : 35} size={38} stroke={3.5}>
                      <span className="text-[9.5px] font-bold">{inst.installed ? '✓' : '%'}</span>
                    </RingProgress>
                  </div>
                  <div className="mt-4 flex items-center justify-between text-[11px] text-mist-400">
                    <span>{inst.ramMb} МБ</span>
                    <span>{formatDuration(inst.playtimeMs)}</span>
                  </div>
                  <ProgressBar className="mt-2" value={Math.min(100, (inst.playtimeMs / 86_400_000) * 100)} height={3} />
                  </div>
                </Card>
              </button>
            );
          })}
        </div>
      </div>

      {/* ─────────── Метрики и советы ─────────── */}
      <div className="grid grid-cols-1 gap-5 xl:grid-cols-[1.2fr_1fr]">
        <Card>
          <SectionTitle icon={<TrendingUp size={16} />} title="Производительность добычи" subtitle="Измеряется по всем активным ботам (блоков за 15 секунд)" />
          <div className="h-[120px]">
            <Sparkline data={aggregateThroughput(Object.values(runtimes).map((r) => r.throughput ?? []))} height={120} />
          </div>
          <div className="mt-4 grid grid-cols-3 gap-3">
            <StatCard label="Блоков/мин" value={formatNumber(avgThroughput(Object.values(runtimes).map((r) => r.throughput ?? [])) * 4)} icon={<Gauge />} />
            <StatCard label="Аптайм" value={formatDuration(Object.values(runtimes).reduce((s, r) => s + (r.stats?.sessionMs ?? 0), 0))} icon={<Radio />} />
            <StatCard label="Смертей" value={String(Object.values(runtimes).reduce((s, r) => s + (r.stats?.deaths ?? 0), 0))} icon={<Flame />} />
          </div>
        </Card>

        <Card>
          <SectionTitle icon={<Sparkles size={16} />} title="Советы AXIOM" subtitle="Персонализация окружения" />
          <div className="space-y-3">
            <TipRow
              title="Шейдеры без просадки FPS"
              text="Установите Sodium + Iris и шейдерпак Complementary: +40% кадров и кинематографичная вода."
              action={<Button size="sm" variant="outline" onClick={() => setView('mods')}>Открыть каталог</Button>}
            />
            <TipRow
              title="Больше ОЗУ для модпаков"
              text={`Сейчас выделено ${settings.ramMb} МБ. Для сборок с модами рекомендуем 6–8 ГБ.`}
              action={<Button size="sm" variant="outline" onClick={() => updateSettings({ ramMb: Math.min(16384, settings.ramMb + 2048) })}>+2 ГБ</Button>}
            />
            <TipRow
              title="Автоматизация пока вы спите"
              text="Запустите «Шахтёр» и «Алхимик» с анти-AFK: к утру — стак алмазов и ящик зелий."
              action={<Button size="sm" variant="outline" onClick={() => setView('automation')}>К ботам</Button>}
            />
          </div>
        </Card>
      </div>
    </div>
  );
}

function HeroStat({ label, value, icon, tone }: { label: string; value: string; icon: React.ReactNode; tone?: 'ok' }) {
  return (
    <div className="glass-soft rounded-2xl px-3.5 py-3">
      <div className={clsx('flex items-center gap-1.5 text-[10.5px] font-bold uppercase tracking-wider', tone === 'ok' ? 'text-emerald-300' : 'text-mist-400')}>
        <span className="accent-text">{icon}</span>
        {label}
      </div>
      <div className="mt-1 text-[19px] font-extrabold tracking-tight">{value}</div>
    </div>
  );
}

function QuickAction({ icon, label, value, onClick }: { icon: React.ReactNode; label: string; value: string; onClick: () => void }) {
  return (
    <button onClick={onClick} className="glass-soft group flex items-center gap-3 rounded-2xl p-3 text-left transition-all hover:border-[var(--accent-ring)]">
      <span className="grid h-9 w-9 place-items-center rounded-xl accent-soft-bg accent-text">{icon}</span>
      <span className="min-w-0">
        <span className="block truncate text-[11px] font-bold uppercase tracking-wide text-mist-400">{label}</span>
        <span className="block text-[15px] font-extrabold">{value}</span>
      </span>
    </button>
  );
}

function TipRow({ title, text, action }: { title: string; text: string; action?: React.ReactNode }) {
  return (
    <div className="glass-soft flex items-start justify-between gap-4 rounded-2xl p-3.5">
      <div className="min-w-0">
        <p className="text-[13px] font-bold">{title}</p>
        <p className="mt-1 text-[12px] leading-snug text-mist-400">{text}</p>
      </div>
      <div className="shrink-0">{action}</div>
    </div>
  );
}

function FlaskIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 3h6v4l4 12a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2L9 7z" />
      <path d="M6.5 14h11" />
    </svg>
  );
}

function loadersMods(loader: string) {
  return loader === 'vanilla' ? 0 : loader === 'forge' ? 62 : loader === 'fabric' ? 48 : 24;
}

function aggregateThroughput(series: number[][]): number[] {
  const len = Math.max(12, ...series.map((s) => s.length), 0);
  return Array.from({ length: len }, (_, i) => series.reduce((sum, s) => sum + (s[s.length - len + i] ?? 0), 0));
}

function avgThroughput(series: number[][]) {
  const all = series.flat().filter((n) => n > 0);
  if (!all.length) return 0;
  return Math.round(all.reduce((a, b) => a + b, 0) / all.length);
}
