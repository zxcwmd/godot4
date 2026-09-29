class_name AutomationService
extends Node
## Пульт автоматизации: хранит задачи, запускает и останавливает ботов,
## следит за расписанием, читает состояние и логи, рассылает события в UI.

const POLL_INTERVAL := 1.0

var tasks: Array = []
var states := {}          # id -> {"state","pid","dir","started","actions","note","error","log_offset"}
var _node: NodeRuntime
var _timer: Timer

func _ready() -> void:
	_node = NodeRuntime.new()
	load()
	_timer = Timer.new()
	_timer.wait_time = POLL_INTERVAL
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

# ------------------------------------------------------------------ CRUD -----
func load() -> void:
	var raw = Store.read_json(Constants.TASKS_FILE, [])
	tasks = raw if raw is Array else []

func save() -> void:
	Store.write_json(Constants.TASKS_FILE, tasks)

func all() -> Array:
	return tasks

func get(id: String) -> Dictionary:
	for task in tasks:
		if String(task.get("id", "")) == id:
			return task
	return {}

func new_task(kind: String) -> Dictionary:
	var defaults := AutomationSchema.defaults(kind)
	return {
		"id": _new_id(),
		"name": Constants.kind_title(kind),
		"kind": kind,
		"trigger": "manual",
		"interval_minutes": 30,
		"enabled": true,
		"instance_id": "",
		"params": defaults,
		"runs": 0,
		"actions": 0,
		"last_run": 0,
		"last_status": "",
	}

func add(task: Dictionary) -> void:
	tasks.append(task)
	save()
	Bus.task_state_changed.emit(String(task.get("id", "")), "added")

func update(task: Dictionary) -> void:
	var id := String(task.get("id", ""))
	for i in range(tasks.size()):
		if String(tasks[i].get("id", "")) == id:
			tasks[i] = task
			save()
			Bus.task_state_changed.emit(id, "updated")
			return

func remove(id: String) -> void:
	for i in range(tasks.size()):
		if String(tasks[i].get("id", "")) == id:
			tasks.remove_at(i)
			break
	states.erase(id)
	save()
	var dir := Store.task_dir(id)
	if DirAccess.dir_exists_absolute(dir):
		OS.move_to_trash(ProjectSettings.globalize_path(dir))
	Bus.task_state_changed.emit(id, "removed")

func set_enabled(id: String, value: bool) -> void:
	var task := get(id)
	if task.is_empty():
		return
	task["enabled"] = value
	update(task)

# ---------------------------------------------------------------- запуск -----
## Запускает задачу. Возвращает {"ok": bool, "error": String, "pending": bool}
func run_now(id: String) -> Dictionary:
	var task := get(id)
	if task.is_empty():
		return {"ok": false, "error": "Задача не найдена"}
	var current := String(states.get(id, {}).get("state", ""))
	if current in ["running", "starting", "installing"]:
		return {"ok": false, "error": "Задача уже выполняется"}
	if running_count() >= int(Store.setting("max_concurrent_tasks", 2)):
		return {"ok": false, "error": "Достигнут лимит одновременных задач (%d)" % int(Store.setting("max_concurrent_tasks", 2))}
	if not _node.available():
		return {"ok": false, "error": "Node.js не найден. Боты работают на Node.js 18+."}

	var kind := String(task.get("kind", "mine"))
	var dir := Store.task_dir(id)
	_node.prepare(dir, BotTemplates.render(kind, _config_for(task)))

	task["runs"] = int(task.get("runs", 0)) + 1
	task["last_run"] = Time.get_unix_time_from_system()
	task["last_status"] = "starting"
	update(task)

	if _node.deps_ready(dir):
		return _spawn_bot(id, dir, task)

	states[id] = {"state": "installing", "pid": -1, "dir": dir, "started": Time.get_unix_time_from_system(), "actions": 0, "note": "npm install", "log_offset": 0}
	_node.start_installer(dir)
	Bus.task_state_changed.emit(id, "installing")
	Bus.notified.emit("Готовлю бота", "Устанавливаю зависимости Node.js для «%s»" % String(task.get("name", "")), "info")
	return {"ok": true, "pending": true}

