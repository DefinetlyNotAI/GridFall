extends Node3D

var game
var geometry: Node3D
var structures: Dictionary = {}
var fixed_nodes: Dictionary = {}
var materials: Dictionary = {}
var effects: Array = []
var bolts: Array = []
var numbers: Array = []
var core: Node3D
var sun: DirectionalLight3D
var atmosphere: WorldEnvironment
var effects_rng = RandomNumberGenerator.new()
var rain: CPUParticles3D
var weather = "Clear"
var lightning_timer = 0.0
var post: ColorRect
var impacts: Array = []
var floor_normal: NoiseTexture2D
var enemy_meshes: Dictionary = {}
var enemy_material: StandardMaterial3D

func material(color: Color, emission: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var key = str(color) + str(emission) + str(metal)
	if materials.has(key):
		return materials[key]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mat.metallic = metal
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	if color.a < 1:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materials[key] = mat
	return mat

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color, glow, 0.35)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = CylinderMesh.new()
	shape.top_radius = radius * 0.85
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 8
	mesh.mesh = shape
	mesh.material_override = material(color, glow, 0.6)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func collision(parent: CollisionObject3D, size: Vector3, offset: Vector3) -> void:
	var shape = CollisionShape3D.new()
	var rect = BoxShape3D.new()
	rect.size = size
	shape.shape = rect
	shape.position = offset
	parent.add_child(shape)

func setup(owner_game) -> void:
	game = owner_game
	effects_rng.randomize()
	floor_normal = NoiseTexture2D.new()
	floor_normal.width = 128
	floor_normal.height = 128
	floor_normal.seamless = true
	floor_normal.as_normal_map = true
	floor_normal.bump_strength = 0.25
	var noise = FastNoiseLite.new()
	noise.seed = 937
	noise.frequency = 0.12
	floor_normal.noise = noise
	atmosphere = WorldEnvironment.new()
	atmosphere.environment = Environment.new()
	atmosphere.environment.background_mode = Environment.BG_COLOR
	atmosphere.environment.background_color = Color("101c29")
	atmosphere.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.environment.ambient_light_color = Color("7193ac")
	atmosphere.environment.ambient_light_energy = 0.65
	atmosphere.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	atmosphere.environment.fog_enabled = true
	atmosphere.environment.fog_light_color = Color("243747")
	atmosphere.environment.fog_density = 0.006
	add_child(atmosphere)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("b9d6e4")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("0e1c35")
	sky_material.sky_horizon_color = Color("567788")
	sky_material.ground_bottom_color = Color("101c29")
	sky_material.ground_horizon_color = Color("567788")
	sky.sky_material = sky_material
	atmosphere.environment.sky = sky
	atmosphere.environment.background_mode = Environment.BG_SKY
	atmosphere.environment.fog_height = 0
	atmosphere.environment.fog_height_density = 0.08
	var layer = CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	post = ColorRect.new()
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen_material = ShaderMaterial.new()
	screen_material.shader = preload("res://scripts/display.gdshader")
	post.material = screen_material
	layer.add_child(post)
	rain = CPUParticles3D.new()
	rain.emitting = false
	rain.amount = 160
	rain.lifetime = 1.2
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(12, 1, 12)
	rain.direction = Vector3(0.15, -1, 0)
	rain.spread = 4
	rain.initial_velocity_min = 16
	rain.initial_velocity_max = 21
	rain.gravity = Vector3(0, -4, 0)
	var drop_mesh = BoxMesh.new()
	drop_mesh.size = Vector3(0.025, 0.45, 0.025)
	rain.mesh = drop_mesh
	rain.material_override = material(Color("88c6de"), 0.3)
	add_child(rain)
	for i in 96:
		var mesh = box(self, Vector3.ZERO, Vector3(0.025, 0.025, 1), Color("ffce7a"), 2)
		mesh.visible = false
		effects.append({"mesh": mesh, "life": 0.0})

func world_fog_density() -> float:
	var density = game.world.rule("fog_density")
	return maxf(0.025, density) if game.event_name == "Heavy fog" else density

