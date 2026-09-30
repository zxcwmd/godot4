import { useState } from 'react';
import clsx from 'clsx';
import {
  Settings as SettingsIcon, Palette, Cpu, HardDrive, FolderOpen, Download, RefreshCw, Sparkles, Info, ShieldCheck,
  MemoryStick, Gauge, Languages, Code2, ExternalLink, MonitorSmartphone, Zap, Check,
} from 'lucide-react';
import { useStore, ACCENTS } from '@/store/useStore';
import { Badge, Button, Card, Input, SectionTitle, Segmented, Select, Slider, Toggle, ProgressBar, Tooltip } from '@/components/ui';
import { formatBytes } from '@/lib/format';
import { api, isElectron } from '@/lib/api';
import { Logo } from '@/components/Shell';

export function SettingsView() {
  const settings = useStore((s) => s.settings);
  const javaDetected = useStore((s) => s.javaDetected);
  const systemInfo = useStore((s) => s.systemInfo);
  const accounts = useStore((s) => s.accounts);
  const versions = useStore((s) => s.versions);
  const actions = useStore((s) => s.actions);
  const progress = useStore((s) => s.progress);
  const [javaBusy, setJavaBusy] = useState<number | null>(null);

  const set = (p: Parameters<typeof actions.updateSettings>[0]) => void actions.updateSettings(p);
  const javaProgress = Object.values(progress).find((p) => p.taskId === 'java');

  return (
    <div className="page-enter grid grid-cols-1 gap-5 xl:grid-cols-2">
      {/* ─── Внешний вид ─── */}
      <Card>
        <SectionTitle icon={<Palette size={16} />} title="Внешний вид" subtitle="Акцент, анимации и прозрачность интерфейса" />
        <div className="space-y-5">
          <div>
            <p className="mb-2.5 text-[13px] font-semibold text-mist-200">Акцентный цвет</p>
            <div className="flex flex-wrap gap-2.5">
              {ACCENTS.map((a) => (
                <button
                  key={a.id}
                  onClick={() => set({ accent: a.id })}
                  className={clsx('group relative h-11 w-11 rounded-2xl border transition-all', settings.accent === a.id ? 'border-white/60 scale-105' : 'border-white/10 hover:scale-105')}
                  style={{ background: `linear-gradient(135deg, ${a.from}, ${a.to})` }}
                  title={a.label}
                >
                  {settings.accent === a.id && (
                    <span className="absolute inset-0 grid place-items-center">
                      <Check size={16} className="text-ink-950" strokeWidth={3} />
                    </span>
                  )}
                </button>
              ))}
            </div>
          </div>
          <div className="glass-soft space-y-3 rounded-2xl p-4">
            <Toggle checked={settings.animations} onChange={(v) => set({ animations: v })} label="Живой фон и анимации" hint="Частицы, аврора, плавные переходы между экранами" />
            <Toggle checked={!settings.reduceTransparency} onChange={(v) => set({ reduceTransparency: !v })} label="Стеклянный эффект (blur)" hint="Отключите на слабых GPU или в удалённом рабочем столе" />
            <div className="flex items-center justify-between pt-1">
              <span className="text-[13.5px] font-semibold">Язык интерфейса</span>
              <Segmented
                size="sm"
                value={settings.language}
                onChange={(v) => set({ language: v })}
                options={[
                  { value: 'ru', label: 'Русский' },
                  { value: 'en', label: 'English' },
                ]}
              />
            </div>
          </div>
          <div className="flex items-center gap-3 rounded-2xl border border-white/8 p-3.5">
            <Logo size={36} />
            <div>
              <p className="text-[12.5px] font-bold">Тёмная космическая тема</p>
              <p className="text-[11.5px] text-mist-400">Оптимизирована под долгие сессии, снижает нагрузку на глаза</p>
            </div>
          </div>
        </div>
      </Card>

      {/* ─── Производительность ─── */}
      <Card>
        <SectionTitle icon={<Gauge size={16} />} title="Производительность" subtitle="Память, JVM и параллельные загрузки" />
        <div className="space-y-5">
          <div className="glass-soft rounded-2xl p-4">
            <Slider label="Оперативная память (по умолчанию)" value={settings.ramMb} onChange={(v) => set({ ramMb: v })} min={1024} max={32768} step={512} format={(v) => `${(v / 1024).toFixed(1)} ГБ`} />
            <div className="mt-2 flex items-center justify-between text-[11.5px] text-mist-400">
              <span>Система: {systemInfo?.totalMemoryMb ? `${(systemInfo.totalMemoryMb / 1024).toFixed(1)} ГБ ОЗУ` : '—'}</span>
              <span>{settings.ramMb > 8192 ? 'Хватит для тяжёлых модпаков' : settings.ramMb > 4096 ? 'Оптимально для модов' : 'Для ванили'}</span>
            </div>
          </div>

          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Аргументы JVM по умолчанию</label>
            <Input value={settings.jvmArgs} onChange={(e) => set({ jvmArgs: e.target.value })} placeholder="-XX:+UseG1GC -XX:+AlwaysPreTouch" />
            <div className="mt-2 flex flex-wrap gap-1.5">
              {['-XX:+UseZGC', '-XX:+UseG1GC', '-XX:+AlwaysPreTouch', '-XX:MaxGCPauseMillis=37', '-Dfile.encoding=UTF-8'].map((arg) => (
                <button key={arg} onClick={() => set({ jvmArgs: `${settings.jvmArgs} ${arg}`.trim() })} className="rounded-lg border border-white/10 bg-white/[0.04] px-2 py-1 font-mono text-[10.5px] text-mist-300 transition-colors hover:border-[var(--accent-ring)] hover:text-white">
                  + {arg}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="mb-2 block text-[13px] font-semibold text-mist-200">Аргументы игры по умолчанию</label>
            <Input value={settings.gameArgs} onChange={(e) => set({ gameArgs: e.target.value })} placeholder="--fullscreen --server play.example.com" />
          </div>

          <div className="glass-soft rounded-2xl p-4">
            <Slider label="Параллельных загрузок" value={settings.concurrency} onChange={(v) => set({ concurrency: v })} min={4} max={32} step={2} format={(v) => `${v} потоков`} />
            <p className="mt-2 text-[11.5px] text-mist-400">Больше потоков — быстрее установка, но выше нагрузка на сеть.</p>
          </div>

          <div className="glass-soft space-y-3 rounded-2xl p-4">
            <Toggle checked={settings.closeOnLaunch} onChange={(v) => set({ closeOnLaunch: v })} label="Закрывать лаунчер при запуске игры" />
            <Toggle checked={settings.autoUpdateMods} onChange={(v) => set({ autoUpdateMods: v })} label="Автообновление модов" hint="Проверять новые версии в Modrinth при запуске сборки" />
            <Toggle checked={settings.showSnapshots} onChange={(v) => set({ showSnapshots: v })} label="Показывать снапшоты и альфы" />
            <Toggle checked={settings.telemetryEnabled} onChange={(v) => set({ telemetryEnabled: v })} label="Отправлять анонимную статистику" hint="Помогает улучшать лаунчер. По умолчанию выключено" />
          </div>
        </div>
      </Card>

      {/* ─── Java ─── */}
      <Card>
        <SectionTitle
          icon={<Cpu size={16} />}
          title="Java"
          subtitle="Лаунчер сам подберёт версию под сборку, но можно указать вручную"
          action={
            <Button
              size="sm"
              variant="outline"
              icon={<Download size={14} />}
              loading={javaBusy === 21}
              onClick={async () => {
                setJavaBusy(21);
                await api.invoke('axiom:java:download', { major: 21 });
                const list = await api.invoke<typeof javaDetected>('axiom:java:detect');
                useStore.setState({ javaDetected: list });
                actions.toast({ kind: 'good', title: 'Java 21 установлена', text: 'Eclipse Temurin добавлен в runtime/' });
                setJavaBusy(null);
              }}
            >
              Скачать Temurin 21
            </Button>
          }
        />
        {javaProgress && (
          <div className="mb-3">
            <ProgressBar value={(javaProgress.bytesDone / Math.max(1, javaProgress.bytesTotal)) * 100} height={5} />
            <p className="mt-1.5 text-[11.5px] text-mist-400">
              {formatBytes(javaProgress.bytesDone)} из {formatBytes(javaProgress.bytesTotal)}
            </p>
          </div>
        )}
        <div className="space-y-2">
          {javaDetected.map((j) => (
            <div key={j.path} className="glass-soft flex items-center gap-3 rounded-2xl px-4 py-3">
              <div className="grid h-10 w-10 place-items-center rounded-xl accent-soft-bg accent-text font-mono text-[13px] font-extrabold">{j.major}</div>
              <div className="min-w-0 flex-1">
                <p className="text-[13px] font-bold">{j.vendor} {j.version}</p>
                <p className="truncate font-mono text-[11px] text-mist-400">{j.path}</p>
              </div>
              <Badge tone={j.major >= 17 ? 'good' : 'warn'}>{j.major >= 17 ? 'подходит' : 'только старые версии'}</Badge>
            </div>
          ))}
          {!javaDetected.length && (
            <p className="rounded-2xl border border-dashed border-white/12 py-6 text-center text-[12.5px] text-mist-400">
              Java не найдена. Нажмите «Скачать Temurin 21» — лаунчер установит её сам.
            </p>
          )}
        </div>
        <p className="mt-3 text-[11.5px] leading-snug text-mist-400">
          Требования: 1.20+ → Java 21, 1.18–1.19 → 17, 1.17 → 16, 1.12–1.16 → 8. Несовпадение версии — самая частая причина ошибок запуска.
        </p>
      </Card>

      {/* ─── Файлы и система ─── */}
      <Card>
        <SectionTitle icon={<HardDrive size={16} />} title="Файлы и система" subtitle="Где хранятся сборки, моды и логи" />
        <div className="space-y-2.5">
          {[
            { label: 'Каталог данных AXIOM', path: systemInfo?.userData ?? '—', target: 'root' },
            { label: 'Общие библиотеки и версии', path: `${systemInfo?.userData ?? ''}/shared`, target: 'shared' },
          ].map((row) => (
            <div key={row.label} className="glass-soft flex items-center gap-3 rounded-2xl px-4 py-3">
              <FolderOpen size={16} className="accent-text" />
              <div className="min-w-0 flex-1">
                <p className="text-[12.5px] font-bold">{row.label}</p>
                <p className="truncate font-mono text-[11px] text-mist-400">{row.path}</p>
              </div>
              <Button size="sm" variant="outline" onClick={() => actions.openPath(row.target)}>
                Открыть
              </Button>
            </div>
          ))}
          <div className="glass-soft rounded-2xl p-4">
            <p className="mb-2 text-[12.5px] font-bold">Локальная статистика</p>
            <div className="grid grid-cols-3 gap-3 text-[11.5px] text-mist-400">
              <Stat label="Версий" value={String(versions.filter((v) => v.installed).length)} />
              <Stat label="Аккаунтов" value={String(accounts.length)} />
              <Stat label="Java" value={String(javaDetected.length)} />
            </div>
          </div>
          <div className="flex gap-2">
            <Button variant="outline" icon={<RefreshCw size={15} />} onClick={() => void actions.loadSystemInfo()}>
              Обновить сведения
            </Button>
            {isElectron && (
              <Button variant="outline" icon={<Zap size={15} />} onClick={() => api.invoke('axiom:app:quit')}>
                Перезапустить приложение
              </Button>
            )}
          </div>
        </div>
      </Card>

      {/* ─── О программе ─── */}
      <Card className="xl:col-span-2">
        <div className="flex flex-wrap items-center justify-between gap-6">
          <div className="flex items-center gap-4">
            <Logo size={54} />
            <div>
              <h3 className="text-[20px] font-extrabold tracking-tight">
                AXIOM <span className="accent-grad-text">Launcher</span>
              </h3>
              <p className="mt-0.5 text-[12.5px] text-mist-400">
                Версия {useStore.getState().version} · {isElectron ? `Electron ${systemInfo?.electron ?? ''} · Node ${systemInfo?.node ?? ''}` : 'веб-превью интерфейса'}
              </p>
              <div className="mt-2 flex flex-wrap gap-1.5">
                <Badge tone="accent"><Sparkles size={10} /> автоматизация 24/7</Badge>
                <Badge tone="good"><ShieldCheck size={10} /> официальный вход Microsoft</Badge>
                <Badge><MonitorSmartphone size={10} /> Windows · macOS · Linux</Badge>
              </div>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Button variant="outline" icon={<Code2 size={15} />} onClick={() => actions.openExternal('https://github.com')}>
              Исходный код
            </Button>
            <Button variant="outline" icon={<ExternalLink size={15} />} onClick={() => actions.openExternal('https://modrinth.com')}>
              Каталог Modrinth
            </Button>
          </div>
        </div>
        <div className="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-3">
          <InfoTile icon={<Cpu size={15} />} title="Реальный клиент" text="Запуск настоящего Minecraft: официальные библиотеки, ассеты, Forge/Fabric/Quilt/NeoForge." />
          <InfoTile icon={<MemoryStick size={15} />} title="Умная Java" text="Определяет установленные JDK и автоматически скачивает Temurin нужной версии." />
          <InfoTile icon={<Languages size={15} />} title="Полностью на русском" text="Интерфейс, логи, подсказки и отчёты об ошибках — без англицизмов." />
        </div>
        <div className="mt-4 flex items-start gap-2.5 rounded-2xl border border-white/8 p-3.5 text-[11.5px] leading-snug text-mist-400">
          <Info size={14} className="mt-0.5 shrink-0 accent-text" />
          <span>
            AXIOM не связан с Mojang Studios и Microsoft. Игра запускается через официальные файлы; для онлайн-игры требуется лицензия. Автоматизация
            в ботовом режиме может нарушать правила конкретных серверов — используйте её на своих серверах или там, где это разрешено.
          </span>
        </div>
      </Card>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-[10.5px] font-bold uppercase tracking-wide">{label}</p>
      <p className="mt-0.5 text-[16px] font-extrabold text-mist-100">{value}</p>
    </div>
  );
}

function InfoTile({ icon, title, text }: { icon: React.ReactNode; title: string; text: string }) {
  return (
    <div className="glass-soft rounded-2xl p-4">
      <div className="flex items-center gap-2">
        <span className="grid h-8 w-8 place-items-center rounded-xl accent-soft-bg accent-text">{icon}</span>
        <p className="text-[13px] font-bold">{title}</p>
      </div>
      <p className="mt-2 text-[11.5px] leading-snug text-mist-400">{text}</p>
    </div>
  );
}
