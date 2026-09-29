class_name GameLauncher
extends Node
## Подготовка и запуск Minecraft: профиль версии, библиотеки, ресурсы, Java,
## аргументы, обёрточный скрипт, чтение игрового лога и корректное завершение.
##
## Узел должен быть добавлен в дерево сцен (нужен _process для наблюдения
## за процессом игры).

signal progress(label: String, ratio: float)
signal log_line(level: String, text: String)
signal state_changed(state: String, pid: int)
signal exited(code: int)

var running := false
var _pid := -1
var _game_dir := ""
var _log_size := 0
var _stop_requested := false
var _last_state := ""

func _process(_delta: float) -> void:
	if not running:
		return
	_tail_log()
	if _stop_requested:
		_finish(-1)
		return
	if not Proc.alive(_pid):
		_finish(_read_exit_code())

## Запускает игру. Возвращает PID или -1 при ошибке.
func launch(instance: Dictionary) -> int:
	if running:
		log_line.emit("warn", "Игра уже запущена")
		return -1
	var id := String(instance.get("id", ""))
	if id == "":
		log_line.emit("error", "Экземпляр не выбран")
		state_changed.emit("error", -1)
		return -1
	_stop_requested = false
	state_changed.emit("preparing", -1)
	log_line.emit("info", "Готовлю %s..." % String(instance.get("name", id)))

	var prepared := await prepare(instance)
	if not bool(prepared.get("ok", false)):
		log_line.emit("error", String(prepared.get("error", "неизвестная ошибка")))
		state_changed.emit("error", -1)
		return -1

	var wrapper := _write_wrapper(String(prepared["java"]), prepared["argv"], String(prepared["workdir"]))
	if wrapper == "":
		log_line.emit("error", "Не удалось создать скрипт запуска")
		state_changed.emit("error", -1)
		return -1

	_log_size = 0
	_pid = _spawn(wrapper)
	if _pid <= 0:
		log_line.emit("error", "Не удалось запустить процесс (OS.create_process недоступен?)")
		state_changed.emit("error", -1)
		return -1

	running = true
	state_changed.emit("running", _pid)
	log_line.emit("ok", "Игра запущена, PID %d" % _pid)
	return _pid

func stop() -> void:
	if not running:
		return
	log_line.emit("warn", "Останавливаю игру...")
	_stop_requested = true
	Proc.kill(_pid)
	_finish(-1)

# ------------------------------------------------------------- подготовка ----
func prepare(instance: Dictionary) -> Dictionary:
	var id := String(instance.get("id", ""))
	_game_dir = Store.instance_dir(id)
	DirAccess.make_dir_recursive_absolute(_game_dir)

	var loader := String(instance.get("loader", "vanilla"))
	var mc_version := String(instance.get("version", ""))
	if mc_version == "":
		return {"ok": false, "error": "Не указана версия Minecraft"}

	# --- профиль версии -----------------------------------------------------
	var vjson: Dictionary = {}
	if loader == "vanilla":
		var vanilla := await _download_vanilla(mc_version)
		if not bool(vanilla.get("ok", false)):
			return vanilla
		vjson = vanilla["json"]
	else:
		var loader_json := await Loader.resolve_version_json(_game_dir, loader)
		if loader_json.is_empty():
			log_line.emit("info", "Устанавливаю %s %s..." % [loader, mc_version])
			var installed := await Loader.install(loader, mc_version, _game_dir)
			if not bool(installed.get("ok", false)):
				return {"ok": false, "error": String(installed.get("error", "не удалось установить загрузчик"))}
			loader_json = installed.get("json", {})
		if loader_json.is_empty():
			return {"ok": false, "error": "Загрузчик %s не дал профиль версии" % loader}
		vjson = loader_json

	# --- слияние с родительским профилем ------------------------------------
	var inherits := String(vjson.get("inheritsFrom", ""))
	if inherits != "":
		var parent := await Mojang.version_json(inherits)
		vjson = _merge(vjson, parent)

	# --- клиентский jar ------------------------------------------------------
	var client := await _ensure_client_jar(vjson)
	if not bool(client.get("ok", false)):
		return client

	# --- библиотеки и нативные ----------------------------------------------
	var libs := await _ensure_libraries(vjson)
	if not bool(libs.get("ok", false)):
		return libs

	# --- ресурсы -------------------------------------------------------------
	var assets := await _ensure_assets(vjson)
	if not bool(assets.get("ok", false)):
		return assets

	# --- Java ----------------------------------------------------------------
	var major := Mojang.java_major(vjson)
	var java_path := String(instance.get("java_path", ""))
	if java_path == "":
		java_path = String(Store.setting("java_path", ""))
	var java: Dictionary
	if java_path != "" and FileAccess.file_exists(ProjectSettings.globalize_path(java_path)):
		java = {"ok": true, "path": java_path}
	else:
		java = await Java.ensure(major, bool(Store.setting("auto_install_java", true)))
	if not bool(java.get("ok", false)):
		return {"ok": false, "error": String(java.get("error", "Java не найдена"))}
	log_line.emit("info", "Java %d: %s" % [major, String(java.get("path", ""))])

	var argv := _build_argv(instance, vjson, String(libs["classpath"]), String(client["path"]), String(libs["natives"]), String(assets["assets_dir"]))
	progress.emit("Готово", 1.0)
	return {"ok": true, "argv": argv, "workdir": _game_dir, "java": String(java["path"])}

