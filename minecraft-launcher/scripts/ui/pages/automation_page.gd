class_name AutomationPage
extends LauncherPage
## Пульт автоматизации: создание ботов, запуск, живой статус и консоль.

var _tasks_box: VBoxContainer
var _editor: Control
var _editor_visible := false
var _editing_id := ""
var _name_field: LineEdit
var _kind_select: Select
var _kind_blurb: Label
var _params_box: VBoxContainer
var _trigger_select: Select
var _interval_slider: SleekSlider
var _interval_label: Label
var _interval_row: Control
var _instance_select: Select
var _enabled_toggle: ToggleSwitch
var _console: ConsoleView
var _filter_select: Select
var _lines: Array = []
var _node_banner: Control
var _param_controls := {}

const FILTERS := [
	{"value": "all", "label": "Все сообщения"},
	{"value": "bot", "label": "Только боты"},
	{"value": "game", "label": "Только лаунчер и игра"},
	{"value": "error", "label": "Только ошибки"},
]

func _ready() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.add_child(_build_toolbar())
	content.add_child(_build_node_banner())
	content.add_child(_build_editor())
	_tasks_box = VBoxContainer.new()
	_tasks_box.add_theme_constant_override("separation", 12)
	_tasks_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_tasks_box)
	content.add_child(_build_console())
	add_child(Kit.scroll(Kit.margin(content, 22, 26, 24, 26)))
	refresh()

# ------------------------------------------------------------------ панели ---
func _build_toolbar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var add_button := AccentButton.make("Новый бот", "accent", "plus")
	add_button.custom_minimum_size = Vector2(170, 42)
	add_button.pressed.connect(func(): _open_editor(""))
	row.add_child(add_button)
	var run_all := AccentButton.make("Запустить всё", "ghost", "play")
	run_all.custom_minimum_size = Vector2(160, 42)
	run_all.corner = 13.0
	run_all.pressed.connect(_run_all)
	row.add_child(run_all)
	var stop_all := AccentButton.make("Остановить всё", "ghost", "stop")
	stop_all.custom_minimum_size = Vector2(170, 42)
	stop_all.corner = 13.0
	stop_all.pressed.connect(func(): Bots.stop_all())
	row.add_child(stop_all)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var hint := Kit.muted("Боты подключаются к серверу и выполняют сценарий. Используйте там, где это разрешено.", 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(320, 0)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)
	return row

