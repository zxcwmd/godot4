import crypto from 'node:crypto';
import fs from 'node:fs';
import { paths, ensureDir } from './paths';
import { JsonStore, uid } from './store';
import { logger } from './logger';
import type { Account } from '../../shared/types';

/** UUID офлайн-игры: то же, что делает Java (nameUUIDFromBytes("OfflinePlayer:<ник")). */
export function offlineUuid(name: string): string {
  const md5 = crypto.createHash('md5').update(`OfflinePlayer:${name}`, 'utf8').digest();
  md5[6] = (md5[6] & 0x0f) | 0x30; // version 3
  md5[8] = (md5[8] & 0x3f) | 0x80; // variant
  const hex = md5.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export class AccountManager {
  private store: JsonStore<{ accounts: Account[] }>;
  private tokens = new Map<string, { accessToken: string; expiresAt: number }>();

  constructor() {
    this.store = new JsonStore(paths.accountsFile, { accounts: [] });
  }

  list(): Account[] {
    return this.store.get().accounts;
  }

  private save(accounts: Account[]) {
    this.store.set({ accounts });
  }

  addOffline(name: string): Account {
    const clean = name.trim().slice(0, 16);
    const existing = this.list().find((a) => a.type === 'offline' && a.name.toLowerCase() === clean.toLowerCase());
    if (existing) return existing;
    const account: Account = {
      id: uid('acc'),
      type: 'offline',
      name: clean,
      uuid: offlineUuid(clean),
      addedAt: Date.now(),
      valid: true,
    };
    this.save([...this.list(), account]);
    logger.success(`Офлайн-аккаунт «${clean}» добавлен`, 'launcher');
    return account;
  }

  remove(id: string) {
    this.save(this.list().filter((a) => a.id !== id));
    this.tokens.delete(id);
  }

  get(id: string) {
    return this.list().find((a) => a.id === id);
  }

  markUsed(id: string) {
    this.save(this.list().map((a) => (a.id === id ? { ...a, lastUsed: Date.now() } : a)));
  }

  tokenFor(id: string) {
    return this.tokens.get(id) ?? null;
  }

  /**
   * Вход через Microsoft по device-code flow (так же, как официальный лаунчер в «коде устройства»).
   * Код показываем в UI, пользователь вводит его на microsoft.com/link.
   */
  async loginMicrosoft(
    username: string,
    onCode: (info: { code: string; url: string; expiresIn: number }) => void,
  ): Promise<Account> {
    const cacheDir = paths.accountCache(username);
    ensureDir(cacheDir);
    logger.info(`Начинаю вход Microsoft для «${username}»…`, 'network');
    // Динамический импорт: пакет CJS, тяжеловат — грузим только при реальном входе
    const { Authflow } = await import('prismarine-auth');
    const flow = new Authflow(
      username,
      cacheDir,
      { flow: 'live' },
      (code: { user_code?: string; verification_uri?: string; expires_in?: number; device_code?: string } | string) => {
        const value = typeof code === 'string' ? code : code?.user_code;
        if (value) {
          onCode({
            code: value,
            url: (typeof code === 'object' && code.verification_uri) || 'https://www.microsoft.com/link',
            expiresIn: (typeof code === 'object' && code.expires_in) || 900,
          });
        }
      },
    );
    const result = await flow.getMinecraftJavaToken({ fetchProfile: true });
    const profile = (result as { profile?: { id?: string; name?: string } }).profile;
    const name = profile?.name ?? username;
    const account: Account = this.list().find((a) => a.type === 'microsoft' && a.name === name) ?? {
      id: uid('acc'),
      type: 'microsoft',
      name,
      uuid: profile?.id ?? offlineUuid(name),
      cacheDir,
      addedAt: Date.now(),
    };
    account.uuid = profile?.id ?? account.uuid;
    account.name = name;
    account.valid = true;
    account.cacheDir = cacheDir;
    this.tokens.set(account.id, {
      accessToken: (result as { token: string }).token,
      expiresAt: Date.now() + 1000 * 60 * 60 * 20,
    });
    const others = this.list().filter((a) => a.id !== account.id);
    this.save([...others, account]);
    logger.success(`Аккаунт Minecraft «${name}» авторизован`, 'network');
    return account;
  }

  /** Обновление токена для бота/повторного запуска без нового входа. */
  async refresh(account: Account): Promise<string | null> {
    if (account.type === 'offline') return '0';
    const cached = this.tokens.get(account.id);
    if (cached && cached.expiresAt > Date.now()) return cached.accessToken;
    try {
      const { Authflow } = await import('prismarine-auth');
      const flow = new Authflow(account.name, account.cacheDir ?? paths.accountCache(account.name), { flow: 'live' });
      const result = await flow.getMinecraftJavaToken({ fetchProfile: true });
      this.tokens.set(account.id, {
        accessToken: (result as { token: string }).token,
        expiresAt: Date.now() + 1000 * 60 * 60 * 20,
      });
      return (result as { token: string }).token;
    } catch (e) {
      logger.warn(`Не удалось обновить токен «${account.name}»: ${(e as Error).message}`, 'network');
      this.save(this.list().map((a) => (a.id === account.id ? { ...a, valid: false } : a)));
      return null;
    }
  }

  avatarUrl(account: Account) {
    if (account.type === 'microsoft') return `https://crafatar.com/avatars/${account.uuid}?size=96&overlay`;
    return `https://minotar.net/helm/${encodeURIComponent(account.name)}/96.png`;
  }

  /** Профиль игрока из Mojang API (аватар/скины для офлайн-ников через minotar). */
  ensureDirs() {
    ensureDir(paths.root);
    void fs;
  }
}

export const accounts = new AccountManager();
