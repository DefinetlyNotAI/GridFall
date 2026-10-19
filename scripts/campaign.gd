extends Node3D

const World = preload("res://scripts/world.gd")
const WIDTH = 25
const HEIGHT = 20
const TILE_SIZE = 3.0
const TOTAL_STAGES = 20
const STAGES: Array[Dictionary] = [
	{"name": "Orientation Wing", "hint": "Clear the staggered decks, then tap the release console.", "route": [Vector2i(3, 15), Vector2i(7, 15), Vector2i(11, 13), Vector2i(15, 13), Vector2i(20, 10)], "checkpoints": [2], "switches": [3], "turrets": [Vector2i(11, 6)], "cover": [Vector2i(13, 9)], "deck": 3, "theme": 0},
	{"name": "Vector Basin", "hint": "Dash the long cross-gap; two consoles unlock the exit.", "route": [Vector2i(3, 4), Vector2i(3, 8), Vector2i(7, 8), Vector2i(11, 6), Vector2i(15, 6), Vector2i(20, 9)], "checkpoints": [2, 4], "switches": [1, 4], "turrets": [Vector2i(8, 14), Vector2i(17, 14)], "cover": [Vector2i(9, 9), Vector2i(16, 10)], "deck": 3, "theme": 1},
	{"name": "Weighted Drop", "hint": "Take the raised relay and slam onto the low return deck.", "route": [Vector2i(3, 15), Vector2i(7, 15), Vector2i(11, 12), Vector2i(14, 12), Vector2i(17, 9), Vector2i(21, 9)], "heights": [0.0, 0.8, 1.3, 0.0, 0.0, 0.0], "checkpoints": [3], "switches": [2], "turrets": [Vector2i(8, 5), Vector2i(18, 15)], "cover": [Vector2i(13, 9)], "deck": 3, "theme": 2},
	{"name": "Return Rail", "hint": "Use the side walls to wall-jump through the narrow dogleg.", "route": [Vector2i(3, 4), Vector2i(7, 4), Vector2i(7, 8), Vector2i(11, 8), Vector2i(15, 11), Vector2i(20, 11)], "checkpoints": [2, 4], "switches": [3], "turrets": [Vector2i(11, 15)], "cover": [Vector2i(9, 7), Vector2i(17, 9)], "walls": [Vector2i(8, 6), Vector2i(8, 7), Vector2i(8, 9)], "deck": 3, "theme": 3},
	{"name": "Tether Garden", "hint": "Reach the glowing anchor and grapple across the broken floor.", "route": [Vector2i(3, 15), Vector2i(7, 15), Vector2i(10, 12), Vector2i(14, 12), Vector2i(17, 8), Vector2i(21, 8)], "checkpoints": [2, 4], "switches": [4], "turrets": [Vector2i(9, 5), Vector2i(18, 14)], "cover": [Vector2i(13, 10)], "anchors": [Vector3i(12, 7, 4), Vector3i(18, 6, 4)], "deck": 3, "theme": 0},
	{"name": "Split Focus Room", "hint": "Cross both sightlines and release the two separated consoles.", "route": [Vector2i(3, 5), Vector2i(7, 5), Vector2i(11, 8), Vector2i(14, 8), Vector2i(18, 11), Vector2i(21, 15)], "checkpoints": [2, 4], "switches": [1, 4], "turrets": [Vector2i(8, 14), Vector2i(17, 4)], "cover": [Vector2i(9, 7), Vector2i(15, 10)], "deck": 2, "theme": 1},
	{"name": "Momentum Cask", "hint": "Build speed on the broad pads, then dash the narrow bridge.", "route": [Vector2i(3, 15), Vector2i(6, 15), Vector2i(10, 15), Vector2i(14, 12), Vector2i(18, 12), Vector2i(21, 8)], "checkpoints": [2, 4], "switches": [3], "turrets": [Vector2i(11, 5), Vector2i(19, 16)], "cover": [Vector2i(16, 10)], "deck": 3, "theme": 2},
	{"name": "Echo Shaft", "hint": "Climb the offset ledges and activate the upper relay.", "route": [Vector2i(3, 4), Vector2i(7, 4), Vector2i(7, 8), Vector2i(11, 8), Vector2i(15, 5), Vector2i(20, 5)], "heights": [0.0, 0.0, 0.7, 1.2, 0.5, 0.0], "checkpoints": [2, 4], "switches": [4], "turrets": [Vector2i(11, 14)], "cover": [Vector2i(13, 6)], "deck": 3, "theme": 3},
	{"name": "Wall Sector Nine", "hint": "Bounce between the blue wall faces before the sentry fires.", "route": [Vector2i(3, 14), Vector2i(7, 14), Vector2i(7, 10), Vector2i(11, 10), Vector2i(15, 7), Vector2i(19, 7)], "checkpoints": [2, 4], "switches": [3], "turrets": [Vector2i(11, 4), Vector2i(18, 15)], "cover": [Vector2i(9, 9)], "walls": [Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 11), Vector2i(8, 12)], "deck": 2, "theme": 0},
	{"name": "Amber Crosswind", "hint": "Wait behind the fins, then dash across the exposed diagonal.", "route": [Vector2i(3, 4), Vector2i(6, 4), Vector2i(10, 7), Vector2i(14, 7), Vector2i(18, 10), Vector2i(21, 14)], "checkpoints": [2, 4], "switches": [1, 4], "turrets": [Vector2i(9, 14), Vector2i(17, 4)], "cover": [Vector2i(11, 6), Vector2i(16, 9)], "deck": 2, "theme": 1},
	{"name": "Counterweight Gallery", "hint": "Use the high deck to drop onto the lower switch platform.", "route": [Vector2i(3, 15), Vector2i(7, 15), Vector2i(11, 12), Vector2i(15, 12), Vector2i(18, 8), Vector2i(21, 8)], "heights": [0.0, 0.8, 1.4, 0.0, 0.0, 0.0], "checkpoints": [3], "switches": [2, 4], "turrets": [Vector2i(8, 5), Vector2i(17, 15)], "cover": [Vector2i(13, 10)], "deck": 3, "theme": 2},
	{"name": "Suspension Test", "hint": "Grapple from the central anchor to the far suspended pad.", "route": [Vector2i(3, 5), Vector2i(7, 5), Vector2i(10, 8), Vector2i(14, 8), Vector2i(17, 12), Vector2i(21, 12)], "checkpoints": [2, 4], "switches": [2], "turrets": [Vector2i(10, 14), Vector2i(18, 4)], "cover": [Vector2i(15, 10)], "anchors": [Vector3i(11, 6, 4), Vector3i(17, 9, 4)], "deck": 2, "theme": 3},
	{"name": "Quiet Observatory", "hint": "Use the broken sightline to reach the observation release.", "route": [Vector2i(3, 14), Vector2i(7, 14), Vector2i(7, 10), Vector2i(11, 10), Vector2i(15, 13), Vector2i(20, 13)], "checkpoints": [2, 4], "switches": [3, 4], "turrets": [Vector2i(11, 4)], "cover": [Vector2i(9, 9), Vector2i(16, 12)], "deck": 3, "theme": 0},
	{"name": "Prism Transit", "hint": "Chain the short jumps and cross the final exposed lane in one dash.", "route": [Vector2i(3, 4), Vector2i(6, 4), Vector2i(9, 7), Vector2i(12, 7), Vector2i(15, 10), Vector2i(18, 10), Vector2i(21, 14)], "checkpoints": [3, 5], "switches": [2, 5], "turrets": [Vector2i(8, 14), Vector2i(18, 4)], "cover": [Vector2i(13, 9), Vector2i(16, 11)], "deck": 2, "theme": 1},
	{"name": "Slam Chamber", "hint": "Drop from the raised lip and slam onto the low marked deck.", "route": [Vector2i(3, 14), Vector2i(7, 14), Vector2i(11, 11), Vector2i(14, 11), Vector2i(18, 8), Vector2i(21, 8)], "heights": [0.0, 0.8, 1.5, 0.0, 0.0, 0.0], "checkpoints": [3], "switches": [4], "turrets": [Vector2i(8, 5), Vector2i(18, 15)], "cover": [Vector2i(12, 9)], "deck": 3, "theme": 2},
	{"name": "Double Helix", "hint": "Follow the alternating arms and open both lift controls.", "route": [Vector2i(3, 5), Vector2i(7, 5), Vector2i(10, 8), Vector2i(10, 12), Vector2i(14, 12), Vector2i(18, 9), Vector2i(21, 13)], "heights": [0.0, 0.0, 0.5, 1.0, 0.0, 0.0, 0.0], "checkpoints": [3, 5], "switches": [2, 5], "turrets": [Vector2i(8, 15), Vector2i(17, 4)], "cover": [Vector2i(12, 10), Vector2i(17, 11)], "deck": 2, "theme": 3},
	{"name": "Anchor Circuit", "hint": "Use the high anchors to skip the inner turret lane.", "route": [Vector2i(3, 14), Vector2i(7, 14), Vector2i(10, 11), Vector2i(14, 11), Vector2i(17, 7), Vector2i(21, 7)], "checkpoints": [2, 4], "switches": [1, 4], "turrets": [Vector2i(11, 4), Vector2i(18, 15)], "cover": [Vector2i(13, 9)], "anchors": [Vector3i(11, 8, 4), Vector3i(18, 9, 4)], "deck": 2, "theme": 0},
	{"name": "Redline Gallery", "hint": "Alternate cover and sprint windows; touch the two far consoles.", "route": [Vector2i(3, 4), Vector2i(7, 4), Vector2i(7, 8), Vector2i(11, 8), Vector2i(15, 11), Vector2i(18, 11), Vector2i(21, 15)], "checkpoints": [2, 5], "switches": [3, 5], "turrets": [Vector2i(11, 15), Vector2i(18, 4)], "cover": [Vector2i(9, 7), Vector2i(16, 10)], "deck": 2, "theme": 1},
	{"name": "Last Calibration", "hint": "Climb, tether, and cross the final long gap to the control room.", "route": [Vector2i(3, 14), Vector2i(7, 14), Vector2i(10, 11), Vector2i(14, 11), Vector2i(17, 8), Vector2i(21, 8)], "heights": [0.0, 0.6, 1.2, 0.0, 0.6, 0.0], "checkpoints": [2, 4], "switches": [2, 4], "turrets": [Vector2i(8, 5), Vector2i(18, 15)], "cover": [Vector2i(13, 10), Vector2i(19, 7)], "anchors": [Vector3i(12, 7, 4)], "deck": 2, "theme": 2},
	{"name": "Keystone Control", "hint": "Reach the final console, then cross the gate to end the trial.", "route": [Vector2i(3, 5), Vector2i(7, 5), Vector2i(10, 8), Vector2i(14, 8), Vector2i(17, 12), Vector2i(21, 12)], "checkpoints": [2, 4], "switches": [1, 3, 4], "turrets": [Vector2i(9, 15), Vector2i(18, 4)], "cover": [Vector2i(12, 7), Vector2i(16, 11)], "anchors": [Vector3i(12, 5, 4), Vector3i(18, 9, 4)], "deck": 2, "theme": 3}
]