func _build_node_banner() -> Control:
	var panel := Kit.glass(16)
	panel.visible = false
	_node_banner = panel
	var margin := MarginContainer.new()
	for pair in [["margin_top", 12], ["margin_right", 16], ["margin_bottom", 12], ["margin_left", 16]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := IconGlyph.new()
	glyph.icon = "warn"
	glyph.glyph_color = Constants.C_WARN
	glyph.custom_minimum_size = Vector2(20, 20)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var label := Kit.label("Node.js не найден", 13, Constants.C_WARN)
	row.add_child(label)
	row.add_child(Kit.muted("Боты автоматизации работают на Node.js. Установите Node.js 18 или новее — лаунчер сам поставит зависимости при первом запуске.", 12))
	margin.add_child(row)
	panel.add_child(margin)
	refresh_node_banner()
	return panel

func refresh_node_banner() -> void:
	if _node_banner == null:
		return
	var node := Proc.find_executable(Proc.exec_name("node"))
	_node_banner.visible = (node == "")

func _build_editor() -> Control:
	var panel := Kit.glass(22)
	panel.visible = false
	_editor = panel
	var margin := MarginContainer.new()
	for pair in [["margin_top", 18], ["margin_right", 20], ["margin_bottom", 18], ["margin_left", 20]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(Kit.section("Настройка бота"))

	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 18)
	form.add_theme_constant_override("v_separation", 10)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_name_field = LineEdit.new()
	_name_field.placeholder_text = "Например: Автошахта на железо"
	_name_field.custom_minimum_size = Vector2(0, 40)
	form.add_child(Kit.setting_row("Название", "Отображается в списке и уведомлениях", _name_field))

	_kind_select = Select.make(_kind_options(), 0, false)
	_kind_select.custom_minimum_size = Vector2(240, 40)
	_kind_select.selected.connect(func(_i, _v): _rebuild_editor_params())
	form.add_child(Kit.setting_row("Вид автоматизации", "Что бот будет делать в игре", _kind_select))

	_kind_blurb = Kit.muted("", 12)
	_kind_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_kind_blurb)

	_trigger_select = Select.make([
		{"value": "manual", "label": "Вручную", "hint": "Только по кнопке"},
		{"value": "on_launch", "label": "При запуске игры", "hint": "Стартует вместе с экземпляром"},
		{"value": "interval", "label": "По расписанию", "hint": "Повторять через заданный интервал"},
	], 0, false)
	_trigger_select.custom_minimum_size = Vector2(240, 40)
	_trigger_select.selected.connect(func(_i, _v): _refresh_trigger_visibility())
	form.add_child(Kit.setting_row("Когда запускать", "Триггер задачи", _trigger_select))

	var interval_box := VBoxContainer.new()
	interval_box.add_theme_constant_override("separation", 2)
	interval_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interval_slider = SleekSlider.new()
	_interval_slider.set_range(1.0, 240.0, 1.0)
	_interval_slider.value = 30.0
	_interval_slider.value_changed.connect(func(v): _interval_label.text = "каждые %d мин" % int(v))
	interval_box.add_child(_interval_slider)
	_interval_label = Kit.label("каждые 30 мин", 12, Constants.C_TEXT_MUTED)
	interval_box.add_child(_interval_label)
	_interval_row = Kit.setting_row("Интервал", "Для запуска по расписанию", interval_box)
	form.add_child(_interval_row)

	_instance_select = Select.make(_instance_options(), 0, false)
	_instance_select.custom_minimum_size = Vector2(240, 40)
	form.add_child(Kit.setting_row("Привязка к сборке", "«Любая» — задача запускается для всех сборок", _instance_select))

	_enabled_toggle = ToggleSwitch.new()
	_enabled_toggle.pressed = true
	form.add_child(Kit.setting_row("Включена", "Выключенные задачи не запускаются автоматически", _enabled_toggle))

	box.add_child(form)
	_params_box = VBoxContainer.new()
	_params_box.add_theme_constant_override("separation", 12)
	_params_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_params_box)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	var save := AccentButton.make("Сохранить", "accent", "check")
	save.custom_minimum_size = Vector2(160, 44)
	save.pressed.connect(_save_task)
	actions.add_child(save)
	var cancel := AccentButton.make("Отмена", "ghost", "close")
	cancel.custom_minimum_size = Vector2(120, 44)
	cancel.pressed.connect(func(): _set_editor_visible(false))
	actions.add_child(cancel)
	var run_now := AccentButton.make("Сохранить и запустить", "ghost", "play")
	run_now.custom_minimum_size = Vector2(220, 44)
	run_now.pressed.connect(func():
		_save_task()
		Bots.run_now(_editing_id if _editing_id != "" else _last_added_id)
	)
	actions.add_child(run_now)
	box.add_child(actions)

	margin.add_child(box)
	panel.add_child(margin)
	_rebuild_editor_params()
	return panel

var _last_added_id := ""

func _kind_options() -> Array:
	var out: Array = []
	for kind in AutomationSchema.kinds():
		out.append({"value": kind, "label": Constants.kind_title(kind), "hint": AutomationSchema.kind_blurb(kind)})
	return out

func _instance_options() -> Array:
	var out: Array = [{"value": "", "label": "Любая сборка", "hint": "Задача не привязана к экземпляру"}]
	for instance in Store.instances:
		out.append({"value": String(instance.get("id", "")), "label": String(instance.get("name", "")), "hint": "MC " + String(instance.get("version", ""))})
	return out

# ------------------------------------------------------------------ редактор -
func _open_editor(task_id: String) -> void:
	_editing_id = task_id
	var task: Dictionary = {}
	if task_id != "":
		task = Bots.get(task_id)
	if task.is_empty():
		task = Bots.new_task("mine")
	_name_field.text = String(task.get("name", ""))
	var kind := String(task.get("kind", "mine"))
	for i in range(_kind_select.options.size()):
		if String((_kind_select.options[i] as Dictionary).get("value", "")) == kind:
			_kind_select.select_index(i, false)
			break
	_rebuild_editor_params()
	var params: Dictionary = task.get("params", {})
	for key in _param_controls.keys():
		_apply_value(key, params.get(key, null))
	var trigger := String(task.get("trigger", "manual"))
	for i in range(_trigger_select.options.size()):
		if String((_trigger_select.options[i] as Dictionary).get("value", "")) == trigger:
			_trigger_select.select_index(i, false)
			break
	_interval_slider.value = float(int(task.get("interval_minutes", 30)))
	_interval_label.text = "каждые %d мин" % int(_interval_slider.value)
	var bind := String(task.get("instance_id", ""))
	_instance_select.set_options(_instance_options(), 0)
	for i in range(_instance_select.options.size()):
		if String((_instance_select.options[i] as Dictionary).get("value", "")) == bind:
			_instance_select.select_index(i, false)
			break
	_enabled_toggle.pressed = bool(task.get("enabled", true))
	_refresh_trigger_visibility()
	_set_editor_visible(true)

