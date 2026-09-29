class_name BotTemplates
extends RefCounted
## Шаблоны ботов автоматизации (Mineflayer / Node.js).
## Лаунчер подставляет конфигурацию задачи и пишет готовый проект в каталог задачи.
##
## ВАЖНО: боты — это автоматизация действий в игре. Запускайте их только в своих
## мирах или на серверах, где это разрешено правилами. За нарушение правил
## сервера вы отвечаете сами.

static func render(kind: String, config: Dictionary) -> String:
	return PREAMBLE.replace("__CFG__", JSON.stringify(config)) + "\n" + _mode_body(kind) + "\n" + MAIN

static func _mode_body(kind: String) -> String:
	match kind:
		"mine": return MODE_MINE
		"brew": return MODE_BREW
		"fish": return MODE_FISH
		"farm": return MODE_FARM
		"smelt": return MODE_SMELT
		"eat": return MODE_EAT
		"afk": return MODE_AFK
		"macro": return MODE_MACRO
	return ""

const PREAMBLE := """
// ==== Aurora Launcher :: бот автоматизации (сгенерировано автоматически) ====
// Запускайте бота только там, где автоматизация разрешена правилами сервера.
const mineflayer = require('mineflayer');
const pathfinderPlugin = require('mineflayer-pathfinder');
const fs = require('fs');
const path = require('path');

const cfg = __CFG__;
const statePath = path.join(__dirname, 'state.json');

let bot = null;
let mcData = null;
let actions = 0;
let state = 'starting';
let note = '';
let stopFlag = false;

function saveState(extra) {
  const data = { state: state, actions: actions, note: note, mode: cfg.mode, updated: Date.now() };
  if (extra) { for (const k in extra) data[k] = extra[k]; }
  try { fs.writeFileSync(statePath, JSON.stringify(data)); } catch (e) {}
}
function log() {
  const parts = [];
  for (let i = 0; i < arguments.length; i++) parts.push(String(arguments[i]));
  console.log('[AURORA] ' + parts.join(' '));
}
function setNote(t) { note = t; saveState(); }
function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
function blockId(name) { const b = mcData.blocksByName[name]; return b ? b.id : -1; }
function itemId(name) { const i = mcData.itemsByName[name]; return i ? i.id : -1; }
function idsOf(list, table) {
  const out = [];
  for (const n of list) { const id = table === 'blocks' ? blockId(n) : itemId(n); if (id >= 0) out.push(id); }
  return out;
}
function invCount(names) {
  let total = 0;
  for (const it of bot.inventory.items()) { if (names.indexOf(it.name) >= 0) total += it.count; }
  return total;
}
async function eatSomething() {
  const foods = cfg.foods || ['bread', 'cooked_beef'];
  const item = bot.inventory.items().find(function (it) { return foods.indexOf(it.name) >= 0; });
  if (!item) { setNote('нет еды'); return false; }
  try {
    await bot.equip(item, 'hand');
    await bot.consume();
    actions++;
    saveState();
    return true;
  } catch (e) { log('eat:', e.message); return false; }
}
async function moveToSlot(win, item, targetSlot) {
  if (!item) return false;
  const from = item.slot + win.inventoryStart;
  try {
    await bot.clickWindow(from, 0, 0);
    await bot.clickWindow(targetSlot, 0, 0);
    return true;
  } catch (e) { log('moveToSlot:', e.message); return false; }
}
function takeFromSlot(win, slot) {
  bot.clickWindow(slot, 0, 0);
  const empty = bot.inventory.firstEmptyInventorySlot();
  if (empty !== null) bot.clickWindow(empty + win.inventoryStart, 0, 0);
}
process.on('SIGTERM', function () {
  stopFlag = true; state = 'stopping'; saveState();
  try { bot.quit(); } catch (e) {}
  setTimeout(function () { process.exit(0); }, 600);
});
process.on('SIGINT', function () { process.exit(0); });
"""