var game
var stage_index = 0
var checkpoint_index = 0
var finished = false
var active = false
var stage_root: Node3D
var _turrets: Array[Dictionary] = []
var _switches: Array[Dictionary] = []
var _checkpoint_nodes: Array[Dictionary] = []
var _activated_switches: Dictionary = {}
var _exit_locked_notice = false
var _exit_save_failed = false
var _respawn_grace = 0.0

func setup(owner_game) -> void:
	game = owner_game

func stage_count() -> int:
	return TOTAL_STAGES

func stage_info(index: int = -1) -> Dictionary:
	var selected = stage_index if index < 0 else posmod(index, TOTAL_STAGES)
	var spec: Dictionary = STAGES[selected]
	return {
		"index": selected,
		"number": selected + 1,
		"total": TOTAL_STAGES,
		"name": str(spec.name),
		"hint": str(spec.hint),
		"switches": spec.get("switches", []).size(),
		"checkpoints": spec.get("checkpoints", []).size(),
		"turrets": spec.get("turrets", []).size()
	}

func stage_map(index: int) -> Dictionary:
	var selected = posmod(index, TOTAL_STAGES)
	var spec: Dictionary = STAGES[selected]
	var world = World.new()
	var layers = {"ground": {}, "structure": {}, "height": {}, "markers": {}, "objects": {}, "decoration": {}, "lighting": {}}
	var route: Array = spec.route
	var deck = int(spec.get("deck", 3))
	var radius = int(deck / 2)
	var terrain = ["concrete", "metal", "stone", "concrete"][int(spec.get("theme", 0)) % 4]
	for route_index in route.size():
		var center: Vector2i = route[route_index]
		var elevation = _route_elevation(spec, route_index)
		for y in range(center.y - radius, center.y - radius + deck):
			for x in range(center.x - radius, center.x - radius + deck):
				_add_floor(layers, Vector2i(x, y), terrain)
				if elevation > 0:
					layers.structure[world.cell_key(Vector2i(x, y))] = {"type": "platform", "height": 0.5, "elevation": elevation, "health": 240, "max_health": 240}
	for point_value in spec.get("turrets", []):
		var turret_point: Vector2i = point_value
		for y in range(turret_point.y - 1, turret_point.y + 2):
			for x in range(turret_point.x - 1, turret_point.x + 2):
				_add_floor(layers, Vector2i(x, y), terrain)
	for point_value in spec.get("cover", []):
		var cover_point: Vector2i = point_value
		_add_floor(layers, cover_point, terrain)
		var cover_key = "%d,%d" % [cover_point.x, cover_point.y]
		layers.structure[cover_key] = {"type": "pillar", "height": 3.5, "health": 300, "max_health": 300, "locked": true}
	for point_value in spec.get("walls", []):
		var wall_point: Vector2i = point_value
		_add_floor(layers, wall_point, terrain)
		var wall_key = "%d,%d" % [wall_point.x, wall_point.y]
		layers.structure[wall_key] = {"type": "reinforced", "height": 3.0, "health": 750, "max_health": 750, "locked": true}
	var start_point: Vector2i = route[0]
	var exit_point: Vector2i = route[-1]
	layers.markers["%d,%d" % [start_point.x, start_point.y]] = {"type": "player"}
	layers.markers["%d,%d" % [exit_point.x, exit_point.y]] = {"type": "objective"}
	for checkpoint_route_index in spec.get("checkpoints", []):
		var checkpoint: Vector2i = route[int(checkpoint_route_index)]
		layers.lighting["%d,%d" % [checkpoint.x, checkpoint.y]] = {"type": "light", "color": "6bd8c6", "energy": 1.2, "range": 8}
	layers.lighting["%d,%d" % [exit_point.x, exit_point.y]] = {"type": "light", "color": "f3c678", "energy": 1.4, "range": 10}
	return {
		"version": 2,
		"id": "campaign_%02d" % selected,
		"name": "Trial %02d · %s" % [selected + 1, spec.name],
		"description": str(spec.hint),
		"author": "GRIDFALL Research Division",
		"width": WIDTH,
		"height": HEIGHT,
		"seed": 850000 + selected,
		"theme": int(spec.get("theme", 0)),
		"rules": world.default_rules(),
		"layers": layers,
		"build": [],
		"events": [],
		"campaign_stage": selected
	}

