class_name InstancesPage
extends LauncherPage
## Экземпляры: список сборок и создание новых (версия + загрузчик + Java + ОЗУ).

var _grid: GridContainer
var _create_panel: Control
var _name_field: LineEdit
var _version_select: Select
var _loader_select: Select
var _ram_slider: SleekSlider
var _ram_label: Label
var _java_select: Select
var _status_label: Label
var _search_field: LineEdit
var _create_visible := false
var _pending_delete := ""

func _ready() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.add_child(_build_toolbar())
	content.add_child(_build_create_panel())
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_grid)
	add_child(Kit.scroll(Kit.margin(content, 22, 26, 24, 26)))
	Bus.version_preset.connect(_on_version_preset)
	refresh()

func _build_toolbar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var create_button := AccentButton.make("Новый экземпляр", "accent", "plus")
	create_button.custom_minimum_size = Vector2(200, 42)
	create_button.pressed.connect(_toggle_create)
	row.add_child(create_button)
	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Поиск по сборкам..."
	_search_field.custom_minimum_size = Vector2(260, 42)
	_search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_field.text_changed.connect(func(_t): refresh())
	row.add_child(_search_field)
	var info := Kit.muted("Загрузчик ставится автоматически при первом запуске", 12)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	return row

func _build_create_panel() -> Control:
	var panel := Kit.glass(22)
	panel.visible = false
	_create_panel = panel
	var margin := MarginContainer.new()
	for pair in [["margin_top", 18], ["margin_right", 20], ["margin_bottom", 18], ["margin_left", 20]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(Kit.section("Новая сборка"))

	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 18)
	form.add_theme_constant_override("v_separation", 12)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_name_field = LineEdit.new()
	_name_field.placeholder_text = "Моя сборка"
	_name_field.custom_minimum_size = Vector2(0, 40)
	form.add_child(Kit.setting_row("Название", "Как сборка будет называться в списке", _name_field))

	_version_select = Select.make([], 0, true)
	_version_select.custom_minimum_size = Vector2(240, 40)
	form.add_child(Kit.setting_row("Версия Minecraft", "Из официального манифеста Mojang", _version_select))

	_loader_select = Select.make(_loader_options(), 0, false)
	_loader_select.custom_minimum_size = Vector2(240, 40)
	form.add_child(Kit.setting_row("Загрузчик модов", "Vanilla — чистая игра без модов", _loader_select))

	var ram_row := VBoxContainer.new()
	ram_row.add_theme_constant_override("separation", 4)
	ram_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ram_slider = SleekSlider.new()
	_ram_slider.set_range(1024.0, float(Store.system_ram_mb()), 512.0)
	_ram_slider.value = float(Store.recommended_ram_mb())
	_ram_slider.value_changed.connect(func(v):
		_ram_label.text = "%d МБ" % int(v)
	)
	ram_row.add_child(_ram_slider)
	_ram_label = Kit.label("%d МБ" % int(_ram_slider.value), 12, Constants.C_TEXT_MUTED)
	ram_row.add_child(_ram_label)
	form.add_child(Kit.setting_row("Оперативная память", "Рекомендуется 35–50% от системной", ram_row))

	_java_select = Select.make(_java_options(), 0, false)
	_java_select.custom_minimum_size = Vector2(240, 40)
	form.add_child(Kit.setting_row("Java", "Авто — подберётся под версию игры", _java_select))

	box.add_child(form)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	var create := AccentButton.make("Создать", "accent", "check")
	create.custom_minimum_size = Vector2(160, 44)
	create.pressed.connect(_create)
	actions.add_child(create)
	var cancel := AccentButton.make("Отмена", "ghost", "close")
	cancel.custom_minimum_size = Vector2(120, 44)
	cancel.pressed.connect(func(): _set_create_visible(false))
	actions.add_child(cancel)
	_status_label = Kit.label("", 12, Constants.C_TEXT_MUTED)
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(_status_label)
	box.add_child(actions)

	margin.add_child(box)
	panel.add_child(margin)
	return panel

func _loader_options() -> Array:
	var out: Array = []
	for loader in ["vanilla", "fabric", "quilt", "neoforge", "forge"]:
		out.append({"value": loader, "label": Constants.loader_title(loader), "hint": _loader_hint(loader)})
	return out

