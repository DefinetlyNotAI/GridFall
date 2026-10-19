extends RefCounted

# Authored maps use bounded, connected corridors and arenas so each portal has
# a readable route network while leaving room for construction and combat.
static func _open_cell(world, layers: Dictionary, open: Dictionary, p: Vector2i, terrain: String = "road") -> void:
	var key = world.cell_key(p)
	if not layers.ground.has(key): return
	open[key] = true
	layers.ground[key] = {"type": terrain}

static func _open_rect(world, layers: Dictionary, open: Dictionary, x0: int, y0: int, x1: int, y1: int, terrain: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_open_cell(world, layers, open, Vector2i(x, y), terrain)

static func _open_path(world, layers: Dictionary, open: Dictionary, points: Array, radius: int = 0) -> void:
	for segment in range(points.size() - 1):
		var start: Vector2i = points[segment]
		var finish: Vector2i = points[segment + 1]
		var p = start
		while p.x != finish.x:
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					_open_cell(world, layers, open, p + Vector2i(dx, dy))
			p.x += signi(finish.x - p.x)
		while p.y != finish.y:
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					_open_cell(world, layers, open, p + Vector2i(dx, dy))
			p.y += signi(finish.y - p.y)
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				_open_cell(world, layers, open, finish + Vector2i(dx, dy))

static func _open_expansion_path(world, layers: Dictionary, points: Array) -> void:
	var open: Dictionary = {}
	_open_path(world, layers, open, points)
	for key in open:
		var structure: Dictionary = layers.structure.get(key, {})
		if structure.get("type", "") == "gate" and structure.get("locked", false):
			continue
		layers.structure.erase(key)

static func _cover(world, layers: Dictionary, p: Vector2i, kind: String, health: int, height: float = 2.8) -> void:
	var key = world.cell_key(p)
	layers.structure[key] = {"type": kind, "health": health, "max_health": health, "height": height}

static func _pillar(world, layers: Dictionary, p: Vector2i, height: float) -> void:
	_cover(world, layers, p, "pillar", 600, height)

static func _build_sites(world, layers: Dictionary, open: Dictionary, reserved: Dictionary) -> Array:
	var result: Array = []
	for key in open:
		if reserved.has(key) or layers.structure.has(key) or layers.objects.has(key) or layers.markers.has(key) or layers.decoration.has(key):
			continue
		result.append(key)
	return result

static func authored(world, index: int, seed_value: int) -> Dictionary:
	index = posmod(index, 8)
	var dimensions = [Vector2i(25, 25), Vector2i(25, 25), Vector2i(25, 25), Vector2i(33, 33), Vector2i(35, 29), Vector2i(37, 33), Vector2i(41, 31), Vector2i(39, 35)][index]
	var center = dimensions / 2
	if index == 6: center = Vector2i(29, 15)
	elif index == 7: center = Vector2i(10, 17)
	var terrain = ["metal", "metal", "grass", "metal", "stone", "concrete", "stone", "concrete"][index]
	var layers = {"ground": {}, "structure": {}, "height": {}, "markers": {}, "objects": {}, "decoration": {}, "lighting": {}}
	var open: Dictionary = {}
	for y in dimensions.y:
		for x in dimensions.x:
			var p = Vector2i(x, y)
			layers.ground[world.cell_key(p)] = {"type": terrain}
	match index:
		0:
			_open_rect(world, layers, open, 9, 9, 15, 15, "concrete")
			_open_rect(world, layers, open, 9, 2, 15, 4, "metal")
			_open_rect(world, layers, open, 6, 6, 10, 8, "metal")
			_open_rect(world, layers, open, 2, 10, 5, 14, "metal")
			_open_rect(world, layers, open, 19, 10, 22, 14, "metal")
			_open_path(world, layers, open, [Vector2i(12, 1), Vector2i(12, 3), Vector2i(8, 3), Vector2i(8, 7), Vector2i(10, 7), Vector2i(10, 9)])
			_open_path(world, layers, open, [Vector2i(2, 12), Vector2i(3, 12), Vector2i(3, 8), Vector2i(8, 8), Vector2i(8, 17), Vector2i(16, 17), Vector2i(16, 8), Vector2i(20, 8), Vector2i(20, 12), Vector2i(22, 12)])
			_open_path(world, layers, open, [Vector2i(8, 8), Vector2i(10, 8), Vector2i(10, 12), Vector2i(15, 12), Vector2i(15, 8), Vector2i(16, 8)])
			_open_rect(world, layers, open, 6, 10, 7, 12, "metal")
			_open_rect(world, layers, open, 17, 12, 18, 14, "metal")
		1:
			_open_rect(world, layers, open, 9, 9, 15, 15, "metal")
			_open_rect(world, layers, open, 10, 2, 14, 4, "metal")
			_open_rect(world, layers, open, 2, 10, 4, 14, "metal")
			_open_rect(world, layers, open, 20, 10, 22, 14, "metal")
			_open_path(world, layers, open, [Vector2i(8, 5), Vector2i(16, 5), Vector2i(19, 8), Vector2i(19, 16), Vector2i(16, 19), Vector2i(8, 19), Vector2i(5, 16), Vector2i(5, 8), Vector2i(8, 5)])
			_open_path(world, layers, open, [Vector2i(12, 1), Vector2i(12, 3), Vector2i(8, 3), Vector2i(8, 5)])
			_open_path(world, layers, open, [Vector2i(2, 12), Vector2i(3, 12), Vector2i(3, 16), Vector2i(5, 16)])
			_open_path(world, layers, open, [Vector2i(22, 12), Vector2i(21, 12), Vector2i(21, 8), Vector2i(19, 8)])
			_open_path(world, layers, open, [Vector2i(12, 5), Vector2i(12, 9)])
			_open_path(world, layers, open, [Vector2i(5, 12), Vector2i(9, 12)])
			_open_path(world, layers, open, [Vector2i(19, 12), Vector2i(15, 12)])
			_open_path(world, layers, open, [Vector2i(12, 19), Vector2i(12, 15)])
			_open_rect(world, layers, open, 6, 6, 7, 7, "metal")
			_open_rect(world, layers, open, 17, 17, 18, 18, "metal")
		2:
			_open_rect(world, layers, open, 9, 9, 15, 15, "grass")
			_open_rect(world, layers, open, 9, 2, 15, 4, "grass")
			_open_rect(world, layers, open, 2, 10, 4, 14, "grass")
			_open_rect(world, layers, open, 20, 10, 22, 14, "grass")
			_open_path(world, layers, open, [Vector2i(7, 5), Vector2i(17, 5), Vector2i(20, 8), Vector2i(20, 16), Vector2i(17, 19), Vector2i(7, 19), Vector2i(4, 16), Vector2i(4, 8), Vector2i(7, 5)])
			_open_path(world, layers, open, [Vector2i(12, 1), Vector2i(12, 3), Vector2i(7, 3), Vector2i(7, 5)])
			_open_path(world, layers, open, [Vector2i(2, 12), Vector2i(3, 12), Vector2i(3, 8), Vector2i(4, 8)])
			_open_path(world, layers, open, [Vector2i(22, 12), Vector2i(21, 12), Vector2i(21, 18), Vector2i(17, 18)])
			_open_path(world, layers, open, [Vector2i(4, 12), Vector2i(9, 12)])
			_open_path(world, layers, open, [Vector2i(20, 12), Vector2i(15, 12)])
			_open_rect(world, layers, open, 6, 6, 6, 7, "grass")
			_open_rect(world, layers, open, 17, 6, 18, 7, "grass")
			for y in [8, 9, 15, 16]:
				for x in range(4, 21):
					var key = world.cell_key(Vector2i(x, y))
					layers.ground[key] = {"type": "water", "movement_cost": 2.5}
			for x in [7, 8, 16, 17]:
				for y in [8, 9, 15, 16]:
					_open_cell(world, layers, open, Vector2i(x, y))
		3:
			_open_rect(world, layers, open, 12, 12, 20, 20, "metal")
			_open_rect(world, layers, open, 13, 2, 19, 5, "metal")
			_open_rect(world, layers, open, 2, 13, 5, 19, "metal")
			_open_rect(world, layers, open, 28, 13, 30, 19, "metal")
			_open_rect(world, layers, open, 13, 28, 19, 30, "metal")
			_open_path(world, layers, open, [Vector2i(10, 6), Vector2i(22, 6), Vector2i(26, 10), Vector2i(26, 22), Vector2i(22, 26), Vector2i(10, 26), Vector2i(6, 22), Vector2i(6, 10), Vector2i(10, 6)])
			_open_path(world, layers, open, [Vector2i(16, 1), Vector2i(16, 4), Vector2i(10, 4), Vector2i(10, 6)])
			_open_path(world, layers, open, [Vector2i(1, 16), Vector2i(4, 16), Vector2i(4, 10), Vector2i(6, 10)])
			_open_path(world, layers, open, [Vector2i(31, 16), Vector2i(28, 16), Vector2i(28, 22), Vector2i(26, 22)])
			_open_path(world, layers, open, [Vector2i(16, 31), Vector2i(16, 28), Vector2i(22, 28), Vector2i(22, 26)])
			_open_path(world, layers, open, [Vector2i(16, 6), Vector2i(16, 10)])
			_open_path(world, layers, open, [Vector2i(6, 16), Vector2i(10, 16)])
			_open_path(world, layers, open, [Vector2i(26, 16), Vector2i(22, 16)])
			_open_path(world, layers, open, [Vector2i(16, 26), Vector2i(16, 22)])
			_open_path(world, layers, open, [Vector2i(12, 10), Vector2i(20, 10), Vector2i(22, 12), Vector2i(22, 20), Vector2i(20, 22), Vector2i(12, 22), Vector2i(10, 20), Vector2i(10, 12), Vector2i(12, 10)])
			_open_rect(world, layers, open, 7, 10, 7, 12, "metal")
		4:
			_open_rect(world, layers, open, 13, 10, 21, 18, "concrete")
			_open_rect(world, layers, open, 14, 2, 20, 4, "stone")
			_open_rect(world, layers, open, 2, 12, 4, 16, "stone")
			_open_rect(world, layers, open, 30, 12, 32, 16, "stone")
			_open_rect(world, layers, open, 14, 24, 20, 26, "stone")
			_open_path(world, layers, open, [Vector2i(8, 5), Vector2i(26, 5), Vector2i(29, 8), Vector2i(29, 20), Vector2i(26, 23), Vector2i(8, 23), Vector2i(5, 20), Vector2i(5, 8), Vector2i(8, 5)])
			_open_path(world, layers, open, [Vector2i(17, 1), Vector2i(17, 3), Vector2i(12, 3), Vector2i(12, 5), Vector2i(8, 5)])
			_open_path(world, layers, open, [Vector2i(1, 14), Vector2i(4, 14), Vector2i(4, 8), Vector2i(5, 8)])
			_open_path(world, layers, open, [Vector2i(33, 14), Vector2i(31, 14), Vector2i(31, 20), Vector2i(29, 20)])
			_open_path(world, layers, open, [Vector2i(17, 27), Vector2i(17, 25), Vector2i(23, 25), Vector2i(23, 23)])
			_open_path(world, layers, open, [Vector2i(17, 5), Vector2i(17, 10)])
			_open_path(world, layers, open, [Vector2i(5, 14), Vector2i(10, 14)])
			_open_path(world, layers, open, [Vector2i(29, 14), Vector2i(24, 14)])
			_open_path(world, layers, open, [Vector2i(17, 23), Vector2i(17, 18)])
			_open_path(world, layers, open, [Vector2i(11, 8), Vector2i(23, 8), Vector2i(26, 11), Vector2i(26, 17), Vector2i(23, 20), Vector2i(11, 20), Vector2i(8, 17), Vector2i(8, 11), Vector2i(11, 8)])
			_open_rect(world, layers, open, 6, 6, 7, 7, "stone")
			_open_rect(world, layers, open, 27, 20, 28, 21, "stone")
			_open_rect(world, layers, open, 6, 17, 7, 19, "stone")
			for x in [10, 11, 23, 24]:
				for y in range(1, dimensions.y - 1):
					layers.ground[world.cell_key(Vector2i(x, y))] = {"type": "water", "movement_cost": 2.5}
			for y in [5, 14, 23]:
				for x in [10, 11, 23, 24]:
					_open_cell(world, layers, open, Vector2i(x, y))
		5:
			_open_rect(world, layers, open, 14, 12, 22, 20, "concrete")
			_open_rect(world, layers, open, 15, 2, 21, 4, "concrete")
			_open_rect(world, layers, open, 2, 14, 4, 18, "concrete")
			_open_rect(world, layers, open, 32, 14, 34, 18, "concrete")
			_open_rect(world, layers, open, 15, 28, 21, 30, "concrete")
			_open_rect(world, layers, open, 4, 5, 8, 8, "metal")
			_open_rect(world, layers, open, 28, 5, 32, 8, "metal")
			_open_path(world, layers, open, [Vector2i(10, 8), Vector2i(26, 8), Vector2i(29, 11), Vector2i(29, 21), Vector2i(26, 24), Vector2i(10, 24), Vector2i(7, 21), Vector2i(7, 11), Vector2i(10, 8)])
			_open_path(world, layers, open, [Vector2i(18, 1), Vector2i(18, 4), Vector2i(24, 4), Vector2i(24, 8)])
			_open_path(world, layers, open, [Vector2i(1, 16), Vector2i(4, 16), Vector2i(4, 10), Vector2i(7, 10)])
			_open_path(world, layers, open, [Vector2i(35, 16), Vector2i(32, 16), Vector2i(32, 22), Vector2i(29, 22)])
			_open_path(world, layers, open, [Vector2i(18, 31), Vector2i(18, 28), Vector2i(12, 28), Vector2i(12, 24)])
			_open_path(world, layers, open, [Vector2i(18, 8), Vector2i(18, 12)])
			_open_path(world, layers, open, [Vector2i(7, 16), Vector2i(14, 16)])
			_open_path(world, layers, open, [Vector2i(29, 16), Vector2i(22, 16)])
			_open_path(world, layers, open, [Vector2i(18, 24), Vector2i(18, 20)])
			_open_path(world, layers, open, [Vector2i(14, 10), Vector2i(22, 10), Vector2i(24, 12), Vector2i(24, 20), Vector2i(22, 22), Vector2i(14, 22), Vector2i(12, 20), Vector2i(12, 12), Vector2i(14, 10)])
			_open_path(world, layers, open, [Vector2i(6, 8), Vector2i(6, 10), Vector2i(7, 11)])
			_open_path(world, layers, open, [Vector2i(30, 8), Vector2i(30, 10), Vector2i(29, 11)])
			_open_rect(world, layers, open, 10, 19, 11, 21, "concrete")
			_open_rect(world, layers, open, 26, 10, 27, 12, "concrete")
			_open_path(world, layers, open, [Vector2i(27, 11), Vector2i(29, 11)])
		6:
			# Quarry roads wind between two open water cuts. Each crossing has a
			# stone bridge, while the side terrace stays optional.
			_open_rect(world, layers, open, 25, 12, 33, 18, "stone")
			_open_rect(world, layers, open, 2, 13, 4, 17, "stone")
			_open_rect(world, layers, open, 35, 13, 37, 17, "stone")
			_open_rect(world, layers, open, 27, 25, 31, 28, "stone")
			_open_path(world, layers, open, [Vector2i(29, 1), Vector2i(29, 12)])
			_open_path(world, layers, open, [Vector2i(29, 4), Vector2i(33, 4)])
			_open_path(world, layers, open, [Vector2i(1, 15), Vector2i(5, 15), Vector2i(5, 6), Vector2i(16, 6), Vector2i(16, 12), Vector2i(25, 12)])
			_open_path(world, layers, open, [Vector2i(39, 15), Vector2i(35, 15), Vector2i(35, 18), Vector2i(33, 18)])
			_open_path(world, layers, open, [Vector2i(29, 29), Vector2i(29, 26), Vector2i(20, 26), Vector2i(20, 18), Vector2i(25, 18)])
			_open_path(world, layers, open, [Vector2i(10, 6), Vector2i(10, 10), Vector2i(12, 10), Vector2i(12, 12), Vector2i(11, 12)])
			_open_rect(world, layers, open, 7, 8, 37, 9, "water")
			_open_rect(world, layers, open, 7, 22, 37, 23, "water")
			for y in [8, 9, 22, 23]:
				for x in range(7, 38):
					layers.ground[world.cell_key(Vector2i(x, y))] = {"type": "water", "movement_cost": 2.5}
			for bridge in [Vector2i(9, 8), Vector2i(15, 8), Vector2i(28, 8)]:
				_open_rect(world, layers, open, bridge.x, bridge.y, bridge.x + 2, bridge.y + 1, "road")
			_open_rect(world, layers, open, 19, 22, 21, 23, "road")
			_open_rect(world, layers, open, 6, 13, 9, 16, "stone")
			_open_path(world, layers, open, [Vector2i(5, 15), Vector2i(7, 15)])
			_open_rect(world, layers, open, 31, 3, 35, 6, "stone")
			_open_path(world, layers, open, [Vector2i(29, 4), Vector2i(31, 4)])
			_open_rect(world, layers, open, 9, 10, 11, 13, "stone")
			_open_rect(world, layers, open, 10, 13, 10, 15, "stone")
		7:
			# The reactor's west gate meets the core quickly; its eastern service
			# approach bends through a longer machinery gallery.
			_open_rect(world, layers, open, 7, 14, 13, 20, "concrete")
			_open_rect(world, layers, open, 2, 15, 4, 19, "metal")
			_open_rect(world, layers, open, 33, 15, 35, 19, "metal")
			_open_rect(world, layers, open, 8, 30, 12, 32, "metal")
			_open_path(world, layers, open, [Vector2i(10, 1), Vector2i(10, 4), Vector2i(15, 4), Vector2i(15, 10), Vector2i(10, 10), Vector2i(10, 13)])
			_open_path(world, layers, open, [Vector2i(1, 17), Vector2i(4, 17), Vector2i(4, 14), Vector2i(7, 14)])
			_open_path(world, layers, open, [Vector2i(37, 17), Vector2i(34, 17), Vector2i(34, 8), Vector2i(28, 8), Vector2i(28, 5), Vector2i(22, 5), Vector2i(22, 11), Vector2i(16, 11), Vector2i(16, 15), Vector2i(14, 15)])
			_open_path(world, layers, open, [Vector2i(10, 33), Vector2i(10, 30), Vector2i(18, 30), Vector2i(18, 27), Vector2i(13, 27), Vector2i(13, 21)])
			_open_rect(world, layers, open, 30, 11, 32, 14, "metal")
			_open_path(world, layers, open, [Vector2i(34, 12), Vector2i(32, 12)])
			_open_rect(world, layers, open, 22, 13, 25, 16, "metal")
			_open_path(world, layers, open, [Vector2i(22, 11), Vector2i(22, 14), Vector2i(23, 14)])
	# Everything outside the carved route network is a fixed barrier. That makes
	# the roads real approach choices instead of paint on an open field.
	for y in range(1, dimensions.y - 1):
		for x in range(1, dimensions.x - 1):
			var p = Vector2i(x, y)
			var key = world.cell_key(p)
			if not open.has(key):
				layers.structure[key] = {"type": "permanent", "height": 3.5, "health": 0}
	for x in range(dimensions.x):
		for y in [0, dimensions.y - 1]:
			layers.structure[world.cell_key(Vector2i(x, y))] = {"type": "permanent", "height": 3.5, "health": 0}
	for y in range(dimensions.y):
		for x in [0, dimensions.x - 1]:
			layers.structure[world.cell_key(Vector2i(x, y))] = {"type": "permanent", "height": 3.5, "health": 0}
	# Preserve deployment and objective coordinates used by saves, benchmarks,
	# and the combat flow. Maps 1-3 retain their original three-front schedule.
	layers.markers[world.cell_key(center)] = {"type": "objective"}
	layers.markers[world.cell_key(center + Vector2i(0, 2))] = {"type": "player"}
	layers.markers[world.cell_key(Vector2i(center.x, 1))] = {"type": "enemy"}
	var events: Array = []
	var reserved: Dictionary = {}
	if index < 3:
		var west = Vector2i(2, center.y)
		var east = Vector2i(dimensions.x - 3, center.y)
		for pair in [[west, 4], [east, 8]]:
			var point: Vector2i = pair[0]
			var round_number = int(pair[1])
			var key = world.cell_key(point)
			layers.markers[key] = {"type": "enemy", "unlock": round_number}
			layers.structure[key] = {"type": "gate", "health": 0, "height": 3.0, "locked": true}
			var inward = Vector2i(1 if point.x == 2 else -1, 0)
			var build_sites = [world.cell_key(point + inward + Vector2i(0, -1)), world.cell_key(point + inward + Vector2i(0, 1))]
			for build_key in build_sites: reserved[build_key] = true
			events.append({"id": "west" if round_number == 4 else "east", "round": round_number, "remove": [key], "build": build_sites, "message": ("West service loop opened. Hold the new flank." if round_number == 4 else "East service loop opened. Defend both flanks.")})
	else:
		var portals = [Vector2i(1, center.y), Vector2i(dimensions.x - 2, center.y), Vector2i(center.x, dimensions.y - 2)]
		for portal_index in portals.size():
			var point: Vector2i = portals[portal_index]
			var round_number = (portal_index + 1) * 4
			var key = world.cell_key(point)
			layers.markers[key] = {"type": "enemy", "unlock": round_number}
			layers.structure[key] = {"type": "gate", "health": 0, "height": 3.0, "locked": true}
			var inward = Vector2i(0, -2) if point.y == dimensions.y - 2 else Vector2i(2 if point.x == 1 else -2, 0)
			var build_sites = [world.cell_key(point + inward + Vector2i(0, -1)), world.cell_key(point + inward + Vector2i(0, 1))] if point.x == 1 or point.x == dimensions.x - 2 else [world.cell_key(point + Vector2i(-1, -2)), world.cell_key(point + Vector2i(1, -2))]
			for build_key in build_sites: reserved[build_key] = true
			events.append({"id": "approach_%d" % round_number, "round": round_number, "remove": [key], "build": build_sites, "message": "A new flank opens. Enemies now attack from %d fronts." % (portal_index + 2)})
	if index == 6:
		for key in layers.ground:
			if layers.ground[key].get("type", "") == "water": reserved[key] = true
	# Give each arena useful equipment without occupying its approach lanes.
	if index < 3:
		layers.objects[world.cell_key(center + Vector2i(-1, 2))] = {"type": "supply"}
		layers.objects[world.cell_key(center + Vector2i(1, 2))] = {"type": "shop"}
		layers.objects[world.cell_key(center + Vector2i(-2, -2))] = {"type": "ammo"}
		layers.objects[world.cell_key(center + Vector2i(2, -2))] = {"type": "generator"}
	else:
		for pair in [[Vector2i(-1, 2), "supply"], [Vector2i(1, 2), "shop"], [Vector2i(-2, -2), "ammo"], [Vector2i(2, -2), "generator"]]:
			layers.objects[world.cell_key(center + pair[0])] = {"type": pair[1]}
	match index:
		0:
			_cover(world, layers, Vector2i(7, 11), "steel", 500)
			_cover(world, layers, Vector2i(17, 13), "glass", 35)
			layers.objects[world.cell_key(Vector2i(4, 11))] = {"type": "electric"}
			layers.decoration[world.cell_key(Vector2i(6, 10))] = {"type": "machinery"}
		1:
			_cover(world, layers, Vector2i(10, 11), "brick", 220)
			_cover(world, layers, Vector2i(14, 14), "brick", 220)
			for dx in [-1, 0, 1]:
				layers.height[world.cell_key(center + Vector2i(dx, -1))] = {"type": "ceiling", "elevation": 5.0}
			layers.objects[world.cell_key(Vector2i(7, 7))] = {"type": "slow"}
			layers.decoration[world.cell_key(Vector2i(17, 17))] = {"type": "pipe"}
		2:
			_cover(world, layers, Vector2i(6, 12), "barricade", 140, 1.6)
			_cover(world, layers, Vector2i(18, 12), "barricade", 140, 1.6)
			layers.objects[world.cell_key(Vector2i(6, 6))] = {"type": "spikes"}
			layers.objects[world.cell_key(Vector2i(18, 18))] = {"type": "slow"}
			layers.decoration[world.cell_key(Vector2i(17, 6))] = {"type": "vegetation"}
		3:
			for p in [Vector2i(10, 16), Vector2i(22, 16), Vector2i(16, 10), Vector2i(16, 22)]: _pillar(world, layers, p, 9.0)
			for y in range(14, 19):
				layers.height[world.cell_key(Vector2i(16, y))] = {"type": "ceiling", "elevation": 6.0}
			layers.objects[world.cell_key(Vector2i(8, 11))] = {"type": "electric"}
			layers.objects[world.cell_key(Vector2i(24, 22))] = {"type": "fire"}
			layers.decoration[world.cell_key(Vector2i(7, 11))] = {"type": "machinery"}
		4:
			for p in [Vector2i(12, 8), Vector2i(22, 8), Vector2i(12, 20), Vector2i(22, 20)]: _cover(world, layers, p, "glass", 35)
			for x in [14, 20]:
				layers.height[world.cell_key(Vector2i(x, center.y))] = {"type": "ceiling", "elevation": 4.5}
			layers.objects[world.cell_key(Vector2i(7, 7))] = {"type": "acid"}
			layers.objects[world.cell_key(Vector2i(27, 21))] = {"type": "electric"}
			layers.decoration[world.cell_key(Vector2i(6, 18))] = {"type": "pipe"}
		5:
			# Two offset rooftops sit beside the main loop; stairs, canopy, and tall
			# pylons make them reachable firing positions and clear grapple anchors.
			for hub in [Vector2i(5, 6), Vector2i(31, 6)]:
				for dx in [-1, 1]:
					for dy in [-1, 1]: _pillar(world, layers, hub + Vector2i(dx, dy), 9.0)
				var platform = world.cell_key(hub)
				layers.structure[platform] = {"type": "platform", "height": 0.5, "elevation": 0.9, "health": 240}
				layers.structure[world.cell_key(hub + Vector2i(0, 1))] = {"type": "stairs", "height": 1.4, "rotation": 180, "health": 250}
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]: layers.height[world.cell_key(hub + Vector2i(dx, dy))] = {"type": "ceiling", "elevation": 5.0}
				_cover(world, layers, Vector2i(14, 12), "barricade", 140, 1.6)
				_cover(world, layers, Vector2i(22, 20), "barricade", 140, 1.6)
			layers.objects[world.cell_key(Vector2i(10, 21))] = {"type": "spikes"}
			layers.objects[world.cell_key(Vector2i(26, 11))] = {"type": "electric"}
			layers.decoration[world.cell_key(Vector2i(8, 6))] = {"type": "crate"}
		6:
			for p in [Vector2i(9, 10), Vector2i(11, 10), Vector2i(9, 13), Vector2i(11, 13)]: _pillar(world, layers, p, 9.0)
			layers.structure[world.cell_key(Vector2i(10, 11))] = {"type": "platform", "height": 0.5, "elevation": 2.3, "health": 240}
			layers.structure[world.cell_key(Vector2i(10, 12))] = {"type": "stairs", "height": 1.4, "elevation": 1.4, "rotation": 180, "health": 250}
			layers.structure[world.cell_key(Vector2i(10, 13))] = {"type": "stairs", "height": 1.4, "rotation": 180, "health": 250}
			for x in range(9, 12):
				for y in range(10, 14): layers.height[world.cell_key(Vector2i(x, y))] = {"type": "ceiling", "elevation": 5.0}
			layers.objects[world.cell_key(Vector2i(7, 13))] = {"type": "spikes"}
			layers.decoration[world.cell_key(Vector2i(6, 14))] = {"type": "machinery"}
			layers.decoration[world.cell_key(Vector2i(34, 5))] = {"type": "crate"}
		7:
			for x in range(30, 33):
				for y in range(11, 15): layers.height[world.cell_key(Vector2i(x, y))] = {"type": "ceiling", "elevation": 5.0}
			for x in range(23, 26):
				for y in range(13, 16): layers.height[world.cell_key(Vector2i(x, y))] = {"type": "ceiling", "elevation": 4.5}
			_cover(world, layers, Vector2i(30, 13), "steel", 500)
			_cover(world, layers, Vector2i(24, 15), "brick", 220)
			layers.objects[world.cell_key(Vector2i(31, 14))] = {"type": "electric"}
			layers.objects[world.cell_key(Vector2i(25, 15))] = {"type": "slow"}
			layers.decoration[world.cell_key(Vector2i(30, 12))] = {"type": "machinery"}
			layers.decoration[world.cell_key(Vector2i(23, 13))] = {"type": "pipe"}
	var cache_sites = [Vector2i(6, 12), Vector2i(18, 18), Vector2i(18, 7), Vector2i(7, 12), Vector2i(28, 21), Vector2i(27, 12), Vector2i(8, 14), Vector2i(31, 11)]
	layers.objects[world.cell_key(cache_sites[index])] = {"type": "chest"}
	if index == 6: layers.objects[world.cell_key(Vector2i(33, 5))] = {"type": "chest"}
	elif index == 7: layers.objects[world.cell_key(Vector2i(24, 14))] = {"type": "chest"}
	var ids = ["foundry", "relay", "crossroads", "crucible", "floodworks", "skyline", "quarry", "reactor"]
	var names = ["The Foundry", "Relay Station", "Crossroads", "The Crucible", "Floodworks", "Skyline Yard", "Switchback Quarry", "Reactor Spine"]
	var descriptions = [
		"A switchback service maze loops around the foundry core. West and east flanks open on waves 4 and 8.",
		"A ring-shaped relay concourse joins offset portal halls beneath a covered central station. Side gates open on waves 4 and 8.",
		"A parkland ring crosses two slow flood channels at offset bridges. Side gates open on waves 4 and 8.",
		"Nested furnace circuits and narrow bridgeheads wrap the crucible. New fronts open on waves 4, 8, and 12.",
		"Canal banks, weighted water crossings, and an inner service loop turn the floodworks into a route puzzle. New fronts open on waves 4, 8, and 12.",
		"A looping yard surrounds two elevated rooftops with stair access, canopy cover, and grapple pylons. New fronts open on waves 4, 8, and 12.",
		"Quarry switchbacks cross two slow water cuts at stone bridges, with an optional firing terrace above the service road. West, east, and south gates open on waves 4, 8, and 12.",
		"The reactor's short western gate and long eastern service spine meet at an offset core, with covered maintenance alcoves along the gallery. West, east, and south gates open on waves 4, 8, and 12."
	]
	return {"version": 2, "id": ids[index], "name": names[index], "description": descriptions[index], "author": "GRIDFALL", "width": dimensions.x, "height": dimensions.y, "seed": seed_value, "theme": index % 3, "rules": world.default_rules(), "layers": layers, "build": _build_sites(world, layers, open, reserved), "events": events}