func start(index: int = 0) -> void:
	if game == null or not is_instance_valid(game):
		return
	clear()
	var progress = _progress()
	stage_index = clampi(index, 0, int(progress.unlocked) - 1)
	finished = false
	var saved_stage = int(progress.stage)
	checkpoint_index = int(progress.checkpoint) if saved_stage == stage_index else 0
	var saved: Dictionary = STAGES[stage_index]
	checkpoint_index = clampi(checkpoint_index, 0, saved.get("checkpoints", []).size())
	progress.stage = stage_index
	progress.checkpoint = checkpoint_index
	if saved_stage != stage_index: progress.switches = 0
	_save_progress(progress)
	_build_stage()
	_set_player_at_checkpoint()
	_respawn_grace = 0.65
	active = true

func retry() -> void:
	if not active or game == null:
		return
	var progress = _progress()
	progress.deaths = mini(1000000000, int(progress.deaths) + 1)
	_save_progress(progress)
	_build_stage()
	_set_player_at_checkpoint()
	game.health = game.max_health
	game.shield = 0
	game.hurt_timer = 0.45
	_respawn_grace = 0.65
	if game.state in ["results", "completion", "preparation"]:
		game.state = "wave"
	if is_instance_valid(game.ui):
		game.ui.notify("Trial reset at the last checkpoint.")

