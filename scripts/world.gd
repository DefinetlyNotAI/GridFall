extends RefCounted

const SIZE = 3.0
const Levels = preload("res://scripts/levels.gd")
const LEVEL_NAMES = ["The Foundry", "Relay Station", "Crossroads", "The Crucible", "Floodworks", "Skyline Yard"]
const RULES = {
	"budget_multiplier": {"default": 1.0, "min": 0.25, "max": 4.0},
	"spawn_interval": {"default": 1.0, "min": 0.1, "max": 5.0},
	"enemy_health": {"default": 1.0, "min": 0.25, "max": 4.0},
	"objective_health": {"default": 600.0, "min": 100.0, "max": 10000.0},
	"hazard_damage": {"default": 1.0, "min": 0.0, "max": 4.0},
	"sun_energy": {"default": 1.5, "min": 0.0, "max": 4.0},
	"fog_density": {"default": 0.006, "min": 0.0, "max": 0.05},
	"boss_interval": {"default": 10.0, "min": 2.0, "max": 100.0}
}
const TERRAIN = ["concrete", "grass", "dirt", "sand", "road", "metal", "stone", "water"]
const WALLS = ["wood", "brick", "concrete_wall", "steel", "reinforced", "glass", "permanent", "gate", "door", "window", "barricade", "platform", "ramp", "stairs", "pillar"]
const WALL_DEFS = {
	"wood": {"health": 100, "height": 2.2, "color": "77543c", "resistance": 0.0, "fire": 1.7},
	"brick": {"health": 220, "height": 2.8, "color": "805f52", "resistance": 0.2, "fire": 0.8},
	"concrete_wall": {"health": 350, "height": 2.8, "color": "68747b", "resistance": 0.4, "fire": 0.6},
	"steel": {"health": 500, "height": 2.8, "color": "526c79", "resistance": 0.3, "fire": 0.5},
	"reinforced": {"health": 750, "height": 3.0, "color": "344e5c", "resistance": 0.45, "fire": 0.4},
	"glass": {"health": 35, "height": 2.8, "color": "66bfd477", "resistance": 0.0, "fire": 1.0},
	"permanent": {"health": 0, "height": 3.5, "color": "384b59", "resistance": 1.0, "fire": 0.0},
	"gate": {"health": 0, "height": 3.0, "color": "c28048", "resistance": 1.0, "fire": 0.0},
	"door": {"health": 180, "height": 2.8, "color": "51656b", "resistance": 0.1, "fire": 0.8},
	"window": {"health": 150, "height": 2.8, "color": "637e87", "resistance": 0.15, "fire": 0.8},
	"barricade": {"health": 140, "height": 1.6, "color": "77624e", "resistance": 0.1, "fire": 1.4},
	"platform": {"health": 240, "height": 0.5, "color": "5a727e", "resistance": 0.2, "fire": 0.7},
	"ramp": {"health": 250, "height": 1.4, "color": "5a727e", "resistance": 0.2, "fire": 0.7},
	"stairs": {"health": 250, "height": 1.4, "color": "5a727e", "resistance": 0.2, "fire": 0.7},
	"pillar": {"health": 300, "height": 3.5, "color": "435d6b", "resistance": 0.25, "fire": 0.6}
}
const MARKERS = ["player", "enemy", "objective", "pad", "tower_pad", "structure_pad", "supply", "upgrade", "ammo", "generator", "chest", "shop"]
const HAZARDS = ["fire", "acid", "spikes", "electric", "slow", "mine"]
var map: Dictionary = {}
var construction: Dictionary = {}
var applied: Array = []
var flow: Dictionary = {}
var fields: Dictionary = {}
var nav_ms = 0.0
var nav_revision = 0
var flat_floor = false
var complete_floor = false
var sloped_cells: Dictionary = {}
var uniform_cost = 1.0
var nav_keys = PackedStringArray()
var nav_walkable = PackedByteArray()
var nav_costs = PackedFloat32Array()

func default_rules() -> Dictionary:
	var result: Dictionary = {}
	for name in RULES:
		result[name] = RULES[name].default
	return result