func stop(id: String) -> void:
	var st: Dictionary = states.get(id, {})
	var pid := int(st.get("pid", -1))
	var dir := String(st.get("dir", Store.task_dir(id)))
	if pid > 0:
		_node.stop(pid)
	if states.has(id):
		states[id]["state"] = "stopped"
	Bus.task_state_changed.emit(id, "stopped")
	var task := get(id)
	if not task.is_empty():
		task["last_status"] = "stopped"
		update(task)
	Bus.notified.emit("Бот остановлен", String(task.get("name", id)), "warn")

func stop_all() -> void:
	for id in states.keys():
		if String(states[id].get("state", "")) == "running":
			stop(String(id))

## Запускает задачи, привязанные к запуску игры (или все, если привязки нет).
func run_for_instance(instance_id: String) -> void:
	for task in tasks:
		if not bool(task.get("enabled", true)):
			continue
		if String(task.get("trigger", "")) != "on_launch":
			continue
		var bind := String(task.get("instance_id", ""))
		if bind != "" and bind != instance_id:
			continue
		run_now(String(task.get("id", "")))

func running_count() -> int:
	var n := 0
	for id in states.keys():
		if String(states[id].get("state", "")) in ["running", "starting", "installing"]:
			n += 1
	return n

func state_of(id: String) -> String:
	return String(states.get(id, {}).get("state", "idle"))

func total_actions() -> int:
	var total := 0
	for task in tasks:
		total += int(task.get("actions", 0))
	for id in states.keys():
		total += int(states[id].get("actions", 0))
	return total

# -------------------------------------------------------------- внутреннее ---
func _spawn_bot(id: String, dir: String, task: Dictionary) -> Dictionary:
	var pid := _node.start(dir)
	if pid <= 0:
		var err := "Не удалось запустить бота (OS.create_process недоступен)"
		states[id] = {"state": "error", "pid": -1, "dir": dir, "started": Time.get_unix_time_from_system(), "actions": 0, "note": err, "log_offset": 0}
		Bus.task_state_changed.emit(id, "error")
		return {"ok": false, "error": err}
	states[id] = {"state": "running", "pid": pid, "dir": dir, "started": Time.get_unix_time_from_system(), "actions": 0, "note": "", "log_offset": 0}
	task["last_status"] = "running"
	update(task)
	Bus.task_state_changed.emit(id, "running")
	Bus.notified.emit("Бот запущен", "%s → %s:%d" % [String(task.get("name", "")), String(_config_for(task).get("host", "")), int(_config_for(task).get("port", 0))], "ok")
	return {"ok": true, "pid": pid}

func _config_for(task: Dictionary) -> Dictionary:
	var kind := String(task.get("kind", "mine"))
	var cfg: Dictionary = AutomationSchema.defaults(kind).duplicate()
	var params: Dictionary = task.get("params", {})
	for key in params.keys():
		cfg[key] = params[key]
	cfg["mode"] = kind
	cfg["host"] = String(params.get("host", Store.setting("bot_host", "127.0.0.1")))
	cfg["port"] = int(params.get("port", Store.setting("bot_port", 25565)))
	cfg["username"] = String(params.get("username", Store.setting("bot_username", "AuroraBot")))
	cfg["version"] = String(params.get("version", ""))
	cfg["foods"] = params.get("foods", ["bread", "cooked_beef"])
	var duration := int(cfg.get("duration_minutes", 60))
	cfg["duration_minutes"] = duration if duration > 0 else 720
	return cfg

func _on_tick() -> void:
	_check_schedule()
	for id in states.keys():
		var key := String(id)
		var st: Dictionary = states[key]
		var state := String(st.get("state", ""))
		if state == "installing":
			_check_install(key, st)
			continue
		if state != "running":
			continue
		_poll_task(key, st)

