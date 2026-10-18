extends Node3D

var visuals
var groups: Dictionary = {}
var records: Dictionary = {}
var material: ShaderMaterial

func setup(owner_visuals) -> void:
	visuals = owner_visuals
	material = ShaderMaterial.new()
	material.shader = preload("res://scripts/enemy_instances.gdshader")

func clear() -> void:
	for group in groups.values(): group.node.queue_free()
	groups.clear()
	records.clear()

func group_key(record: Dictionary) -> String:
	var position: Vector3 = record.body.position
	return "%s_%s_%d_%d" % [record.kind, record.color, floori(position.x / 24.0), floori(position.z / 24.0)]

func add_enemy(data: Dictionary, body: CharacterBody3D, scale_value: float) -> void:
	records[data.uid] = {"body": body, "kind": data.type, "color": data.color, "scale": scale_value, "group": "", "slot": -1, "last_position": body.position, "last_time": visuals.game.elapsed, "speed": data.speed}
	body.tree_exiting.connect(func():
		if records.has(data.uid) and records[data.uid].body == body: remove_enemy(data.uid))
	sync(data.uid)

func remove_enemy(uid: int) -> void:
	if not records.has(uid): return
	leave_group(uid)
	records.erase(uid)

func leave_group(uid: int) -> void:
	var record: Dictionary = records[uid]
	if record.group == "": return
	var group: Dictionary = groups[record.group]
	var last = int(group.members.back())
	group.members[record.slot] = last
	records[last].slot = record.slot
	group.members.pop_back()
	group.mesh.visible_instance_count = group.members.size()
	if last != uid: write_transform(last)
	record.group = ""

func sync(uid: int) -> void:
	if not records.has(uid): return
	var record: Dictionary = records[uid]
	var key = group_key(record)
	if key != record.group:
		leave_group(uid)
		if not groups.has(key):
			var mesh = MultiMesh.new()
			mesh.transform_format = MultiMesh.TRANSFORM_3D
			mesh.use_colors = true
			mesh.use_custom_data = true
			mesh.mesh = visuals.enemy_mesh(record.kind, Color(record.color))
			mesh.instance_count = 32
			mesh.visible_instance_count = 0
			var node = MultiMeshInstance3D.new()
			node.multimesh = mesh
			node.material_override = material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.extra_cull_margin = 2.0
			add_child(node)
			groups[key] = {"node": node, "mesh": mesh, "members": []}
		var group: Dictionary = groups[key]
		record.group = key
		record.slot = group.members.size()
		group.members.append(uid)
		if group.members.size() > group.mesh.instance_count:
			group.mesh.instance_count *= 2
			for member in group.members: write_transform(member)
		group.mesh.visible_instance_count = group.members.size()
	write_transform(uid)

func write_transform(uid: int) -> void:
	var record: Dictionary = records[uid]
	var body: CharacterBody3D = record.body
	var transform = Transform3D(body.basis.scaled(Vector3.ONE * record.scale), body.position + body.get_node("Model").position)
	var mesh: MultiMesh = groups[record.group].mesh
	mesh.set_instance_transform(record.slot, transform)
	mesh.set_instance_color(record.slot, Color.WHITE)
	var now = float(visuals.game.elapsed)
	var interval = now - float(record.last_time)
	var motion = ((body.position - record.last_position) / interval).limit_length(record.speed) if interval > 0.0001 else Vector3.ZERO
	mesh.set_instance_custom_data(record.slot, Color(motion.x, motion.z, fmod(now, 8.0), 0))
	record.last_position = body.position
	record.last_time = now

func _process(_delta: float) -> void:
	if material and visuals.game != null: material.set_shader_parameter("simulation_time", fmod(visuals.game.elapsed, 8.0))
