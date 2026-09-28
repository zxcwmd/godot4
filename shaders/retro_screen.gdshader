shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size = 2.0;
void fragment() {
 vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
 vec2 uv = (floor(SCREEN_UV * resolution / pixel_size) + 0.5) * pixel_size / resolution;
 vec3 color = texture(screen_texture, uv).rgb;
 float ordered = fract(dot(mod(FRAGCOORD.xy, 4.0), vec2(0.25, 0.625)));
 color = floor(color * 32.0 + ordered * 0.45) / 32.0;
 vec2 v = SCREEN_UV - vec2(0.5);
 color *= 1.0 - dot(v, v) * 0.42;
 COLOR = vec4(color, 1.0);
}
