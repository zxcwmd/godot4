class_name TagPicker
extends FlowContainer
## Набор переключаемых «тегов» — используется для выбора руд, зелий, культур.

var options: Array = []
var selected: Array = []

signal changed(values: Array)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	_rebuild()

func set_options(list: Array, preselected: Array) -> void:
	options = list
	selected = preselected.duplicate()
	_rebuild()

func get_selected() -> Array:
	return selected

func _toggle(value) -> void:
	if selected.has(value):
		selected.erase(value)
	else:
		selected.append(value)
	_rebuild()
	changed.emit(selected)

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	for option in options:
		var is_on := selected.has(option)
		var button := AccentButton.make(String(option), "accent" if is_on else "ghost", "")
		button.font_size = 11
		button.custom_minimum_size = Vector2(0, 28)
		button.corner = 9.0
		if is_on:
			button.text_color = Color(0.04, 0.06, 0.12)
		button.pressed.connect(func(): _toggle(option))
		add_child(button)
