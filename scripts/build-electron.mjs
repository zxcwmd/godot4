// Сборка main/preload процессов Electron через esbuild.
// Внешние пакеты (mineflayer, prismarine-* и т.п.) не бандлятся — грузятся из node_modules.
import { build } from 'esbuild';
import { rmSync, mkdirSync } from 'node:fs';

const outdir = 'dist-electron';
rmSync(outdir, { recursive: true, force: true });
mkdirSync(outdir, { recursive: true });

const common = {
  bundle: true,
  platform: 'node',
  target: 'node20',
  format: 'cjs',
  sourcemap: false,
  minify: false,
  packages: 'external',
  logLevel: 'info',
  define: { 'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV ?? 'development') },
};

await build({ ...common, entryPoints: ['electron/main.ts'], outfile: `${outdir}/main.cjs` });
await build({ ...common, entryPoints: ['electron/preload.ts'], outfile: `${outdir}/preload.cjs` });

console.log('\x1b[35m✓ Electron main собран в dist-electron\x1b[0m');
