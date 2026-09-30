import { useEffect, useMemo, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, Layers, Boxes, Bot, Puzzle, Users, ArrowRight, CornerDownLeft } from 'lucide-react';
import { useStore, type View } from '@/store/useStore';
import clsx from 'clsx';

interface Hit {
  id: string;
  label: string;
  sub: string;
  icon: React.ReactNode;
  action: () => void;
  group: string;
}

export function GlobalSearch() {
  const open = useStore((s) => s.searchOpen);
  const setOpen = useStore((s) => s.actions.setSearchOpen);
  const instances = useStore((s) => s.instances);
  const versions = useStore((s) => s.versions);
  const bots = useStore((s) => s.bots);
  const actions = useStore((s) => s.actions);
  const [query, setQuery] = useState('');
  const [cursor, setCursor] = useState(0);

  const hits = useMemo<Hit[]>(() => {
    const q = query.trim().toLowerCase();
    const go = (view: View) => () => {
      actions.setView(view);
      setOpen(false);
    };
    const list: Hit[] = [
      { id: 'nav-play', label: 'Играть', sub: 'Запуск выбранной сборки', group: 'Разделы', icon: <ArrowRight size={15} />, action: go('play') },
      { id: 'nav-inst', label: 'Сборки', sub: 'Профили и их параметры', group: 'Разделы', icon: <Layers size={15} />, action: go('instances') },
      { id: 'nav-vers', label: 'Версии Minecraft', sub: 'Установка клиента и загрузчиков', group: 'Разделы', icon: <Boxes size={15} />, action: go('versions') },
      { id: 'nav-mods', label: 'Моды и шейдеры', sub: 'Каталог Modrinth', group: 'Разделы', icon: <Puzzle size={15} />, action: go('mods') },
      { id: 'nav-bots', label: 'Автоматизация', sub: 'Боты: шахта, зелья, ферма', group: 'Разделы', icon: <Bot size={15} />, action: go('automation') },
      { id: 'nav-acc', label: 'Аккаунты', sub: 'Microsoft и офлайн', group: 'Разделы', icon: <Users size={15} />, action: go('accounts') },
    ];
    for (const inst of instances) {
      list.push({
        id: `inst-${inst.id}`,
        label: inst.name,
        sub: `${inst.versionId}${inst.loader !== 'vanilla' ? ` · ${inst.loader}` : ''} · ${inst.ramMb} МБ`,
        group: 'Сборки',
        icon: <Layers size={15} />,
        action: () => {
          actions.selectInstance(inst.id);
          actions.setView('play');
          setOpen(false);
        },
      });
    }
    for (const bot of bots) {
      list.push({
        id: `bot-${bot.id}`,
        label: bot.name,
        sub: `${bot.host}:${bot.port} · ${bot.tasks.filter((t) => t.enabled).length} задач`,
        group: 'Боты',
        icon: <Bot size={15} />,
        action: () => {
          actions.selectBot(bot.id);
          actions.setView('automation');
          setOpen(false);
        },
      });
    }
    for (const v of versions.slice(0, 120)) {
      list.push({
        id: `ver-${v.id}`,
        label: `Установить ${v.id}`,
        sub: v.installed ? 'уже установлена — переустановить' : `${v.type === 'release' ? 'релиз' : v.type}`,
        group: 'Версии',
        icon: <Boxes size={15} />,
        action: () => {
          void actions.installVersion(v.id);
          actions.setView('versions');
          setOpen(false);
        },
      });
    }
    if (!q) return list.slice(0, 9);
    return list.filter((h) => `${h.label} ${h.sub} ${h.group}`.toLowerCase().includes(q)).slice(0, 12);
  }, [query, instances, bots, versions, actions, setOpen]);

  useEffect(() => setCursor(0), [query, open]);

  useEffect(() => {
    if (!open) setQuery('');
  }, [open]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!open) return;
      if (e.key === 'Escape') setOpen(false);
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        setCursor((c) => Math.min(hits.length - 1, c + 1));
      }
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        setCursor((c) => Math.max(0, c - 1));
      }
      if (e.key === 'Enter' && hits[cursor]) {
        e.preventDefault();
        hits[cursor].action();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, hits, cursor, setOpen]);

  return (
    <AnimatePresence>
      {open && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-[120] bg-black/60 p-6 pt-[12vh] backdrop-blur-md" onClick={() => setOpen(false)}>
          <motion.div
            initial={{ opacity: 0, y: -14, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -10, scale: 0.98 }}
            transition={{ type: 'spring', stiffness: 460, damping: 34 }}
            onClick={(e) => e.stopPropagation()}
            className="glass mx-auto w-full max-w-[640px] overflow-hidden rounded-3xl"
          >
            <div className="flex items-center gap-3 border-b border-white/[0.07] px-5 py-4">
              <Search size={18} className="accent-text" />
              <input
                autoFocus
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Введите: сборка, версия, бот, «1.20.1»…"
                className="flex-1 bg-transparent text-[15px] text-mist-100 placeholder:text-mist-400/70 outline-none"
              />
              <kbd className="rounded-md border border-white/10 bg-white/[0.06] px-1.5 py-0.5 font-mono text-[10px] text-mist-400">esc</kbd>
            </div>
            <div className="scroll-thin max-h-[52vh] overflow-y-auto p-2">
              {hits.map((hit, i) => (
                <button
                  key={hit.id}
                  onMouseEnter={() => setCursor(i)}
                  onClick={hit.action}
                  className={clsx('flex w-full items-center gap-3 rounded-2xl px-3.5 py-2.5 text-left transition-colors', i === cursor ? 'accent-soft-bg' : 'hover:bg-white/[0.05]')}
                >
                  <span className={clsx('grid h-9 w-9 shrink-0 place-items-center rounded-xl', i === cursor ? 'accent-text' : 'text-mist-400')}>{hit.icon}</span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[13.5px] font-bold">{hit.label}</span>
                    <span className="block truncate text-[11.5px] text-mist-400">{hit.sub}</span>
                  </span>
                  <span className="shrink-0 text-[10.5px] font-bold uppercase tracking-wide text-mist-400">{hit.group}</span>
                  {i === cursor && <CornerDownLeft size={14} className="shrink-0 accent-text" />}
                </button>
              ))}
              {!hits.length && <p className="py-10 text-center text-[13px] text-mist-400">Ничего не найдено</p>}
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
