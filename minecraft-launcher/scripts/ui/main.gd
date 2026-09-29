class_name Main
extends Node
## Точка сборки приложения: фон, обёртка окна, страницы и связь с ядром.

var _shell: Shell
var _bg: AuroraBackground
var _theme: Theme
var _pages := {}
var _game_state := "idle"

func _ready() -> void:
	var colors := Constants.accent_colors(String(Store.setting("accent", "aurora")))
	_theme = ThemeBuilder.build(colors["a"], colors["b"])

	_bg = AuroraBackground.new()
	_bg.intensity = float(Store.setting("bg_intensity", 1.0))
	_bg.accent = colors["a"]
	_bg.reduce_motion = bool(Store.setting("reduce_motion", false))
	add_child(_bg)

	var toasts := ToastLayer.new()
	add_child(toasts)

	_shell = Shell.new()
	_shell.theme = _theme
	add_child(_shell)

	_add_page("home", HomePage.new())
	_add_page("instances", InstancesPage.new())
	_add_page("automation", AutomationPage.new())
	_add_page("mods", ModsPage.new())
	_add_page("settings", SettingsPage.new())

	_connect()
	_shell.show_page("home")
	_shell.refresh_instances()
	_shell.refresh_account()
	_refresh_status()
	_refresh_node_status()
	_bootstrap()

func _add_page(id: String, page: LauncherPage) -> void:
	page.theme = _theme
	_pages[id] = page
	_shell.register_page(id, page)

func _connect() -> void:
	Bus.nav_requested.connect(func(page_id: String): _shell.show_page(page_id))
	Bus.instances_changed.connect(_on_instances_changed)
	Bus.current_instance_changed.connect(func(_id: String): _broadcast("on_instance_changed"))
	Bus.settings_changed.connect(_on_settings_changed)
	Bus.logged.connect(_on_logged)
	Bus.game_state_changed.connect(_on_game_state)
	Bus.task_state_changed.connect(_on_task_state)
	Bus.task_progress.connect(_on_task_progress)
	Bus.task_log.connect(_on_task_log)
	Bus.versions_changed.connect(func(): _broadcast("on_versions_ready"))
	Bus.java_changed.connect(_on_java_changed)
	Bus.download_progress.connect(_on_download_progress)
	Bus.accent_changed.connect(_on_accent_changed)

	Game.progress.connect(_on_launch_progress)
	Game.log_line.connect(_on_game_log)
	Game.state_changed.connect(func(state: String, pid: int): Bus.game_state_changed.emit(state, pid))
	Game.exited.connect(_on_game_exited)

func _bootstrap() -> void:
	Java.detect()
	Bus.java_ready.emit()
	await Mojang.load_manifest()
	Bus.versions_changed.emit()
	_refresh_status()

# ------------------------------------------------------------- broadcast -----
func _broadcast(method: String) -> void:
	for key in _pages.keys():
		var page: LauncherPage = _pages[key]
		if page.has_method(method):
			page.call(method)

func _on_instances_changed() -> void:
	_shell.refresh_instances()
	_broadcast("refresh")

func _on_logged(level: String, text: String) -> void:
	for key in _pages.keys():
		var page: LauncherPage = _pages[key]
		page.on_log(level, text)

func _on_game_log(level: String, text: String) -> void:
	_on_logged("game", text)

func _on_game_state(state: String, pid: int) -> void:
	_game_state = state
	for key in _pages.keys():
		var page: LauncherPage = _pages[key]
		page.on_game_state(state, pid)
	_refresh_status()

func _on_game_exited(code: int) -> void:
	Notify.push("Игра закрыта", "Код выхода: %d" % code, "info")

func _on_task_state(task_id: String, state: String) -> void:
	for key in _pages.keys():
		var page: LauncherPage = _pages[key]
		page.on_task_state(task_id, state)

func _on_task_progress(task_id: String, ratio: float) -> void:
	for key in _pages.keys():
		var page: LauncherPage = _pages[key]
		page.on_task_progress(task_id, ratio)

func _on_task_log(task_id: String, level: String, text: String) -> void:
	for key in _pages.keys():
		var page: LauncherPage = _pages[key]
		page.on_task_log(task_id, level, text)

func _on_java_changed() -> void:
	_refresh_status()

func _on_download_progress(label: String, ratio: float) -> void:
	_shell.set_status("%s — %d%%" % [label, int(ratio * 100.0)])
	for key in _pages.keys():
		var page: LauncherPage = _pages[key]
		page.on_download_progress(label, ratio)

func _on_launch_progress(label: String, ratio: float) -> void:
	_shell.set_status("%s — %d%%" % [label, int(ratio * 100.0)])

func _on_settings_changed() -> void:
	_bg.intensity = float(Store.setting("bg_intensity", 1.0))
	_bg.reduce_motion = bool(Store.setting("reduce_motion", false))
	_refresh_status()

func _on_accent_changed(a: Color, b: Color) -> void:
	_bg.accent = a
	_theme = ThemeBuilder.build(a, b)
	_shell.theme = _theme
	for key in _pages.keys():
		var page: LauncherPage = _pages[key]
		page.theme = _theme
	_shell.set_accent(a, b)

# ---------------------------------------------------------------- статус -----
func _refresh_status() -> void:
	var ram := int(Store.setting("ram_mb", 4096))
	var java_text := "Java: авто"
	var instance := Store.current_instance()
	if not instance.is_empty():
		var java_path := String(instance.get("java_path", ""))
		if java_path == "":
			java_path = String(Store.setting("java_path", ""))
		if java_path != "":
			var probed := Java.detected
			for info in probed:
				if String(info.get("path", "")) == java_path:
					java_text = "Java %d" % int(info.get("major", 0))
					break
	var state_text := ""
	match _game_state:
		"running": state_text = " · игра запущена"
		"preparing": state_text = " · подготовка..."
		"error": state_text = " · ошибка запуска"
	_shell.set_status("ОЗУ %d МБ · %s%s" % [ram, java_text, state_text])

func _refresh_node_status() -> void:
	var node := Proc.find_executable(Proc.exec_name("node"))
	if node != "":
		var res := Proc.run_capture(node, PackedStringArray(["--version"]))
		_shell.set_node_status("Node.js %s — боты готовы" % String(res.get("out", "")).strip_edges(), Constants.C_OK)
	else:
		_shell.set_node_status("Node.js не найден — установите Node.js 18+, иначе боты не запустятся", Constants.C_WARN)