func _download_vanilla(mc_version: String) -> Dictionary:
	var vjson := await Mojang.version_json(mc_version)
	if vjson.is_empty():
		return {"ok": false, "error": "Неизвестная версия Minecraft: %s" % mc_version}
	var client: Dictionary = vjson.get("downloads", {}).get("client", {})
	if client.is_empty():
		return {"ok": false, "error": "В профиле версии нет клиента"}
	var dest := Store.runtime_dir().path_join("versions").path_join(mc_version).path_join("%s.jar" % mc_version)
	if not _file_ok(dest):
		progress.emit("Скачиваю клиент %s..." % mc_version, 0.0)
		var r := await Net.download_file(String(client.get("url", "")), dest, {}, 900.0, func(ratio):
			progress.emit("Клиент %s" % mc_version, ratio)
			Bus.download_progress.emit("Клиент Minecraft", ratio)
		)
		if not bool(r.get("ok", false)):
			return {"ok": false, "error": "Не удалось скачать клиент: %s" % String(r.get("error", ""))}
	return {"ok": true, "json": vjson, "path": dest}

func _ensure_client_jar(vjson: Dictionary) -> Dictionary:
	var client: Dictionary = vjson.get("downloads", {}).get("client", {})
	if client.is_empty():
		return {"ok": false, "error": "В профиле версии нет клиента"}
	var version_id := String(vjson.get("id", "client"))
	var dest := Store.runtime_dir().path_join("versions").path_join(version_id).path_join("%s.jar" % version_id)
	if not _file_ok(dest):
		var r := await Net.download_file(String(client.get("url", "")), dest, {}, 900.0, func(ratio):
			progress.emit("Клиент %s" % version_id, ratio)
			Bus.download_progress.emit("Клиент Minecraft", ratio)
		)
		if not bool(r.get("ok", false)):
			return {"ok": false, "error": "Не удалось скачать клиент: %s" % String(r.get("error", ""))}
	return {"ok": true, "path": dest}

func _ensure_libraries(vjson: Dictionary) -> Dictionary:
	var lib_root := Store.runtime_dir().path_join("libraries")
	var natives_dir := Store.runtime_dir().path_join("natives")
	DirAccess.make_dir_recursive_absolute(lib_root)
	DirAccess.make_dir_recursive_absolute(natives_dir)

	var os_name := Mojang.os_rule_name()
	var arch := Mojang.arch_rule_name()
	var cp: Array = []
	var libs: Array = vjson.get("libraries", [])
	var total := maxi(libs.size(), 1)
	var done := 0
	for lib in libs:
		var entry: Dictionary = lib
		done += 1
		if not _rules_allow(entry.get("rules", []), os_name, arch):
			continue
		var downloads: Dictionary = entry.get("downloads", {})
		if entry.has("natives"):
			var native_key := String(entry["natives"].get(os_name, ""))
			var classifiers: Dictionary = downloads.get("classifiers", {})
			if native_key != "" and classifiers.has(native_key):
				var art: Dictionary = classifiers[native_key]
				var np := lib_root.path_join(String(art.get("path", "")))
				await _ensure_file(String(art.get("url", "")), np)
				_extract_natives(np, natives_dir)
			continue
		var artifact: Dictionary = downloads.get("artifact", {})
		var path := String(artifact.get("path", ""))
		if path == "":
			continue
		var dest := lib_root.path_join(path)
		await _ensure_file(String(artifact.get("url", "")), dest)
		cp.append(dest)
		if done % 10 == 0:
			progress.emit("Библиотеки %d/%d" % [done, total], float(done) / float(total))

	if cp.is_empty():
		return {"ok": false, "error": "Не удалось собрать classpath"}
	var sep := ";" if Proc.is_windows() else ":"
	return {"ok": true, "classpath": sep.join(cp), "natives": natives_dir}

