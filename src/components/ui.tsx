import React from 'react';
import clsx from 'clsx';
import { motion, AnimatePresence } from 'framer-motion';
import { Loader2, X, ChevronDown, Check } from 'lucide-react';

/* ─────────────────────────── Кнопки ─────────────────────────── */

type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'ghost' | 'outline' | 'danger' | 'subtle';
  size?: 'sm' | 'md' | 'lg' | 'xl';
  icon?: React.ReactNode;
  iconRight?: React.ReactNode;
  loading?: boolean;
  full?: boolean;
};

export function Button({ variant = 'ghost', size = 'md', icon, iconRight, loading, full, className, children, disabled, ...rest }: ButtonProps) {
  const sizes: Record<string, string> = {
    sm: 'h-8 px-3 text-[12.5px] rounded-lg gap-1.5',
    md: 'h-10 px-4 text-[13.5px] rounded-xl gap-2',
    lg: 'h-12 px-5 text-[15px] rounded-2xl gap-2.5',
    xl: 'h-14 px-7 text-[16px] rounded-2xl gap-3',
  };
  const variants: Record<string, string> = {
    primary: 'btn-primary',
    ghost: 'btn-ghost text-mist-200',
    outline: 'border border-white/12 bg-white/[0.03] hover:bg-white/[0.07] hover:border-white/25 text-mist-100',
    danger: 'bg-rose-500/15 border border-rose-400/30 text-rose-200 hover:bg-rose-500/25',
    subtle: 'text-mist-300 hover:text-white hover:bg-white/[0.06]',
  };
  return (
    <button
      className={clsx('relative inline-flex items-center justify-center font-semibold tracking-tight transition-all select-none whitespace-nowrap', sizes[size], variants[variant], full && 'w-full', className)}
      disabled={disabled || loading}
      {...rest}
    >
      {loading ? <Loader2 size={size === 'sm' ? 14 : 17} className="animate-spin" /> : icon}
      {children}
      {iconRight}
    </button>
  );
}

export function IconButton({ className, children, size = 34, ...rest }: React.ButtonHTMLAttributes<HTMLButtonElement> & { size?: number }) {
  return (
    <button
      {...rest}
      style={{ width: size, height: size }}
      className={clsx(
        'inline-flex items-center justify-center rounded-xl text-mist-300 transition-all hover:text-white hover:bg-white/[0.08] active:scale-95 disabled:opacity-40 disabled:pointer-events-none no-drag',
        className,
      )}
    >
      {children}
    </button>
  );
}

/* ─────────────────────────── Контейнеры ─────────────────────────── */

export function Card({ className, children, hover, padded = true, ...rest }: React.HTMLAttributes<HTMLDivElement> & { hover?: boolean; padded?: boolean }) {
  return (
    <div {...rest} className={clsx('glass rounded-3xl', padded && 'p-5', hover && 'glass-hover', className)}>
      {children}
    </div>
  );
}

export function SectionTitle({ title, subtitle, action, icon }: { title: string; subtitle?: string; action?: React.ReactNode; icon?: React.ReactNode }) {
  return (
    <div className="mb-4 flex items-end justify-between gap-4">
      <div className="flex items-center gap-3">
        {icon && <div className="grid h-9 w-9 place-items-center rounded-xl accent-soft-bg accent-text">{icon}</div>}
        <div>
          <h2 className="text-[17px] font-extrabold tracking-tight text-mist-100">{title}</h2>
          {subtitle && <p className="mt-0.5 text-[12.5px] text-mist-400">{subtitle}</p>}
        </div>
      </div>
      {action}
    </div>
  );
}

export function Badge({ children, tone = 'neutral', className }: { children: React.ReactNode; tone?: 'neutral' | 'good' | 'warn' | 'bad' | 'accent'; className?: string }) {
  const tones = {
    neutral: 'bg-white/[0.06] text-mist-300 border-white/10',
    good: 'bg-emerald-400/12 text-emerald-300 border-emerald-400/25',
    warn: 'bg-amber-400/12 text-amber-300 border-amber-400/25',
    bad: 'bg-rose-400/12 text-rose-300 border-rose-400/25',
    accent: 'accent-soft-bg accent-text border-transparent',
  };
  return <span className={clsx('inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wide', tones[tone], className)}>{children}</span>;
}

