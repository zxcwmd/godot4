import { useMemo, useState } from 'react';
import clsx from 'clsx';
import { Boxes, Download, Search, RefreshCw, Check, Filter, History, Sparkles, Layers } from 'lucide-react';
import { useStore } from '@/store/useStore';
import { Badge, Button, Card, IconButton, Input, ProgressBar, SectionTitle, Segmented, Skeleton } from '@/components/ui';
import { timeAgo } from '@/lib/format';
import { api } from '@/lib/api';
import type { VersionType } from '@shared/types';

const TYPE_LABEL: Record<VersionType, string> = {
  release: 'Релизы',
  snapshot: 'Снапшоты',
  old_beta: 'Бета',
  old_alpha: 'Альфа',
};

export function VersionsView() {
  const versions = useStore((s) => s.versions);
  const progress = useStore((s) => s.progress);
  const actions = useStore((s) => s.actions);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<'release' | 'snapshot' | 'all'>('release');
  const [onlyInstalled, setOnlyInstalled] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [limit, setLimit] = useState(40);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return versions
      .filter((v) => (filter === 'all' ? true : v.type === filter))
      .filter((v) => (onlyInstalled ? v.installed : true))
      .filter((v) => (q ? v.id.toLowerCase().includes(q) : true))
      .slice(0, limit);
  }, [versions, query, filter, onlyInstalled, limit]);

  const installing = Object.values(progress).find((p) => p.stage !== 'done' && p.stage !== 'error');
  const releasesCount = versions.filter((v) => v.type === 'release').length;

  return (
    <div className="page-enter">
      <SectionTitle
        icon={<Boxes size={16} />}
        title="Версии Minecraft"
        subtitle={`${releasesCount} релизов · ${versions.filter((v) => v.installed).length} установлено локально`}
        action={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              icon={<RefreshCw size={15} className={clsx(refreshing && 'animate-spin')} />}
              onClick={async () => {
                setRefreshing(true);
                await actions.launchLoaderOptions('1.21.4', 'fabric');
                const list = await api.invoke<typeof versions>('axiom:versions:list', true);
                actions.applyEvent({ type: 'toast', payload: { kind: 'info', title: 'Манифест версий обновлён', text: `${list.length} версий доступно` } });
                useStore.setState({ versions: list });
                setRefreshing(false);
              }}
            >
              Обновить манифест
            </Button>
            <Button variant="primary" icon={<Layers size={15} />} onClick={() => actions.setView('instances')}>
              Создать сборку
            </Button>
          </div>
        }
      />

      {installing && (
        <Card className="mb-5">
          <div className="flex items-center justify-between gap-4">
            <div className="min-w-0">
              <p className="truncate text-[13.5px] font-bold">{installing.label}</p>
              <p className="mt-0.5 text-[12px] text-mist-400">
                {installing.current} / {installing.total} файлов · этап: {stageLabel(installing.stage)}
                {installing.speed > 0 && ` · ${(installing.speed / 1024 / 1024).toFixed(1)} МБ/с`}
              </p>
            </div>
            <span className="accent-text font-mono text-[15px] font-extrabold">
              {Math.round((installing.bytesTotal > 0 ? (installing.bytesDone / installing.bytesTotal) * 100 : 0) || 0)}%
            </span>
          </div>
          <ProgressBar className="mt-3" value={(installing.bytesDone / Math.max(1, installing.bytesTotal)) * 100} glow />
        </Card>
      )}

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <Input className="w-[280px]" icon={<Search size={15} />} placeholder="Поиск версии, например 1.20.1" value={query} onChange={(e) => setQuery(e.target.value)} />
        <Segmented
          value={filter}
          onChange={setFilter}
          options={[
            { value: 'release', label: 'Релизы' },
            { value: 'snapshot', label: 'Снапшоты' },
            { value: 'all', label: 'Все' },
          ]}
        />
        <button
          onClick={() => setOnlyInstalled((v) => !v)}
          className={clsx('flex items-center gap-2 rounded-xl border px-3 py-2 text-[12.5px] font-semibold transition-all', onlyInstalled ? 'border-[var(--accent-ring)] accent-soft-bg text-white' : 'border-white/10 bg-white/[0.03] text-mist-300 hover:text-white')}
        >
          <Filter size={13} /> Только установленные
        </button>
        <span className="ml-auto text-[12px] text-mist-400">Показано {filtered.length} из {versions.length}</span>
      </div>

      {!versions.length ? (
        <div className="space-y-2">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton key={i} className="h-[68px]" />
          ))}
        </div>
      ) : (
        <div className="stagger space-y-2">
          {filtered.map((v) => {
            const task = Object.values(progress).find((p) => p.label.includes(v.id) && p.stage !== 'done');
            return (
              <Card key={v.id} padded={false} hover className="overflow-hidden">
                <div className="flex items-center gap-4 px-5 py-3.5">
                  <div className={clsx('grid h-11 w-11 shrink-0 place-items-center rounded-2xl text-[12px] font-extrabold', v.installed ? 'accent-soft-bg accent-text' : 'bg-white/[0.05] text-mist-400')}>
                    {v.id.slice(0, 4)}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <p className="truncate text-[14.5px] font-extrabold tracking-tight">{v.id}</p>
                      {v.installed && <Badge tone="good"><Check size={11} /> установлена</Badge>}
                      {v.loaders?.map((l) => (
                        <Badge key={l} tone="accent">{l}</Badge>
                      ))}
                      {v.type !== 'release' && <Badge tone="warn">{TYPE_LABEL[v.type]}</Badge>}
                    </div>
                    <p className="mt-0.5 flex items-center gap-2 text-[11.5px] text-mist-400">
                      <History size={11} /> выпущена {timeAgo(new Date(v.releaseTime).getTime())}
                      {v.type === 'release' && /^1\.(2[01]|[89])/.test(v.id) && <span className="accent-text font-semibold">· поддерживает Fabric и Forge</span>}
                    </p>
                    {task && (
                      <div className="mt-2 max-w-md">
                        <ProgressBar value={(task.bytesDone / Math.max(1, task.bytesTotal)) * 100} height={4} />
                        <p className="mt-1 text-[11px] text-mist-400">{task.label} · {stageLabel(task.stage)}</p>
                      </div>
                    )}
                  </div>
                  <div className="flex shrink-0 items-center gap-2">
                    <Button
                      size="sm"
                      variant="outline"
                      icon={<Sparkles size={13} />}
                      onClick={() =>
                        actions.createInstance({
                          name: `${v.id} · Fabric`,
                          versionId: v.id,
                          loader: 'fabric',
                          ramMb: useStore.getState().settings.ramMb,
                        })
                      }
                    >
                      Fabric-сборка
                    </Button>
                    <Button
                      size="sm"
                      variant={v.installed ? 'ghost' : 'primary'}
                      icon={v.installed ? <Check size={14} /> : <Download size={14} />}
                      loading={!!task}
                      onClick={() => actions.installVersion(v.id)}
                    >
                      {v.installed ? 'Переустановить' : 'Установить'}
                    </Button>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {filtered.length < versions.filter((v) => (filter === 'all' ? true : v.type === filter)).length && (
        <div className="mt-5 flex justify-center">
          <Button variant="ghost" icon={<RefreshCw size={15} />} onClick={() => setLimit((l) => l + 40)}>
            Показать ещё
          </Button>
        </div>
      )}

      <div className="mt-6 hidden">
        <IconButton />
      </div>
    </div>
  );
}

function stageLabel(stage: string) {
  const map: Record<string, string> = {
    prepare: 'подготовка',
    client: 'клиент',
    libraries: 'библиотеки',
    assets: 'ресурсы',
    natives: 'нативы',
    loader: 'загрузчик',
    done: 'завершено',
    error: 'ошибка',
  };
  return map[stage] ?? stage;
}
