class_name ThemeBuilder
extends RefCounted
## Сборка темы и общих визуальных примитивов (стекло, градиенты, тени).

const GLASS_A := Color(0.055, 0.075, 0.145, 0.86)
const GLASS_B := Color(0.10, 0.12, 0.23, 0.62)
const GLASS_BORDER := Color(1.0, 1.0, 1.0, 0.10)
const CARD_A := Color(0.07, 0.09, 0.17, 0.78)
const CARD_B := Color(0.12, 0.14, 0.26, 0.52)
const SHADOW := Color(0.0, 0.0, 0.0, 0.45)

static func build(accent_a: Color, accent_b: Color) -> Theme:
	var t := Theme.new()
	t.default_font_size = 15

	# ------------------------------------------------------------- Label ----
	t.set_color("font_color", "Label", Constants.C_TEXT)
	t.set_font_size("font_size", "Label", 14)
	t.set_color("font_color", "RichTextLabel", Constants.C_TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 13)

	# ------------------------------------------------------------ Button ----
	var normal := _flat(Color(0.10, 0.12, 0.22, 0.72), 14, GLASS_BORDER, 1, 6)
	var hover := _flat(Color(0.14, 0.17, 0.30, 0.86), 14, Color(1, 1, 1, 0.20), 1, 10)
	var pressed := _flat(Color(0.07, 0.09, 0.17, 0.92), 14, accent_a, 1, 4)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", _flat(Color(0.08, 0.09, 0.15, 0.5), 14, Color(1, 1, 1, 0.05), 1, 0))
	t.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), 14, accent_a, 2, 0))
	t.set_color("font_color", "Button", Constants.C_TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Constants.C_TEXT)
	t.set_color("font_disabled_color", "Button", Constants.C_TEXT_DIM)
	t.set_constant("h_separation", "Button", 8)

	# ----------------------------------------------------- PanelContainer --
	t.set_stylebox("panel", "PanelContainer", _flat(Color(0, 0, 0, 0), 16, Color(0, 0, 0, 0), 0, 0))

	# ---------------------------------------------------------- LineEdit ---
	t.set_stylebox("normal", "LineEdit", _flat(Color(0.05, 0.07, 0.14, 0.85), 12, Color(1, 1, 1, 0.10), 1, 0))
	t.set_stylebox("focus", "LineEdit", _flat(Color(0.06, 0.09, 0.17, 0.95), 12, accent_a, 2, 0))
	t.set_stylebox("read_only", "LineEdit", _flat(Color(0.05, 0.07, 0.14, 0.6), 12, Color(1, 1, 1, 0.06), 1, 0))
	t.set_color("font_color", "LineEdit", Constants.C_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Constants.C_TEXT_DIM)
	t.set_color("caret_color", "LineEdit", accent_a)
	t.set_color("selection_color", "LineEdit", Color(accent_a.r, accent_a.g, accent_a.b, 0.35))
	t.set_font_size("font_size", "LineEdit", 14)

	# ------------------------------------------------------- OptionButton --
	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	t.set_stylebox("disabled", "OptionButton", _flat(Color(0.08, 0.09, 0.15, 0.5), 14, Color(1, 1, 1, 0.05), 1, 0))
	t.set_color("font_color", "OptionButton", Constants.C_TEXT)
	t.set_color("font_hover_color", "OptionButton", Color(1, 1, 1))
	t.set_color("font_pressed_color", "OptionButton", Constants.C_TEXT)
	t.set_color("font_disabled_color", "OptionButton", Constants.C_TEXT_DIM)
	t.set_stylebox("panel", "PopupMenu", _flat(Color(0.06, 0.08, 0.16, 0.98), 12, GLASS_BORDER, 1, 20))
	t.set_color("font_color", "PopupMenu", Constants.C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 1, 1))
	t.set_stylebox("hover", "PopupMenu", _flat(Color(1, 1, 1, 0.10), 8, Color(0, 0, 0, 0), 0, 0))

	# ------------------------------------------------------ ScrollContainer -
	t.set_stylebox("panel", "ScrollContainer", _flat(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("grabber", "VScrollBar", _flat(Color(1, 1, 1, 0.16), 6, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", _flat(accent_a, 6, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("grabber", "HScrollBar", _flat(Color(1, 1, 1, 0.16), 6, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("grabber_highlight", "HScrollBar", _flat(accent_a, 6, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("scroll", "VScrollBar", _flat(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("scroll", "HScrollBar", _flat(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 0))

	# -------------------------------------------------------- ProgressBar ---
	t.set_stylebox("background", "ProgressBar", _flat(Color(1, 1, 1, 0.08), 8, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("fill", "ProgressBar", _flat(accent_a, 8, Color(0, 0, 0, 0), 0, 0))
	t.set_color("font_color", "ProgressBar", Constants.C_TEXT)

	# ----------------------------------------------------------- Tooltip ----
	t.set_stylebox("panel", "TooltipPanel", _flat(Color(0.05, 0.07, 0.14, 0.96), 8, GLASS_BORDER, 1, 12))
	t.set_color("font_color", "TooltipLabel", Constants.C_TEXT)
	t.set_font_size("font_size", "TooltipLabel", 12)

	# ------------------------------------------------------------- Window ---
	t.set_color("title_color", "Window", Constants.C_TEXT)
	t.set_stylebox("embedded_border", "Window", _flat(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 0))
	return t

static func _flat(bg: Color, radius: int, border_color: Color, border_width: int, shadow: int, shadow_color := SHADOW) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_width > 0:
		sb.border_color = border_color
		sb.set_border_width_all(border_width)
	if shadow > 0:
		sb.shadow_color = shadow_color
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb

## Прозрачная "пустая" рамка — чтобы стандартный вид не протекал в кастомные кнопки.
static func empty_stylebox() -> StyleBoxFlat:
	return _flat(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 0)

static func gradient(a: Color, b: Color, vertical := false, width := 256, height := 64) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0.0, a)
	g.set_color(1.0, b)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = width
	tex.height = height
	if vertical:
		tex.fill_from = Vector2(0.5, 0.0)
		tex.fill_to = Vector2(0.5, 1.0)
	else:
		tex.fill_from = Vector2(0.0, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
	return tex

static func glass_surface() -> StyleBoxFlat:
	return _flat(GLASS_A, 20, GLASS_BORDER, 1, 26)

static func card_surface() -> StyleBoxFlat:
	return _flat(CARD_A, 18, Color(1, 1, 1, 0.07), 1, 18)
