extends Control

const TileArt = preload("res://scripts/tile_art.gd")

signal selected(cell: Vector2i, button: int, dragging: bool)

class TerrainLayer extends Control:
	var grid
	func _draw() -> void:
		grid.draw_terrain(self)

var terrain_layer: TerrainLayer
var terrain_state: Array = []
var game
var editor = false
var miniature = false
var zoom = 1.0
var pan = Vector2.ZERO
var hover = Vector2i(-1, -1)
var selection_start = Vector2i(-1, -1)
var selection_end = Vector2i(-1, -1)
var painting = false
var panning = false
var cell_size = 20.0
var offset = Vector2.ZERO
var visible_layers = {"ground": true, "structure": true, "markers": true, "objects": true, "decoration": true, "lighting": true, "height": true}
var invalid_cells: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if miniature else Control.MOUSE_FILTER_STOP
	clip_contents = true
	terrain_layer = TerrainLayer.new()
	terrain_layer.grid = self
	terrain_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain_layer.show_behind_parent = true
	add_child(terrain_layer)
	set_process(true)

func _process(_delta: float) -> void:
	if game == null or game.world.map.is_empty(): return
	update_layout()
	var current = [game.world.nav_revision, size, zoom, pan, visible_layers.duplicate(), editor, miniature, game.playing(), game.challenge("pads_only"), invalid_cells.hash(), game.ui.build_id]
	if current != terrain_state:
		terrain_state = current
		terrain_layer.queue_redraw()
	queue_redraw()

func update_layout() -> void:
	var world = game.world
	cell_size = minf(size.x / float(world.map.width + 2), size.y / float(world.map.height + 2)) * zoom
	offset = (size - Vector2(world.map.width, world.map.height) * cell_size) * 0.5 + pan

func _draw() -> void:
	if game == null or game.world.map.is_empty(): return
	var world = game.world
	cell_size = minf(size.x / float(world.map.width + 2), size.y / float(world.map.height + 2)) * zoom
	offset = (size - Vector2(world.map.width, world.map.height) * cell_size) * 0.5 + pan
	for key in world.construction:
		var p = world.point(key)
		var rect = Rect2(offset + Vector2(p) * cell_size, Vector2.ONE * (cell_size - (0.6 if not miniature else 0)))
		var item = world.construction[key]
		draw_rect(rect.grow(-cell_size * 0.16), Color(item.color))
		if cell_size > 16:
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(cell_size * 0.25, cell_size * 0.75), str(item.id).left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(cell_size * 0.6), Color("101c25"))
	if not editor:
		if game.enemies.size() > 600:
			for bucket in game.enemy_index.buckets:
				var pos = offset + (Vector2(bucket) + Vector2.ONE * 0.5) * game.enemy_index.CELL / 3 * cell_size
				var count = game.enemy_index.buckets[bucket].size()
				draw_circle(pos, clampf(1.5 + log(1.0 + count) * 0.6, 2, 6), Color("ff806a"))
		else:
			for uid in game.enemy_index.ids:
				var enemy = game.enemies[uid]
				var pos = offset + Vector2(enemy.node.position.x, enemy.node.position.z) / 3 * cell_size
				draw_circle(pos, maxf(1.5, cell_size * 0.13), Color("ff806a"))
		if is_instance_valid(game.player):
			var pos = offset + Vector2(game.player.position.x, game.player.position.z) / 3 * cell_size
			draw_circle(pos, maxf(2.0, cell_size * 0.18), Color("ffffff"))
			var aim = -game.player.basis.z
			draw_line(pos, pos + Vector2(aim.x, aim.z) * cell_size * 0.8, Color("ffffff"), 1.5)
	if not miniature and world.inside(hover):
		var rect = Rect2(offset + Vector2(hover) * cell_size, Vector2.ONE * cell_size)
		var allowed = editor or game.placement(hover) == ""
		draw_rect(rect, Color(0.4, 0.9, 0.8, 0.22) if allowed else Color(1, 0.3, 0.2, 0.22))
		draw_rect(rect, Color("6fe2cf") if allowed else Color("ef8b73"), false, 2)
		if not editor:
			draw_hover_details(world, hover)
	if miniature and game.playing():
		draw_horde_arrows(world)
	if selection_start.x >= 0 and selection_end.x >= 0:
		var top = Vector2(selection_start.min(selection_end))
		var dimensions = Vector2((selection_start - selection_end).abs() + Vector2i.ONE)
		draw_rect(Rect2(offset + top * cell_size, dimensions * cell_size), Color("f1c477"), false, 2)