func world_sun_energy() -> float:
	var energy = game.world.rule("sun_energy")
	return minf(0.25, energy) if game.event_name == "Blackout" else energy

func apply_render_settings() -> void:
	if not is_instance_valid(post): return
	var settings = game.profile.data.settings
	post.visible = int(settings.visual_mode) > 0
	post.material.set_shader_parameter("display_mode", int(settings.visual_mode))
	atmosphere.environment.fog_density = world_fog_density()
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		atmosphere.environment.ssr_enabled = settings.advanced_lighting
		atmosphere.environment.ssao_enabled = settings.advanced_lighting
		atmosphere.environment.volumetric_fog_enabled = settings.advanced_lighting
		atmosphere.environment.volumetric_fog_density = world_fog_density()
	rain.amount = 64 if settings.quality == 0 else 160
	rain.emitting = settings.weather and weather != "Clear" and game.state == "wave"
	if not settings.weather or weather != "Thunderstorm": sun.light_energy = world_sun_energy()

func set_weather(event: String, number: int) -> void:
	weather = "Acid rain" if event == "Acid rain" else ("Thunderstorm" if number % 19 == 0 else ("Rain" if number % 8 == 3 else "Clear"))
	lightning_timer = 3
	rain.material_override = material(Color("a9d16d") if weather == "Acid rain" else Color("88c6de"), 0.3)
	apply_render_settings()

func clear_weather() -> void:
	weather = "Clear"
	if rain: rain.emitting = false