func _check_install(id: String, st: Dictionary) -> void:
	var dir := String(st.get("dir", ""))
	var code := _node.install_result(dir)
	if code < 0:
		return
	if code != 0:
		states[id]["state"] = "error"
		states[id]["error"] = "npm install завершился с кодом %d (см. install.log)" % code
		Bus.task_state_changed.emit(id, "error")
		Bus.notified.emit("Не удалось установить зависимости", "Код %d — проверьте install.log в каталоге задачи" % code, "error")
		var task := get(id)
		if not task.is_empty():
			task["last_status"] = "error"
			update(task)
		return
	var task := get(id)
	if task.is_empty():
		return
	states.erase(id)
	_spawn_bot(id, dir, task)

func _poll_task(id: String, st: Dictionary) -> void:
	var dir := String(st.get("dir", ""))
	var bstate := _node.read_state(dir)
	if not bstate.is_empty():
		var bot_state := String(bstate.get("state", ""))
		var actions := int(bstate.get("actions", 0))
		var note := String(bstate.get("note", ""))
		var prev := int(states[id].get("actions", 0))
		if actions > prev:
			states[id]["actions"] = actions
			var task0 := get(id)
			if not task0.is_empty():
				task0["actions"] = int(task0.get("actions", 0)) + (actions - prev)
				update(task0)
		states[id]["note"] = note
		var params: Dictionary = get(id).get("params", {})
		var duration_cfg := int(params.get("duration_minutes", 60))
		var elapsed := maxi(0, Time.get_unix_time_from_system() - int(st.get("started", 0)))
		if duration_cfg > 0:
			Bus.task_progress.emit(id, clampf(float(elapsed) / float(duration_cfg * 60), 0.0, 1.0))
		if bot_state in ["error", "kicked", "dead", "ended"]:
			states[id]["state"] = "error"
			states[id]["error"] = String(bstate.get("error", bstate.get("reason", bot_state)))
			_finish_task(id, "error")
			return
		if bot_state == "done":
			_finish_task(id, "done")
			return

	var log_result := _node.read_log(dir, int(st.get("log_offset", 0)))
	states[id]["log_offset"] = int(log_result.get("offset", 0))
	for line in log_result.get("lines", []):
		Bus.task_log.emit(id, "info", String(line))

	var pid := int(st.get("pid", -1))
	var code := _node.exit_code(dir)
	if code >= 0 or (pid > 0 and not Proc.alive(pid)):
		_finish_task(id, "done" if code == 0 else "error")

func _finish_task(id: String, final_state: String) -> void:
	if not states.has(id):
		return
	var st: Dictionary = states[id]
	var started := int(st.get("started", 0))
	var duration := maxi(0, Time.get_unix_time_from_system() - started)
	var actions := int(st.get("actions", 0))
	var error := String(st.get("error", ""))
	states.erase(id)
	var task := get(id)
	if not task.is_empty():
		task["last_status"] = final_state
		task["last_run"] = Time.get_unix_time_from_system()
		update(task)
	Bus.task_state_changed.emit(id, final_state)
	var task_name := id
	var task := get(id)
	if not task.is_empty():
		task_name = String(task.get("name", id))
	if final_state == "done":
		Bus.notified.emit("Бот завершил работу", "%s · %d действий за %s" % [task_name, actions, Constants.format_duration(duration)], "ok")
	else:
		var suffix := (" · " + error) if error != "" else ""
		Bus.notified.emit("Бот завершился с ошибкой", task_name + suffix, "error")

func _check_schedule() -> void:
	var now := Time.get_unix_time_from_system()
	for task in tasks:
		if not bool(task.get("enabled", true)):
			continue
		if String(task.get("trigger", "")) != "interval":
			continue
		var last := int(task.get("last_run", 0))
		var every := maxi(60, int(task.get("interval_minutes", 30)) * 60)
		if now - last >= every:
			run_now(String(task.get("id", "")))

func _new_id() -> String:
	return "%d-%s" % [Time.get_unix_time_from_system(), str(randi() % 100000)]
