/* ============================================================
   AXIOM Automation Engine — реальные задачи для mineflayer-бота.
   Каждая задача — асинхронный цикл, который можно поставить на паузу
   и остановить. Прогресс и статистика уходят в UI.
   ============================================================ */

import type { BotStats, TaskKind } from '../../shared/types';
import { logger } from '../services/logger';

export type Botish = any;

export interface TaskContext {
  bot: Botish;
  options: Record<string, any>;
  stats: BotStats;
  log: (text: string, level?: 'info' | 'good' | 'warn' | 'bad' | 'task') => void;
  progress: (value: number, text?: string) => void;
  cancelled: () => boolean;
  waitWhilePaused: () => Promise<void>;
  /** Универсальная пауза с проверкой отмены (мс). */
  sleep: (ms: number) => Promise<boolean>;
}

export interface AutomationTask {
  kind: TaskKind;
  title: string;
  run: (ctx: TaskContext) => Promise<void>;
}

const ORE_LIST = [
  'coal_ore', 'iron_ore', 'copper_ore', 'gold_ore', 'diamond_ore', 'redstone_ore', 'lapis_ore', 'emerald_ore',
  'deepslate_coal_ore', 'deepslate_iron_ore', 'deepslate_copper_ore', 'deepslate_gold_ore', 'deepslate_diamond_ore',
  'deepslate_redstone_ore', 'deepslate_lapis_ore', 'deepslate_emerald_ore',
  'nether_gold_ore', 'nether_quartz_ore', 'ancient_debris',
];

const FOOD_HINTS = ['bread', 'cooked_beef', 'cooked_porkchop', 'cooked_chicken', 'cooked_mutton', 'cooked_rabbit', 'cooked_salmon', 'cooked_cod', 'golden_apple', 'apple', 'carrot', 'baked_potato', 'beetroot_soup'];
const FUEL_ITEMS = ['coal', 'charcoal', 'blaze_powder', 'oak_planks', 'birch_planks', 'spruce_planks', 'stick', 'oak_log'];
const JUNK_ITEMS = ['cobblestone', 'cobbled_deepslate', 'dirt', 'gravel', 'andesite', 'diorite', 'granite', 'stone', 'netherrack', 'tuff', 'flint', 'sand', 'sandstone'];

export const POTION_RECIPES: Record<string, { title: string; base: string[]; ingredient: string }> = {
  awkward: { title: 'Неуклюжее зелье', base: ['water_bottle'], ingredient: 'nether_wart' },
  strength: { title: 'Зелье силы', base: ['potion', 'water_bottle'], ingredient: 'blaze_powder' },
  healing: { title: 'Зелье исцеления', base: ['awkward_potion', 'potion'], ingredient: 'glistering_melon_slice' },
  swiftness: { title: 'Зелье скорости', base: ['awkward_potion', 'potion'], ingredient: 'sugar' },
  night_vision: { title: 'Зелье ночного зрения', base: ['awkward_potion', 'potion'], ingredient: 'golden_carrot' },
  fire_resistance: { title: 'Зелье огнестойкости', base: ['awkward_potion', 'potion'], ingredient: 'magma_cream' },
  regeneration: { title: 'Зелье регенерации', base: ['awkward_potion', 'potion'], ingredient: 'ghast_tear' },
};

/* ─────────────────────────── Утилиты ─────────────────────────── */

function mcDataOf(bot: Botish) {
  return load('minecraft-data')(bot.version);
}

const nodeRequire: NodeRequire = require as NodeRequire;
export function load(name: string): any {
  return nodeRequire(name);
}

export function sleepRaw(ms: number) {
  return new Promise<void>((r) => setTimeout(r, ms));
}

function countInventory(bot: Botish, predicate: (name: string) => boolean) {
  return bot.inventory.items().filter((i: any) => predicate(i.name)).reduce((s: number, i: any) => s + i.count, 0);
}

function findItem(bot: Botish, names: string[]) {
  return bot.inventory.items().find((i: any) => names.some((n) => i.name === n || i.name.includes(n)));
}

function allItems(bot: Botish, names: string[]) {
  return bot.inventory.items().filter((i: any) => names.some((n) => i.name === n || i.name.includes(n)));
}

export function bestToolFor(bot: Botish, block: any) {
  try {
    const tool = bot.pathfinder?.bestHarvestTool?.(block);
    if (tool) return tool;
  } catch {
    /* нет подходящего инструмента */
  }
  return null;
}

