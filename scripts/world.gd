extends RefCounted

const SIZE = 3.0
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
	var width = 25
	var height = 25
	var layers = {"ground": {}, "structure": {}, "height": {}, "markers": {}, "objects": {}, "decoration": {}, "lighting": {}}
	var build: Array = []
	for y in height:
		for x in width:
			var p = Vector2i(x, y)
			var key = cell_key(p)
			layers.ground[key] = {"type": "road" if x == 12 or y == 12 else ("metal" if index == 1 else "concrete"), "rotation": 0}
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
	return {"version": 1, "id": "foundry" if index == 0 else "relay", "name": "The Foundry" if index == 0 else "Relay Station", "description": "An industrial crossroad. West opens after wave 4; east after wave 8.", "author": "GRIDFALL", "width": width, "height": height, "seed": seed_value, "theme": index, "layers": layers, "build": build, "events": [{"id": "west", "round": 4, "remove": ["2,12"], "build": ["3,11", "3,13"], "message": "West gate opened. A second approach is active."}, {"id": "east", "round": 8, "remove": ["22,12"], "build": ["21,11", "21,13"], "message": "East gate opened. Defend all three approaches."}]}

func load_map(value: Dictionary) -> void:
	map = value.duplicate(true)
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
	return not tile.is_empty() and tile.get("type") not in ["platform", "ramp", "stairs"]

func solid(p: Vector2i) -> bool:
	return fixed_solid(p) or (construction.has(cell_key(p)) and construction[cell_key(p)].kind not in ["trap"])

func can_destroy(p: Vector2i) -> bool:
	var tile = map.layers.structure.get(cell_key(p), {})
	return not tile.is_empty() and WALL_DEFS.get(tile.type, {}).get("health", 0) > 0 and tile.get("health", 0) > 0 and not tile.get("locked", false)

func rebuild_flow() -> void:
	var start = Time.get_ticks_usec()
	flow.clear()
	fields.clear()
	if map.is_empty():
		return
	var target = marker("objective")
	flow = navigation_field(target)
	nav_ms = (Time.get_ticks_usec() - start) / 1000.0

func navigation_field(target: Vector2i) -> Dictionary:
	var target_key = cell_key(target)
	if fields.has(target_key): return fields[target_key]
	var result: Dictionary = {}
	var queue: Array = [target]
	result[target_key] = 0
	var head = 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = p + d
			var key = cell_key(next)
			if not inside(next) or result.has(key):
				continue
			if fixed_solid(next):
				if not can_destroy(next):
					continue
			result[key] = int(result[cell_key(p)]) + 1
			queue.append(next)
	if fields.size() >= 32: fields.clear()
	fields[target_key] = result
	return result

func next_cell(p: Vector2i) -> Vector2i:
	return next_toward(p, marker("objective"))

func next_toward(p: Vector2i, target: Vector2i) -> Vector2i:
	var field = navigation_field(target)
	var best = p
	var score = float(field.get(cell_key(p), 1e9))
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var q: Vector2i = p + d
		var cost = float(field.get(cell_key(q), 1e9))
		if cost < score:
			score = cost
			best = q
	return best

func placement(p: Vector2i) -> String:
	var key = cell_key(p)
	if not inside(p):
		return "Outside world boundaries."
	if not key in map.build or fixed_solid(p):
		return "Fixed world, protected route, or locked region."
	if (map.layers.markers.has(key) and map.layers.markers[key].type not in ["pad", "tower_pad", "structure_pad"]) or map.layers.objects.has(key):
		return "This tile is reserved for a world object."
	for event in map.events:
		if key in event.get("remove", []):
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
	if not value is Dictionary or value.get("version") != 1:
		return ["Unsupported or missing map format version."]
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
	for layer in ["ground", "structure", "height", "markers", "objects", "decoration", "lighting"]:
		if not value.layers.get(layer) is Dictionary:
			return ["Missing layer: " + layer]
	var counts = {"player": 0, "objective": 0, "enemy": 0}
	var initial_spawns = 0
	for layer in value.layers:
		if not value.layers[layer] is Dictionary:
			return ["Layer must be an object: " + layer]
		for key in value.layers[layer]:
			var parts = str(key).split(",")
			if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
				return ["Invalid tile coordinate: " + str(key)]
			var p = point(key)
			if p.x < 0 or p.y < 0 or p.x >= value.width or p.y >= value.height:
				issues.append("Out-of-bounds tile: " + key)
			var tile = value.layers[layer][key]
			if not tile is Dictionary or not tile.get("type") is String:
				return ["Invalid tile definition at " + key]
			for field in ["height", "elevation", "health", "max_health", "rotation", "unlock"]:
				if tile.has(field):
					if not (tile[field] is int or tile[field] is float) or not is_finite(float(tile[field])) or float(tile[field]) < 0 or float(tile[field]) > 100000:
						return ["Invalid " + field + " at " + key]
			if layer == "ground" and tile.type not in TERRAIN:
				issues.append("Unknown terrain at " + key)
			if layer == "structure" and tile.type not in WALLS:
				issues.append("Unknown structure at " + key)
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
			if float(tile.get("height", 1)) < 0 or float(tile.get("elevation", 0)) < 0:
				issues.append("Invalid elevation at " + key)
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
		if not key is String or key.split(",").size() != 2 or not probe.inside(probe.point(key)):
			return ["Invalid construction permission coordinate."]
		if not key.split(",")[0].is_valid_int() or not key.split(",")[1].is_valid_int(): return ["Invalid construction permission coordinate."]
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
		if event.id in ids or event.round < 1 or not event.get("remove", []) is Array or not event.get("build", []) is Array:
			return ["Invalid world evolution event."]
		if not is_finite(float(event.round)) or event.round > 1000000 or event.round != int(event.round): return ["Evolution round must be a positive whole number up to 1000000."]
		if not event.get("message") is String:
			return ["World evolution event needs a message."]
		for key in event.get("remove", []) + event.get("build", []):
			if not key is String or key.split(",").size() != 2:
				return ["Invalid evolution coordinate."]
			if not key.split(",")[0].is_valid_int() or not key.split(",")[1].is_valid_int(): return ["Invalid evolution coordinate."]
			var p = probe.point(key)
			if not probe.inside(p): return ["Evolution coordinate outside the map: " + key]
			if value.layers.markers.has(key) and value.layers.markers[key].type in ["player", "objective"]:
				return ["Evolution cannot overwrite a protected marker."]
		ids.append(event.id)
		for key in event.get("remove", []):
			if key in value.build:
				issues.append("Evolution overlaps construction permissions at " + key)
	probe.evolve(2147483647)
	for key in value.layers.markers:
		if not require_playable: break
		if value.layers.markers[key].type == "enemy" and not probe.flow.has(key):
			issues.append("Evolution leaves an unreachable enemy spawn at " + key)
	return issues