func rebuild() -> void:
	if is_instance_valid(geometry):
		remove_child(geometry)
		geometry.queue_free()
	geometry = Node3D.new()
	add_child(geometry)
	structures.clear()
	fixed_nodes.clear()
	var world = game.world
	var w = int(world.map.width)
	var h = int(world.map.height)
	apply_render_settings()
	var floor_body = StaticBody3D.new()
	geometry.add_child(floor_body)
	for y in h:
		var start = -1
		for x in range(w + 1):
			var present = x < w and world.map.layers.ground.has(world.cell_key(Vector2i(x, y)))
			if present and start < 0: start = x
			if not present and start >= 0:
				collision(floor_body, Vector3((x - start) * 3, 0.4, 3), Vector3((start + x) * 1.5, -0.2, (y + 0.5) * 3))
				start = -1
	var terrain_colors = {"concrete": Color("303e48"), "grass": Color("344c3d"), "dirt": Color("5b4d40"), "sand": Color("8c7d56"), "road": Color("202d35"), "metal": Color("344a55"), "stone": Color("4f5358"), "water": Color("174b65")}
	for terrain in terrain_colors:
		var cells: Array = []
		for key in world.map.layers.ground:
			if world.map.layers.ground[key].type == terrain:
				cells.append(world.point(key))
		if cells.is_empty():
			continue
		var multi = MultiMeshInstance3D.new()
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var mesh = BoxMesh.new()
		mesh.size = Vector3(2.96, 0.15, 2.96)
		mm.mesh = mesh
		mm.instance_count = cells.size()
		for i in cells.size():
			mm.set_instance_transform(i, Transform3D(Basis(), world.position(cells[i], -0.075)))
		multi.multimesh = mm
		multi.material_override = material(terrain_colors[terrain])
		multi.material_override.normal_enabled = true
		multi.material_override.normal_texture = floor_normal
		multi.material_override.normal_scale = 0.2
		geometry.add_child(multi)
	for key in world.map.layers.structure:
		fixed_tile(key)
	for key in world.construction:
		structure(key)
	for key in world.map.layers.markers:
		var marker = world.map.layers.markers[key]
		var pos = world.position(world.point(key))
		if marker.type == "objective":
			core = StaticBody3D.new()
			core.set_meta("core", true)
			core.position = pos
			geometry.add_child(core)
			collision(core, Vector3(2.2, 2.8, 2.2), Vector3(0, 1.4, 0))
			cylinder(core, Vector3(0, 0.2, 0), 1.45, 0.4, Color("15222b"))
			cylinder(core, Vector3(0, 1.4, 0), 0.65, 2.4, Color("50e3ce"), 1.4)
			for x in [-1, 1]:
				for z in [-1, 1]:
					box(core, Vector3(x * 0.85, 1.25, z * 0.85), Vector3(0.3, 2.5, 0.3), Color("203746"))
			var light = OmniLight3D.new()
			light.position.y = 3
			light.light_color = Color("50e3ce")
			light.omni_range = 12
			light.light_energy = 2
			core.add_child(light)
		elif marker.type == "enemy":
			cylinder(geometry, pos + Vector3(0, 0.04, 0), 1.25, 0.08, Color("e46e54"), 0.8)
			for i in [-1, 1]:
				box(geometry, pos + Vector3(i * 1.2, 1.8, 0), Vector3(0.2, 3.6, 0.3), Color("9c5549"), 0.3)
		elif marker.type in ["pad", "tower_pad", "structure_pad"]:
			cylinder(geometry, pos + Vector3.UP * 0.025, 1.1, 0.05, Color("3c827d"), 0.15)
	var interactive = world.interactive_tiles()
	for key in interactive:
		var tile = interactive[key]
		var pos = world.position(world.point(key), float(tile.get("elevation", 0)))
		if tile.type in world.HAZARDS:
			var hazard_color = {"fire": Color("ff8245"), "acid": Color("9fcd61"), "spikes": Color("a1b4c0"), "electric": Color("6fbefa"), "slow": Color("89d9ea"), "mine": Color("e89c68")}.get(tile.type, Color.WHITE)
			cylinder(geometry, pos + Vector3.UP * 0.04, 1.3, 0.08, hazard_color, 0.5)
			for i in 4:
				box(geometry, pos + Vector3((i % 2 - 0.5) * 1.2, 0.2, (i / 2 - 0.5) * 1.2), Vector3(0.15, 0.4, 0.15), hazard_color, 0.3)
			continue
		var object_body = StaticBody3D.new()
		object_body.position = pos
		object_body.rotation_degrees.y = float(tile.get("rotation", 0))
		object_body.set_meta("station", tile.type)
		geometry.add_child(object_body)
		collision(object_body, Vector3(1.4, 1.3, 1.2), Vector3(0, 0.65, 0))
		box(object_body, Vector3(0, 0.55, 0), Vector3(1.4, 1.1, 1.2), Color("243e4c"))
		box(object_body, Vector3(0, 1.15, 0), Vector3(1, 0.2, 0.7), Color("f4bd69") if tile.type == "shop" else Color("50d9ce"), 0.8)
	for key in world.map.layers.decoration:
		var tile = world.map.layers.decoration[key]
		var pos = world.position(world.point(key), float(tile.get("elevation", 0)))
		if tile.type == "vegetation":
			cylinder(geometry, pos + Vector3.UP * 0.6, 0.7, 1.2, Color("4e7660"))
		elif tile.type in ["pipe", "light"]:
			cylinder(geometry, pos + Vector3.UP, 0.2, 2, Color("6c8896"), 0.4 if tile.type == "light" else 0)
		else:
			box(geometry, pos + Vector3.UP * 0.5, Vector3(1.3, 1, 1.3), Color("52616b"))
	for key in world.map.layers.lighting:
		var tile: Dictionary = world.map.layers.lighting[key]
		var light = OmniLight3D.new()
		light.position = world.position(world.point(key), float(tile.get("elevation", 3)))
		light.light_color = Color(tile.get("color", "8acdd6"))
		light.omni_range = float(tile.get("range", 10))
		light.light_energy = float(tile.get("energy", 1.5))
		geometry.add_child(light)
	for key in world.map.layers.height:
		var tile = world.map.layers.height[key]
		var elevation = float(tile.get("elevation", 3.5))
		var pos = world.position(world.point(key), elevation)
		var ceiling = StaticBody3D.new()
		ceiling.position = pos
		geometry.add_child(ceiling)
		box(ceiling, Vector3.ZERO, Vector3(3, 0.25, 3), Color("384b59"))
		collision(ceiling, Vector3(3, 0.25, 3), Vector3.ZERO)
	for x in range(3, w - 2, 6):
		for y in [1, h - 2]:
			var p = world.position(Vector2i(x, y))
			box(geometry, p + Vector3(0, 2.5, 0), Vector3(0.14, 5, 0.14), Color("425460"))
			box(geometry, p + Vector3(0, 5, 0), Vector3(1.2, 0.16, 0.35), Color("ffd799"), 1)