func draw_hover_details(world, p: Vector2i) -> void:
	var key = world.cell_key(p)
	var ground: Dictionary = world.map.layers.ground.get(key, {})
	var lines: Array[String] = ["%s  /  %s ground · Move ×%.1f" % [str(p), str(ground.get("type", "missing")), world.movement_cost(p)]]
	var structure: Dictionary = world.map.layers.structure.get(key, {})
	if world.construction.has(key):
		var built: Dictionary = world.construction[key]
		lines.append("Built: %s · Level %d · HP %d/%d" % [built.name, built.level, built.health, built.max_health])
	if not structure.is_empty():
		var kind = str(structure.get("type", "structure"))
		var physical: Dictionary = world.WALL_DEFS.get(kind, {})
		var health = int(structure.get("health", physical.get("health", 0)))
		lines.append("Structure: %s · %dm · %d HP · %.0f%% resistance" % [kind.capitalize(), int(round(float(structure.get("height", physical.get("height", 0.0))))), health, float(structure.get("resistance", physical.get("resistance", 0.0))) * 100])
	var object: Dictionary = world.map.layers.objects.get(key, {})
	if not object.is_empty(): lines.append("Object: %s · %s" % [str(object.type).capitalize(), "hazard ground effect" if object.type in world.HAZARDS else "solid collision"])
	var decoration: Dictionary = world.map.layers.decoration.get(key, {})
	if not decoration.is_empty(): lines.append("Environment: %s · %s" % [str(decoration.type).capitalize(), "solid collision" if decoration.type in ["crate", "machinery", "pipe"] else "decoration"])
	var height_tile: Dictionary = world.map.layers.height.get(key, {})
	if not height_tile.is_empty(): lines.append("Overhead: %s · %.1f m" % [str(height_tile.type).capitalize(), float(height_tile.get("elevation", 3.5))])
	var marker: Dictionary = world.map.layers.markers.get(key, {})
	if not marker.is_empty():
		var marker_type = str(marker.type)
		var marker_text = "Marker: " + marker_type.capitalize()
		if marker_type == "tower_pad": marker_text += " · attack towers only"
		elif marker_type == "structure_pad": marker_text += " · non-tower structures only"
		elif marker_type == "enemy" and int(marker.get("unlock", 0)) > 0: marker_text += " · opens wave %d" % int(marker.unlock)
		lines.append(marker_text)
	var reason = game.placement(p)
	if reason == "":
		var mount_height = world.mount_height(p, game.ui.build_id)
		lines.append("Build: wall mount at %.1f m" % mount_height if mount_height > 0 else "Build: permitted")
	else:
		lines.append("Build: " + reason)
	var width = minf(330, size.x - 16)
	var wrapped: Array[String] = []
	for line in lines:
		var current_line = ""
		for word in line.split(" "):
			var candidate = current_line + (" " if current_line != "" else "") + word
			if current_line != "" and ThemeDB.fallback_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > width - 14:
				wrapped.append(current_line)
				current_line = word
			else: current_line = candidate
		wrapped.append(current_line)
	lines = wrapped
	var line_height = 16
	var height = lines.size() * line_height + 12
	var tile_pos = offset + Vector2(p) * cell_size
	var box_pos = tile_pos + Vector2(cell_size + 8, 0)
	if box_pos.x + width > size.x - 4: box_pos.x = tile_pos.x - width - 8
	box_pos.x = clampf(box_pos.x, 4, maxf(4, size.x - width - 4))
	box_pos.y = clampf(tile_pos.y, 4, maxf(4, size.y - height - 4))
	draw_rect(Rect2(box_pos, Vector2(width, height)), Color("101a22", 0.96))
	draw_rect(Rect2(box_pos, Vector2(width, height)), Color("5c7b87"), false, 1)
	for i in lines.size():
		draw_string(ThemeDB.fallback_font, box_pos + Vector2(7, 15 + i * line_height), lines[i], HORIZONTAL_ALIGNMENT_LEFT, width - 14, 12, Color("e1edf1") if i < lines.size() - 1 else Color("88dfcf") if reason == "" else Color("f0a18e"))

func draw_horde_arrows(world) -> void:
	var buckets: Dictionary = game.enemy_index.buckets
	if buckets.is_empty(): return
	# Aggregate the bucket index into a fixed 8×8 screen grid; never visit individual enemies here.
	var groups: Dictionary = {}
	var grid_size = Vector2i(8, 8)
	for bucket in buckets:
		var members: Array = buckets[bucket]
		if members.is_empty(): continue
		var enemy_cell = world.cell(Vector3((bucket.x + 0.5) * game.enemy_index.CELL, 0, (bucket.y + 0.5) * game.enemy_index.CELL))
		if not world.inside(enemy_cell): continue
		var next = world.next_cell(enemy_cell)
		var direction = Vector2(next - enemy_cell)
		if direction.length_squared() < 0.5: continue
		var group = Vector2i(clampi(enemy_cell.x * grid_size.x / int(world.map.width), 0, grid_size.x - 1), clampi(enemy_cell.y * grid_size.y / int(world.map.height), 0, grid_size.y - 1))
		if not groups.has(group): groups[group] = {"direction": Vector2.ZERO, "count": 0}
		groups[group].direction += direction.normalized() * minf(members.size(), 8)
		groups[group].count += members.size()
	for group in groups:
		var aggregate: Dictionary = groups[group]
		var direction: Vector2 = aggregate.direction
		if direction.length_squared() < 0.25: continue
		var center = offset + Vector2((group.x + 0.5) * world.map.width / 8.0, (group.y + 0.5) * world.map.height / 8.0) * cell_size
		var heading = direction.normalized()
		var phase = fposmod(Time.get_ticks_msec() / 900.0 + group.x * 0.37 + group.y * 0.61, 1.0)
		center += heading * (phase - 0.5) * minf(cell_size * 0.8, 5.0)
		var vector = heading * minf(cell_size * 1.2, 7.0)
		var color = Color("ffd08a", clampf(0.48 + float(aggregate.count) / 20.0, 0.48, 0.95))
		draw_line(center - vector * 0.55, center + vector * 0.55, color, 1.5, true)
		var tip = center + vector * 0.55
		var back = center - vector * 0.35
		var side = vector.normalized().orthogonal() * 2.4
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), color)

