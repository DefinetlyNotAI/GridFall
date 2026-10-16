extends Node

var ui
var game
var grid
var tools = ["Paint", "Erase", "Rectangle", "Select", "Fill", "Paste", "Inspect"]
var tool = "Paint"
var layer = "ground"
var tile_type = "concrete"
var rotation = 0
var undo_stack: Array = []
var redo_stack: Array = []
var clipboard: Dictionary = {}
var corner = Vector2i(-1, -1)
var selection_a = Vector2i(-1, -1)
var selection_b = Vector2i(-1, -1)
var path = ""
var status: Label
var palette: OptionButton
var layers = ["ground", "structure", "height", "markers", "objects", "decoration", "lighting"]
var authoring: Dictionary = {}

func open() -> void:
	game.clear_run()
	game.state = "editor"
	if authoring.is_empty():
		authoring = game.world.preset()
		authoring.id = "custom_" + str(Time.get_unix_time_from_system())
		authoring.name = "Untitled world"
		authoring.author = "Player"
	game.world.load_map(authoring)
	show_editor()

func show_editor() -> void:
	ui.overlay = "editor"
	ui.wipe()
	game.state = "editor"
	var body = ui.column(ui.backdrop())
	var top = ui.row(body, 8)
	var title = ui.label(top, "SANDBOX / " + str(game.world.map.name), 25)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.button(top, "New", new_map_dialog)
	ui.button(top, "Load / Import JSON", load_map_dialog)
	ui.button(top, "Save", func(): save_map(false))
	ui.button(top, "Save As / Export", func(): save_map(true))
	ui.button(top, "Playtest", playtest)
	ui.button(top, "Menu", func(): authoring = game.world.map.duplicate(true); game.to_menu())
	var toolbar = ui.row(body, 8)
	for item in tools:
		ui.button(toolbar, item, func(): tool = item; corner = Vector2i(-1, -1); set_status("Tool: " + tool), false)
	ui.button(toolbar, "Undo", undo)
	ui.button(toolbar, "Redo", redo)
	ui.button(toolbar, "Copy", copy_selection)
	ui.button(toolbar, "Rotate 90°", func(): rotation = (rotation + 90) % 360; set_status("Rotation %d°" % rotation))
	ui.label(body, "Custom maps are sandbox only. Paint with left mouse; right mouse erases. Rectangle and selection use two clicks. Wheel zooms; middle drag pans.", 15, Color("93afbd"))
	var content = ui.row(body, 20)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid = ui.Grid.new()
	grid.game = game
	grid.editor = true
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.selected.connect(click)
	content.add_child(grid)
	var side_scroll = ScrollContainer.new()
	side_scroll.custom_minimum_size.x = 330
	content.add_child(side_scroll)
	var side = ui.column(side_scroll)
	side.custom_minimum_size.x = 305
	ui.label(side, "AUTHORING LAYERS", 17, Color("7ed8c4"))
	var layer_picker = OptionButton.new()
	for name_value in layers: layer_picker.add_item(name_value.capitalize())
	layer_picker.selected = layers.find(layer)
	layer_picker.item_selected.connect(func(index): layer = layers[index]; update_palette())
	side.add_child(layer_picker)
	palette = OptionButton.new()
	palette.item_selected.connect(func(index): tile_type = palette.get_item_text(index))
	side.add_child(palette)
	update_palette()
	ui.label(side, "VISIBILITY", 16)
	for layer_name in layers:
		var check = CheckBox.new()
		check.text = layer_name.capitalize()
		check.button_pressed = true
		check.toggled.connect(func(value): grid.visible_layers[layer_name] = value)
		side.add_child(check)
	ui.button(side, "Map metadata", metadata_dialog)
	ui.button(side, "Validate", validate_map)
	ui.label(side, "Inspect a tile to edit height, elevation, health, rotation, or construction permission.", 16, Color("93afbd"))
	status = ui.label(side, "Full world authoring enabled.\nThis map cannot earn TP.", 16, Color("f0c58d"))

func set_status(text: String) -> void:
	if is_instance_valid(status): status.text = text

func update_palette() -> void:
	if not is_instance_valid(palette): return
	palette.clear()
	var options: Array = []
	match layer:
		"ground": options = game.world.TERRAIN
		"structure": options = game.world.WALLS
		"markers": options = game.world.MARKERS
		"objects": options = game.world.HAZARDS + ["supply", "shop", "chest", "ammo", "generator"]
		"height": options = ["ceiling", "elevation"]
		"decoration": options = ["light", "vegetation", "crate", "debris", "pipe", "machinery"]
		"lighting": options = ["light"]
	for option in options: palette.add_item(option)
	tile_type = options[0]

func checkpoint() -> void:
	undo_stack.append(game.world.map.duplicate(true))
	if undo_stack.size() > 60: undo_stack.pop_front()
	redo_stack.clear()

func undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(game.world.map.duplicate(true))
	game.world.map = undo_stack.pop_back()
	set_status("Undo")

func redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(game.world.map.duplicate(true))
	game.world.map = redo_stack.pop_back()
	set_status("Redo")

func paint(p: Vector2i, erase: bool = false) -> void:
	if not game.world.inside(p): return
	var key = game.world.cell_key(p)
	if erase:
		game.world.map.layers[layer].erase(key)
	else:
		if layer == "markers" and tile_type in ["player", "objective"]:
			for old_key in game.world.map.layers.markers.keys():
				if game.world.map.layers.markers[old_key].type == tile_type:
					game.world.map.layers.markers.erase(old_key)
		var tile = {"type": tile_type, "rotation": rotation}
		if layer == "structure":
			tile.height = 2.8
			tile.health = 0 if tile_type in ["permanent", "gate"] else 150
		game.world.map.layers[layer][key] = tile
		if layer == "ground" and key not in game.world.map.build:
			game.world.map.build.append(key)

func click(p: Vector2i, mouse_button: int, dragging: bool) -> void:
	if not game.world.inside(p): return
	if dragging and tool not in ["Paint", "Erase"]: return
	if tool == "Inspect":
		inspect(p)
		return
	if tool in ["Rectangle", "Select"]:
		if corner.x < 0:
			corner = p
			grid.selection_start = p
			grid.selection_end = p
			set_status("Choose the opposite corner.")
		else:
			selection_a = corner.min(p)
			selection_b = corner.max(p)
			grid.selection_start = selection_a
			grid.selection_end = selection_b
			if tool == "Rectangle":
				checkpoint()
				for y in range(selection_a.y, selection_b.y + 1):
					for x in range(selection_a.x, selection_b.x + 1): paint(Vector2i(x, y), mouse_button == MOUSE_BUTTON_RIGHT)
			set_status("Selected %s to %s" % [selection_a, selection_b])
			corner = Vector2i(-1, -1)
		return
	if not dragging: checkpoint()
	if tool == "Fill":
		var initial = game.world.map.layers[layer].get(game.world.cell_key(p), {}).get("type", "")
		var queue: Array = [p]
		var visited: Dictionary = {}
		var index = 0
		while index < queue.size() and index < 9216:
			var q: Vector2i = queue[index]
			index += 1
			var key = game.world.cell_key(q)
			if visited.has(key) or not game.world.inside(q): continue
			visited[key] = true
			if game.world.map.layers[layer].get(key, {}).get("type", "") != initial: continue
			paint(q)
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]: queue.append(q + d)
	elif tool == "Paste":
		for key in clipboard:
			var destination: Vector2i = p + game.world.point(key)
			if game.world.inside(destination): game.world.map.layers[layer][game.world.cell_key(destination)] = clipboard[key].duplicate(true)
	else:
		paint(p, tool == "Erase" or mouse_button == MOUSE_BUTTON_RIGHT)
	set_status("%s / %s / %s / %d°" % [p, layer, tile_type, rotation])

func copy_selection() -> void:
	if selection_a.x < 0:
		set_status("Use Select and choose two corners first.")
		return
	clipboard.clear()
	for y in range(selection_a.y, selection_b.y + 1):
		for x in range(selection_a.x, selection_b.x + 1):
			var p = Vector2i(x, y)
			var key = game.world.cell_key(p)
			if game.world.map.layers[layer].has(key):
				clipboard[game.world.cell_key(p - selection_a)] = game.world.map.layers[layer][key].duplicate(true)
	tool = "Paste"
	set_status("Copied %d tiles from %s. Click to paste." % [clipboard.size(), layer])