export async function gotoNear(ctx: TaskContext, pos: any, range = 1): Promise<boolean> {
  const { bot } = ctx;
  const { goals } = load('mineflayer-pathfinder');
  try {
    bot.pathfinder.setGoal(new goals.GoalNear(pos.x, pos.y, pos.z, range));
    const started = Date.now();
    while (!ctx.cancelled() && Date.now() - started < 25000) {
      await ctx.sleep(250);
      await ctx.waitWhilePaused();
      if (bot.entity.position.distanceTo(pos) <= range + 1.2) return true;
      if (!bot.pathfinder.isMoving() && bot.entity.position.distanceTo(pos) > range + 4) {
        // застряли — пересчитываем маршрут
        bot.pathfinder.setGoal(new goals.GoalNear(pos.x, pos.y, pos.z, range));
      }
    }
    return bot.entity.position.distanceTo(pos) <= range + 2;
  } catch (e) {
    ctx.log(`Не дошёл до цели: ${(e as Error).message}`, 'warn');
    return false;
  }
}

/** Достаёт еду из инвентаря и перекусывает, если голоден. */
export async function autoEat(bot: Botish) {
  if (bot.food > 16 || bot.food === undefined) return;
  const food = findItem(bot, FOOD_HINTS);
  if (!food) return;
  try {
    await bot.equip(food, 'hand');
    await bot.consume();
  } catch {
    /* не удалось поесть */
  }
}

/** Выбрасывает мусор, если инвентарь переполнен. */
export async function freeInventorySpace(ctx: TaskContext) {
  const { bot } = ctx;
  const empty = bot.inventory.emptySlotCount();
  if (empty > 3) return;
  const junk = bot.inventory.items().filter((i: any) => JUNK_ITEMS.includes(i.name) && i.count >= 32);
  for (const item of junk.slice(0, 4)) {
    try {
      await bot.toss(item.type, null, item.count);
      ctx.log(`Выбросил ${item.count}× ${item.name} (инвентарь переполнен)`, 'warn');
    } catch {
      /* ignore */
    }
  }
}

/* ─────────────────────────── 1. Автошахта ─────────────────────────── */

const miningTask: AutomationTask = {
  kind: 'mine',
  title: 'Автошахта',
  async run(ctx) {
    const { bot, options, stats } = ctx;
    const mode: string = options.mode ?? 'ores'; // ores | stone | wood | all
    const radius: number = Number(options.radius ?? 48);
    const mcData = mcDataOf(bot);
    const oreIds = ORE_LIST.map((n) => mcData.blocksByName[n]?.id).filter(Boolean);
    const logIds = Object.values(mcData.blocksByName)
      .filter((b: any) => /_log$|_wood$/.test(b.name))
      .map((b: any) => b.id);

    const matchFn = (block: any) => {
      if (!block) return false;
      if (mode === 'ores') return oreIds.includes(block.type);
      if (mode === 'wood') return logIds.includes(block.type);
      if (mode === 'stone') return /stone|deepslate|granite|diorite|andesite|tuff|calcite|basalt|blackstone/i.test(block.name);
      return !/^(air|water|lava|bedrock|barrier)/.test(block.name);
    };

    ctx.log(`Автошахта запущена: режим «${mode}», радиус ${radius}`, 'task');
    let idle = 0;

    while (!ctx.cancelled()) {
      await ctx.waitWhilePaused();
      await autoEat(bot);
      await freeInventorySpace(ctx);

      const targets = bot.findBlocks({ matching: matchFn, maxDistance: radius, count: 32 });
      if (!targets.length) {
        idle++;
        ctx.progress(0, 'Руда не найдена рядом — расширяю зону поиска');
        if (idle % 3 === 0) {
          // мягкое «прощупывание»: спускаемся/идём в случайную сторону
          const { goals } = load('mineflayer-pathfinder');
          const p = bot.entity.position;
          await gotoNear(ctx, p.offset((Math.random() - 0.5) * 24, -2, (Math.random() - 0.5) * 24), 2).catch(() => false);
          void goals;
        }
        if (!(await ctx.sleep(1200))) return;
        continue;
      }
      idle = 0;

      let mined = 0;
      for (const pos of targets) {
        if (ctx.cancelled()) return;
        await ctx.waitWhilePaused();
        const block = bot.blockAt(pos);
        if (!block || !matchFn(block)) continue;

        const tool = bestToolFor(bot, block);
        if (tool) await bot.equip(tool, 'hand').catch(() => null);

        const reachable = await gotoNear(ctx, pos, 1);
        if (!reachable) {
          ctx.log(`Не смог подойти к ${block.name} — пропускаю`, 'warn');
          continue;
        }
        try {
          await bot.dig(block, true);
          mined++;
          stats.blocksMined++;
          if (oreIds.includes(block.type)) {
            stats.oresFound[block.name] = (stats.oresFound[block.name] ?? 0) + 1;
            ctx.log(`⛏ Найдена руда: ${block.name} (${stats.oresFound[block.name]} всего)`, 'good');
          }
          ctx.progress(Math.min(100, (mined / Math.max(1, targets.length)) * 100));
          if (mined % 8 === 0) ctx.log(`Добыто блоков в цикле: ${mined}`, 'info');
        } catch (e) {
          ctx.log(`Сбой добычи ${block.name}: ${(e as Error).message}`, 'warn');
        }
        if (bot.inventory.emptySlotCount() === 0) break;
      }
      if (!(await ctx.sleep(200))) return;
    }
  },
};