func _loader_hint(loader: String) -> String:
	match loader:
		"vanilla": return "Чистая игра без модов"
		"fabric": return "Лёгкий и быстрый загрузчик, лучшая совместимость"
		"quilt": return "Форк Fabric с расширенными возможностями"
		"neoforge": return "Актуальный форк Forge для новых версий"
		"forge": return "Классический загрузчик больших сборок"
	return ""

func _java_options() -> Array:
	var out: Array = [{"value": "", "label": "Авто (рекомендуется)", "hint": "Лаунчер подберёт Java под версию"}]
	for info in Java.detected:
		out.append({"value": String(info.get("path", "")), "label": String(info.get("name", "Java")), "hint": String(info.get("path", ""))})
	return out

# ---------------------------------------------------------------- действия ---
func _toggle_create() -> void:
	_set_create_visible(not _create_visible)

func _set_create_visible(value: bool) -> void:
	_create_visible = value
	_create_panel.visible = value
	if value:
		_version_select.set_options(_version_options(), _version_select.selected_index)
		_java_select.set_options(_java_options(), 0)
		_name_field.grab_focus()

func _on_version_preset(version_id: String) -> void:
	_set_create_visible(true)
	_version_select.set_options(_version_options(), 0)
	for i in range(_version_select.options.size()):
		var opt: Dictionary = _version_select.options[i]
		if String(opt.get("value", "")) == version_id:
			_version_select.select_index(i, false)
			break

func _version_options() -> Array:
	var out: Array = []
	if Mojang.manifest.is_empty():
		out.append({"value": "", "label": "Загружаю манифест..."})
		return out
	for v in Mojang.manifest.get("versions", []):
		var version: Dictionary = v
		var kind := String(version.get("type", ""))
		if kind == "old_alpha" or kind == "old_beta":
			continue
		out.append({"value": String(version.get("id", "")), "label": String(version.get("id", "")) + "  ·  " + _kind_title(kind), "hint": String(version.get("releaseTime", "")).substr(0, 10)})
		if out.size() >= 160:
			break
	return out

func _kind_title(kind: String) -> String:
	match kind:
		"release": return "релиз"
		"snapshot": return "снапшот"
		"old_beta": return "бета"
		"old_alpha": return "альфа"
	return kind

func _create() -> void:
	var name := _name_field.text.strip_edges()
	if name == "":
		name = "Сборка " + str(Store.instances.size() + 1)
	var version = _version_select.selected_value()
	if version == null or String(version) == "":
		Notify.push("Не выбрана версия", "Выберите версию из манифеста Mojang", "warn")
		return
	var loader = _loader_select.selected_value()
	var java_path = _java_select.selected_value()
	var id := "%s-%d" % [name.to_lower().replace(" ", "-"), Time.get_unix_time_from_system()]
	var instance := {
		"id": id,
		"name": name,
		"version": String(version),
		"loader": String(loader),
		"ram_mb": int(_ram_slider.value),
		"java_path": String(java_path) if java_path != null else "",
		"java_major": 17,
		"mods": [],
		"created": Time.get_unix_time_from_system(),
		"last_played": 0,
	}
	Store.upsert_instance(instance)
	Store.select_instance(id)
	DirAccess.make_dir_recursive_absolute(Store.instance_dir(id).path_join("mods"))
	Notify.push("Экземпляр создан", "%s · %s · %s" % [name, String(version), Constants.loader_title(String(loader))], "ok")
	_set_create_visible(false)
	_name_field.text = ""
	refresh()
	_probe_java(id)

func _probe_java(id: String) -> void:
	var instance := Store.instance_by_id(id)
	if instance.is_empty():
		return
	var vjson := await Mojang.version_json(String(instance.get("version", "")))
	if vjson.is_empty():
		return
	instance["java_major"] = Mojang.java_major(vjson)
	Store.upsert_instance(instance)

func _delete(id: String) -> void:
	if _pending_delete != id:
		_pending_delete = id
		Notify.push("Нажмите удалить ещё раз", "Экземпляр будет перемещён в корзину", "warn")
		refresh()
		return
	_pending_delete = ""
	var instance := _instance_by_id(id)
	Store.remove_instance(id)
	var dir := Store.instance_dir(id)
	if DirAccess.dir_exists_absolute(dir):
		OS.move_to_trash(ProjectSettings.globalize_path(dir))
	Notify.push("Экземпляр удалён", String(instance.get("name", id)), "info")
	refresh()