export function Dot({ tone = 'good', pulse }: { tone?: 'good' | 'bad' | 'warn' | 'idle'; pulse?: boolean }) {
  const colors = { good: 'text-emerald-400 bg-emerald-400', bad: 'text-rose-400 bg-rose-400', warn: 'text-amber-400 bg-amber-400', idle: 'text-slate-500 bg-slate-500' };
  return (
    <span className={clsx('relative inline-flex', colors[tone])}>
      <span className={clsx('dot', pulse && 'animate-pulse')} />
      {pulse && <span className="absolute inset-0 rounded-full bg-current opacity-40 animate-ping" />}
    </span>
  );
}

/* ─────────────────────────── Формы ─────────────────────────── */

export function Input({ className, icon, ...rest }: React.InputHTMLAttributes<HTMLInputElement> & { icon?: React.ReactNode }) {
  return (
    <div className={clsx('field flex h-10 items-center gap-2 rounded-xl px-3 text-[13.5px]', className)}>
      {icon && <span className="text-mist-400">{icon}</span>}
      <input {...rest} className="w-full bg-transparent text-mist-100 placeholder:text-mist-400/70 outline-none" />
    </div>
  );
}

export function Select<T extends string>({ value, onChange, options, className, placeholder }: { value: T; onChange: (v: T) => void; options: { value: T; label: string }[]; className?: string; placeholder?: string }) {
  const [open, setOpen] = React.useState(false);
  const ref = React.useRef<HTMLDivElement>(null);
  React.useEffect(() => {
    const onDoc = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDoc);
    return () => document.removeEventListener('mousedown', onDoc);
  }, []);
  const current = options.find((o) => o.value === value);
  return (
    <div ref={ref} className={clsx('relative', className)}>
      <button type="button" onClick={() => setOpen((o) => !o)} className={clsx('field flex h-10 w-full items-center justify-between gap-2 rounded-xl px-3 text-[13.5px] text-mist-100', open && 'border-[var(--accent-ring)]')}>
        <span className="truncate">{current?.label ?? placeholder ?? '—'}</span>
        <ChevronDown size={15} className={clsx('shrink-0 text-mist-400 transition-transform', open && 'rotate-180')} />
      </button>
      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ opacity: 0, y: -6, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -6, scale: 0.98 }}
            transition={{ duration: 0.16 }}
            className="glass scroll-thin absolute z-50 mt-2 max-h-64 w-full overflow-y-auto rounded-2xl p-1.5"
          >
            {options.map((o) => (
              <button
                key={o.value}
                type="button"
                onClick={() => {
                  onChange(o.value);
                  setOpen(false);
                }}
                className={clsx(
                  'flex w-full items-center justify-between gap-2 rounded-xl px-3 py-2 text-left text-[13px] transition-colors',
                  o.value === value ? 'accent-soft-bg accent-text font-semibold' : 'text-mist-200 hover:bg-white/[0.06]',
                )}
              >
                <span className="truncate">{o.label}</span>
                {o.value === value && <Check size={14} />}
              </button>
            ))}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export function Toggle({ checked, onChange, label, hint, disabled }: { checked: boolean; onChange: (v: boolean) => void; label?: string; hint?: string; disabled?: boolean }) {
  return (
    <label className={clsx('flex cursor-pointer items-center justify-between gap-4', disabled && 'cursor-not-allowed opacity-50')}>
      {(label || hint) && (
        <span className="min-w-0">
          {label && <span className="block text-[13.5px] font-semibold text-mist-100">{label}</span>}
          {hint && <span className="mt-0.5 block text-[12px] leading-snug text-mist-400">{hint}</span>}
        </span>
      )}
      <button
        type="button"
        disabled={disabled}
        onClick={() => onChange(!checked)}
        className={clsx('relative h-6 w-11 shrink-0 rounded-full border transition-all duration-300', checked ? 'accent-bg border-transparent accent-glow' : 'border-white/10 bg-white/[0.08]')}
      >
        <motion.span layout transition={{ type: 'spring', stiffness: 500, damping: 32 }} className={clsx('absolute top-[3px] h-4 w-4 rounded-full bg-white shadow', checked ? 'left-[25px]' : 'left-[3px]')} />
      </button>
    </label>
  );
}

