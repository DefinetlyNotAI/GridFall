shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int display_mode = 1;
void fragment() {
	vec2 uv = SCREEN_UV;
	if (display_mode == 1) uv = floor(uv * vec2(480.0, 300.0)) / vec2(480.0, 300.0);
	vec3 scene = texture(screen_texture, uv).rgb;
	if (display_mode == 1) scene = floor(scene * 24.0) / 24.0;
	else scene = clamp((scene - vec3(0.3)) * 1.35 + vec3(0.4), vec3(0.0), vec3(1.0));
	COLOR = vec4(scene, 1.0);
}
