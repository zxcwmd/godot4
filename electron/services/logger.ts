import fs from 'node:fs';
import path from 'node:path';
import { EventEmitter } from 'node:events';
import type { LogEntry } from '../../shared/types';
import { paths, ensureDir } from './paths';

/** Шина логов: кольцевой буфер + файл + рассылка в UI. */
class Logger extends EventEmitter {
  private buffer: LogEntry[] = [];
  private max = 3000;
  private seq = 0;

  constructor() {
    super();
    this.setMaxListeners(50);
  }

  log(level: LogEntry['level'], source: LogEntry['source'], message: string) {
    const entry: LogEntry = {
      id: `log_${++this.seq}`,
      ts: Date.now(),
      level,
      source,
      message: String(message ?? ''),
    };
    this.buffer.push(entry);
    if (this.buffer.length > this.max) this.buffer.splice(0, this.buffer.length - this.max);
    this.emit('entry', entry);
    if (process.env.NODE_ENV !== 'production') {
      const tag = `[${source}]`.padEnd(12);
      const color = { debug: 90, info: 36, warn: 33, error: 31, success: 32 }[level] ?? 37;
      console.log(`\x1b[${color}m${tag}\x1b[0m ${message}`);
    }
    this.toFile(entry);
    return entry;
  }

  private toFile(entry: LogEntry) {
    try {
      ensureDir(paths.logs);
      const day = new Date().toISOString().slice(0, 10);
      fs.appendFileSync(
        path.join(paths.logs, `axiom-${day}.log`),
        `${new Date(entry.ts).toISOString()} [${entry.level}] [${entry.source}] ${entry.message}\n`,
      );
    } catch {
      /* логи не должны ломать приложение */
    }
  }

  debug = (m: string, s: LogEntry['source'] = 'launcher') => this.log('debug', s, m);
  info = (m: string, s: LogEntry['source'] = 'launcher') => this.log('info', s, m);
  warn = (m: string, s: LogEntry['source'] = 'launcher') => this.log('warn', s, m);
  error = (m: string, s: LogEntry['source'] = 'launcher') => this.log('error', s, m);
  success = (m: string, s: LogEntry['source'] = 'launcher') => this.log('success', s, m);

  history() {
    return this.buffer;
  }

  clear() {
    this.buffer = [];
  }
}

export const logger = new Logger();
