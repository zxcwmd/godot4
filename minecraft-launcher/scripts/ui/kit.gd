class_name Kit
extends RefCounted
## Набор помощников для сборки интерфейса из кода.

static func full_rect(control: Control, keep_offsets := false) -> Control:
	control.set_anchors_preset(Control.PRESET_FULL_RECT, keep_offsets)
	return control

static func label(text: String, size := 14, color := Constants.C_TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func muted(text: String, size := 13) -> Label:
	return label(text, size, Constants.C_TEXT_MUTED)

static func dim(text: String, size := 12) -> Label:
	return label(text, size, Constants.C_TEXT_DIM)

static func title(text: String, size := 24) -> Label:
	return label(text, size, Color(1, 1, 1))

static func section(text: String, size := 13) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var bar := ColorRect.new()
	bar.color = Constants.C_INFO
	bar.custom_minimum_size = Vector2(3, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	row.add_child(label(text.to_upper(), size, Constants.C_TEXT_MUTED))
	return row

static func vbox(separation := 0, expand := true) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	if expand:
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box

static func hbox(separation := 0) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box

static func margin(child: Control, top := 0, right := 0, bottom := 0, left := 0) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.add_theme_constant_override("margin_left", left)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(child)
	return m

static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.add_child(child)
	return s

static func spacer(height := 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func hsep(color := Constants.C_LINE, height := 1) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Стеклянная панель со шейдером.
static func glass(radius := 20.0, fill_a := ThemeBuilder.GLASS_A, fill_b := ThemeBuilder.GLASS_B, border := ThemeBuilder.GLASS_BORDER) -> ShaderSurface:
	var s := ShaderSurface.new()
	s.set_radius(radius)
	s.set_fill(fill_a, fill_b)
	s.set_border(border, 1.0)
	return s

## Панель-карточка: стекло + мягкая внутренняя тень.
static func card(radius := 18.0) -> ShaderSurface:
	return glass(radius, ThemeBuilder.CARD_A, ThemeBuilder.CARD_B, Color(1, 1, 1, 0.07))

## Обёртка: стеклянная панель с содержимым внутри.
static func glass_box(child: Control, radius := 20.0, padding := 18) -> Control:
	var panel := glass(radius)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", padding)
	m.add_theme_constant_override("margin_right", padding)
	m.add_theme_constant_override("margin_bottom", padding)
	m.add_theme_constant_override("margin_left", padding)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(child)
	panel.add_child(m)
	return panel

## "Плитка" со значением и подписью.
static func stat_tile(caption: String, value: String, hint := "", accent := Constants.C_INFO) -> Control:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_node := glass(16, Color(0.06, 0.08, 0.15, 0.72), Color(0.10, 0.12, 0.22, 0.5), Color(1, 1, 1, 0.06))
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_top", 12)
	inner.add_theme_constant_override("margin_right", 14)
	inner.add_theme_constant_override("margin_bottom", 12)
	inner.add_theme_constant_override("margin_left", 14)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(label(caption.to_upper(), 11, Constants.C_TEXT_DIM))
	box.add_child(label(value, 20, Color(1, 1, 1)))
	if hint != "":
		box.add_child(label(hint, 11, accent))
	inner.add_child(box)
	card_node.add_child(inner)
	outer.add_child(card_node)
	return outer

## Строка настройки: подпись, подсказка и управление справа.
static func setting_row(caption: String, hint: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(label(caption, 14, Color(1, 1, 1)))
	if hint != "":
		left.add_child(muted(hint, 12))
	row.add_child(left)
	if control != null:
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(control)
	return row
