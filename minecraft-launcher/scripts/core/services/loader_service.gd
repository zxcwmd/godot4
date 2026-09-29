class_name LoaderService
extends Node
## Установка загрузчиков модов: Fabric, Quilt (через profile-json),
## Forge и NeoForge (через installer-jar).

signal progress(text: String, ratio: float)

func install(loader: String, mc_version: String, game_dir: String) -> Dictionary:
	match loader:
		"fabric":
			return await _install_profile_loader(mc_version, game_dir, Constants.FABRIC_META, "fabric-loader")
		"quilt":
			return await _install_profile_loader(mc_version, game_dir, Constants.QUILT_META, "quilt-loader")
		"forge":
			return await _install_forge_family(mc_version, game_dir, "forge")
		"neoforge":
			return await _install_forge_family(mc_version, game_dir, "neoforge")
	return {"ok": false, "error": "Неизвестный загрузчик: %s" % loader}

## Fabric / Quilt: лаунчер отдаёт готовый version.json, устанавливать ничего не надо.
func _install_profile_loader(mc_version: String, game_dir: String, meta: String, prefix: String) -> Dictionary:
	progress.emit("Ищу %s для %s..." % [prefix, mc_version], 0.1)
	var r := await Net.get_json("%s/versions/loader/%s" % [meta, mc_version], {}, 30.0)
	if not bool(r.get("ok", false)) or r["json"] == null:
		return {"ok": false, "error": "%s не поддерживает Minecraft %s" % [prefix, mc_version]}
	var list: Array = r["json"]
	if list.is_empty():
		return {"ok": false, "error": "%s не поддерживает Minecraft %s" % [prefix, mc_version]}
	var loader_version := ""
	var first: Dictionary = list[0]
	if first.has("loader"):
		loader_version = String(first["loader"].get("version", ""))
	else:
		loader_version = String(first.get("version", ""))
	if loader_version == "":
		return {"ok": false, "error": "%s: не удалось определить версию загрузчика" % prefix}

	progress.emit("Получаю профиль %s %s..." % [prefix, loader_version], 0.5)
	var pj := await Net.get_json("%s/versions/loader/%s/%s/profile/json" % [meta, mc_version, loader_version], {}, 30.0)
	if not bool(pj.get("ok", false)) or pj["json"] == null:
		return {"ok": false, "error": "%s: не удалось получить профиль" % prefix}
	var vjson: Dictionary = pj["json"]
	var dir_name := "%s-%s-%s" % [prefix, loader_version, mc_version]
	var dir_path := game_dir.path_join("versions").path_join(dir_name)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var f := FileAccess.open(dir_path.path_join(dir_name + ".json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(vjson, "\t"))
		f.close()
	progress.emit("%s готов" % prefix, 1.0)
	return {"ok": true, "json": vjson, "version_dir": dir_name, "loader_version": loader_version}

## Forge / NeoForge: качаем installer-jar и запускаем его с java.
func _install_forge_family(mc_version: String, game_dir: String, family: String) -> Dictionary:
	var loader_version := ""
	var jar_url := ""
	if family == "forge":
		var r := await Net.get_json(Constants.FORGE_PROMOTIONS, {}, 30.0)
		if bool(r.get("ok", false)) and r["json"] != null:
			var promos: Dictionary = r["json"].get("promotions", {})
			loader_version = String(promos.get("%s-latest" % mc_version, ""))
		if loader_version == "":
			return {"ok": false, "error": "Forge не собран для Minecraft %s" % mc_version}
		var full := "%s-%s" % [mc_version, loader_version]
		jar_url = "%s%s/forge-%s-installer.jar" % [Constants.FORGE_MAVEN, full, full]
	else:
		var xml := await Net.get_text(Constants.NEOFORGE_META, {}, 30.0)
		loader_version = _pick_neoforge(xml, mc_version)
		if loader_version == "":
			return {"ok": false, "error": "NeoForge не собран для Minecraft %s" % mc_version}
		jar_url = "%s%s/neoforge-%s-installer.jar" % [Constants.NEOFORGE_MAVEN, loader_version, loader_version]

	var jar_path := Store.runtime_dir().path_join("installers").path_join(jar_url.get_file())
	progress.emit("Скачиваю установщик %s %s..." % [family, loader_version], 0.1)
	Bus.download_progress.emit("Установщик %s" % family, 0.0)
	var dl := await Net.download_file(jar_url, jar_path, {}, 600.0, func(ratio):
		Bus.download_progress.emit("Установщик %s" % family, ratio)
		progress.emit("Скачиваю установщик %s..." % family, ratio)
	)
	if not bool(dl.get("ok", false)):
		return {"ok": false, "error": "Не удалось скачать установщик: %s" % String(dl.get("error", ""))}

	var vjson_probe := await _run_installer_jar(jar_path, game_dir, family)
	if not bool(vjson_probe.get("ok", false)):
		return vjson_probe
	progress.emit("%s готов" % family, 1.0)
	return {"ok": true, "json": vjson_probe.get("json", {}), "version_dir": vjson_probe.get("version_dir", ""), "loader_version": loader_version}

func _run_installer_jar(jar_path: String, game_dir: String, family: String) -> Dictionary:
	var major := 17
	var java := await Java.ensure(major)
	if not bool(java.get("ok", false)):
		return {"ok": false, "error": "Для установщика нужна Java 17: %s" % String(java.get("error", ""))}
	var res := Proc.run_capture(String(java["path"]), PackedStringArray(["-jar", jar_path, "--installClient", game_dir]), game_dir)
	if int(res.get("code", 1)) != 0:
		var tail := String(res.get("out", ""))
		if tail.length() > 400:
			tail = tail.substr(tail.length() - 400)
		return {"ok": false, "error": "Установщик %s завершился с ошибкой: %s" % [family, tail]}
	var found := resolve_version_json(game_dir, family)
	if found.is_empty():
		return {"ok": false, "error": "Установщик %s не создал профиль версии" % family}
	return found

## Ищет самый свежий созданный установщиком version.json в каталоге игры.
func resolve_version_json(game_dir: String, loader: String) -> Dictionary:
	var versions_dir := game_dir.path_join("versions")
	var best := {}
	var best_time := -1
	for d in DirAccess.get_directories_at(versions_dir):
		var dir_path := versions_dir.path_join(String(d))
		for f in DirAccess.get_files_at(dir_path):
			var file_name := String(f)
			if not file_name.ends_with(".json"):
				continue
			var full := dir_path.path_join(file_name)
			var fh := FileAccess.open(full, FileAccess.READ)
			if fh == null:
				continue
			var parsed = JSON.parse_string(fh.get_as_text())
			fh.close()
			if parsed == null:
				continue
			var pj: Dictionary = parsed
			var id := String(pj.get("id", "")).to_lower()
			if not id.contains(loader):
				continue
			var mtime := int(FileAccess.get_modified_time(full))
			if mtime > best_time:
				best_time = mtime
				best = pj
	return best

func _pick_neoforge(xml: String, mc_version: String) -> String:
	var re := RegEx.new()
	re.compile("<version>([^<]+)</version>")
	var prefix := _neoforge_prefix(mc_version)
	var best := ""
	var best_key := []
	for m in re.search_all(xml):
		var v := m.get_string(1)
		if prefix != "" and not v.begins_with(prefix):
			continue
		var key := _version_key(v)
		if best == "" or _compare_keys(key, best_key) > 0:
			best = v
			best_key = key
	return best

func _neoforge_prefix(mc_version: String) -> String:
	var parts := mc_version.split(".")
	if parts.size() >= 3:
		var minor := int(parts[1])
		var patch := int(parts[2])
		if minor == 20 and patch == 1:
			return "47."
		return "%d.%d." % [minor, patch]
	if parts.size() == 2:
		return "%s.0." % parts[1]
	return ""

func _version_key(v: String) -> Array:
	var key: Array = []
	var re := RegEx.new()
	re.compile("[0-9]+")
	for m in re.search_all(v):
		key.append(int(m.get_string(0)))
	return key

func _compare_keys(a: Array, b: Array) -> int:
	var n := mini(a.size(), b.size())
	for i in range(n):
		var x := int(a[i])
		var y := int(b[i])
		if x != y:
			return 1 if x > y else -1
	if a.size() != b.size():
		return 1 if a.size() > b.size() else -1
	return 0
