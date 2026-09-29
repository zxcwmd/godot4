class_name HomePage
extends LauncherPage
## Главная: герой-карточка сборки, живая статистика, автоматизация и новости.

var _cover: CoverArt
var _title: Label
var _subtitle: Label
var _chip_version: Chip
var _chip_loader: Chip
var _chip_mods: Chip
var _chip_java: Chip
var _play_button: AccentButton
var _bots_button: AccentButton
var _folder_button: AccentButton
var _ring: ProgressRing
var _launch_label: Label
var _launch_bar: ProgressBar
var _tasks_box: VBoxContainer
var _tasks_chip: Chip
var _mini_console: ConsoleView
var _stat_ram: Label
var _stat_java: Label
var _stat_mods: Label
var _stat_bots: Label
var _versions_box: VBoxContainer

const CHANGELOG := [
	"Новый пульт автоматизации: 8 видов ботов",
	"Мгновенная установка Fabric, Quilt, Forge и NeoForge",
	"Каталог модов Modrinth с проверкой обновлений",
	"Автоустановка Java и авто-бэкап миров перед запуском",
]

func _ready() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	content.add_child(_build_hero())
	content.add_child(_build_stats())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 18)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_build_automation_panel())
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 18)
	right.custom_minimum_size = Vector2(360, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_build_versions_panel())
	right.add_child(_build_changelog_panel())
	columns.add_child(left)
	columns.add_child(right)
	content.add_child(columns)
	add_child(Kit.scroll(Kit.margin(content, 24, 26, 24, 26)))
	refresh()

# ------------------------------------------------------------------ герой ----
func _build_hero() -> Control:
	var panel := Kit.glass(26)
	var margin := MarginContainer.new()
	for pair in [["margin_top", 22], ["margin_right", 24], ["margin_bottom", 22], ["margin_left", 24]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	_cover = CoverArt.new()
	_cover.custom_minimum_size = Vector2(290, 168)
	_cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cover.set_caption("AURORA")
	row.add_child(_cover)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_PASS

	_title = Kit.label("Экземпляр не выбран", 27, Color(1, 1, 1))
	info.add_child(_title)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_version = _make_chip("1.20.1")
	_chip_loader = _make_chip("Vanilla")
	_chip_mods = _make_chip("0 модов")
	_chip_java = _make_chip("Java 17")
	chips.add_child(_chip_version)
	chips.add_child(_chip_loader)
	chips.add_child(_chip_mods)
	chips.add_child(_chip_java)
	info.add_child(chips)

	_subtitle = Kit.muted("Создайте экземпляр на странице «Экземпляры», чтобы начать играть.", 13)
	info.add_child(_subtitle)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	_play_button = AccentButton.make("Играть", "accent", "play")
	_play_button.custom_minimum_size = Vector2(180, 52)
	_play_button.pressed.connect(_on_play)
	buttons.add_child(_play_button)
	_bots_button = AccentButton.make("С ботами", "ghost", "robot")
	_bots_button.custom_minimum_size = Vector2(160, 52)
	_bots_button.pressed.connect(_on_play_with_bots)
	buttons.add_child(_bots_button)
	_folder_button = AccentButton.make("Папка", "ghost", "folder")
	_folder_button.custom_minimum_size = Vector2(120, 52)
	_folder_button.pressed.connect(_on_open_folder)
	buttons.add_child(_folder_button)
	info.add_child(buttons)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 14)
	progress_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring = ProgressRing.new()
	_ring.custom_minimum_size = Vector2(58, 58)
	_ring.thickness = 6.0
	progress_row.add_child(_ring)
	var progress_texts := VBoxContainer.new()
	progress_texts.add_theme_constant_override("separation", 4)
	progress_texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_launch_label = Kit.label("Готов к запуску", 13, Constants.C_TEXT)
	progress_texts.add_child(_launch_label)
	_launch_bar = ProgressBar.new()
	_launch_bar.custom_minimum_size = Vector2(0, 8)
	_launch_bar.max_value = 100.0
	_launch_bar.show_percentage = false
	_launch_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_texts.add_child(_launch_bar)
	progress_row.add_child(progress_texts)
	info.add_child(progress_row)

	row.add_child(info)
	margin.add_child(row)
	panel.add_child(margin)
	return panel

func _make_chip(text: String) -> Chip:
	var chip := Chip.new()
	chip.text = text
	return chip

func _build_stats() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_stat_ram = _tile(row, "Оперативная память", "4096 МБ", "выделено лаунчером")
	_stat_java = _tile(row, "Java", "—", "среда выполнения")
	_stat_mods = _tile(row, "Моды", "0", "в текущей сборке")
	_stat_bots = _tile(row, "Боты", "0 активны", "автоматизация")
	return row