func _ensure_file(url: String, dest: String) -> void:
	if url == "":
		return
	if _file_ok(dest):
		return
	var r := await Net.download_file(url, dest, {}, 600.0)
	if not bool(r.get("ok", false)):
		log_line.emit("warn", "Не скачан файл %s (%s)" % [url, String(r.get("error", ""))])

func _file_ok(path: String) -> bool:
	var abs := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs):
		return false
	var fh := FileAccess.open(abs, FileAccess.READ)
	if fh == null:
		return false
	var size := fh.get_length()
	fh.close()
	return size > 0

func _extract_natives(jar_path: String, natives_dir: String) -> void:
	var abs := ProjectSettings.globalize_path(jar_path)
	if not FileAccess.file_exists(abs):
		return
	var zip := ZipArchive.new()
	if not zip.open(abs):
		return
	zip.extract_all(natives_dir)
	zip.close()

func _ensure_assets(vjson: Dictionary) -> Dictionary:
	var assets_root := Store.runtime_dir().path_join("assets")
	var asset_index: Dictionary = vjson.get("assetIndex", {})
	if asset_index.is_empty():
		return {"ok": true, "assets_dir": assets_root, "index_id": ""}
	var index_id := String(asset_index.get("id", "pre"))
	var index_path := assets_root.path_join("indexes").path_join("%s.json" % index_id)
	if not _file_ok(index_path):
		var r := await Net.download_file(String(asset_index.get("url", "")), index_path, {}, 300.0)
		if not bool(r.get("ok", false)):
			return {"ok": false, "error": "Не удалось скачать индекс ресурсов: %s" % String(r.get("error", ""))}
	var fh := FileAccess.open(ProjectSettings.globalize_path(index_path), FileAccess.READ)
	if fh == null:
		return {"ok": false, "error": "Индекс ресурсов недоступен"}
	var index = JSON.parse_string(fh.get_as_text())
	fh.close()
	if index == null:
		return {"ok": false, "error": "Битый индекс ресурсов"}

	var objects: Dictionary = index.get("objects", {})
	var missing: Array = []
	for key in objects.keys():
		var hash := String(key)
		var obj: Dictionary = objects[key]
		var dest := assets_root.path_join("objects").path_join(hash.substr(0, 2)).path_join(hash)
		if _file_ok(dest):
			continue
		missing.append({"hash": hash, "dest": dest, "size": int(obj.get("size", 0))})

	var total := maxi(missing.size(), 1)
	var done := 0
	for item in missing:
		var hash := String(item["hash"])
		var url := "%s%s/%s" % [Constants.MC_RESOURCES, hash.substr(0, 2), hash]
		await _ensure_file(url, String(item["dest"]))
		done += 1
		if done % 20 == 0 or done == total:
			progress.emit("Ресурсы %d/%d" % [done, total], float(done) / float(total))
			Bus.download_progress.emit("Ресурсы", float(done) / float(total))

	if String(vjson.get("assets", "1")) == "legacy":
		_mirror_legacy(objects, assets_root)
	return {"ok": true, "assets_dir": assets_root, "index_id": index_id}

## Для очень старых версий движок ждёт ресурсы в assets/virtual/legacy/.
func _mirror_legacy(objects: Dictionary, assets_root: String) -> void:
	var legacy_root := assets_root.path_join("virtual").path_join("legacy")
	DirAccess.make_dir_recursive_absolute(legacy_root)
	for key in objects.keys():
		var hash := String(key)
		var obj: Dictionary = objects[key]
		var name := String(obj.get("path", hash))
		var src := assets_root.path_join("objects").path_join(hash.substr(0, 2)).path_join(hash)
		var dst := legacy_root.path_join(name)
		if FileAccess.file_exists(ProjectSettings.globalize_path(dst)):
			continue
		if not FileAccess.file_exists(ProjectSettings.globalize_path(src)):
			continue
		var in_fh := FileAccess.open(src, FileAccess.READ)
		if in_fh == null:
			continue
		var data := in_fh.get_buffer(in_fh.get_length())
		in_fh.close()
		DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
		var out_fh := FileAccess.open(dst, FileAccess.WRITE)
		if out_fh == null:
			continue
		out_fh.store_buffer(data)
		out_fh.close()

