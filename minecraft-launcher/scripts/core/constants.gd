class_name Constants
extends RefCounted
## Константы приложения: сетевые endpoint-ы, пути данных и палитра оформления.

const APP_NAME := "Aurora Launcher"
const APP_SHORT := "Aurora"
const APP_VERSION := "1.0.0"
const REPO_URL := "https://github.com/aurora-launcher/aurora"
const MIN_GODOT := "4.2"

# ---------------------------------------------------------------- сеть / API --
const MC_VERSION_MANIFEST := "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json"
const MC_JAVA_MANIFEST := "https://launchermeta.mojang.com/mc/game/java_manifest.json"
const MC_RESOURCES := "https://resources.download.minecraft.net/"
const ADOPTIUM_LATEST := "https://api.adoptium.net/v3/binary/latest/%d/ga/%s/%s/jre/hotspot/normal/eclipse"
const MODRINTH_API := "https://api.modrinth.com/v2"
const FABRIC_META := "https://meta.fabricmc.net/v2"
const QUILT_META := "https://meta.quiltmc.org/api/v3"
const FORGE_PROMOTIONS := "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json"
const FORGE_MAVEN := "https://maven.minecraftforge.net/net/minecraftforge/forge/"
const NEOFORGE_META := "https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml"
const NEOFORGE_MAVEN := "https://maven.neoforged.net/releases/net/neoforged/neoforge/"

# ------------------------------------------------------------ хранение данных --
const DATA_DIR := "user://aurora"
const SETTINGS_FILE := DATA_DIR + "/settings.json"
const INSTANCES_FILE := DATA_DIR + "/instances.json"
const TASKS_FILE := DATA_DIR + "/automation.json"
const ACCOUNT_FILE := DATA_DIR + "/accounts.json"
const INSTANCES_DIR := DATA_DIR + "/instances"
const RUNTIME_DIR := DATA_DIR + "/runtime"
const JAVA_DIR := DATA_DIR + "/java"
const AUTOMATION_DIR := DATA_DIR + "/automation"
const LOG_DIR := DATA_DIR + "/logs"

# ------------------------------------------------------------------ палитра --
const C_BG := Color.html("#05070f")
const C_SURFACE := Color.html("#0b1020")
const C_SURFACE_2 := Color.html("#111931")
const C_LINE := Color.html("#1e2a4a")
const C_TEXT := Color.html("#e8ecf8")
const C_TEXT_MUTED := Color.html("#93a0bd")
const C_TEXT_DIM := Color.html("#64748b")
const C_OK := Color.html("#34d399")
const C_WARN := Color.html("#fbbf24")
const C_ERR := Color.html("#fb7185")
const C_INFO := Color.html("#38bdf8")

## Акценты оформления (выбираются в настройках).
static func accents() -> Dictionary:
	return {
		"aurora": {"name": "Аврора", "a": Color.html("#22d3ee"), "b": Color.html("#a855f7")},
		"emerald": {"name": "Изумруд", "a": Color.html("#34d399"), "b": Color.html("#0ea5e9")},
		"sunset": {"name": "Закат", "a": Color.html("#fb923c"), "b": Color.html("#f43f5e")},
		"violet": {"name": "Аметист", "a": Color.html("#818cf8"), "b": Color.html("#e879f9")},
	}

static func accent_colors(key: String) -> Dictionary:
	var all := accents()
	if all.has(key):
		return all[key]
	return all["aurora"]

# --------------------------------------------------------- человекочитаемые --
static func kind_title(kind: String) -> String:
	match kind:
		"mine": return "Автошахта"
		"brew": return "Автоварка зелий"
		"fish": return "Авторыбалка"
		"farm": return "Автоферма"
		"smelt": return "Автоплавильня"
		"eat": return "Автопитание"
		"afk": return "Анти-AFK"
		"macro": return "Макрос"
	return kind

static func loader_title(loader: String) -> String:
	match loader:
		"vanilla": return "Vanilla"
		"fabric": return "Fabric"
		"quilt": return "Quilt"
		"forge": return "Forge"
		"neoforge": return "NeoForge"
	return loader

static func trigger_title(trigger: String) -> String:
	match trigger:
		"manual": return "Вручную"
		"on_launch": return "При запуске игры"
		"interval": return "По расписанию"
	return trigger

static func format_bytes(bytes: int) -> String:
	var f := float(bytes)
	var units := ["Б", "КБ", "МБ", "ГБ", "ТБ"]
	var i := 0
	while f >= 1024.0 and i < units.size() - 1:
		f /= 1024.0
		i += 1
	return "%s %s" % [_round_str(f), units[i]]

static func format_duration(seconds: float) -> String:
	var s := int(absf(seconds))
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%02d:%02d:%02d" % [h, m, sec]
	return "%02d:%02d" % [m, sec]

static func _round_str(v: float) -> String:
	if v >= 100.0:
		return "%d" % int(v)
	if v >= 10.0:
		return "%.1f" % v
	return "%.2f" % v
