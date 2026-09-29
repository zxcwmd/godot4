class_name Chip
extends Control
## Небольшая метка-«пилюля»: текст, необязательная иконка или цветная точка.

var text := "":
	set(v):
		text = v
		if _label != null:
			_label.text = v
		_update_size()
		queue_redraw()
var chip_color := Constants.C_TEXT_MUTED
var background := Color(1, 1, 1, 0.07)
var dot := false
var icon := ""

var _label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Kit.label(text, 11, chip_color, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_label)
	Kit.full_rect(_label)
	_update_size()
	queue_redraw()

func _update_size() -> void:
	var width := 16.0
	if icon != "":
		width += 12.0
	width += float(text.length()) * 6.6
	custom_minimum_size = Vector2(width, 22.0)

func _draw() -> void:
	var height := size.y
	if height <= 2.0:
		return
	var radius := height * 0.5
	draw_circle(Vector2(radius, radius), radius, background)
	if size.x > radius * 2.0:
		draw_rect(Rect2(radius, 0.0, size.x - radius * 2.0, height), background, true)
	draw_circle(Vector2(size.x - radius, radius), radius, background)