func clear() -> void:
	active = false
	_turrets.clear()
	_switches.clear()
	_checkpoint_nodes.clear()
	_activated_switches.clear()
	_exit_locked_notice = false
	if is_instance_valid(stage_root):
		remove_child(stage_root)
		stage_root.queue_free()
	stage_root = null

func interact() -> bool:
	if not active or not is_instance_valid(game.player):
		return false
	var nearest_index = -1
	var nearest_distance = 4.2
	for index in _switches.size():
		if _activated_switches.has(index):
			continue
		var distance = game.player.position.distance_to(_switches[index].point)
		if distance <= nearest_distance:
			nearest_index = index
			nearest_distance = distance
	if nearest_index < 0:
		return false
	_activate_switch(nearest_index)
	var progress = _progress()
	progress.switches = _switch_mask()
	var saved = _save_progress(progress)
	var activated = _activated_switches.size()
	var required = _switches.size()
	if saved: game.ui.notify("Console %d/%d enabled%s" % [activated, required, " · exit released" if activated == required else ""])
	return true

func update(delta: float) -> void:
	if not active or game == null or game.mode != "campaign" or game.state != "wave" or not is_instance_valid(game.player):
		return
	_respawn_grace = maxf(0.0, _respawn_grace - delta)
	_update_checkpoints()
	_update_turrets(delta)
	if not active or game.state != "wave":
		return
	var exit = _route_point(STAGES[stage_index].route.size() - 1)
	if game.player.position.distance_to(exit) <= 3.6:
		if _activated_switches.size() < _switches.size():
			if not _exit_locked_notice:
				_exit_locked_notice = true
				game.ui.notify("Exit locked. Activate the chamber consoles with E.")
		elif not _exit_save_failed:
			_advance_stage()
	else:
		_exit_locked_notice = false
		_exit_save_failed = false