func draw_terrain(canvas: CanvasItem) -> void:
	if game == null or game.world.map.is_empty(): return
	var world = game.world
	var permissions: Dictionary = {}
	for key in world.map.build: permissions[key] = true
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color("0c151d"))
	var colors = {"concrete": Color("263844"), "grass": Color("315240"), "dirt": Color("5c4b3b"), "sand": Color("837347"), "road": Color("344956"), "metal": Color("374d5c"), "stone": Color("4a5157"), "water": Color("1d576e")}
	for y in int(world.map.height):
		for x in int(world.map.width):
			var p = Vector2i(x, y)
			var key = world.cell_key(p)
			var rect = Rect2(offset + Vector2(p) * cell_size, Vector2.ONE * (cell_size - (0.6 if not miniature else 0)))
			var terrain = world.map.layers.ground.get(key, {}).get("type", "concrete")
			var color = colors.get(terrain, Color("263844")) if visible_layers.ground else Color("14212b")
			if not editor and (permissions.has(key) or terrain == "road" or world.mount_height(p, game.ui.build_id) > 0):
				var permitted = game.placement(p) == ""
				if permitted: color = color.lightened(0.11)
			if visible_layers.structure and world.map.layers.structure.has(key):
				color = Color("b4844f") if world.map.layers.structure[key].type == "gate" else Color("697b87")
			canvas.draw_rect(rect, color)
			if visible_layers.objects and world.map.layers.objects.has(key):
				var tile_type = world.map.layers.objects[key].type
				canvas.draw_rect(rect.grow(-cell_size * 0.2), Color("dc8261") if tile_type in world.HAZARDS else Color("c1a665"))
			if visible_layers.decoration and world.map.layers.decoration.has(key):
				canvas.draw_circle(rect.get_center(), cell_size * 0.18, Color("7a986c"))
			if visible_layers.lighting and world.map.layers.lighting.has(key):
				canvas.draw_circle(rect.get_center(), cell_size * 0.12, Color("ffdc92"))
			if visible_layers.height and world.map.layers.height.has(key):
				canvas.draw_rect(rect.grow(-cell_size * 0.1), Color("a1b5cb"), false, 1.5)
			if visible_layers.markers and world.map.layers.markers.has(key):
				var marker = world.map.layers.markers[key]
				var c = Color("5ce6d4")
				if marker.type == "enemy": c = Color("eb856a")
				if marker.type == "player": c = Color("e5eaf0")
				canvas.draw_circle(rect.get_center(), cell_size * 0.32, c)
			if not miniature and cell_size >= 18:
				var symbol = terrain
				for layer in ["decoration", "objects", "structure", "markers"]:
					if visible_layers.get(layer, true) and world.map.layers[layer].has(key): symbol = world.map.layers[layer][key].type
				if symbol != terrain and symbol != "permanent" and (symbol not in world.WALLS or cell_size >= 32):
					canvas.draw_rect(rect.grow(-cell_size * 0.08), Color("1a2b34"))
					canvas.draw_texture_rect(TileArt.icon(symbol), rect.grow(-cell_size * 0.08), false, Color(1, 1, 1, 0.8))
			if key in invalid_cells: canvas.draw_rect(rect, Color("ff705d"), false, 3)

func local_cell(pos: Vector2) -> Vector2i:
	return Vector2i(((pos - offset) / cell_size).floor())

func _gui_input(event: InputEvent) -> void:
	if miniature: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom = minf(4, zoom * 1.1)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom = maxf(0.4, zoom / 1.1)
		if event.button_index == MOUSE_BUTTON_MIDDLE: panning = event.pressed
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			painting = event.pressed
			if event.pressed:
				hover = local_cell(event.position)
				selected.emit(hover, event.button_index, false)
	if event is InputEventMouseMotion:
		if panning: pan += event.relative
		var cell = local_cell(event.position)
		if cell != hover:
			hover = cell
			if painting: selected.emit(cell, MOUSE_BUTTON_LEFT if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else MOUSE_BUTTON_RIGHT, true)
	accept_event()