export function Slider({ value, onChange, min, max, step = 1, label, format, suffix }: { value: number; onChange: (v: number) => void; min: number; max: number; step?: number; label?: string; format?: (v: number) => string; suffix?: string }) {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div>
      {label && (
        <div className="mb-2 flex items-center justify-between text-[13px]">
          <span className="font-semibold text-mist-200">{label}</span>
          <span className="accent-text font-mono font-bold">{format ? format(value) : `${value}${suffix ?? ''}`}</span>
        </div>
      )}
      <input type="range" min={min} max={max} step={step} value={value} onChange={(e) => onChange(Number(e.target.value))} style={{ ['--fill' as never]: `${pct}%` }} />
    </div>
  );
}

export function Segmented<T extends string>({ value, onChange, options, size = 'md', className }: { value: T; onChange: (v: T) => void; options: { value: T; label: string; icon?: React.ReactNode }[]; size?: 'sm' | 'md'; className?: string }) {
  return (
    <div className={clsx('glass-soft inline-flex rounded-xl p-1', className)}>
      {options.map((o) => (
        <button
          key={o.value}
          onClick={() => onChange(o.value)}
          className={clsx(
            'relative inline-flex items-center gap-1.5 rounded-lg font-semibold transition-all',
            size === 'sm' ? 'px-2.5 py-1 text-[12px]' : 'px-3.5 py-1.5 text-[12.5px]',
            value === o.value ? 'text-ink-950' : 'text-mist-300 hover:text-white',
          )}
        >
          {value === o.value && <motion.span layoutId={`seg-${options.map((x) => x.value).join('')}`} className="accent-bg absolute inset-0 rounded-lg" transition={{ type: 'spring', stiffness: 500, damping: 34 }} />}
          <span className="relative z-10 inline-flex items-center gap-1.5">
            {o.icon}
            {o.label}
          </span>
        </button>
      ))}
    </div>
  );
}

/* ─────────────────────────── Прогресс ─────────────────────────── */

export function ProgressBar({ value, indeterminate, height = 6, className, glow }: { value: number; indeterminate?: boolean; height?: number; className?: string; glow?: boolean }) {
  return (
    <div className={clsx('w-full overflow-hidden rounded-full bg-white/[0.07]', className)} style={{ height }}>
      <motion.div
        className={clsx('h-full rounded-full accent-bg', glow && 'accent-glow')}
        initial={false}
        animate={{ width: indeterminate ? '40%' : `${Math.max(0, Math.min(100, value))}%` }}
        transition={{ type: 'spring', stiffness: 120, damping: 22 }}
        style={indeterminate ? { animation: 'shimmer 1.4s ease-in-out infinite' } : undefined}
      />
    </div>
  );
}

