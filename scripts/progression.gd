extends RefCounted

const BRANCHES = {
	"Ballistics": {"color": "d9b678", "detail": "Firearms / precision / impact"},
	"Engineering": {"color": "d58e67", "detail": "Explosives / tower systems"},
	"Fortification": {"color": "8ba3b4", "detail": "Armor / shields / durability"},
	"Biotechnology": {"color": "89b89a", "detail": "Recovery / status / close combat"},
	"Energy": {"color": "80cbd3", "detail": "Plasma / abilities / conduction"},
	"Logistics": {"color": "b8bd83", "detail": "Supply / capacity / efficiency"}
}
const TEAL = Color("7ed9cb")
const AMBER = Color("e3bb7d")
const MUTED = Color("8ca3af")
const NODE_SIZE = Vector2(152, 80)
const NODE_START_X = 32.0
const NODE_GAP_X = 40.0
const NODE_GAP_Y = 12.0
const BRANCH_LANE_HEIGHT = 220.0
var ui
var game
var tree_viewport: Control
var tree_canvas: ResearchTreeCanvas
var tree_nodes: Dictionary = {}
var inspector: VBoxContainer
var selection = ""
var status_filter = 0
var view_branch = ""
var offsets: Dictionary = {}
var zoom_value = 0.92
var zoom_label: Label
var result_label: Label
var lookup: Dictionary = {}
var selecting = false
var panning = false
var pan_start = Vector2.ZERO
var canvas_start = Vector2.ZERO

class ResearchTreeCanvas extends Control:
	var node_positions: Dictionary = {}
	var links: Array = []
	var lanes: Array = []
	var stages: Array = []
	var card_size = Vector2(152, 80)

	func _draw() -> void:
		var font = ThemeDB.fallback_font
		for lane in lanes:
			var lane_y = float(lane.y)
			var lane_height = float(lane.height)
			var color: Color = lane.color
			draw_rect(Rect2(8, lane_y, size.x - 16, lane_height - 8), Color("14222a", 0.42), true)
			draw_rect(Rect2(8, lane_y, 3, lane_height - 8), Color(color, 0.82), true)
			draw_string(font, Vector2(22, lane_y + 21), str(lane.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 150, 13, color)
			draw_line(Vector2(20, lane_y + 31), Vector2(size.x - 20, lane_y + 31), Color("354852", 0.38), 1, true)
		for stage in stages:
			var x = float(stage.x)
			draw_line(Vector2(x - 14, 43), Vector2(x - 14, size.y - 14), Color("7c929b", 0.10), 1, true)
			draw_string(font, Vector2(x, 28), str(stage.label), HORIZONTAL_ALIGNMENT_LEFT, 120, 11, Color("92abb8"))
		for link in links:
			if not node_positions.has(link.from) or not node_positions.has(link.to):
				continue
			var start: Vector2 = node_positions[link.from] + Vector2(card_size.x, card_size.y * 0.5)
			var finish: Vector2 = node_positions[link.to] + Vector2(0, card_size.y * 0.5)
			var bend = maxf(30.0, (finish.x - start.x) * 0.44)
			var control_a = start + Vector2(bend, 0)
			var control_b = finish - Vector2(bend, 0)
			var points = PackedVector2Array()
			for step in 17:
				var t = float(step) / 16.0
				var inverse = 1.0 - t
				points.append(start * inverse * inverse * inverse + control_a * 3.0 * inverse * inverse * t + control_b * 3.0 * inverse * t * t + finish * t * t * t)
			var color: Color = link.color
			draw_polyline(points, color, 2.2, true)
			draw_circle(finish, 3.0, color)

class AscensionSeal extends Control:
	var wave_progress = 0.0
	var research_progress = 0.0
	var cycle = 1
	func _draw() -> void:
		var center = size * 0.5
		for i in 2:
			var radius = 64.0 - i * 12
			var color = Color("e3bb7d") if i == 0 else Color("7ed9cb")
			var progress = wave_progress if i == 0 else research_progress
			draw_arc(center, radius, 0, TAU, 64, Color("2b3941"), 3, true)
			if progress > 0: draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * minf(1, progress), 64, color, 3, true)
		var polygon = PackedVector2Array()
		for i in 7:
			polygon.append(center + Vector2.from_angle(i * TAU / 6 - PI * 0.5) * 35)
		draw_colored_polygon(polygon, Color("17282f"))
		draw_polyline(polygon, Color("9b865f"), 1.5, true)
		var text = "%02d" % cycle
		var font = ThemeDB.fallback_font
		draw_string(font, center + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x * 0.5, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("ecd4aa"))

