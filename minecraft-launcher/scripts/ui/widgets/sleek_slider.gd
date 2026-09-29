class_name SleekSlider
extends Control
## Современный ползунок: тонкий трек, градиентная заливка, светящийся ползунок.

var value := 0.5:
	set(v):
		var next := clampf(v, min_value, max_value)
		if step > 0.0:
			next = round(next / step) * step
		value = clampf(next, min_value, max_value)
		queue_redraw()
var min_value := 0.0
var max_value := 1.0
var step := 0.0
var fill_a := Color(0.13, 0.83, 0.93)
var fill_b := Color(0.66, 0.33, 0.97)
var track_color := Color(1, 1, 1, 0.10)

signal value_changed(v: float)
signal drag_ended(v: float)

var _dragging := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(180, 26)

func set_range(min_v: float, max_v: float, step_v := 0.0) -> void:
	min_value = min_v
	max_value = max_v
	step = step_v
	value = value

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_update_from(event.position.x)
				accept_event()
			else:
				if _dragging:
					drag_ended.emit(value)
				_dragging = false
	elif event is InputEventMouseMotion:
		if _dragging:
			_update_from(event.position.x)
			accept_event()

func _update_from(x: float) -> void:
	var width := size.x
	if width <= 1.0:
		return
	var ratio := clampf(x / width, 0.0, 1.0)
	var next := min_value + (max_value - min_value) * ratio
	if absf(next - value) > 0.0001:
		value = next
		value_changed.emit(value)
	queue_redraw()

func _ratio() -> float:
	if max_value <= min_value:
		return 0.0
	return clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)

func _draw() -> void:
	var height := 6.0
	var y := size.y * 0.5 - height * 0.5
	var radius := height * 0.5
	draw_circle(Vector2(radius, y + radius), radius, track_color)
	if size.x > radius * 2.0:
		draw_rect(Rect2(radius, y, size.x - radius * 2.0, height), track_color, true)
	draw_circle(Vector2(size.x - radius, y + radius), radius, track_color)

	var ratio := _ratio()
	var fx := maxf(radius, size.x * ratio)
	draw_circle(Vector2(radius, y + radius), radius, fill_a)
	if fx > radius:
		draw_rect(Rect2(radius, y, fx - radius, height), fill_a.lerp(fill_b, 0.65), true)
	draw_circle(Vector2(fx, y + radius), radius, fill_b)

	var knob_x := clampf(fx, radius, maxf(radius, size.x - radius))
	draw_circle(Vector2(knob_x, y + radius), 10.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2(knob_x, y + radius), 8.0, Color(1, 1, 1))
