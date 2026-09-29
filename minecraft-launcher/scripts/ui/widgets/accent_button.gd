class_name AccentButton
extends Button
## Кнопка с шейдерной подложкой: градиентная заливка, свечение, анимация наведения.
## Варианты: "accent" (градиент), "ghost" (стекло с обводкой), "danger".

var fill_a := Color(0.13, 0.83, 0.93)
var fill_b := Color(0.66, 0.33, 0.97)
var text_color := Color(0.04, 0.06, 0.12)
var variant := "accent"
var icon_name := ""
var label_text := ""
var corner := 14.0
var font_size := 15
var active := false:
	set(value):
		active = value
		if _bg != null:
			_apply_variant()
var left_aligned := false:
	set(value):
		left_aligned = value
		if _row != null:
			_row.alignment = BoxContainer.ALIGNMENT_BEGIN if value else BoxContainer.ALIGNMENT_CENTER

var _bg: ShaderSurface
var _row: HBoxContainer
var _was_disabled := false

func _ready() -> void:
	label_text = text
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state_name, ThemeBuilder.empty_stylebox())
	add_theme_color_override("font_color", text_color)
	add_theme_color_override("font_hover_color", Color(1, 1, 1))
	add_theme_color_override("font_pressed_color", text_color)
	add_theme_color_override("font_disabled_color", Constants.C_TEXT_DIM)
	add_theme_font_size_override("font_size", font_size)
	custom_minimum_size = Vector2(120, 44)
	focus_mode = Control.FOCUS_NONE

	_bg = ShaderSurface.new()
	_bg.show_behind_parent = true
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_radius(corner)
	_apply_variant()
	add_child(_bg)
	Kit.full_rect(_bg)

	if icon_name != "":
		self.text = ""
		_row = HBoxContainer.new()
		_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_row.add_theme_constant_override("separation", 8)
		var glyph := IconGlyph.new()
		glyph.icon = icon_name
		glyph.glyph_color = text_color
		glyph.custom_minimum_size = Vector2(18, 18)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(glyph)
		_row.add_child(Kit.label(label_text, 15, text_color))
		add_child(_row)
		Kit.full_rect(_row)

	mouse_entered.connect(func(): _bg.tween_uniform("hover", 1.0, 0.16))
	mouse_exited.connect(func(): _bg.tween_uniform("hover", 0.0, 0.2))
	button_down.connect(func(): _bg.tween_uniform("press", 1.0, 0.08))
	button_up.connect(func(): _bg.tween_uniform("press", 0.0, 0.12))
	_was_disabled = disabled
	_refresh_disabled()

func set_colors(a: Color, b: Color, label_col: Color) -> void:
	fill_a = a
	fill_b = b
	text_color = label_col
	if _bg != null:
		_apply_variant()

## Перерисовать подложку после изменения варианта/акцентных цветов.
func refresh_style() -> void:
	if _bg != null:
		_apply_variant()

## Меняет подпись (учитывая вариант кнопки с иконкой).
func set_label(value: String) -> void:
	text = value
	label_text = value
	if _row != null:
		for child in _row.get_children():
			if child is Label:
				child.text = value

func _apply_variant() -> void:
	match variant:
		"nav":
			if active:
				_bg.set_fill(Color(fill_a.r, fill_a.g, fill_a.b, 0.20), Color(fill_b.r, fill_b.g, fill_b.b, 0.10))
				_bg.set_border(Color(fill_a.r, fill_a.g, fill_a.b, 0.45), 1.0)
				_bg.set_glow(fill_a, 0.30)
				text_color = Color(1, 1, 1)
			else:
				_bg.set_fill(Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0))
				_bg.set_border(Color(1, 1, 1, 0.0), 0.0)
				_bg.set_glow(fill_a, 0.0)
				text_color = Constants.C_TEXT_MUTED
		"ghost":
			_bg.set_fill(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.02))
			_bg.set_border(Color(1, 1, 1, 0.16), 1.0)
			_bg.set_glow(fill_a, 0.12)
			text_color = Constants.C_TEXT
		"danger":
			_bg.set_fill(Color(0.55, 0.12, 0.20, 0.92), Color(0.42, 0.07, 0.15, 0.86))
			_bg.set_border(Color(1, 1, 1, 0.14), 1.0)
			_bg.set_glow(Constants.C_ERR, 0.30)
			text_color = Color(1, 0.92, 0.94)
		_:
			_bg.set_fill(fill_a, fill_b)
			_bg.set_border(Color(1, 1, 1, 0.22), 1.0)
			_bg.set_glow(fill_a, 0.42)
	add_theme_color_override("font_color", text_color)
	if _row != null:
		for child in _row.get_children():
			if child is Label:
				child.add_theme_color_override("font_color", text_color)
			elif child is IconGlyph:
				child.glyph_color = text_color

func _process(_delta: float) -> void:
	if disabled != _was_disabled:
		_was_disabled = disabled
		_refresh_disabled()

func _refresh_disabled() -> void:
	if _bg == null:
		return
	if disabled:
		_bg.modulate = Color(1, 1, 1, 0.45)
	else:
		_bg.modulate = Color(1, 1, 1, 1)

## Быстрая фабрика.
static func make(text_value: String, variant_name := "accent", icon := "") -> AccentButton:
	var b := AccentButton.new()
	b.text = text_value
	b.label_text = text_value
	b.variant = variant_name
	b.icon_name = icon
	return b