func _tile(row: HBoxContainer, caption: String, value: String, hint: String) -> Label:
	var tile := Kit.stat_tile(caption, value, hint)
	row.add_child(tile)
	var value_label: Label = null
	var stack := tile.get_child(0)
	if stack is ShaderSurface:
		var margin_node: MarginContainer = stack.get_child(0)
		var box: VBoxContainer = margin_node.get_child(0)
		value_label = box.get_child(1)
	return value_label

func _build_automation_panel() -> Control:
	var panel := Kit.glass(22)
	var margin := MarginContainer.new()
	for pair in [["margin_top", 18], ["margin_right", 18], ["margin_bottom", 18], ["margin_left", 18]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_PASS

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(Kit.section("Автоматизация"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	_tasks_chip = Chip.new()
	_tasks_chip.text = "0 задач"
	header.add_child(_tasks_chip)
	var open_button := AccentButton.make("Пульт", "ghost", "robot")
	open_button.custom_minimum_size = Vector2(120, 34)
	open_button.corner = 11.0
	open_button.pressed.connect(func(): Bus.nav_requested.emit("automation"))
	header.add_child(open_button)
	box.add_child(header)

	_tasks_box = VBoxContainer.new()
	_tasks_box.add_theme_constant_override("separation", 8)
	_tasks_box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_tasks_box)

	_mini_console = ConsoleView.new()
	_mini_console.custom_minimum_size = Vector2(0, 132)
	_mini_console.autoscroll = true
	_mini_console.font_size = 11.0
	box.add_child(_mini_console)

	margin.add_child(box)
	panel.add_child(margin)
	return panel

func _build_versions_panel() -> Control:
	var panel := Kit.glass(22)
	var margin := MarginContainer.new()
	for pair in [["margin_top", 18], ["margin_right", 18], ["margin_bottom", 18], ["margin_left", 18]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(Kit.section("Версии Minecraft"))
	_versions_box = VBoxContainer.new()
	_versions_box.add_theme_constant_override("separation", 8)
	_versions_box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_versions_box)
	margin.add_child(box)
	panel.add_child(margin)
	return panel

func _build_changelog_panel() -> Control:
	var panel := Kit.glass(22)
	var margin := MarginContainer.new()
	for pair in [["margin_top", 18], ["margin_right", 18], ["margin_bottom", 18], ["margin_left", 18]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(Kit.section("Что нового в Aurora"))
	for line in CHANGELOG:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glyph := IconGlyph.new()
		glyph.icon = "check"
		glyph.glyph_color = Constants.C_OK
		glyph.custom_minimum_size = Vector2(15, 15)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
		row.add_child(Kit.muted(line, 12))
		box.add_child(row)
	margin.add_child(box)
	panel.add_child(margin)
	return panel

# ---------------------------------------------------------------- данные -----
func refresh() -> void:
	var instance := Store.current_instance()
	if instance.is_empty():
		_title.text = "Экземпляр не выбран"
		_subtitle.text = "Создайте экземпляр на странице «Экземпляры», чтобы начать играть."
		_cover.set_caption("AURORA")
		_cover.seed_text = "aurora"
		_chip_version.text = "—"
		_chip_loader.text = "—"
		_chip_mods.text = "0 модов"
		_chip_java.text = "Java —"
		_play_button.disabled = true
		_bots_button.disabled = true
	else:
		var name := String(instance.get("name", "Экземпляр"))
		_title.text = name
		_cover.seed_text = name
		_cover.set_caption(name.to_upper())
		_cover.set_icon(_icon_for(instance))
		var loader := String(instance.get("loader", "vanilla"))
		_chip_version.text = "MC " + String(instance.get("version", "?"))
		_chip_loader.text = Constants.loader_title(loader)
		var mods: Array = instance.get("mods", [])
		_chip_mods.text = "%d модов" % mods.size()
		_chip_java.text = "Java %d" % int(instance.get("java_major", 17))
		var last_played := int(instance.get("last_played", 0))
		if last_played > 0:
			var when := Time.get_datetime_string_from_unix_time(last_played)
			_subtitle.text = "Последний запуск: %s" % when
		else:
			_subtitle.text = "Готов к запуску · %s" % Constants.loader_title(loader)
		_play_button.disabled = Game.running
		_bots_button.disabled = Game.running

	_stat_ram.text = "%d МБ" % int(Store.setting("ram_mb", 4096))
	_stat_java.text = _java_summary()
	var mods_count := 0
	if not instance.is_empty():
		mods_count = int((instance.get("mods", []) as Array).size())
	_stat_mods.text = str(mods_count)
	_stat_bots.text = "%d активны" % Bots.running_count()
	_refresh_tasks()
	_refresh_versions()

func _icon_for(instance: Dictionary) -> String:
	match String(instance.get("loader", "vanilla")):
		"fabric", "quilt", "forge", "neoforge": return "box"
	return "layers"

func _java_summary() -> String:
	if Java.detected.is_empty():
		Java.detect()
	var best := 0
	for info in Java.detected:
		best = maxi(best, int(info.get("major", 0)))
	if best == 0:
		return "не найдена"
	return "%d доступна" % best

func _refresh_tasks() -> void:
	for child in _tasks_box.get_children():
		child.queue_free()
	var enabled: Array = []
	for task in Bots.all():
		if bool(task.get("enabled", true)):
			enabled.append(task)
	_tasks_chip.text = "%d задач · %d активны" % [enabled.size(), Bots.running_count()]
	if enabled.is_empty():
		var hint := Kit.muted("Пока нет включённых задач. Откройте пульт автоматизации и добавьте, например, автошахту или автоварку зелий.", 12)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tasks_box.add_child(hint)
		return
	for task in enabled:
		_tasks_box.add_child(_task_row(task))

func _task_row(task: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 44)
	var card := Kit.card(14)
	var inner := MarginContainer.new()
	for pair in [["margin_top", 8], ["margin_right", 12], ["margin_bottom", 8], ["margin_left", 12]]:
		inner.add_theme_constant_override(pair[0], pair[1])
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := IconGlyph.new()
	glyph.icon = AutomationSchema.kind_icon(String(task.get("kind", "mine")))
	glyph.glyph_color = Constants.C_INFO
	glyph.custom_minimum_size = Vector2(18, 18)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(glyph)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(Kit.label(String(task.get("name", "")), 13, Color(1, 1, 1)))
	texts.add_child(Kit.label("%s · %s" % [Constants.kind_title(String(task.get("kind", ""))), Constants.trigger_title(String(task.get("trigger", "")))], 11, Constants.C_TEXT_DIM))
	line.add_child(texts)
	var chip := Chip.new()
	chip.text = _state_title(String(task.get("id", "")))
	chip.chip_color = _state_color(String(task.get("id", "")))
	line.add_child(chip)
	inner.add_child(line)
	card.add_child(inner)
	row.add_child(card)
	var run_button := AccentButton.make("Пуск", "ghost", "play")
	run_button.custom_minimum_size = Vector2(96, 40)
	run_button.corner = 12.0
	run_button.pressed.connect(func(): _run_task(String(task.get("id", ""))))
	row.add_child(run_button)
	return row

func _state_title(id: String) -> String:
	return Bots.state_of(id)

func _state_color(id: String) -> Color:
	match Bots.state_of(id):
		"running", "starting": return Constants.C_OK
		"installing": return Constants.C_WARN
		"error": return Constants.C_ERR
		"done", "stopped": return Constants.C_INFO
	return Constants.C_TEXT_DIM

func _run_task(id: String) -> void:
	var result := Bots.run_now(id)
	if not bool(result.get("ok", false)):
		Notify.push("Не удалось запустить", String(result.get("error", "")), "error")
	else:
		Notify.push("Бот запущен", "Задача выполнется в фоне", "ok")

func _refresh_versions() -> void:
	for child in _versions_box.get_children():
		child.queue_free()
	var latest: Dictionary = Mojang.manifest.get("latest", {})
	if latest.is_empty():
		var hint := Kit.muted("Загружаю манифест версий...", 12)
		_versions_box.add_child(hint)
		return
	var entries: Array = []
	for kind in ["release", "snapshot"]:
		var item: Dictionary = latest.get(kind, {})
		if not item.is_empty():
			entries.append({"id": String(item.get("id", "")), "kind": kind})
	var count := 0
	for v in Mojang.manifest.get("versions", []):
		if count >= 4:
			break
		var version: Dictionary = v
		entries.append({"id": String(version.get("id", "")), "kind": String(version.get("type", ""))})
		count += 1
	for entry in entries:
		_versions_box.add_child(_version_row(entry))

func _version_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 40)
	var card := Kit.card(12)
	var inner := MarginContainer.new()
	for pair in [["margin_top", 6], ["margin_right", 10], ["margin_bottom", 6], ["margin_left", 10]]:
		inner.add_theme_constant_override(pair[0], pair[1])
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := IconGlyph.new()
	glyph.icon = "layers"
	glyph.glyph_color = Constants.C_TEXT_MUTED
	glyph.custom_minimum_size = Vector2(16, 16)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(glyph)
	line.add_child(Kit.label(String(entry.get("id", "")), 13, Color(1, 1, 1)))
	var chip := Chip.new()
	chip.text = _kind_title(String(entry.get("kind", "")))
	line.add_child(chip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(spacer)
	var button := AccentButton.make("Создать", "ghost", "plus")
	button.custom_minimum_size = Vector2(104, 32)
	button.corner = 10.0
	var version_id := String(entry.get("id", ""))
	button.pressed.connect(func(): _create_with_version(version_id))
	line.add_child(button)
	inner.add_child(line)
	card.add_child(inner)
	row.add_child(card)
	return row

func _kind_title(kind: String) -> String:
	match kind:
		"release": return "релиз"
		"snapshot": return "снапшот"
		"old_beta": return "бета"
		"old_alpha": return "альфа"
	return kind

func _create_with_version(version_id: String) -> void:
	Bus.nav_requested.emit("instances")
	Bus.version_preset.emit(version_id) else null

# ----------------------------------------------------------------- события ---
func on_log(level: String, text: String) -> void:
	if _mini_console == null:
		return
	_mini_console.add_line(text, level)

func on_game_state(state: String, pid: int) -> void:
	if _ring == null:
		return
	match state:
		"preparing":
			_launch_label.text = "Готовлю запуск..."
			_ring.value = 0.02
			_play_button.set_label("Подготовка")
			_play_button.disabled = true
		"running":
			_launch_label.text = "Игра запущена · PID %d" % pid
			_ring.value = 1.0
			_launch_bar.value = 100.0
			_play_button.set_label("Остановить")
			_play_button.disabled = false
			_play_button.variant = "danger"
			_play_button.refresh_style()
		"error":
			_launch_label.text = "Ошибка запуска — подробности в консоли"
			_ring.value = 0.0
			_play_button.set_label("Играть")
			_play_button.disabled = false
			_play_button.variant = "accent"
			_play_button.refresh_style()
		"stopped":
			_launch_label.text = "Игра остановлена"
			_ring.value = 0.0
			_play_button.set_label("Играть")
			_play_button.disabled = false
			_play_button.variant = "accent"
			_play_button.refresh_style()
	refresh()

func on_download_progress(label: String, ratio: float) -> void:
	if _launch_bar == null:
		return
	_launch_bar.value = ratio * 100.0
	_ring.value = maxf(_ring.value, ratio)
	_launch_label.text = "%s — %d%%" % [label, int(ratio * 100.0)]

func on_task_state(task_id: String, state: String) -> void:
	refresh()

func _on_play() -> void:
	var instance := Store.current_instance()
	if instance.is_empty():
		Notify.push("Нет экземпляра", "Создайте сборку на странице «Экземпляры»", "warn")
		Bus.nav_requested.emit("instances")
		return
	if Game.running:
		Game.stop()
		return
	_start(instance, false)

func _on_play_with_bots() -> void:
	var instance := Store.current_instance()
	if instance.is_empty():
		Notify.push("Нет экземпляра", "Создайте сборку на странице «Экземпляры»", "warn")
		Bus.nav_requested.emit("instances")
		return
	if Game.running:
		Game.stop()
		return
	_start(instance, true)

func _start(instance: Dictionary, with_bots: bool) -> void:
	if bool(Store.setting("auto_backup", true)):
		_backup_saves(instance)
	Notify.push("Запускаю " + String(instance.get("name", "")), "Готовлю файлы и Java", "info")
	var pid := await Game.launch(instance)
	if pid > 0 and with_bots:
		Bots.run_for_instance(String(instance.get("id", "")))

func _backup_saves(instance: Dictionary) -> void:
	var saves := Store.instance_dir(String(instance.get("id", ""))).path_join("saves")
	if not DirAccess.dir_exists_absolute(saves):
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var target := Store.data_dir().path_join("backups").path_join("%s-%s" % [String(instance.get("id", "")), stamp])
	var result := _copy_dir(saves, target)
	if bool(result):
		Notify.push("Бэкап создан", "Сохранения скопированы перед запуском", "ok")

func _copy_dir(from: String, to: String) -> bool:
	var abs_from := ProjectSettings.globalize_path(from)
	var abs_to := ProjectSettings.globalize_path(to)
	if not DirAccess.dir_exists_absolute(abs_from):
		return false
	DirAccess.make_dir_recursive_absolute(abs_to)
	var dir := DirAccess.open(abs_from)
	if dir == null:
		return false
	for sub in dir.get_directories():
		if not _copy_dir(abs_from.path_join(String(sub)), abs_to.path_join(String(sub))):
			return false
	for file in dir.get_files():
		var src := FileAccess.open(abs_from.path_join(String(file)), FileAccess.READ)
		if src == null:
			continue
		var data := src.get_buffer(src.get_length())
		src.close()
		var dst := FileAccess.open(abs_to.path_join(String(file)), FileAccess.WRITE)
		if dst == null:
			continue
		dst.store_buffer(data)
		dst.close()
	return true

func _on_open_folder() -> void:
	var instance := Store.current_instance()
	if instance.is_empty():
		Proc.open_in_file_manager(Store.data_dir())
		return
	Proc.open_in_file_manager(Store.instance_dir(String(instance.get("id", ""))))