func _instance_by_id(id: String) -> Dictionary:
	return Store.instance_by_id(id)

func _play(id: String) -> void:
	Store.select_instance(id)
	var instance := _instance_by_id(id)
	if instance.is_empty():
		return
	if Game.running:
		Game.stop()
		return
	if bool(Store.setting("auto_backup", true)):
		Notify.push("Делаю бэкап сохранений", "Перед запуском", "info")
	await Game.launch(instance)

func _open_folder(id: String) -> void:
	Proc.open_in_file_manager(Store.instance_dir(id))

# --------------------------------------------------------------- отрисовка ---
func refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var needle := ""
	if _search_field != null:
		needle = _search_field.text.to_lower()
	if Store.instances.is_empty():
		_grid.columns = 1
		var hint := Kit.muted("Пока нет ни одной сборки. Нажмите «Новый экземпляр» — лаунчер сам скачает клиент, библиотеки и ресурсы.", 13)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_grid.add_child(hint)
		return
	_grid.columns = 2
	for instance in Store.instances:
		var name := String(instance.get("name", ""))
		if needle != "" and not name.to_lower().contains(needle):
			continue
		_grid.add_child(_instance_card(instance))

func _instance_card(instance: Dictionary) -> Control:
	var id := String(instance.get("id", ""))
	var name := String(instance.get("name", "Экземпляр"))
	var panel := Kit.card(20)
	panel.custom_minimum_size = Vector2(430, 170)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var margin := MarginContainer.new()
	for pair in [["margin_top", 14], ["margin_right", 16], ["margin_bottom", 14], ["margin_left", 16]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	var cover := CoverArt.new()
	cover.seed_text = name
	cover.custom_minimum_size = Vector2(128, 128)
	cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cover.set_caption(name.substr(0, 18).to_upper())
	cover.set_icon(_icon_for(instance))
	row.add_child(cover)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(Kit.label(name, 17, Color(1, 1, 1)))

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_child(_chip("MC " + String(instance.get("version", "?"))))
	chips.add_child(_chip(Constants.loader_title(String(instance.get("loader", "vanilla")))))
	chips.add_child(_chip("%d модов" % int((instance.get("mods", []) as Array).size())))
	chips.add_child(_chip("%d МБ" % int(instance.get("ram_mb", 4096))))
	info.add_child(chips)

	var last := int(instance.get("last_played", 0))
	var meta := "Ещё не запускался"
	if last > 0:
		meta = "Запускался: " + Time.get_datetime_string_from_unix_time(last)
	info.add_child(Kit.label(meta, 11, Constants.C_TEXT_DIM))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	var play := AccentButton.make("Играть", "accent", "play")
	play.custom_minimum_size = Vector2(118, 40)
	play.corner = 12.0
	play.pressed.connect(func(): _play(id))
	buttons.add_child(play)
	var bots := AccentButton.make("Боты", "ghost", "robot")
	bots.custom_minimum_size = Vector2(104, 40)
	bots.corner = 12.0
	bots.pressed.connect(func():
		Store.select_instance(id)
		Bus.nav_requested.emit("automation")
	)
	buttons.add_child(bots)
	var folder := AccentButton.make("", "ghost", "folder")
	folder.custom_minimum_size = Vector2(44, 40)
	folder.corner = 12.0
	folder.tooltip_text = "Открыть папку сборки"
	folder.pressed.connect(func(): _open_folder(id))
	buttons.add_child(folder)
	var remove := AccentButton.make("", "danger", "trash")
	remove.custom_minimum_size = Vector2(44, 40)
	remove.corner = 12.0
	remove.tooltip_text = "Удалить сборку"
	if _pending_delete == id:
		remove.set_label("!")
	remove.pressed.connect(func(): _delete(id))
	buttons.add_child(remove)
	info.add_child(buttons)

	row.add_child(info)
	margin.add_child(row)
	panel.add_child(margin)
	return panel

func _chip(text: String) -> Chip:
	var chip := Chip.new()
	chip.text = text
	return chip

func _icon_for(instance: Dictionary) -> String:
	match String(instance.get("loader", "vanilla")):
		"fabric", "quilt", "forge", "neoforge": return "box"
	return "layers"

func on_versions_ready() -> void:
	_version_select.set_options(_version_options(), 0)

func on_game_state(state: String, pid: int) -> void:
	refresh()