func box_style(background: Color, border: Color, inset: int = 14) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	return style

func panel(parent: Node, color: Color, background: Color = Color("101e27")) -> VBoxContainer:
	var frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", box_style(background, color.darkened(0.65), 18))
	parent.add_child(frame)
	return ui.column(frame, 12)

func text(parent: Node, value: String, size: int = 16, color: Color = Color("d5e2e8"), wrap: bool = true) -> Label:
	var label = ui.label(parent, value, size, color)
	if not wrap: label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func divider(parent: Node, color: Color = Color("304650")) -> void:
	var line = ColorRect.new()
	line.color = color
	line.custom_minimum_size.y = 1
	parent.add_child(line)

func pips(parent: Node, value: int, maximum: int, color: Color) -> void:
	var line = ui.row(parent, 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in maximum:
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 4)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.color = color if i < value else Color("334650")
		line.add_child(pip)

func heading(title: String, ascension: bool) -> VBoxContainer:
	var body = ui.page(title)
	var tabs = ui.row(body, 10)
	ui.button(tabs, "Technology", ui.show_research, not ascension)
	ui.button(tabs, "Ascension", ui.show_ascension, ascension)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	text(tabs, "%d %s" % [game.profile.data.cores if ascension else game.profile.data.tp, "CORES" if ascension else "TP AVAILABLE"], 24, AMBER if ascension else TEAL, false)
	return body

func remember_view() -> void:
	if is_instance_valid(tree_canvas) and tree_canvas.is_inside_tree():
		offsets[view_branch] = tree_canvas.position