func rule(name: String) -> float:
	var definition: Dictionary = RULES.get(name, {})
	if definition.is_empty():
		return 0.0
	var configured: Variant = map.get("rules", {})
	if configured is Dictionary:
		var value: Variant = configured.get(name, definition.default)
		if (value is int or value is float) and is_finite(float(value)):
			return clampf(float(value), float(definition.min), float(definition.max))
	return float(definition.default)

func migrate(value: Dictionary) -> Dictionary:
	var result = value.duplicate(true)
	if result.get("version", 0) == 1:
		result.version = 2
		if not result.has("rules"):
			result.rules = default_rules()
		elif result.rules is Dictionary:
			var merged = default_rules()
			for name in result.rules:
				merged[name] = result.rules[name]
			result.rules = merged
	return result

func cell_key(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]

func point(key: String) -> Vector2i:
	var parts = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func position(p: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3((p.x + 0.5) * SIZE, height, (p.y + 0.5) * SIZE)

func cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / SIZE), floori(pos.z / SIZE))

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < int(map.width) and p.y < int(map.height)

func preset(index: int = 0, seed_value: int = 104729) -> Dictionary:
	index = posmod(index, LEVEL_NAMES.size())
	if index >= 3: return Levels.authored(self, index - 3, seed_value)
	var width = 25
	var height = 25
	var layers = {"ground": {}, "structure": {}, "height": {}, "markers": {}, "objects": {}, "decoration": {}, "lighting": {}}
	var build: Array = []
	for y in height:
		for x in width:
			var p = Vector2i(x, y)
			var key = cell_key(p)
			var terrain = "road" if x == 12 or y == 12 else "concrete"
			if index == 1:
				terrain = "road" if x == 12 or y == 12 else "metal"
			elif index == 2:
				terrain = "road" if x == 12 or y == 12 else ("grass" if (x + y) % 3 != 0 else "dirt")
			layers.ground[key] = {"type": terrain, "rotation": 0}
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				layers.structure[key] = {"type": "permanent", "health": 0, "height": 3.5}
			elif x > 2 and y > 2 and x < 22 and y < 22 and p.distance_to(Vector2i(12, 12)) > 2 and x != 12 and y != 12:
				build.append(key)
	for x in [7, 17]:
		for y in range(6, 19):
			if y in [9, 12, 15]:
				continue
			var key = cell_key(Vector2i(x, y))
			layers.structure[key] = {"type": "permanent", "height": 2.8, "health": 0}
			build.erase(key)
	if index == 1:
		for y in [7, 17]:
			for x in range(8, 17):
				if x in [11, 12, 13]: continue
				var key = cell_key(Vector2i(x, y))
				layers.structure[key] = {"type": "permanent", "height": 2.8, "health": 0}
				build.erase(key)
	elif index == 2:
		for x in [4, 20]:
			for y in range(5, 20):
				if y in [11, 12, 13]: continue
				var key = cell_key(Vector2i(x, y))
				layers.structure[key] = {"type": "permanent", "height": 2.8, "health": 0}
				build.erase(key)
	layers.markers["12,14"] = {"type": "player"}
	layers.markers["12,12"] = {"type": "objective"}
	layers.markers["12,1"] = {"type": "enemy"}
	layers.markers["2,12"] = {"type": "enemy", "unlock": 4}
	layers.markers["22,12"] = {"type": "enemy", "unlock": 8}
	layers.objects["11,14"] = {"type": "supply"}
	layers.objects["13,14"] = {"type": "shop"}
	for key in ["11,14", "13,14", "3,11", "3,13", "21,11", "21,13"]: build.erase(key)
	layers.structure["2,12"] = {"type": "gate", "height": 3.0, "health": 0, "locked": true}
	layers.structure["22,12"] = {"type": "gate", "height": 3.0, "health": 0, "locked": true}
	var names = ["The Foundry", "Relay Station", "Crossroads"]
	var descriptions = [
		"An industrial crossroad. West opens after wave 4; east after wave 8.",
		"A fortified relay station with gated side approaches.",
		"A greenbelt split by open roads and low cover."
	]
	var ids = ["foundry", "relay", "crossroads"]
	return {"version": 2, "id": ids[index % ids.size()], "name": names[index % names.size()], "description": descriptions[index % descriptions.size()], "author": "GRIDFALL", "width": width, "height": height, "seed": seed_value, "theme": index, "rules": default_rules(), "layers": layers, "build": build, "events": [{"id": "west", "round": 4, "remove": ["2,12"], "build": ["3,11", "3,13"], "message": "West gate opened. A second approach is active."}, {"id": "east", "round": 8, "remove": ["22,12"], "build": ["21,11", "21,13"], "message": "East gate opened. Defend all three approaches."}]}

