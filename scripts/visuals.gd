extends Node3D

const EnemyRenderer = preload("res://scripts/enemy_renderer.gd")
var enemy_renderer

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
var decoration_meshes: Dictionary = {}
var enemy_material: StandardMaterial3D
var decoration_material: StandardMaterial3D
var unit_box_mesh: BoxMesh
var unit_cylinder_mesh: CylinderMesh
const FLOOR_COLOR = preload("res://assets/materials/floor_diff.jpg")
const FLOOR_NORMAL = preload("res://assets/materials/floor_nor_gl.jpg")
const FLOOR_ROUGHNESS = preload("res://assets/materials/floor_rough.jpg")
const WATER_SHADER = preload("res://scripts/water.gdshader")
const WEAPON_SHOWCASE = {
	"pistol": preload("res://assets/kenney/blaster-k.glb"),
	"smg": preload("res://assets/kenney/blaster-a.glb"),
	"rifle": preload("res://assets/kenney/blaster-h.glb"),
	"shotgun": preload("res://assets/kenney/blaster-m.glb"),
	"sniper": preload("res://assets/kenney/blaster-g.glb"),
	"lmg": preload("res://assets/kenney/blaster-e.glb"),
	"rocket": preload("res://assets/kenney/blaster-o.glb"),
	"plasma": preload("res://assets/kenney/blaster-q.glb")
}
var turret_clock = 0.0

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

func cylinder_collision(parent: CollisionObject3D, radius: float, height: float, offset: Vector3) -> void:
	var shape = CollisionShape3D.new()
	var cylinder_shape = CylinderShape3D.new()
	cylinder_shape.radius = radius
	cylinder_shape.height = height
	shape.shape = cylinder_shape
	shape.position = offset
	parent.add_child(shape)

func floor_collisions(floor_body: StaticBody3D, world, w: int, h: int) -> void:
	var has_water = false
	for key in world.map.layers.ground:
		if world.map.layers.ground[key].type == "water":
			has_water = true
			break
	if world.map.layers.ground.size() == w * h and not has_water:
		collision(floor_body, Vector3(w * 3, 0.4, h * 3), Vector3(w * 1.5, -0.2, h * 1.5))
		return
	for y in h:
		var start = -1
		var water = false
		for x in range(w + 1):
			var key = world.cell_key(Vector2i(x, y)) if x < w else ""
			var present = x < w and world.map.layers.ground.has(key)
			var next_water = present and world.map.layers.ground[key].type == "water"
			if start >= 0 and (not present or next_water != water):
				var top = -0.65 if water else 0.0
				collision(floor_body, Vector3((x - start) * 3, 0.4, 3), Vector3((start + x) * 1.5, top - 0.2, (y + 0.5) * 3))
				start = -1
			if present and start < 0:
				start = x
				water = next_water

func rotated_box_collision(parent: CollisionObject3D, size: Vector3, offset: Vector3, rotation_degrees: float) -> void:
	var shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = offset
	shape.rotation_degrees.y = rotation_degrees
	parent.add_child(shape)

func add_visual_part(parts: Array, position: Vector3, size: Vector3, color: Color, shape: String = "box", rotation: Vector3 = Vector3.ZERO) -> void:
	parts.append({"shape": shape, "position": position, "size": size, "color": color, "rotation": rotation})

func compose_mesh(parts: Array) -> ArrayMesh:
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var primitive: Mesh = unit_box_mesh if part.shape == "box" else unit_cylinder_mesh
		var arrays = primitive.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var part_basis = Basis.from_euler(part.rotation)
		for index in indices:
			var vertex = vertices[index] * part.size
			var normal = Vector3(normals[index].x / part.size.x, normals[index].y / part.size.y, normals[index].z / part.size.z)
			builder.set_color(part.color)
			builder.set_normal((part_basis * normal).normalized())
			builder.set_uv(uvs[index])
			builder.add_vertex(part.position + part_basis * vertex)
	builder.index()
	return builder.commit()

func add_multimesh(parent: Node3D, mesh: Mesh, transforms: Array, mat: Material) -> void:
	if transforms.is_empty(): return
	var instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for i in transforms.size(): instances.set_instance_transform(i, transforms[i])
	var multi = MultiMeshInstance3D.new()
	multi.multimesh = instances
	multi.material_override = mat
	multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(multi)

func setup(owner_game) -> void:
	game = owner_game
	enemy_renderer = EnemyRenderer.new()
	add_child(enemy_renderer)
	enemy_renderer.setup(self)
	effects_rng.randomize()
	unit_box_mesh = BoxMesh.new()
	unit_cylinder_mesh = CylinderMesh.new()
	unit_cylinder_mesh.top_radius = 0.5
	unit_cylinder_mesh.bottom_radius = 0.5
	unit_cylinder_mesh.height = 1.0
	unit_cylinder_mesh.radial_segments = 8
	decoration_material = StandardMaterial3D.new()
	decoration_material.vertex_color_use_as_albedo = true
	decoration_material.roughness = 0.78
	decoration_material.metallic = 0.28
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
	atmosphere.environment.ambient_light_color = Color("b0bfce")
	atmosphere.environment.ambient_light_energy = 0.4
	atmosphere.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	atmosphere.environment.fog_enabled = true
	atmosphere.environment.fog_light_color = Color("243747")
	atmosphere.environment.fog_density = 0.006
	atmosphere.environment.fog_sky_affect = 0.25
	add_child(atmosphere)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("ffdfb3")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("101c30")
	sky_material.sky_horizon_color = Color("71828d")
	sky_material.ground_bottom_color = Color("101c29")
	sky_material.ground_horizon_color = Color("586674")
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
	get_viewport().msaa_3d = Viewport.MSAA_2X if settings.quality > 0 else Viewport.MSAA_DISABLED
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