static func expand(world, round_number: int) -> String:
	var id = "frontier_%d" % round_number
	if id in world.applied or (world.map.width >= 96 and world.map.height >= 96): return ""
	var old_width = int(world.map.width)
	var old_height = int(world.map.height)
	var width = mini(96, old_width + 8)
	var height = mini(96, old_height + 8)
	var center = world.marker("objective")
	var layers = world.map.layers
	# Existing coordinates, player, buildings and evolution events stay stable.
	for key in layers.structure.keys():
		var p = world.point(key)
		if (p.x == old_width - 1 or p.y == old_height - 1) and layers.structure[key].type == "permanent":
			layers.structure.erase(key)
	for y in height:
		for x in width:
			if x < old_width - 1 and y < old_height - 1: continue
			var p = Vector2i(x, y)
			var key = world.cell_key(p)
			var lane = x == center.x or y == center.y
			layers.ground[key] = {"type": "road" if lane else "concrete"}
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				layers.structure[key] = {"type": "permanent", "height": 3.5, "health": 0}
			elif not lane and not layers.structure.has(key) and not layers.objects.has(key) and not layers.markers.has(key):
				if x % 8 == 3 and y % 8 == 3:
					layers.structure[key] = {"type": "pillar", "height": 6.0, "health": 300}
				elif x % 8 == 5 and y % 8 == 3:
					layers.objects[key] = {"type": "chest"}
				elif x % 8 == 5 and y % 8 == 5:
					layers.objects[key] = {"type": "electric"}
				elif key not in world.map.build:
					world.map.build.append(key)
	for key in layers.markers.keys():
		if layers.markers[key].type != "enemy": continue
		var p = world.point(key)
		var target = p
		if p.x >= old_width - 3: target.x = width - 2
		if p.y >= old_height - 3: target.y = height - 2
		if target != p:
			var portal = layers.markers[key]
			layers.markers.erase(key)
			layers.markers[world.cell_key(target)] = portal
			world.map.build.erase(world.cell_key(target))
	if world.map.id in ["foundry", "relay", "crossroads"]:
		# The eastern portal moves beyond the old inner wall, so open its threshold
		# while retaining the scheduled gate until its original wave.
		_open_expansion_path(world, layers, [Vector2i(old_width - 3, center.y), Vector2i(old_width - 2, center.y)])
	var south_route: Array = []
	match world.map.id:
		"foundry": south_route = [Vector2i(center.x, old_height - 2), Vector2i(center.x, old_height - 4), Vector2i(center.x + 2, old_height - 4), Vector2i(center.x + 2, 17), Vector2i(16, 17)]
		"relay": south_route = [Vector2i(center.x, old_height - 2), Vector2i(center.x, old_height - 4), Vector2i(center.x - 2, old_height - 4), Vector2i(center.x - 2, 19), Vector2i(8, 19)]
		"crossroads": south_route = [Vector2i(center.x, old_height - 2), Vector2i(center.x, old_height - 4), Vector2i(center.x - 2, old_height - 4), Vector2i(center.x - 2, 19), Vector2i(7, 19)]
		"crucible": south_route = [Vector2i(center.x, old_height - 2), Vector2i(center.x, old_height - 4), Vector2i(center.x + 3, old_height - 4), Vector2i(center.x + 3, 26), Vector2i(19, 26)]
		"floodworks": south_route = [Vector2i(center.x, old_height - 2), Vector2i(center.x, old_height - 4), Vector2i(center.x + 4, old_height - 4), Vector2i(center.x + 4, 23), Vector2i(21, 23)]
		"skyline": south_route = [Vector2i(center.x, old_height - 2), Vector2i(center.x, old_height - 4), Vector2i(center.x - 4, old_height - 4), Vector2i(center.x - 4, 24), Vector2i(14, 24)]
	if not south_route.is_empty() and "frontier_4" not in world.applied: _open_expansion_path(world, layers, south_route)
	# The original two-front maps also gain a south approach as land opens.
	var south = world.cell_key(Vector2i(center.x, height - 2))
	if not layers.markers.has(south): layers.markers[south] = {"type": "enemy"}
	world.map.width = width
	world.map.height = height
	world.applied.append(id)
	world.rebuild_flow()
	return "Frontier expanded to %d × %d tiles. New caches, grapple anchors and building ground are available.%s" % [width, height, " Territorial limit reached; waves continue." if width == 96 and height == 96 else ""]
