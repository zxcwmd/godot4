import { useEffect } from 'react';
import { Background } from './components/Background';
import { Shell } from './components/Shell';
import { GlobalSearch } from './components/GlobalSearch';
import { Play } from './views/Play';
import { InstancesView } from './views/InstancesView';
import { VersionsView } from './views/VersionsView';
import { ModsView } from './views/ModsView';
import { Automation } from './views/Automation';
import { AccountsView } from './views/AccountsView';
import { ConsoleView } from './views/ConsoleView';
import { SettingsView } from './views/SettingsView';
import { subscribeToCore, useStore } from './store/useStore';
import { Logo } from './components/Shell';

export default function App() {
  const view = useStore((s) => s.view);
  const ready = useStore((s) => s.ready);
  const reduceTransparency = useStore((s) => s.settings.reduceTransparency);

  useEffect(() => {
    const unsubscribe = subscribeToCore();
    void useStore.getState().actions.init();
    return unsubscribe;
  }, []);

  useEffect(() => {
    document.body.style.setProperty('backdrop-filter', reduceTransparency ? 'none' : '');
  }, [reduceTransparency]);

  if (!ready) return <BootScreen />;

  return (
    <Shell>
      <GlobalSearch />
      {view === 'play' && <Play />}
      {view === 'instances' && <InstancesView />}
      {view === 'versions' && <VersionsView />}
      {view === 'mods' && <ModsView />}
      {view === 'automation' && <Automation />}
      {view === 'accounts' && <AccountsView />}
      {view === 'console' && <ConsoleView />}
      {view === 'settings' && <SettingsView />}
    </Shell>
  );
}

function BootScreen() {
  const version = useStore((s) => s.version);
  return (
    <div className="relative z-10 grid h-full place-items-center">
      <div className="flex flex-col items-center">
        <div className="animate-[float_6s_ease-in-out_infinite]">
          <Logo size={72} />
        </div>
        <h1 className="mt-6 text-[26px] font-extrabold tracking-tight">
          AXIOM <span className="accent-grad-text">Launcher</span>
        </h1>
        <p className="mt-1.5 text-[12.5px] text-mist-400">Подготовка окружения, проверка Java, синхронизация манифеста…</p>
        <div className="mt-7 h-1 w-[280px] overflow-hidden rounded-full bg-white/[0.08]">
          <div className="h-full w-1/3 accent-bg" style={{ animation: 'shimmer 1.3s ease-in-out infinite' }} />
        </div>
        <p className="mt-3 font-mono text-[11px] text-mist-400">v{version}</p>
      </div>
    </div>
  );
}