const MODE_MINE := """
// ---------------------------- автошахта ----------------------------
const KEEP_ITEMS = ['netherite_pickaxe', 'diamond_pickaxe', 'iron_pickaxe', 'golden_pickaxe', 'stone_pickaxe', 'wooden_pickaxe', 'torch', 'bread', 'cooked_beef', 'cooked_porkchop', 'golden_apple', 'cobblestone'];
const JUNK = ['cobblestone', 'dirt', 'gravel', 'sand', 'andesite', 'diorite', 'granite', 'tuff', 'deepslate', 'cobbled_deepslate', 'clay'];

function chestIds() {
  const names = ['chest', 'trapped_chest', 'barrel'];
  return idsOf(names, 'blocks');
}
function findOre() {
  const ids = idsOf(cfg.ores || ['iron_ore', 'coal_ore'], 'blocks');
  if (ids.length === 0) return null;
  const positions = bot.findBlocks({ matching: ids, maxDistance: cfg.radius, count: 96 });
  const pos = bot.entity.position;
  let best = null;
  let bestD = 1e9;
  for (const p of positions) {
    if (p.y < cfg.min_y || p.y > cfg.max_y) continue;
    const d = pos.distanceTo(p);
    if (d < bestD) { bestD = d; best = p; }
  }
  if (!best) return null;
  return bot.blockAt(best);
}
function nearDanger(p) {
  const offs = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]];
  for (const o of offs) {
    const b = bot.blockAt(p.offset(o[0], o[1], o[2]));
    if (b && (b.name === 'lava' || b.name === 'flowing_lava' || b.name === 'fire' || b.name === 'magma_block' || b.name === 'soul_fire')) return true;
  }
  return false;
}
async function equipPick() {
  const pick = bot.inventory.items().find(function (it) { return it.name.indexOf('pickaxe') >= 0; });
  if (pick) { try { await bot.equip(pick, 'hand'); } catch (e) {} }
}
async function depositOres() {
  const ids = chestIds();
  if (ids.length === 0) return false;
  const positions = bot.findBlocks({ matching: ids, maxDistance: 32, count: 8 });
  if (positions.length === 0) { setNote('сундук не найден'); return false; }
  const chest = bot.blockAt(positions[0]);
  try {
    await bot.pathfinder.goto(new pathfinderPlugin.goals.GoalNear(chest.position.x, chest.position.y, chest.position.z, 2));
    const win = await bot.openContainer(chest);
    for (const item of bot.inventory.items()) {
      if (KEEP_ITEMS.indexOf(item.name) >= 0) continue;
      const isOre = (cfg.ores || []).indexOf(item.name) >= 0;
      if (!isOre && JUNK.indexOf(item.name) < 0) continue;
      try { await win.deposit(item.type, null, item.count); actions++; } catch (e) {}
    }
    win.close();
    setNote('сбросил добычу в сундук');
    return true;
  } catch (e) { log('deposit:', e.message); return false; }
}
async function placeTorch() {
  if (!cfg.torch) return;
  const torch = bot.inventory.items().find(function (it) { return it.name === 'torch'; });
  if (!torch) return;
  const p = bot.entity.position;
  const below = bot.blockAt(p.offset(0, -1, 0));
  if (!below) return;
  try {
    await bot.equip(torch, 'hand');
    await bot.placeBlock(below, { x: 0, y: 1, z: 0 });
    actions++;
    saveState();
  } catch (e) {}
}
async function mineLoop() {
  setNote('готовлюсь');
  while (!stopFlag) {
    if (bot.food <= 17) await eatSomething();
    if (bot.inventory.items().length >= 34) {
      setNote('инвентарь почти полон');
      if (!await depositOres()) { await sleep(4000); continue; }
    }
    const block = findOre();
    if (!block) { setNote('ищу руду рядом'); await sleep(2000); continue; }
    if (nearDanger(block.position)) { setNote('рядом лава, обхожу'); await sleep(1200); continue; }
    try {
      setNote('иду к ' + block.name);
      await bot.pathfinder.goto(new pathfinderPlugin.goals.GoalGetToBlock(block.position.x, block.position.y, block.position.z));
      await equipPick();
      setNote('добываю ' + block.name);
      await bot.dig(block, true);
      actions++;
      saveState();
      await placeTorch();
    } catch (e) {
      log('mine:', e.message);
      await sleep(1500);
    }
  }
}
"""

