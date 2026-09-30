import { useEffect, useMemo, useRef, useState } from 'react';
import clsx from 'clsx';
import { TerminalSquare, Trash2, Search, ArrowDownToLine, Pause, Play, Download, Filter } from 'lucide-react';
import { useStore } from '@/store/useStore';
import { Badge, Button, Card, IconButton, Input, SectionTitle, Segmented, Tooltip } from '@/components/ui';
import { formatTime } from '@/lib/format';
import type { LogEntry } from '@shared/types';

const SOURCE_META: Record<LogEntry['source'], { label: string; color: string }> = {
  launcher: { label: 'LAUNCHER', color: '#a78bfa' },
  game: { label: 'GAME', color: '#22d3ee' },
  bot: { label: 'BOT', color: '#34d399' },
  installer: { label: 'INSTALL', color: '#fbbf24' },
  network: { label: 'NET', color: '#f472b6' },
};

const LEVEL_COLOR: Record<LogEntry['level'], string> = {
  debug: 'text-mist-400',
  info: 'text-mist-200',
  warn: 'text-amber-300',
  error: 'text-rose-300',
  success: 'text-emerald-300',
};

export function ConsoleView() {
  const logs = useStore((s) => s.logs);
  const clear = useStore((s) => s.actions.clearConsole);
  const [query, setQuery] = useState('');
  const [source, setSource] = useState<LogEntry['source'] | 'all'>('all');
  const [pinned, setPinned] = useState(true);
  const [follow, setFollow] = useState(true);
  const endRef = useRef<HTMLDivElement>(null);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return logs.filter((l) => (source === 'all' ? true : l.source === source)).filter((l) => (q ? l.message.toLowerCase().includes(q) : true)).slice(-800);
  }, [logs, query, source]);

  useEffect(() => {
    if (follow) endRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }, [filtered.length, follow]);

  const counts = useMemo(() => {
    const c: Record<string, number> = { all: logs.length };
    for (const l of logs) c[l.source] = (c[l.source] ?? 0) + 1;
    return c;
  }, [logs]);

  const exportLogs = () => {
    const text = filtered.map((l) => `${new Date(l.ts).toISOString()} [${l.level}] [${l.source}] ${l.message}`).join('\n');
    const blob = new Blob([text], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `axiom-console-${Date.now()}.log`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="page-enter flex h-[calc(100vh-140px)] flex-col">
      <SectionTitle
        icon={<TerminalSquare size={16} />}
        title="Консоль"
        subtitle={`${logs.length} записей · логи ядра, установщика, игры и ботов`}
        action={
          <div className="flex items-center gap-2">
            <Button size="sm" variant="outline" icon={<Download size={14} />} onClick={exportLogs}>
              Экспорт
            </Button>
            <Button size="sm" variant="outline" icon={follow ? <Pause size={14} /> : <Play size={14} />} onClick={() => setFollow((f) => !f)}>
              {follow ? 'Пауза ленты' : 'Следовать'}
            </Button>
            <Button size="sm" variant="danger" icon={<Trash2 size={14} />} onClick={clear}>
              Очистить
            </Button>
          </div>
        }
      />

      <div className="mb-3 flex flex-wrap items-center gap-3">
        <Input className="w-[300px]" icon={<Search size={15} />} placeholder="Фильтр по тексту: ошибка, diamond, Modrinth…" value={query} onChange={(e) => setQuery(e.target.value)} />
        <Segmented
          size="sm"
          value={source}
          onChange={setSource}
          options={[
            { value: 'all', label: `Все · ${counts.all ?? 0}` },
            { value: 'launcher', label: `Ядро · ${counts.launcher ?? 0}` },
            { value: 'game', label: `Игра · ${counts.game ?? 0}` },
            { value: 'bot', label: `Боты · ${counts.bot ?? 0}` },
            { value: 'installer', label: `Установка · ${counts.installer ?? 0}` },
            { value: 'network', label: `Сеть · ${counts.network ?? 0}` },
          ]}
        />
        <button
          onClick={() => setPinned((p) => !p)}
          className={clsx('flex items-center gap-2 rounded-xl border px-3 py-2 text-[12.5px] font-semibold transition-all', pinned ? 'border-[var(--accent-ring)] accent-soft-bg' : 'border-white/10 bg-white/[0.03] text-mist-300')}
        >
          <Filter size={13} /> Только важные
        </button>
        <div className="ml-auto flex items-center gap-2 font-mono text-[11px] text-mist-400">
          {(['error', 'warn', 'success'] as const).map((lv) => (
            <span key={lv} className="inline-flex items-center gap-1.5">
              <span className={clsx('dot', lv === 'error' ? 'bg-rose-400 text-rose-400' : lv === 'warn' ? 'bg-amber-400 text-amber-400' : 'bg-emerald-400 text-emerald-400')} />
              {logs.filter((l) => l.level === lv).length}
            </span>
          ))}
        </div>
      </div>

      <Card padded={false} className="flex min-h-0 flex-1 flex-col overflow-hidden">
        <div className="flex items-center gap-2 border-b border-white/[0.06] px-4 py-2.5">
          <span className="flex gap-1.5">
            <span className="h-2.5 w-2.5 rounded-full bg-rose-400/70" />
            <span className="h-2.5 w-2.5 rounded-full bg-amber-400/70" />
            <span className="h-2.5 w-2.5 rounded-full bg-emerald-400/70" />
          </span>
          <span className="ml-2 font-mono text-[11.5px] text-mist-400">axiom@launcher — поток логов</span>
          {pinned && <Badge tone="accent" className="ml-auto">только важные</Badge>}
        </div>
        <div className="scroll-thin min-h-0 flex-1 overflow-y-auto px-3 py-3">
          {filtered
            .filter((l) => !pinned || l.level !== 'debug')
            .map((l) => (
              <div key={l.id} className="term-line term group">
                <span className="shrink-0 font-mono text-mist-400/70">{formatTime(l.ts)}</span>
                <span className="shrink-0 font-bold" style={{ color: SOURCE_META[l.source]?.color ?? '#94a3b8', minWidth: 68 }}>
                  {SOURCE_META[l.source]?.label ?? l.source}
                </span>
                <span className={clsx('break-words', LEVEL_COLOR[l.level])}>{l.message}</span>
              </div>
            ))}
          {!filtered.length && <p className="py-10 text-center text-[12.5px] text-mist-400">Пусто. Запустите игру, установите версию или включите бота.</p>}
          <div ref={endRef} />
        </div>
        <div className="flex items-center justify-between border-t border-white/[0.06] px-4 py-2 text-[11px] text-mist-400">
          <span>Показано {filtered.length} строк</span>
          <Tooltip text="Логи также пишутся в файл logs/axiom-ДАТА.log">
            <span className="cursor-help">Автосохранение в файл включено</span>
          </Tooltip>
        </div>
      </Card>

      <div className="mt-3 hidden">
        <IconButton />
      </div>
    </div>
  );
}
