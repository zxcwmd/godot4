import { app } from 'electron';
import path from 'node:path';
import fs from 'node:fs';

/**
 * Структура каталогов AXIOM:
 *
 *  <userData>/
 *    config.json            — настройки лаунчера
 *    instances.json         — профили (версия + загрузчик + параметры)
 *    accounts.json          — аккаунты
 *    bots.json              — профили автоматизации
 *    logs/                  — логи лаунчера
 *    meta/                  — кэш манифестов Mojang / Modrinth
 *    shared/                — общие для всех сборок файлы игры
 *      versions/  libraries/  assets/  runtime/  modloaders/
 *    instances/<id>/        — игровая папка конкретной сборки (mods, saves, config…)
 */
export const paths = {
  get root() {
    return app.getPath('userData');
  },
  get config() {
    return path.join(this.root, 'config.json');
  },
  get instancesFile() {
    return path.join(this.root, 'instances.json');
  },
  get accountsFile() {
    return path.join(this.root, 'accounts.json');
  },
  get botsFile() {
    return path.join(this.root, 'bots.json');
  },
  get logs() {
    return path.join(this.root, 'logs');
  },
  get meta() {
    return path.join(this.root, 'meta');
  },
  get shared() {
    return path.join(this.root, 'shared');
  },
  get versions() {
    return path.join(this.shared, 'versions');
  },
  get libraries() {
    return path.join(this.shared, 'libraries');
  },
  get assets() {
    return path.join(this.shared, 'assets');
  },
  get runtime() {
    return path.join(this.shared, 'runtime');
  },
  get modloaders() {
    return path.join(this.shared, 'modloaders');
  },
  get instancesDir() {
    return path.join(this.root, 'instances');
  },
  instance(id: string) {
    return path.join(this.instancesDir, id);
  },
  accountCache(id: string) {
    return path.join(this.root, 'auth', id);
  },
};

export function ensureDir(dir: string) {
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

export function ensureBaseDirs() {
  for (const d of [
    paths.root,
    paths.logs,
    paths.meta,
    paths.shared,
    paths.versions,
    paths.libraries,
    paths.assets,
    paths.assets + '/indexes',
    paths.assets + '/objects',
    paths.runtime,
    paths.modloaders,
    paths.instancesDir,
  ]) {
    ensureDir(d);
  }
}