# --------------------------------------------------------------- правила ----
func _rules_allow(rules, os_name: String, arch: String) -> bool:
	if rules == null or not (rules is Array) or rules.is_empty():
		return true
	var allowed := true
	for rule in rules:
		var r: Dictionary = rule
		if _rule_matches(r, os_name, arch):
			if String(r.get("action", "allow")) == "disallow":
				allowed = false
			else:
				allowed = true
	return allowed

func _rule_matches(rule: Dictionary, os_name: String, arch: String) -> bool:
	if rule.has("os"):
		var os_rule: Dictionary = rule["os"]
		var wanted := String(os_rule.get("name", "")).to_lower()
		if wanted != "" and wanted != os_name:
			return false
		var wanted_arch := String(os_rule.get("arch", "")).to_lower()
		if wanted_arch != "" and wanted_arch != arch:
			return false
	if rule.has("arch"):
		if String(rule.get("arch", "")).to_lower() != arch:
			return false
	return true

# -------------------------------------------------------------- аргументы ----
func _build_argv(instance: Dictionary, vjson: Dictionary, classpath: String, client_jar: String, natives_dir: String, assets_dir: String) -> PackedStringArray:
	var argv := PackedStringArray()
	var ram := int(Store.setting("ram_mb", 4096))
	argv.append("-Xmx%dM" % ram)
	argv.append("-Xms%dM" % maxi(256, int(ram * 0.25)))
	argv.append("-Djava.library.path=%s" % natives_dir)
	argv.append("-Dminecraft.launcher.brand=Aurora")
	argv.append("-cp")
	argv.append(classpath)
	argv.append(String(vjson.get("mainClass", "net.minecraft.client.main.Main")))

	var account := Store.account
	var username := String(account.get("name", "Player"))
	if username == "":
		username = "Player"
	var uuid := String(account.get("uuid", ""))
	if uuid == "":
		uuid = _offline_uuid(username)
	var token := String(account.get("token", ""))
	if token == "":
		token = "0"
	var user_type := "msa" if String(account.get("type", "offline")) == "msa" else "legacy"
	var asset_id := "pre"
	var ai: Dictionary = vjson.get("assetIndex", {})
	if not ai.is_empty():
		asset_id = String(ai.get("id", "pre"))

	var common := PackedStringArray([
		"--gameDir", _game_dir,
		"--assetsDir", assets_dir,
		"--assetIndex", asset_id,
		"--uuid", uuid,
		"--accessToken", token,
		"--userType", user_type,
		"--versionType", "Aurora Launcher " + Constants.APP_VERSION,
		"--version", String(vjson.get("id", String(instance.get("version", "1.0")))),
	])
	var os_name := Mojang.os_rule_name()
	var arch := Mojang.arch_rule_name()

	if vjson.has("arguments"):
		var args: Dictionary = vjson["arguments"]
		for a in args.get("game", []):
			if a is String:
				argv.append(String(a))
			elif a is Dictionary:
				var d: Dictionary = a
				if _rules_allow(d.get("rules", []), os_name, arch):
					var val = d.get("value", "")
					if val is String:
						argv.append(String(val))
					elif val is Array:
						for v in val:
							argv.append(String(v))
		for c in common:
			argv.append(c)
	elif vjson.has("minecraftArguments"):
		var raw := String(vjson["minecraftArguments"])
		raw = raw.replace("${auth_player_name}", username)
		raw = raw.replace("${auth_uuid}", uuid)
		raw = raw.replace("${auth_access_token}", token)
		raw = raw.replace("${user_type}", user_type)
		raw = raw.replace("${version_type}", "Aurora")
		raw = raw.replace("${game_directory}", _game_dir)
		raw = raw.replace("${assets_root}", assets_dir)
		raw = raw.replace("${assets_index_name}", asset_id)
		raw = raw.replace("${game_assets}", assets_dir)
		raw = raw.replace("${user_properties}", "{}")
		for part in raw.split(" ", false):
			argv.append(String(part))
		for c in common:
			argv.append(c)
	else:
		for c in common:
			argv.append(c)
	return argv

