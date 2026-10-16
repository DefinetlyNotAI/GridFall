shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 mark_color : source_color = vec4(0.08, 0.12, 0.15, 0.85);
void fragment() {
	float distance_from_center = length(UV - vec2(0.5));
	ALBEDO = mark_color.rgb;
	ALPHA = mark_color.a * (1.0 - smoothstep(0.25, 0.5, distance_from_center));
}