/* ─────────────────────────── 2. Автоварка зелий ─────────────────────────── */

const brewingTask: AutomationTask = {
  kind: 'brew',
  title: 'Автоварка зелий',
  async run(ctx) {
    const { bot, options, stats } = ctx;
    const recipeKey: string = options.recipe ?? 'strength';
    const recipe = POTION_RECIPES[recipeKey] ?? POTION_RECIPES.strength;
    ctx.log(`Варка зелий: цель — «${recipe.title}» (ингредиент ${recipe.ingredient})`, 'task');

    while (!ctx.cancelled()) {
      await ctx.waitWhilePaused();
      await autoEat(bot);

      /* Ищем варочную стойку рядом (или идём к координатам из настроек) */
      const mcData = mcDataOf(bot);
      const standId = mcData.blocksByName['brewing_stand']?.id;
      let standPos = bot.findBlock({ matching: standId, maxDistance: Number(options.radius ?? 24) });
      if (!standPos && options.coords) {
        const [x, y, z] = String(options.coords).split(/[, ]+/).map(Number);
        await gotoNear(ctx, { x, y, z }, 2);
        standPos = bot.blockAt({ x, y, z } as any);
      }
      if (!standPos) {
        ctx.progress(0, 'Жду варочную стойку в радиусе 24 блоков');
        if (!(await ctx.sleep(3000))) return;
        continue;
      }

      const standBlock = (standPos as any).position ? standPos : bot.blockAt(standPos);
      if (!standBlock) {
        await sleepRaw(1000);
        continue;
      }
      await gotoNear(ctx, standBlock.position, 2);

      /* Проверяем наличие ингредиента/топлива */
      const ingredient = findItem(bot, [recipe.ingredient]);
      const fuel = findItem(bot, ['blaze_powder', 'blaze_rod']);
      if (!ingredient) {
        ctx.progress(0, `Нет ингредиента «${recipe.ingredient}» в инвентаре — жду`);
        ctx.log(`Нет «${recipe.ingredient}» — варка на паузе`, 'warn');
        if (!(await ctx.sleep(5000))) return;
        continue;
      }
      if (!fuel) {
        ctx.progress(0, 'Нет топлива (огненный порошок) — жду');
        if (!(await ctx.sleep(5000))) return;
        continue;
      }

      let win: any;
      try {
        win = await bot.openBlock(standBlock);
      } catch (e) {
        ctx.log(`Не удалось открыть варочную стойку: ${(e as Error).message}`, 'warn');
        if (!(await ctx.sleep(2500))) return;
        continue;
      }

      try {
        /* Раскладываем: слоты 0-2 — бутылочки, 3 — ингредиент, 4 — топливо */
        const bottles = allItems(bot, ['potion', 'water_bottle']).slice(0, 3);
        if (!bottles.length) {
          ctx.progress(0, 'Нет бутылочек с водой — нужен запас из сундука или крафт');
          ctx.log('Нет бутылочек для варки', 'warn');
          win.close();
          if (!(await ctx.sleep(4000))) return;
          continue;
        }
        for (let i = 0; i < bottles.length; i++) {
          await win.moveSlotItem(bottles[i].slot, i).catch(() => null);
        }
        await win.moveSlotItem(fuel.slot, 4).catch(() => null);
        const fresh = findItem(bot, [recipe.ingredient]);
        if (fresh) await win.moveSlotItem(fresh.slot, 3).catch(() => null);

        ctx.progress(20, 'Ингредиенты заложены, идёт варка…');
        ctx.log('Начал варку (20 секунд на цикл)', 'task');

        /* Ожидание варки: 400 тиков ≈ 20 с */
        for (let t = 0; t < 24; t++) {
          if (ctx.cancelled()) return;
          await ctx.waitWhilePaused();
          if (!(await ctx.sleep(1000))) return;
          ctx.progress(20 + (t / 24) * 70);
        }

        /* Забираем результат */
        for (const slot of [0, 1, 2]) {
          const item = win.slots?.[slot];
          if (item && !/water_bottle/.test(item.name)) {
            await win.moveSlotItem(slot, item.slot).catch(() => null);
          }
        }
        stats.brewsMade += bottles.length;
        stats.itemsCollected += bottles.length;
        ctx.log(`🍶 Готово: ${bottles.length}× ${recipe.title}`, 'good');
        ctx.progress(100, `${recipe.title} готово`);
      } catch (e) {
        ctx.log(`Ошибка варки: ${(e as Error).message}`, 'bad');
      } finally {
        try {
          win.close();
        } catch {
          /* окно уже закрыто */
        }
      }
      if (!(await ctx.sleep(600))) return;
    }
  },
};

