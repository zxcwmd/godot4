class_name ModsPage
extends LauncherPage
## Каталог модов Modrinth: поиск, установка в выбранную сборку и обновления.

var _results_grid: GridContainer
var _installed_box: VBoxContainer
var _search_field: LineEdit
var _version_field: LineEdit
var _loader_select: Select
var _status_label: Label
var _hint_box: Control
var _last_results: Array = []
var _busy := false

func _ready() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.add_child(_build_header())
	content.add_child(_build_search())
	_results_grid = GridContainer.new()
	_results_grid.columns = 2
	_results_grid.add_theme_constant_override("h_separation", 16)
	_results_grid.add_theme_constant_override("v_separation", 16)
	_results_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_results_grid)
	content.add_child(_build_installed())
	add_child(Kit.scroll(Kit.margin(content, 22, 26, 24, 26)))
	refresh()

func _build_header() -> Control:
	var panel := Kit.glass(20)
	var margin := MarginContainer.new()
	for pair in [["margin_top", 14], ["margin_right", 18], ["margin_bottom", 14], ["margin_left", 18]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := IconGlyph.new()
	glyph.icon = "box"
	glyph.glyph_color = Constants.C_INFO
	glyph.custom_minimum_size = Vector2(22, 22)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(Kit.label("Моды ставятся в выбранную сборку", 14, Color(1, 1, 1)))
	_hint_box = texts
	row.add_child(texts)
	margin.add_child(row)
	panel.add_child(margin)
	return panel

func _build_search() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Поиск модов на Modrinth (например: sodium, jei, create)"
	_search_field.custom_minimum_size = Vector2(320, 42)
	_search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_field.text_submitted.connect(func(_t): _search())
	row.add_child(_search_field)
	_version_field = LineEdit.new()
	_version_field.placeholder_text = "1.20.1"
	_version_field.custom_minimum_size = Vector2(110, 42)
	row.add_child(_version_field)
	_loader_select = Select.make(_loader_options(), 0, false)
	_loader_select.custom_minimum_size = Vector2(170, 42)
	row.add_child(_loader_select)
	var button := AccentButton.make("Найти", "accent", "search")
	button.custom_minimum_size = Vector2(130, 42)
	button.pressed.connect(_search)
	row.add_child(button)
	_status_label = Kit.label("", 12, Constants.C_TEXT_MUTED)
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_status_label)
	return row

func _loader_options() -> Array:
	var out: Array = [{"value": "", "label": "Любой загрузчик"}]
	for loader in ["fabric", "quilt", "neoforge", "forge"]:
		out.append({"value": loader, "label": Constants.loader_title(loader)})
	return out