func generated(seed_value: int, width: int = 33, height: int = 33, style: int = 0) -> Dictionary:
	var map_width = clampi(width, 8, 96)
	var map_height = clampi(height, 8, 96)
	var map_seed = clampi(seed_value, -2147483647, 2147483647)
	var map_style = clampi(style, 0, 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = map_seed
	var layers = {"ground": {}, "structure": {}, "height": {}, "markers": {}, "objects": {}, "decoration": {}, "lighting": {}}
	var center = Vector2i(map_width / 2, map_height / 2)
	var candidates: Array[String] = []
	var terrain_options: Array = [
		["concrete", "grass", "dirt", "sand", "stone", "road"],
		["metal", "concrete", "stone", "road"],
		["grass", "dirt", "sand", "stone", "concrete"]
	]
	var cover_options: Array = [
		["wood", "brick", "concrete_wall", "glass"],
		["steel", "brick", "concrete_wall", "glass"],
		["wood", "brick", "barricade", "glass"]
	]
	var hazard_options: Array = [
		["spikes", "slow", "fire", "acid", "mine"],
		["fire", "electric", "spikes", "mine"],
		["acid", "slow", "spikes", "electric"]
	]
	var decoration_options: Array = [
		["crate", "debris", "pipe", "machinery"],
		["machinery", "pipe", "crate", "debris"],
		["vegetation", "debris", "crate", "pipe"]
	]
	for y in range(map_height):
		for x in range(map_width):
			var p = Vector2i(x, y)
			var key = cell_key(p)
			var border = x == 0 or y == 0 or x == map_width - 1 or y == map_height - 1
			var lane = x == center.x or y == center.y
			var terrain = "road" if lane else terrain_options[map_style][rng.randi_range(0, terrain_options[map_style].size() - 1)]
			if map_style == 1 and lane:
				terrain = "metal"
			layers.ground[key] = {"type": terrain, "rotation": 0}
			if border:
				layers.structure[key] = {"type": "permanent", "health": 0, "height": 3.5}
			elif not lane:
				candidates.append(key)
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index = rng.randi_range(0, index)
		var saved = candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = saved
	if candidates.size() >= 3:
		var cover_key: String = candidates[0]
		var cover_type: String = cover_options[map_style][rng.randi_range(0, cover_options[map_style].size() - 1)]
		var cover_definition: Dictionary = WALL_DEFS[cover_type]
		layers.structure[cover_key] = {"type": cover_type, "height": cover_definition.height, "health": cover_definition.health, "max_health": cover_definition.health}
		var guaranteed_hazards = ["spikes", "slow"] if map_style != 1 else ["fire", "electric"]
		for index in guaranteed_hazards.size():
			layers.objects[candidates[index + 1]] = {"type": guaranteed_hazards[index]}
		var cover_chance = [0.07, 0.10, 0.045][map_style]
		var hazard_chance = [0.035, 0.04, 0.035][map_style]
		var decoration_chance = [0.035, 0.04, 0.06][map_style]
		for index in range(3, candidates.size()):
			var key: String = candidates[index]
			var roll = rng.randf()
			if roll < cover_chance:
				cover_type = cover_options[map_style][rng.randi_range(0, cover_options[map_style].size() - 1)]
				cover_definition = WALL_DEFS[cover_type]
				layers.structure[key] = {"type": cover_type, "height": cover_definition.height, "health": cover_definition.health, "max_health": cover_definition.health}
			elif roll < cover_chance + hazard_chance:
				layers.objects[key] = {"type": hazard_options[map_style][rng.randi_range(0, hazard_options[map_style].size() - 1)]}
			elif roll < cover_chance + hazard_chance + decoration_chance:
				layers.decoration[key] = {"type": decoration_options[map_style][rng.randi_range(0, decoration_options[map_style].size() - 1)]}
	var player = Vector2i(center.x, center.y + 1)
	layers.markers[cell_key(player)] = {"type": "player"}
	layers.markers[cell_key(center)] = {"type": "objective"}
	var spawn_points = [Vector2i(center.x, 1), Vector2i(1, center.y), Vector2i(map_width - 2, center.y), Vector2i(center.x, map_height - 2)]
	for spawn in spawn_points:
		layers.markers[cell_key(spawn)] = {"type": "enemy"}
	var build: Array[String] = []
	for y in range(1, map_height - 1):
		for x in range(1, map_width - 1):
			var key = cell_key(Vector2i(x, y))
			if layers.structure.has(key) or layers.objects.has(key) or layers.markers.has(key):
				continue
			build.append(key)
	var style_names = ["Balanced", "Foundry", "Overgrown"]
	return {
		"version": 2,
		"id": "custom_generated_%d_%d_%d_%d" % [map_seed, map_width, map_height, map_style],
		"name": "Generated %s %d" % [style_names[map_style], map_seed],
		"description": "Procedural %s layout, seed %d." % [style_names[map_style], map_seed],
		"author": "Player",
		"width": map_width,
		"height": map_height,
		"seed": map_seed,
		"theme": map_style,
		"rules": default_rules(),
		"layers": layers,
		"build": build,
		"events": []
	}

func load_map(value: Dictionary) -> void:
	map = migrate(value)
	construction.clear()
	applied.clear()
	rebuild_flow()

func marker(kind: String) -> Vector2i:
	for key in map.layers.markers:
		if map.layers.markers[key].type == kind:
			return point(key)
	return Vector2i(-1, -1)

func spawns(round_number: int) -> Array:
	var found: Array = []
	for key in map.layers.markers:
		var m = map.layers.markers[key]
		if m.type == "enemy" and int(m.get("unlock", 0)) <= round_number:
			found.append(point(key))
	return found

func interactive_tiles() -> Dictionary:
	var result = map.layers.objects.duplicate()
	for key in map.layers.markers:
		if map.layers.markers[key].type in ["supply", "upgrade", "ammo", "generator", "chest", "shop"]:
			result[key] = map.layers.markers[key]
	return result

func fixed_solid(p: Vector2i) -> bool:
	if not inside(p):
		return true
	if not map.layers.ground.has(cell_key(p)): return true
	var key = cell_key(p)
	if map.layers.objects.has(key) and map.layers.objects[key].type not in HAZARDS: return true
	if map.layers.markers.get(key, {}).get("type") in ["supply", "upgrade", "ammo", "generator", "chest", "shop"]: return true
	var tile = map.layers.structure.get(key, {})
	return not tile.is_empty() and tile.get("type") not in ["ramp", "stairs"]

func movement_cost(p: Vector2i) -> float:
	var tile: Dictionary = map.get("layers", {}).get("ground", {}).get(cell_key(p), {})
	var default_cost = 2.0 if tile.get("type", "") == "water" else 1.0
	var value: Variant = tile.get("movement_cost", default_cost)
	if not (value is int or value is float) or not is_finite(float(value)):
		return default_cost
	return clampf(float(value), 1.0, 8.0)

func solid(p: Vector2i) -> bool:
	return fixed_solid(p) or (construction.has(cell_key(p)) and construction[cell_key(p)].kind not in ["trap"])

func can_destroy(p: Vector2i) -> bool:
	var tile = map.layers.structure.get(cell_key(p), {})
	if tile.is_empty() or WALL_DEFS.get(tile.get("type", ""), {}).get("health", 0) <= 0 or tile.get("locked", false):
		return false
	var resistance = float(tile.get("resistance", WALL_DEFS.get(tile.type, {}).get("resistance", 0.0)))
	return float(tile.get("health", WALL_DEFS[tile.type].health)) > 0 and resistance < 1.0

func remove_structure(key: String) -> void:
	var tile: Dictionary = map.layers.structure.get(key, {})
	if not map.layers.structure.erase(key): return
	var p = point(key)
	var index = p.y * int(map.width) + p.x
	var walkable = 1 if not fixed_solid(p) or can_destroy(p) else 0
	# Breakable cover is already traversable in enemy route planning.
	if nav_walkable[index] != walkable:
		rebuild_flow()
	else:
		nav_revision += 1
		if tile.type in ["ramp", "stairs"]: refresh_slopes()

func refresh_slopes() -> void:
	flat_floor = complete_floor
	sloped_cells.clear()
	if not complete_floor: return
	for key in map.layers.structure:
		var tile = map.layers.structure[key]
		if tile.type in ["ramp", "stairs"]:
			flat_floor = false
			var p = point(key)
			for dy in range(-1, 2):
				for dx in range(-1, 2): sloped_cells[cell_key(p + Vector2i(dx, dy))] = true

func rebuild_flow() -> void:
	var start = Time.get_ticks_usec()
	nav_revision += 1
	flow.clear()
	fields.clear()
	if map.is_empty():
		return
	var total = int(map.width) * int(map.height)
	nav_keys.resize(total)
	nav_walkable.resize(total)
	nav_costs.resize(total)
	for index in total:
		var p = Vector2i(index % int(map.width), index / int(map.width))
		nav_keys[index] = cell_key(p)
		nav_walkable[index] = 1 if not fixed_solid(p) or can_destroy(p) else 0
		nav_costs[index] = movement_cost(p)
	uniform_cost = -1.0
	for tile in map.layers.ground.values():
		var cost = float(tile.get("movement_cost", 2.0 if tile.type == "water" else 1.0))
		if uniform_cost < 0: uniform_cost = cost
		elif uniform_cost != cost:
			uniform_cost = 0.0
			break
	complete_floor = map.layers.ground.size() == int(map.width) * int(map.height)
	refresh_slopes()
	var target = marker("objective")
	flow = navigation_field(target)
	nav_ms = (Time.get_ticks_usec() - start) / 1000.0

func navigation_field(target: Vector2i) -> Dictionary:
	if not inside(target): return {}
	var target_key = cell_key(target)
	if fields.has(target_key): return fields[target_key]
	var width = int(map.width)
	var total = nav_keys.size()
	var start = target.y * width + target.x
	var distances = PackedFloat64Array()
	distances.resize(total)
	distances.fill(INF)
	distances[start] = 0
	var result: Dictionary = {}
	if uniform_cost > 0:
		var frontier: Array[int] = [start]
		var head = 0
		while head < frontier.size():
			var current = frontier[head]
			head += 1
			for next in [current - width, current + width, current - 1 if current % width > 0 else -1, current + 1 if current % width < width - 1 else -1]:
				if next < 0 or next >= total or nav_walkable[next] == 0 or distances[next] != INF: continue
				distances[next] = distances[current] + uniform_cost
				frontier.append(next)
	else:
		var queue: Array = []
		_heap_push(queue, [start, 0.0])
		while not queue.is_empty():
			var entry: Array = _heap_pop(queue)
			var current = int(entry[0])
			var current_cost = float(entry[1])
			if current_cost > distances[current]: continue
			for next in [current - width, current + width, current - 1 if current % width > 0 else -1, current + 1 if current % width < width - 1 else -1]:
				if next < 0 or next >= total or nav_walkable[next] == 0: continue
				var next_cost = current_cost + nav_costs[current]
				if next_cost >= distances[next]: continue
				distances[next] = next_cost
				_heap_push(queue, [next, next_cost])
	for index in total:
		if distances[index] != INF: result[nav_keys[index]] = distances[index]
	if fields.size() >= 32: fields.clear()
	fields[target_key] = result
	return result

func _heap_push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var child = heap.size() - 1
	while child > 0:
		var parent = floori(float(child - 1) / 2.0)
		if float(heap[parent][1]) <= float(entry[1]):
			break
		heap[child] = heap[parent]
		child = parent
	heap[child] = entry

func _heap_pop(heap: Array) -> Array:
	var first: Array = heap[0]
	var tail: Array = heap.pop_back()
	if not heap.is_empty():
		var parent = 0
		while true:
			var left = parent * 2 + 1
			if left >= heap.size():
				break
			var child = left
			var right = left + 1
			if right < heap.size() and float(heap[right][1]) < float(heap[left][1]):
				child = right
			if float(tail[1]) <= float(heap[child][1]):
				break
			heap[parent] = heap[child]
			parent = child
		heap[parent] = tail
	return first

func next_cell(p: Vector2i) -> Vector2i:
	return next_toward(p, marker("objective"))

func next_toward(p: Vector2i, target: Vector2i) -> Vector2i:
	var field = navigation_field(target)
	var best = p
	var remaining = float(field.get(cell_key(p), INF))
	var score = INF
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var q: Vector2i = p + d
		if not inside(q) or not field.has(cell_key(q)):
			continue
		var cost = movement_cost(q) + float(field[cell_key(q)])
		if cost < score:
			score = cost
			best = q
	return best if score <= remaining + 0.000001 else p

func placement(p: Vector2i) -> String:
	var key = cell_key(p)
	if not inside(p):
		return "Outside world boundaries."
	if not key in map.build or fixed_solid(p):
		return "Fixed world, protected route, or locked region."
	if (map.layers.markers.has(key) and map.layers.markers[key].type not in ["pad", "tower_pad", "structure_pad"]) or map.layers.objects.has(key):
		return "This tile is reserved for a world object."
	for event in map.events:
		if event.id not in applied and key in event.get("remove", []):
			return "Reserved for a scheduled world change."
	if construction.has(key):
		return "A structure already occupies this tile."
	return ""

func evolve(round_number: int) -> Array:
	var messages: Array = []
	for event in map.events:
		if event.id in applied or int(event.round) > round_number:
			continue
		for key in event.get("remove", []):
			map.layers.structure.erase(key)
		for key in event.get("build", []):
			if not key in map.build:
				map.build.append(key)
		applied.append(event.id)
		messages.append(event.message)
	if not messages.is_empty():
		rebuild_flow()
	return messages

func validate(value: Variant, require_playable: bool = true) -> Array:
	var issues: Array = []
	if not value is Dictionary or (value.get("version") != 1 and value.get("version") != 2):
		return ["Unsupported or missing map format version."]
	value = migrate(value)
	for key in ["id", "name", "width", "height", "layers", "build", "events", "seed"]:
		if not value.has(key):
			return ["Missing map property: " + key]
	if not value.width is float and not value.width is int:
		return ["Width must be a number."]
	if not value.height is float and not value.height is int:
		return ["Height must be a number."]
	if value.width < 8 or value.height < 8 or value.width > 96 or value.height > 96:
		return ["Map dimensions must be 8–96 tiles."]
	if value.width != int(value.width) or value.height != int(value.height): return ["Map dimensions must be whole numbers."]
	if not value.name is String or not value.id is String or not (value.seed is int or value.seed is float): return ["Invalid map metadata or seed."]
	if not is_finite(float(value.seed)) or absf(value.seed) > 2147483647: return ["Seed is out of range."]
	if not value.layers is Dictionary or not value.build is Array or not value.events is Array:
		return ["Invalid layers, construction permissions, or events."]
	if value.has("rules"):
		if not value.rules is Dictionary:
			return ["World rules must be an object."]
		for name in value.rules:
			var definition: Dictionary = RULES.get(str(name), {})
			if definition.is_empty():
				issues.append("Unknown world rule: " + str(name))
				continue
			var rule_value: Variant = value.rules[name]
			if not (rule_value is int or rule_value is float) or not is_finite(float(rule_value)):
				issues.append("Invalid world rule value: " + str(name))
				continue
			if float(rule_value) < float(definition.min) or float(rule_value) > float(definition.max):
				issues.append("World rule %s must be between %s and %s." % [name, definition.min, definition.max])
			if name in ["objective_health", "boss_interval"] and float(rule_value) != int(rule_value):
				issues.append("World rule %s must be a whole number." % name)
	for layer in ["ground", "structure", "height", "markers", "objects", "decoration", "lighting"]:
		if not value.layers.get(layer) is Dictionary:
			return ["Missing layer: " + layer]
	var counts = {"player": 0, "objective": 0, "enemy": 0}
	var initial_spawns = 0
	for layer in value.layers:
		if not value.layers[layer] is Dictionary:
			return ["Layer must be an object: " + layer]
		for key in value.layers[layer]:
			if not key is String:
				return ["Invalid tile coordinate: " + str(key)]
			var parts = key.split(",")
			if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
				return ["Invalid tile coordinate: " + str(key)]
			var p = point(key)
			if key != cell_key(p):
				return ["Non-canonical tile coordinate: " + key]
			if p.x < 0 or p.y < 0 or p.x >= value.width or p.y >= value.height:
				issues.append("Out-of-bounds tile: " + key)
			var tile = value.layers[layer][key]
			if not tile is Dictionary or not tile.get("type") is String:
				return ["Invalid tile definition at " + key]
			for field in ["height", "elevation", "health", "max_health", "rotation", "unlock", "movement_cost", "energy", "range", "resistance", "fire"]:
				if tile.has(field):
					var field_min = 0.0
					var field_max = 100000.0
					match field:
						"height", "elevation": field_max = 100.0
						"rotation": field_max = 360.0
						"unlock": field_max = 1000000.0
						"movement_cost":
							field_min = 1.0
							field_max = 8.0
						"energy": field_max = 8.0
						"range": field_max = 80.0
						"resistance": field_max = 1.0
						"fire": field_max = 4.0
					if not (tile[field] is int or tile[field] is float) or not is_finite(float(tile[field])) or float(tile[field]) < field_min or float(tile[field]) > field_max:
						return ["Invalid " + field + " at " + key]
					if field in ["height", "range"] and float(tile[field]) <= 0:
						return ["Invalid " + field + " at " + key]
					if field in ["health", "max_health", "rotation", "unlock"] and float(tile[field]) != int(tile[field]):
						return ["Invalid " + field + " at " + key]
					if field == "movement_cost" and layer != "ground":
						return ["Movement cost is only valid on ground tiles: " + key]
					if field in ["health", "max_health", "resistance", "fire"] and layer != "structure":
						return [field.capitalize() + " is only valid on structures: " + key]
					if field in ["energy", "range"] and layer != "lighting":
						return [field.capitalize() + " is only valid on lights: " + key]
					if field == "height" and layer != "structure":
						return ["Height is only valid on structures: " + key]
			if tile.has("locked") and not tile.locked is bool:
				return ["Invalid locked flag at " + key]
			if tile.has("locked") and layer != "structure":
				return ["Locked is only valid on structures: " + key]
			if tile.has("color") and (layer != "lighting" or not tile.color is String or not Color.html_is_valid(tile.color)):
				return ["Invalid light color at " + key]
			if layer == "ground" and tile.type not in TERRAIN:
				issues.append("Unknown terrain at " + key)
			if layer == "structure" and tile.type not in WALLS:
				issues.append("Unknown structure at " + key)
			elif layer == "structure" and WALL_DEFS[tile.type].health > 0 and not tile.get("locked", false) and float(tile.get("health", WALL_DEFS[tile.type].health)) <= 0:
				issues.append("Destructible structures need positive health or must be locked: " + key)
			if layer == "markers" and tile.type not in MARKERS:
				issues.append("Unknown marker at " + key)
			if layer == "objects" and tile.type not in HAZARDS + ["supply", "shop", "chest", "ammo", "generator", "upgrade"]: issues.append("Unknown object at " + key)
			if layer == "decoration" and tile.type not in ["light", "vegetation", "crate", "debris", "pipe", "machinery"]: issues.append("Unknown decoration at " + key)
			if layer == "height" and tile.type not in ["ceiling", "elevation"]: issues.append("Unknown height tile at " + key)
			if layer == "lighting" and tile.type != "light": issues.append("Unknown light at " + key)
			if layer == "markers" and counts.has(tile.type):
				counts[tile.type] += 1
				if tile.type == "enemy" and int(tile.get("unlock", 0)) == 0: initial_spawns += 1
				if tile.type != "enemy" and tile.has("unlock"): issues.append("Only enemy spawn markers may have an unlock wave: " + key)
	if require_playable:
		for kind in counts:
			if counts[kind] == 0 or (kind != "enemy" and counts[kind] != 1):
				issues.append("Map needs %s %s marker." % ["at least one" if kind == "enemy" else "exactly one", kind])
		if initial_spawns == 0: issues.append("Map needs a reachable enemy spawn active from the first wave.")
	if not issues.is_empty():
		return issues
	var probe = get_script().new()
	probe.load_map(value)
	for key in value.build:
		if not key is String or key.split(",").size() != 2:
			return ["Invalid construction permission coordinate."]
		if not key.split(",")[0].is_valid_int() or not key.split(",")[1].is_valid_int(): return ["Invalid construction permission coordinate."]
		var p = probe.point(key)
		if key != cell_key(p): return ["Invalid construction permission coordinate."]
		if not probe.inside(p): return ["Invalid construction permission coordinate."]
	for key in value.layers.markers:
		if not require_playable: break
		var kind = value.layers.markers[key].type
		var p = probe.point(key)
		if kind in ["pad", "tower_pad", "structure_pad"] and (probe.fixed_solid(p) or key not in value.build): issues.append("Invalid construction pad at " + key)
		if kind in ["player", "objective", "enemy"] and probe.fixed_solid(p):
			if not value.layers.markers[key].has("unlock"):
				issues.append("Blocked mandatory marker at " + key)
		if kind in ["player", "enemy"] and not value.layers.markers[key].has("unlock") and not probe.flow.has(key):
			issues.append("No route to objective from " + key)
	for key in value.layers.objects:
		if value.layers.objects[key].type not in HAZARDS:
			if value.layers.structure.has(key) or value.layers.markers.has(key): issues.append("Overlapping incompatible object at " + key)
	var ids: Array = []
	for event in value.events:
		if not event is Dictionary or not event.get("id") is String or not event.get("round") is float and not event.get("round") is int:
			return ["Malformed world evolution event."]
		if event.id.strip_edges().is_empty() or event.id in ids or event.round < 1 or not event.get("remove", []) is Array or not event.get("build", []) is Array:
			return ["Invalid world evolution event."]
		if not is_finite(float(event.round)) or event.round > 1000000 or event.round != int(event.round): return ["Evolution round must be a positive whole number up to 1000000."]
		if not event.get("message") is String or event.message.strip_edges().is_empty():
			return ["World evolution event needs a message."]
		for key in event.get("remove", []) + event.get("build", []):
			if not key is String or key.split(",").size() != 2:
				return ["Invalid evolution coordinate."]
			if not key.split(",")[0].is_valid_int() or not key.split(",")[1].is_valid_int(): return ["Invalid evolution coordinate."]
			var p = probe.point(key)
			if key != cell_key(p): return ["Invalid evolution coordinate."]
			if not probe.inside(p): return ["Evolution coordinate outside the map: " + key]
			if value.layers.markers.has(key) and value.layers.markers[key].type in ["player", "objective"]:
				return ["Evolution cannot overwrite a protected marker."]
		ids.append(event.id)
		for key in event.get("remove", []):
			if key in value.build and value.layers.structure.has(key):
				issues.append("Evolution overlaps construction permissions at " + key)
	if require_playable:
		var stage_rounds: Array[int] = [0]
		for key in value.layers.markers:
			var marker_value: Dictionary = value.layers.markers[key]
			if marker_value.type == "enemy":
				var unlock_round = int(marker_value.get("unlock", 0))
				if unlock_round not in stage_rounds:
					stage_rounds.append(unlock_round)
		for event in value.events:
			var event_round = int(event.round)
			if event_round not in stage_rounds:
				stage_rounds.append(event_round)
		stage_rounds.sort()
		var player_key = cell_key(probe.marker("player"))
		for stage_round in stage_rounds:
			if stage_round > 0:
				probe.evolve(stage_round)
			if not probe.flow.has(player_key):
				issues.append("No route to objective from player after wave %d." % stage_round)
			for key in value.layers.markers:
				var marker_value: Dictionary = value.layers.markers[key]
				if marker_value.type == "enemy" and int(marker_value.get("unlock", 0)) <= stage_round and not probe.flow.has(key):
					issues.append("No route to enemy spawn %s after wave %d." % [key, stage_round])
	return issues