/* ─────────────────────────── 3. Авторыбалка ─────────────────────────── */

const fishingTask: AutomationTask = {
  kind: 'fish',
  title: 'Авторыбалка',
  async run(ctx) {
    const { bot, stats } = ctx;
    ctx.log('Забрасываю удочку…', 'task');
    let attempts = 0;
    while (!ctx.cancelled()) {
      await ctx.waitWhilePaused();
      await autoEat(bot);
      const rod = findItem(bot, ['fishing_rod']);
      if (!rod) {
        ctx.progress(0, 'Нужна удочка в инвентаре');
        if (!(await ctx.sleep(5000))) return;
        continue;
      }
      try {
        await bot.equip(rod, 'hand');
        const before = countInventory(bot, (n) => !/fishing_rod/.test(n));
        ctx.progress(35, 'Поплавок в воде, ждём поклёвку…');
        await bot.fish();
        const after = countInventory(bot, (n) => !/fishing_rod/.test(n));
        if (after > before) {
          stats.fishCaught += after - before;
          stats.itemsCollected += after - before;
          ctx.progress(100, `Поймано: ${after - before} шт (всего ${stats.fishCaught})`);
          ctx.log(`🎣 Поймано ${after - before} шт. Всего: ${stats.fishCaught}`, 'good');
        }
        attempts = 0;
      } catch (e) {
        attempts++;
        ctx.log(`Сбой рыбалки: ${(e as Error).message}`, 'warn');
        if (!(await ctx.sleep(1500 + attempts * 500))) return;
        if (attempts > 6) {
          ctx.progress(0, 'Не могу рыбачить — проверьте воду рядом');
          if (!(await ctx.sleep(5000))) return;
          attempts = 0;
        }
      }
    }
  },
};

/* ─────────────────────────── 4. Автоферма ─────────────────────────── */