func show_research() -> void:
	remember_view()
	ui.overlay = "research"
	lookup.clear()
	for node in game.catalog.technologies: lookup[node.id] = node
	var body = heading("TECHNOLOGY", false)
	var layout = ui.row(body, 20)
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var branches = ui.column(layout, 10)
	branches.custom_minimum_size.x = 190
	text(branches, "RESEARCH DIVISIONS", 12, MUTED)
	for branch in ["All"] + BRANCHES.keys():
		var nodes = game.catalog.technologies.filter(func(node): return branch == "All" or node.branch == branch)
		var owned = nodes.filter(func(node): return game.profile.rank(node.id) > 0).size()
		var accent = TEAL if branch == "All" else Color(BRANCHES[branch].color)
		var action = ui.button(branches, "%s\n%d / %d researched" % ["All systems" if branch == "All" else branch, owned, nodes.size()], func():
			remember_view()
			ui.research_branch = branch
			ui.research_filter = ""
			ui.show_research())
		action.alignment = HORIZONTAL_ALIGNMENT_LEFT
		action.add_theme_font_size_override("font_size", 16)
		if branch == ui.research_branch:
			var style = box_style(Color("203039"), accent, 12)
			style.border_width_left = 3
			action.add_theme_stylebox_override("normal", style)
			action.add_theme_color_override("font_color", accent)
	ui.spacer(branches)
	text(branches, "%d TP invested" % game.profile.invested_tp(game.catalog.technologies), 15, MUTED)
	if game.profile.data.settings.get("respec_enabled", true):
		var respec = ui.button(branches, "Respec / 90% refund", ui.confirm_respec, game.read_run_checkpoint() != null or game.profile.data.research.is_empty() or game.state != "menu")
		respec.add_theme_font_size_override("font_size", 13)
	var center = ui.column(layout, 10)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text(center, ui.research_branch.to_upper() + (" / " + BRANCHES[ui.research_branch].detail if BRANCHES.has(ui.research_branch) else " / all six divisions"), 15, TEAL)
	var controls = ui.row(center, 8)
	var search = LineEdit.new()
	search.placeholder_text = "Search this division" if ui.research_branch != "All" else "Search all technology"
	search.text = ui.research_filter
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.x = 180
	controls.add_child(search)
	var status = OptionButton.new()
	for value in ["All states", "Ready to research", "Owned"]: status.add_item(value)
	status.selected = status_filter
	controls.add_child(status)
	var zoom_controls = ui.row(center, 8)
	result_label = text(zoom_controls, "", 13, MUTED)
	result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.button(zoom_controls, "−", func(): change_zoom(1.0 / 1.15))
	zoom_label = text(zoom_controls, "%d%%" % roundi(zoom_value * 100), 14)
	zoom_label.custom_minimum_size.x = 44
	ui.button(zoom_controls, "+", func(): change_zoom(1.15))
	ui.button(zoom_controls, "Focus", func(): focus_selection())
	var tree_frame = PanelContainer.new()
	tree_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_frame.add_theme_stylebox_override("panel", box_style(Color("0b171f"), Color("293e49"), 0))
	center.add_child(tree_frame)
	tree_viewport = Control.new()
	tree_viewport.clip_contents = true
	tree_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	tree_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_frame.add_child(tree_viewport)
	tree_canvas = ResearchTreeCanvas.new()
	tree_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_viewport.add_child(tree_canvas)
	tree_viewport.gui_input.connect(on_tree_viewport_input)
	text(center, "Drag or scroll to explore · Ctrl + wheel to zoom · Select a node to inspect", 12, MUTED)
	var side = panel(layout, TEAL)
	side.get_parent().custom_minimum_size.x = 310
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(scroll)
	inspector = ui.column(scroll, 14)
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_branch = ui.research_branch
	search.text_changed.connect(func(value): ui.research_filter = value; populate_graph())
	status.item_selected.connect(func(index): status_filter = index; populate_graph())
	populate_graph()
	restore_view()

func ready(node: Dictionary) -> bool:
	if game.profile.rank(node.id) >= node.max_rank: return false
	for required in node.requires:
		if game.profile.rank(required) == 0: return false
	return true