func _set_editor_visible(value: bool) -> void:
	_editor_visible = value
	_editor.visible = value

func _refresh_trigger_visibility() -> void:
	var trigger = _trigger_select.selected_value()
	_interval_row.visible = (String(trigger) == "interval")

func _current_value(field: Dictionary):
	return field.get("default", null)

func _apply_value(key: String, value) -> void:
	if not _param_controls.has(key):
		return
	var control = _param_controls[key]
	var field := _find_field(String(_kind_select.selected_value()), key)
	if field.is_empty():
		return
	match String(field["type"]):
		"text":
			(control as LineEdit).text = String(value) if value != null else String(field.get("default", ""))
		"text_area":
			(control as TextEdit).text = String(value) if value != null else String(field.get("default", ""))
		"int":
			var slider: SleekSlider = control.get_child(0)
			slider.value = float(value) if value != null else float(field.get("default", 0))
		"bool":
			(control as ToggleSwitch).pressed = bool(value) if value != null else bool(field.get("default", false))
		"tags":
			var picker: TagPicker = control
			picker.set_options(field["options"], value if value != null else field.get("default", []))

func _find_field(kind: String, key: String) -> Dictionary:
	for field in AutomationSchema.fields(kind):
		if String(field["key"]) == key:
			return field
	return {}

func _rebuild_editor_params() -> void:
	if _params_box == null:
		return
	for child in _params_box.get_children():
		child.queue_free()
	_param_controls.clear()
	var kind := String(_kind_select.selected_value())
	_kind_blurb.text = AutomationSchema.kind_blurb(kind)
	for field in AutomationSchema.fields(kind):
		var key := String(field["key"])
		var type := String(field["type"])
		var hint := String(field.get("hint", ""))
		var control: Control
		match type:
			"text":
				var edit := LineEdit.new()
				edit.text = String(field.get("default", ""))
				edit.placeholder_text = hint
				edit.custom_minimum_size = Vector2(260, 38)
				control = edit
			"text_area":
				var area := TextEdit.new()
				area.text = String(field.get("default", ""))
				area.custom_minimum_size = Vector2(460, 140)
				area.add_theme_font_size_override("font_size", 12)
				area.add_theme_color_override("font_color", Constants.C_TEXT)
				area.add_theme_color_override("font_readonly_color", Constants.C_TEXT)
				area.add_theme_stylebox_override("normal", ThemeBuilder.glass_surface())
				area.add_theme_stylebox_override("focus", ThemeBuilder.glass_surface())
				control = area
			"int":
				var box := VBoxContainer.new()
				box.add_theme_constant_override("separation", 2)
				box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var slider := SleekSlider.new()
				slider.set_range(float(field.get("min", 0)), float(field.get("max", 100)), 1.0)
				slider.value = float(field.get("default", 0))
				var value_label := Kit.label("%d" % int(slider.value), 12, Constants.C_TEXT_MUTED)
				slider.value_changed.connect(func(v): value_label.text = "%d" % int(v))
				box.add_child(slider)
				box.add_child(value_label)
				control = box
			"bool":
				var toggle := ToggleSwitch.new()
				toggle.pressed = bool(field.get("default", false))
				control = toggle
			"tags":
				var picker := TagPicker.new()
				picker.set_options(field.get("options", []), field.get("default", []))
				picker.custom_minimum_size = Vector2(460, 0)
				control = picker
		_param_controls[key] = control
		_params_box.add_child(Kit.setting_row(String(field["label"]), hint, control))

func _save_task() -> void:
	var kind := String(_kind_select.selected_value())
	var params := AutomationSchema.defaults(kind)
	for key in _param_controls.keys():
		var control = _param_controls[key]
		var field := _find_field(kind, key)
		if field.is_empty():
			continue
		match String(field["type"]):
			"text":
				params[key] = String((control as LineEdit).text)
			"text_area":
				params[key] = String((control as TextEdit).text)
			"int":
				params[key] = int((control.get_child(0) as SleekSlider).value)
			"bool":
				params[key] = bool((control as ToggleSwitch).pressed)
			"tags":
				params[key] = (control as TagPicker).get_selected()

	var name := _name_field.text.strip_edges()
	if name == "":
		name = Constants.kind_title(kind)

	var task: Dictionary = {}
	if _editing_id != "":
		task = Bots.get(_editing_id)
	if task.is_empty():
		task = Bots.new_task(kind)
		_last_added_id = String(task.get("id", ""))
	task["name"] = name
	task["kind"] = kind
	task["params"] = params
	task["trigger"] = String(_trigger_select.selected_value())
	task["interval_minutes"] = int(_interval_slider.value)
	var bind = _instance_select.selected_value()
	task["instance_id"] = String(bind) if bind != null else ""
	task["enabled"] = _enabled_toggle.pressed

	if _editing_id != "":
		Bots.update(task)
		Notify.push("Задача обновлена", name, "ok")
	else:
		Bots.add(task)
		Notify.push("Задача добавлена", name, "ok")
	_set_editor_visible(false)
	refresh()