const farmTask: AutomationTask = {
  kind: 'farm',
  title: 'Автоферма',
  async run(ctx) {
    const { bot, stats, options } = ctx;
    const radius = Number(options.radius ?? 32);
    const mcData = mcDataOf(bot);
    const cropNames = ['wheat', 'carrots', 'potatoes', 'beetroots', 'pumpkin', 'melon', 'sugar_cane', 'nether_wart'];
    const cropIds = cropNames.map((n) => mcData.blocksByName[n]?.id).filter(Boolean);
    const seedMap: Record<string, string> = {
      wheat: 'wheat_seeds',
      carrots: 'carrot',
      potatoes: 'potato',
      beetroots: 'beetroot_seeds',
      nether_wart: 'nether_wart',
      sugar_cane: 'sugar_cane',
    };
    ctx.log(`Автоферма запущена (радиус ${radius})`, 'task');

    while (!ctx.cancelled()) {
      await ctx.waitWhilePaused();
      await autoEat(bot);
      await freeInventorySpace(ctx);

      const blocks = bot.findBlocks({ matching: cropIds, maxDistance: radius, count: 64 });
      const mature = blocks
        .map((p: any) => bot.blockAt(p))
        .filter((b: any) => {
          if (!b) return false;
          if (b.name === 'sugar_cane') return true;
          const age = b.getProperties?.().age;
          return age !== undefined && Number(age) >= 7;
        });

      if (!mature.length) {
        ctx.progress(0, 'Урожай ещё не созрел — жду');
        if (!(await ctx.sleep(3000))) return;
        continue;
      }

      for (let i = 0; i < mature.length; i++) {
        if (ctx.cancelled()) return;
        await ctx.waitWhilePaused();
        const block = mature[i];
        try {
          await gotoNear(ctx, block.position, 1);
          await bot.dig(block, true);
          stats.blocksMined++;
          /* Сажаем заново, если есть семена */
          const seedName = seedMap[block.name];
          if (seedName && block.name !== 'sugar_cane') {
            const seeds = findItem(bot, [seedName]);
            if (seeds) {
              await bot.equip(seeds, 'hand');
              const soil = bot.blockAt(block.position.offset(0, -1, 0));
              if (soil) await bot.placeBlock(soil, new (load('vec3').Vec3)(0, 1, 0)).catch(() => null);
            }
          }
          ctx.progress(((i + 1) / mature.length) * 100, `Собрано ${i + 1}/${mature.length}`);
        } catch (e) {
          ctx.log(`Не удалось собрать ${block.name}: ${(e as Error).message}`, 'warn');
        }
      }
      ctx.log(`🌾 Собрано ${mature.length} растений`, 'good');
      if (!(await ctx.sleep(500))) return;
    }
  },
};

/* ─────────────────────────── 5. Автоплавка ─────────────────────────── */

const smeltTask: AutomationTask = {
  kind: 'smelt',
  title: 'Автоплавка',
  async run(ctx) {
    const { bot, options, stats } = ctx;
    const radius = Number(options.radius ?? 24);
    const mcData = mcDataOf(bot);
    const furnaceIds = ['furnace', 'blast_furnace', 'smoker'].map((n) => mcData.blocksByName[n]?.id).filter(Boolean);
    ctx.log('Автоплавка запущена — ищу печь', 'task');

    while (!ctx.cancelled()) {
      await ctx.waitWhilePaused();
      const candidates = bot.findBlocks({ matching: furnaceIds, maxDistance: radius, count: 8 });
      if (!candidates.length) {
        ctx.progress(0, 'Печь не найдена в радиусе — жду');
        if (!(await ctx.sleep(4000))) return;
        continue;
      }
      const block = bot.blockAt(candidates[0]);
      if (!block) continue;

      let furnace: any;
      try {
        await gotoNear(ctx, block.position, 2);
        furnace = await bot.openFurnace(block);
      } catch (e) {
        ctx.log(`Не открыл печь: ${(e as Error).message}`, 'warn');
        if (!(await ctx.sleep(2500))) return;
        continue;
      }

      try {
        const smeltables = bot.inventory
          .items()
          .filter((i: any) => /raw_(iron|copper|gold)|_ore$|sand$|_log$|beef|porkchop|chicken|mutton|cod|salmon|potato$|kelp$|clay_ball|cobblestone/.test(i.name));
        const fuel = findItem(bot, FUEL_ITEMS);
        if (!smeltables.length || !fuel) {
          ctx.progress(0, smeltables.length ? 'Нужно топливо (уголь/дрова)' : 'Нет сырья для плавки');
          if (!(await ctx.sleep(4000))) return;
          furnace.close();
          continue;
        }
        for (const item of smeltables.slice(0, 6)) {
          await furnace.putInput(item.type, null, Math.min(item.count, 32)).catch(() => null);
        }
        await furnace.putFuel(fuel.type, null, Math.min(fuel.count, 16)).catch(() => null);
        ctx.progress(25, `Плавлю ${smeltables.length} типов предметов…`);
        ctx.log(`🔥 Печь загружена (${smeltables.length} типов сырья)`, 'task');

        for (let t = 0; t < 20; t++) {
          if (ctx.cancelled()) return;
          await ctx.waitWhilePaused();
          if (!(await ctx.sleep(1000))) return;
          ctx.progress(25 + (t / 20) * 60);
        }

        let got = 0;
        while (furnace.outputItem()) {
          const out = furnace.outputItem();
          if (!out) break;
          await furnace.takeOutput().catch(() => null);
          got += out.count;
        }
        stats.itemsCollected += got;
        if (got) ctx.log(`Плавка завершена: +${got} предметов`, 'good');
        ctx.progress(100, `Готово: ${got} предметов`);
      } catch (e) {
        ctx.log(`Ошибка плавки: ${(e as Error).message}`, 'bad');
      } finally {
        try {
          furnace.close();
        } catch {
          /* ignore */
        }
      }
      if (!(await ctx.sleep(700))) return;
    }
  },
};