func _build_installed() -> Control:
	var panel := Kit.glass(20)
	var margin := MarginContainer.new()
	for pair in [["margin_top", 16], ["margin_right", 18], ["margin_bottom", 16], ["margin_left", 18]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(Kit.section("Установленные моды"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	var update_button := AccentButton.make("Обновить все", "ghost", "refresh")
	update_button.custom_minimum_size = Vector2(160, 36)
	update_button.corner = 11.0
	update_button.pressed.connect(_update_all)
	head.add_child(update_button)
	box.add_child(head)
	_installed_box = VBoxContainer.new()
	_installed_box.add_theme_constant_override("separation", 8)
	_installed_box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_installed_box)
	margin.add_child(box)
	panel.add_child(margin)
	return panel

# ------------------------------------------------------------------ действия --
func _current() -> Dictionary:
	return Store.current_instance()

func refresh() -> void:
	if _hint_box == null:
		return
	for child in _hint_box.get_children():
		child.queue_free()
	var instance := _current()
	if instance.is_empty():
		_hint_box.add_child(Kit.label("Сначала выберите сборку", 14, Color(1, 1, 1)))
		_hint_box.add_child(Kit.muted("Моды можно ставить только в существующий экземпляр с загрузчиком модов.", 12))
	else:
		var loader := String(instance.get("loader", "vanilla"))
		_hint_box.add_child(Kit.label("%s · MC %s · %s" % [String(instance.get("name", "")), String(instance.get("version", "")), Constants.loader_title(loader)], 14, Color(1, 1, 1)))
		if loader == "vanilla":
			_hint_box.add_child(Kit.label("Vanilla не поддерживает моды — создайте сборку с Fabric, Quilt, Forge или NeoForge.", 12, Constants.C_WARN))
		else:
			_hint_box.add_child(Kit.muted("Версия и загрузчик подставятся автоматически при поиске.", 12))
		_version_field.text = String(instance.get("version", ""))
	_refresh_installed()
	_refresh_results()

func _refresh_results() -> void:
	for child in _results_grid.get_children():
		child.queue_free()
	if _last_results.is_empty():
		var hint := Kit.muted("Введите запрос и нажмите «Найти» — результаты появятся здесь.", 12)
		_results_grid.add_child(hint)
		return
	for hit in _last_results:
		_results_grid.add_child(_result_card(hit))

func _result_card(hit: Dictionary) -> Control:
	var slug := String(hit.get("slug", ""))
	var panel := Kit.card(18)
	panel.custom_minimum_size = Vector2(430, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var margin := MarginContainer.new()
	for pair in [["margin_top", 14], ["margin_right", 16], ["margin_bottom", 14], ["margin_left", 16]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cover := CoverArt.new()
	cover.seed_text = slug
	cover.custom_minimum_size = Vector2(56, 56)
	cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cover.set_icon("box")
	head.add_child(cover)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(Kit.label(String(hit.get("title", slug)), 15, Color(1, 1, 1)))
	var description := String(hit.get("description", ""))
	if description.length() > 110:
		description = description.substr(0, 110) + "..."
	texts.add_child(Kit.muted(description, 11))
	var meta := Kit.label("загрузок: %s" % str(int(hit.get("downloads", 0))), 11, Constants.C_TEXT_DIM)
	texts.add_child(meta)
	head.add_child(texts)
	var install := AccentButton.make("Установить", "accent", "download")
	install.custom_minimum_size = Vector2(140, 38)
	install.corner = 12.0
	install.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	install.pressed.connect(func(): _install(slug, install))
	head.add_child(install)
	box.add_child(head)
	margin.add_child(box)
	panel.add_child(margin)
	return panel

func _install(slug: String, button: AccentButton) -> void:
	var instance := _current()
	if instance.is_empty():
		Notify.push("Нет сборки", "Выберите экземпляр на странице «Экземпляры»", "warn")
		return
	if String(instance.get("loader", "vanilla")) == "vanilla":
		Notify.push("Vanilla без модов", "Создайте сборку с Fabric, Quilt, Forge или NeoForge", "warn")
		return
	button.disabled = true
	button.set_label("Качаю...")
	_status_label.text = "Ищу совместимую версию %s..." % slug
	var version := await Mods.latest_compatible(slug, _version_field.text.strip_edges(), String(instance.get("loader", "")))
	if version.is_empty():
		button.disabled = false
		button.set_label("Установить")
		_status_label.text = "Нет совместимой версии для этой сборки"
		Notify.push("Несовместимо", "Для %s нет версии под MC %s / %s" % [slug, String(instance.get("version", "")), Constants.loader_title(String(instance.get("loader", "")))], "warn")
		return
	var result := await Mods.install_mod(instance, version)
	button.disabled = false
	button.set_label("Установить")
	if bool(result.get("ok", false)):
		_status_label.text = "Установлен %s (%s)" % [slug, String(version.get("version_number", ""))]
		Notify.push("Мод установлен", String(version.get("name", slug)), "ok")
	else:
		_status_label.text = "Ошибка: " + String(result.get("error", ""))
		Notify.push("Не удалось установить", String(result.get("error", "")), "error")
	refresh()

func _search() -> void:
	if _busy:
		return
	var query := _search_field.text.strip_edges()
	if query == "":
		return
	_busy = true
	_status_label.text = "Ищу «%s»..." % query
	var hits := await Mods.search(query, _version_field.text.strip_edges(), String(_loader_select.selected_value()), "mod", 24, 0)
	_last_results = hits
	_busy = false
	_status_label.text = "Найдено: %d" % hits.size()
	_refresh_results()

func _refresh_installed() -> void:
	for child in _installed_box.get_children():
		child.queue_free()
	var instance := _current()
	if instance.is_empty():
		_installed_box.add_child(Kit.muted("Сборка не выбрана.", 12))
		return
	var mods: Array = instance.get("mods", [])
	if mods.is_empty():
		_installed_box.add_child(Kit.muted("Модов пока нет. Найдите нужный мод выше и нажмите «Установить».", 12))
		return
	for mod in mods:
		_installed_box.add_child(_installed_row(mod, instance))

func _installed_row(mod: Dictionary, instance: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 42)
	var card := Kit.card(12)
	var inner := MarginContainer.new()
	for pair in [["margin_top", 8], ["margin_right", 12], ["margin_bottom", 8], ["margin_left", 12]]:
		inner.add_theme_constant_override(pair[0], pair[1])
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := IconGlyph.new()
	glyph.icon = "box"
	glyph.glyph_color = Constants.C_TEXT_MUTED
	glyph.custom_minimum_size = Vector2(16, 16)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(glyph)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(Kit.label(String(mod.get("name", mod.get("filename", ""))), 13, Color(1, 1, 1)))
	texts.add_child(Kit.label(String(mod.get("version_number", "")), 11, Constants.C_TEXT_DIM))
	line.add_child(texts)
	var remove := AccentButton.make("", "danger", "trash")
	remove.custom_minimum_size = Vector2(40, 34)
	remove.corner = 11.0
	remove.tooltip_text = "Удалить мод"
	var filename := String(mod.get("filename", ""))
	remove.pressed.connect(func(): _remove_mod(filename, instance))
	line.add_child(remove)
	inner.add_child(line)
	card.add_child(inner)
	row.add_child(card)
	return row

func _remove_mod(filename: String, instance: Dictionary) -> void:
	var mods_dir := Store.instance_dir(String(instance.get("id", ""))).path_join("mods")
	var path := mods_dir.path_join(filename)
	if FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var mods: Array = instance.get("mods", [])
	for i in range(mods.size()):
		if String((mods[i] as Dictionary).get("filename", "")) == filename:
			mods.remove_at(i)
			break
	instance["mods"] = mods
	Store.upsert_instance(instance)
	Notify.push("Мод удалён", filename, "info")
	refresh()

func _update_all() -> void:
	var instance := _current()
	if instance.is_empty():
		return
	if String(instance.get("loader", "vanilla")) == "vanilla":
		Notify.push("Vanilla без модов", "Обновлять нечего", "warn")
		return
	_status_label.text = "Проверяю обновления..."
	var updates := await Mods.updates_for(instance)
	if updates.is_empty():
		_status_label.text = "Все моды актуальны"
		Notify.push("Обновления не найдены", "Все установленные моды актуальны", "ok")
		return
	var done := 0
	for entry in updates:
		var mod: Dictionary = entry.get("mod", {})
		var latest: Dictionary = entry.get("latest", {})
		var result := await Mods.update_mod(instance, mod, latest)
		if bool(result.get("ok", false)):
			done += 1
	_status_label.text = "Обновлено модов: %d из %d" % [done, updates.size()]
	Notify.push("Обновление завершено", "Обновлено %d из %d" % [done, updates.size()], "ok")
	refresh()

func on_instance_changed() -> void:
	refresh()
