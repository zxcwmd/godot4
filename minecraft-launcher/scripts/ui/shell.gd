class_name Shell
extends Control
## Каркас окна: боковое меню, верхняя панель и область страниц.

const PAGES := [
	{"id": "home", "title": "Главная", "subtitle": "Быстрый старт, статус и обзор", "icon": "home"},
	{"id": "instances", "title": "Экземпляры", "subtitle": "Сборки, версии и загрузчики модов", "icon": "layers"},
	{"id": "automation", "title": "Автоматизация", "subtitle": "Автошахта, автоварка зелий, автоферма и не только", "icon": "robot"},
	{"id": "mods", "title": "Моды", "subtitle": "Каталог Modrinth и обновления", "icon": "box"},
	{"id": "settings", "title": "Настройки", "subtitle": "Java, память, оформление и аккаунт", "icon": "gear"},
]

const SIDEBAR_WIDTH := 252.0
const TOPBAR_HEIGHT := 78.0

signal page_changed(page_id: String)

var body: Control
var title_label: Label
var subtitle_label: Label
var status_label: Label
var instance_select: Select
var account_chip: Control

var _nav_buttons := {}
var _pages := {}
var _pages_host: Control
var _current := ""
var _accent_a := Color(0.13, 0.83, 0.93)
var _accent_b := Color(0.66, 0.33, 0.97)
var _node_status: Label

func _ready() -> void:
	var colors := Constants.accent_colors(String(Store.setting("accent", "aurora")))
	_accent_a = colors["a"]
	_accent_b = colors["b"]
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_sidebar()
	_build_content()

func register_page(id: String, page: Control) -> void:
	if _pages_host == null:
		return
	_pages[id] = page
	_pages_host.add_child(page)
	Kit.full_rect(page)
	page.visible = false

