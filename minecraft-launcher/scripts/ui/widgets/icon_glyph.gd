class_name IconGlyph
extends Control
## Векторные иконки, рисуемые средствами CanvasItem.
## Не зависит от наличия иконочных шрифтов в системе.

const NAMES := [
	"home", "layers", "pick", "flask", "hook", "sprout", "flame", "apple", "clock",
	"bolt", "robot", "box", "gear", "play", "stop", "check", "warn", "close",
	"search", "download", "refresh", "user", "trash", "plus", "folder", "chart",
	"server", "sparkle", "shield", "exit", "coffee", "arrow_right"
]

var icon := "home":
	set(value):
		icon = value
		queue_redraw()
var glyph_color := Color(0.9, 0.93, 1.0):
	set(value):
		glyph_color = value
		queue_redraw()
var thickness := 2.0
var filled := false:
	set(value):
		filled = value
		queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var c := glyph_color
	var s := minf(size.x, size.y)
	var t := maxf(1.5, thickness * (s / 24.0))
	var m := s * 0.5
	var center := Vector2(m, m)
	# центрируем иконку в прямоугольнике кнопки
	draw_set_transform(Vector2((size.x - s) * 0.5, (size.y - s) * 0.5))

	match icon:
		"home":
			_line(Vector2(m * 0.4, m * 0.9), Vector2(m * 1.1, m * 0.25), t, c)
			_line(Vector2(m * 1.1, m * 0.25), Vector2(m * 1.8, m * 0.9), t, c)
			_line(Vector2(m * 0.7, m * 0.68), Vector2(m * 1.5, m * 0.68), t, c)
			_line(Vector2(m * 0.7, m * 0.68), Vector2(m * 0.7, m * 1.6), t, c)
			_line(Vector2(m * 1.5, m * 0.68), Vector2(m * 1.5, m * 1.6), t, c)
			_line(Vector2(m * 0.7, m * 1.6), Vector2(m * 1.5, m * 1.6), t, c)
		"layers":
			for i in range(3):
				var y := m * (0.55 + i * 0.42)
				_line(Vector2(m * 0.5, y - m * 0.3), Vector2(m * 1.75, y), t, c)
				_line(Vector2(m * 1.75, y), Vector2(m * 0.5, y + m * 0.3), t, c)
				_line(Vector2(m * 0.5, y + m * 0.3), Vector2(m * 0.15, y), t, c)
				_line(Vector2(m * 0.15, y), Vector2(m * 0.5, y - m * 0.3), t, c)
		"pick":
			_line(Vector2(m * 0.45, m * 1.7), Vector2(m * 1.5, m * 0.65), t, c)
			_polyline([Vector2(m * 1.25, m * 0.5), Vector2(m * 1.75, m * 0.45), Vector2(m * 1.85, m * 0.95), Vector2(m * 1.45, m * 1.15)], t, c)
		"flask":
			_line(Vector2(m * 0.85, m * 0.3), Vector2(m * 0.85, m * 0.95), t, c)
			_line(Vector2(m * 1.35, m * 0.3), Vector2(m * 1.35, m * 0.95), t, c)
			_polyline([Vector2(m * 0.85, m * 0.95), Vector2(m * 0.45, m * 1.65), Vector2(m * 1.75, m * 1.65), Vector2(m * 1.35, m * 0.95)], t, c)
			if filled:
				_polygon([Vector2(m * 0.62, m * 1.5), Vector2(m * 1.58, m * 1.5), Vector2(m * 1.75, m * 1.65), Vector2(m * 0.45, m * 1.65)], c)
			_line(Vector2(m * 0.7, m * 0.3), Vector2(m * 1.5, m * 0.3), t, c)
		"hook":
			_line(Vector2(m * 1.1, m * 0.3), Vector2(m * 1.1, m * 1.05), t, c)
			draw_arc(center + Vector2(0, m * 0.35), m * 0.55, 0.0, TAU, 32, c, t, true)
			_line(Vector2(center.x + m * 0.55, center.y + m * 0.35), Vector2(center.x + m * 0.95, center.y + m * 0.35), t, c)
			_line(Vector2(center.x + m * 0.95, center.y + m * 0.35), Vector2(center.x + m * 0.95, center.y + m * 0.05), t, c)
		"sprout":
			_line(Vector2(m * 1.1, m * 1.7), Vector2(m * 1.1, m * 0.9), t, c)
			_polyline([Vector2(m * 1.1, m * 1.15), Vector2(m * 0.5, m * 0.75), Vector2(m * 0.35, m * 1.0), Vector2(m * 1.1, m * 1.3)], t, c)
			_polyline([Vector2(m * 1.1, m * 1.0), Vector2(m * 1.7, m * 0.6), Vector2(m * 1.85, m * 0.85), Vector2(m * 1.1, m * 1.2)], t, c)
		"flame":
			_polyline([Vector2(m * 1.1, m * 0.25), Vector2(m * 0.55, m * 0.85), Vector2(m * 0.8, m * 0.95), Vector2(m * 0.65, m * 1.6), Vector2(m * 1.55, m * 1.05), Vector2(m * 1.25, m * 0.95), Vector2(m * 1.45, m * 0.25)], t, c)
			if filled:
				_polygon([Vector2(m * 1.1, m * 0.6), Vector2(m * 0.8, m * 1.05), Vector2(m * 0.95, m * 1.1), Vector2(m * 0.9, m * 1.4), Vector2(m * 1.3, m * 1.05), Vector2(m * 1.2, m * 1.0), Vector2(m * 1.25, m * 0.6)], c)
		"apple":
			_line(Vector2(m * 1.1, m * 0.35), Vector2(m * 1.1, m * 0.7), t, c)
			_polyline([Vector2(m * 0.5, m * 0.8), Vector2(m * 0.35, m * 1.3), Vector2(m * 0.7, m * 1.7), Vector2(m * 1.5, m * 1.7), Vector2(m * 1.85, m * 1.3), Vector2(m * 1.7, m * 0.8), Vector2(m * 1.1, m * 0.7)], t, c)
		"clock":
			draw_arc(center, m * 0.75, 0.0, TAU, 40, c, t, true)
			_line(center, center + Vector2(0, -m * 0.45), t, c)
			_line(center, center + Vector2(m * 0.35, m * 0.15), t, c)
		"bolt":
			_polygon([Vector2(m * 1.35, m * 0.2), Vector2(m * 0.6, m * 1.05), Vector2(m * 1.0, m * 1.05), Vector2(m * 0.8, m * 1.8), Vector2(m * 1.6, m * 0.85), Vector2(m * 1.2, m * 0.85), Vector2(m * 1.45, m * 0.2)], c)
		"robot":
			draw_rect(Rect2(m * 0.4, m * 0.65, m * 1.4, m * 1.05), c, false, t)
			draw_circle(Vector2(m * 0.8, m * 1.1), m * 0.09, c)
			draw_circle(Vector2(m * 1.4, m * 1.1), m * 0.09, c)
			_line(Vector2(m * 1.1, m * 0.65), Vector2(m * 1.1, m * 0.4), t, c)
			draw_circle(Vector2(m * 1.1, m * 0.32), m * 0.07, c)
			_line(Vector2(m * 0.4, m * 0.95), Vector2(m * 0.15, m * 0.8), t, c)
			_line(Vector2(m * 1.8, m * 0.95), Vector2(m * 2.05, m * 0.8), t, c)
		"box":
			draw_rect(Rect2(m * 0.4, m * 0.7, m * 1.4, m * 1.0), c, false, t)
			_line(Vector2(m * 0.4, m * 0.7), Vector2(m * 0.65, m * 0.45), t, c)
			_line(Vector2(m * 0.65, m * 0.45), Vector2(m * 2.05, m * 0.45), t, c)
			_line(Vector2(m * 2.05, m * 0.45), Vector2(m * 1.8, m * 0.7), t, c)
			_line(Vector2(m * 2.05, m * 0.45), Vector2(m * 2.05, m * 1.45), t, c)
			_line(Vector2(m * 2.05, m * 1.45), Vector2(m * 1.8, m * 1.7), t, c)
			_line(Vector2(m * 0.65, m * 0.45), Vector2(m * 0.65, m * 1.45), t, c)
		"gear":
			draw_arc(center, m * 0.5, 0.0, TAU, 36, c, t, true)
			draw_arc(center, m * 0.18, 0.0, TAU, 20, c, t, true)
			for i in range(8):
				var a := TAU * float(i) / 8.0
				_line(center + Vector2(cos(a), sin(a)) * m * 0.58, center + Vector2(cos(a), sin(a)) * m * 0.85, t, c)
		"play":
			_polygon([Vector2(m * 0.75, m * 0.45), Vector2(m * 1.75, m * 1.1), Vector2(m * 0.75, m * 1.75)], c)
		"stop":
			draw_rect(Rect2(m * 0.55, m * 0.55, m * 1.1, m * 1.1), c, true)
		"check":
			_polyline([Vector2(m * 0.45, m * 1.1), Vector2(m * 0.95, m * 1.6), Vector2(m * 1.8, m * 0.55)], t, c)
		"warn":
			_polyline([Vector2(m * 1.1, m * 0.35), Vector2(m * 1.95, m * 1.65), Vector2(m * 0.25, m * 1.65), Vector2(m * 1.1, m * 0.35)], t, c)
			draw_circle(center + Vector2(0, m * 0.55), m * 0.08, c)
			_line(center + Vector2(0, m * 0.8), center + Vector2(0, m * 1.15), t, c)
		"close":
			_line(Vector2(m * 0.6, m * 0.6), Vector2(m * 1.6, m * 1.6), t, c)
			_line(Vector2(m * 1.6, m * 0.6), Vector2(m * 0.6, m * 1.6), t, c)
		"search":
			draw_arc(center + Vector2(-m * 0.1, -m * 0.1), m * 0.55, 0.0, TAU, 28, c, t, true)
			_line(center + Vector2(m * 0.35, m * 0.35), center + Vector2(m * 0.85, m * 0.85), t, c)
		"download":
			_line(Vector2(m * 1.1, m * 0.35), Vector2(m * 1.1, m * 1.25), t, c)
			_polyline([Vector2(m * 0.7, m * 0.9), Vector2(m * 1.1, m * 1.3), Vector2(m * 1.5, m * 0.9)], t, c)
			_polyline([Vector2(m * 0.45, m * 1.6), Vector2(m * 1.75, m * 1.6)], t, c)
		"refresh":
			draw_arc(center, m * 0.7, 0.5, TAU - 0.7, 28, c, t, true)
			_polyline([Vector2(center.x + m * 0.72, center.y - m * 0.45), Vector2(center.x + m * 0.78, center.y - m * 0.05), Vector2(center.x + m * 0.35, center.y - m * 0.1)], t, c)
		"user":
			draw_arc(center + Vector2(0, -m * 0.25), m * 0.38, 0.0, TAU, 24, c, t, true)
			_polyline([Vector2(m * 0.5, m * 1.7), Vector2(m * 0.65, m * 1.2), Vector2(m * 1.55, m * 1.2), Vector2(m * 1.7, m * 1.7)], t, c)
		"trash":
			_line(Vector2(m * 0.55, m * 0.6), Vector2(m * 1.65, m * 0.6), t, c)
			_polyline([Vector2(m * 0.7, m * 0.6), Vector2(m * 0.85, m * 1.7), Vector2(m * 1.35, m * 1.7), Vector2(m * 1.5, m * 0.6)], t, c)
			_line(Vector2(m * 0.9, m * 0.4), Vector2(m * 1.3, m * 0.4), t, c)
		"plus":
			_line(Vector2(m * 1.1, m * 0.5), Vector2(m * 1.1, m * 1.7), t, c)
			_line(Vector2(m * 0.5, m * 1.1), Vector2(m * 1.7, m * 1.1), t, c)
		"folder":
			_polyline([Vector2(m * 0.4, m * 0.7), Vector2(m * 0.4, m * 1.6), Vector2(m * 1.8, m * 1.6), Vector2(m * 1.8, m * 0.9), Vector2(m * 1.05, m * 0.9), Vector2(m * 0.85, m * 0.7), Vector2(m * 0.4, m * 0.7)], t, c)
		"chart":
			for i in range(3):
				var h := m * (0.5 + 0.45 * float(i))
				draw_rect(Rect2(m * (0.5 + float(i) * 0.45), m * 1.8 - h, m * 0.3, h), c, true)
		"server":
			draw_rect(Rect2(m * 0.45, m * 0.45, m * 1.3, m * 0.55), c, false, t)
			draw_rect(Rect2(m * 0.45, m * 1.15, m * 1.3, m * 0.55), c, false, t)
			draw_circle(Vector2(m * 0.7, m * 0.72), m * 0.07, c)
			draw_circle(Vector2(m * 0.7, m * 1.42), m * 0.07, c)
		"sparkle":
			_polygon([Vector2(m * 1.1, m * 0.3), Vector2(m * 1.3, m * 0.9), Vector2(m * 1.9, m * 1.1), Vector2(m * 1.3, m * 1.3), Vector2(m * 1.1, m * 1.9), Vector2(m * 0.9, m * 1.3), Vector2(m * 0.3, m * 1.1), Vector2(m * 0.9, m * 0.9)], c)
		"shield":
			_polyline([Vector2(m * 1.1, m * 0.35), Vector2(m * 1.75, m * 0.6), Vector2(m * 1.7, m * 1.3), Vector2(m * 1.1, m * 1.7), Vector2(m * 0.5, m * 1.3), Vector2(m * 0.45, m * 0.6), Vector2(m * 1.1, m * 0.35)], t, c)
		"exit":
			_polyline([Vector2(m * 0.5, m * 0.55), Vector2(m * 1.5, m * 0.55), Vector2(m * 1.5, m * 1.65), Vector2(m * 0.5, m * 1.65), Vector2(m * 0.5, m * 0.55)], t, c)
			_line(Vector2(m * 1.0, m * 0.8), Vector2(m * 1.75, m * 1.1), t, c)
			_polyline([Vector2(m * 1.5, m * 0.8), Vector2(m * 1.85, m * 1.1), Vector2(m * 1.5, m * 1.4)], t, c)
		"coffee":
			draw_rect(Rect2(m * 0.6, m * 0.7, m * 1.0, m * 0.9), c, false, t)
			_polyline([Vector2(m * 0.6, m * 0.7), Vector2(m * 0.75, m * 1.6), Vector2(m * 1.45, m * 1.6), Vector2(m * 1.6, m * 0.7)], t, c)
			_polyline([Vector2(m * 0.9, m * 0.5), Vector2(m * 1.05, m * 0.28)], t, c)
			_polyline([Vector2(m * 1.3, m * 0.5), Vector2(m * 1.45, m * 0.28)], t, c)
		"arrow_right":
			_line(Vector2(m * 0.5, m * 1.1), Vector2(m * 1.7, m * 1.1), t, c)
			_polyline([Vector2(m * 1.3, m * 0.7), Vector2(m * 1.75, m * 1.1), Vector2(m * 1.3, m * 1.5)], t, c)
		_:
			draw_arc(center, m * 0.7, 0.0, TAU, 24, c, t, true)

func _line(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, color, width, true)

func _polyline(points: Array, width: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(p)
	draw_polyline(pts, color, width, true)

func _polygon(points: Array, color: Color) -> void:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(p)
	draw_colored_polygon(pts, color)
