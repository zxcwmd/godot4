import { app, BrowserWindow, ipcMain, shell, session } from 'electron';
import path from 'node:path';
import { logger } from './services/logger';
import { createCore, registerIpc, APP_VERSION } from './ipc';
import type { AxiomEvent } from '../shared/types';

const isDev = process.env.NODE_ENV !== 'production' && !app.isPackaged;
const DEV_URL = process.env.VITE_DEV_SERVER_URL ?? 'http://localhost:5173';

let mainWindow: BrowserWindow | null = null;

function broadcast(event: AxiomEvent) {
  for (const win of BrowserWindow.getAllWindows()) {
    if (!win.isDestroyed()) win.webContents.send('axiom:event', event);
  }
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 1080,
    minHeight: 700,
    show: false,
    backgroundColor: '#04050c',
    titleBarStyle: process.platform === 'darwin' ? 'hiddenInset' : 'hidden',
    trafficLightPosition: { x: 18, y: 22 },
    frame: process.platform === 'darwin',
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
      spellcheck: false,
      backgroundThrottling: false,
    },
  });

  mainWindow.once('ready-to-show', () => {
    mainWindow?.show();
    logger.info(`AXIOM ${APP_VERSION} запущен (${process.platform}, Electron ${process.versions.electron})`, 'launcher');
  });

  if (isDev) {
    void mainWindow.loadURL(DEV_URL);
    mainWindow.webContents.openDevTools({ mode: 'detach' });
  } else {
    void mainWindow.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
  }

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    void shell.openExternal(url);
    return { action: 'deny' };
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

/* ─────────────── Горячие клавиши окна ─────────────── */
ipcMain.handle('axiom:window:minimize', () => mainWindow?.minimize());
ipcMain.handle('axiom:window:maximize', () => {
  if (!mainWindow) return false;
  if (mainWindow.isMaximized()) mainWindow.unmaximize();
  else mainWindow.maximize();
  return mainWindow.isMaximized();
});
ipcMain.handle('axiom:window:close', () => mainWindow?.close());
ipcMain.handle('axiom:window:is-maximized', () => mainWindow?.isMaximized() ?? false);

app.whenReady().then(() => {
  const core = createCore(broadcast);
  registerIpc(core);

  // CSP: разрешаем картинки/шрифты CDN, иначе UI останется без иконок каталога
  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        'Content-Security-Policy': [
          "default-src 'self' 'unsafe-inline' data: blob: https:; img-src 'self' data: blob: https:; media-src 'self' data: blob: https:;",
        ],
      },
    });
  });

  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });

  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
  });

  app.on('before-quit', async () => {
    logger.info('Завершение работы AXIOM…', 'launcher');
    try {
      await core.bots.stopAll();
      for (const handle of core.running.values()) handle.stop();
    } catch {
      /* не мешаем выходу */
    }
  });
});

process.on('uncaughtException', (err) => {
  logger.error(`Необработанная ошибка: ${err.stack ?? err.message}`, 'launcher');
});
process.on('unhandledRejection', (reason) => {
  logger.error(`Необработанный reject: ${String(reason)}`, 'launcher');
});
