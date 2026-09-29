class_name Select
extends Button
## Выпадающий список с собственным оформлением.
##Popup рисуется в отдельном CanvasLayer, поэтому не обрезается скроллами.

var options: Array = []
var selected_index := 0
var searchable := false
var placeholder := "—"

signal selected(index: int, value: Variant)

var _layer: CanvasLayer
var _popup: PanelContainer
var _list: VBoxContainer
var _filter: LineEdit
var _open := false
var _frames := 0
var _value_label: Label
var _bg: ShaderSurface

func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state_name, ThemeBuilder.empty_stylebox())
	add_theme_color_override("font_color", Constants.C_TEXT)
	custom_minimum_size = Vector2(190, 38)

	_bg = ShaderSurface.new()
	_bg.show_behind_parent = true
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_radius(12.0)
	_bg.set_fill(Color(0.05, 0.07, 0.14, 0.85), Color(0.09, 0.11, 0.20, 0.7))
	_bg.set_border(Color(1, 1, 1, 0.12), 1.0)
	add_child(_bg)
	Kit.full_rect(_bg)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	_value_label = Kit.label("", 14, Constants.C_TEXT)
	_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_value_label.clip_text = true
	row.add_child(_value_label)
	var arrow := IconGlyph.new()
	arrow.icon = "download"
	arrow.glyph_color = Constants.C_TEXT_MUTED
	arrow.custom_minimum_size = Vector2(13, 13)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	add_child(row)
	Kit.full_rect(row)

	_refresh_label()
	pressed.connect(_toggle)
	tree_exiting.connect(_close_popup)
	resized.connect(func(): _bg.set_radius(12.0))

func set_options(list: Array, index := 0) -> void:
	options = list
	selected_index = clampi(index, 0, maxi(0, options.size() - 1))
	_refresh_label()

func select_index(index: int, notify := true) -> void:
	if options.is_empty():
		return
	selected_index = clampi(index, 0, options.size() - 1)
	_refresh_label()
	if notify:
		selected.emit(selected_index, selected_value())

func selected_value():
	if options.is_empty():
		return null
	var opt: Dictionary = options[selected_index]
	return opt.get("value", null)

func selected_label() -> String:
	if options.is_empty():
		return placeholder
	var opt: Dictionary = options[selected_index]
	return String(opt.get("label", placeholder))

func _refresh_label() -> void:
	if _value_label != null:
		_value_label.text = selected_label()

func _toggle() -> void:
	if disabled:
		return
	if _open:
		_close_popup()
	else:
		_open_popup()

func _open_popup() -> void:
	if options.is_empty():
		return
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 120
		get_tree().root.add_child(_layer)
	if _popup == null:
		_build_popup()
	_refresh_options()
	var rect := get_global_rect()
	var width := maxf(rect.size.x, 220.0)
	var row_height := 32.0
	var visible := mini(options.size(), 12)
	var height := 10.0 + visible * row_height + (34.0 if searchable else 0.0)
	_popup.size = Vector2(width, height)
	var pos := rect.position + Vector2(0, rect.size.y + 6)
	var viewport_size := get_viewport_rect().size
	if pos.y + height > viewport_size.y - 10:
		pos = Vector2(rect.position.x, rect.position.y - height - 6)
	if pos.x + width > viewport_size.x - 10:
		pos.x = viewport_size.x - width - 10
	_popup.global_position = pos
	_popup.visible = true
	_open = true
	_frames = 0

func _close_popup() -> void:
	if _popup != null:
		_popup.visible = false
	_open = false

func _build_popup() -> void:
	_popup = PanelContainer.new()
	_popup.add_theme_stylebox_override("panel", ThemeBuilder.glass_surface())
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.visible = false
	_popup.clip_contents = true
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.add_theme_constant_override("margin_left", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	if searchable:
		_filter = LineEdit.new()
		_filter.placeholder_text = "Поиск..."
		_filter.custom_minimum_size = Vector2(0, 30)
		_filter.text_changed.connect(_on_filter_changed)
		box.add_child(_filter)
	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_list)
	box.add_child(scroll)
	margin.add_child(box)
	_popup.add_child(margin)
	_layer.add_child(_popup)

func _on_filter_changed(_text: String) -> void:
	_refresh_options()

func _visible_options() -> Array:
	if not searchable or _filter == null or _filter.text.strip_edges() == "":
		return options
	var needle := _filter.text.to_lower()
	var out: Array = []
	for opt in options:
		if String((opt as Dictionary).get("label", "")).to_lower().contains(needle):
			out.append(opt)
	return out

func _refresh_options() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var list := _visible_options()
	for i in range(list.size()):
		var opt: Dictionary = list[i]
		var real_index := options.find(opt)
		var b := Button.new()
		b.text = String(opt.get("label", ""))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 30)
		b.add_theme_font_size_override("font_size", 13)
		b.clip_text = true
		if real_index == selected_index:
			b.add_theme_color_override("font_color", Constants.C_INFO)
		if opt.has("hint"):
			b.tooltip_text = String(opt.get("hint", ""))
		b.pressed.connect(func(): _choose(real_index))
		_list.add_child(b)

func _choose(index: int) -> void:
	_close_popup()
	select_index(index, false)
	selected.emit(selected_index, selected_value())

func _process(_delta: float) -> void:
	if not _open or _popup == null or not _popup.visible:
		return
	_frames += 1
	if _frames < 2:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse := get_global_mouse_position()
		if not get_global_rect().grow(4.0).has_point(mouse) and not _popup.get_global_rect().grow(4.0).has_point(mouse):
			_close_popup()

## Удобная фабрика: [{ "value": ..., "label": ..., "hint": ... }]
static func make(list: Array, index := 0, with_search := false) -> Select:
	var s := Select.new()
	s.options = list
	s.selected_index = clampi(index, 0, maxi(0, list.size() - 1))
	s.searchable = with_search
	return s