func update_idle_turrets(delta: float) -> void:
	if game == null or not is_instance_valid(geometry): return
	turret_clock += delta
	for key in structures:
		if not game.world.construction.has(key): continue
		var data: Dictionary = game.world.construction[key]
		if data.kind != "tower": continue
		var body: Node3D = structures[key]
		var head = body.get_node_or_null("Head")
		if not is_instance_valid(head): continue
		var aim_lock = maxf(0.0, float(head.get_meta("aim_lock", 0.0)) - delta)
		head.set_meta("aim_lock", aim_lock)
		if game.state == "wave" and (aim_lock > 0.0 or float(data.get("cooldown", 0.0)) > 0.0): continue
		var phase = float(posmod(hash(key), 4096)) / 4096.0 * TAU
		var desired_yaw = sin(turret_clock * 0.58 + phase) * deg_to_rad(42.0)
		head.rotation.y = lerp_angle(head.rotation.y, desired_yaw, minf(1.0, delta * 2.2))

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
	floor_collisions(floor_body, world, w, h)
	var terrain_colors = {"concrete": Color("303e48"), "grass": Color("344c3d"), "dirt": Color("5b4d40"), "sand": Color("8c7d56"), "road": Color("202d35"), "metal": Color("344a55"), "stone": Color("4f5358"), "water": Color("174b65")}
	var terrain_details = {"metal": [], "grass": []}
	for terrain in terrain_colors:
		var cells: Array = []
		for key in world.map.layers.ground:
			if world.map.layers.ground[key].type == terrain:
				cells.append(world.point(key))
				if terrain_details.has(terrain):
					var tile: Dictionary = world.map.layers.ground[key]
					var basis = Basis(Vector3.UP, deg_to_rad(float(tile.get("rotation", 0))))
					terrain_details[terrain].append(Transform3D(basis, world.position(world.point(key), 0.006)))
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
		multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ground_material: StandardMaterial3D = material(terrain_colors[terrain]).duplicate()
		ground_material.normal_enabled = true
		ground_material.normal_texture = floor_normal
		ground_material.normal_scale = 0.32
		ground_material.roughness = 0.92
		ground_material.metallic = 0
		if terrain == "metal":
			ground_material.albedo_color = Color("455963")
			ground_material.metallic = 0.62
			ground_material.roughness = 0.48
		if terrain in ["concrete", "stone"]:
			ground_material.albedo_color = Color("a6b0b7") if terrain == "concrete" else Color("8e9395")
			ground_material.albedo_texture = FLOOR_COLOR
			ground_material.normal_texture = FLOOR_NORMAL
			ground_material.normal_scale = 0.7
			ground_material.roughness_texture = FLOOR_ROUGHNESS
			ground_material.roughness = 1
			ground_material.metallic = 0
			ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if terrain == "water":
			var water_material = ShaderMaterial.new()
			water_material.shader = WATER_SHADER
			multi.material_override = water_material
		else:
			multi.material_override = ground_material
		geometry.add_child(multi)
	for terrain in terrain_details:
		if not terrain_details[terrain].is_empty():
			add_multimesh(geometry, compose_mesh(terrain_detail_parts(terrain)), terrain_details[terrain], decoration_material)
	road_markings()
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
			light.light_energy = 1.2
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
		match tile.type:
			"chest", "supply":
				for x in [-0.45, 0.45]: box(object_body, Vector3(x, 0.55, -0.62), Vector3(0.1, 1.0, 0.04), Color("d4b782"))
				box(object_body, Vector3(0, 0.55, -0.64), Vector3(0.38, 0.1, 0.04), Color("7ed9cb"), 0.3)
				box(object_body, Vector3(0, 0.55, -0.64), Vector3(0.1, 0.38, 0.04), Color("7ed9cb"), 0.3)
			"ammo":
				for x in [-0.4, 0.0, 0.4]: cylinder(object_body, Vector3(x, 0.72, -0.62), 0.1, 0.55, Color("d4b782"))
			"generator":
				for x in [-0.45, 0.0, 0.45]: box(object_body, Vector3(x, 0.65, -0.63), Vector3(0.14, 0.6, 0.05), Color("79c9b6"), 0.3)
			"shop", "upgrade":
				box(object_body, Vector3(0, 0.78, -0.63), Vector3(1.0, 0.45, 0.04), Color("112630"))
				box(object_body, Vector3(0, 0.78, -0.66), Vector3(0.65, 0.05, 0.02), Color("f4bd69"), 0.5)
	var decoration_transforms = {"vegetation": [], "debris": [], "crate": [], "pipe": [], "machinery": [], "light": []}
	var solid_decorations = StaticBody3D.new()
	solid_decorations.collision_layer = 1
	solid_decorations.collision_mask = 0
	var has_solid_decoration = false
	for key in world.map.layers.decoration:
		var tile: Dictionary = world.map.layers.decoration[key]
		var kind: String = tile.type
		if not decoration_transforms.has(kind): continue
		var rotation = float(tile.get("rotation", 0))
		var pos = world.position(world.point(key), float(tile.get("elevation", 0)))
		var basis = Basis(Vector3.UP, deg_to_rad(rotation))
		decoration_transforms[kind].append(Transform3D(basis, pos))
		if kind == "crate":
			has_solid_decoration = true
			rotated_box_collision(solid_decorations, Vector3(1.3, 0.9, 1.3), pos + Vector3.UP * 0.45, rotation)
		elif kind == "machinery":
			has_solid_decoration = true
			rotated_box_collision(solid_decorations, Vector3(1.35, 1.4, 1.35), pos + Vector3.UP * 0.7, rotation)
		elif kind == "pipe":
			has_solid_decoration = true
			cylinder_collision(solid_decorations, 0.24, 2.0, pos + Vector3.UP)
	if has_solid_decoration:
		geometry.add_child(solid_decorations)
	else:
		solid_decorations.free()
	for kind in decoration_transforms:
		if not decoration_transforms[kind].is_empty():
			add_multimesh(geometry, decoration_mesh(kind), decoration_transforms[kind], decoration_material)
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
	if world.map.get("id", "") == "debug_gallery":
		gallery_labels(world)

func gallery_labels(world) -> void:
	for layer in world.map.layers:
		for key in world.map.layers[layer]:
			var point: Vector2i = world.point(key)
			if layer == "ground" and (point.y != 2 or point.x < 2 or point.x > 23 or (point.x - 2) % 3 != 0):
				continue
			var tile: Dictionary = world.map.layers[layer][key]
			var label = Label3D.new()
			label.text = "%s / %s" % [str(layer).capitalize(), str(tile.get("type", "tile")).replace("_", " ").capitalize()]
			label.position = world.position(point, 1.45 if layer in ["ground", "objects", "decoration"] else 4.0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 42
			label.pixel_size = 0.006
			label.outline_size = 8
			label.outline_modulate = Color("101c25")
			label.modulate = Color("f2ddb0")
			label.no_depth_test = true
			geometry.add_child(label)

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
		var wall = box(body, Vector3(0, height * 0.5, 0), Vector3(3, height, 3), color)
		if tile.type in ["concrete_wall", "permanent", "reinforced"]:
			var wall_key = "wall_" + tile.type
			if not materials.has(wall_key):
				var mat = material(color).duplicate()
				mat.albedo_color = color.lightened(0.2)
				mat.albedo_texture = FLOOR_COLOR
				mat.normal_enabled = true
				mat.normal_texture = FLOOR_NORMAL
				mat.normal_scale = 0.5
				mat.roughness_texture = FLOOR_ROUGHNESS
				mat.uv1_triplanar = true
				mat.uv1_scale = Vector3.ONE * 0.33
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				materials[wall_key] = mat
			wall.material_override = materials[wall_key]
		collision(body, Vector3(3, height, 3), Vector3(0, height * 0.5, 0))
	box(body, Vector3(0, height - 0.16, -1.51), Vector3(2.7, 0.08, 0.03), Color("6796a0"), 0.2)

func road_markings() -> void:
	var transforms: Array[Transform3D] = []
	for key in game.world.map.layers.ground:
		if game.world.map.layers.ground[key].type != "road": continue
		var p = game.world.point(key)
		var horizontal = game.world.map.layers.ground.get(game.world.cell_key(p + Vector2i.RIGHT), {}).get("type") == "road"
		var vertical = game.world.map.layers.ground.get(game.world.cell_key(p + Vector2i.DOWN), {}).get("type") == "road"
		if horizontal == vertical: continue
		var basis = Basis(Vector3.UP, PI * 0.5 if horizontal else 0.0)
		transforms.append(Transform3D(basis, game.world.position(p, 0.006)))
	if transforms.is_empty(): return
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.075, 0.008, 1.2)
	var instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for i in transforms.size(): instances.set_instance_transform(i, transforms[i])
	var markings = MultiMeshInstance3D.new()
	markings.multimesh = instances
	markings.material_override = material(Color("b49b61"))
	markings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry.add_child(markings)

func terrain_detail_parts(terrain: String) -> Array:
	var parts: Array = []
	if terrain == "metal":
		add_visual_part(parts, Vector3(0, 0.014, 0), Vector3(2.72, 0.025, 2.72), Color("273942"))
		add_visual_part(parts, Vector3(0, 0.031, 0), Vector3(2.56, 0.018, 2.56), Color("506773"))
		for edge in [-1, 1]:
			add_visual_part(parts, Vector3(edge * 0.72, 0.043, 0), Vector3(0.025, 0.008, 2.48), Color("31464f"))
			add_visual_part(parts, Vector3(0, 0.043, edge * 0.72), Vector3(2.48, 0.008, 0.025), Color("31464f"))
		for x in [-1.12, 1.12]:
			for z in [-1.12, 1.12]:
				add_visual_part(parts, Vector3(x, 0.055, z), Vector3(0.075, 0.035, 0.075), Color("a7b7b7"), "cylinder")
	elif terrain == "grass":
		for i in 3:
			var x = -0.68 + i * 0.36
			var z = 0.52 - (i % 2) * 0.42
			add_visual_part(parts, Vector3(x, 0.13, z), Vector3(0.055, 0.25, 0.045), Color("66865d"), "box", Vector3(0, 0, -0.24 + i * 0.18))
			add_visual_part(parts, Vector3(x + 0.06, 0.1, z - 0.04), Vector3(0.045, 0.2, 0.04), Color("8a9e62"), "box", Vector3(0.12, 0, 0.22 - i * 0.12))
	return parts