func populate_graph() -> void:
	for child in tree_canvas.get_children():
		tree_canvas.remove_child(child)
		child.queue_free()
	tree_nodes.clear()
	tree_canvas.node_positions.clear()
	tree_canvas.links.clear()
	tree_canvas.lanes.clear()
	tree_canvas.stages.clear()
	var matches: Dictionary = {}
	var shown: Dictionary = {}
	for node in game.catalog.technologies:
		if ui.research_branch != "All" and node.branch != ui.research_branch: continue
		if ui.research_filter != "" and not (node.name + " " + node.description).to_lower().contains(ui.research_filter.to_lower()): continue
		if status_filter == 1 and (not ready(node) or game.profile.data.tp < node.cost * (game.profile.rank(node.id) + 1)): continue
		if status_filter == 2 and game.profile.rank(node.id) == 0: continue
		matches[node.id] = true
		var pending: Array = [node.id]
		while not pending.is_empty():
			var id = pending.pop_back()
			if shown.has(id): continue
			shown[id] = true
			pending.append_array(lookup[id].requires)
	result_label.text = "%d %s%s" % [matches.size(), "technology" if matches.size() == 1 else "technologies", " / prerequisites included" if shown.size() > matches.size() else ""]
	var depths: Dictionary = {}
	for node in game.catalog.technologies:
		var depth = 0
		for required in node.requires: depth = maxi(depth, int(depths.get(required, 0)) + 1)
		depths[node.id] = depth
	var branches = BRANCHES.keys() if ui.research_branch == "All" else [ui.research_branch]
	var max_depth = 0
	for node in game.catalog.technologies:
		if shown.has(node.id): max_depth = maxi(max_depth, int(depths[node.id]))
	var content_width = maxf(900.0, NODE_START_X + max_depth * (NODE_SIZE.x + NODE_GAP_X) + NODE_SIZE.x + 48)
	var content_height = 76.0 + branches.size() * BRANCH_LANE_HEIGHT
	tree_canvas.size = Vector2(content_width, content_height)
	tree_canvas.custom_minimum_size = tree_canvas.size
	for index in branches.size():
		var branch_nodes = game.catalog.technologies.filter(func(node): return shown.has(node.id) and node.branch == branches[index])
		var lane_y = 48.0 + index * BRANCH_LANE_HEIGHT
		tree_canvas.lanes.append({"name": branches[index], "y": lane_y, "height": BRANCH_LANE_HEIGHT, "color": Color(BRANCHES[branches[index]].color)})
		var grouped: Dictionary = {}
		for node in branch_nodes:
			var depth = int(depths[node.id])
			if not grouped.has(depth): grouped[depth] = []
			grouped[depth].append(node)
		for depth in grouped:
			var siblings: Array = grouped[depth]
			var group_height = siblings.size() * NODE_SIZE.y + (siblings.size() - 1) * NODE_GAP_Y
			var available_height = BRANCH_LANE_HEIGHT - 42.0
			var first_y = lane_y + 36.0 + maxf(0, (available_height - group_height) * 0.5)
			var x = NODE_START_X + int(depth) * (NODE_SIZE.x + NODE_GAP_X)
			for slot in siblings.size():
				var node: Dictionary = siblings[slot]
				var id = str(node.id)
				var rank_value = game.profile.rank(id)
				var accent = Color(BRANCHES[node.branch].color)
				var owned = rank_value >= node.max_rank
				var available = ready(node)
				var affordable = available and game.profile.data.tp >= node.cost * (rank_value + 1)
				var ink = TEAL if owned or affordable else (accent if available or rank_value > 0 else Color("71848d"))
				var entry = Button.new()
				entry.name = id
				entry.text = ""
				entry.toggle_mode = true
				entry.focus_mode = Control.FOCUS_ALL
				entry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				entry.custom_minimum_size = NODE_SIZE
				entry.size = NODE_SIZE
				entry.position = Vector2(x, first_y + slot * (NODE_SIZE.y + NODE_GAP_Y))
				var background = Color("12252c") if owned else Color("14212a")
				var normal_style = box_style(background, ink.darkened(0.45), 4)
				var hover_style = normal_style.duplicate()
				hover_style.bg_color = background.lightened(0.07)
				hover_style.border_color = accent
				var selected_style = normal_style.duplicate()
				selected_style.bg_color = Color("20333b")
				selected_style.border_color = accent
				selected_style.set_border_width_all(2)
				entry.add_theme_stylebox_override("normal", normal_style)
				entry.add_theme_stylebox_override("hover", hover_style)
				entry.add_theme_stylebox_override("pressed", selected_style)
				entry.add_theme_stylebox_override("hover_pressed", selected_style)
				entry.add_theme_stylebox_override("focus", selected_style)
				tree_canvas.add_child(entry)
				tree_nodes[id] = entry
				tree_canvas.node_positions[id] = entry.position
				var inset = MarginContainer.new()
				inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				inset.add_theme_constant_override("margin_left", 6)
				inset.add_theme_constant_override("margin_right", 6)
				inset.add_theme_constant_override("margin_top", 4)
				inset.add_theme_constant_override("margin_bottom", 4)
				inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
				entry.add_child(inset)
				var content = ui.column(inset, 3)
				content.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var title = text(content, node.name, 13, Color("e1edf0"), false)
				title.clip_text = true
				title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				var info = ui.row(content, 6)
				info.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var state = "COMPLETE" if owned else ("READY" if affordable else ("NEEDS TP" if available else "LOCKED"))
				text(info, state, 9, ink, false).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				text(info, "%d / %d" % [rank_value, node.max_rank], 10, MUTED, false)
				var footer = ui.row(content, 6)
				footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pips(footer, rank_value, int(node.max_rank), ink)
				var cost = text(footer, "—" if owned else "%d TP" % (node.cost * (rank_value + 1)), 10, ink, false)
				cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				entry.tooltip_text = node.name + "\n" + node.description
				if not matches.has(id): entry.modulate.a = 0.58
				var technology_id = id
				entry.pressed.connect(func(): game.audio.cue("ui"); select_technology(technology_id))
				for required in node.requires:
					if not shown.has(required): continue
					var line_color = accent
					line_color.a = 0.72 if game.profile.rank(required) > 0 else 0.34
					tree_canvas.links.append({"from": str(required), "to": id, "color": line_color})
				if not tree_canvas.stages.any(func(stage): return stage.x == x):
					tree_canvas.stages.append({"x": x, "label": "STAGE %02d" % (int(depth) + 1)})
	if not shown.has(selection): selection = str(matches.keys()[0]) if not matches.is_empty() else ""
	select_technology(selection)
	if shown.is_empty():
		text(inspector, "No matching technology", 23)
		text(inspector, "Try another search, division, or availability filter.", 16, MUTED)
	tree_canvas.queue_redraw()
	settle_graph()

