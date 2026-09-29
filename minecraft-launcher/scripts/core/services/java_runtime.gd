class_name JavaService
extends Node
## Поиск и (при необходимости) установка Java Runtime.

signal progress(text: String, ratio: float)

var detected: Array = []

func detect() -> Array:
	detected = []
	var sys := Proc.find_executable(Proc.exec_name("java"))
	if sys != "":
		var info := _probe(sys)
		if not info.is_empty():
			info["name"] = "Системная Java %d" % int(info.get("major", 0))
			info["source"] = "system"
			detected.append(info)
	for path in _bundled_javas():
		if path == sys:
			continue
		var info2 := _probe(path)
		if info2.is_empty():
			continue
		info2["name"] = "Aurora JRE %d" % int(info2.get("major", 0))
		info2["source"] = "bundled"
		detected.append(info2)
	Bus.java_changed.emit()
	return detected

func find(major: int) -> Dictionary:
	if detected.is_empty():
		detect()
	for info in detected:
		if int(info.get("major", 0)) == major:
			return info
	return {}

## Возвращает {"ok": bool, "path": String, "error": String}
func ensure(major: int, auto_install := true) -> Dictionary:
	var existing := find(major)
	if not existing.is_empty():
		return {"ok": true, "path": String(existing["path"]), "installed": false}
	if not auto_install:
		return {"ok": false, "error": "Java %d не найдена. Укажите путь вручную в настройках." % major}
	return await install(major)

## Скачивает и распаковывает Temurin JRE нужной мажорной версии.
func install(major: int) -> Dictionary:
	var os_name := "linux"
	match OS.get_name():
		"Windows": os_name = "windows"
		"macOS": os_name = "mac"
	var arch := "x64"
	if Engine.get_architecture_name().to_lower().contains("arm"):
		arch = "aarch64"
	var url := Constants.ADOPTIUM_LATEST % [major, os_name, arch]
	var target_dir := Store.java_dir().path_join("jre-%d" % major)
	var zip_path := Store.java_dir().path_join("jre-%d.zip" % major)

	progress.emit("Скачиваю Java %d..." % major, 0.0)
	Bus.download_progress.emit("Java %d" % major, 0.0)
	var r := await Net.download_file(url, zip_path, {}, 600.0, func(ratio):
		progress.emit("Скачиваю Java %d..." % major, ratio)
		Bus.download_progress.emit("Java %d" % major, ratio)
	)
	if not bool(r.get("ok", false)):
		return {"ok": false, "error": "Не удалось скачать Java %d: %s" % [major, String(r.get("error", ""))]}

	progress.emit("Распаковываю Java %d..." % major, 0.9)
	DirAccess.make_dir_recursive_absolute(target_dir)
	var zip := ZipArchive.new()
	if not zip.open(zip_path):
		return {"ok": false, "error": "Архив Java %d повреждён" % major}
	zip.extract_all(target_dir)
	zip.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(zip_path))

	var java_bin := _find_java_in(target_dir)
	if java_bin == "":
		return {"ok": false, "error": "В архиве Java %d не найден исполняемый файл" % major}
	detect()
	progress.emit("Java %d готова" % major, 1.0)
	return {"ok": true, "path": java_bin, "installed": true}

# ------------------------------------------------------------- внутреннее ----
func _probe(path: String) -> Dictionary:
	var res := Proc.run_capture(path, PackedStringArray(["-version"]))
	var text := String(res.get("out", ""))
	if text.strip_edges() == "":
		return {}
	var major := _parse_major(text)
	if major <= 0:
		return {}
	return {"path": path, "major": major, "vendor": _parse_vendor(text)}

func _parse_major(text: String) -> int:
	var re := RegEx.new()
	re.compile("version \"([0-9][0-9._]*)\"")
	var m := re.search(text)
	if m == null:
		return 0
	var raw := m.get_string(1)
	var parts := raw.split(".")
	var first := 0
	if parts.size() > 0:
		first = int(parts[0])
	if first == 1 and parts.size() > 1:
		return int(parts[1])
	return first

func _parse_vendor(text: String) -> String:
	var lower := text.to_lower()
	if lower.contains("temurin") or lower.contains("adoptium"):
		return "Eclipse Temurin"
	if lower.contains("corretto"):
		return "Amazon Corretto"
	if lower.contains("zulu"):
		return "Azul Zulu"
	if lower.contains("graal"):
		return "GraalVM"
	if lower.contains("openjdk"):
		return "OpenJDK"
	return "Java"

func _bundled_javas() -> Array:
	var out: Array = []
	var base := Store.java_dir()
	if not DirAccess.dir_exists_absolute(base):
		return out
	for dir in DirAccess.get_directories_at(base):
		var java_bin := _find_java_in(base.path_join(String(dir)))
		if java_bin != "":
			out.append(java_bin)
	return out

func _find_java_in(dir: String) -> String:
	var root := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(root):
		return ""
	var direct := root.path_join("bin").path_join(Proc.exec_name("java"))
	if FileAccess.file_exists(direct):
		return direct
	var stack: Array = [root]
	while stack.size() > 0:
		var current := String(stack.pop_back())
		var d := DirAccess.open(current)
		if d == null:
			continue
		for sub in d.get_directories():
			stack.push_back(current.path_join(String(sub)))
		for file in d.get_files():
			if String(file) == Proc.exec_name("java"):
				return current.path_join(String(file))
	return ""
