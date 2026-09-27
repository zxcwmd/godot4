shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.035, 0.055, 0.08, 1.0);
uniform vec4 line_color : source_color = vec4(0.12, 0.24, 0.28, 1.0);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 g = abs(fract(world_pos.xz / 2.0 - 0.5) - 0.5) / max(fwidth(world_pos.xz / 2.0), vec2(0.001));
 float line = 1.0 - min(min(g.x, g.y), 1.0);
 ALBEDO = mix(base_color.rgb, line_color.rgb, line * 0.45);
 ROUGHNESS = 0.7;
 EMISSION = line_color.rgb * line * 0.16;
}