func settle_graph() -> void:
	var expected = tree_canvas
	await ui.get_tree().process_frame
	if not is_instance_valid(expected) or expected != tree_canvas or not expected.is_inside_tree(): return
	expected.queue_redraw()

func select_technology(id: String, focus: bool = false) -> void:
	if selecting: return
	selecting = true
	selection = id
	for node_id in tree_nodes:
		tree_nodes[node_id].button_pressed = str(node_id) == id
	ui.clear_children(inspector)
	if lookup.has(id):
		var node = lookup[id]
		var rank_value = game.profile.rank(id)
		var accent = Color(BRANCHES[node.branch].color)
		text(inspector, node.branch.to_upper() + " / TIER %d" % node.get("tier", 1), 12, accent)
		text(inspector, node.name, 26)
		text(inspector, node.description, 18, Color("b3c4cc"))
		divider(inspector)
		text(inspector, "RESEARCH RANK   %d / %d" % [rank_value, node.max_rank], 14, accent)
		pips(inspector, rank_value, int(node.max_rank), accent)
		if node.value is int or node.value is float:
			var units = {"health": " HP", "shield": " shield", "core_health": " HP", "core_shield": " shield", "capacity": " slots", "scrap": " scrap", "burn": " damage/s", "poison": " damage/s", "regen": " HP/s", "projectiles": " projectiles"}
			var flat = units.has(node.effect)
			var scale_value = 1.0 if flat else 100.0
			var suffix = units[node.effect] if flat else "%"
			text(inspector, "THIS TECHNOLOGY", 12, MUTED)
			text(inspector, "+%s%s  →  +%s%s" % [str(snappedf(float(node.value) * rank_value * scale_value, 0.01)), suffix, str(snappedf(float(node.value) * mini(rank_value + 1, int(node.max_rank)) * scale_value, 0.01)), suffix], 23, accent)
		elif node.effect in ["weapon", "structure"]:
			var definition = game.catalog.weapons[node.value] if node.effect == "weapon" else game.catalog.structures[node.value]
			text(inspector, str(node.effect).to_upper() + " UNLOCK", 12, MUTED)
			text(inspector, definition.name, 20, accent)
			text(inspector, "%.0f damage · %.0fm range" % [definition.damage, definition.range], 15, MUTED)
		divider(inspector)
		if not node.requires.is_empty():
			text(inspector, "PREREQUISITES", 12, MUTED)
			for required in node.requires:
				var met = game.profile.rank(required) > 0
				var button = ui.button(inspector, ("✓ " if met else "↳ ") + lookup[required].name, func(): select_technology(required, true))
				button.add_theme_font_size_override("font_size", 14)
				button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var cost = int(node.cost * (rank_value + 1))
		var full = rank_value >= node.max_rank
		var available = ready(node)
		var can_pay = game.profile.data.tp >= cost
		text(inspector, "Fully researched" if full else ("Prerequisite research required" if not available else ("Ready to research" if can_pay else "Need %d more TP" % (cost - game.profile.data.tp))), 15, TEAL if full or (available and can_pay) else AMBER)
		var purchase = ui.button(inspector, "Fully researched" if full else "Research rank %d · %d TP" % [rank_value + 1, cost], func(): remember_view(); ui.confirm_research(node), full or not available or not can_pay)
		purchase.add_theme_font_size_override("font_size", 15)
		text(inspector, "Permanent · applies to future runs", 13, MUTED)
	selecting = false
	if focus: focus_selection()

