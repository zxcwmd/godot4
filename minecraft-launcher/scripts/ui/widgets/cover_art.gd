class_name CoverArt
extends Control
## Процедурная обложка сборки: градиент по хешу названия, пятна и крупная иконка.

var seed_text := "":
	set(value):
		seed_text = value
		queue_redraw()
var caption := ""
var icon := "layers"
var accent_a := Color(0.13, 0.83, 0.93)
var accent_b := Color(0.66, 0.33, 0.97)
var show_caption := true

var _glyph: IconGlyph
var _label: Label

const PALETTE := [
	[Color.html("#22d3ee"), Color.html("#6366f1")],
	[Color.html("#a855f7"), Color.html("#ec4899")],
	[Color.html("#34d399"), Color.html("#0ea5e9")],
	[Color.html("#f59e0b"), Color.html("#ef4444")],
	[Color.html("#38bdf8"), Color.html("#8b5cf6")],
	[Color.html("#f472b6"), Color.html("#818cf8")],
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_glyph = IconGlyph.new()
	_glyph.icon = icon
	_glyph.glyph_color = Color(1, 1, 1, 0.22)
	_glyph.thickness = 2.4
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.custom_minimum_size = Vector2(54, 54)
	_glyph.size = Vector2(54, 54)
	_glyph.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_glyph)
	_label = Kit.label(caption, 11, Color(1, 1, 1, 0.75))
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_label.add_theme_constant_override("outline_size", 3)
	Kit.full_rect(_label)
	_label.offset_left = 12.0
	_label.offset_right = -12.0
	_label.offset_bottom = -10.0
	add_child(_label)
	queue_redraw()

func set_icon(name: String) -> void:
	icon = name
	if _glyph != null:
		_glyph.icon = name

func set_caption(text: String) -> void:
	caption = text
	if _label != null:
		_label.text = text

func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var hash_value := abs(hash(seed_text))
	var pair: Array = PALETTE[hash_value % PALETTE.size()]
	var a: Color = pair[0]
	var b: Color = pair[1]
	var a2 := a.lerp(accent_a, 0.25)
	var b2 := b.lerp(accent_b, 0.25)
	var strips := 26
	for i in range(strips):
		var t := float(i) / float(strips - 1)
		var color := a2.lerp(b2, t)
		draw_rect(Rect2(0.0, size.y * float(i) / float(strips), size.x, size.y / float(strips) + 1.0), color, true)
	# мягкие пятна
	for i in range(3):
		var seed := hash_value / (i + 3)
		var cx := size.x * (0.2 + 0.6 * absf(sin(float(seed))))
		var cy := size.y * (0.15 + 0.7 * absf(cos(float(seed * 7))))
		var radius := minf(size.x, size.y) * (0.22 + 0.16 * absf(sin(float(seed * 3))))
		draw_circle(Vector2(cx, cy), radius, Color(1, 1, 1, 0.07))
	# сетка
	var grid_color := Color(0, 0, 0, 0.10)
	var step := 26.0
	var x := step
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
		x += step
	var y := step
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
		y += step
	# затемнение снизу для подписи
	var fade := 6
	for i in range(fade):
		var alpha := 0.28 * float(i + 1) / float(fade)
		draw_rect(Rect2(0.0, size.y - float(i + 1) * 12.0, size.x, 12.0), Color(0, 0, 0, alpha), true)
