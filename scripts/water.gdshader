shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 water_position;

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	water_position = world_position;
	if (NORMAL.y > 0.5) {
		float phase_a = world_position.x * 1.7 + world_position.z * 0.8 + TIME * 1.1;
		float phase_b = world_position.z * 1.5 - world_position.x * 0.6 - TIME * 0.85;
		VERTEX.y += (sin(phase_a) + sin(phase_b)) * 0.012;
		float slope_x = cos(phase_a) * 0.025 - cos(phase_b) * 0.009;
		float slope_z = cos(phase_a) * 0.012 + cos(phase_b) * 0.023;
		NORMAL = normalize(vec3(-slope_x, 1.0, -slope_z));
	}
}

void fragment() {
	float bands = sin(water_position.x * 2.4 + water_position.z * 1.2 + TIME * 1.3)
		+ sin(water_position.z * 2.0 - water_position.x * 0.7 - TIME * 0.9);
	float glint = smoothstep(0.85, 1.65, bands);
	ALBEDO = mix(vec3(0.035, 0.17, 0.23), vec3(0.12, 0.38, 0.43), glint * 0.62);
	METALLIC = 0.18;
	ROUGHNESS = mix(0.32, 0.2, glint);
	SPECULAR = 0.8;
}