func refresh_zoom() -> void:
	if not is_instance_valid(tree_canvas) or not tree_canvas.is_inside_tree(): return
	zoom_label.text = "%d%%" % roundi(zoom_value * 100)

func change_zoom(multiplier: float, anchor: Vector2 = Vector2(-1, -1)) -> void:
	if not is_instance_valid(tree_viewport) or not is_instance_valid(tree_canvas): return
	if anchor.x < 0 or anchor.y < 0: anchor = tree_viewport.size * 0.5
	var world_point = (anchor - tree_canvas.position) / zoom_value
	zoom_value = clampf(zoom_value * multiplier, 0.45, 1.35)
	tree_canvas.scale = Vector2.ONE * zoom_value
	tree_canvas.position = anchor - world_point * zoom_value
	offsets[view_branch] = tree_canvas.position
	refresh_zoom()

func focus_selection(center_horizontal: bool = true) -> void:
	if not is_instance_valid(tree_viewport) or not is_instance_valid(tree_canvas): return
	if selection == "" or not tree_nodes.has(selection): return
	var node: Control = tree_nodes[selection]
	var selected_center = (node.position + node.size * 0.5) * zoom_value
	var horizontal = tree_viewport.size.x * 0.5 - selected_center.x if center_horizontal else 12.0
	tree_canvas.position = Vector2(horizontal, tree_viewport.size.y * 0.5 - selected_center.y)
	offsets[view_branch] = tree_canvas.position

func on_tree_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				panning = true
				pan_start = event.position
				canvas_start = tree_canvas.position
				tree_viewport.mouse_default_cursor_shape = Control.CURSOR_DRAG
			else:
				panning = false
				tree_viewport.mouse_default_cursor_shape = Control.CURSOR_ARROW
			tree_viewport.accept_event()
			return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if event.ctrl_pressed:
				change_zoom(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12, event.position)
			else:
				var direction = -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				if event.shift_pressed: tree_canvas.position.x -= direction * 72
				else: tree_canvas.position.y -= direction * 72
				offsets[view_branch] = tree_canvas.position
			tree_viewport.accept_event()
			return
	if event is InputEventMouseMotion and panning:
		tree_canvas.position = canvas_start + event.position - pan_start
		offsets[view_branch] = tree_canvas.position
		tree_viewport.accept_event()

func restore_view() -> void:
	var expected = tree_canvas
	var remembered: Variant = offsets.get(view_branch)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	if not is_instance_valid(expected) or expected != tree_canvas or not expected.is_inside_tree(): return
	tree_canvas.scale = Vector2.ONE * zoom_value
	if remembered is Vector2:
		tree_canvas.position = remembered
	else:
		tree_canvas.position = Vector2(12, 6)
		focus_selection(false)
	offsets[view_branch] = tree_canvas.position
	refresh_zoom()

