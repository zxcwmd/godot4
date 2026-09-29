class_name ToastLayer
extends CanvasLayer
## Всплывающие уведомления в правом верхнем углу.

var _list: VBoxContainer

func _ready() -> void:
	layer = 128
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.set_anchor(SIDE_LEFT, 1.0)
	_list.set_anchor(SIDE_RIGHT, 1.0)
	_list.set_anchor(SIDE_TOP, 0.0)
	_list.set_anchor(SIDE_BOTTOM, 1.0)
	_list.offset_left = -400.0
	_list.offset_right = -22.0
	_list.offset_top = 22.0
	_list.add_theme_constant_override("separation", 10)
	root.add_child(_list)
	Bus.notified.connect(_on_notified)

func _on_notified(title: String, body: String, level: String) -> void:
	if _list == null:
		return
	var card := _build_card(title, body, level)
	_list.add_child(card)
	card.modulate = Color(1, 1, 1, 0)
	card.scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dismiss_later(card, 4.5)

func _dismiss_later(card: Control, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(card):
		return
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 0.0, 0.28)
	await tw.finished
	if is_instance_valid(card):
		card.queue_free()

func _build_card(title: String, body: String, level: String) -> Control:
	var accent := Constants.C_INFO
	match level:
		"ok": accent = Constants.C_OK
		"warn": accent = Constants.C_WARN
		"error": accent = Constants.C_ERR
	var icon := "sparkle"
	match level:
		"ok": icon = "check"
		"warn": icon = "warn"
		"error": icon = "warn"
	var panel := ShaderSurface.new()
	panel.set_radius(16.0)
	panel.set_fill(Color(0.06, 0.08, 0.16, 0.94), Color(0.10, 0.12, 0.23, 0.88))
	panel.set_border(Color(1, 1, 1, 0.12), 1.0)
	panel.set_glow(accent, 0.35)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_theme_constant_override("margin_left", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(3, 34)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)

	var glyph := IconGlyph.new()
	glyph.icon = icon
	glyph.glyph_color = accent
	glyph.custom_minimum_size = Vector2(20, 20)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 2)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(Kit.label(title, 13, Color(1, 1, 1)))
	if body != "":
		text_box.add_child(Kit.label(body, 11, Constants.C_TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	row.add_child(text_box)

	margin.add_child(row)
	panel.add_child(margin)
	panel.custom_minimum_size = Vector2(340, 0)
	return panel
