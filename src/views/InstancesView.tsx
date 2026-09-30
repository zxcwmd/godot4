import { useState } from 'react';
import clsx from 'clsx';
import {
  Layers, Plus, Play, Trash2, Settings2, FolderOpen, MemoryStick, Terminal, Save, Copy, Star, Cpu, Sparkles,
} from 'lucide-react';
import { useStore } from '@/store/useStore';
import { Badge, Button, Card, IconButton, Input, Modal, SectionTitle, Segmented, Select, Slider, Toggle, ProgressBar, EmptyState } from '@/components/ui';
import { formatDuration, timeAgo } from '@/lib/format';
import { coverFor } from '@/lib/covers';
import type { Instance, Loader } from '@shared/types';
import { api } from '@/lib/api';

const LOADERS: { value: Loader; label: string }[] = [
  { value: 'vanilla', label: 'Vanilla (чистая игра)' },
  { value: 'fabric', label: 'Fabric (моды, оптимизация)' },
  { value: 'quilt', label: 'Quilt (форк Fabric)' },
  { value: 'forge', label: 'Forge (модпаки)' },
  { value: 'neoforge', label: 'NeoForge (современный форк)' },
];

export function InstancesView() {
  const instances = useStore((s) => s.instances);
  const versions = useStore((s) => s.versions);
  const settings = useStore((s) => s.settings);
  const actions = useStore((s) => s.actions);
  const [editing, setEditing] = useState<Instance | null>(null);
  const [creating, setCreating] = useState(false);

  return (
    <div className="page-enter">
      <SectionTitle
        icon={<Layers size={16} />}
        title="Сборки"
        subtitle="Каждая сборка — отдельная игровая папка со своими модами, мирами и параметрами запуска"
        action={
          <Button variant="primary" icon={<Plus size={16} />} onClick={() => setCreating(true)}>
            Новая сборка
          </Button>
        }
      />

      {instances.length === 0 ? (
        <EmptyState
          icon={<Layers size={26} />}
          title="Сборок ещё нет"
          text="Создайте профиль: выберите версию Minecraft и загрузчик — AXIOM скачает клиент, библиотеки и ресурсы автоматически."
          action={<Button variant="primary" icon={<Plus size={16} />} onClick={() => setCreating(true)}>Создать сборку</Button>}
        />
      ) : (
        <div className="stagger grid grid-cols-1 gap-4 lg:grid-cols-2 2xl:grid-cols-3">
          {instances.map((inst, index) => (
            <Card key={inst.id} hover padded={false} className="group relative overflow-hidden">
              <div className="relative h-[132px] overflow-hidden">
                <img src={coverFor(inst, index)} alt="" className="h-full w-full object-cover transition-transform duration-700 group-hover:scale-[1.05]" />
                <div className="absolute inset-0 bg-gradient-to-t from-ink-900 via-ink-900/40 to-transparent" />
                <div className="absolute left-4 top-4 flex flex-wrap items-center gap-1.5">
                  <Badge tone="accent">{inst.versionId}</Badge>
                  {inst.loader !== 'vanilla' && <Badge>{inst.loader}{inst.loaderVersion ? ` ${inst.loaderVersion}` : ''}</Badge>}
                  {inst.installed ? <Badge tone="good">готова</Badge> : <Badge tone="warn">не установлена</Badge>}
                </div>
                <div className="absolute right-3 top-3 flex items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100">
                  <IconButton size={30} className="bg-ink-950/60 backdrop-blur" onClick={() => setEditing(inst)}>
                    <Settings2 size={14} />
                  </IconButton>
                  <IconButton size={30} className="bg-ink-950/60 backdrop-blur hover:!text-rose-300" onClick={() => actions.removeInstance(inst.id, false)}>
                    <Trash2 size={14} />
                  </IconButton>
                </div>
              </div>
              <div className="relative p-5 pt-4">
                <div className="flex items-start gap-3">
                  <h3 className="truncate text-[16px] font-extrabold tracking-tight">{inst.name}</h3>
                  {inst.favorited && <Star size={13} className="mt-1 shrink-0 text-amber-300" fill="currentColor" />}
                </div>

                <div className="mt-3 grid grid-cols-3 gap-2 text-[11.5px] text-mist-400">
                  <span className="inline-flex items-center gap-1.5"><MemoryStick size={12} className="accent-text" />{inst.ramMb} МБ</span>
                  <span className="inline-flex items-center gap-1.5"><Cpu size={12} className="accent-text" />{inst.javaPath ? 'своя Java' : 'авто Java'}</span>
                  <span className="inline-flex items-center gap-1.5"><Terminal size={12} className="accent-text" />{[inst.jvmArgs, inst.gameArgs].filter(Boolean).length} арг.</span>
                </div>

                <div className="mt-3">
                  <div className="flex items-center justify-between text-[11px] text-mist-400">
                    <span>Наработано {formatDuration(inst.playtimeMs)}</span>
                    <span>{timeAgo(inst.lastPlayed)}</span>
                  </div>
                  <ProgressBar className="mt-1.5" value={Math.min(100, (inst.playtimeMs / 86_400_000) * 100)} height={3} />
                </div>

                <div className="mt-4 flex items-center gap-2">
                  <Button variant="primary" icon={<Play size={15} />} onClick={() => actions.launch(inst.id)} full>
                    Запустить
                  </Button>
                  <IconButton size={40} className="glass-soft" onClick={() => api.invoke('axiom:system:open-path', { target: `instances/${inst.id}` })}>
                    <FolderOpen size={15} />
                  </IconButton>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}

      <CreateInstanceModal open={creating} onClose={() => setCreating(false)} versions={versions} defaultRam={settings.ramMb} />
      <EditInstanceModal instance={editing} onClose={() => setEditing(null)} />
    </div>
  );
}

function CreateInstanceModal({ open, onClose, versions, defaultRam }: { open: boolean; onClose: () => void; versions: ReturnType<typeof useStore.getState>['versions']; defaultRam: number }) {
  const actions = useStore((s) => s.actions);
  const [name, setName] = useState('');
  const [versionId, setVersionId] = useState('1.21.4');
  const [loader, setLoader] = useState<Loader>('fabric');
  const [loaderVersion, setLoaderVersion] = useState('');
  const [loaderOptions, setLoaderOptions] = useState<{ version: string; stable: boolean }[]>([]);
  const [ram, setRam] = useState(defaultRam);
  const [busy, setBusy] = useState(false);
  const [copyOf, setCopyOf] = useState<string | null>(null);

  const releases = versions.filter((v) => v.type === 'release').slice(0, 60);

  async function loadLoaders(mc: string, ld: Loader) {
    if (ld === 'vanilla') {
      setLoaderOptions([]);
      setLoaderVersion('');
      return;
    }
    const opts = await actions.launchLoaderOptions(mc, ld);
    setLoaderOptions(opts);
    setLoaderVersion(opts.find((o) => o.stable)?.version ?? opts[0]?.version ?? '');
  }

  async function create() {
    setBusy(true);
    await actions.createInstance({
      name: name.trim() || `${versionId}${loader !== 'vanilla' ? ` · ${loader}` : ''}`,
      versionId,
      loader,
      loaderVersion: loader === 'vanilla' ? undefined : loaderVersion,
      ramMb: ram,
      icon: 'Sparkles',
    });
    setBusy(false);
    onClose();
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Новая сборка"
      subtitle="Профиль создаётся мгновенно, файлы игры докачиваются при первом запуске"
      width={620}
      footer={
        <>
          <Button variant="subtle" onClick={onClose}>Отмена</Button>
          <Button variant="primary" icon={<Sparkles size={16} />} loading={busy} onClick={create}>
            Создать сборку
          </Button>
        </>
      }
    >
      <div className="space-y-5">
        <div>
          <label className="mb-2 block text-[13px] font-semibold text-mist-200">Название</label>
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Например: Выживание с друзьями" />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Версия Minecraft</label>
            <Select
              value={versionId}
              onChange={(v) => {
                setVersionId(v);
                void loadLoaders(v, loader);
              }}
              options={releases.map((v) => ({ value: v.id, label: `${v.id}${v.installed ? ' · установлена' : ''}` }))}
            />
          </div>
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Загрузчик</label>
            <Select
              value={loader}
              onChange={(v) => {
                setLoader(v);
                void loadLoaders(versionId, v);
              }}
              options={LOADERS}
            />
          </div>
        </div>

        {loader !== 'vanilla' && (
          <div>
            <label className="mb-2 flex items-center justify-between text-[13px] font-semibold text-mist-200">
              Версия {loader}
              <button className="text-[11.5px] accent-text font-bold" onClick={() => void loadLoaders(versionId, loader)}>
                Обновить список
              </button>
            </label>
            {loaderOptions.length ? (
              <Select
                value={loaderVersion}
                onChange={setLoaderVersion}
                options={loaderOptions.map((o) => ({ value: o.version, label: `${o.version}${o.stable ? ' · стабильная' : ''}` }))}
              />
            ) : (
              <Input value={loaderVersion} onChange={(e) => setLoaderVersion(e.target.value)} placeholder="Версия загрузчика (например 0.16.9)" />
            )}
            <p className="mt-1.5 text-[11.5px] text-mist-400">Список подтягивается с официальных мета-серверов Fabric/Quilt/Forge.</p>
          </div>
        )}

        <div className="glass-soft rounded-2xl p-4">
          <Slider label="Оперативная память" value={ram} onChange={setRam} min={1024} max={32768} step={512} format={(v) => `${(v / 1024).toFixed(1)} ГБ`} />
          <p className="mt-2 text-[11.5px] text-mist-400">Для ванили хватает 2–4 ГБ, для модпаков — 6–10 ГБ.</p>
        </div>

        <div className="glass-soft flex items-center justify-between gap-4 rounded-2xl p-4">
          <div>
            <p className="text-[13px] font-semibold">Скопировать настройки существующей сборки</p>
            <p className="mt-0.5 text-[11.5px] text-mist-400">JVM-аргументы, ОЗУ и акцентный цвет</p>
          </div>
          <Select
            className="w-[190px]"
            value={copyOf ?? 'none'}
            onChange={async (v) => {
              setCopyOf(v);
              if (v === 'none') return;
              const src = useStore.getState().instances.find((i) => i.id === v);
              if (!src) return;
              setRam(src.ramMb);
              setVersionId(src.versionId);
              setLoader(src.loader);
              if (src.loaderVersion) setLoaderVersion(src.loaderVersion);
            }}
            options={[{ value: 'none', label: 'Не копировать' }, ...useStore.getState().instances.map((i) => ({ value: i.id, label: i.name }))]}
          />
        </div>
      </div>
    </Modal>
  );
}

function EditInstanceModal({ instance, onClose }: { instance: Instance | null; onClose: () => void }) {
  const actions = useStore((s) => s.actions);
  const [draft, setDraft] = useState<Instance | null>(instance);
  const [deleteFiles, setDeleteFiles] = useState(false);
  const [tab, setTab] = useState<'main' | 'jvm' | 'danger'>('main');

  if (instance && draft?.id !== instance.id) setDraft(instance);
  if (!instance || !draft) return <Modal open={false} onClose={onClose} title="" children={null} />;

  const patch = (p: Partial<Instance>) => setDraft({ ...draft, ...p });

  return (
    <Modal
      open={!!instance}
      onClose={onClose}
      title={instance.name}
      subtitle={`${instance.versionId}${instance.loader !== 'vanilla' ? ` · ${instance.loader} ${instance.loaderVersion ?? ''}` : ''}`}
      width={640}
      footer={
        <>
          <Button variant="subtle" onClick={onClose}>Отмена</Button>
          <Button
            variant="primary"
            icon={<Save size={16} />}
            onClick={async () => {
              await actions.updateInstance(instance.id, draft);
              actions.toast({ kind: 'good', title: 'Настройки сборки сохранены', text: draft.name });
              onClose();
            }}
          >
            Сохранить
          </Button>
        </>
      }
    >
      <Segmented
        className="mb-5"
        value={tab}
        onChange={setTab}
        options={[
          { value: 'main', label: 'Основное' },
          { value: 'jvm', label: 'Память и JVM' },
          { value: 'danger', label: 'Опасная зона' },
        ]}
      />

      {tab === 'main' && (
        <div className="space-y-4">
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Название сборки</label>
            <Input value={draft.name} onChange={(e) => patch({ name: e.target.value })} />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="mb-2 block text-[13px] font-semibold text-mist-200">Версия Minecraft</label>
              <Input value={draft.versionId} onChange={(e) => patch({ versionId: e.target.value })} />
            </div>
            <div>
              <label className="mb-2 block text-[13px] font-semibold text-mist-200">Загрузчик</label>
              <Select value={draft.loader} onChange={(v) => patch({ loader: v })} options={LOADERS} />
            </div>
          </div>
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Версия загрузчика</label>
            <Input value={draft.loaderVersion ?? ''} onChange={(e) => patch({ loaderVersion: e.target.value })} placeholder="например 0.16.9" />
          </div>
          <Toggle label="В избранном" hint="Отмеченные сборки подсвечиваются на главной" checked={!!draft.favorited} onChange={(v) => patch({ favorited: v })} />
          <div className="flex items-center justify-between rounded-2xl border border-white/8 p-4">
            <div>
              <p className="text-[13px] font-semibold">Папка сборки</p>
              <p className="mt-0.5 font-mono text-[11px] text-mist-400">instances/{instance.id}/</p>
            </div>
            <Button size="sm" variant="outline" icon={<FolderOpen size={14} />} onClick={() => api.invoke('axiom:system:open-path', { target: `instances/${instance.id}` })}>
              Открыть
            </Button>
          </div>
        </div>
      )}

      {tab === 'jvm' && (
        <div className="space-y-5">
          <Slider label="ОЗУ для сборки" value={draft.ramMb} onChange={(v) => patch({ ramMb: v })} min={1024} max={32768} step={512} format={(v) => `${(v / 1024).toFixed(1)} ГБ`} />
          <Slider label="Минимум ОЗУ (-Xms)" value={draft.minRamMb} onChange={(v) => patch({ minRamMb: v })} min={256} max={8192} step={256} format={(v) => `${(v / 1024).toFixed(1)} ГБ`} />
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Дополнительные аргументы JVM</label>
            <Input value={draft.jvmArgs} onChange={(e) => patch({ jvmArgs: e.target.value })} placeholder="-XX:+UseZGC -XX:+AlwaysPreTouch" />
            <div className="mt-2 flex flex-wrap gap-1.5">
              {['-XX:+UseZGC', '-XX:+UseG1GC', '-XX:+AlwaysPreTouch', '-Dfml.ignoreInvalidMinecraftCertificates=true', '-Dfml.ignorePatchDiscrepancies=true'].map((arg) => (
                <button
                  key={arg}
                  onClick={() => patch({ jvmArgs: `${draft.jvmArgs} ${arg}`.trim() })}
                  className="rounded-lg border border-white/10 bg-white/[0.04] px-2 py-1 font-mono text-[10.5px] text-mist-300 transition-colors hover:border-[var(--accent-ring)] hover:text-white"
                >
                  + {arg}
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Аргументы игры</label>
            <Input value={draft.gameArgs} onChange={(e) => patch({ gameArgs: e.target.value })} placeholder="--server play.example.com" />
          </div>
          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Путь к Java (необязательно)</label>
            <Input value={draft.javaPath ?? ''} onChange={(e) => patch({ javaPath: e.target.value })} placeholder="Автоматический выбор по версии" />
          </div>
        </div>
      )}

      {tab === 'danger' && (
        <div className="space-y-4">
          <div className="rounded-2xl border border-rose-400/25 bg-rose-500/[0.07] p-4">
            <p className="text-[13.5px] font-bold text-rose-200">Удаление сборки</p>
            <p className="mt-1 text-[12px] leading-snug text-rose-200/80">
              Профиль будет удалён из списка. Файлы игры (миры, моды, скриншоты) можно удалить вместе с ним — это необратимо.
            </p>
            <div className="mt-3">
              <Toggle checked={deleteFiles} onChange={setDeleteFiles} label="Удалить папку сборки целиком" hint="Мир, моды и настройки будут стёрты" />
            </div>
            <div className="mt-3 flex justify-end">
              <Button
                variant="danger"
                icon={<Trash2 size={15} />}
                onClick={() => {
                  void actions.removeInstance(instance.id, deleteFiles);
                  onClose();
                }}
              >
                Удалить сборку
              </Button>
            </div>
          </div>
          <div className="rounded-2xl border border-white/8 p-4">
            <p className="text-[13px] font-semibold">Дублировать сборку</p>
            <p className="mt-0.5 text-[12px] text-mist-400">Создаст новый профиль с теми же параметрами запуска.</p>
            <div className="mt-3 flex justify-end">
              <Button variant="outline" icon={<Copy size={15} />} onClick={() => actions.createInstance({ ...instance, id: undefined, name: `${instance.name} (копия)` })}>
                Дублировать
              </Button>
            </div>
          </div>
        </div>
      )}
    </Modal>
  );
}