func _run_all() -> void:
	var started := 0
	for task in Bots.all():
		if not bool(task.get("enabled", true)):
			continue
		var result := Bots.run_now(String(task.get("id", "")))
		if bool(result.get("ok", false)):
			started += 1
	if started == 0:
		Notify.push("Нечего запускать", "Включите задачи или добавьте новую", "warn")
	else:
		Notify.push("Запущено задач: %d" % started, "Следите за статусом в списке", "ok")

# ------------------------------------------------------------------- список --
func refresh() -> void:
	if _tasks_box == null:
		return
	for child in _tasks_box.get_children():
		child.queue_free()
	refresh_node_banner()
	if Bots.all().is_empty():
		var hint := Kit.muted("Задач пока нет. Нажмите «Новый бот»: автошахта, автоварка зелий, авторыбалка, автоферма, автоплавильня, автопитание, анти-AFK или свой макрос.", 13)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tasks_box.add_child(hint)
		return
	var stats := _build_stats_panel()
	_tasks_box.add_child(stats)
	for task in Bots.all():
		_tasks_box.add_child(_task_card(task))

func _build_stats_panel() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var total := Bots.all().size()
	var running := Bots.running_count()
	var actions := Bots.total_actions()
	row.add_child(_stat("Активно", "%d из %d" % [running, total]))
	row.add_child(_stat("Действий всего", str(actions)))
	row.add_child(_stat("Лимит параллельно", str(int(Store.setting("max_concurrent_tasks", 2)))))
	return row

func _stat(caption: String, value: String) -> Control:
	var tile := Kit.stat_tile(caption, value)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tile

func _task_card(task: Dictionary) -> Control:
	var id := String(task.get("id", ""))
	var state := Bots.state_of(id)
	var panel := Kit.card(18)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var margin := MarginContainer.new()
	for pair in [["margin_top", 14], ["margin_right", 16], ["margin_bottom", 14], ["margin_left", 16]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_PASS

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := IconGlyph.new()
	glyph.icon = AutomationSchema.kind_icon(String(task.get("kind", "mine")))
	glyph.glyph_color = _state_color(state)
	glyph.custom_minimum_size = Vector2(22, 22)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(glyph)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 1)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(Kit.label(String(task.get("name", "")), 15, Color(1, 1, 1)))
	var meta := "%s · %s · запусков: %d · действий: %d" % [
		Constants.kind_title(String(task.get("kind", ""))),
		Constants.trigger_title(String(task.get("trigger", ""))),
		int(task.get("runs", 0)),
		int(task.get("actions", 0)),
	]
	texts.add_child(Kit.label(meta, 11, Constants.C_TEXT_DIM))
	head.add_child(texts)
	var chip := Chip.new()
	chip.text = _state_title(state)
	chip.chip_color = _state_color(state)
	head.add_child(chip)

	var running := state in ["running", "starting", "installing"]
	var primary := AccentButton.make("Остановить" if running else "Запустить", "danger" if running else "accent", "stop" if running else "play")
	primary.custom_minimum_size = Vector2(140, 38)
	primary.corner = 12.0
	primary.pressed.connect(func():
		if running:
			Bots.stop(id)
		else:
			var result := Bots.run_now(id)
			if not bool(result.get("ok", false)):
				Notify.push("Не удалось запустить", String(result.get("error", "")), "error")
	)
	head.add_child(primary)
	var edit := AccentButton.make("", "ghost", "gear")
	edit.custom_minimum_size = Vector2(44, 38)
	edit.corner = 12.0
	edit.tooltip_text = "Изменить задачу"
	edit.pressed.connect(func(): _open_editor(id))
	head.add_child(edit)
	var remove := AccentButton.make("", "danger", "trash")
	remove.custom_minimum_size = Vector2(44, 38)
	remove.corner = 12.0
	remove.tooltip_text = "Удалить задачу"
	remove.pressed.connect(func(): _delete_task(id))
	head.add_child(remove)
	box.add_child(head)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st: Dictionary = Bots.states.get(id, {})
	var started_at := int(st.get("started", 0))
	var duration_cfg := int((task.get("params", {}) as Dictionary).get("duration_minutes", 60))
	if running and started_at > 0 and duration_cfg > 0:
		var elapsed := maxi(0, Time.get_unix_time_from_system() - started_at)
		bar.value = clampf(float(elapsed) / float(duration_cfg * 60), 0.0, 1.0) * 100.0
	else:
		bar.value = 0.0
	box.add_child(bar)

	var note := String(st.get("note", ""))
	var status_text := ""
	if running:
		status_text = note if note != "" else "выполняется"
	elif state == "error":
		status_text = "ошибка: " + String(st.get("error", ""))
	elif state == "done":
		status_text = "завершено успешно"
	elif state == "stopped":
		status_text = "остановлено"
	else:
		status_text = "ожидает запуска"
	box.add_child(Kit.label(status_text, 11, Constants.C_TEXT_MUTED))

	margin.add_child(box)
	panel.add_child(margin)
	return panel

