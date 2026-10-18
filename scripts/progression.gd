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
var ui
var game
var graph: GraphEdit
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
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in maximum:
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 4)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	if is_instance_valid(graph) and graph.is_inside_tree():
		offsets[view_branch] = graph.scroll_offset
		zoom_value = graph.zoom

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
	graph = GraphEdit.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.show_menu = false
	graph.snapping_enabled = false
	graph.minimap_enabled = false
	graph.panning_scheme = GraphEdit.SCROLL_PANS
	graph.zoom = zoom_value
	graph.connection_lines_thickness = 2
	graph.connection_lines_curvature = 0.3
	graph.add_theme_stylebox_override("panel", box_style(Color("0b171f"), Color("293e49"), 0))
	graph.add_theme_color_override("grid_major", Color(0.2, 0.35, 0.4, 0.12))
	graph.add_theme_color_override("grid_minor", Color(0.2, 0.35, 0.4, 0.04))
	center.add_child(graph)
	text(center, "Scroll to explore · Ctrl + wheel to zoom · Select a node to inspect", 12, MUTED)
	var side = panel(layout, TEAL)
	side.get_parent().custom_minimum_size.x = 310
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(scroll)
	inspector = ui.column(scroll, 14)
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.node_selected.connect(func(node): select_technology(str(node.name)))
	var active_graph = graph
	graph.scroll_offset_changed.connect(func(offset):
		if active_graph == graph and active_graph.is_inside_tree(): offsets[view_branch] = offset)
	graph.gui_input.connect(func(event):
		if event is InputEventMouseButton: refresh_zoom.call_deferred())
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
	graph.clear_connections()
	for child in graph.get_children():
		if child is GraphNode:
			graph.remove_child(child)
			child.queue_free()
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
	var groups: Dictionary = {}
	for node in game.catalog.technologies:
		var depth = 0
		for required in node.requires: depth = maxi(depth, int(depths.get(required, 0)) + 1)
		depths[node.id] = depth
		if not shown.has(node.id): continue
		var key = node.branch + str(depth)
		if not groups.has(key): groups[key] = []
		groups[key].append(node.id)
	var indices: Dictionary = {}
	for node in game.catalog.technologies:
		if not shown.has(node.id): continue
		var rank_value = game.profile.rank(node.id)
		var accent = Color(BRANCHES[node.branch].color)
		var owned = rank_value >= node.max_rank
		var available = ready(node)
		var affordable = available and game.profile.data.tp >= node.cost * (rank_value + 1)
		var ink = TEAL if owned or affordable else (accent if available or rank_value > 0 else Color("627984"))
		var entry = GraphNode.new()
		entry.name = node.id
		entry.title = node.name
		entry.draggable = false
		entry.custom_minimum_size = Vector2(218, 84)
		var key = node.branch + str(depths[node.id])
		var lane = groups[key].find(node.id)
		if ui.research_branch == "All":
			entry.position_offset = Vector2(28 + BRANCHES.keys().find(node.branch) * 252, 46 + int(indices.get(node.branch, 0)) * 112)
		else:
			entry.position_offset = Vector2(28 + (130 if groups[key].size() == 1 else lane * 260), 46 + int(depths[node.id]) * 108)
		indices[node.branch] = int(indices.get(node.branch, 0)) + 1
		var frame = box_style(Color("12252c") if owned else Color("14212a"), ink.darkened(0.4), 10)
		frame.content_margin_top = 3
		frame.content_margin_bottom = 5
		entry.add_theme_stylebox_override("panel", frame)
		var selected_frame = frame.duplicate()
		selected_frame.bg_color = Color("20333b")
		selected_frame.border_color = accent
		entry.add_theme_stylebox_override("panel_selected", selected_frame)
		var title_style = box_style(Color("192c34"), ink.darkened(0.4), 10)
		title_style.border_width_bottom = 0
		title_style.content_margin_top = 7
		title_style.content_margin_bottom = 7
		entry.add_theme_stylebox_override("titlebar", title_style)
		var selected_title = title_style.duplicate()
		selected_title.bg_color = accent.darkened(0.7)
		selected_title.border_color = accent
		entry.add_theme_stylebox_override("titlebar_selected", selected_title)
		entry.add_theme_font_size_override("title_font_size", 15)
		graph.add_child(entry)
		for child in entry.get_titlebar_hbox().get_children():
			if child is Label:
				child.add_theme_font_size_override("font_size", 16)
				child.clip_text = true
				child.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var content = ui.column(entry, 6)
		content.custom_minimum_size.x = 198
		var info = ui.row(content, 6)
		var state = "COMPLETE" if owned else ("READY" if affordable else ("NEEDS TP" if available else "LOCKED"))
		text(info, state, 11, ink, false).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text(info, "%d / %d" % [rank_value, node.max_rank], 12, MUTED, false)
		var footer = ui.row(content, 8)
		pips(footer, rank_value, int(node.max_rank), ink)
		var cost = text(footer, "—" if owned else "%d TP" % (node.cost * (rank_value + 1)), 12, ink, false)
		cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		entry.set_slot(0, not node.requires.is_empty(), 0, ink, true, 0, ink)
		entry.tooltip_text = node.name + "\n" + node.description
		if not matches.has(node.id): entry.modulate.a = 0.5
	for node in game.catalog.technologies:
		if not shown.has(node.id): continue
		for required in node.requires:
			if shown.has(required): graph.connect_node(required, 0, node.id, 0)
	if not shown.has(selection): selection = str(matches.keys()[0]) if not matches.is_empty() else ""
	select_technology(selection)
	if shown.is_empty():
		text(inspector, "No matching technology", 23)
		text(inspector, "Try another search, division, or availability filter.", 16, MUTED)
	settle_graph()

func settle_graph() -> void:
	var expected = graph
	await ui.get_tree().process_frame
	if not is_instance_valid(expected) or expected != graph or not expected.is_inside_tree(): return
	for child in graph.get_children():
		if child is GraphNode: child.reset_size()

func select_technology(id: String, focus: bool = false) -> void:
	if selecting: return
	selecting = true
	selection = id
	for child in graph.get_children():
		if child is GraphNode: child.selected = str(child.name) == id
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
	if not is_instance_valid(graph) or not graph.is_inside_tree(): return
	zoom_value = graph.zoom
	zoom_label.text = "%d%%" % roundi(graph.zoom * 100)

func change_zoom(multiplier: float) -> void:
	var center = (graph.scroll_offset + graph.size * 0.5) / graph.zoom
	graph.zoom = clampf(graph.zoom * multiplier, graph.zoom_min, graph.zoom_max)
	graph.scroll_offset = center * graph.zoom - graph.size * 0.5
	refresh_zoom()

func focus_selection() -> void:
	if selection == "" or not graph.has_node(selection): return
	var node = graph.get_node(selection)
	graph.scroll_offset = (node.position_offset + node.size * 0.5) * graph.zoom - graph.size * 0.5
	offsets[view_branch] = graph.scroll_offset

func restore_view() -> void:
	var expected = graph
	var remembered: Variant = offsets.get(view_branch)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	if not is_instance_valid(expected) or expected != graph or not expected.is_inside_tree(): return
	var initial_x = -22.0 if view_branch == "All" else 267 * graph.zoom - graph.size.x * 0.5
	graph.scroll_offset = remembered if remembered is Vector2 else Vector2(initial_x, -15)

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
