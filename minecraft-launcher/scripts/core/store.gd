class_name Store
extends Node
## Хранилище состояния: настройки, экземпляры, задачи автоматизации, аккаунт.

var settings := {
	"accent": "aurora",
	"ram_mb": 4096,
	"java_path": "",
	"auto_backup": true,
	"auto_update_mods": true,
	"auto_install_java": true,
	"auto_install_loader": true,
	"reduce_motion": false,
	"bg_intensity": 1.0,
	"console_autoscroll": true,
	"bot_host": "127.0.0.1",
	"bot_port": 25565,
	"bot_username": "AuroraBot",
	"bot_version": "",
	"max_concurrent_tasks": 2,
	"last_instance": "",
}

var instances: Array = []
var tasks: Array = []
var account := {"type": "offline", "name": "Player", "uuid": "", "token": "", "expires_at": 0}
var java_runtimes: Array = []
var selected_instance_id := ""

func _ready() -> void:
	_ensure_dirs()
	settings = _read_json(Constants.SETTINGS_FILE, settings)
	instances = _read_json(Constants.INSTANCES_FILE, [])
	tasks = _read_json(Constants.TASKS_FILE, [])
	account = _read_json(Constants.ACCOUNT_FILE, account)
	selected_instance_id = String(settings.get("last_instance", ""))
	if selected_instance_id != "" and current_instance().is_empty():
		selected_instance_id = ""
	if instances.size() > 0 and selected_instance_id == "":
		selected_instance_id = String(instances[0].get("id", ""))
	Bus.instances_changed.emit()
	Bus.settings_changed.emit()

# ------------------------------------------------------------------- пути ----
func data_dir() -> String:
	return ProjectSettings.globalize_path(Constants.DATA_DIR)

func instances_dir() -> String:
	return ProjectSettings.globalize_path(Constants.INSTANCES_DIR)

func runtime_dir() -> String:
	return ProjectSettings.globalize_path(Constants.RUNTIME_DIR)

func java_dir() -> String:
	return ProjectSettings.globalize_path(Constants.JAVA_DIR)

func automation_dir() -> String:
	return ProjectSettings.globalize_path(Constants.AUTOMATION_DIR)

func log_dir() -> String:
	return ProjectSettings.globalize_path(Constants.LOG_DIR)

func instance_dir(instance_id: String) -> String:
	return instances_dir().path_join(instance_id)

func task_dir(task_id: String) -> String:
	return automation_dir().path_join(task_id)

func _ensure_dirs() -> void:
	for p in [data_dir(), instances_dir(), runtime_dir(), java_dir(), automation_dir(), log_dir()]:
		DirAccess.make_dir_recursive_absolute(p)

# --------------------------------------------------------------- настройки --
func set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()
	Bus.settings_changed.emit()

func setting(key: String, default = null):
	if settings.has(key):
		return settings[key]
	return default

func save_settings() -> void:
	_write_json(Constants.SETTINGS_FILE, settings)

func system_ram_mb() -> int:
	var info := OS.get_memory_info()
	if info.has("total"):
		return int(float(info["total"]) / (1024.0 * 1024.0))
	return 8192

func recommended_ram_mb() -> int:
	return clampi(int(system_ram_mb() * 0.35), 2048, 16384)

# ------------------------------------------------------------- экземпляры ---
func current_instance() -> Dictionary:
	for inst in instances:
		if String(inst.get("id", "")) == selected_instance_id:
			return inst
	return {}

func instance_by_id(id: String) -> Dictionary:
	for inst in instances:
		if String(inst.get("id", "")) == id:
			return inst
	return {}

func upsert_instance(instance: Dictionary) -> void:
	var id := String(instance.get("id", ""))
	for i in range(instances.size()):
		if String(instances[i].get("id", "")) == id:
			instances[i] = instance
			save_instances()
			Bus.instances_changed.emit()
			return
	instances.append(instance)
	save_instances()
	Bus.instances_changed.emit()

func remove_instance(id: String) -> void:
	for i in range(instances.size()):
		if String(instances[i].get("id", "")) == id:
			instances.remove_at(i)
			break
	if selected_instance_id == id:
		selected_instance_id = ""
		if instances.size() > 0:
			selected_instance_id = String(instances[0].get("id", ""))
	save_instances()
	Bus.instances_changed.emit()

func select_instance(id: String) -> void:
	selected_instance_id = id
	settings["last_instance"] = id
	save_settings()
	Bus.current_instance_changed.emit(id)
	Bus.settings_changed.emit()

func save_instances() -> void:
	_write_json(Constants.INSTANCES_FILE, instances)

# ------------------------------------------------------- задачи автоматизации -
func save_tasks() -> void:
	_write_json(Constants.TASKS_FILE, tasks)

# ------------------------------------------------------------------ аккаунт --
func save_account() -> void:
	_write_json(Constants.ACCOUNT_FILE, account)

# ------------------------------------------------------------------- JSON ---
func _read_json(path: String, fallback):
	var abs := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs):
		return fallback
	var f := FileAccess.open(abs, FileAccess.READ)
	if f == null:
		return fallback
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		return fallback
	return parsed

func _write_json(path: String, data) -> void:
	var abs := ProjectSettings.globalize_path(path)
	var dir := abs.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(abs, FileAccess.WRITE)
	if f == null:
		push_warning("Aurora: не удалось записать %s" % abs)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

## Публичные обёртки для сервисов.
func read_json(path: String, fallback):
	return _read_json(path, fallback)

func write_json(path: String, data) -> void:
	_write_json(path, data)
