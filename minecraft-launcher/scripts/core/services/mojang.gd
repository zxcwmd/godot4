class_name MojangService
extends Node
## Работа с манифестами Mojang: список версий, version.json, версия Java.

var manifest: Dictionary = {}
var manifest_ready := false
var _cache := {}

func load_manifest(force := false) -> Dictionary:
	if manifest_ready and not force:
		return manifest
	var r := await Net.get_json(Constants.MC_VERSION_MANIFEST, {}, 20.0)
	if bool(r.get("ok", false)) and r["json"] != null:
		manifest = r["json"]
		manifest_ready = true
	else:
		Bus.logged.emit("error", "Mojang: %s" % String(r.get("error", "неизвестная ошибка")))
	return manifest

func latest(kind := "release") -> Dictionary:
	if not manifest_ready:
		await load_manifest()
	return manifest.get(kind, {})

## Список версий: kind = "" (все), "release", "snapshot", "old_beta", "old_alpha".
func version_list(kind := "release", limit := 200) -> Array:
	if not manifest_ready:
		await load_manifest()
	var out: Array = []
	for v in manifest.get("versions", []):
		var item: Dictionary = v
		if kind != "" and String(item.get("type", "")) != kind:
			continue
		out.append(item)
		if out.size() >= limit:
			break
	return out

func version_url(id: String) -> String:
	for v in manifest.get("versions", []):
		if String(v.get("id", "")) == id:
			return String(v.get("url", ""))
	return ""

func version_json(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var url := version_url(id)
	if url == "":
		return {}
	var r := await Net.get_json(url, {}, 30.0)
	if bool(r.get("ok", false)) and r["json"] != null:
		_cache[id] = r["json"]
		return r["json"]
	Bus.logged.emit("error", "Mojang: не удалось получить version.json для %s" % id)
	return {}

func java_major(version_json: Dictionary) -> int:
	var jv: Dictionary = version_json.get("javaVersion", {})
	if jv.is_empty():
		return 17
	return int(jv.get("majorVersion", 17))

func os_rule_name() -> String:
	match OS.get_name():
		"Windows": return "windows"
		"macOS": return "osx"
		_: return "linux"

func arch_rule_name() -> String:
	var arch := Engine.get_architecture_name().to_lower()
	if arch.contains("arm"):
		return "arm64"
	return "x86"