func _delete_task(id: String) -> void:
	var task := Bots.get(id)
	Bots.remove(id)
	Notify.push("Задача удалена", String(task.get("name", id)), "info")
	refresh()

func _state_title(state: String) -> String:
	match state:
		"running": return "выполняется"
		"starting": return "запуск"
		"installing": return "установка"
		"stopped": return "остановлена"
		"done": return "готово"
		"error": return "ошибка"
		"added", "updated": return "сохранена"
	return "ожидает"

func _state_color(state: String) -> Color:
	match state:
		"running", "starting": return Constants.C_OK
		"installing": return Constants.C_WARN
		"stopped", "done", "added", "updated": return Constants.C_INFO
		"error": return Constants.C_ERR
	return Constants.C_TEXT_DIM

# ------------------------------------------------------------------ консоль --
func _build_console() -> Control:
	var panel := Kit.glass(20)
	var margin := MarginContainer.new()
	for pair in [["margin_top", 16], ["margin_right", 16], ["margin_bottom", 16], ["margin_left", 16]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(Kit.section("Живой журнал"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	_filter_select = Select.make(FILTERS, 0, false)
	_filter_select.custom_minimum_size = Vector2(230, 36)
	_filter_select.selected.connect(func(_i, _v): _render_console())
	head.add_child(_filter_select)
	var clear := AccentButton.make("Очистить", "ghost", "close")
	clear.custom_minimum_size = Vector2(120, 36)
	clear.corner = 11.0
	clear.pressed.connect(func():
		_lines.clear()
		_render_console()
	)
	head.add_child(clear)
	box.add_child(head)

	_console = ConsoleView.new()
	_console.custom_minimum_size = Vector2(0, 220)
	box.add_child(_console)
	margin.add_child(box)
	panel.add_child(margin)
	return panel

func _render_console() -> void:
	if _console == null:
		return
	_console.clear_all()
	var count := 0
	for entry in _lines:
		var level := String(entry.get("level", "info"))
		var task_id := String(entry.get("task", ""))
		if not _matches_filter(level, task_id):
			continue
		_console.add_line(String(entry.get("text", "")), level)
		count += 1
		if count >= 300:
			break

func _push_line(level: String, text: String, task_id := "") -> void:
	_lines.append({"level": level, "text": text, "task": task_id})
	if _lines.size() > 600:
		_lines = _lines.slice(_lines.size() - 600)
	if _matches_filter(level, task_id):
		_console.add_line(text, level)

func _matches_filter(level: String, task_id: String) -> bool:
	var filter := String(_filter_select.selected_value() if _filter_select != null else "all")
	match filter:
		"bot": return task_id != ""
		"game": return task_id == ""
		"error": return level == "error" or level == "warn"
	return true

# ------------------------------------------------------------------ события --
func on_log(level: String, text: String) -> void:
	_push_line(level, text)

func on_task_log(task_id: String, level: String, text: String) -> void:
	var task := Bots.get(task_id)
	var name := String(task.get("name", task_id))
	_push_line(level, "[" + name + "] " + text, task_id)

func on_task_state(task_id: String, state: String) -> void:
	refresh()

func on_task_progress(task_id: String, ratio: float) -> void:
	pass

func on_instance_changed() -> void:
	_instance_select.set_options(_instance_options(), 0)

func on_versions_ready() -> void:
	pass