export function Sparkline({ data, height = 46, color = 'var(--accent)' }: { data: number[]; height?: number; color?: string }) {
  const max = Math.max(1, ...data);
  const w = 100;
  const points = data.length
    ? data.map((v, i) => `${(i / Math.max(1, data.length - 1)) * w},${height - (v / max) * (height - 6) - 3}`).join(' ')
    : `0,${height - 3} ${w},${height - 3}`;
  return (
    <svg viewBox={`0 0 ${w} ${height}`} preserveAspectRatio="none" className="h-full w-full overflow-visible">
      <defs>
        <linearGradient id={`spark-${color.replace(/[^a-z0-9]/gi, '')}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.5" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <polyline points={`0,${height} ${points} ${w},${height}`} fill={`url(#spark-${color.replace(/[^a-z0-9]/gi, '')})`} stroke="none" />
      <polyline points={points} fill="none" stroke={color} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" vectorEffect="non-scaling-stroke" />
    </svg>
  );
}

export function RingProgress({ value, size = 58, stroke = 5, children }: { value: number; size?: number; stroke?: number; children?: React.ReactNode }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  return (
    <div className="relative grid place-items-center" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="-rotate-90">
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth={stroke} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke="var(--accent)"
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={c - (Math.max(0, Math.min(100, value)) / 100) * c}
          style={{ transition: 'stroke-dashoffset 0.5s cubic-bezier(0.22,1,0.36,1)' }}
        />
      </svg>
      <div className="absolute inset-0 grid place-items-center">{children}</div>
    </div>
  );
}

/* ─────────────────────────── Модалка ─────────────────────────── */

export function Modal({ open, onClose, title, subtitle, children, width = 560, footer }: { open: boolean; onClose: () => void; title: string; subtitle?: string; children: React.ReactNode; width?: number; footer?: React.ReactNode }) {
  React.useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    if (open) document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open, onClose]);
  return (
    <AnimatePresence>
      {open && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-[100] grid place-items-center bg-black/65 p-6 backdrop-blur-md" onClick={onClose}>
          <motion.div
            initial={{ opacity: 0, y: 18, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 12, scale: 0.98 }}
            transition={{ type: 'spring', stiffness: 420, damping: 34 }}
            style={{ width }}
            onClick={(e) => e.stopPropagation()}
            className="glass max-h-[86vh] overflow-y-auto scroll-thin rounded-3xl p-6"
          >
            <div className="mb-5 flex items-start justify-between gap-4">
              <div>
                <h3 className="text-[19px] font-extrabold tracking-tight">{title}</h3>
                {subtitle && <p className="mt-1 text-[13px] text-mist-400">{subtitle}</p>}
              </div>
              <IconButton onClick={onClose}>
                <X size={17} />
              </IconButton>
            </div>
            {children}
            {footer && <div className="mt-6 flex items-center justify-end gap-2">{footer}</div>}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

/* ─────────────────────────── Прочее ─────────────────────────── */

export function StatCard({ label, value, hint, icon, tone, className }: { label: string; value: React.ReactNode; hint?: string; icon?: React.ReactNode; tone?: 'accent' | 'good' | 'warn' | 'bad'; className?: string }) {
  const toneClass = tone === 'good' ? 'text-emerald-300' : tone === 'warn' ? 'text-amber-300' : tone === 'bad' ? 'text-rose-300' : 'accent-text';
  return (
    <Card className={clsx('relative overflow-hidden', className)} padded>
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="text-[11.5px] font-bold uppercase tracking-wider text-mist-400">{label}</div>
          <div className={clsx('mt-1.5 truncate text-[24px] font-extrabold tracking-tight', toneClass)}>{value}</div>
          {hint && <div className="mt-0.5 truncate text-[12px] text-mist-400">{hint}</div>}
        </div>
        {icon && <div className="grid h-10 w-10 shrink-0 place-items-center rounded-2xl accent-soft-bg accent-text">{icon}</div>}
      </div>
    </Card>
  );
}

export function EmptyState({ title, text, icon, action }: { title: string; text?: string; icon?: React.ReactNode; action?: React.ReactNode }) {
  return (
    <div className="grid place-items-center rounded-3xl border border-dashed border-white/10 px-6 py-14 text-center">
      {icon && <div className="mb-3 grid h-14 w-14 place-items-center rounded-3xl accent-soft-bg accent-text">{icon}</div>}
      <p className="text-[15px] font-bold text-mist-100">{title}</p>
      {text && <p className="mt-1 max-w-md text-[13px] text-mist-400">{text}</p>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return <div className={clsx('skeleton rounded-xl', className)} />;
}

export function Tooltip({ children, text }: { children: React.ReactNode; text: string }) {
  return (
    <span className="group/tt relative inline-flex">
      {children}
      <span className="glass pointer-events-none absolute -top-9 left-1/2 z-50 -translate-x-1/2 whitespace-nowrap rounded-lg px-2.5 py-1 text-[11.5px] font-semibold text-mist-100 opacity-0 transition-opacity group-hover/tt:opacity-100">
        {text}
      </span>
    </span>
  );
}