/* ─────────────────────────── 6. Охрана ─────────────────────────── */

const guardTask: AutomationTask = {
  kind: 'guard',
  title: 'Охрана базы',
  async run(ctx) {
    const { bot, options } = ctx;
    const radius = Number(options.radius ?? 16);
    ctx.log(`Охрана территории: радиус ${radius}, автоответ атакой`, 'task');
    let lastReport = 0;

    while (!ctx.cancelled()) {
      await ctx.waitWhilePaused();
      await autoEat(bot);

      const hostile = Object.values(bot.entities).filter((e: any) => {
        if (!e || e === bot.entity) return false;
        const dist = e.position.distanceTo(bot.entity.position);
        if (dist > radius) return false;
        const name: string = e.name ?? e.displayName ?? '';
        return /zombie|skeleton|creeper|spider|witch|enderman|pillager|vindicator|ravager|blaze|ghast|slime|hoglin|piglin|warden|phantom|drowned|husk|stray|wither/i.test(name);
      });

      if (!hostile.length) {
        ctx.progress(0, 'Территория чиста');
        if (Date.now() - lastReport > 60000) {
          ctx.log('Патрулирую… противников нет', 'info');
          lastReport = Date.now();
        }
        if (!(await ctx.sleep(800))) return;
        continue;
      }

      const target: any = hostile.sort((a: any, b: any) => a.position.distanceTo(bot.entity.position) - b.position.distanceTo(bot.entity.position))[0];
      const sword = findItem(bot, ['netherite_sword', 'diamond_sword', 'iron_sword', 'stone_sword', 'wooden_sword', 'sword', 'axe']);
      if (sword) await bot.equip(sword, 'hand').catch(() => null);
      try {
        const { goals } = load('mineflayer-pathfinder');
        bot.pathfinder.setGoal(new goals.GoalFollow(target, 1), true);
        ctx.progress(50, `Атакую ${target.name} (${target.position.distanceTo(bot.entity.position).toFixed(1)} бл.)`);
        while (bot.entities[target.id] && bot.entity.position.distanceTo(target.position) < radius + 8 && !ctx.cancelled()) {
          await bot.attack(target).catch(() => null);
          await ctx.sleep(450);
        }
        ctx.log(`Противник ${target.name} нейтрализован`, 'good');
      } catch (e) {
        ctx.log(`Ошибка боя: ${(e as Error).message}`, 'warn');
      }
      if (!(await ctx.sleep(400))) return;
    }
  },
};

/* ─────────────────────────── 7. Автоторговля ─────────────────────────── */

const shopTask: AutomationTask = {
  kind: 'shop',
  title: 'Автоторговля',
  async run(ctx) {
    const { bot, options, stats } = ctx;
    const radius = Number(options.radius ?? 24);
    const want = String(options.item ?? '').trim(); // что продаём жителю
    ctx.log(`Автоторговля: ищу жителей в радиусе ${radius}${want ? ` (обмен на ${want})` : ''}`, 'task');

    while (!ctx.cancelled()) {
      await ctx.waitWhilePaused();
      const villagers = Object.values(bot.entities).filter(
        (e: any) => e?.name === 'villager' || e?.displayName === 'Villager' || e?.entityType === 'villager' || e?.type === 'mob' && /villager/i.test(e?.name ?? ''),
      );
      const near = villagers
        .map((v: any) => ({ v, d: v.position.distanceTo(bot.entity.position) }))
        .filter((x: any) => x.d <= radius)
        .sort((a: any, b: any) => a.d - b.d);

      if (!near.length) {
        ctx.progress(0, 'Жителей рядом нет — жду');
        if (!(await ctx.sleep(4000))) return;
        continue;
      }

      const villager = near[0].v;
      try {
        await gotoNear(ctx, villager.position, 2);
        const openFn = bot.openVillager ?? bot.openEntity;
        const win = await openFn.call(bot, villager);
        const trades: any[] = win.trades ?? [];
        if (!trades.length) {
          ctx.progress(0, 'У жителя нет доступных сделок');
          win.close?.();
          if (!(await ctx.sleep(4000))) return;
          continue;
        }

        /* Ищем сделку, где мы отдаём ненужное, а получаем изумруды/нужное */
        const index = trades.findIndex((t: any) => {
          const inputs = [t.inputItem1, t.inputItem2].filter(Boolean).map((i: any) => i.name);
          const out = t.outputItem?.name ?? '';
          if (want) return out.includes(want) || inputs.some((n) => (n ?? '').includes(want));
          return /emerald/.test(out);
        });

        if (index === -1) {
          ctx.progress(0, 'Подходящей сделки нет — пропускаю жителя');
          win.close?.();
          if (!(await ctx.sleep(5000))) return;
          continue;
        }

        const trade = trades[index];
        const have = trade.inputItem1 ? countInventory(bot, () => true) : 0;
        void have;
        const times = Math.max(1, Math.min(Number(options.times ?? 3), 12));
        for (let i = 0; i < times; i++) {
          if (ctx.cancelled()) return;
          await ctx.waitWhilePaused();
          await bot.trade(win, index, 1);
          stats.itemsCollected++;
          ctx.progress(((i + 1) / times) * 100, `Сделка ${i + 1}/${times}: ${trade.outputItem?.name ?? 'обмен'}`);
          await ctx.sleep(700);
        }
        ctx.log(`💱 Обменяно ${times}× (${trade.inputItem1?.name ?? '?'} → ${trade.outputItem?.name ?? '?'})`, 'good');
        win.close?.();
      } catch (e) {
        ctx.log(`Торговля не удалась: ${(e as Error).message}`, 'warn');
      }
      if (!(await ctx.sleep(1200))) return;
    }
  },
};

