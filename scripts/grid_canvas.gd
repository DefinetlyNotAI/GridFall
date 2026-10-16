extends Control

signal selected(cell: Vector2i, button: int, dragging: bool)
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
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null or game.world.map.is_empty(): return
	var world = game.world
	cell_size = minf(size.x / float(world.map.width + 2), size.y / float(world.map.height + 2)) * zoom
	offset = (size - Vector2(world.map.width, world.map.height) * cell_size) * 0.5 + pan
	draw_rect(Rect2(Vector2.ZERO, size), Color("0c151d"))
	var colors = {"concrete": Color("263844"), "grass": Color("315240"), "dirt": Color("5c4b3b"), "sand": Color("837347"), "road": Color("344956"), "metal": Color("374d5c"), "stone": Color("4a5157"), "water": Color("1d576e")}
	for y in int(world.map.height):
		for x in int(world.map.width):
			var p = Vector2i(x, y)
			var key = world.cell_key(p)
			var rect = Rect2(offset + Vector2(p) * cell_size, Vector2.ONE * (cell_size - (0.6 if not miniature else 0)))
			var terrain = world.map.layers.ground.get(key, {}).get("type", "concrete")
			var color = colors.get(terrain, Color("263844")) if visible_layers.ground else Color("14212b")
			if not editor and key in world.map.build:
				var permitted = not game.playing() or not game.challenge("pads_only") or world.map.layers.markers.get(key, {}).get("type", "") in ["pad", "tower_pad", "structure_pad"]
				if permitted: color = color.lightened(0.11)
			if visible_layers.structure and world.map.layers.structure.has(key):
				color = Color("b4844f") if world.map.layers.structure[key].type == "gate" else Color("697b87")
			draw_rect(rect, color)
			if visible_layers.objects and world.map.layers.objects.has(key):
				var tile_type = world.map.layers.objects[key].type
				draw_rect(rect.grow(-cell_size * 0.2), Color("dc8261") if tile_type in world.HAZARDS else Color("c1a665"))
			if visible_layers.decoration and world.map.layers.decoration.has(key):
				draw_circle(rect.get_center(), cell_size * 0.18, Color("7a986c"))
			if visible_layers.lighting and world.map.layers.lighting.has(key):
				draw_circle(rect.get_center(), cell_size * 0.12, Color("ffdc92"))
			if visible_layers.height and world.map.layers.height.has(key):
				draw_rect(rect.grow(-cell_size * 0.1), Color("a1b5cb"), false, 1.5)
			if world.construction.has(key):
				var item = world.construction[key]
				draw_rect(rect.grow(-cell_size * 0.16), Color(item.color))
				if cell_size > 16:
					draw_string(ThemeDB.fallback_font, rect.position + Vector2(cell_size * 0.25, cell_size * 0.75), str(item.id).left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(cell_size * 0.6), Color("101c25"))
			if visible_layers.markers and world.map.layers.markers.has(key):
				var marker = world.map.layers.markers[key]
				var c = Color("5ce6d4")
				if marker.type == "enemy": c = Color("eb856a")
				if marker.type == "player": c = Color("e5eaf0")
				draw_circle(rect.get_center(), cell_size * 0.32, c)
			if key in invalid_cells: draw_rect(rect, Color("ff705d"), false, 3)
	if not editor:
		for enemy in game.enemies.values():
			var pos = offset + Vector2(enemy.node.position.x, enemy.node.position.z) / 3 * cell_size
			draw_circle(pos, maxf(1.5, cell_size * 0.13), Color("ff806a"))
		if is_instance_valid(game.player):
			var pos = offset + Vector2(game.player.position.x, game.player.position.z) / 3 * cell_size
			draw_circle(pos, maxf(2.0, cell_size * 0.18), Color("ffffff"))
			var aim = -game.player.basis.z
			draw_line(pos, pos + Vector2(aim.x, aim.z) * cell_size * 0.8, Color("ffffff"), 1.5)
	if not miniature and world.inside(hover):
		var rect = Rect2(offset + Vector2(hover) * cell_size, Vector2.ONE * cell_size)
		var allowed = editor or game.world.placement(hover) == ""
		draw_rect(rect, Color(0.4, 0.9, 0.8, 0.22) if allowed else Color(1, 0.3, 0.2, 0.22))
		draw_rect(rect, Color("6fe2cf") if allowed else Color("ef8b73"), false, 2)
	if selection_start.x >= 0 and selection_end.x >= 0:
		var top = Vector2(selection_start.min(selection_end))
		var dimensions = Vector2((selection_start - selection_end).abs() + Vector2i.ONE)
		draw_rect(Rect2(offset + top * cell_size, dimensions * cell_size), Color("f1c477"), false, 2)

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
