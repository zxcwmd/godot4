import { useEffect, useMemo, useState } from 'react';
import clsx from 'clsx';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Bot, Plus, Play, Pause, Square, Trash2, Pickaxe, FlaskConical, Fish, Sprout, Flame, ShieldHalf, HandCoins,
  Archive, Timer, MapPin, Compass, Heart, Drumstick, Wifi, Users, Boxes, Settings2, ChevronRight, Zap,
  CircleDot, Activity, Package, TrendingUp, Skull, Route, Sparkles, Info,
} from 'lucide-react';
import { useStore } from '@/store/useStore';
import { Badge, Button, Card, Dot, EmptyState, IconButton, Input, Modal, ProgressBar, SectionTitle, Segmented, Select, Slider, Sparkline, StatCard, Toggle, Tooltip } from '@/components/ui';
import { formatDuration, formatNumber, formatTime } from '@/lib/format';
import type { BotProfile, BotRuntime, TaskDef, TaskKind } from '@shared/types';

const TASK_META: Record<TaskKind, { name: string; icon: React.ReactNode; accent: string; description: string }> = {
  mine: { name: 'Автошахта', icon: <Pickaxe size={15} />, accent: '#8b5cf6', description: 'Добывает руду и копает туннели, сам меняет инструмент' },
  brew: { name: 'Автоварка зелий', icon: <FlaskConical size={15} />, accent: '#f472b6', description: 'Работает у варочной стойки: закладка, ожидание, сбор' },
  fish: { name: 'Авторыбалка', icon: <Fish size={15} />, accent: '#38bdf8', description: 'Бесконечный цикл заброса и подсчёта улова' },
  farm: { name: 'Автоферма', icon: <Sprout size={15} />, accent: '#34d399', description: 'Сбор урожая и пересадка культур' },
  smelt: { name: 'Автоплавка', icon: <Flame size={15} />, accent: '#fb923c', description: 'Загружает печь сырьём и топливом, забирает результат' },
  guard: { name: 'Охрана базы', icon: <ShieldHalf size={15} />, accent: '#60a5fa', description: 'Атакует враждебных мобов в радиусе' },
  shop: { name: 'Автоторговля', icon: <HandCoins size={15} />, accent: '#fbbf24', description: 'Обмен с жителями: продаёт ресурсы за изумруды' },
  stash: { name: 'Автосклад', icon: <Archive size={15} />, accent: '#a78bfa', description: 'Раскладывает добычу по сундукам' },
  afk: { name: 'Анти-AFK', icon: <Timer size={15} />, accent: '#94a3b8', description: 'Имитирует активность, чтобы не выкинуло с сервера' },
};

const TASK_OPTIONS: Record<TaskKind, { key: string; label: string; type: 'text' | 'number' | 'select'; placeholder?: string; choices?: { value: string; label: string }[]; default?: string | number }[]> = {
  mine: [
    { key: 'mode', label: 'Что копать', type: 'select', default: 'ores', choices: [
      { value: 'ores', label: 'Только руду' },
      { value: 'stone', label: 'Камень и грунт' },
      { value: 'wood', label: 'Дерево' },
      { value: 'all', label: 'Всё подряд' },
    ] },
    { key: 'radius', label: 'Радиус поиска (блоки)', type: 'number', default: 48 },
  ],
  brew: [
    { key: 'recipe', label: 'Рецепт', type: 'select', default: 'strength', choices: [
      { value: 'awkward', label: 'Неуклюжее зелье' },
      { value: 'strength', label: 'Зелье силы' },
      { value: 'healing', label: 'Зелье исцеления' },
      { value: 'swiftness', label: 'Зелье скорости' },
      { value: 'night_vision', label: 'Ночное зрение' },
      { value: 'fire_resistance', label: 'Огнестойкость' },
      { value: 'regeneration', label: 'Регенерация' },
    ] },
    { key: 'radius', label: 'Радиус поиска стойки', type: 'number', default: 24 },
    { key: 'coords', label: 'Координаты стойки (x,y,z)', type: 'text', placeholder: 'необязательно' },
  ],
  fish: [],
  farm: [{ key: 'radius', label: 'Радиус фермы', type: 'number', default: 32 }],
  smelt: [{ key: 'radius', label: 'Радиус поиска печи', type: 'number', default: 24 }],
  guard: [{ key: 'radius', label: 'Радиус охраны', type: 'number', default: 16 }],
  shop: [
    { key: 'item', label: 'Что хотим получить', type: 'text', placeholder: 'emerald' },
    { key: 'times', label: 'Сделок за подход', type: 'number', default: 3 },
    { key: 'radius', label: 'Радиус поиска жителей', type: 'number', default: 24 },
  ],
  stash: [
    { key: 'keep', label: 'Оставлять (через запятую)', type: 'text', placeholder: 'sword,pickaxe,food' },
    { key: 'radius', label: 'Радиус поиска сундуков', type: 'number', default: 24 },
  ],
  afk: [],
};