func _merge(child: Dictionary, parent: Dictionary) -> Dictionary:
	if parent.is_empty():
		return child
	var out := parent.duplicate(true)
	var libs: Array = []
	var seen := {}
	for lib in out.get("libraries", []):
		var e: Dictionary = lib
		libs.append(e)
		seen[String(e.get("name", ""))] = true
	for lib in child.get("libraries", []):
		var e2: Dictionary = lib
		var name := String(e2.get("name", ""))
		if seen.has(name):
			for i in range(libs.size()):
				if String((libs[i] as Dictionary).get("name", "")) == name:
					libs[i] = e2
					break
		else:
			libs.append(e2)
			seen[name] = true
	out["libraries"] = libs
	for key in ["mainClass", "assetIndex", "assets", "javaVersion", "downloads", "id", "minecraftArguments"]:
		if child.has(key):
			out[key] = child[key]
	if child.has("arguments"):
		out["arguments"] = child["arguments"]
	return out

func _offline_uuid(name: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(("OfflinePlayer:" + name).to_utf8_buffer())
	var digest := ctx.finish()
	if digest.size() < 16:
		return "00000000-0000-0000-0000-000000000000"
	var bytes := digest
	bytes[6] = (bytes[6] & 0x0f) | 0x30
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5], bytes[6], bytes[7],
		bytes[8], bytes[9], bytes[10], bytes[11],
		bytes[12], bytes[13], bytes[14], bytes[15]
	]

# ------------------------------------------------------------- запуск ------
func _write_wrapper(java: String, argv: PackedStringArray, workdir: String) -> String:
	DirAccess.make_dir_recursive_absolute(_game_dir)
	var script_path := ""
	if Proc.is_windows():
		script_path = _game_dir.path_join("aurora-launch.bat")
		var lines := PackedStringArray(["@echo off"])
		var quoted := PackedStringArray()
		for a in argv:
			quoted.append('"%s"' % String(a))
		lines.append('"%s" %s' % [java, " ".join(quoted)])
		lines.append("echo %ERRORLEVEL% > exit_code.txt")
		_write_text(script_path, "\n".join(lines))
	else:
		script_path = _game_dir.path_join("aurora-launch.sh")
		var lines2 := PackedStringArray(["#!/bin/sh", "cd " + _sh_quote(workdir)])
		var quoted2 := PackedStringArray()
		for a in argv:
			quoted2.append(_sh_quote(String(a)))
		lines2.append("%s %s" % [_sh_quote(java), " ".join(quoted2)])
		lines2.append("echo $? > exit_code.txt")
		_write_text(script_path, "\n".join(lines2) + "\n")
	return script_path

func _sh_quote(value: String) -> String:
	if value.contains("'"):
		return '"' + value + '"'
	return "'" + value + "'"

func _write_text(path: String, text: String) -> void:
	var fh := FileAccess.open(path, FileAccess.WRITE)
	if fh == null:
		return
	fh.store_string(text)
	fh.close()

func _spawn(wrapper: String) -> int:
	if Proc.is_windows():
		return Proc.spawn("cmd.exe", PackedStringArray(["/c", wrapper]), _game_dir)
	return Proc.spawn("/bin/sh", PackedStringArray([wrapper]), _game_dir)

func _read_exit_code() -> int:
	var path := _game_dir.path_join("exit_code.txt")
	var abs := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs):
		return 0
	var fh := FileAccess.open(abs, FileAccess.READ)
	if fh == null:
		return 0
	var text := fh.get_as_text().strip_edges()
	fh.close()
	if text.is_valid_int():
		return int(text)
	return 0

func _tail_log() -> void:
	var abs := ProjectSettings.globalize_path(_game_dir.path_join("logs").path_join("latest.log"))
	if not FileAccess.file_exists(abs):
		return
	var fh := FileAccess.open(abs, FileAccess.READ)
	if fh == null:
		return
	fh.seek(_log_size)
	var rest := fh.get_length() - _log_size
	if rest <= 0:
		fh.close()
		return
	var chunk := fh.get_buffer(rest)
	_log_size = fh.get_length()
	fh.close()
	if chunk.is_empty():
		return
	var lines := chunk.get_string_from_utf8().replace("\r\n", "\n").split("\n")
	var emitted := 0
	for line in lines:
		var text := String(line).strip_edges()
		if text == "":
			continue
		log_line.emit("game", text)
		emitted += 1
		if emitted >= 25:
			break

func _finish(code: int) -> void:
	if not running and _last_state == "stopped":
		return
	running = false
	_pid = -1
	_last_state = "stopped"
	_tail_log()
	state_changed.emit("stopped", code)
	exited.emit(code)
	if _stop_requested:
		log_line.emit("warn", "Игра остановлена пользователем")
	else:
		log_line.emit("info", "Игра завершилась (код %d)" % code)