func decoration_mesh(kind: String) -> ArrayMesh:
	if decoration_meshes.has(kind): return decoration_meshes[kind]
	var parts: Array = []
	var frame = Color("354751")
	var metal = Color("718793")
	match kind:
		"crate":
			add_visual_part(parts, Vector3(0, 0.45, 0), Vector3(1.14, 0.78, 1.14), Color("705540"))
			add_visual_part(parts, Vector3(0, 0.08, 0), Vector3(1.22, 0.12, 1.22), frame)
			add_visual_part(parts, Vector3(0, 0.85, 0), Vector3(1.22, 0.08, 1.22), frame)
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.53, 0.46, 0), Vector3(0.1, 0.78, 1.2), metal)
				add_visual_part(parts, Vector3(0, 0.46, side * 0.53), Vector3(1.2, 0.78, 0.1), metal)
				add_visual_part(parts, Vector3(side * 0.24, 0.45, -0.586), Vector3(0.075, 0.66, 0.035), Color("b5844b"), "box", Vector3(0, 0, side * 0.5))
			add_visual_part(parts, Vector3(0, 0.46, -0.59), Vector3(0.75, 0.075, 0.035), Color("b5844b"))
		"machinery":
			add_visual_part(parts, Vector3(0, 0.62, 0), Vector3(1.25, 1.22, 1.24), Color("364b54"))
			add_visual_part(parts, Vector3(0, 1.27, 0), Vector3(1.34, 0.12, 1.32), metal)
			add_visual_part(parts, Vector3(0, 0.7, -0.642), Vector3(0.82, 0.46, 0.045), Color("1e3038"))
			add_visual_part(parts, Vector3(0, 0.7, -0.672), Vector3(0.56, 0.05, 0.025), Color("59c5bf"))
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.34, 0.84, -0.679), Vector3(0.11, 0.11, 0.035), Color("e9b967"), "cylinder")
				add_visual_part(parts, Vector3(side * 0.4, 1.02, 0.22), Vector3(0.12, 0.48, 0.12), frame, "cylinder")
				add_visual_part(parts, Vector3(side * 0.42, 0.22, -0.2), Vector3(0.12, 0.28, 0.07), metal)
			for i in 3:
				add_visual_part(parts, Vector3(-0.24 + i * 0.24, 1.2, -0.22), Vector3(0.08, 0.08, 0.14), frame)
		"pipe":
			add_visual_part(parts, Vector3(0, 0.08, 0), Vector3(0.46, 0.16, 0.46), frame, "cylinder")
			add_visual_part(parts, Vector3(0, 1.0, 0), Vector3(0.32, 1.78, 0.32), metal, "cylinder")
			add_visual_part(parts, Vector3(0, 0.34, 0), Vector3(0.48, 0.12, 0.48), frame, "cylinder")
			add_visual_part(parts, Vector3(0, 1.74, 0), Vector3(0.42, 0.12, 0.42), frame, "cylinder")
			add_visual_part(parts, Vector3(0, 1.88, 0), Vector3(0.24, 0.12, 0.24), Color("546b74"), "cylinder")
		"light":
			add_visual_part(parts, Vector3(0, 0.08, 0), Vector3(0.48, 0.16, 0.48), frame, "cylinder")
			add_visual_part(parts, Vector3(0, 1.0, 0), Vector3(0.12, 1.84, 0.12), metal, "cylinder")
			add_visual_part(parts, Vector3(0, 1.92, 0), Vector3(0.54, 0.16, 0.22), frame)
			add_visual_part(parts, Vector3(0, 1.82, 0), Vector3(0.34, 0.08, 0.2), Color("f4d18d"))
		"vegetation":
			add_visual_part(parts, Vector3(0, 0.35, 0), Vector3(0.22, 0.7, 0.22), Color("536e4e"), "cylinder")
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.24, 0.54, 0), Vector3(0.28, 0.76, 0.24), Color("4f7655"), "cylinder")
				add_visual_part(parts, Vector3(side * 0.15, 0.84, -0.12), Vector3(0.3, 0.48, 0.28), Color("76915d"), "cylinder")
			add_visual_part(parts, Vector3(0, 1.08, 0.06), Vector3(0.34, 0.45, 0.3), Color("8c9b62"), "cylinder")
		"debris":
			add_visual_part(parts, Vector3(-0.38, 0.13, 0.14), Vector3(0.62, 0.26, 0.46), Color("677076"), "box", Vector3(0.08, 0.14, -0.12))
			add_visual_part(parts, Vector3(0.28, 0.16, 0.28), Vector3(0.54, 0.32, 0.42), Color("4b5960"), "box", Vector3(-0.12, -0.2, 0.1))
			add_visual_part(parts, Vector3(0.12, 0.11, -0.36), Vector3(0.68, 0.22, 0.34), Color("818681"), "box", Vector3(0.05, 0.25, -0.08))
			add_visual_part(parts, Vector3(-0.16, 0.08, -0.08), Vector3(0.35, 0.16, 0.52), Color("394951"), "box", Vector3(0.1, -0.1, 0.18))
	var result = compose_mesh(parts)
	decoration_meshes[kind] = result
	return result

func remove_fixed(key: String) -> void:
	if fixed_nodes.has(key) and is_instance_valid(fixed_nodes[key]):
		geometry.remove_child(fixed_nodes[key])
		fixed_nodes[key].queue_free()
	fixed_nodes.erase(key)
	if game.world.construction.has(key):
		structure(key)

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
	body.position = game.structure_position(key)
	body.rotation_degrees.y = float(data.get("rotation", 0))
	geometry.add_child(body)
	structures[key] = body
	if data.kind == "wall":
		collision(body, Vector3(2.8, 2.2, 2.8), Vector3(0, 1.1, 0))
	elif data.kind != "trap":
		collision(body, Vector3(1.6, 1.9, 1.6), Vector3(0, 0.95, 0))
	add_structure_visual(body, data)

func add_structure_visual(parent: Node3D, data: Dictionary) -> void:
	var color = Color(data.color)
	var frame = Color("263841")
	var steel = Color("72858b")
	if data.kind == "wall":
		box(parent, Vector3(0, 0.14, 0), Vector3(2.9, 0.28, 2.9), frame)
		box(parent, Vector3(0, 1.19, 0), Vector3(2.78, 2.1, 2.78), Color("4b5b64"))
		box(parent, Vector3(0, 2.28, 0), Vector3(2.9, 0.16, 2.9), steel)
		box(parent, Vector3(0, 1.38, -1.405), Vector3(2.2, 0.46, 0.045), frame)
		box(parent, Vector3(0, 1.38, -1.435), Vector3(0.84, 0.12, 0.025), color, 0.2)
		for x in [-1.0, 0.0, 1.0]:
			box(parent, Vector3(x, 1.18, -1.414), Vector3(0.06, 1.46, 0.04), steel)
			box(parent, Vector3(x, 0.42, -1.44), Vector3(0.12, 0.12, 0.06), color, 0.15)
		return
	if data.kind == "trap":
		cylinder(parent, Vector3(0, 0.1, 0), 1.2, 0.2, frame)
		if data.id == "mine":
			cylinder(parent, Vector3(0, 0.34, 0), 0.62, 0.38, Color("4d3b37"))
			cylinder(parent, Vector3(0, 0.56, 0), 0.43, 0.08, color, 0.4)
			for side in [-1, 1]:
				box(parent, Vector3(side * 0.82, 0.19, 0), Vector3(0.16, 0.06, 1.42), color)
		else:
			for i in 8:
				var angle = TAU * i / 8.0
				var spike = cylinder(parent, Vector3(cos(angle) * 0.77, 0.38, sin(angle) * 0.77), 0.09, 0.62, steel)
				spike.rotation.z = -0.18
		return
	box(parent, Vector3(0, 0.12, 0), Vector3(2.55, 0.2, 2.55), frame)
	cylinder(parent, Vector3(0, 0.34, 0), 1.08, 0.3, steel)
	cylinder(parent, Vector3(0, 0.88, 0), 0.46, 0.94, frame)
	cylinder(parent, Vector3(0, 1.36, 0), 0.68, 0.12, color, 0.12)
	for side in [-1, 1]:
		for depth in [-1, 1]:
			var brace = box(parent, Vector3(side * 0.73, 0.79, depth * 0.73), Vector3(0.16, 0.82, 0.16), steel)
			brace.rotation.z = -side * 0.18
	match data.kind:
		"tower":
			var head = Node3D.new()
			head.name = "Head"
			head.position.y = 1.8
			parent.add_child(head)
			build_turret_head(head, str(data.id), color)
		"support":
			cylinder(parent, Vector3(0, 2.0, 0), 0.16, 1.25, steel)
			cylinder(parent, Vector3(0, 2.62, 0), 0.48, 0.14, color, 1.1)
			cylinder(parent, Vector3(0, 2.84, 0), 0.3, 0.08, steel)
			for side in [-1, 1]:
				box(parent, Vector3(side * 0.34, 2.22, 0), Vector3(0.11, 0.54, 0.11), color, 0.15)
		"repair":
			box(parent, Vector3(0, 1.24, 0), Vector3(1.05, 0.82, 0.94), frame)
			box(parent, Vector3(0, 1.69, 0), Vector3(0.7, 0.1, 0.66), color, 0.7)
			for side in [-1, 1]:
				var arm = box(parent, Vector3(side * 0.78, 1.85, 0), Vector3(0.16, 0.75, 0.16), steel)
				arm.rotation.z = -side * 0.4
				box(parent, Vector3(side * 1.02, 2.16, 0), Vector3(0.3, 0.14, 0.3), color, 0.45)
		"generator":
			box(parent, Vector3(0, 1.22, 0), Vector3(1.42, 1.12, 1.32), frame)
			box(parent, Vector3(0, 1.84, 0), Vector3(1.54, 0.16, 1.44), steel)
			cylinder(parent, Vector3(0, 2.04, 0), 0.38, 0.34, color, 0.8)
			for side in [-1, 1]:
				cylinder(parent, Vector3(side * 0.48, 1.22, -0.7), 0.11, 0.78, steel)
		"ammo":
			box(parent, Vector3(0, 1.16, 0), Vector3(1.56, 0.92, 1.36), Color("705540"))
			for side in [-1, 1]:
				box(parent, Vector3(side * 0.62, 1.17, -0.7), Vector3(0.13, 0.86, 0.06), steel)
			for x in [-0.42, 0.0, 0.42]:
				var shell = cylinder(parent, Vector3(x, 1.76, 0), 0.14, 0.76, color)
				shell.rotation.x = PI * 0.5
		"shield":
			cylinder(parent, Vector3(0, 1.5, 0), 0.3, 0.84, frame)
			cylinder(parent, Vector3(0, 1.98, 0), 0.48, 0.24, color, 1.2)
			for side in [-1, 1]:
				var coil = cylinder(parent, Vector3(side * 0.62, 1.78, 0), 0.14, 0.88, steel)
				coil.rotation.z = -side * 0.25
				box(parent, Vector3(side * 0.62, 2.26, 0), Vector3(0.28, 0.14, 0.28), color, 0.9)

