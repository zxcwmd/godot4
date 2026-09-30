import { contextBridge, ipcRenderer } from 'electron';

/**
 * Мост UI ⇄ ядро. Renderer не имеет доступа к Node —
 * только к белому списку каналов через invoke + подписка на события.
 */
const api = {
  invoke: (channel: string, payload?: unknown) => ipcRenderer.invoke(channel, payload),
  on: (handler: (event: unknown) => void) => {
    const listener = (_e: unknown, data: unknown) => handler(data);
    ipcRenderer.on('axiom:event', listener);
    return () => ipcRenderer.removeListener('axiom:event', listener);
  },
  window: {
    minimize: () => ipcRenderer.invoke('axiom:window:minimize'),
    maximize: () => ipcRenderer.invoke('axiom:window:maximize'),
    close: () => ipcRenderer.invoke('axiom:window:close'),
    isMaximized: () => ipcRenderer.invoke('axiom:window:is-maximized'),
  },
};

contextBridge.exposeInMainWorld('axiom', api);

export type AxiomApi = typeof api;