func fixed_tile(key: String) -> void:
	var tile = game.world.map.layers.structure[key]
	var definition = game.world.WALL_DEFS[tile.type]
	var body = StaticBody3D.new()
	body.position = game.world.position(game.world.point(key))
	body.set_meta("tile", key)
	geometry.add_child(body)
	fixed_nodes[key] = body
	var height = float(tile.get("height", definition.height))
	body.position.y = float(tile.get("elevation", 0))
	body.rotation_degrees.y = float(tile.get("rotation", 0))
	var color = Color(definition.color)
	if tile.type in ["ramp", "stairs"]:
		for i in 6:
			var step_height = (i + 1) / 6.0 * minf(1.4, height)
			box(body, Vector3(0, step_height * 0.5, -1.25 + i * 0.5), Vector3(3, step_height, 0.5), color)
		var slope_shape = ConvexPolygonShape3D.new()
		slope_shape.points = PackedVector3Array([Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5), Vector3(-1.5, minf(1.4, height), 1.5), Vector3(1.5, minf(1.4, height), 1.5)])
		var slope = CollisionShape3D.new()
		slope.shape = slope_shape
		body.add_child(slope)
	elif tile.type == "window":
		box(body, Vector3(0, 0.4, 0), Vector3(3, 0.8, 0.3), color)
		collision(body, Vector3(3, 0.8, 0.3), Vector3(0, 0.4, 0))
		box(body, Vector3(0, height - 0.25, 0), Vector3(3, 0.5, 0.3), color)
		collision(body, Vector3(3, 0.5, 0.3), Vector3(0, height - 0.25, 0))
		for side in [-1, 1]:
			box(body, Vector3(side * 1.3, height * 0.5, 0), Vector3(0.4, height, 0.3), color)
			collision(body, Vector3(0.4, height, 0.3), Vector3(side * 1.3, height * 0.5, 0))
	else:
		if tile.type == "platform": height = minf(0.5, height)
		box(body, Vector3(0, height * 0.5, 0), Vector3(3, height, 3), color)
		collision(body, Vector3(3, height, 3), Vector3(0, height * 0.5, 0))
	box(body, Vector3(0, height - 0.16, -1.51), Vector3(2.7, 0.08, 0.03), Color("6796a0"), 0.2)

func remove_fixed(key: String) -> void:
	if fixed_nodes.has(key) and is_instance_valid(fixed_nodes[key]):
		geometry.remove_child(fixed_nodes[key])
		fixed_nodes[key].queue_free()
	fixed_nodes.erase(key)

func structure(key: String) -> void:
	if structures.has(key) and is_instance_valid(structures[key]):
		geometry.remove_child(structures[key])
		structures[key].queue_free()
	structures.erase(key)
	if not game.world.construction.has(key):
		return
	var data = game.world.construction[key]
	var body = StaticBody3D.new()
	body.set_meta("structure", key)
	body.position = game.world.position(game.world.point(key))
	body.rotation_degrees.y = float(data.get("rotation", 0))
	geometry.add_child(body)
	structures[key] = body
	var color = Color(data.color)
	if data.kind == "wall":
		collision(body, Vector3(2.8, 2.2, 2.8), Vector3(0, 1.1, 0))
		box(body, Vector3(0, 1.1, 0), Vector3(2.8, 2.2, 2.8), Color("4b5b64"))
		box(body, Vector3(0, 2.22, 0), Vector3(2.7, 0.1, 2.7), color)
	elif data.kind == "trap":
		cylinder(body, Vector3(0, 0.1, 0), 1.2, 0.2, color, 0.5)
	else:
		collision(body, Vector3(1.6, 1.9, 1.6), Vector3(0, 0.95, 0))
		cylinder(body, Vector3(0, 0.25, 0), 1.15, 0.5, Color("1e303b"))
		cylinder(body, Vector3(0, 0.9, 0), 0.5, 1, Color("4d6570"))
		var head = Node3D.new()
		head.name = "Head"
		head.position.y = 1.8
		body.add_child(head)
		box(head, Vector3.ZERO, Vector3(1.2, 0.65, 1.0), color)
		if data.kind == "tower":
			box(head, Vector3(0, 0.05, -0.85), Vector3(0.22, 0.22, 1.3), Color("a1bac4"))
			box(head, Vector3(0, 0.05, -1.52), Vector3(0.24, 0.24, 0.08), color, 2)
		else:
			cylinder(head, Vector3(0, 0.6, 0), 0.3, 1.0, color, 1)

