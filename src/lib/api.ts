import type { AxiomEvent } from '@shared/types';
import { mockBackend } from './mock';

interface AxiomBridge {
  invoke: (channel: string, payload?: unknown) => Promise<unknown>;
  on: (handler: (event: unknown) => void) => () => void;
  window: {
    minimize: () => Promise<void>;
    maximize: () => Promise<boolean>;
    close: () => Promise<void>;
    isMaximized: () => Promise<boolean>;
  };
}

const bridge: AxiomBridge | undefined = (globalThis as { axiom?: AxiomBridge }).axiom;

/** true, когда интерфейс работает внутри Electron (иначе — веб-превью с демо-ядром). */
export const isElectron = !!bridge;

export const api = {
  invoke: async <T = unknown>(channel: string, payload?: unknown): Promise<T> => {
    if (bridge) return (await bridge.invoke(channel, payload)) as T;
    return (await mockBackend.invoke(channel, payload)) as T;
  },
  on: (handler: (e: AxiomEvent) => void): (() => void) => {
    if (bridge) {
      return bridge.on((raw) => handler(raw as AxiomEvent));
    }
    return mockBackend.on(handler);
  },
  window: {
    minimize: () => bridge?.window.minimize?.() ?? Promise.resolve(),
    maximize: () => bridge?.window.maximize?.() ?? Promise.resolve(false),
    close: () => bridge?.window.close?.() ?? Promise.resolve(),
    isMaximized: () => bridge?.window.isMaximized?.() ?? Promise.resolve(false),
  },
};
