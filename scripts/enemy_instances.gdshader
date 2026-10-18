shader_type spatial;
render_mode world_vertex_coords;

uniform float simulation_time = 0.0;

void vertex() {
	float age = simulation_time - INSTANCE_CUSTOM.z;
	if (age < -4.0) {
		age += 8.0;
	}
	VERTEX.xz += INSTANCE_CUSTOM.xy * clamp(age, 0.0, 0.10);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.72;
	METALLIC = 0.35;
}
