class_name ProgressRing
extends Control
## Круговой индикатор с градиентной дугой и подписью в центре.

var value := 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var track_color := Color(1, 1, 1, 0.08)
var fill_a := Color(0.13, 0.83, 0.93)
var fill_b := Color(0.66, 0.33, 0.97)
var thickness := 7.0
var caption := "":
	set(v):
		caption = v
		_queue_label()
var subcaption := "":
	set(v):
		subcaption = v
		_queue_label()

var _anim := 0.0
var _label: Label
var _sub: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	_label = Kit.label("", 17, Color(1, 1, 1))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub = Kit.label("", 10, Constants.C_TEXT_MUTED)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	box.add_child(_sub)
	add_child(box)
	Kit.full_rect(box)
	_queue_label()

func _process(delta: float) -> void:
	if absf(_anim - value) > 0.0005:
		_anim = lerpf(_anim, value, clampf(delta * 9.0, 0.0, 1.0))
		queue_redraw()
		_queue_label()

func _queue_label() -> void:
	if _label == null:
		return
	var pct := int(round(_anim * 100.0))
	_label.text = caption if caption != "" else ("%d%%" % pct)
	_sub.text = subcaption

func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 4.0:
		return
	var center := size * 0.5
	var radius := s * 0.5 - thickness * 0.5 - 2.0
	if radius <= 1.0:
		return
	draw_arc(center, radius, 0.0, TAU, 96, track_color, thickness, true)
	if _anim <= 0.001:
		return
	var steps := maxi(4, int(96 * _anim))
	var start := -PI * 0.5
	for i in range(steps):
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var color := fill_a.lerp(fill_b, t0)
		draw_arc(center, radius, start + TAU * t0, start + TAU * t1 + 0.012, 3, color, thickness, true)