const MODE_BREW := """
// -------------------------- автоварка зелий --------------------------
const POTION_RECIPES = {
  healing: 'glistering_melon_slice',
  regeneration: 'ghast_tear',
  strength: 'blaze_powder',
  swiftness: 'sugar',
  fire_resistance: 'magma_cream',
  water_breathing: 'pufferfish',
  night_vision: 'golden_carrot',
  invisibility: 'fermented_spider_eye',
  leaping: 'rabbit_foot'
};
async function fillBottles(win) {
  const water = bot.findBlock({ matching: [blockId('water'), blockId('cauldron')], maxDistance: 12 });
  if (!water) { setNote('источник воды не найден'); return false; }
  try {
    await bot.pathfinder.goto(new pathfinderPlugin.goals.GoalNear(water.position.x, water.position.y, water.position.z, 2));
    const bottles = bot.inventory.items().filter(function (it) { return it.name === 'glass_bottle'; });
    for (const b of bottles) {
      await bot.equip(b, 'hand');
      await bot.activateItem();
      actions++;
    }
    saveState();
    return true;
  } catch (e) { log('fillBottles:', e.message); return false; }
}
async function brewCycle() {
  const stands = bot.findBlocks({ matching: [blockId('brewing_stand')], maxDistance: cfg.stand_radius, count: 8 });
  if (stands.length === 0) { setNote('стенд варки не найден'); return false; }
  const stand = bot.blockAt(stands[0]);
  try {
    await bot.pathfinder.goto(new pathfinderPlugin.goals.GoalNear(stand.position.x, stand.position.y, stand.position.z, 2));
    const win = await bot.openContainer(stand);
    const bottles = bot.inventory.items().filter(function (it) { return it.name === 'glass_bottle' || it.name === 'potion'; });
    if (bottles.length === 0) {
      if (cfg.refill_water) await fillBottles(win);
      win.close();
      return false;
    }
    for (let i = 0; i < 3 && i < bottles.length; i++) await moveToSlot(win, bottles[i], i);
    const fuel = bot.inventory.items().find(function (it) { return it.name === 'blaze_powder'; });
    if (fuel) await moveToSlot(win, fuel, 4);
    for (const recipe of (cfg.recipes || ['healing'])) {
      if (stopFlag) break;
      const ingredientName = POTION_RECIPES[recipe];
      if (!ingredientName) continue;
      const ingredient = bot.inventory.items().find(function (it) { return it.name === ingredientName; });
      if (!ingredient) { setNote('нет ингредиента: ' + ingredientName); continue; }
      await moveToSlot(win, ingredient, 3);
      setNote('варю ' + recipe);
      await sleep(21000);
      for (let s = 0; s < 3; s++) takeFromSlot(win, s);
      actions++;
      saveState();
    }
    win.close();
    return true;
  } catch (e) { log('brew:', e.message); return false; }
}
async function brewLoop() {
  let done = 0;
  while (!stopFlag && done < (cfg.count || 3)) {
    if (await brewCycle()) done++;
    await sleep(1500);
  }
  setNote('варка завершена');
  state = 'done';
  saveState();
}
"""

const MODE_FISH := """
// --------------------------- авторыбалка ---------------------------
async function fishLoop() {
  setNote('забрасываю удочку');
  while (!stopFlag) {
    try {
      if (bot.food <= 16) await eatSomething();
      await bot.fish();
      actions++;
      saveState();
      setNote('поймал ' + actions);
    } catch (e) {
      log('fish:', e.message);
      await sleep(3000);
    }
    if (cfg.drop_junk) {
      const junk = bot.inventory.items().filter(function (it) {
        return ['cod', 'salmon', 'tropical_fish', 'pufferfish', 'bowl', 'leather_boots', 'lily_pad', 'bow', 'fishing_rod', 'name_tag', 'saddle', 'enchanted_book', 'stick', 'string', 'tripwire_hook'].indexOf(it.name) >= 0 && it.name !== 'fishing_rod';
      });
      for (const it of junk) { try { await bot.tossStack(it); } catch (e) {} }
    }
  }
}
"""