/* ─────────────────────────── 8. Автосклад ─────────────────────────── */

const stashTask: AutomationTask = {
  kind: 'stash',
  title: 'Автосклад',
  async run(ctx) {
    const { bot, options } = ctx;
    const radius = Number(options.radius ?? 24);
    const keep: string[] = String(options.keep ?? 'sword,pickaxe,axe,shovel,hoe,food,coal,torch')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    ctx.log(`Автосклад: раскладка по сундукам (оставляю: ${keep.join(', ')})`, 'task');

    while (!ctx.cancelled()) {
      await ctx.waitWhilePaused();
      if (bot.inventory.emptySlotCount() > 6) {
        ctx.progress(0, 'Инвентарь не переполнен — жду');
        if (!(await ctx.sleep(4000))) return;
        continue;
      }

      const mcData = mcDataOf(bot);
      const chestIds = ['chest', 'trapped_chest', 'barrel'].map((n) => mcData.blocksByName[n]?.id).filter(Boolean);
      const positions = bot.findBlocks({ matching: chestIds, maxDistance: radius, count: 8 });
      if (!positions.length) {
        ctx.progress(0, 'Сундук не найден — жду');
        if (!(await ctx.sleep(5000))) return;
        continue;
      }

      const block = bot.blockAt(positions[0]);
      if (!block) continue;
      try {
        await gotoNear(ctx, block.position, 2);
        const container = await bot.openContainer(block);
        const items = bot.inventory.items().filter((i: any) => !keep.some((k) => i.name.includes(k)));
        let moved = 0;
        for (const item of items) {
          if (ctx.cancelled()) return;
          try {
            await container.deposit(item.type, null, item.count);
            moved += item.count;
          } catch {
            /* нет места в сундуке */
          }
        }
        ctx.log(`📦 Сложено на склад: ${moved} предметов`, 'good');
        ctx.progress(100, `${moved} предметов в сундуке`);
        container.close();
      } catch (e) {
        ctx.log(`Склад недоступен: ${(e as Error).message}`, 'warn');
      }
      if (!(await ctx.sleep(1500))) return;
    }
  },
};

/* ─────────────────────────── 9. Анти-AFK ─────────────────────────── */

const afkTask: AutomationTask = {
  kind: 'afk',
  title: 'Анти-AFK',
  async run(ctx) {
    const { bot } = ctx;
    ctx.log('Анти-AFK активен: имитирую активность', 'task');
    while (!ctx.cancelled()) {
      await ctx.waitWhilePaused();
      try {
        bot.swingArm();
        await bot.look(bot.entity.yaw + (Math.random() - 0.5) * 0.8, (Math.random() - 0.5) * 0.3, true);
        const from = bot.entity.position;
        await gotoNear(ctx, from.offset((Math.random() - 0.5) * 3, 0, (Math.random() - 0.5) * 3), 1);
        ctx.progress(Date.now() % 100, 'Поддерживаю соединение');
      } catch {
        /* игнорируем — бот всё равно продолжит */
      }
      if (!(await ctx.sleep(9000 + Math.random() * 12000))) return;
    }
  },
};

