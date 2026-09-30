import { useEffect, useMemo, useState } from 'react';
import clsx from 'clsx';
import {
  Search, Download, Puzzle, Package, Sparkles, Palette, FileArchive, Trash2, Power, RefreshCw, Layers, Star, TrendingUp, Boxes, ExternalLink,
} from 'lucide-react';
import { useStore } from '@/store/useStore';
import { Badge, Button, Card, IconButton, Input, Segmented, SectionTitle, Select, EmptyState, Skeleton, Tooltip } from '@/components/ui';
import { formatNumber, timeAgo, formatBytes } from '@/lib/format';
import type { ModProjectType } from '@shared/types';

const TYPE_TABS: { value: ModProjectType | 'all'; label: string; icon: React.ReactNode }[] = [
  { value: 'all', label: 'Всё', icon: <Sparkles size={13} /> },
  { value: 'mod', label: 'Моды', icon: <Puzzle size={13} /> },
  { value: 'shader', label: 'Шейдеры', icon: <Palette size={13} /> },
  { value: 'resourcepack', label: 'Ресурспаки', icon: <FileArchive size={13} /> },
  { value: 'datapack', label: 'Датапаки', icon: <Boxes size={13} /> },
];

export function ModsView() {
  const instances = useStore((s) => s.instances);
  const selectedId = useStore((s) => s.selectedInstanceId);
  const modSearch = useStore((s) => s.modSearch);
  const installedMods = useStore((s) => s.installedMods);
  const actions = useStore((s) => s.actions);
  const [tab, setTab] = useState<'catalog' | 'installed'>('catalog');
  const [installingId, setInstallingId] = useState<string | null>(null);

  const instance = instances.find((i) => i.id === selectedId) ?? instances[0];

  useEffect(() => {
    if (!modSearch.results.length && !modSearch.loading) void actions.searchMods({});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (instance) void actions.loadMods(instance.id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [instance?.id]);

  const enabledCount = useMemo(() => installedMods.filter((m) => m.enabled).length, [installedMods]);

  if (!instance) {
    return <EmptyState icon={<Layers size={26} />} title="Сначала создайте сборку" text="Каталог модов устанавливается в конкретную сборку — выберите или создайте её." action={<Button variant="primary" onClick={() => actions.setView('instances')}>К сборкам</Button>} />;
  }

  return (
    <div className="page-enter">
      <SectionTitle
        icon={<Puzzle size={16} />}
        title="Моды и ресурсы"
        subtitle={`Каталог Modrinth · установка напрямую в «${instance.name}»`}
        action={
          <div className="flex items-center gap-2">
            <Select
              className="w-[240px]"
              value={instance.id}
              onChange={(v) => actions.selectInstance(v)}
              options={instances.map((i) => ({ value: i.id, label: i.name }))}
            />
            <Button variant="outline" icon={<RefreshCw size={15} />} onClick={() => actions.searchMods()}>
              Обновить
            </Button>
          </div>
        }
      />

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <Segmented
          value={tab}
          onChange={setTab}
          options={[
            { value: 'catalog', label: 'Каталог' },
            { value: 'installed', label: `Установлено · ${installedMods.length}` },
          ]}
        />
        {tab === 'catalog' && (
          <>
            <Input
              className="w-[320px]"
              icon={<Search size={15} />}
              placeholder="Sodium, шейдеры, автоматизация…"
              value={modSearch.query}
              onChange={(e) => void actions.searchMods({ query: e.target.value })}
            />
            <Segmented value={modSearch.projectType} onChange={(v) => void actions.searchMods({ projectType: v })} options={TYPE_TABS} size="sm" />
            <div className="ml-auto flex items-center gap-2">
              <Segmented
                size="sm"
                value={modSearch.sort}
                onChange={(v) => void actions.searchMods({ sort: v })}
                options={[
                  { value: 'relevance', label: 'Релевантность' },
                  { value: 'downloads', label: 'Загрузки' },
                  { value: 'newest', label: 'Новизна' },
                ]}
              />
              <Badge tone="accent">{instance.versionId}</Badge>
              {instance.loader !== 'vanilla' && <Badge>{instance.loader}</Badge>}
            </div>
          </>
        )}
        {tab === 'installed' && (
          <div className="ml-auto flex items-center gap-2 text-[12px] text-mist-400">
            <span>{enabledCount} активно из {installedMods.length}</span>
            <Badge tone="good">папка mods/</Badge>
          </div>
        )}
      </div>

      {tab === 'catalog' ? (
        modSearch.loading && !modSearch.results.length ? (
          <div className="grid grid-cols-1 gap-4 lg:grid-cols-2 2xl:grid-cols-3">
            {Array.from({ length: 6 }).map((_, i) => <Skeleton key={i} className="h-[186px]" />)}
          </div>
        ) : (
          <div className="stagger grid grid-cols-1 gap-4 lg:grid-cols-2 2xl:grid-cols-3">
            {modSearch.results.map((project) => {
              const installed = installedMods.some((m) => m.projectId === project.id);
              return (
                <Card key={project.id} hover className="flex flex-col">
                  <div className="flex items-start gap-3">
                    <div className="grid h-12 w-12 shrink-0 place-items-center overflow-hidden rounded-2xl border border-white/10 bg-white/[0.04]">
                      {project.iconUrl ? <img src={project.iconUrl} alt="" className="h-full w-full object-cover" /> : <Puzzle size={20} className="accent-text" />}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <p className="truncate text-[14.5px] font-extrabold tracking-tight">{project.title}</p>
                        {installed && <Badge tone="good">установлен</Badge>}
                      </div>
                      <p className="mt-0.5 truncate text-[11.5px] text-mist-400">от {project.author}</p>
                      <div className="mt-1.5 flex flex-wrap items-center gap-2 text-[11px] text-mist-400">
                        <span className="inline-flex items-center gap-1"><Download size={11} /> {formatNumber(project.downloads)}</span>
                        <span className="inline-flex items-center gap-1"><Star size={11} /> {formatNumber(project.follows)}</span>
                        <span className="inline-flex items-center gap-1"><TrendingUp size={11} /> {timeAgo(new Date(project.updated).getTime())}</span>
                      </div>
                    </div>
                  </div>

                  <p className="mt-3 line-clamp-3 text-[12.5px] leading-snug text-mist-300">{project.description}</p>

                  <div className="mt-3 flex flex-wrap gap-1.5">
                    {project.categories.slice(0, 3).map((c) => (
                      <span key={c} className="rounded-lg bg-white/[0.05] px-2 py-0.5 text-[10.5px] font-semibold text-mist-400">{c}</span>
                    ))}
                    {project.loaders.slice(0, 3).map((l) => (
                      <span key={l} className="rounded-lg accent-soft-bg px-2 py-0.5 text-[10.5px] font-bold accent-text">{l}</span>
                    ))}
                  </div>

                  <div className="mt-auto flex items-center gap-2 pt-4">
                    <Button
                      variant={installed ? 'ghost' : 'primary'}
                      size="sm"
                      icon={installed ? <RefreshCw size={14} /> : <Download size={14} />}
                      loading={installingId === project.id}
                      onClick={async () => {
                        setInstallingId(project.id);
                        await actions.installProject(instance.id, project);
                        setInstallingId(null);
                      }}
                      full
                    >
                      {installed ? 'Обновить' : 'Установить'}
                    </Button>
                    <Tooltip text="Открыть страницу на Modrinth">
                      <IconButton size={34} onClick={() => actions.openExternal(`https://modrinth.com/${project.projectType}/${project.slug}`)}>
                        <ExternalLink size={14} />
                      </IconButton>
                    </Tooltip>
                  </div>
                </Card>
              );
            })}
          </div>
        )
      ) : (
        <div className="space-y-2">
          {installedMods.length === 0 && (
            <EmptyState
              icon={<Package size={26} />}
              title="В сборке пока нет модов"
              text="Откройте каталог и установите Sodium, Iris, JEI или что-нибудь для автоматизации — файлы попадут в mods/ автоматически."
              action={<Button variant="primary" icon={<Puzzle size={15} />} onClick={() => setTab('catalog')}>Открыть каталог</Button>}
            />
          )}
          {installedMods.map((mod) => (
            <Card key={mod.fileName} padded={false} hover>
              <div className="flex items-center gap-4 px-4 py-3">
                <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-white/[0.05]">
                  {mod.type === 'shader' ? <Palette size={16} className="accent-text" /> : mod.type === 'resourcepack' ? <FileArchive size={16} className="accent-text" /> : <Puzzle size={16} className="accent-text" />}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className={clsx('truncate text-[13.5px] font-bold', !mod.enabled && 'text-mist-400 line-through')}>{mod.title}</p>
                    {mod.version && <Badge>{mod.version}</Badge>}
                    {!mod.enabled && <Badge tone="warn">отключён</Badge>}
                  </div>
                  <p className="mt-0.5 truncate font-mono text-[11px] text-mist-400">
                    {mod.fileName} · {formatBytes(mod.sizeBytes)}
                  </p>
                </div>
                <div className="flex shrink-0 items-center gap-1">
                  <Tooltip text={mod.enabled ? 'Отключить (переименовать в .disabled)' : 'Включить'}>
                    <Button size="sm" variant={mod.enabled ? 'outline' : 'primary'} icon={<Power size={13} />} onClick={() => actions.toggleMod(instance.id, mod.fileName)}>
                      {mod.enabled ? 'Отключить' : 'Включить'}
                    </Button>
                  </Tooltip>
                  <IconButton size={32} className="hover:!text-rose-300" onClick={() => actions.removeMod(instance.id, mod.fileName)}>
                    <Trash2 size={14} />
                  </IconButton>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