func _build_stage() -> void:
	if is_instance_valid(stage_root):
		remove_child(stage_root)
		stage_root.queue_free()
	stage_root = Node3D.new()
	stage_root.name = "CampaignStage"
	add_child(stage_root)
	_turrets.clear()
	_switches.clear()
	_checkpoint_nodes.clear()
	_activated_switches.clear()
	_exit_locked_notice = false
	_exit_save_failed = false
	var spec: Dictionary = STAGES[stage_index]
	var route: Array = spec.route
	for checkpoint_order in spec.get("checkpoints", []).size():
		var route_index = int(spec.checkpoints[checkpoint_order])
		var point = _route_point(route_index)
		var pad = game.visuals.cylinder(stage_root, point + Vector3.UP * 0.035, 1.0, 0.07, Color("478f88"), 0.4)
		var light = OmniLight3D.new()
		light.position = point + Vector3.UP * 0.3
		light.light_color = Color("6bd8c6")
		light.omni_range = 6
		light.light_energy = 0.65
		stage_root.add_child(light)
		if checkpoint_order + 1 <= checkpoint_index:
			pad.material_override = game.visuals.material(Color("6bd8c6"), 1.2, 0.4)
		_checkpoint_nodes.append({"route_index": route_index, "order": checkpoint_order + 1, "mesh": pad, "light": light})
	for switch_order in spec.get("switches", []).size():
		var route_index = int(spec.switches[switch_order])
		var point = _route_point(route_index)
		var console = Node3D.new()
		console.position = point
		stage_root.add_child(console)
		game.visuals.cylinder(console, Vector3(0, 0.14, 0), 0.58, 0.28, Color("b37f48"), 0.4)
		var mesh = game.visuals.box(console, Vector3(0, 0.55, 0), Vector3(0.52, 0.48, 0.28), Color("ffbf71"), 0.6)
		var light = OmniLight3D.new()
		light.position = Vector3(0, 0.85, 0)
		light.light_color = Color("ffbf71")
		light.omni_range = 3.5
		light.light_energy = 0.8
		console.add_child(light)
		_switches.append({"point": point, "mesh": mesh, "light": light, "console": console})
	_restore_switches()
	_build_exit(_route_point(route.size() - 1))
	_build_turrets(spec)
	_build_anchors(spec)
	_build_enclosure()
	_build_sign(spec)
	if is_instance_valid(game.ui):
		game.ui.notify("Trial %02d · %s" % [stage_index + 1, spec.name])

func _build_enclosure() -> void:
	var shell = StaticBody3D.new()
	shell.name = "ChamberShell"
	shell.collision_layer = 1
	shell.collision_mask = 0
	stage_root.add_child(shell)
	var room_width = WIDTH * TILE_SIZE
	var room_depth = HEIGHT * TILE_SIZE
	var room_height = 9.0
	var wall_color = Color("485960")
	_add_shell_box(shell, Vector3(TILE_SIZE * 0.5, room_height * 0.5, room_depth * 0.5), Vector3(0.5, room_height, room_depth), wall_color)
	_add_shell_box(shell, Vector3(room_width - TILE_SIZE * 0.5, room_height * 0.5, room_depth * 0.5), Vector3(0.5, room_height, room_depth), wall_color)
	_add_shell_box(shell, Vector3(room_width * 0.5, room_height * 0.5, TILE_SIZE * 0.5), Vector3(room_width, room_height, 0.5), wall_color)
	_add_shell_box(shell, Vector3(room_width * 0.5, room_height * 0.5, room_depth - TILE_SIZE * 0.5), Vector3(room_width, room_height, 0.5), wall_color)
	_add_shell_box(shell, Vector3(room_width * 0.5, room_height, room_depth * 0.5), Vector3(room_width, 0.2, room_depth), Color("53686d"))
	for x in range(4, WIDTH - 2, 5):
		game.visuals.box(shell, Vector3((x + 0.5) * TILE_SIZE, room_height - 0.16, room_depth * 0.5), Vector3(0.08, 0.04, room_depth - TILE_SIZE * 2), Color("91b1aa"), 0.35)
	for x in range(5, WIDTH - 2, 7):
		var light = OmniLight3D.new()
		light.position = Vector3((x + 0.5) * TILE_SIZE, room_height - 0.45, room_depth * 0.5)
		light.light_color = Color("b7d4ce")
		light.omni_range = 18
		light.light_energy = 0.7
		shell.add_child(light)