export const TASKS: Record<TaskKind, AutomationTask> = {
  mine: miningTask,
  brew: brewingTask,
  fish: fishingTask,
  farm: farmTask,
  smelt: smeltTask,
  guard: guardTask,
  shop: shopTask,
  stash: stashTask,
  afk: afkTask,
};

export const TASK_CATALOG: { kind: TaskKind; name: string; description: string; icon: string; options: { key: string; label: string; type: 'text' | 'number' | 'select'; placeholder?: string; choices?: { value: string; label: string }[]; default?: string | number }[] }[] = [
  {
    kind: 'mine',
    name: 'Автошахта',
    description: 'Ищет и добывает руду, копает туннели, сам меняет инструмент и выкидывает мусор.',
    icon: 'Pickaxe',
    options: [
      { key: 'mode', label: 'Что копать', type: 'select', default: 'ores', choices: [
        { value: 'ores', label: 'Только руду' },
        { value: 'stone', label: 'Камень и грунт' },
        { value: 'wood', label: 'Дерево' },
        { value: 'all', label: 'Всё подряд' },
      ] },
      { key: 'radius', label: 'Радиус поиска (блоки)', type: 'number', default: 48 },
    ],
  },
  {
    kind: 'brew',
    name: 'Автоварка зелий',
    description: 'Работает с варочной стойкой: закладывает ингредиенты, ждёт цикл и забирает зелья.',
    icon: 'FlaskConical',
    options: [
      { key: 'recipe', label: 'Рецепт', type: 'select', default: 'strength', choices: Object.entries(POTION_RECIPES).map(([value, r]) => ({ value, label: r.title })) },
      { key: 'radius', label: 'Радиус поиска стойки', type: 'number', default: 24 },
      { key: 'coords', label: 'Координаты стойки (x,y,z)', type: 'text', placeholder: 'необязательно' },
    ],
  },
  {
    kind: 'fish',
    name: 'Авторыбалка',
    description: 'Бесконечная рыбалка с авто-забросом и подсчётом улова.',
    icon: 'Fish',
    options: [],
  },
  {
    kind: 'farm',
    name: 'Автоферма',
    description: 'Собирает созревшие культуры и сажает их заново.',
    icon: 'Sprout',
    options: [{ key: 'radius', label: 'Радиус фермы', type: 'number', default: 32 }],
  },
  {
    kind: 'smelt',
    name: 'Автоплавка',
    description: 'Загружает печь сырьём и топливом, забирает готовый результат.',
    icon: 'Flame',
    options: [{ key: 'radius', label: 'Радиус поиска печи', type: 'number', default: 24 }],
  },
  {
    kind: 'guard',
    name: 'Охрана базы',
    description: 'Атакует враждебных мобов, защищает территорию и вас.',
    icon: 'ShieldHalf',
    options: [{ key: 'radius', label: 'Радиус охраны', type: 'number', default: 16 }],
  },
  {
    kind: 'shop',
    name: 'Автоторговля',
    description: 'Обменивается с жителями: продаёт ресурсы, забирает изумруды.',
    icon: 'HandCoins',
    options: [
      { key: 'item', label: 'Что хотим получить', type: 'text', placeholder: 'emerald' },
      { key: 'times', label: 'Сделок за подход', type: 'number', default: 3 },
      { key: 'radius', label: 'Радиус поиска жителей', type: 'number', default: 24 },
    ],
  },
  {
    kind: 'stash',
    name: 'Автосклад',
    description: 'Складывает добычу в сундуки, оставляя только нужное в инвентаре.',
    icon: 'Archive',
    options: [
      { key: 'keep', label: 'Оставлять (через запятую)', type: 'text', placeholder: 'sword,pickaxe,food' },
      { key: 'radius', label: 'Радиус поиска сундуков', type: 'number', default: 24 },
    ],
  },
  {
    kind: 'afk',
    name: 'Анти-AFK',
    description: 'Имитирует активность, чтобы сервер не кикал бота за неактивность.',
    icon: 'Timer',
    options: [],
  },
];

export function logTaskError(kind: TaskKind, err: unknown) {
  logger.error(`Задача ${kind} упала: ${(err as Error)?.message ?? err}`, 'bot');
}