func enemy(data: Dictionary) -> CharacterBody3D:
	var body = CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	body.set_meta("enemy", data.uid)
	add_child(body)
	var scale_value = 1.8 if data.type == "boss" else (1.25 if data.type == "tank" else 1.0)
	var color = Color(data.color)
	collision(body, Vector3(0.85, 1.7, 0.85) * scale_value, Vector3(0, 0.85 * scale_value, 0))
	var model = Node3D.new()
	model.name = "Model"
	model.scale = Vector3.ONE * scale_value
	body.add_child(model)
	var mesh = MeshInstance3D.new()
	mesh.mesh = enemy_mesh(data.type, color)
	if enemy_material == null:
		enemy_material = StandardMaterial3D.new()
		enemy_material.vertex_color_use_as_albedo = true
		enemy_material.roughness = 0.72
		enemy_material.metallic = 0.35
	mesh.material_override = enemy_material
	model.add_child(mesh)
	if data.type == "boss":
		for side in [-1, 1]:
			cylinder(model, Vector3(side * 0.8, 1.65, 0), 0.25, 0.8, Color("ff8b4a"), 1)
	return body

func enemy_mesh(kind: String, color: Color) -> ArrayMesh:
	var key = kind + str(color)
	if enemy_meshes.has(key): return enemy_meshes[key]
	var parts = [
		[Vector3(0, 0.95, 0), Vector3(0.9, 0.85, 0.65), color],
		[Vector3(0, 1.6, -0.05), Vector3(0.65, 0.5, 0.65), color.darkened(0.2)],
		[Vector3(0, 1.64, -0.39), Vector3(0.5, 0.12, 0.05), Color("ffbf80")]
	]
	for side in [-1, 1]:
		parts.append([Vector3(side * 0.25, 0.3, 0), Vector3(0.25, 0.6, 0.3), Color("24323d")])
		parts.append([Vector3(side * 0.65, 0.95, -0.08), Vector3(0.25, 0.8, 0.3), color.darkened(0.25)])
	if kind in ["shielded", "tank"]: parts.append([Vector3(0, 1.0, -0.5), Vector3(1.1, 1.0, 0.15), Color("526a79")])
	var cube = BoxMesh.new()
	cube.size = Vector3.ONE
	var arrays = cube.surface_get_arrays(0)
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		for index in arrays[Mesh.ARRAY_INDEX]:
			builder.set_color(part[2])
			builder.set_normal(arrays[Mesh.ARRAY_NORMAL][index])
			builder.set_uv(arrays[Mesh.ARRAY_TEX_UV][index])
			builder.add_vertex(arrays[Mesh.ARRAY_VERTEX][index] * part[1] + part[0])
	builder.index()
	var result = builder.commit()
	enemy_meshes[key] = result
	return result

func beam(from: Vector3, to: Vector3, color: Color = Color("ffc980"), width: float = 0.035, lifetime: float = 0.1) -> void:
	if from.distance_squared_to(to) < 0.001:
		return
	for effect in effects:
		if effect.life > 0:
			continue
		effect.life = lifetime
		var mesh: MeshInstance3D = effect.mesh
		mesh.visible = true
		mesh.material_override = material(color, 2)
		mesh.position = (from + to) * 0.5
		mesh.scale = Vector3(width / 0.025, width / 0.025, from.distance_to(to))
		mesh.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
		return

