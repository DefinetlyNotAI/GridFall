extends RefCounted

# Authored districts share the world's existing tile and interaction contracts.
static func authored(world, index: int, seed_value: int) -> Dictionary:
	var dimensions = [Vector2i(33, 33), Vector2i(35, 29), Vector2i(37, 33)][index]
	var center = dimensions / 2
	var layers = {"ground": {}, "structure": {}, "height": {}, "markers": {}, "objects": {}, "decoration": {}, "lighting": {}}
	for y in dimensions.y:
		for x in dimensions.x:
			var p = Vector2i(x, y)
			var key = world.cell_key(p)
			var road = x == center.x or y == center.y
			var terrain = ["metal", "stone", "concrete"][index]
			if index == 1 and x in [center.x - 5, center.x - 4, center.x + 4, center.x + 5]: terrain = "water"
			layers.ground[key] = {"type": "road" if road else terrain}
			if x == 0 or y == 0 or x == dimensions.x - 1 or y == dimensions.y - 1:
				layers.structure[key] = {"type": "permanent", "height": 3.5, "health": 0}
	# Four off-road compounds leave the objective approaches open. Each has a
	# climbable approach, overhead cover, destructible cover and a useful cache.
	for side in [-1, 1]:
		for end in [-1, 1]:
			var hub = center + Vector2i(side * 8, end * 7)
			for dx in [-2, 2]:
				for dy in [-2, 2]:
					var key = world.cell_key(hub + Vector2i(dx, dy))
					layers.structure[key] = {"type": "pillar", "height": [5.0, 3.5, 8.0][index], "health": 500, "max_health": 500}
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					layers.height[world.cell_key(hub + Vector2i(dx, dy))] = {"type": "ceiling", "elevation": [5.0, 3.5, 8.0][index]}
			var ramp_key = world.cell_key(hub + Vector2i(0, 3))
			layers.structure[ramp_key] = {"type": "stairs", "height": 1.4, "rotation": 180, "health": 250}
			layers.structure[world.cell_key(hub + Vector2i(0, 2))] = {"type": "platform", "height": 0.5, "elevation": 0.9, "health": 240}
			var cover_type = ["steel", "glass", "barricade"][index]
			for dx in [-1, 1]:
				layers.structure[world.cell_key(hub + Vector2i(dx, 0))] = {"type": cover_type, "health": [500, 35, 140][index], "height": [2.8, 2.8, 1.6][index]}
			layers.objects[world.cell_key(hub)] = {"type": "chest"}
			layers.objects[world.cell_key(hub + Vector2i(3, -1))] = {"type": ["electric", "acid", "spikes"][index]}
			layers.decoration[world.cell_key(hub + Vector2i(-3, -1))] = {"type": ["machinery", "pipe", "crate"][index]}
	# Distinct traversal and defensive geography, beyond a terrain palette swap.
	if index == 0:
		for y in range(4, dimensions.y - 4):
			if absi(y - center.y) < 3 or y % 6 == 0: continue
			for x in [center.x - 4, center.x + 4]:
				layers.structure[world.cell_key(Vector2i(x, y))] = {"type": "window", "health": 150, "height": 2.8}
	elif index == 1:
		for y in [5, center.y, dimensions.y - 6]:
			for x in range(1, dimensions.x - 1):
				layers.ground[world.cell_key(Vector2i(x, y))] = {"type": "road"}
		for x in [center.x - 3, center.x + 3]:
			for y in [center.y - 3, center.y + 3]:
				layers.structure[world.cell_key(Vector2i(x, y))] = {"type": "brick", "health": 220, "height": 1.6}
	else:
		for x in range(5, dimensions.x - 4, 6):
			if absi(x - center.x) <= 2: continue
			layers.structure[world.cell_key(Vector2i(x, center.y - 3))] = {"type": "pillar", "height": 9.0, "health": 600}
			layers.structure[world.cell_key(Vector2i(x, center.y + 4))] = {"type": "pillar", "height": 6.0, "health": 600}
	layers.markers[world.cell_key(center)] = {"type": "objective"}
	layers.markers[world.cell_key(center + Vector2i(0, 2))] = {"type": "player"}
	layers.markers[world.cell_key(Vector2i(center.x, 1))] = {"type": "enemy"}
	layers.markers[world.cell_key(Vector2i(1, center.y))] = {"type": "enemy", "unlock": 4}
	layers.markers[world.cell_key(Vector2i(dimensions.x - 2, center.y))] = {"type": "enemy", "unlock": 8}
	layers.markers[world.cell_key(Vector2i(center.x, dimensions.y - 2))] = {"type": "enemy", "unlock": 12}
	for pair in [[Vector2i(-1, 2), "supply"], [Vector2i(1, 2), "shop"], [Vector2i(-2, -2), "ammo"], [Vector2i(2, -2), "generator"]]:
		layers.objects[world.cell_key(center + pair[0])] = {"type": pair[1]}
	var events: Array = []
	for point in [Vector2i(1, center.y), Vector2i(dimensions.x - 2, center.y), Vector2i(center.x, dimensions.y - 2)]:
		var key = world.cell_key(point)
		var round_number = int(layers.markers[key].unlock)
		layers.structure[key] = {"type": "gate", "health": 0, "height": 3.0, "locked": true}
		events.append({"id": "approach_%d" % round_number, "round": round_number, "remove": [key], "build": [], "message": "A new approach opened. Incoming attacks now use %d fronts." % (round_number / 4 + 1)})
	var build: Array = []
	for y in range(2, dimensions.y - 2):
		for x in range(2, dimensions.x - 2):
			var p = Vector2i(x, y)
			var key = world.cell_key(p)
			if x == center.x or y == center.y or p.distance_to(center) < 3: continue
			if layers.structure.has(key) or layers.objects.has(key) or layers.markers.has(key): continue
			if layers.ground[key].type == "water": continue
			build.append(key)
	return {"version": 2, "id": ["crucible", "floodworks", "skyline"][index], "name": ["The Crucible", "Floodworks", "Skyline Yard"][index], "description": ["Steel workshops, electric hazards and sheltered caches. Windows split the approaches.", "Flood channels slow movement. Three bridges connect glass caches, brick cover and supply stations.", "Tall grapple towers, rooftop shelters and low cover reward fast vertical fighting."][index] + " New fronts open after waves 4, 8 and 12.", "author": "GRIDFALL", "width": dimensions.x, "height": dimensions.y, "seed": seed_value, "theme": index % 3, "rules": world.default_rules(), "layers": layers, "build": build, "events": events}

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
	# The original two-front maps also gain a south approach as land opens.
	var south = world.cell_key(Vector2i(center.x, height - 2))
	if not layers.markers.has(south): layers.markers[south] = {"type": "enemy"}
	world.map.width = width
	world.map.height = height
	world.applied.append(id)
	world.rebuild_flow()
	return "Frontier expanded to %d × %d tiles. New caches, grapple anchors and building ground are available.%s" % [width, height, " Territorial limit reached; waves continue." if width == 96 and height == 96 else ""]
