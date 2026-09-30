import fs from 'node:fs';
import path from 'node:path';

/** Простейшее атомарное JSON-хранилище с кэшем в памяти. */
export class JsonStore<T> {
  private cache: T | null = null;
  private writeTimer: NodeJS.Timeout | null = null;

  constructor(
    private file: string,
    private defaults: T,
  ) {}

  get(): T {
    if (this.cache) return this.cache;
    try {
      const raw = fs.readFileSync(this.file, 'utf8');
      const parsed = JSON.parse(raw);
      this.cache = { ...this.defaults, ...parsed } as T;
    } catch {
      this.cache = structuredClone(this.defaults);
    }
    return this.cache!;
  }

  set(value: T) {
    this.cache = value;
    this.scheduleWrite();
  }

  patch(partial: Partial<T>) {
    this.set({ ...this.get(), ...partial });
  }

  private scheduleWrite() {
    if (this.writeTimer) clearTimeout(this.writeTimer);
    this.writeTimer = setTimeout(() => this.flush(), 120);
  }

  flush() {
    if (!this.cache) return;
    const dir = path.dirname(this.file);
    fs.mkdirSync(dir, { recursive: true });
    const tmp = `${this.file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(this.cache, null, 2), 'utf8');
    fs.renameSync(tmp, this.file);
  }
}

export function uid(prefix = 'id') {
  return `${prefix}_${Math.random().toString(36).slice(2, 9)}${Date.now().toString(36).slice(-4)}`;
}