const MODE_FARM := """
// ---------------------------- автоферма ----------------------------
const MAX_AGE = { wheat: 7, carrots: 7, potatoes: 7, beetroots: 3, nether_wart: 3 };
const SEEDS = { wheat: 'wheat_seeds', carrots: 'carrot', potatoes: 'potato', beetroots: 'beetroot_seeds', nether_wart: 'nether_wart', pumpkin: 'pumpkin_seeds', melon: 'melon_seeds' };
function cropBlockName(crop) {
  if (crop === 'wheat') return 'wheat';
  if (crop === 'carrots') return 'carrots';
  if (crop === 'potatoes') return 'potatoes';
  if (crop === 'beetroots') return 'beetroots';
  if (crop === 'nether_wart') return 'nether_wart';
  if (crop === 'pumpkin') return 'pumpkin';
  if (crop === 'melon') return 'melon';
  return crop;
}
function isMature(block) {
  const props = block.getProperties();
  if (!props) return true;
  if (props.age === undefined) return true;
  return props.age >= (MAX_AGE[block.name] || 7);
}
async function replant(block) {
  const seedName = SEEDS[block.name];
  if (!seedName || !cfg.replant) return;
  const seed = bot.inventory.items().find(function (it) { return it.name === seedName; });
  if (!seed) return;
  try {
    await bot.equip(seed, 'hand');
    await bot.placeBlock(block, { x: 0, y: 1, z: 0 });
    actions++;
  } catch (e) {}
}
async function farmLoop() {
  while (!stopFlag) {
    if (bot.food <= 17) await eatSomething();
    const names = (cfg.crops || ['wheat', 'carrot']).map(cropBlockName);
    const ids = idsOf(names, 'blocks');
    const positions = bot.findBlocks({ matching: ids, maxDistance: cfg.radius, count: 128 });
    let harvested = 0;
    for (const p of positions) {
      if (stopFlag) break;
      const block = bot.blockAt(p);
      if (!block || !isMature(block)) continue;
      try {
        await bot.pathfinder.goto(new pathfinderPlugin.goals.GoalNear(p.x, p.y, p.z, 2));
        await bot.dig(block, true);
        await replant(block);
        actions++;
        harvested++;
        saveState();
      } catch (e) {}
    }
    setNote(harvested > 0 ? ('собрано культур: ' + harvested) : 'ищу спелые культуры');
    await sleep(4000);
  }
}
"""

const MODE_SMELT := """
// -------------------------- автоплавильня --------------------------
async function smeltOnce() {
  const ids = idsOf(['furnace', 'smoker', 'blast_furnace'], 'blocks');
  const positions = bot.findBlocks({ matching: ids, maxDistance: cfg.radius, count: 8 });
  if (positions.length === 0) { setNote('печь не найдена'); return false; }
  const furnace = bot.blockAt(positions[0]);
  try {
    await bot.pathfinder.goto(new pathfinderPlugin.goals.GoalNear(furnace.position.x, furnace.position.y, furnace.position.z, 2));
    const win = await bot.openContainer(furnace);
    const inputIds = idsOf(cfg.items || ['raw_iron'], 'items');
    const inputs = bot.inventory.items().filter(function (it) { return inputIds.indexOf(it.type) >= 0; });
    for (const it of inputs) await moveToSlot(win, it, 0);
    const fuelNames = [cfg.fuel || 'coal', 'coal', 'charcoal', 'blaze_rod', 'oak_log', 'oak_planks'];
    const fuel = bot.inventory.items().find(function (it) { return fuelNames.indexOf(it.name) >= 0; });
    if (fuel) await moveToSlot(win, fuel, 1);
    setNote('плавлю');
    for (let i = 0; i < 90 && !stopFlag; i++) {
      await sleep(2000);
      if (win.slots[2]) {
        takeFromSlot(win, 2);
        actions++;
        setNote('забрал результат');
        break;
      }
    }
    win.close();
    return true;
  } catch (e) { log('smelt:', e.message); return false; }
}
async function smeltLoop() {
  while (!stopFlag) {
    await smeltOnce();
    await sleep(2000);
  }
}
"""

const MODE_EAT := """
// --------------------------- автопитание ---------------------------
async function eatLoop() {
  while (!stopFlag) {
    if (bot.food <= (cfg.threshold || 14)) {
      setNote('ем, сытость ' + bot.food);
      await eatSomething();
    } else {
      setNote('сытость в норме (' + bot.food + ')');
    }
    await sleep(2500);
  }
}
"""

const MODE_AFK := """
// ---------------------------- анти-AFK -----------------------------
function afkLoop() {
  setNote('держу онлайн');
  const jumpEvery = (cfg.jump_seconds || 45) * 1000;
  setInterval(function () {
    if (stopFlag) return;
    bot.setControlState('jump', true);
    setTimeout(function () { bot.setControlState('jump', false); }, 350);
    try { bot.look(bot.entity.yaw + (Math.random() * 40 - 20), Math.random() * 40 - 20, true); } catch (e) {}
    if (cfg.swing) bot.swingArm();
    actions++;
    saveState();
  }, jumpEvery);
  if (cfg.chat) {
    const chatEvery = (cfg.chat_seconds || 300) * 1000;
    setInterval(function () { if (!stopFlag) bot.chat(cfg.chat); }, chatEvery);
  }
  return new Promise(function () {});
}
"""

