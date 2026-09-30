import { useState } from 'react';
import clsx from 'clsx';
import { Users, Plus, Trash2, ShieldCheck, Gamepad2, KeyRound, ExternalLink, Copy, Check, UserRound, Star, Bot } from 'lucide-react';
import { useStore } from '@/store/useStore';
import { Badge, Button, Card, Dot, IconButton, Input, Modal, SectionTitle, Toggle, EmptyState } from '@/components/ui';
import { timeAgo } from '@/lib/format';
import { isElectron } from '@/lib/api';

export function AccountsView() {
  const accounts = useStore((s) => s.accounts);
  const bots = useStore((s) => s.bots);
  const msaCode = useStore((s) => s.msaCode);
  const actions = useStore((s) => s.actions);
  const [offlineName, setOfflineName] = useState('');
  const [msUsername, setMsUsername] = useState('');
  const [msOpen, setMsOpen] = useState(false);
  const [msBusy, setMsBusy] = useState(false);
  const [copied, setCopied] = useState(false);

  return (
    <div className="page-enter">
      <SectionTitle icon={<Users size={16} />} title="Аккаунты" subtitle="Microsoft для онлайн-серверов и офлайн-профили для локальной игры" />

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-[1.4fr_1fr]">
        <div className="space-y-3">
          {accounts.length === 0 && (
            <EmptyState icon={<UserRound size={24} />} title="Аккаунтов нет" text="Войдите через Microsoft (рекомендуется для серверов) или создайте офлайн-профиль." />
          )}
          {accounts.map((account, index) => {
            const usedBy = bots.filter((b) => b.accountId === account.id);
            return (
              <Card key={account.id} hover className="relative overflow-hidden">
                {index === 0 && <span className="absolute inset-y-0 left-0 w-[3px] accent-bg" />}
                <div className="flex items-center gap-4">
                  <div className="relative">
                    <img src={account.avatar} alt="" className="h-14 w-14 rounded-2xl border border-white/10 bg-white/[0.05] object-cover" />
                    <span className="absolute -bottom-1 -right-1 grid h-5 w-5 place-items-center rounded-lg border border-white/10 bg-ink-900">
                      {account.type === 'microsoft' ? <ShieldCheck size={12} className="text-emerald-400" /> : <Gamepad2 size={12} className="text-sky-400" />}
                    </span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="truncate text-[16px] font-extrabold tracking-tight">{account.name}</p>
                      {index === 0 && <Badge tone="accent"><Star size={10} /> основной</Badge>}
                      <Badge tone={account.type === 'microsoft' ? 'good' : 'neutral'}>{account.type === 'microsoft' ? 'Microsoft' : 'офлайн'}</Badge>
                      {account.valid === false && <Badge tone="bad">токен истёк</Badge>}
                    </div>
                    <p className="mt-1 truncate font-mono text-[11px] text-mist-400">{account.uuid}</p>
                    <div className="mt-1.5 flex flex-wrap items-center gap-3 text-[11.5px] text-mist-400">
                      <span className="inline-flex items-center gap-1.5">
                        <Dot tone={account.valid === false ? 'bad' : 'good'} /> {account.type === 'microsoft' ? 'сессия активна' : 'локальный профиль'}
                      </span>
                      <span>добавлен {timeAgo(account.addedAt)}</span>
                      {usedBy.length > 0 && (
                        <span className="inline-flex items-center gap-1.5">
                          <Bot size={11} /> используется: {usedBy.map((b) => b.name).join(', ')}
                        </span>
                      )}
                    </div>
                  </div>
                  <div className="flex shrink-0 items-center gap-1.5">
                    {index !== 0 && (
                      <Button
                        size="sm"
                        variant="outline"
                        icon={<Star size={13} />}
                        onClick={() => {
                          const rest = accounts.filter((a) => a.id !== account.id);
                          useStore.setState({ accounts: [account, ...rest] });
                          actions.toast({ kind: 'info', title: `Основной аккаунт: ${account.name}` });
                        }}
                      >
                        Сделать основным
                      </Button>
                    )}
                    <IconButton size={32} className="hover:!text-rose-300" onClick={() => actions.removeAccount(account.id)}>
                      <Trash2 size={14} />
                    </IconButton>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>

        <div className="space-y-4">
          <Card>
            <SectionTitle icon={<ShieldCheck size={16} />} title="Вход через Microsoft" subtitle="Официальная авторизация: скины, плащи, доступ к любым серверам" />
            <div className="space-y-3">
              <Input value={msUsername} onChange={(e) => setMsUsername(e.target.value)} placeholder="Ник или e-mail (для кэша токенов)" icon={<UserRound size={15} />} />
              <Button
                variant="primary"
                full
                icon={<KeyRound size={16} />}
                loading={msBusy}
                onClick={async () => {
                  setMsBusy(true);
                  setMsOpen(true);
                  await actions.loginMicrosoft(msUsername || 'AXIOM');
                  setMsBusy(false);
                }}
              >
                Войти по коду устройства
              </Button>
              <p className="text-[11.5px] leading-snug text-mist-400">
                Откроется окно с кодом: введите его на microsoft.com/link. Токены кэшируются локально (20 часов), повторный вход не нужен.
              </p>
            </div>
          </Card>

          <Card>
            <SectionTitle icon={<Gamepad2 size={16} />} title="Офлайн-профиль" subtitle="Для локальных серверов и тестовых миров" />
            <div className="flex gap-2">
              <Input value={offlineName} onChange={(e) => setOfflineName(e.target.value)} placeholder="Ник (до 16 символов)" maxLength={16} />
              <Button
                variant="outline"
                icon={<Plus size={15} />}
                disabled={!offlineName.trim()}
                onClick={async () => {
                  await actions.addOfflineAccount(offlineName.trim());
                  setOfflineName('');
                }}
              >
                Добавить
              </Button>
            </div>
            <p className="mt-2.5 text-[11.5px] leading-snug text-mist-400">
              UUID генерируется так же, как в Java (<code className="font-mono">nameUUIDFromBytes</code>), поэтому ник и скин совпадут с офлайн-сервером.
            </p>
          </Card>

          <Card>
            <SectionTitle icon={<Bot size={16} />} title="Для ботов" subtitle="Автоматизация использует те же аккаунты" />
            <p className="text-[12.5px] leading-snug text-mist-300">
              Microsoft-аккаунт полностью поддерживается ботом: токен обновляется автоматически, при первом запуске может потребоваться ввод кода —
              он появится прямо в активности бота.
            </p>
            <div className="mt-3 flex gap-2">
              <Button size="sm" variant="outline" onClick={() => actions.setView('automation')}>К панели автоматизации</Button>
            </div>
          </Card>
        </div>
      </div>

      <Modal
        open={msOpen}
        onClose={() => setMsOpen(false)}
        title="Авторизация Microsoft"
        subtitle="Введите код на странице microsoft.com/link"
        width={520}
        footer={
          <>
            <Button variant="subtle" onClick={() => setMsOpen(false)}>Отмена</Button>
            <Button variant="primary" icon={<ExternalLink size={15} />} onClick={() => actions.openExternal(msaCode?.url ?? 'https://www.microsoft.com/link')}>
              Открыть страницу входа
            </Button>
          </>
        }
      >
        <div className="grid place-items-center py-4">
          {msaCode ? (
            <>
              <button
                onClick={() => {
                  navigator.clipboard?.writeText(msaCode.code);
                  setCopied(true);
                  setTimeout(() => setCopied(false), 1800);
                }}
                className="group flex items-center gap-3 rounded-3xl border border-[var(--accent-ring)] accent-soft-bg px-8 py-5"
              >
                <span className="font-mono text-[38px] font-extrabold tracking-[0.18em] accent-text">{msaCode.code}</span>
                {copied ? <Check size={18} className="text-emerald-400" /> : <Copy size={18} className="text-mist-400 group-hover:text-white" />}
              </button>
              <p className="mt-4 text-center text-[13px] text-mist-300">
                Откройте <span className="accent-text font-semibold">microsoft.com/link</span> и введите код.
                <br />
                <span className="text-mist-400">Ожидание подтверждения…</span>
              </p>
              <div className="mt-4 flex items-center gap-2 text-[12px] text-mist-400">
                <Dot tone="warn" pulse /> Ждём ответа Microsoft
              </div>
            </>
          ) : (
            <div className="flex items-center gap-3 py-6 text-[13px] text-mist-400">
              <Dot tone="warn" pulse /> Запрашиваю код у Microsoft…
            </div>
          )}
        </div>
        <div className={clsx('mt-2 rounded-2xl border border-white/8 p-3.5 text-[11.5px] text-mist-400', !isElectron && 'opacity-70')}>
          {isElectron
            ? 'Код выдаётся напрямую серверами Microsoft. AXIOM не видит ваш пароль — используется тот же протокол, что и в официальном лаунчере.'
            : 'Это веб-превью: вход выполняется в демо-режиме и сразу подтверждается, чтобы показать весь поток интерфейса.'}
        </div>
      </Modal>
    </div>
  );
}