func inspect(p: Vector2i) -> void:
	var key = game.world.cell_key(p)
	var value = game.world.map.layers[layer].get(key, {})
	if value.is_empty():
		set_status("No tile on %s at %s." % [layer, key])
		return
	var dialog = ConfirmationDialog.new()
	dialog.title = "Tile %s / %s / %s" % [key, layer, value.type]
	var body = ui.column(dialog)
	var fields: Dictionary = {}
	for field in ["height", "elevation", "health", "rotation", "unlock"]:
		ui.label(body, field.capitalize(), 16)
		var spin = SpinBox.new()
		spin.min_value = 0
		spin.max_value = 100000 if field in ["health", "unlock"] else 360
		spin.step = 1 if field in ["health", "unlock", "rotation"] else 0.1
		spin.value = value.get(field, 0)
		body.add_child(spin)
		fields[field] = spin
	var allowed = CheckBox.new()
	allowed.text = "Allow player construction on this tile"
	allowed.button_pressed = key in game.world.map.build
	body.add_child(allowed)
	dialog.confirmed.connect(func():
		checkpoint()
		for field in fields:
			if fields[field].value > 0 or value.has(field): value[field] = fields[field].value
		game.world.map.build.erase(key)
		if allowed.button_pressed: game.world.map.build.append(key)
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	ui.root.add_child(dialog)
	dialog.popup_centered(Vector2i(420, 600))

func metadata_dialog() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "World metadata"
	var body = ui.column(dialog)
	var fields: Dictionary = {}
	for field in ["name", "description", "author"]:
		ui.label(body, field.capitalize())
		var input = LineEdit.new()
		input.text = game.world.map.get(field, "")
		body.add_child(input)
		fields[field] = input
	dialog.confirmed.connect(func():
		checkpoint()
		for field in fields: game.world.map[field] = fields[field].text.left(500)
		authoring = game.world.map.duplicate(true)
		show_editor()
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	ui.root.add_child(dialog)
	dialog.popup_centered(Vector2i(550, 340))

func new_map_dialog() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "New sandbox world"
	dialog.dialog_text = "Replace the current canvas? Save your work first."
	var body = ui.column(dialog)
	var fields: Array = []
	for title in ["Width", "Height"]:
		ui.label(body, title)
		var input = SpinBox.new()
		input.min_value = 8
		input.max_value = 96
		input.value = 25
		body.add_child(input)
		fields.append(input)
	dialog.confirmed.connect(func():
		checkpoint()
		var value = game.world.preset()
		value.id = "custom_" + str(Time.get_unix_time_from_system())
		value.name = "Untitled world"
		value.width = int(fields[0].value)
		value.height = int(fields[1].value)
		value.events = []
		value.build = []
		for name_value in value.layers: value.layers[name_value] = {}
		for y in int(value.height):
			for x in int(value.width):
				var key = game.world.cell_key(Vector2i(x, y))
				value.layers.ground[key] = {"type": "concrete"}
				if x == 0 or y == 0 or x == int(value.width) - 1 or y == int(value.height) - 1:
					value.layers.structure[key] = {"type": "permanent", "height": 3.5, "health": 0}
				else: value.build.append(key)
		var cx = int(value.width) / 2
		var cy = int(value.height) / 2
		value.layers.markers["%d,%d" % [cx, cy]] = {"type": "objective"}
		value.layers.markers["%d,%d" % [cx, cy + 1]] = {"type": "player"}
		value.layers.markers["%d,1" % cx] = {"type": "enemy"}
		game.world.load_map(value)
		authoring = value.duplicate(true)
		path = ""
		show_editor()
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	ui.root.add_child(dialog)
	dialog.popup_centered(Vector2i(420, 360))

func validate_map() -> bool:
	var issues = game.world.validate(game.world.map)
	set_status("Map valid. Ready for sandbox play." if issues.is_empty() else "\n".join(issues.slice(0, 12)))
	return issues.is_empty()

func save_map(save_as: bool) -> void:
	if path != "" and not save_as:
		var success = game.write_json(path, game.world.map)
		set_status("Saved " + path if success else "Save failed; previous file preserved.")
		authoring = game.world.map.duplicate(true)
		return
	DirAccess.make_dir_recursive_absolute("user://maps")
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.json", "GRIDFALL world")
	dialog.current_dir = ProjectSettings.globalize_path("user://maps")
	dialog.current_file = str(game.world.map.name).validate_filename() + ".json"
	dialog.file_selected.connect(func(selected_path): path = selected_path; save_map(false); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	ui.root.add_child(dialog)
	dialog.popup_centered_ratio(0.75)

func load_map_dialog() -> void:
	DirAccess.make_dir_recursive_absolute("user://maps")
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.json", "GRIDFALL world")
	dialog.current_dir = ProjectSettings.globalize_path("user://maps")
	dialog.file_selected.connect(func(selected_path):
		var file_size = FileAccess.get_file_as_bytes(selected_path).size()
		if file_size > 8 * 1024 * 1024:
			set_status("Map exceeds the 8 MB import limit.")
			dialog.queue_free()
			return
		var value = JSON.parse_string(FileAccess.get_file_as_string(selected_path))
		var issues = game.world.validate(value)
		if not issues.is_empty():
			set_status("Import rejected: " + "; ".join(issues.slice(0, 8)))
		else:
			checkpoint()
			game.world.load_map(value)
			authoring = value.duplicate(true)
			path = selected_path
			show_editor()
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	ui.root.add_child(dialog)
	dialog.popup_centered_ratio(0.75)

func playtest() -> void:
	if not validate_map(): return
	authoring = game.world.map.duplicate(true)
	game.saved_editor = authoring.duplicate(true)
	game.state = "menu"
	game.start_run("sandbox", authoring)

func return_from_playtest() -> void:
	game.clear_run()
	authoring = game.saved_editor.duplicate(true)
	game.saved_editor.clear()
	game.world.load_map(authoring)
	game.menu_camera()
	show_editor()