export function Automation() {
  const bots = useStore((s) => s.bots);
  const runtimes = useStore((s) => s.runtimes);
  const selectedId = useStore((s) => s.selectedBotId);
  const selectBot = useStore((s) => s.actions.selectBot);
  const actions = useStore((s) => s.actions);
  const [creating, setCreating] = useState(false);
  const [editing, setEditing] = useState<BotProfile | null>(null);
  const [addingTask, setAddingTask] = useState(false);

  const bot = bots.find((b) => b.id === selectedId) ?? bots[0];
  const rt = bot ? runtimes[bot.id] : undefined;

  const global = useMemo(() => {
    const all = Object.values(runtimes);
    return {
      online: all.filter((r) => r.status === 'online').length,
      mined: all.reduce((s, r) => s + (r.stats?.blocksMined ?? 0), 0),
      items: all.reduce((s, r) => s + (r.stats?.itemsCollected ?? 0), 0),
      brews: all.reduce((s, r) => s + (r.stats?.brewsMade ?? 0), 0),
      fish: all.reduce((s, r) => s + (r.stats?.fishCaught ?? 0), 0),
      deaths: all.reduce((s, r) => s + (r.stats?.deaths ?? 0), 0),
      distance: all.reduce((s, r) => s + (r.stats?.distance ?? 0), 0),
    };
  }, [runtimes]);

  return (
    <div className="page-enter">
      <SectionTitle
        icon={<Bot size={16} />}
        title="Автоматизация"
        subtitle="Реальные боты Minecraft (mineflayer): подключаются к вашему серверу и работают за вас 24/7"
        action={
          <div className="flex items-center gap-2">
            <Badge tone={global.online ? 'good' : 'neutral'}>
              <Dot tone={global.online ? 'good' : 'idle'} pulse={!!global.online} /> {global.online} из {bots.length} в игре
            </Badge>
            <Button variant="primary" icon={<Plus size={16} />} onClick={() => setCreating(true)}>
              Новый бот
            </Button>
          </div>
        }
      />

      {bots.length === 0 ? (
        <EmptyState
          icon={<Bot size={26} />}
          title="Ботов пока нет"
          text="Создайте профиль: укажите адрес сервера, версию и задачи — автошахту, варку зелий, ферму или рыбалку. Бот подключится и начнёт работать."
          action={<Button variant="primary" icon={<Plus size={16} />} onClick={() => setCreating(true)}>Создать бота</Button>}
        />
      ) : (
        <div className="grid grid-cols-1 gap-5 xl:grid-cols-[320px_1fr]">
          {/* Список ботов */}
          <div className="space-y-2.5">
            {bots.map((b) => {
              const r = runtimes[b.id];
              const status = r?.status ?? 'offline';
              const tone = status === 'online' ? 'good' : status === 'paused' ? 'warn' : status === 'connecting' ? 'warn' : status === 'error' ? 'bad' : 'idle';
              const active = bot?.id === b.id;
              return (
                <button key={b.id} onClick={() => selectBot(b.id)} className="block w-full text-left">
                  <Card hover padded={false} className={clsx('relative overflow-hidden px-4 py-3.5', active && 'border-[var(--accent-ring)] shadow-glow')}>
                    {active && <motion.span layoutId="bot-active" className="absolute inset-y-0 left-0 w-[3px] accent-bg" />}
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <Dot tone={tone as never} pulse={status === 'online' || status === 'connecting'} />
                          <p className="truncate text-[13.5px] font-extrabold">{b.name}</p>
                        </div>
                        <p className="mt-1 truncate font-mono text-[11px] text-mist-400">{b.host}:{b.port} · {b.version}</p>
                      </div>
                      <Badge tone={status === 'online' ? 'good' : status === 'paused' ? 'warn' : 'neutral'}>{statusLabel(status)}</Badge>
                    </div>
                    <div className="mt-2.5 flex items-center gap-3 text-[11px] text-mist-400">
                      <span className="inline-flex items-center gap-1"><Pickaxe size={11} /> {(r?.stats?.blocksMined ?? b.stats.blocksMined).toLocaleString('ru-RU')}</span>
                      <span className="inline-flex items-center gap-1"><Package size={11} /> {(r?.stats?.itemsCollected ?? 0).toLocaleString('ru-RU')}</span>
                      <span className="inline-flex items-center gap-1"><Timer size={11} /> {formatDuration(r?.stats?.sessionMs ?? 0)}</span>
                    </div>
                    {r?.currentTaskText && <p className="mt-2 truncate text-[11.5px] accent-text font-semibold">{r.currentTaskText}</p>}
                  </Card>
                </button>
              );
            })}

            <Card className="!p-4">
              <p className="text-[12px] font-bold uppercase tracking-wide text-mist-400">Сводка движка</p>
              <div className="mt-3 grid grid-cols-2 gap-2.5">
                <MiniStat icon={<Pickaxe size={12} />} label="Блоков" value={formatNumber(global.mined)} />
                <MiniStat icon={<Package size={12} />} label="Предметов" value={formatNumber(global.items)} />
                <MiniStat icon={<FlaskConical size={12} />} label="Зелий" value={formatNumber(global.brews)} />
                <MiniStat icon={<Fish size={12} />} label="Рыбы" value={formatNumber(global.fish)} />
                <MiniStat icon={<Skull size={12} />} label="Смертей" value={String(global.deaths)} />
                <MiniStat icon={<Route size={12} />} label="Пройдено" value={`${formatNumber(global.distance)} бл.`} />
              </div>
            </Card>
          </div>

          {/* Дашборд бота */}
          {bot && (
            <div className="space-y-5">
              <BotHeader bot={bot} rt={rt} />

              <div className="grid grid-cols-1 gap-5 2xl:grid-cols-[1.35fr_1fr]">
                <div className="space-y-5">
                  <Card>
                    <SectionTitle
                      icon={<Zap size={16} />}
                      title="Очередь задач"
                      subtitle="Задачи выполняются по кругу; переключайте и настраивайте параметры"
                      action={
                        <Button size="sm" variant="outline" icon={<Plus size={14} />} onClick={() => setAddingTask(true)}>
                          Добавить
                        </Button>
                      }
                    />
                    <div className="space-y-2.5">
                      {bot.tasks.map((task) => {
                        const meta = TASK_META[task.kind];
                        const queueItem = rt?.taskQueue?.find((q) => q.id === task.id);
                        const isActive = queueItem?.state === 'active';
                        return (
                          <div key={task.id} className={clsx('rounded-2xl border p-3.5 transition-all', isActive ? 'border-[var(--accent-ring)] bg-white/[0.05]' : 'border-white/8 bg-white/[0.02]')}>
                            <div className="flex items-center gap-3">
                              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl" style={{ background: `${meta.accent}22`, color: meta.accent }}>
                                {meta.icon}
                              </span>
                              <div className="min-w-0 flex-1">
                                <div className="flex items-center gap-2">
                                  <p className="truncate text-[13.5px] font-bold">{task.name}</p>
                                  {isActive && <Badge tone="accent"><CircleDot size={10} /> выполняется</Badge>}
                                  {task.enabled && !isActive && <Badge tone="good">в очереди</Badge>}
                                </div>
                                <p className="mt-0.5 truncate text-[11.5px] text-mist-400">{optionsSummary(task)}</p>
                              </div>
                              <Toggle checked={task.enabled} onChange={(v) => actions.setBotTasks(bot.id, bot.tasks.map((t) => (t.id === task.id ? { ...t, enabled: v } : t)))} />
                              <IconButton size={30} onClick={() => setEditing({ ...bot, __taskFocus: task.id } as never)}>
                                <Settings2 size={14} />
                              </IconButton>
                              <IconButton size={30} className="hover:!text-rose-300" onClick={() => actions.setBotTasks(bot.id, bot.tasks.filter((t) => t.id !== task.id))}>
                                <Trash2 size={14} />
                              </IconButton>
                            </div>
                            {isActive && (
                              <div className="mt-3">
                                <ProgressBar value={queueItem?.progress ?? 0} height={5} glow />
                                <p className="mt-1.5 text-[11.5px] accent-text font-semibold">{rt?.currentTaskText}</p>
                              </div>
                            )}
                          </div>
                        );
                      })}
                      {!bot.tasks.length && (
                        <div className="rounded-2xl border border-dashed border-white/12 py-8 text-center">
                          <p className="text-[13px] font-bold">Задач нет</p>
                          <p className="mt-1 text-[12px] text-mist-400">Добавьте хотя бы одну — бот начнёт работать сразу после запуска</p>
                          <Button className="mt-3" size="sm" variant="primary" icon={<Plus size={14} />} onClick={() => setAddingTask(true)}>Добавить задачу</Button>
                        </div>
                      )}
                    </div>
                  </Card>

                  <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
                    <StatCard label="Блоков добыто" value={formatNumber(rt?.stats?.blocksMined ?? bot.stats.blocksMined)} icon={<Pickaxe size={15} />} />
                    <StatCard label="Руд найдено" value={formatNumber(Object.values(rt?.stats?.oresFound ?? bot.stats.oresFound ?? {}).reduce((s, v) => s + v, 0))} icon={<Sparkles size={15} />} />
                    <StatCard label="Зелий сварено" value={formatNumber(rt?.stats?.brewsMade ?? 0)} icon={<FlaskConical size={15} />} />
                    <StatCard label="Улова" value={formatNumber(rt?.stats?.fishCaught ?? 0)} icon={<Fish size={15} />} />
                  </div>

                  <Card>
                    <SectionTitle icon={<TrendingUp size={16} />} title="Темп добычи" subtitle="Блоков за интервал 15 секунд" />
                    <div className="h-[110px]">
                      <Sparkline data={rt?.throughput?.length ? rt.throughput : [4, 7, 6, 11, 9, 14, 12, 16, 13, 18, 15, 20]} height={110} color={TASK_META.mine.accent} />
                    </div>
                  </Card>
                </div>

                <div className="space-y-5">
                  <Card>
                    <SectionTitle icon={<Activity size={16} />} title="Живая телеметрия" subtitle="Обновляется каждые 1.2 с" />
                    <div className="grid grid-cols-2 gap-3">
                      <Telemetry icon={<MapPin size={13} />} label="Позиция" value={rt ? `${rt.position.x} / ${rt.position.y} / ${rt.position.z}` : '—'} mono />
                      <Telemetry icon={<Compass size={13} />} label="Измерение" value={dimensionLabel(rt?.dimension)} />
                      <Telemetry icon={<Wifi size={13} />} label="Пинг" value={rt ? `${rt.ping} мс` : '—'} />
                      <Telemetry icon={<Timer size={13} />} label="Сессия" value={formatDuration(rt?.stats?.sessionMs ?? 0)} />
                    </div>
                    <div className="mt-3 space-y-2.5">
                      <Bar icon={<Heart size={12} />} label="Здоровье" value={rt?.health ?? 20} max={20} color="#fb7185" />
                      <Bar icon={<Drumstick size={12} />} label="Сытость" value={rt?.food ?? 20} max={20} color="#fbbf24" />
                      <Bar icon={<Route size={12} />} label="Пройдено блоков" value={Math.min(100, (rt?.stats?.distance ?? 0) / 50)} max={100} color="var(--accent)" raw={formatNumber(rt?.stats?.distance ?? 0)} />
                    </div>
                    {rt?.nearbyPlayers?.length ? (
                      <div className="mt-4">
                        <p className="mb-1.5 flex items-center gap-1.5 text-[11px] font-bold uppercase tracking-wide text-mist-400"><Users size={11} /> Игроки рядом</p>
                        <div className="flex flex-wrap gap-1.5">
                          {rt.nearbyPlayers.map((p) => (
                            <span key={p} className="rounded-lg bg-white/[0.06] px-2 py-0.5 text-[11px] font-semibold text-mist-200">{p}</span>
                          ))}
                        </div>
                      </div>
                    ) : null}
                  </Card>

                  <Card>
                    <SectionTitle icon={<Boxes size={16} />} title="Инвентарь" subtitle={`${rt?.inventory?.length ?? 0} слотов занято`} />
                    <div className="grid grid-cols-9 gap-1.5">
                      {Array.from({ length: 36 }).map((_, i) => {
                        const item = rt?.inventory?.[i];
                        return (
                          <Tooltip key={i} text={item ? `${item.displayName} × ${item.count}` : 'Пусто'}>
                            <div className={clsx('relative grid aspect-square w-full place-items-center rounded-lg border text-[10px] font-extrabold', item ? 'border-white/12' : 'border-white/[0.05] bg-white/[0.02] text-mist-400/40')} style={item ? { background: `${item.tint}22`, color: item.tint } : undefined}>
                              {item ? (
                                <>
                                  <span className="text-[9px] leading-none">{item.name.slice(0, 2).toUpperCase()}</span>
                                  {item.count > 1 && <span className="absolute -bottom-0.5 -right-0.5 rounded bg-ink-950/90 px-1 font-mono text-[8.5px] font-bold text-mist-200">{item.count}</span>}
                                </>
                              ) : (
                                <span className="text-[9px]">—</span>
                              )}
                            </div>
                          </Tooltip>
                        );
                      })}
                    </div>
                  </Card>

                  <Card>
                    <SectionTitle icon={<Activity size={16} />} title="Активность бота" subtitle="Последние события" />
                    <div className="scroll-thin max-h-[320px] space-y-1.5 overflow-y-auto pr-1">
                      <AnimatePresence initial={false}>
                        {(rt?.activity ?? []).slice(0, 40).map((a) => (
                          <motion.div key={a.id} initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} className="flex items-start gap-2 rounded-xl px-2 py-1.5 hover:bg-white/[0.04]">
                            <span className={clsx('mt-1 dot', a.level === 'good' ? 'text-emerald-400 bg-emerald-400' : a.level === 'warn' ? 'text-amber-400 bg-amber-400' : a.level === 'bad' ? 'text-rose-400 bg-rose-400' : a.level === 'task' ? 'text-[var(--accent)] bg-[var(--accent)]' : 'text-sky-400 bg-sky-400')} />
                            <span className="min-w-0 flex-1">
                              <span className="block text-[12px] leading-snug text-mist-200">{a.text}</span>
                              <span className="font-mono text-[10px] text-mist-400">{formatTime(a.ts)}</span>
                            </span>
                          </motion.div>
                        ))}
                      </AnimatePresence>
                      {!rt?.activity?.length && <p className="py-6 text-center text-[12px] text-mist-400">События появятся после запуска бота</p>}
                    </div>
                  </Card>

                  <Card className="!p-4">
                    <div className="flex items-center gap-2 text-[11.5px] text-mist-400">
                      <Info size={13} className="accent-text" />
                      <span className="font-semibold">Как это работает</span>
                    </div>
                    <p className="mt-1.5 text-[11.5px] leading-snug text-mist-400">
                      Бот — это настоящий клиент Minecraft на Node.js (mineflayer + pathfinder). Он честно ходит, копает, открывает
                      верстаки и варочные стойки, поэтому работает на любом сервере без модов.
                    </p>
                  </Card>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      <CreateBotModal open={creating} onClose={() => setCreating(false)} />
      <EditBotModal bot={editing} onClose={() => setEditing(null)} />
      {bot && <AddTaskModal open={addingTask} onClose={() => setAddingTask(false)} bot={bot} />}
    </div>
  );
}

/* ─────────────────────────── Части ─────────────────────────── */

function BotHeader({ bot, rt }: { bot: BotProfile; rt?: BotRuntime }) {
  const actions = useStore((s) => s.actions);
  const accounts = useStore((s) => s.accounts);
  const account = accounts.find((a) => a.id === bot.accountId);
  const status = rt?.status ?? 'offline';
  const running = status === 'online' || status === 'connecting';
  const paused = status === 'paused';

  return (
    <Card className="relative overflow-hidden">
      <div className="absolute inset-0 opacity-60" style={{ background: 'radial-gradient(ellipse 60% 140% at 0% 0%, var(--accent-soft), transparent 65%)' }} />
      <div className="relative flex flex-wrap items-center justify-between gap-5">
        <div className="flex items-center gap-4">
          <div className="relative grid h-14 w-14 place-items-center rounded-2xl accent-bg accent-glow">
            <Bot size={26} className="text-ink-950" />
            {running && <span className="absolute -right-1 -top-1"><Dot tone="good" pulse /></span>}
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-[22px] font-extrabold tracking-tight">{bot.name}</h2>
              <Badge tone={running ? 'good' : paused ? 'warn' : 'neutral'}>{statusLabel(status)}</Badge>
            </div>
            <p className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-[12px] text-mist-400">
              <span className="inline-flex items-center gap-1.5"><Wifi size={12} /> {bot.host}:{bot.port}</span>
              <span className="inline-flex items-center gap-1.5"><Compass size={12} /> {bot.version}</span>
              <span className="inline-flex items-center gap-1.5"><Users size={12} /> {account?.name ?? 'аккаунт не выбран'}</span>
              <span className="inline-flex items-center gap-1.5"><Timer size={12} /> {formatDuration(bot.totalRuntimeMs)} всего</span>
            </p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {running ? (
            <>
              <Button variant="outline" icon={<Pause size={15} />} onClick={() => actions.pauseBot(bot.id)}>
                Пауза
              </Button>
              <Button variant="danger" icon={<Square size={15} />} onClick={() => actions.stopBot(bot.id)}>
                Остановить
              </Button>
            </>
          ) : (
            <>
              {paused && (
                <Button variant="outline" icon={<Play size={15} />} onClick={() => actions.resumeBot(bot.id)}>
                  Продолжить
                </Button>
              )}
              <Button variant="primary" icon={<Play size={16} />} onClick={() => actions.startBot(bot.id)}>
                {paused ? 'Перезапустить' : 'Запустить бота'}
              </Button>
            </>
          )}
        </div>
      </div>

      <div className="relative mt-4 flex flex-wrap items-center gap-2 text-[11.5px]">
        <Toggle
          checked={bot.autoReconnect}
          onChange={(v) => actions.updateBot(bot.id, { autoReconnect: v })}
          label="Автопереподключение"
        />
        <span className="mx-2 h-4 w-px bg-white/10" />
        <Toggle checked={bot.antiAfk} onChange={(v) => actions.updateBot(bot.id, { antiAfk: v })} label="Анти-AFK" />
        <span className="mx-2 h-4 w-px bg-white/10" />
        <Toggle checked={bot.autoEat} onChange={(v) => actions.updateBot(bot.id, { autoEat: v })} label="Авто-еда" />
      </div>
    </Card>
  );
}

function Telemetry({ icon, label, value, mono }: { icon: React.ReactNode; label: string; value: string; mono?: boolean }) {
  return (
    <div className="glass-soft rounded-2xl px-3 py-2.5">
      <p className="flex items-center gap-1.5 text-[10.5px] font-bold uppercase tracking-wide text-mist-400">
        <span className="accent-text">{icon}</span>
        {label}
      </p>
      <p className={clsx('mt-1 truncate text-[13.5px] font-extrabold', mono && 'font-mono text-[12.5px]')}>{value}</p>
    </div>
  );
}

function Bar({ icon, label, value, max, color, raw }: { icon: React.ReactNode; label: string; value: number; max: number; color: string; raw?: string }) {
  const pct = Math.max(0, Math.min(100, (value / max) * 100));
  return (
    <div>
      <div className="flex items-center justify-between text-[11.5px]">
        <span className="flex items-center gap-1.5 font-semibold text-mist-300">
          <span style={{ color }}>{icon}</span>
          {label}
        </span>
        <span className="font-mono font-bold" style={{ color }}>{raw ?? `${Math.round(value)}/${max}`}</span>
      </div>
      <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-white/[0.07]">
        <motion.div className="h-full rounded-full" style={{ background: color }} initial={false} animate={{ width: `${pct}%` }} transition={{ type: 'spring', stiffness: 140, damping: 22 }} />
      </div>
    </div>
  );
}

function MiniStat({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div>
      <p className="flex items-center gap-1 text-[10px] font-bold uppercase tracking-wide text-mist-400">
        <span className="accent-text">{icon}</span>
        {label}
      </p>
      <p className="mt-0.5 text-[14px] font-extrabold">{value}</p>
    </div>
  );
}

/* ─────────────────────────── Модалки ─────────────────────────── */

function CreateBotModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const actions = useStore((s) => s.actions);
  const accounts = useStore((s) => s.accounts);
  const instances = useStore((s) => s.instances);
  const [form, setForm] = useState({ name: 'AXIOM-бот', host: 'localhost', port: 25565, version: '1.20.1', accountId: '' });
  const [preset, setPreset] = useState<'mine' | 'brew' | 'farm' | 'custom'>('mine');

  const presets: Record<string, { label: string; description: string; tasks: TaskDef[] }> = {
    mine: {
      label: 'Шахтёр',
      description: 'Автошахта руды + склад + анти-AFK',
      tasks: [
        { id: `t${Date.now()}1`, kind: 'mine', name: 'Автошахта', enabled: true, options: { mode: 'ores', radius: 48 } },
        { id: `t${Date.now()}2`, kind: 'stash', name: 'Автосклад', enabled: true, options: { keep: 'sword,pickaxe,torch,coal', radius: 24 } },
        { id: `t${Date.now()}3`, kind: 'afk', name: 'Анти-AFK', enabled: true, options: {} },
      ],
    },
    brew: {
      label: 'Алхимик',
      description: 'Варка зелий + рыбалка + анти-AFK',
      tasks: [
        { id: `t${Date.now()}4`, kind: 'brew', name: 'Автоварка зелий', enabled: true, options: { recipe: 'strength', radius: 24 } },
        { id: `t${Date.now()}5`, kind: 'fish', name: 'Авторыбалка', enabled: false, options: {} },
        { id: `t${Date.now()}6`, kind: 'afk', name: 'Анти-AFK', enabled: true, options: {} },
      ],
    },
    farm: {
      label: 'Фермер',
      description: 'Ферма + торговля + охрана',
      tasks: [
        { id: `t${Date.now()}7`, kind: 'farm', name: 'Автоферма', enabled: true, options: { radius: 48 } },
        { id: `t${Date.now()}8`, kind: 'shop', name: 'Автоторговля', enabled: true, options: { item: 'emerald', times: 4, radius: 24 } },
        { id: `t${Date.now()}9`, kind: 'guard', name: 'Охрана базы', enabled: true, options: { radius: 16 } },
      ],
    },
    custom: { label: 'Настрою сам', description: 'Пустая очередь задач', tasks: [] },
  };

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Новый бот автоматизации"
      subtitle="Бот подключится к серверу как обычный игрок и будет работать по вашим задачам"
      width={640}
      footer={
        <>
          <Button variant="subtle" onClick={onClose}>Отмена</Button>
          <Button
            variant="primary"
            icon={<Bot size={16} />}
            onClick={async () => {
              await actions.createBot({ ...form, accountId: form.accountId || accounts[0]?.id, tasks: presets[preset].tasks });
              onClose();
            }}
          >
            Создать бота
          </Button>
        </>
      }
    >
      <div className="space-y-5">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Имя профиля</label>
            <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          </div>
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Аккаунт</label>
            <Select
              value={form.accountId || accounts[0]?.id || ''}
              onChange={(v) => setForm({ ...form, accountId: v })}
              options={accounts.length ? accounts.map((a) => ({ value: a.id, label: `${a.name} (${a.type === 'microsoft' ? 'Microsoft' : 'офлайн'})` })) : [{ value: '', label: 'Нет аккаунтов' }]}
            />
          </div>
        </div>

        <div className="grid grid-cols-[1.6fr_1fr_1fr] gap-4">
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Адрес сервера</label>
            <Input value={form.host} onChange={(e) => setForm({ ...form, host: e.target.value })} placeholder="play.example.com" />
          </div>
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Порт</label>
            <Input type="number" value={form.port} onChange={(e) => setForm({ ...form, port: Number(e.target.value) })} />
          </div>
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Версия</label>
            <Select
              value={form.version}
              onChange={(v) => setForm({ ...form, version: v })}
              options={['1.21.4', '1.21.1', '1.20.6', '1.20.4', '1.20.1', '1.19.4', '1.18.2', '1.16.5', '1.12.2', 'auto'].map((v) => ({ value: v, label: v === 'auto' ? 'Автоопределение' : v }))}
            />
          </div>
        </div>

        <div>
          <label className="mb-2 block text-[13px] font-semibold text-mist-200">Готовый набор задач</label>
          <div className="grid grid-cols-2 gap-3">
            {(Object.keys(presets) as (keyof typeof presets)[]).map((key) => (
              <button
                key={key}
                onClick={() => setPreset(key as never)}
                className={clsx('rounded-2xl border p-3.5 text-left transition-all', preset === key ? 'border-[var(--accent-ring)] accent-soft-bg' : 'border-white/10 bg-white/[0.03] hover:border-white/20')}
              >
                <p className="text-[13px] font-bold">{presets[key].label}</p>
                <p className="mt-0.5 text-[11.5px] text-mist-400">{presets[key].description}</p>
              </button>
            ))}
          </div>
        </div>

        {instances.length > 0 && (
          <p className="text-[11.5px] text-mist-400">
            Совет: версия бота должна совпадать с версией сервера — иначе возможны рассинхроны протокола. Для локального сервера используйте «localhost».
          </p>
        )}
      </div>
    </Modal>
  );
}

function EditBotModal({ bot, onClose }: { bot: BotProfile | null; onClose: () => void }) {
  const actions = useStore((s) => s.actions);
  const accounts = useStore((s) => s.accounts);
  const [draft, setDraft] = useState<BotProfile | null>(bot);
  const focusTaskId = (bot as unknown as { __taskFocus?: string } | null)?.__taskFocus;

  useEffect(() => {
    setDraft(bot ? { ...bot, tasks: bot.tasks.map((t) => ({ ...t })) } : null);
  }, [bot]);

  if (!bot || !draft) return <Modal open={false} onClose={onClose} title="">{null}</Modal>;

  const patch = (p: Partial<BotProfile>) => setDraft({ ...draft, ...p });

  return (
    <Modal
      open={!!bot}
      onClose={onClose}
      title={`Настройки: ${bot.name}`}
      subtitle="Параметры подключения и опции задач"
      width={680}
      footer={
        <>
          <div className="mr-auto">
            <Button
              variant="danger"
              size="sm"
              icon={<Trash2 size={14} />}
              onClick={() => {
                void actions.removeBot(bot.id);
                onClose();
              }}
            >
              Удалить бота
            </Button>
          </div>
          <Button variant="subtle" onClick={onClose}>Отмена</Button>
          <Button
            variant="primary"
            onClick={async () => {
              const { tasks, ...rest } = draft;
              await actions.updateBot(bot.id, rest);
              await actions.setBotTasks(bot.id, tasks);
              actions.toast({ kind: 'good', title: 'Настройки бота сохранены', text: draft.name });
              onClose();
            }}
          >
            Сохранить
          </Button>
        </>
      }
    >
      <div className="space-y-5">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Имя профиля</label>
            <Input value={draft.name} onChange={(e) => patch({ name: e.target.value })} />
          </div>
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Аккаунт</label>
            <Select value={draft.accountId} onChange={(v) => patch({ accountId: v })} options={accounts.map((a) => ({ value: a.id, label: a.name }))} />
          </div>
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Сервер</label>
            <Input value={draft.host} onChange={(e) => patch({ host: e.target.value })} />
          </div>
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Порт / версия</label>
            <div className="flex gap-2">
              <Input type="number" value={draft.port} onChange={(e) => patch({ port: Number(e.target.value) })} className="w-[110px]" />
              <Input value={draft.version} onChange={(e) => patch({ version: e.target.value })} />
            </div>
          </div>
        </div>

        <div className="glass-soft space-y-3 rounded-2xl p-4">
          <Toggle checked={draft.autoReconnect} onChange={(v) => patch({ autoReconnect: v })} label="Автопереподключение" hint="Бот вернётся в игру после разрыва соединения или перезагрузки сервера" />
          <Toggle checked={draft.antiAfk} onChange={(v) => patch({ antiAfk: v })} label="Обход AFK-кика" hint="Случайные микродвижения и повороты камеры" />
          <Toggle checked={draft.autoEat} onChange={(v) => patch({ autoEat: v })} label="Авто-еда" hint="Съест еду из инвентаря, когда проголодается" />
        </div>

        <div className="space-y-3">
          <p className="text-[13px] font-semibold text-mist-200">Параметры задач</p>
          {draft.tasks.map((task) => (
            <div key={task.id} className={clsx('rounded-2xl border p-4', focusTaskId === task.id ? 'border-[var(--accent-ring)]' : 'border-white/8')}>
              <div className="flex items-center gap-2">
                <span className="grid h-8 w-8 place-items-center rounded-xl" style={{ background: `${TASK_META[task.kind].accent}22`, color: TASK_META[task.kind].accent }}>
                  {TASK_META[task.kind].icon}
                </span>
                <p className="flex-1 text-[13px] font-bold">{task.name}</p>
                <Toggle checked={task.enabled} onChange={(v) => patch({ tasks: draft.tasks.map((t) => (t.id === task.id ? { ...t, enabled: v } : t)) })} />
              </div>
              {TASK_OPTIONS[task.kind].length > 0 && (
                <div className="mt-3 grid grid-cols-2 gap-3">
                  {TASK_OPTIONS[task.kind].map((opt) => (
                    <div key={opt.key}>
                      <label className="mb-1.5 block text-[11.5px] font-semibold text-mist-400">{opt.label}</label>
                      {opt.type === 'select' ? (
                        <Select
                          value={String(task.options[opt.key] ?? opt.default ?? '')}
                          onChange={(v) => patch({ tasks: draft.tasks.map((t) => (t.id === task.id ? { ...t, options: { ...t.options, [opt.key]: v } } : t)) })}
                          options={(opt.choices ?? []).map((c) => ({ value: c.value, label: c.label }))}
                        />
                      ) : opt.type === 'number' ? (
                        <Input
                          type="number"
                          value={String(task.options[opt.key] ?? opt.default ?? 0)}
                          onChange={(e) => patch({ tasks: draft.tasks.map((t) => (t.id === task.id ? { ...t, options: { ...t.options, [opt.key]: Number(e.target.value) } } : t)) })}
                        />
                      ) : (
                        <Input
                          value={String(task.options[opt.key] ?? '')}
                          placeholder={opt.placeholder}
                          onChange={(e) => patch({ tasks: draft.tasks.map((t) => (t.id === task.id ? { ...t, options: { ...t.options, [opt.key]: e.target.value } } : t)) })}
                        />
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </Modal>
  );
}

function AddTaskModal({ open, onClose, bot }: { open: boolean; onClose: () => void; bot: BotProfile }) {
  const actions = useStore((s) => s.actions);
  const catalog = Object.keys(TASK_META) as TaskKind[];

  return (
    <Modal open={open} onClose={onClose} title="Добавить задачу" subtitle="Выберите процесс — параметры можно изменить в настройках бота" width={640}>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        {catalog.map((kind) => {
          const meta = TASK_META[kind];
          const already = bot.tasks.some((t) => t.kind === kind);
          return (
            <button
              key={kind}
              disabled={already}
              onClick={async () => {
                const options: Record<string, unknown> = {};
                for (const opt of TASK_OPTIONS[kind]) options[opt.key] = opt.default ?? (opt.type === 'number' ? 24 : '');
                await actions.setBotTasks(bot.id, [...bot.tasks, { id: `task_${Date.now()}`, kind, name: meta.name, enabled: true, options }]);
                actions.toast({ kind: 'good', title: `Задача «${meta.name}» добавлена`, text: bot.name });
                onClose();
              }}
              className={clsx('group flex items-start gap-3 rounded-2xl border p-4 text-left transition-all', already ? 'cursor-not-allowed border-white/6 opacity-40' : 'border-white/10 bg-white/[0.03] hover:border-[var(--accent-ring)] hover:bg-white/[0.06]')}
            >
              <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl" style={{ background: `${meta.accent}22`, color: meta.accent }}>
                {meta.icon}
              </span>
              <span className="min-w-0">
                <span className="flex items-center gap-2 text-[13.5px] font-bold">
                  {meta.name}
                  {already && <Badge>уже добавлена</Badge>}
                </span>
                <span className="mt-0.5 block text-[11.5px] leading-snug text-mist-400">{meta.description}</span>
              </span>
            </button>
          );
        })}
      </div>
    </Modal>
  );
}

/* ─────────────────────────── Утилиты ─────────────────────────── */

function statusLabel(status: string) {
  return { online: 'в игре', connecting: 'подключение', paused: 'пауза', error: 'ошибка', offline: 'офлайн' }[status] ?? status;
}

function dimensionLabel(dim?: string) {
  if (!dim) return 'Overworld';
  if (dim.includes('nether')) return 'Нижний мир';
  if (dim.includes('end')) return 'Край';
  return 'Обычный мир';
}

function optionsSummary(task: TaskDef) {
  const parts: string[] = [];
  const o = task.options as Record<string, unknown>;
  if (o.mode) parts.push({ ores: 'руда', stone: 'камень', wood: 'дерево', all: 'всё' }[String(o.mode)] ?? String(o.mode));
  if (o.recipe) parts.push(String(o.recipe));
  if (o.radius) parts.push(`радиус ${o.radius}`);
  if (o.keep) parts.push(`оставлять: ${o.keep}`);
  if (o.item) parts.push(`ищем «${o.item}»`);
  if (o.coords) parts.push(`точка ${o.coords}`);
  return parts.length ? parts.join(' · ') : TASK_META[task.kind].description;
}
