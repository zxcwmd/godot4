class_name NodeRuntime
extends RefCounted
## Запуск ботов автоматизации: пишет проект, ставит зависимости через npm,
## стартует бота отдельным процессом и умеет читать его состояние и лог.

const PACKAGE_JSON := """
{
  "name": "aurora-bot",
  "version": "1.0.0",
  "private": true,
  "description": "Сгенерировано Aurora Launcher",
  "dependencies": {
    "mineflayer": "^4.20.0",
    "mineflayer-pathfinder": "^2.4.5",
    "minecraft-data": "^3.78.0",
    "vec3": "^0.1.10"
  }
}
"""

const MARKER := "node_modules/.aurora-installed"
const EXIT_FILE := "exit.txt"
const INSTALL_CODE := "install_code.txt"

func node_path() -> String:
	return Proc.find_executable(Proc.exec_name("node"))

func available() -> bool:
	return node_path() != ""

func npm_path() -> String:
	return Proc.find_executable(Proc.exec_name("npm"))

func deps_ready(dir: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(dir.path_join(MARKER)))

func prepare(dir: String, script: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	_write(dir.path_join("bot.js"), script)
	_write(dir.path_join("package.json"), PACKAGE_JSON)

func install_result(dir: String) -> int:
	var abs := ProjectSettings.globalize_path(dir.path_join(INSTALL_CODE))
	if not FileAccess.file_exists(abs):
		return -1
	var fh := FileAccess.open(abs, FileAccess.READ)
	if fh == null:
		return -1
	var text := fh.get_as_text().strip_edges()
	fh.close()
	if text.is_valid_int():
		return int(text)
	return 1

## Запускает npm install в фоне, чтобы не подвешивать интерфейс.
func start_installer(dir: String) -> int:
	var abs := ProjectSettings.globalize_path(dir)
	var wrapper := ""
	if Proc.is_windows():
		wrapper = abs.path_join("install.bat")
		_write(wrapper, "@echo off\r\ncd /d \"%s\"\r\ncall npm install --omit=dev --no-audit --no-fund > install.log 2>&1\r\necho %ERRORLEVEL% > install_code.txt\r\nif %ERRORLEVEL%==0 (mkdir node_modules 2>nul & type nul > \"%s\")\r\n" % [abs, MARKER])
		return Proc.spawn("cmd.exe", PackedStringArray(["/c", wrapper]), abs)
	wrapper = abs.path_join("install.sh")
	var marker := abs.path_join(MARKER)
	_write(wrapper, "#!/bin/sh\ncd '%s'\nnpm install --omit=dev --no-audit --no-fund > install.log 2>&1\ncode=$?\necho $code > install_code.txt\nif [ $code -eq 0 ]; then mkdir -p node_modules && touch '%s'; fi\n" % [abs.replace("'", ""), marker])
	return Proc.spawn("/bin/sh", PackedStringArray([wrapper]), abs)

func start(dir: String) -> int:
	var abs := ProjectSettings.globalize_path(dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(EXIT_FILE)))
	var wrapper := ""
	if Proc.is_windows():
		wrapper = abs.path_join("run.bat")
		_write(wrapper, "@echo off\r\ncd /d \"%s\"\r\nnode bot.js > out.log 2>&1\r\necho %ERRORLEVEL% > exit.txt\r\n" % abs)
		return Proc.spawn("cmd.exe", PackedStringArray(["/c", wrapper]), abs)
	wrapper = abs.path_join("run.sh")
	_write(wrapper, "#!/bin/sh\ncd '%s'\nnode bot.js > out.log 2>&1\necho $? > exit.txt\n" % abs.replace("'", ""))
	return Proc.spawn("/bin/sh", PackedStringArray([wrapper]), abs)

func stop(pid: int) -> void:
	if pid > 0:
		Proc.kill(pid)

## Состояние бота из state.json: {"state": ..., "actions": ..., "note": ...}
func read_state(dir: String) -> Dictionary:
	var abs := ProjectSettings.globalize_path(dir.path_join("state.json"))
	if not FileAccess.file_exists(abs):
		return {}
	var fh := FileAccess.open(abs, FileAccess.READ)
	if fh == null:
		return {}
	var parsed = JSON.parse_string(fh.get_as_text())
	fh.close()
	if parsed == null:
		return {}
	return parsed

func exit_code(dir: String) -> int:
	var abs := ProjectSettings.globalize_path(dir.path_join(EXIT_FILE))
	if not FileAccess.file_exists(abs):
		return -1
	var fh := FileAccess.open(abs, FileAccess.READ)
	if fh == null:
		return -1
	var text := fh.get_as_text().strip_edges()
	fh.close()
	if text.is_valid_int():
		return int(text)
	return 0

## Дочитывает лог бота с сохранённой позиции. Возвращает {"offset": int, "lines": Array}
func read_log(dir: String, offset: int) -> Dictionary:
	var abs := ProjectSettings.globalize_path(dir.path_join("out.log"))
	var result := {"offset": offset, "lines": []}
	if not FileAccess.file_exists(abs):
		return result
	var fh := FileAccess.open(abs, FileAccess.READ)
	if fh == null:
		return result
	var length := fh.get_length()
	if length <= offset:
		fh.close()
		return result
	fh.seek(offset)
	var chunk := fh.get_buffer(length - offset)
	fh.close()
	result["offset"] = length
	if chunk.is_empty():
		return result
	var lines: Array = []
	for line in chunk.get_string_from_utf8().replace("\r\n", "\n").split("\n"):
		var text := String(line).strip_edges()
		if text != "":
			lines.append(text)
	result["lines"] = lines
	return result

func _write(path: String, text: String) -> void:
	var fh := FileAccess.open(path, FileAccess.WRITE)
	if fh == null:
		push_warning("Aurora: не удалось записать %s" % path)
		return
	fh.store_string(text)
	fh.close()
