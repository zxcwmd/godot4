class_name ShaderSurface
extends Control
## Поверхность со шейдером: скруглённый прямоугольник со стеклянной заливкой,
## градиентом, тонкой обводкой и внешним свечением. Основа всей графики лаунчера.

const SHADER_CODE := """
shader_type canvas_item;

uniform vec4 fill_a : source_color = vec4(0.055, 0.075, 0.145, 0.86);
uniform vec4 fill_b : source_color = vec4(0.10, 0.12, 0.23, 0.62);
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.10);
uniform vec4 glow_color : source_color = vec4(0.13, 0.83, 0.93, 0.55);
uniform float radius = 18.0;
uniform float border_width = 1.0;
uniform float glow = 0.0;
uniform float hover = 0.0;
uniform float press = 0.0;
uniform float vertical = 1.0;
uniform vec2 box_size = vec2(200.0, 100.0);

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * box_size;
	vec2 half_box = box_size * 0.5;
	float r = min(radius, min(half_box.x, half_box.y));
	float d = sd_round_box(p, half_box, r);
	float aa = 1.3;
	float inside = 1.0 - smoothstep(-aa, 0.0, d);
	float t = mix(UV.x, UV.y, vertical);
	vec4 fill = mix(fill_a, fill_b, t);
	vec3 col = fill.rgb;
	float alpha = fill.a * inside;
	float ring = (1.0 - smoothstep(-border_width - aa, -border_width + aa, abs(d))) * inside;
	col = mix(col, border_color.rgb, ring * border_color.a);
	alpha = max(alpha, ring * border_color.a);
	float g = exp(-max(d, 0.0) / 30.0) * glow * (0.55 + 0.45 * hover);
	alpha = max(alpha, g * glow_color.a);
	col = mix(glow_color.rgb, col, clamp(alpha, 0.0, 1.0));
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
"""

var fill_a: Color = Color(0.055, 0.075, 0.145, 0.86)
var fill_b: Color = Color(0.10, 0.12, 0.23, 0.62)
var border_color: Color = Color(1, 1, 1, 0.10)
var glow_color: Color = Color(0.13, 0.83, 0.93, 0.55)
var radius := 18.0
var border_width := 1.0
var glow := 0.0
var vertical := 1.0

var _material: ShaderMaterial

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = false
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material
	_push_all()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _material != null:
			_material.set_shader_parameter("box_size", size)

func _push_all() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("fill_a", fill_a)
	_material.set_shader_parameter("fill_b", fill_b)
	_material.set_shader_parameter("border_color", border_color)
	_material.set_shader_parameter("glow_color", glow_color)
	_material.set_shader_parameter("radius", radius)
	_material.set_shader_parameter("border_width", border_width)
	_material.set_shader_parameter("glow", glow)
	_material.set_shader_parameter("vertical", vertical)
	_material.set_shader_parameter("box_size", size)

func set_fill(a: Color, b: Color) -> void:
	fill_a = a
	fill_b = b
	_material.set_shader_parameter("fill_a", a)
	_material.set_shader_parameter("fill_b", b)

func set_border(color: Color, width: float) -> void:
	border_color = color
	border_width = width
	_material.set_shader_parameter("border_color", color)
	_material.set_shader_parameter("border_width", width)

func set_radius(value: float) -> void:
	radius = value
	_material.set_shader_parameter("radius", value)

func set_glow(color: Color, strength: float) -> void:
	glow_color = color
	glow = strength
	_material.set_shader_parameter("glow_color", color)
	_material.set_shader_parameter("glow", strength)

func set_gradient_direction(v: float) -> void:
	vertical = v
	_material.set_shader_parameter("vertical", v)

func set_hover(value: float) -> void:
	_material.set_shader_parameter("hover", clampf(value, 0.0, 1.0))

func set_press(value: float) -> void:
	_material.set_shader_parameter("press", clampf(value, 0.0, 1.0))

## Плавная анимация параметра шейдера.
func tween_uniform(uniform: String, to: float, duration := 0.18) -> void:
	if not is_inside_tree():
		_material.set_shader_parameter(uniform, to)
		return
	var tw := create_tween()
	tw.tween_method(func(v): _material.set_shader_parameter(uniform, v), _material.get_shader_parameter(uniform), to, duration)