const MODE_MACRO := """
// ------------------------------ макрос ------------------------------
async function macroLoop() {
  const lines = String(cfg.steps || '').split(String.fromCharCode(10));
  while (!stopFlag) {
    for (const raw of lines) {
      if (stopFlag) break;
      const line = raw.trim();
      if (line === '' || line.indexOf('//') === 0) continue;
      const parts = line.split(' ');
      const cmd = (parts[0] || '').toLowerCase();
      if (cmd === 'chat') { bot.chat(line.substring(5)); setNote('chat'); }
      else if (cmd === 'wait') { await sleep(parseFloat(parts[1] || '1') * 1000); }
      else if (cmd === 'key') {
        const dir = parts[1] || 'forward';
        bot.setControlState(dir, true);
        setNote('движение: ' + dir);
        await sleep(parseFloat(parts[2] || '1') * 1000);
        bot.setControlState(dir, false);
      }
      else if (cmd === 'dig') {
        const b = bot.blockAt(bot.entity.position.offset(0, -1, 0));
        if (b) { try { await bot.dig(b, true); } catch (e) {} }
      }
      else if (cmd === 'use') { try { await bot.activateItem(); } catch (e) {} }
      else if (cmd === 'look') { try { bot.look(parseFloat(parts[1] || '0'), parseFloat(parts[2] || '0'), true); } catch (e) {} }
      else if (cmd === 'jump') {
        bot.setControlState('jump', true);
        await sleep(400);
        bot.setControlState('jump', false);
      }
      else if (cmd === 'swing') { bot.swingArm(); }
      else if (cmd === 'eat') { await eatSomething(); }
      actions++;
      saveState();
    }
  }
}
"""

const MAIN := """
// ------------------------------ запуск -----------------------------
function onSpawn() {
  try { bot.loadPlugin(pathfinderPlugin); } catch (e) { log('pathfinder не загрузился:', e.message); }
  mcData = require('minecraft-data')(bot.version);
  try {
    const moves = new pathfinderPlugin.Movements(bot);
    moves.canDig = true;
    moves.allow1by1 = true;
    bot.pathfinder.setMovements(moves);
  } catch (e) {}
  state = 'running';
  saveState();
  log('режим ' + cfg.mode + ' запущен');
  const mode = cfg.mode;
  if (mode === 'mine') mineLoop();
  else if (mode === 'brew') brewLoop();
  else if (mode === 'fish') fishLoop();
  else if (mode === 'farm') farmLoop();
  else if (mode === 'smelt') smeltLoop();
  else if (mode === 'eat') eatLoop();
  else if (mode === 'afk') afkLoop();
  else if (mode === 'macro') macroLoop();
}

bot = mineflayer.createBot({
  host: cfg.host,
  port: cfg.port,
  username: cfg.username,
  version: cfg.version || false,
  auth: 'offline',
  checkTimeoutInterval: 120000,
  hideErrors: false
});

bot.on('login', function () { log('вход как ' + cfg.username + ' на ' + cfg.host + ':' + cfg.port); });
bot.on('spawn', onSpawn);
bot.on('error', function (e) { state = 'error'; saveState({ error: String(e && e.message ? e.message : e) }); log('error', e && e.message ? e.message : e); });
bot.on('kicked', function (reason) { state = 'kicked'; saveState({ reason: JSON.stringify(reason) }); log('кик:', JSON.stringify(reason)); stopFlag = true; setTimeout(function () { process.exit(3); }, 500); });
bot.on('message', function (m) { log('чат:', m.toString()); });
bot.on('death', function () { state = 'dead'; saveState(); log('смерть'); });
bot.on('end', function (reason) { if (!stopFlag) { state = 'ended'; saveState({ reason: String(reason) }); } log('соединение закрыто'); setTimeout(function () { process.exit(0); }, 400); });

if (cfg.duration_minutes && cfg.duration_minutes > 0) {
  setTimeout(function () { log('время вышло'); stopFlag = true; state = 'done'; saveState(); setTimeout(function () { process.exit(0); }, 800); }, cfg.duration_minutes * 60000);
}
setInterval(function () { saveState(); }, 5000);
"""
