class_name Proc
extends RefCounted
## Работа с внешними процессами: поиск исполняемых файлов, запуск, завершение.
## Использует OS.create_process(), если он доступен (Godot 4.3+), иначе
## аккуратно выходит из положения через OS.execute().

static func is_windows() -> bool:
	return OS.get_name() == "Windows"

static func path_separator() -> String:
	return ";" if is_windows() else ":"

## Ищет исполняемый файл в PATH и в типичных местах установки.
static func find_executable(name: String) -> String:
	if is_windows():
		if not name.ends_with(".exe"):
			name += ".exe"
	var candidates: Array = []
	var dirs := OS.get_environment("PATH").split(path_separator())
	for d in dirs:
		if String(d) != "":
			candidates.append(String(d).path_join(name))
	candidates.append_array(_extra_search_dirs(name))
	for c in candidates:
		if FileAccess.file_exists(String(c)):
			return String(c)
	return ""

static func _extra_search_dirs(name: String) -> Array:
	var out: Array = []
	var home := ""
	if is_windows():
		home = OS.get_environment("USERPROFILE")
	else:
		home = OS.get_environment("HOME")
	if home == "":
		home = "/root"
	if is_windows():
		out.append("C:\\Program Files\\nodejs\\" + name)
		out.append("C:\\Program Files\\Eclipse Adoptium\\" + name)
		out.append("C:\\Program Files\\Java\\" + name)
	else:
		out.append("/usr/bin/" + name)
		out.append("/usr/local/bin/" + name)
		out.append("/opt/homebrew/bin/" + name)
		out.append("/snap/bin/" + name)
		out.append(home + "/.local/bin/" + name)
		out.append(home + "/.sdkman/candidates/java/current/bin/" + name)
	return out

## Выполняет команду и возвращает {"code": int, "out": String}.
static func run_capture(cmd: String, args: PackedStringArray, workdir := "") -> Dictionary:
	var output: Array = []
	var code := OS.execute(cmd, args, output, true)
	return {"code": int(code), "out": "\n".join(output)}

## Неблокирующий запуск. Возвращает PID или -1, если платформа не умеет.
static func spawn(cmd: String, args: PackedStringArray, workdir := "") -> int:
	if OS.has_method("create_process"):
		var pid = OS.create_process(cmd, args, false)
		return int(pid)
	return -1

static func alive(pid: int) -> bool:
	if pid <= 0:
		return false
	if OS.has_method("is_process_running"):
		return bool(OS.is_process_running(pid))
	if not is_windows():
		return DirAccess.dir_exists_absolute("/proc/%d" % pid)
	return true

static func kill(pid: int) -> void:
	if pid <= 0:
		return
	if OS.has_method("kill"):
		OS.kill(pid)

static func open_in_file_manager(path: String) -> void:
	if is_windows():
		OS.execute("explorer.exe", PackedStringArray([path]), [], false)
	elif OS.get_name() == "macOS":
		OS.execute("open", PackedStringArray([path]), [], false)
	else:
		OS.execute("xdg-open", PackedStringArray([path]), [], false)

static func exec_name(base: String) -> String:
	return base + ".exe" if is_windows() else base