func horizontal_barrel(parent: Node3D, position: Vector3, radius: float, length: float, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh = cylinder(parent, position, radius, length, color, glow)
	mesh.rotation.x = PI * 0.5
	return mesh

func build_turret_head(head: Node3D, id: String, color: Color) -> void:
	var frame = Color("1b2b34")
	var steel = Color("8c9da1")
	box(head, Vector3(0, 0, 0), Vector3(1.32, 0.68, 1.08), color)
	box(head, Vector3(0, 0.36, 0.02), Vector3(1.18, 0.12, 0.96), steel)
	box(head, Vector3(0, -0.39, 0.08), Vector3(0.92, 0.14, 0.76), frame)
	for side in [-1, 1]:
		var pivot = cylinder(head, Vector3(side * 0.7, 0, 0.02), 0.19, 0.2, steel)
		pivot.rotation.z = PI * 0.5
	match id:
		"sentry":
			for side in [-1, 1]:
				horizontal_barrel(head, Vector3(side * 0.3, -0.02, -0.94), 0.13, 1.12, frame)
				horizontal_barrel(head, Vector3(side * 0.3, -0.02, -1.48), 0.16, 0.12, steel)
				box(head, Vector3(side * 0.3, -0.02, -1.56), Vector3(0.1, 0.1, 0.04), color, 0.5)
			box(head, Vector3(0, 0.54, 0.18), Vector3(0.44, 0.13, 0.28), frame)
		"rocket":
			for side in [-1, 1]:
				box(head, Vector3(side * 0.34, 0.03, -0.88), Vector3(0.42, 0.47, 1.02), frame)
				horizontal_barrel(head, Vector3(side * 0.34, 0.03, -1.42), 0.17, 0.1, steel)
				box(head, Vector3(side * 0.34, 0.03, -1.49), Vector3(0.22, 0.22, 0.025), color, 0.45)
			box(head, Vector3(0, 0.56, 0.12), Vector3(0.7, 0.12, 0.32), steel)
		"tesla":
			for side in [-1, 1]:
				var coil = cylinder(head, Vector3(side * 0.32, 0.18, -0.18), 0.12, 0.7, steel)
				coil.rotation.z = side * 0.22
				cylinder(head, Vector3(side * 0.32, 0.48, -0.18), 0.2, 0.09, color, 1.2)
			horizontal_barrel(head, Vector3(0, 0.08, -0.88), 0.23, 0.64, frame)
			horizontal_barrel(head, Vector3(0, 0.08, -1.23), 0.27, 0.11, color, 1.4)
		"laser":
			horizontal_barrel(head, Vector3(0, 0.02, -0.92), 0.18, 1.1, frame)
			horizontal_barrel(head, Vector3(0, 0.02, -1.5), 0.25, 0.12, color, 1.4)
			for side in [-1, 1]:
				box(head, Vector3(side * 0.36, 0.18, -0.72), Vector3(0.1, 0.12, 0.82), steel)
		"flame":
			for side in [-1, 1]:
				horizontal_barrel(head, Vector3(side * 0.3, -0.04, -0.85), 0.16, 0.9, frame)
				horizontal_barrel(head, Vector3(side * 0.3, -0.04, -1.33), 0.21, 0.13, Color("ffb558"), 1.1)
				cylinder(head, Vector3(side * 0.61, 0, 0.05), 0.16, 0.5, steel)
		"rail":
			horizontal_barrel(head, Vector3(0, 0.02, -1.06), 0.19, 1.48, frame)
			horizontal_barrel(head, Vector3(0, 0.02, -1.85), 0.26, 0.13, steel)
			for side in [-1, 1]:
				box(head, Vector3(side * 0.25, 0.24, -1.08), Vector3(0.08, 0.11, 1.48), color, 0.2)
		"mortar":
			var tube = cylinder(head, Vector3(0, 0.1, -0.38), 0.27, 1.14, frame)
			tube.rotation.x = -0.68
			var muzzle = cylinder(head, Vector3(0, 0.53, -0.73), 0.34, 0.12, steel)
			muzzle.rotation.x = -0.68
			box(head, Vector3(0, -0.38, 0.24), Vector3(0.82, 0.2, 0.64), steel)
		"interceptor":
			cylinder(head, Vector3(0, 0.62, 0.12), 0.38, 0.12, frame)
			cylinder(head, Vector3(0, 0.73, 0.12), 0.29, 0.08, color, 0.35)
			cylinder(head, Vector3(0, 0.86, 0.12), 0.1, 0.22, steel)
			for side in [-1, 1]:
				horizontal_barrel(head, Vector3(side * 0.3, 0.02, -0.72), 0.13, 0.72, steel)
				box(head, Vector3(side * 0.3, 0.02, -1.1), Vector3(0.2, 0.19, 0.1), color, 0.35)
				box(head, Vector3(side * 0.3, 0.34, -0.38), Vector3(0.08, 0.16, 0.5), frame)
			var radar_arm = box(head, Vector3(0, 0.96, 0.12), Vector3(0.06, 0.32, 0.06), steel)
			radar_arm.rotation.z = 0.2
			cylinder(head, Vector3(0, 1.12, 0.12), 0.32, 0.08, color, 0.3)
		"cryo":
			for side in [-1, 1]:
				horizontal_barrel(head, Vector3(side * 0.36, 0.02, -1.0), 0.1, 1.18, steel)
				horizontal_barrel(head, Vector3(side * 0.36, 0.02, -1.62), 0.15, 0.1, color, 1.4)
			horizontal_barrel(head, Vector3(0, 0.02, -1.15), 0.08, 1.2, Color("c7fbff"), 1.5)
		_:
			horizontal_barrel(head, Vector3(0, 0.02, -1.0), 0.18, 1.2, steel)
			horizontal_barrel(head, Vector3(0, 0.02, -1.65), 0.23, 0.12, color, 1.0)

func add_special_weapon_model(parent: Node3D, id: String) -> bool:
	match id:
		"arc":
			var frame = Color("263941")
			var steel = Color("71858a")
			var cyan = Color("51d8e4")
			box(parent, Vector3(0, 0, 0.12), Vector3(0.3, 0.25, 0.76), frame)
			box(parent, Vector3(0, 0.04, -0.2), Vector3(0.22, 0.28, 0.48), steel)
			box(parent, Vector3(0, -0.08, -0.57), Vector3(0.16, 0.15, 0.42), frame)
			box(parent, Vector3(0, -0.28, 0.08), Vector3(0.2, 0.34, 0.23), frame)
			for side in [-1, 1]:
				var coil = cylinder(parent, Vector3(side * 0.2, 0.02, -0.32), 0.085, 0.44, cyan, 1.2)
				coil.rotation.x = PI * 0.5
				box(parent, Vector3(side * 0.2, 0.02, -0.55), Vector3(0.12, 0.12, 0.08), steel)
			box(parent, Vector3(0, 0.2, 0.1), Vector3(0.26, 0.08, 0.5), cyan, 0.65)
			return true
		"frost_launcher":
			var frame = Color("344b58")
			var steel = Color("a4c7d0")
			var frost = Color("a6efff")
			box(parent, Vector3(0, 0, 0.12), Vector3(0.42, 0.32, 0.72), frame)
			box(parent, Vector3(0, 0.01, -0.25), Vector3(0.32, 0.3, 0.42), steel)
			horizontal_barrel(parent, Vector3(0, 0.02, -0.68), 0.2, 0.52, steel)
			horizontal_barrel(parent, Vector3(0, 0.02, -0.98), 0.25, 0.14, frost, 0.8)
			for side in [-1, 1]:
				box(parent, Vector3(side * 0.32, 0.02, 0.12), Vector3(0.18, 0.3, 0.62), frame)
				cylinder(parent, Vector3(side * 0.32, 0.03, 0.0), 0.11, 0.62, frost, 0.35)
			box(parent, Vector3(0, -0.27, 0.11), Vector3(0.24, 0.3, 0.24), frame)
			box(parent, Vector3(0, 0.23, 0.08), Vector3(0.3, 0.1, 0.42), steel)
			return true
	return false

func catalog_model(category: String, entry: Dictionary) -> Node3D:
	var model = Node3D.new()
	var id = str(entry.get("id", ""))
	match category:
		"Weapons":
			if add_special_weapon_model(model, id):
				pass
			elif WEAPON_SHOWCASE.has(id):
				var weapon = WEAPON_SHOWCASE[id].instantiate() as Node3D
				weapon.rotation.y = PI
				weapon.scale = Vector3.ONE * (0.65 if id in ["sniper", "lmg"] else 0.8)
				model.add_child(weapon)
			else:
				build_blade_model(model, Color(entry.color))
		"Enemies":
			var enemy = MeshInstance3D.new()
			enemy.mesh = enemy_mesh(id, Color(entry.color))
			var enemy_surface = StandardMaterial3D.new()
			enemy_surface.vertex_color_use_as_albedo = true
			enemy_surface.roughness = 0.72
			enemy_surface.metallic = 0.35
			enemy.material_override = enemy_surface
			model.add_child(enemy)
		"Defenses": add_structure_visual(model, entry)
		"Attachments": build_attachment_model(model, id)
		"Equipment": build_equipment_model(model, id)
		"Tiles": build_tile_model(model, id)
		_:
			model.free()
			return null
	return model

func build_blade_model(parent: Node3D, color: Color) -> void:
	box(parent, Vector3(0, -0.08, 0), Vector3(0.2, 0.28, 0.22), Color("263b43"))
	box(parent, Vector3(0, 0.04, 0), Vector3(0.38, 0.07, 0.25), Color("819497"))
	box(parent, Vector3(0, 0.42, 0), Vector3(0.16, 0.72, 0.08), color, 0.45)
	box(parent, Vector3(0, 0.82, 0), Vector3(0.07, 0.1, 0.075), Color("d7fff0"), 0.75)

func build_attachment_model(parent: Node3D, id: String) -> void:
	var frame = Color("263841")
	var steel = Color("85969b")
	box(parent, Vector3(0, -0.3, 0), Vector3(1.22, 0.12, 0.54), frame)
	match id:
		"barrel":
			horizontal_barrel(parent, Vector3(0, -0.02, -0.2), 0.19, 0.88, steel)
			horizontal_barrel(parent, Vector3(0, -0.02, -0.69), 0.24, 0.12, Color("b0babc"))
			for side in [-1, 1]: box(parent, Vector3(side * 0.24, -0.17, -0.3), Vector3(0.08, 0.2, 0.48), frame)
		"optic":
			horizontal_barrel(parent, Vector3(0, 0.05, -0.05), 0.19, 0.76, frame)
			horizontal_barrel(parent, Vector3(0, 0.05, -0.46), 0.16, 0.1, Color("78cbd1"), 0.35)
			box(parent, Vector3(0, -0.12, -0.02), Vector3(0.24, 0.22, 0.22), steel)
		"magazine":
			box(parent, Vector3(0, 0.0, -0.02), Vector3(0.43, 0.62, 0.48), Color("45575a"))
			box(parent, Vector3(0, 0.0, -0.27), Vector3(0.28, 0.46, 0.035), Color("b48a50"))
			box(parent, Vector3(0, 0.34, -0.02), Vector3(0.51, 0.1, 0.55), steel)
		"grip":
			var grip = box(parent, Vector3(0, -0.02, 0.0), Vector3(0.4, 0.58, 0.35), Color("43565c"))
			grip.rotation.z = -0.22
			box(parent, Vector3(0, 0.3, -0.06), Vector3(0.52, 0.14, 0.46), steel)
		"elemental":
			for side in [-1, 1]:
				var coil = cylinder(parent, Vector3(side * 0.22, 0.08, 0), 0.13, 0.58, Color("d77f54"), 1.1)
				coil.rotation.z = side * 0.2
			box(parent, Vector3(0, 0.4, 0), Vector3(0.55, 0.1, 0.5), steel)
		"coolant":
			box(parent, Vector3(0, 0.0, 0), Vector3(0.56, 0.3, 0.48), Color("314955"))
			for side in [-1, 1]:
				cylinder(parent, Vector3(side * 0.24, 0.02, -0.03), 0.14, 0.48, Color("91e5f0"), 0.8)
				box(parent, Vector3(side * 0.24, 0.02, -0.29), Vector3(0.2, 0.22, 0.08), steel)
			box(parent, Vector3(0, 0.21, 0.0), Vector3(0.52, 0.1, 0.44), Color("b5eff2"))
			box(parent, Vector3(0, 0.29, -0.08), Vector3(0.18, 0.12, 0.16), Color("78d9e6"), 0.5)
		"accelerator":
			horizontal_barrel(parent, Vector3(0, -0.02, -0.25), 0.22, 1.0, steel)
			horizontal_barrel(parent, Vector3(0, -0.02, -0.81), 0.28, 0.14, Color("70c4d5"), 0.55)
			for side in [-1, 1]:
				box(parent, Vector3(side * 0.29, 0.04, -0.2), Vector3(0.1, 0.22, 0.76), frame)
				box(parent, Vector3(side * 0.29, 0.04, -0.2), Vector3(0.06, 0.08, 0.58), Color("84d5e0"), 0.35)
			box(parent, Vector3(0, 0.14, -0.04), Vector3(0.38, 0.12, 0.32), frame)

func build_equipment_model(parent: Node3D, id: String) -> void:
	var frame = Color("263841")
	match id:
		"armor":
			box(parent, Vector3(0, 0.08, 0), Vector3(1.16, 0.86, 0.22), Color("66797e"))
			box(parent, Vector3(0, 0.08, -0.13), Vector3(0.56, 0.58, 0.04), Color("c4a05f"))
			for side in [-1, 1]:
				box(parent, Vector3(side * 0.43, 0.08, -0.15), Vector3(0.06, 0.7, 0.04), frame)
		"shield_pack":
			box(parent, Vector3(0, 0.0, 0), Vector3(0.84, 0.82, 0.38), frame)
			cylinder(parent, Vector3(0, 0.1, -0.23), 0.31, 0.16, Color("78c8f0"), 1.0)
			for side in [-1, 1]: box(parent, Vector3(side * 0.35, 0.0, -0.22), Vector3(0.12, 0.56, 0.08), Color("8eb4bd"))
		"ammo_cell":
			box(parent, Vector3(0, 0.0, 0), Vector3(0.82, 0.58, 0.54), frame)
			box(parent, Vector3(0, 0.0, -0.29), Vector3(0.64, 0.38, 0.05), Color("b68b50"))
			for side in [-1, 0, 1]:
				box(parent, Vector3(side * 0.2, 0.0, -0.34), Vector3(0.1, 0.28, 0.04), Color("e1c27b"))
			box(parent, Vector3(0, 0.34, 0), Vector3(0.46, 0.12, 0.42), Color("8c9b95"))
		"repair_kit":
			box(parent, Vector3(0, 0.0, 0), Vector3(0.94, 0.62, 0.62), Color("bc784c"))
			box(parent, Vector3(0, 0.0, -0.33), Vector3(0.54, 0.4, 0.05), Color("354b4b"))
			box(parent, Vector3(0, 0.0, -0.37), Vector3(0.1, 0.32, 0.035), Color("d5c08a"))
			box(parent, Vector3(0, 0.0, -0.37), Vector3(0.34, 0.1, 0.035), Color("d5c08a"))
			box(parent, Vector3(0, 0.36, 0), Vector3(0.5, 0.1, 0.48), Color("d0ad72"))
		"trauma_kit":
			box(parent, Vector3(0, 0.0, 0), Vector3(0.9, 0.62, 0.6), Color("d9dfd4"))
			box(parent, Vector3(0, 0.0, -0.31), Vector3(0.2, 0.44, 0.04), Color("c95850"))
			box(parent, Vector3(0, 0.0, -0.32), Vector3(0.44, 0.18, 0.04), Color("c95850"))
			box(parent, Vector3(0, 0.35, 0), Vector3(0.58, 0.1, 0.48), Color("9aada7"))
		"medkit":
			box(parent, Vector3(0, 0.0, 0), Vector3(0.9, 0.62, 0.6), Color("d9dfd4"))
			box(parent, Vector3(0, 0.0, -0.31), Vector3(0.18, 0.42, 0.04), Color("d85f54"))
			box(parent, Vector3(0, 0.0, -0.32), Vector3(0.42, 0.16, 0.04), Color("d85f54"))
		"grenade":
			cylinder(parent, Vector3(0, 0.0, 0), 0.28, 0.76, Color("596954"))
			box(parent, Vector3(0, 0.42, 0), Vector3(0.22, 0.15, 0.16), Color("aab096"))
			box(parent, Vector3(0.18, 0.36, 0), Vector3(0.3, 0.08, 0.08), Color("c5a46b"))
		_:
			box(parent, Vector3.ZERO, Vector3(0.8, 0.8, 0.3), frame)

func build_tile_model(parent: Node3D, id: String) -> void:
	var terrain_colors = {"concrete": Color("a6b0b7"), "grass": Color("344c3d"), "dirt": Color("5b4d40"), "sand": Color("8c7d56"), "road": Color("202d35"), "metal": Color("455963"), "stone": Color("8e9395"), "water": Color("174b65")}
	if terrain_colors.has(id):
		var floor_mesh = MeshInstance3D.new()
		var slab = BoxMesh.new()
		slab.size = Vector3(2.96, 0.15, 2.96)
		floor_mesh.mesh = slab
		floor_mesh.position.y = -0.075
		if id == "water":
			var water_surface = ShaderMaterial.new()
			water_surface.shader = WATER_SHADER
			floor_mesh.material_override = water_surface
		else:
			floor_mesh.material_override = material(terrain_colors[id])
		parent.add_child(floor_mesh)
		if id in ["metal", "grass"]:
			var detail = MeshInstance3D.new()
			detail.mesh = compose_mesh(terrain_detail_parts(id))
			detail.material_override = decoration_material
			detail.position.y = 0.006
			parent.add_child(detail)
		return
	if id in game.world.WALLS:
		var definition = game.world.WALL_DEFS[id]
		var height = float(definition.height)
		var color = Color(definition.color)
		if id in ["ramp", "stairs"]:
			for i in 6:
				var step_height = (i + 1) / 6.0 * minf(1.4, height)
				box(parent, Vector3(0, step_height * 0.5, -1.25 + i * 0.5), Vector3(3, step_height, 0.5), color)
		elif id == "window":
			box(parent, Vector3(0, 0.4, 0), Vector3(3, 0.8, 0.3), color)
			box(parent, Vector3(0, height - 0.25, 0), Vector3(3, 0.5, 0.3), color)
			for side in [-1, 1]:
				box(parent, Vector3(side * 1.3, height * 0.5, 0), Vector3(0.4, height, 0.3), color)
		else:
			box(parent, Vector3(0, height * 0.5, 0), Vector3(3, minf(height, 3.2), 3), color)
			box(parent, Vector3(0, minf(height, 3.2) - 0.08, -1.52), Vector3(2.7, 0.08, 0.03), Color("6796a0"), 0.2)
		return
	if id in game.world.HAZARDS:
		var hazard_color = {"fire": Color("ff8245"), "acid": Color("9fcd61"), "spikes": Color("a1b4c0"), "electric": Color("6fbefa"), "slow": Color("89d9ea"), "mine": Color("e89c68")}.get(id, Color("a1b4c0"))
		cylinder(parent, Vector3(0, 0.06, 0), 1.25, 0.12, hazard_color, 0.4)
		for i in 4:
			box(parent, Vector3((i % 2 - 0.5) * 1.2, 0.2, (i / 2 - 0.5) * 1.2), Vector3(0.15, 0.4, 0.15), hazard_color, 0.3)
		return
	if id in ["crate", "machinery", "pipe", "light", "vegetation", "debris"]:
		var prop = MeshInstance3D.new()
		prop.mesh = decoration_mesh(id)
		prop.material_override = decoration_material
		parent.add_child(prop)
		return
	if id in ["ceiling", "elevation"]:
		box(parent, Vector3(0, 0.1, 0), Vector3(3, 0.25, 3), Color("384b59"))
		return
	var marker_color = Color("3c827d")
	if id == "objective":
		cylinder(parent, Vector3(0, 0.18, 0), 1.05, 0.35, Color("15222b"))
		cylinder(parent, Vector3(0, 1.1, 0), 0.48, 1.8, Color("50e3ce"), 1.2)
	elif id == "enemy":
		marker_color = Color("e46e54")
		cylinder(parent, Vector3(0, 0.08, 0), 1.25, 0.16, marker_color, 0.8)
	elif id in ["tower_pad", "structure_pad", "pad"]:
		cylinder(parent, Vector3(0, 0.06, 0), 1.1, 0.12, marker_color, 0.25)
	else:
		box(parent, Vector3(0, 0.55, 0), Vector3(1.4, 1.1, 1.2), Color("243e4c"))
		box(parent, Vector3(0, 1.15, 0), Vector3(1, 0.2, 0.7), Color("f4bd69"), 0.6)

func enemy(data: Dictionary) -> CharacterBody3D:
	var body = CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	body.set_meta("enemy", data.uid)
	add_child(body)
	var scale_value = 1.8 if data.type == "boss" else (1.25 if data.type == "tank" else 1.0)
	var color = Color(data.color)
	var collision_size = Vector3(1.05, 1.7, 0.95)
	if data.type in ["tank", "breaker"]: collision_size = Vector3(1.3, 1.7, 1.05)
	if data.type == "shielded": collision_size = Vector3(1.12, 1.7, 1.3)
	if data.type == "runner": collision_size = Vector3(1.0, 1.7, 0.85)
	if data.type == "saboteur": collision_size = Vector3(1.2, 1.8, 0.95)
	if data.type == "exploder": collision_size = Vector3(1.08, 1.7, 0.95)
	if data.type == "boss": collision_size = Vector3(1.3, 1.7, 1.1)
	collision(body, collision_size * scale_value, Vector3(0, collision_size.y * 0.5 * scale_value, 0))
	var model = Node3D.new()
	model.name = "Model"
	model.scale = Vector3.ONE * scale_value
	body.add_child(model)
	enemy_renderer.add_enemy(data, body, scale_value)
	return body

func enemy_mesh(kind: String, color: Color) -> ArrayMesh:
	var key = kind + str(color)
	if enemy_meshes.has(key): return enemy_meshes[key]
	var result = compose_mesh(enemy_parts(kind, color))
	enemy_meshes[key] = result
	return result

func enemy_parts(kind: String, color: Color) -> Array:
	var parts: Array = []
	var plate = color.darkened(0.22)
	var trim = color.lightened(0.1)
	var joint = Color("1c2a32")
	var steel = Color("617680")
	var optic = Color("ffd28b")
	match kind:
		"grunt":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.19, 0.28, 0.02), Vector3(0.22, 0.52, 0.3), joint)
				add_visual_part(parts, Vector3(side * 0.2, 0.1, -0.08), Vector3(0.26, 0.16, 0.42), steel)
				add_visual_part(parts, Vector3(side * 0.42, 0.83, -0.02), Vector3(0.19, 0.58, 0.25), plate, "box", Vector3(0, 0, side * -0.08))
				add_visual_part(parts, Vector3(side * 0.36, 1.07, 0), Vector3(0.26, 0.3, 0.35), steel)
				add_visual_part(parts, Vector3(side * 0.17, 1.08, 0.3), Vector3(0.14, 0.28, 0.14), plate, "cylinder")
			add_visual_part(parts, Vector3(0, 0.82, 0.02), Vector3(0.68, 0.62, 0.48), color)
			add_visual_part(parts, Vector3(0, 0.98, -0.27), Vector3(0.62, 0.34, 0.1), plate)
			add_visual_part(parts, Vector3(0, 1.44, -0.02), Vector3(0.44, 0.35, 0.42), steel)
			add_visual_part(parts, Vector3(0, 1.44, -0.24), Vector3(0.3, 0.08, 0.035), optic)
			add_visual_part(parts, Vector3(0, 0.58, -0.25), Vector3(0.45, 0.09, 0.08), trim)
		"runner":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.16, 0.34, 0.04), Vector3(0.15, 0.55, 0.17), joint, "box", Vector3(0, 0, side * 0.08))
				add_visual_part(parts, Vector3(side * 0.18, 0.08, -0.12), Vector3(0.22, 0.13, 0.38), steel)
				add_visual_part(parts, Vector3(side * 0.4, 0.88, 0.08), Vector3(0.14, 0.54, 0.19), plate, "box", Vector3(0, 0, side * 0.1))
				add_visual_part(parts, Vector3(side * 0.23, 0.88, 0.24), Vector3(0.11, 0.52, 0.1), trim, "box", Vector3(side * 0.18, 0, side * 0.28))
				add_visual_part(parts, Vector3(side * 0.24, 1.12, 0.18), Vector3(0.1, 0.43, 0.12), steel, "box", Vector3(0, 0, side * 0.46))
			add_visual_part(parts, Vector3(0, 0.88, 0.02), Vector3(0.5, 0.62, 0.36), color, "box", Vector3(-0.12, 0, 0))
			add_visual_part(parts, Vector3(0, 1.05, -0.2), Vector3(0.4, 0.26, 0.08), plate)
			add_visual_part(parts, Vector3(0, 1.48, -0.03), Vector3(0.32, 0.28, 0.32), steel)
			add_visual_part(parts, Vector3(0, 1.48, -0.2), Vector3(0.24, 0.065, 0.03), optic)
		"tank":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.28, 0.29, 0.03), Vector3(0.29, 0.52, 0.34), joint)
				add_visual_part(parts, Vector3(side * 0.3, 0.1, -0.08), Vector3(0.35, 0.16, 0.46), steel)
				add_visual_part(parts, Vector3(side * 0.48, 1.08, 0), Vector3(0.27, 0.44, 0.51), plate)
				add_visual_part(parts, Vector3(side * 0.47, 0.77, -0.12), Vector3(0.29, 0.3, 0.32), steel)
				add_visual_part(parts, Vector3(side * 0.24, 1.08, 0.31), Vector3(0.19, 0.4, 0.18), steel, "cylinder")
			add_visual_part(parts, Vector3(0, 0.82, 0.02), Vector3(0.82, 0.68, 0.58), color)
			add_visual_part(parts, Vector3(0, 0.98, -0.31), Vector3(0.76, 0.44, 0.13), plate)
			add_visual_part(parts, Vector3(0, 0.98, -0.39), Vector3(0.5, 0.2, 0.04), steel)
			add_visual_part(parts, Vector3(0, 1.46, -0.02), Vector3(0.39, 0.29, 0.35), joint)
			add_visual_part(parts, Vector3(0, 1.45, -0.2), Vector3(0.24, 0.075, 0.04), optic)
		"spitter":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.18, 0.28, 0.03), Vector3(0.19, 0.51, 0.26), joint)
				add_visual_part(parts, Vector3(side * 0.4, 0.83, 0.02), Vector3(0.15, 0.55, 0.2), plate, "box", Vector3(0, 0, side * 0.1))
				add_visual_part(parts, Vector3(side * 0.23, 1.13, 0.29), Vector3(0.24, 0.48, 0.24), trim, "cylinder")
				add_visual_part(parts, Vector3(side * 0.23, 1.13, 0.29), Vector3(0.28, 0.1, 0.28), Color("4d713e"), "cylinder")
			add_visual_part(parts, Vector3(0, 0.8, 0.07), Vector3(0.6, 0.56, 0.48), color, "box", Vector3(0.16, 0, 0))
			add_visual_part(parts, Vector3(0, 1.19, -0.08), Vector3(0.42, 0.4, 0.42), plate)
			add_visual_part(parts, Vector3(0, 1.24, -0.34), Vector3(0.28, 0.14, 0.18), trim)
			add_visual_part(parts, Vector3(0, 1.25, -0.44), Vector3(0.14, 0.07, 0.04), Color("bded7c"))
		"breaker":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.2, 0.28, 0.02), Vector3(0.24, 0.5, 0.3), joint)
				add_visual_part(parts, Vector3(side * 0.43, 0.88, 0), Vector3(0.25, 0.38, 0.41), steel)
				add_visual_part(parts, Vector3(side * 0.5, 0.58, -0.04), Vector3(0.3, 0.32, 0.35), plate)
				add_visual_part(parts, Vector3(side * 0.5, 0.59, -0.25), Vector3(0.24, 0.22, 0.12), trim)
			add_visual_part(parts, Vector3(0, 0.81, 0.03), Vector3(0.72, 0.64, 0.52), color)
			add_visual_part(parts, Vector3(0, 1.04, -0.29), Vector3(0.7, 0.35, 0.14), plate)
			add_visual_part(parts, Vector3(0, 1.4, -0.04), Vector3(0.46, 0.32, 0.44), steel)
			add_visual_part(parts, Vector3(0, 1.39, -0.28), Vector3(0.38, 0.14, 0.2), trim)
			add_visual_part(parts, Vector3(0, 1.39, -0.4), Vector3(0.17, 0.1, 0.08), Color("ffd093"))
		"saboteur":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.18, 0.28, 0.03), Vector3(0.18, 0.51, 0.25), joint)
				add_visual_part(parts, Vector3(side * 0.39, 0.86, 0.02), Vector3(0.14, 0.54, 0.18), plate, "box", Vector3(0, 0, side * -0.1))
				add_visual_part(parts, Vector3(side * 0.48, 1.12, 0.03), Vector3(0.2, 0.25, 0.3), steel)
			add_visual_part(parts, Vector3(0, 0.82, 0.02), Vector3(0.57, 0.62, 0.43), color)
			add_visual_part(parts, Vector3(0, 0.95, 0.29), Vector3(0.48, 0.46, 0.24), plate)
			add_visual_part(parts, Vector3(0, 1.43, -0.03), Vector3(0.39, 0.3, 0.37), joint)
			add_visual_part(parts, Vector3(0, 1.42, -0.23), Vector3(0.26, 0.07, 0.035), Color("d9a2e4"))
			add_visual_part(parts, Vector3(0.16, 1.65, 0.24), Vector3(0.055, 0.3, 0.055), steel, "cylinder", Vector3(0, 0, -0.08))
			add_visual_part(parts, Vector3(0, 0.97, -0.25), Vector3(0.17, 0.16, 0.06), optic)
		"shielded":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.19, 0.28, 0.08), Vector3(0.22, 0.51, 0.3), joint)
				add_visual_part(parts, Vector3(side * 0.4, 0.84, 0.13), Vector3(0.16, 0.54, 0.2), plate)
			add_visual_part(parts, Vector3(0, 0.83, 0.12), Vector3(0.62, 0.62, 0.46), color)
			add_visual_part(parts, Vector3(0, 1.43, 0.04), Vector3(0.4, 0.34, 0.38), steel)
			add_visual_part(parts, Vector3(0, 1.42, -0.17), Vector3(0.23, 0.07, 0.035), optic)
			add_visual_part(parts, Vector3(0, 0.82, -0.48), Vector3(0.96, 1.28, 0.16), plate)
			add_visual_part(parts, Vector3(0, 0.82, -0.58), Vector3(0.8, 1.08, 0.05), color)
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.45, 0.82, -0.61), Vector3(0.07, 1.2, 0.05), steel)
			add_visual_part(parts, Vector3(0, 1.34, -0.62), Vector3(0.42, 0.08, 0.05), trim)
		"support":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.18, 0.28, 0.02), Vector3(0.18, 0.5, 0.24), joint)
				add_visual_part(parts, Vector3(side * 0.39, 0.84, 0), Vector3(0.14, 0.52, 0.18), plate)
				add_visual_part(parts, Vector3(side * 0.22, 1.02, 0.32), Vector3(0.19, 0.54, 0.19), Color("4e8067"), "cylinder")
				add_visual_part(parts, Vector3(side * 0.22, 1.02, 0.32), Vector3(0.22, 0.1, 0.22), steel, "cylinder")
			add_visual_part(parts, Vector3(0, 0.82, 0.03), Vector3(0.61, 0.62, 0.45), color)
			add_visual_part(parts, Vector3(0, 1.43, -0.02), Vector3(0.4, 0.33, 0.37), steel)
			add_visual_part(parts, Vector3(0, 1.42, -0.22), Vector3(0.24, 0.07, 0.035), Color("9bf0b2"))
			add_visual_part(parts, Vector3(0, 0.84, -0.28), Vector3(0.28, 0.3, 0.08), Color("a9e1bd"))
		"lancer":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.2, 0.28, 0.02), Vector3(0.2, 0.5, 0.27), joint)
				add_visual_part(parts, Vector3(side * 0.2, 0.1, -0.08), Vector3(0.28, 0.14, 0.38), steel)
				add_visual_part(parts, Vector3(side * 0.42, 0.88, 0.04), Vector3(0.18, 0.52, 0.23), plate, "box", Vector3(0, 0, side * -0.08))
				add_visual_part(parts, Vector3(side * 0.4, 1.11, 0.08), Vector3(0.2, 0.24, 0.28), steel)
			add_visual_part(parts, Vector3(0, 0.82, 0.04), Vector3(0.62, 0.61, 0.48), color)
			add_visual_part(parts, Vector3(0, 0.96, -0.27), Vector3(0.55, 0.32, 0.1), plate)
			add_visual_part(parts, Vector3(0, 1.43, 0.0), Vector3(0.39, 0.32, 0.39), steel)
			add_visual_part(parts, Vector3(0, 1.43, -0.22), Vector3(0.27, 0.08, 0.035), optic)
			add_visual_part(parts, Vector3(0.22, 1.68, 0.18), Vector3(0.055, 0.42, 0.055), steel, "cylinder", Vector3(0, 0, -0.12))
			add_visual_part(parts, Vector3(0.22, 1.9, 0.18), Vector3(0.24, 0.07, 0.24), Color("78d8d2"), "cylinder")
			add_visual_part(parts, Vector3(-0.34, 0.96, -0.25), Vector3(0.18, 0.2, 0.48), joint)
			add_visual_part(parts, Vector3(-0.34, 0.96, -0.52), Vector3(0.13, 0.12, 0.42), steel, "cylinder")
		"bombardier":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.22, 0.27, 0.02), Vector3(0.23, 0.5, 0.3), joint)
				add_visual_part(parts, Vector3(side * 0.22, 0.1, -0.08), Vector3(0.3, 0.15, 0.4), steel)
				add_visual_part(parts, Vector3(side * 0.43, 0.87, 0.02), Vector3(0.2, 0.48, 0.26), plate)
				add_visual_part(parts, Vector3(side * 0.43, 1.14, 0.05), Vector3(0.24, 0.2, 0.3), steel)
				add_visual_part(parts, Vector3(side * 0.38, 1.16, 0.36), Vector3(0.22, 0.52, 0.22), Color("bd8050"), "cylinder", Vector3(0.2, 0, side * -0.12))
				add_visual_part(parts, Vector3(side * 0.38, 1.42, 0.36), Vector3(0.25, 0.08, 0.25), trim, "cylinder")
			add_visual_part(parts, Vector3(0, 0.82, 0.04), Vector3(0.68, 0.66, 0.52), color)
			add_visual_part(parts, Vector3(0, 0.96, -0.27), Vector3(0.6, 0.34, 0.1), plate)
			add_visual_part(parts, Vector3(0, 1.42, -0.02), Vector3(0.42, 0.34, 0.4), steel)
			add_visual_part(parts, Vector3(0, 1.42, -0.24), Vector3(0.3, 0.08, 0.04), optic)
			add_visual_part(parts, Vector3(0, 1.12, 0.42), Vector3(0.76, 0.58, 0.3), plate)
			add_visual_part(parts, Vector3(0, 1.14, 0.59), Vector3(0.58, 0.42, 0.18), Color("d99452"))
			add_visual_part(parts, Vector3(0, 1.46, 0.57), Vector3(0.48, 0.12, 0.12), trim)
		"regenerator":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.25, 0.26, 0.02), Vector3(0.29, 0.48, 0.34), joint)
				add_visual_part(parts, Vector3(side * 0.27, 0.1, -0.06), Vector3(0.37, 0.15, 0.44), steel)
				add_visual_part(parts, Vector3(side * 0.55, 0.88, 0.04), Vector3(0.32, 0.47, 0.53), plate)
				add_visual_part(parts, Vector3(side * 0.57, 0.9, -0.25), Vector3(0.22, 0.34, 0.12), trim)
				add_visual_part(parts, Vector3(side * 0.47, 1.15, 0.31), Vector3(0.21, 0.46, 0.22), Color("329d89"), "cylinder")
				add_visual_part(parts, Vector3(side * 0.47, 1.15, 0.31), Vector3(0.25, 0.09, 0.25), Color("79e4bd"), "cylinder")
			add_visual_part(parts, Vector3(0, 0.81, 0.03), Vector3(0.9, 0.75, 0.65), color)
			add_visual_part(parts, Vector3(0, 0.96, -0.34), Vector3(0.76, 0.46, 0.14), plate)
			add_visual_part(parts, Vector3(0, 0.97, -0.43), Vector3(0.52, 0.22, 0.05), steel)
			add_visual_part(parts, Vector3(0, 0.97, -0.47), Vector3(0.26, 0.18, 0.06), Color("75edc2"), "cylinder")
			add_visual_part(parts, Vector3(0, 1.41, 0.02), Vector3(0.5, 0.38, 0.48), joint)
			add_visual_part(parts, Vector3(0, 1.42, -0.25), Vector3(0.33, 0.09, 0.04), Color("b0ffd8"))
			add_visual_part(parts, Vector3(0, 1.18, 0.4), Vector3(0.54, 0.08, 0.08), Color("61c8a5"))
		"exploder":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.22, 0.31, 0.03), Vector3(0.22, 0.55, 0.26), joint)
				add_visual_part(parts, Vector3(side * 0.43, 0.9, 0.05), Vector3(0.2, 0.42, 0.3), plate)
				add_visual_part(parts, Vector3(side * 0.27, 1.02, 0.28), Vector3(0.22, 0.48, 0.22), trim, "cylinder")
				add_visual_part(parts, Vector3(side * 0.27, 1.02, 0.28), Vector3(0.25, 0.09, 0.25), Color("492c2c"), "cylinder")
			add_visual_part(parts, Vector3(0, 0.84, 0.02), Vector3(0.72, 0.72, 0.56), color)
			add_visual_part(parts, Vector3(0, 1.35, -0.02), Vector3(0.39, 0.33, 0.36), plate)
			add_visual_part(parts, Vector3(0, 1.34, -0.22), Vector3(0.25, 0.08, 0.035), Color("ffe59b"))
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.19, 0.91, -0.3), Vector3(0.12, 0.58, 0.045), Color("303438"), "box", Vector3(0, 0, side * -0.38))
			add_visual_part(parts, Vector3(0, 0.89, -0.31), Vector3(0.31, 0.24, 0.06), Color("ffbf78"), "cylinder")
		"boss":
			for side in [-1, 1]:
				add_visual_part(parts, Vector3(side * 0.25, 0.28, 0.04), Vector3(0.3, 0.53, 0.35), joint)
				add_visual_part(parts, Vector3(side * 0.3, 0.1, -0.08), Vector3(0.38, 0.16, 0.46), steel)
				add_visual_part(parts, Vector3(side * 0.48, 1.12, 0.02), Vector3(0.34, 0.48, 0.57), plate)
				add_visual_part(parts, Vector3(side * 0.48, 1.14, -0.3), Vector3(0.25, 0.36, 0.14), steel)
				add_visual_part(parts, Vector3(side * 0.25, 1.39, 0.3), Vector3(0.22, 0.38, 0.22), Color("ff8b4a"), "cylinder", Vector3(0, 0, side * -0.16))
				add_visual_part(parts, Vector3(side * 0.52, 0.78, -0.36), Vector3(0.2, 0.24, 0.18), trim)
			add_visual_part(parts, Vector3(0, 0.83, 0.03), Vector3(0.86, 0.72, 0.61), color)
			add_visual_part(parts, Vector3(0, 0.98, -0.34), Vector3(0.82, 0.46, 0.15), plate)
			add_visual_part(parts, Vector3(0, 0.99, -0.44), Vector3(0.52, 0.24, 0.05), steel)
			add_visual_part(parts, Vector3(0, 0.99, -0.48), Vector3(0.22, 0.22, 0.08), Color("ff9a64"), "cylinder")
			add_visual_part(parts, Vector3(0, 1.45, -0.04), Vector3(0.49, 0.35, 0.44), joint)
			add_visual_part(parts, Vector3(0, 1.45, -0.27), Vector3(0.35, 0.1, 0.04), Color("e9a7dc"))
			add_visual_part(parts, Vector3(0, 1.62, 0.13), Vector3(0.26, 0.08, 0.28), trim)
	return parts

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
	update_idle_turrets(delta)
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