func burst(pos: Vector3, color: Color, count: int = 8, radius: float = 0.8) -> void:
	for i in mini(count, 4 if game.profile.data.settings.quality == 0 else 16):
		var direction = Vector3(effects_rng.randf_range(-1, 1), effects_rng.randf_range(-0.3, 1), effects_rng.randf_range(-1, 1)).normalized()
		beam(pos, pos + direction * radius, color, 0.05, 0.15)

func obtain_bolt(pos: Vector3, color: Color) -> MeshInstance3D:
	var result: MeshInstance3D
	for bolt in bolts:
		if not bolt.visible:
			result = bolt
			break
	if result == null:
		result = box(self, pos, Vector3(0.15, 0.15, 0.4), color, 2)
		bolts.append(result)
	result.position = pos
	result.material_override = material(color, 2)
	result.visible = true
	return result

func release_bolt(mesh: MeshInstance3D) -> void:
	mesh.visible = false

func impact(pos: Vector3, normal: Vector3, body: Node3D) -> void:
	if DisplayServer.get_name() == "headless" or game.profile.data.settings.quality == 0: return
	var entry: Dictionary = {}
	for mark in impacts:
		if mark.life <= 0:
			entry = mark
			break
	if entry.is_empty():
		if impacts.size() >= 48: return
		var mesh = MeshInstance3D.new()
		var quad = QuadMesh.new()
		quad.size = Vector2(0.16, 0.16)
		mesh.mesh = quad
		var ink = ShaderMaterial.new()
		ink.shader = preload("res://scripts/impact.gdshader")
		mesh.material_override = ink
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		entry = {"node": mesh, "life": 0.0}
		impacts.append(entry)
	entry.life = 12.0
	entry.anchor = weakref(body)
	entry.point = body.to_local(pos + normal * 0.015)
	entry.node.position = pos + normal * 0.015
	entry.node.look_at(entry.node.position + normal, Vector3.RIGHT if absf(normal.y) > 0.99 else Vector3.UP)
	entry.node.visible = true

func damage_number(pos: Vector3, amount: float) -> void:
	if DisplayServer.get_name() == "headless": return
	var entry: Dictionary = {}
	for number in numbers:
		if number.life <= 0:
			entry = number
			break
	if entry.is_empty():
		if numbers.size() >= 32: return
		var text = Label3D.new()
		text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text.font_size = 48
		text.pixel_size = 0.007
		text.no_depth_test = false
		text.modulate = Color("ffdb97")
		add_child(text)
		entry = {"node": text, "life": 0.0}
		numbers.append(entry)
	entry.life = 0.65
	entry.node.position = pos
	entry.node.text = str(int(ceil(amount)))
	entry.node.visible = true

func _process(delta: float) -> void:
	if game != null and game.state == "paused":
		rain.speed_scale = 0
		return
	rain.speed_scale = 1
	rain.emitting = game.profile.data.settings.weather and weather != "Clear" and game.state == "wave"
	if is_instance_valid(game.player):
		rain.position = game.player.position + Vector3.UP * 13
	if weather == "Thunderstorm" and game.state == "wave" and game.profile.data.settings.weather:
		lightning_timer -= delta
		var baseline = world_sun_energy()
		sun.light_energy = minf(4.0, baseline * (4.0 / 1.5)) if lightning_timer < 0.15 else baseline * (0.8 / 1.5)
		if lightning_timer <= 0:
			game.audio.cue("explosion", rain.position, 0.25)
			lightning_timer = effects_rng.randf_range(5, 9)
	for mark in impacts:
		if mark.life <= 0: continue
		mark.life -= delta
		var anchor = mark.anchor.get_ref()
		if not is_instance_valid(anchor) or not anchor.is_inside_tree(): mark.life = 0
		else: mark.node.position = anchor.to_global(mark.point)
		mark.node.visible = mark.life > 0
	for number in numbers:
		if number.life > 0:
			number.life -= delta
			number.node.position.y += delta * 0.7
			number.node.visible = number.life > 0
	for effect in effects:
		if effect.life > 0:
			effect.life -= delta
			if effect.life <= 0:
				effect.mesh.visible = false
