class_name AuroraBackground
extends ColorRect
## Анимированный фон: аврора, шум, звёзды и виньетка (шейдер canvas_item).

const SHADER := """
shader_type canvas_item;

uniform vec4 tint_a : source_color = vec4(0.016, 0.024, 0.058, 1.0);
uniform vec4 tint_b : source_color = vec4(0.055, 0.043, 0.125, 1.0);
uniform vec4 accent : source_color = vec4(0.13, 0.83, 0.93, 1.0);
uniform float time_scale = 1.0;
uniform float intensity = 1.0;
uniform float reduce_motion = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}
void fragment() {
	float speed = 1.0 - reduce_motion * 0.92;
	float t = TIME * speed * time_scale;
	vec2 uv = UV;
	float n = fbm(uv * 3.0 + vec2(t * 0.05, -t * 0.035));
	float n2 = fbm(uv * 2.0 - vec2(t * 0.04, t * 0.06) + n * 0.85);
	vec3 col = mix(tint_a.rgb, tint_b.rgb, smoothstep(0.12, 0.95, n2));
	float ribbon = exp(-pow((uv.y - (0.34 + 0.16 * sin(uv.x * 3.1 + t * 0.35))) * 3.2, 2.0));
	float ribbon2 = exp(-pow((uv.y - (0.68 + 0.12 * sin(uv.x * 2.3 - t * 0.28))) * 3.6, 2.0));
	col += accent.rgb * (ribbon * 0.11 + ribbon2 * 0.07) * intensity * (0.6 + 0.4 * n);
	vec2 g = floor(uv * vec2(720.0, 420.0));
	float s = step(0.9988, hash(g));
	col += vec3(s) * (0.45 + 0.55 * sin(t * 2.5 + hash(g) * 40.0)) * 0.32 * intensity;
	col *= 1.0 - 0.62 * pow(length((uv - 0.5) * vec2(1.15, 1.0)) * 1.28, 2.0);
	COLOR = vec4(col, 1.0);
}
"""

var intensity := 1.0:
	set(v):
		intensity = v
		_apply()
var accent := Color(0.13, 0.83, 0.93):
	set(v):
		accent = v
		_apply()
var reduce_motion := false:
	set(v):
		reduce_motion = v
		_apply()

var _material: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color(0.02, 0.03, 0.06)
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material
	_apply()

func _apply() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("intensity", intensity)
	_material.set_shader_parameter("accent", accent)
	_material.set_shader_parameter("reduce_motion", 1.0 if reduce_motion else 0.0)
