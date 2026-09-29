class_name ToggleSwitch
extends Control
## Переключатель с анимированным ползунком.

var pressed := false:
	set(v):
		pressed = v
		queue_redraw()
var on_color := Color(0.13, 0.83, 0.93)
var off_color := Color(1, 1, 1, 0.14)

signal toggled(value: bool)

var _anim := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(46, 26)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = not pressed
		toggled.emit(pressed)
		accept_event()

func _process(delta: float) -> void:
	var target := 1.0 if pressed else 0.0
	if absf(_anim - target) > 0.001:
		_anim = lerpf(_anim, target, clampf(delta * 12.0, 0.0, 1.0))
		queue_redraw()

func _draw() -> void:
	var height := minf(size.y, 26.0)
	var width := height * 1.75
	var y := size.y * 0.5 - height * 0.5
	var rect := Rect2(0.0, y, width, height)
	var radius := height * 0.5
	var bg := off_color.lerp(on_color, _anim)
	draw_circle(Vector2(radius, y + radius), radius, bg)
	draw_rect(Rect2(radius, y, width - radius * 2.0, height), bg, true)
	draw_circle(Vector2(width - radius, y + radius), radius, bg)
	var knob_r := height * 0.36
	var knob_x := lerpf(radius + knob_r * 0.4, width - radius - knob_r * 0.4, _anim)
	var knob_y := y + radius
	draw_circle(Vector2(knob_x, knob_y), knob_r + 2.0, Color(0, 0, 0, 0.25))
	draw_circle(Vector2(knob_x, knob_y), knob_r, Color(1, 1, 1))
