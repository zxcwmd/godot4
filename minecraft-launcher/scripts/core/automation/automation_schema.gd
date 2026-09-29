class_name AutomationSchema
extends RefCounted
## Описание параметров для каждого вида автоматизации.
## UI строит форму редактирования задачи прямо по этой схеме, поэтому новый
## вид бота не требует правок в интерфейсе.

const CONNECTION_FIELDS := [
	{"key": "host", "label": "Адрес сервера", "type": "text", "default": "127.0.0.1", "hint": "IP или домен"},
	{"key": "port", "label": "Порт", "type": "int", "min": 1, "max": 65535, "default": 25565},
	{"key": "username", "label": "Ник бота", "type": "text", "default": "AuroraBot", "hint": "Ник в игре"},
	{"key": "version", "label": "Версия клиента", "type": "text", "default": "", "hint": "Пусто — определить автоматически"},
]

const ORES := ["coal_ore", "iron_ore", "copper_ore", "gold_ore", "redstone_ore", "lapis_ore", "diamond_ore", "emerald_ore", "ancient_debris", "nether_quartz_ore"]
const CROPS := ["wheat", "carrot", "potato", "beetroot", "nether_wart", "pumpkin", "melon"]
const POTIONS := ["healing", "regeneration", "strength", "swiftness", "fire_resistance", "water_breathing", "night_vision", "invisibility", "leaping"]
const FOODS := ["bread", "cooked_beef", "cooked_porkchop", "golden_apple", "carrot", "baked_potato", "cooked_chicken"]
const SMELTABLE := ["raw_iron", "raw_gold", "raw_copper", "sand", "cobblestone", "oak_log", "beef", "porkchop", "chicken"]

static func kinds() -> Array:
	return ["mine", "brew", "fish", "farm", "smelt", "eat", "afk", "macro"]

static func kind_icon(kind: String) -> String:
	match kind:
		"mine": return "pick"
		"brew": return "flask"
		"fish": return "hook"
		"farm": return "sprout"
		"smelt": return "flame"
		"eat": return "apple"
		"afk": return "clock"
		"macro": return "bolt"
	return "robot"

static func kind_blurb(kind: String) -> String:
	match kind:
		"mine": return "Ищет и добывает заданные руды, сбрасывает в сундук, ставит факелы."
		"brew": return "Варит зелья на стэнде: наливает бутылочки, топливо, ингредиенты, ждёт цикл."
		"fish": return "Автоматически ловит рыбу удочкой и подбирает добычу."
		"farm": return "Собирает спелые культуры и пересаживает их заново."
		"smelt": return "Жарит ресурсы в печи, следит за топливом и забирает результат."
		"eat": return "Держит сытость выше порога, автоматически ест из инвентаря."
		"afk": return "Не даёт кикнуть за простой: прыжки, повороты, взмах рукой."
		"macro": return "Свой сценарий: чат, ожидание, зажатие клавиш, действия."
	return ""

static func fields(kind: String) -> Array:
	var base: Array = [
		{"key": "duration_minutes", "label": "Длительность, мин", "type": "int", "min": 1, "max": 720, "default": 60, "hint": "0 — бессрочно (макс. 720)"},
	]
	match kind:
		"mine":
			return base + [
				{"key": "ores", "label": "Руды", "type": "tags", "options": ORES, "default": ["iron_ore", "coal_ore"]},
				{"key": "radius", "label": "Радиус поиска", "type": "int", "min": 8, "max": 64, "default": 24},
				{"key": "min_y", "label": "Мин. высота Y", "type": "int", "min": -64, "max": 320, "default": 12},
				{"key": "max_y", "label": "Макс. высота Y", "type": "int", "min": -64, "max": 320, "default": 60},
				{"key": "chest", "label": "Сундук для сброса", "type": "text", "default": "", "hint": "Часть имени; пусто — ближайший сундук"},
				{"key": "torch", "label": "Ставить факелы", "type": "bool", "default": true},
			]
		"brew":
			return base + [
				{"key": "recipes", "label": "Зелья", "type": "tags", "options": POTIONS, "default": ["healing", "swiftness"]},
				{"key": "count", "label": "Циклов варки", "type": "int", "min": 1, "max": 64, "default": 3},
				{"key": "stand_radius", "label": "Радиус поиска стэнда", "type": "int", "min": 4, "max": 64, "default": 16},
				{"key": "refill_water", "label": "Наполнять бутылочки водой", "type": "bool", "default": true},
			]
		"fish":
			return base + [
				{"key": "rod_slot", "label": "Слот удочки", "type": "int", "min": 1, "max": 9, "default": 1},
				{"key": "drop_junk", "label": "Выбрасывать мусор", "type": "bool", "default": true},
			]
		"farm":
			return base + [
				{"key": "crops", "label": "Культуры", "type": "tags", "options": CROPS, "default": ["wheat", "carrot"]},
				{"key": "radius", "label": "Радиус поиска", "type": "int", "min": 4, "max": 64, "default": 16},
				{"key": "replant", "label": "Пересаживать", "type": "bool", "default": true},
			]
		"smelt":
			return base + [
				{"key": "items", "label": "Что жарить", "type": "tags", "options": SMELTABLE, "default": ["raw_iron"]},
				{"key": "fuel", "label": "Топливо", "type": "text", "default": "coal", "hint": "coal, charcoal, blaze_rod, log..."},
				{"key": "radius", "label": "Радиус поиска печи", "type": "int", "min": 4, "max": 64, "default": 16},
			]
		"eat":
			return base + [
				{"key": "threshold", "label": "Порог сытости", "type": "int", "min": 2, "max": 20, "default": 14},
				{"key": "foods", "label": "Что есть", "type": "tags", "options": FOODS, "default": ["bread", "cooked_beef"]},
			]
		"afk":
			return base + [
				{"key": "jump_seconds", "label": "Прыжок каждые, сек", "type": "int", "min": 5, "max": 600, "default": 45},
				{"key": "swing", "label": "Взмах рукой", "type": "bool", "default": true},
				{"key": "chat", "label": "Сообщение в чат", "type": "text", "default": "", "hint": "Пусто — не писать"},
				{"key": "chat_seconds", "label": "Повторять сообщение, сек", "type": "int", "min": 30, "max": 3600, "default": 300},
			]
		"macro":
			return base + [
				{"key": "steps", "label": "Сценарий", "type": "text_area", "default": "chat /home\nwait 3\ndig\nwait 2\nuse\n", "hint": "chat <текст> · wait <сек> · key <направление> <сек> · dig · use · look <yaw> <pitch>"},
			]
	return base

## Значения по умолчанию для нового задачи (без блока подключения — он берётся из настроек).
static func defaults(kind: String) -> Dictionary:
	var out := {}
	for field in fields(kind):
		out[String(field["key"])] = field["default"]
	return out