func _add_shell_box(parent: StaticBody3D, point: Vector3, size: Vector3, color: Color) -> void:
	game.visuals.box(parent, point, size, color, 0.05)
	game.visuals.collision(parent, size, point)

func _build_sign(spec: Dictionary) -> void:
	var start_point: Vector2i = spec.route[0]
	var sign = Label3D.new()
	sign.text = "GRIDFALL TEST %02d  /  %s\n%s" % [stage_index + 1, spec.name, spec.hint]
	sign.position = game.world.position(start_point, 3.7)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 30
	sign.pixel_size = 0.006
	sign.outline_size = 7
	sign.outline_modulate = Color("101c25")
	sign.modulate = Color("dae3dd")
	stage_root.add_child(sign)

func _build_exit(point: Vector3) -> void:
	var gate = Node3D.new()
	gate.position = point
	stage_root.add_child(gate)
	for x in [-0.8, 0.8]:
		game.visuals.box(gate, Vector3(x, 1.45, 0), Vector3(0.16, 2.9, 0.18), Color("6bd8c6"), 0.8)
	game.visuals.box(gate, Vector3(0, 2.82, 0), Vector3(1.75, 0.16, 0.18), Color("6bd8c6"), 0.8)
	game.visuals.box(gate, Vector3(0, 0.12, 0), Vector3(1.7, 0.12, 1.7), Color("f3c678"), 0.5)
	var label = Label3D.new()
	label.text = "EXIT  %02d" % (stage_index + 1)
	label.position = Vector3(0, 3.3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 38
	label.pixel_size = 0.007
	label.outline_size = 7
	label.outline_modulate = Color("101c25")
	label.modulate = Color("f3c678")
	gate.add_child(label)

func _build_turrets(spec: Dictionary) -> void:
	var turret_index = 0
	for point_value in spec.get("turrets", []):
		var point: Vector2i = point_value
		var turret = StaticBody3D.new()
		turret.position = game.world.position(point)
		turret.collision_layer = 1
		turret.collision_mask = 0
		stage_root.add_child(turret)
		game.visuals.cylinder(turret, Vector3(0, 0.22, 0), 0.85, 0.44, Color("293d48"), 0.1)
		game.visuals.cylinder(turret, Vector3(0, 0.52, 0), 0.62, 0.2, Color("596a70"))
		var shape = CollisionShape3D.new()
		var collision = CylinderShape3D.new()
		collision.radius = 0.7
		collision.height = 1.2
		shape.shape = collision
		shape.position.y = 0.6
		turret.add_child(shape)
		var head = Node3D.new()
		head.position.y = 0.88
		turret.add_child(head)
		game.visuals.box(head, Vector3(0, 0.12, 0), Vector3(0.74, 0.48, 0.72), Color("a75149"), 0.15)
		game.visuals.box(head, Vector3(0, 0.1, -0.66), Vector3(0.22, 0.2, 0.82), Color("d37a5c"), 0.45)
		var eye = game.visuals.box(head, Vector3(0, 0.15, -1.09), Vector3(0.2, 0.16, 0.08), Color("ff6257"), 1.8)
		_turrets.append({
			"body": turret,
			"head": head,
			"eye": eye,
			"cooldown": 1.3 + turret_index * 0.9,
			"charge": 0.0,
			"interval": 3.15 + turret_index * 0.45,
			"damage": 18.0 + turret_index * 2.0,
			"target": Vector3.ZERO,
			"firing": false
		})
		turret_index += 1

func _build_anchors(spec: Dictionary) -> void:
	for point_value in spec.get("anchors", []):
		var point: Vector3i = point_value
		var body = StaticBody3D.new()
		body.position = game.world.position(Vector2i(point.x, point.y), float(point.z))
		body.collision_layer = 1
		body.collision_mask = 0
		stage_root.add_child(body)
		var shape = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 0.42
		shape.shape = sphere
		shape.position.y = 0.3
		body.add_child(shape)
		game.visuals.cylinder(body, Vector3(0, -0.2, 0), 0.16, 0.8, Color("596e74"))
		game.visuals.cylinder(body, Vector3(0, 0.3, 0), 0.62, 0.12, Color("6bd8c6"), 1.0)
		game.visuals.box(body, Vector3(0, 0.3, 0), Vector3(0.24, 0.24, 0.24), Color("8cf0dc"), 1.5)

func _update_checkpoints() -> void:
	var player_position: Vector3 = game.player.position
	for index in _checkpoint_nodes.size():
		var checkpoint: Dictionary = _checkpoint_nodes[index]
		if int(checkpoint.order) <= checkpoint_index:
			continue
		if player_position.distance_to(_route_point(int(checkpoint.route_index))) > 2.7:
			continue
		var pending_console = false
		for switch_index in _switches.size():
			if int(STAGES[stage_index].switches[switch_index]) <= int(checkpoint.route_index) and not _activated_switches.has(switch_index):
				pending_console = true
		if pending_console:
			if not checkpoint.get("warned", false):
				checkpoint.warned = true
				game.ui.notify("Enable earlier consoles before saving this checkpoint. U returns to the previous pad.")
			continue
		checkpoint_index = int(checkpoint.order)
		var progress = _progress()
		progress.stage = stage_index
		progress.checkpoint = checkpoint_index
		progress.switches = _switch_mask()
		var saved = _save_progress(progress)
		checkpoint.mesh.material_override = game.visuals.material(Color("6bd8c6"), 1.2, 0.4)
		if saved: game.ui.notify("Checkpoint %d saved." % checkpoint_index)

func _restore_switches() -> void:
	var mask = int(_progress().switches)
	for switch_index in _switches.size():
		if mask & (1 << switch_index):
			_activate_switch(switch_index)

func _switch_mask() -> int:
	var mask = 0
	for switch_index in _activated_switches: mask |= 1 << int(switch_index)
	return mask

func _activate_switch(index: int) -> void:
	if _activated_switches.has(index):
		return
	_activated_switches[index] = true
	_switches[index].mesh.material_override = game.visuals.material(Color("6bd8c6"), 1.4, 0.45)
	_switches[index].light.light_color = Color("6bd8c6")

func _update_turrets(delta: float) -> void:
	for turret in _turrets:
		if not is_instance_valid(turret.body):
			continue
		var player_point: Vector3 = game.player.camera.global_position
		var muzzle = turret.head.global_position - turret.head.global_basis.z * 1.12
		var distance = muzzle.distance_to(player_point)
		if distance > 38.0:
			turret.firing = false
			turret.charge = 0.0
			turret.cooldown = maxf(0.2, float(turret.cooldown) - delta)
			continue
		if turret.firing:
			var excluded: Array[RID] = [turret.body.get_rid()]
			if not game.sight(muzzle, turret.target, excluded):
				turret.firing = false
				turret.charge = 0.0
				turret.cooldown = 0.6
				turret.eye.material_override = game.visuals.material(Color("ff6257"), 1.8)
				continue
			turret.head.look_at(turret.target, Vector3.UP)
			turret.charge = maxf(0.0, float(turret.charge) - delta)
			var charge_ratio = clampf(floorf((1.0 - float(turret.charge) / 1.35) * 12.0) / 12.0, 0.0, 1.0)
			var color = Color("f3c678").lerp(Color("ff514d"), clampf(charge_ratio, 0.0, 1.0))
			turret.eye.material_override = game.visuals.material(color, 1.2 + charge_ratio)
			game.visuals.beam(muzzle, turret.target, color, 0.04, 0.13)
			if turret.charge <= 0.0:
				var current = game.player.camera.global_position
				var ray = turret.target - muzzle
				var amount = clampf((current - muzzle).dot(ray) / maxf(0.001, ray.length_squared()), 0.0, 1.0)
				var closest = muzzle + ray * amount
				game.visuals.beam(muzzle, turret.target, Color("ff6257"), 0.11, 0.24)
				if _respawn_grace <= 0.0 and current.distance_to(closest) < 1.25 and game.sight(muzzle, current, excluded):
					var health_before = game.health
					game.damage_player(float(turret.damage))
					if game.health > health_before:
						return
				turret.firing = false
				turret.cooldown = float(turret.interval)
				turret.eye.material_override = game.visuals.material(Color("ff6257"), 1.8)
			continue
		turret.cooldown = maxf(0.0, float(turret.cooldown) - delta)
		var excluded: Array[RID] = [turret.body.get_rid()]
		if game.sight(muzzle, player_point, excluded):
			turret.head.look_at(player_point, Vector3.UP)
			if turret.cooldown <= 0.0:
				turret.firing = true
				turret.charge = 1.35
				turret.target = player_point
				turret.eye.material_override = game.visuals.material(Color("f3c678"), 1.3)
		else:
			turret.eye.material_override = game.visuals.material(Color("ff6257"), 1.8)

func _advance_stage() -> void:
	if finished or not active:
		return
	var progress = _progress()
	progress.completed = maxi(int(progress.completed), stage_index + 1)
	progress.unlocked = mini(TOTAL_STAGES, maxi(int(progress.unlocked), stage_index + 2))
	progress.stage = mini(TOTAL_STAGES - 1, stage_index + 1)
	progress.checkpoint = 0
	progress.switches = 0
	if not _save_progress(progress):
		_exit_save_failed = true
		return
	if stage_index + 1 < TOTAL_STAGES:
		active = false
		game.call_deferred("start_campaign_stage", stage_index + 1)
		return
	finished = true
	active = false
	game.state = "completion"
	game.ui.show_campaign_complete()

func _set_player_at_checkpoint() -> void:
	if not is_instance_valid(game.player):
		return
	var spec: Dictionary = STAGES[stage_index]
	var route_index = 0
	if checkpoint_index > 0:
		route_index = int(spec.checkpoints[checkpoint_index - 1])
	var point: Vector2i = spec.route[route_index]
	var platform = game.world.map.layers.structure.get(game.world.cell_key(point), {})
	var surface = float(platform.get("elevation", 0.0)) + (float(platform.get("height", 0.0)) if not platform.is_empty() else 0.0)
	game.player.position = game.world.position(point, surface + 0.1)
	game.player.velocity = Vector3.ZERO
	game.player.dash_energy = 3.0
	game.player.dash_timer = 0.0
	game.player.slam_active = false
	game.player.slide_active = false
	game.player.grapple_active = false
	game.player.grapple_cooldown = 0.0
	game.player.jump_buffer = 0.0
	game.player.coyote_timer = 0.0
	game.player.slam_jump_timer = 0.0
	game.player.stamina = 100.0
	game.player.wall_jumps = 0
	if route_index + 1 < spec.route.size():
		var next_point = _route_point(route_index + 1)
		next_point.y = game.player.position.y
		game.player.look_at(next_point, Vector3.UP)

func _route_point(route_index: int) -> Vector3:
	var spec: Dictionary = STAGES[stage_index]
	var point: Vector2i = spec.route[route_index]
	var key = game.world.cell_key(point)
	var platform: Dictionary = game.world.map.layers.structure.get(key, {})
	var surface = float(platform.get("elevation", 0.0)) + (float(platform.get("height", 0.0)) if not platform.is_empty() else 0.0)
	return game.world.position(point, surface + 0.08)

func _route_elevation(spec: Dictionary, route_index: int) -> float:
	var heights: Array = spec.get("heights", [])
	return float(heights[route_index]) if route_index < heights.size() else 0.0

func _add_floor(layers: Dictionary, point: Vector2i, terrain: String) -> void:
	if point.x < 0 or point.y < 0 or point.x >= WIDTH or point.y >= HEIGHT:
		return
	var key = "%d,%d" % [point.x, point.y]
	if not layers.ground.has(key):
		layers.ground[key] = {"type": terrain, "rotation": 0}

func _progress() -> Dictionary:
	var value: Variant = game.profile.data.get("campaign", {})
	if not value is Dictionary:
		value = {}
	return {
		"unlocked": clampi(int(value.get("unlocked", 1)), 1, TOTAL_STAGES),
		"completed": clampi(int(value.get("completed", 0)), 0, TOTAL_STAGES),
		"stage": clampi(int(value.get("stage", 0)), 0, TOTAL_STAGES - 1),
		"checkpoint": clampi(int(value.get("checkpoint", 0)), 0, 64),
		"switches": clampi(int(value.get("switches", 0)), 0, 7),
		"deaths": clampi(int(value.get("deaths", 0)), 0, 1000000000)
	}

func _save_progress(progress: Dictionary) -> bool:
	var old_value: Variant = game.profile.data.get("campaign", null)
	game.profile.data.campaign = progress.duplicate(true)
	if game.profile.save():
		return true
	if old_value == null:
		game.profile.data.erase("campaign")
	else:
		game.profile.data.campaign = old_value
	if is_instance_valid(game.ui):
		game.ui.notify("Campaign progress could not be saved: " + game.profile.error)
	return false