func show_page(id: String) -> void:
	if not _pages.has(id):
		return
	for key in _nav_buttons.keys():
		_nav_buttons[key].active = (key == id)
	var page: Control = _pages[id]
	for child in _pages_host.get_children():
		child.visible = false
	page.visible = true
	if not bool(Store.setting("reduce_motion", false)):
		page.modulate = Color(1, 1, 1, 0)
		page.position = Vector2(0, 14)
		var tw := create_tween()
		tw.tween_property(page, "modulate:a", 1.0, 0.18)
		tw.parallel().tween_property(page, "position", Vector2(0, 0), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_current = id
	for meta in PAGES:
		if String(meta["id"]) == id:
			title_label.text = String(meta["title"])
			subtitle_label.text = String(meta["subtitle"])
			break
	page_changed.emit(id)

func current_page() -> String:
	return _current

# ------------------------------------------------------------------ сборка ---
func _build_sidebar() -> void:
	var sidebar := Control.new()
	sidebar.set_anchor(SIDE_RIGHT, 0.0)
	sidebar.set_anchor(SIDE_BOTTOM, 1.0)
	sidebar.offset_right = SIDEBAR_WIDTH
	sidebar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(sidebar)

	var panel := ShaderSurface.new()
	panel.set_radius(0.0)
	panel.set_fill(Color(0.035, 0.05, 0.10, 0.92), Color(0.06, 0.08, 0.16, 0.82))
	panel.set_border(Color(1, 1, 1, 0.06), 1.0)
	panel.set_gradient_direction(1.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sidebar.add_child(panel)
	Kit.full_rect(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_left", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(box)
	sidebar.add_child(margin)

	# --- логотип
	var logo := HBoxContainer.new()
	logo.add_theme_constant_override("separation", 12)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := ShaderSurface.new()
	mark.set_radius(14.0)
	mark.set_fill(_accent_a, _accent_b)
	mark.set_glow(_accent_a, 0.55)
	mark.custom_minimum_size = Vector2(44, 44)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark_margin := MarginContainer.new()
	mark_margin.add_theme_constant_override("margin_top", 11)
	mark_margin.add_theme_constant_override("margin_left", 11)
	mark_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := IconGlyph.new()
	glyph.icon = "sparkle"
	glyph.glyph_color = Color(0.03, 0.05, 0.10)
	glyph.custom_minimum_size = Vector2(22, 22)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark_margin.add_child(glyph)
	mark.add_child(mark_margin)
	logo.add_child(mark)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(Kit.label("AURORA", 17, Color(1, 1, 1)))
	names.add_child(Kit.label("лаунчер " + Constants.APP_VERSION, 10, Constants.C_TEXT_DIM))
	logo.add_child(names)
	box.add_child(logo)

	box.add_child(Kit.spacer(22))

	# --- навигация
	for meta in PAGES:
		var button := AccentButton.make(String(meta["title"]), "nav", String(meta["icon"]))
		button.fill_a = _accent_a
		button.fill_b = _accent_b
		button.left_aligned = true
		button.custom_minimum_size = Vector2(0, 44)
		button.corner = 13.0
		button.pressed.connect(func(): show_page(String(meta["id"])))
		_nav_buttons[String(meta["id"])] = button
		box.add_child(button)

	box.add_child(Kit.spacer(0))
	var expander := Control.new()
	expander.size_flags_vertical = Control.SIZE_EXPAND_FILL
	expander.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(expander)

	# --- статус Node.js
	var node_box := HBoxContainer.new()
	node_box.add_theme_constant_override("separation", 8)
	node_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var node_icon := IconGlyph.new()
	node_icon.icon = "robot"
	node_icon.glyph_color = Constants.C_TEXT_MUTED
	node_icon.custom_minimum_size = Vector2(16, 16)
	node_box.add_child(node_icon)
	_node_status = Kit.label("Проверяю Node.js...", 11, Constants.C_TEXT_MUTED)
	_node_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node_box.add_child(_node_status)
	box.add_child(node_box)
	box.add_child(Kit.spacer(10))

	var data_button := AccentButton.make("Папка данных", "ghost", "folder")
	data_button.left_aligned = true
	data_button.custom_minimum_size = Vector2(0, 36)
	data_button.corner = 11.0
	data_button.pressed.connect(_open_data_dir)
	box.add_child(data_button)

func _build_content() -> void:
	var content := Control.new()
	content.set_anchor(SIDE_LEFT, 0.0)
	content.set_anchor(SIDE_RIGHT, 1.0)
	content.set_anchor(SIDE_BOTTOM, 1.0)
	content.offset_left = SIDEBAR_WIDTH
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(content)

	var topbar := Control.new()
	topbar.set_anchor(SIDE_RIGHT, 1.0)
	topbar.set_anchor(SIDE_BOTTOM, 0.0)
	topbar.offset_bottom = TOPBAR_HEIGHT
	topbar.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(topbar)

	var bar := ShaderSurface.new()
	bar.set_radius(0.0)
	bar.set_fill(Color(0.04, 0.055, 0.11, 0.72), Color(0.06, 0.08, 0.15, 0.55))
	bar.set_border(Color(1, 1, 1, 0.06), 1.0)
	bar.set_gradient_direction(0.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topbar.add_child(bar)
	Kit.full_rect(bar)

	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_top", 16)
	bar_margin.add_theme_constant_override("margin_right", 22)
	bar_margin.add_theme_constant_override("margin_bottom", 16)
	bar_margin.add_theme_constant_override("margin_left", 24)
	bar_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	bar_margin.add_child(row)
	topbar.add_child(bar_margin)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label = Kit.label("Главная", 21, Color(1, 1, 1))
	subtitle_label = Kit.label("", 12, Constants.C_TEXT_MUTED)
	titles.add_child(title_label)
	titles.add_child(subtitle_label)
	row.add_child(titles)

	status_label = Kit.label("", 12, Constants.C_TEXT_MUTED)
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status_label)

	instance_select = Select.make([], 0, false)
	instance_select.custom_minimum_size = Vector2(230, 38)
	instance_select.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	instance_select.selected.connect(_on_instance_selected)
	row.add_child(instance_select)

	account_chip = _build_account_chip()
	row.add_child(account_chip)

	var pages := Control.new()
	pages.set_anchor(SIDE_RIGHT, 1.0)
	pages.set_anchor(SIDE_BOTTOM, 1.0)
	pages.offset_top = TOPBAR_HEIGHT
	pages.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(pages)
	_pages_host = pages
	body = pages

func _build_account_chip() -> Control:
	var chip := ShaderSurface.new()
	chip.set_radius(19.0)
	chip.set_fill(Color(0.06, 0.08, 0.15, 0.8), Color(0.10, 0.12, 0.22, 0.6))
	chip.set_border(Color(1, 1, 1, 0.10), 1.0)
	chip.custom_minimum_size = Vector2(180, 38)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.add_theme_constant_override("margin_left", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar := ShaderSurface.new()
	avatar.set_radius(15.0)
	avatar.set_fill(_accent_a, _accent_b)
	avatar.custom_minimum_size = Vector2(26, 26)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar_margin := MarginContainer.new()
	avatar_margin.add_theme_constant_override("margin_top", 6)
	avatar_margin.add_theme_constant_override("margin_left", 7)
	avatar_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar_glyph := IconGlyph.new()
	avatar_glyph.icon = "user"
	avatar_glyph.glyph_color = Color(0.03, 0.05, 0.10)
	avatar_glyph.custom_minimum_size = Vector2(13, 13)
	avatar_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_margin.add_child(avatar_glyph)
	avatar.add_child(avatar_margin)
	row.add_child(avatar)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Kit.label("Player", 12, Color(1, 1, 1))
	var type_label := Kit.label("оффлайн-режим", 10, Constants.C_TEXT_DIM)
	account_chip.set_meta("name_label", name_label)
	account_chip.set_meta("type_label", type_label)
	texts.add_child(name_label)
	texts.add_child(type_label)
	row.add_child(texts)
	margin.add_child(row)
	chip.add_child(margin)
	return chip

func _on_instance_selected(index: int, value) -> void:
	Store.select_instance(String(value))

func _open_data_dir() -> void:
	Proc.open_in_file_manager(Store.data_dir())

# ---------------------------------------------------------------- обновление -
func refresh_instances() -> void:
	var options: Array = []
	var current := 0
	for i in range(Store.instances.size()):
		var inst: Dictionary = Store.instances[i]
		var label_text := String(inst.get("name", "экземпляр"))
		label_text += "  ·  " + String(inst.get("version", ""))
		if String(inst.get("loader", "vanilla")) != "vanilla":
			label_text += " / " + Constants.loader_title(String(inst.get("loader", "vanilla")))
		options.append({"value": String(inst.get("id", "")), "label": label_text})
		if String(inst.get("id", "")) == Store.selected_instance_id:
			current = i
	instance_select.set_options(options, current)

func refresh_account() -> void:
	var name_label: Label = account_chip.get_meta("name_label")
	var type_label: Label = account_chip.get_meta("type_label")
	name_label.text = String(Store.account.get("name", "Player"))
	if String(Store.account.get("type", "offline")) == "msa":
		type_label.text = "Microsoft-аккаунт"
	else:
		type_label.text = "оффлайн-режим"

func set_status(text: String) -> void:
	status_label.text = text

func set_node_status(text: String, color: Color) -> void:
	if _node_status == null:
		return
	_node_status.text = text
	_node_status.add_theme_color_override("font_color", color)

func set_accent(a: Color, b: Color) -> void:
	_accent_a = a
	_accent_b = b
	for key in _nav_buttons.keys():
		_nav_buttons[key].fill_a = a
		_nav_buttons[key].fill_b = b
		_nav_buttons[key].refresh_style()
