class_name ConsoleView
extends RichTextLabel
## Консоль с BBCode-подсветкой уровней, автоскроллом и ограничением длины.

var autoscroll := true
var max_paragraphs := 400
var font_size := 12.0

func _ready() -> void:
	bbcode_enabled = true
	fit_content = false
	scroll_active = false
	selection_enabled = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_font_size_override("normal_font_size", int(font_size))
	add_theme_color_override("default_color", Constants.C_TEXT_MUTED)
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())

func add_line(text: String, level := "info") -> void:
	var color := _color_for(level)
	var stamp := Time.get_time_string_from_system()
	append_text("[color=#%s]%s[/color]  [color=#%s]%s[/color]\n" % [
		color.to_html(false), _escape(text), Constants.C_TEXT_DIM.to_html(false), stamp
	])
	_trim()
	if autoscroll:
		scroll_to_line(maxi(0, get_line_count() - 1))

func clear_all() -> void:
	clear()
	scroll_to_line(0)

func _trim() -> void:
	var count := get_paragraph_count()
	if count <= max_paragraphs:
		return
	var remove := count - max_paragraphs
	for i in range(remove):
		remove_paragraph(0)

func _color_for(level: String) -> Color:
	match level:
		"ok": return Constants.C_OK
		"success": return Constants.C_OK
		"warn": return Constants.C_WARN
		"error": return Constants.C_ERR
		"game": return Constants.C_INFO
		"aurora": return Color(0.66, 0.33, 0.97)
	return Constants.C_TEXT_MUTED

func _escape(text: String) -> String:
	return text.replace("[", "(").replace("]", ")")