func show_ascension() -> void:
	remember_view()
	ui.overlay = "ascension"
	var body = heading("ASCENSION", true)
	var layout = ui.row(body, 24)
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var data = game.profile.data
	var reward = game.profile.ascension_reward(game.catalog.technologies)
	var saved_run = game.read_run_checkpoint() != null or game.state != "menu"
	var ritual = panel(layout, AMBER, Color("171f24"))
	ritual.get_parent().custom_minimum_size.x = 340
	text(ritual, "ASCENSION CYCLE %02d" % (data.ascensions + 1), 13, AMBER)
	var seal = AscensionSeal.new()
	seal.custom_minimum_size = Vector2(280, 154)
	seal.wave_progress = float(data.best) / 25.0
	seal.research_progress = float(data.research.size()) / 20.0
	seal.cycle = int(data.ascensions) + 1
	ritual.add_child(seal)
	text(ritual, "+%d CORES" % reward if reward > 0 else "ASCENSION LOCKED", 32 if reward > 0 else 24, AMBER)
	text(ritual, "Convert this research cycle into permanent power.", 16, MUTED)
	divider(ritual)
	requirement(ritual, "Wave record", int(data.best), 25, AMBER)
	requirement(ritual, "Technologies researched", data.research.size(), 20, TEAL)
	divider(ritual)
	var tradeoff = ui.row(ritual, 16)
	var resets = ui.column(tradeoff, 6)
	resets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text(resets, "RESETS", 12, Color("d29a87"))
	text(resets, "Research + TP\nBasic loadouts", 15, MUTED)
	var keeps = ui.column(tradeoff, 6)
	keeps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text(keeps, "PRESERVES", 12, TEAL)
	text(keeps, "Records + settings\nAscension upgrades", 15, MUTED)
	ui.spacer(ritual)
	if saved_run: text(ritual, "Finish or abandon the saved run before ascending.", 14, AMBER)
	var ascend = ui.button(ritual, "Ascend · receive %d cores" % reward if reward > 0 else "Complete both requirements", ui.confirm_ascension, reward == 0 or saved_run)
	ascend.add_theme_font_size_override("font_size", 16)
	text(ritual, "%d completed ascensions" % data.ascensions, 13, MUTED)
	var right = ui.column(layout, 16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text(right, "PERMANENT AUGMENTATIONS", 18, AMBER)
	text(right, "Purchased ranks survive every ascension. Their effects apply to future runs.", 15, MUTED)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var content = ui.column(scroll, 16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)
	for id in game.profile.ASCENSION_PERKS:
		var perk = game.profile.ASCENSION_PERKS[id]
		var rank_value = game.profile.perk(id)
		var full = rank_value >= perk.max_rank
		var col = panel(grid, TEAL if rank_value > 0 else AMBER)
		col.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.get_parent().custom_minimum_size = Vector2(310, 220)
		text(col, "RANK %d / %d" % [rank_value, perk.max_rank], 12, TEAL if rank_value > 0 else MUTED)
		text(col, perk.name, 23)
		var description = text(col, perk.description, 16, Color("a5bac5"))
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pips(col, rank_value, perk.max_rank, TEAL)
		var cost = rank_value + 1
		var purchase = ui.button(col, "Fully upgraded" if full else "%s · %d core%s" % ["Unlock" if rank_value == 0 else "Upgrade", cost, "s" if cost != 1 else ""], func():
			var error = game.profile.purchase_perk(id)
			ui.notify(error if error != "" else perk.name + " upgraded.")
			ui.show_ascension(), full or data.cores < cost)
		purchase.add_theme_font_size_override("font_size", 16)
	var mutation_rank = game.profile.perk("mutation")
	text(content, "STARTING MUTATION", 13, AMBER)
	var picker = OptionButton.new()
	var ids = ["vitality", "overclock", "salvage"]
	var multiplier = maxi(1, mutation_rank)
	for option in ["Vitality / +%d starting health" % (20 * multiplier), "Overclock / +%d%% fire rate" % (8 * multiplier), "Salvage / +%d starting scrap" % (60 * multiplier)]: picker.add_item(option)
	picker.selected = ids.find(data.mutation)
	picker.disabled = mutation_rank == 0
	picker.item_selected.connect(func(index): data.mutation = ids[index]; game.profile.save())
	content.add_child(picker)
	if mutation_rank == 0: text(content, "Unlock Inherited mutation to choose a starting bonus.", 14, MUTED)
	if game.profile.perk("dual_loadout") > 0: ui.button(content, "Configure paired loadout", ui.show_loadout)

func requirement(parent: Node, name: String, value: int, target: int, color: Color) -> void:
	var line = ui.row(parent, 8)
	text(line, ("✓ " if value >= target else "") + name, 15, color).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text(line, "%d / %d" % [value, target], 15, color if value >= target else MUTED, false)
