extends CanvasLayer

const Grid = preload("res://scripts/grid_canvas.gd")
const Hud = preload("res://scripts/hud.gd")
const Editor = preload("res://scripts/editor.gd")
const Progression = preload("res://scripts/progression.gd")
var progression = Progression.new()
var game
var root: Control
var screen: Control
var hud: Control
var hud_top: Label
var boss_label: Label
var hud_left: Label
var hud_right: Label
var hints: Label
var notice: Label
var debug_label: Label
var notice_time = 0.0
var overlay = ""
var hit_flash = 0.0
var hurt_flash = 0.0
var debug_visible = false
var grid
var build_id = "sentry"
var selected_key = ""
var planning_detail: VBoxContainer
var editor
var research_filter = ""
var research_branch = "Ballistics"
var inventory_selected = -1
var rebind_action = ""
var planning_action = ""
var replace_key = ""
var build_rotation = 0
var planning_preview: Label
var loadout_selected = ""
var settings_section = "Gameplay"
var hud_refresh = 0.0
var planning_category = 0
var planning_schedule = false

func setup(owner_game) -> void:
	game = owner_game
	progression.ui = self
	progression.game = game
	var theme = Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("d5e2e8"))
	theme.set_color("font_color", "Button", Color("d5e2e8"))
	theme.set_color("font_hover_color", "Button", Color("ffffff"))
	theme.set_color("font_pressed_color", "Button", Color("f5d39a"))
	theme.set_color("font_disabled_color", "Button", Color("71838a"))
	var backgrounds = {"normal": Color("172b38"), "hover": Color("213e49"), "pressed": Color("10232d"), "focus": Color("1b3943"), "disabled": Color("111d25")}
	var borders = {"normal": Color("3b5b68"), "hover": Color("61bfae"), "pressed": Color("b9905d"), "focus": Color("8ce5d2"), "disabled": Color("263943")}
	for state in backgrounds:
		var style = StyleBoxFlat.new()
		style.bg_color = backgrounds[state]
		style.border_color = borders[state]
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(2)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		theme.set_stylebox(state, "Button", style)
	var focus_style = StyleBoxFlat.new()
	focus_style.bg_color = Color(0, 0, 0, 0)
	focus_style.border_color = Color("8ce5d2")
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(2)
	for type in ["OptionButton", "CheckButton", "CheckBox", "SpinBox", "LineEdit"]:
		theme.set_stylebox("focus", type, focus_style.duplicate())
		theme.set_color("font_disabled_color", type, Color("71838a"))
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.065, 0.085, 0.88)
	panel_style.border_color = Color("304b57")
	panel_style.set_border_width_all(1)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)
	hud = Hud.new()
	hud.game = game
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	hud_top = floating_label(hud, Vector2(30, 22), 22)
	boss_label = floating_label(hud, Vector2(30, 165), 18)
	hud_left = floating_label(hud, Vector2(30, 720), 22)
	hud_left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud_left.offset_left = 30
	hud_left.offset_right = 400
	hud_left.offset_top = -285
	hud_left.offset_bottom = -60
	hud_right = floating_label(hud, Vector2.ZERO, 23)
	hud_right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hud_right.offset_left = -400
	hud_right.offset_right = -30
	hud_right.offset_top = -185
	hud_right.offset_bottom = -60
	hud_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hints = floating_label(hud, Vector2.ZERO, 15)
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hints.offset_left = 30
	hints.offset_right = -30
	hints.offset_top = -62
	hints.offset_bottom = -12
	hints.add_theme_font_size_override("font_size", 14)
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var minimap = Grid.new()
	minimap.game = game
	minimap.miniature = true
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -208
	minimap.offset_right = -20
	minimap.offset_top = 20
	minimap.offset_bottom = 208
	hud.add_child(minimap)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(screen)
	notice = floating_label(root, Vector2.ZERO, 20)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	notice.offset_left = -450
	notice.offset_right = 450
	notice.offset_top = -85
	notice.offset_bottom = -42
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_color", Color("f5d09a"))
	debug_label = floating_label(root, Vector2(20, 210), 15)
	editor = Editor.new()
	editor.ui = self
	editor.game = game
	add_child(editor)

func floating_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var label = Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color("050d13"))
	label.add_theme_color_override("font_outline_color", Color("050d13"))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func label(parent: Node, text: String, font_size: int = 18, color: Color = Color("d5e2e8")) -> Label:
	var item = Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func button(parent: Node, text: String, action: Callable, disabled: bool = false) -> Button:
	var item = Button.new()
	item.text = text
	item.disabled = disabled
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.pressed.connect(func(): game.audio.cue("ui"); action.call())
	parent.add_child(item)
	return item

func row(parent: Node, separation: int = 12) -> HBoxContainer:
	var item = HBoxContainer.new()
	item.add_theme_constant_override("separation", separation)
	parent.add_child(item)
	return item

func column(parent: Node, separation: int = 12) -> VBoxContainer:
	var item = VBoxContainer.new()
	item.add_theme_constant_override("separation", separation)
	parent.add_child(item)
	return item

func spacer(parent: Node) -> void:
	var control = Control.new()
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(control)

func scroll_column(parent: Node, separation: int = 12) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var content = column(scroll, separation)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return content

func section(parent: Node, title: String) -> void:
	label(parent, title, 13, Color("7ed9cb"))
	var line = HSeparator.new()
	parent.add_child(line)

func readout(parent: Node, title: String, value: String) -> void:
	var line = row(parent, 20)
	label(line, title, 17, Color("92abb8")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var amount = label(line, value, 20)
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func wipe() -> void:
	for child in screen.get_children():
		screen.remove_child(child)
		child.queue_free()
	grid = null
	planning_detail = null

func backdrop(alpha: float = 0.96) -> MarginContainer:
	var background = ColorRect.new()
	background.color = Color(0.035, 0.065, 0.09, alpha)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	screen.add_child(margin)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return margin

func page(title: String, subtitle: String = "", back_action: Callable = Callable()) -> VBoxContainer:
	wipe()
	var body = column(backdrop())
	var top = row(body)
	var heading = label(top, title, 30, Color("e1f1f3"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "Back", back_action if back_action.is_valid() else show_menu)
	if subtitle != "": label(body, subtitle, 16, Color("92abb8"))
	return body

func close_overlay() -> void:
	wipe()
	overlay = ""
	planning_action = ""
	replace_key = ""
	if game.playing() and game.state != "paused": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func notify(text: String) -> void:
	notice.text = text
	notice_time = 5.0

func key_name(action: String) -> String:
	var events = InputMap.action_get_events(action)
	return events[0].as_text_physical_keycode() if not events.is_empty() and events[0] is InputEventKey else action

func show_menu() -> void:
	if game.state in ["results", "editor"]:
		game.to_menu()
		return
	game.state = "menu"
	overlay = "menu"
	wipe()
	var margin = backdrop(0.55)
	var body = column(margin, 24)
	var title = row(body)
	label(title, "GRIDFALL", 48, Color("e2f3f1")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(title, "ENDLESS DEFENSE", 15, Color("e3bb7d")).autowrap_mode = TextServer.AUTOWRAP_OFF
	var layout = row(body, 48)
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left = scroll_column(layout, 10)
	left.get_parent().custom_minimum_size.x = 330
	left.get_parent().size_flags_horizontal = Control.SIZE_FILL
	section(left, "OPERATIONS")
	if game.resume_available: button(left, "Continue saved run", func(): game.load_run())
	var deploy = button(left, "Deploy new run", show_selection)
	for state in ["normal", "hover", "pressed", "focus"]:
		var action_style: StyleBoxFlat = root.theme.get_stylebox(state, "Button").duplicate()
		action_style.bg_color = Color("23463f") if state != "pressed" else Color("17362f")
		action_style.border_color = Color("6cd7c5")
		deploy.add_theme_stylebox_override(state, action_style)
	deploy.add_theme_color_override("font_color", Color("f0d7a7"))
	section(left, "PROGRESSION")
	button(left, "Technology research · %d TP" % game.profile.data.tp, show_research)
	button(left, "Ascension · %d cores" % game.profile.data.cores, show_ascension)
	button(left, "Loadout", show_loadout)
	section(left, "TOOLS & RECORDS")
	button(left, "Sandbox map editor", func(): editor.open())
	button(left, "Statistics", show_statistics)
	button(left, "Settings", show_settings)
	button(left, "Quit", func(): game.quit_game())
	var right = column(layout, 18)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer(right)
	section(right, "OPERATOR RECORD")
	readout(right, "Best wave", str(game.profile.data.best))
	readout(right, "Completed runs", str(game.profile.data.runs))
	readout(right, "Technologies researched", "%d / %d" % [game.profile.data.research.size(), game.catalog.technologies.size()])
	readout(right, "Ascension cycles", str(game.profile.data.ascensions))
	section(right, "STARTING ARSENAL")
	var primary = str(game.profile.data.loadout)
	var secondary = str(game.profile.data.secondary_loadout) if game.profile.perk("dual_loadout") > 0 else "pistol"
	label(right, "%s / %s" % [game.catalog.weapons.get(primary, game.catalog.weapons.rifle).name, game.catalog.weapons.get(secondary, game.catalog.weapons.pistol).name], 24)
	label(right, "Fight in first person. Build between waves. Defeat earns permanent technology for the next deployment.", 18, Color("9bb1bd"))
	if game.resume_available: label(right, "A saved run is available. Continue restores its original equipment and research.", 16, Color("e3bb7d"))
	spacer(right)
	label(body, "HOLD THE CORE. BUILD THE NEXT CHANCE.", 14, Color("91c8c7"))

func show_selection() -> void:
	overlay = "selection"
	var body = page("DEPLOYMENT", "Fixed layouts · construction during Preparation · permanent research applies to standard runs")
	var content = row(body, 30)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var settings_panel = PanelContainer.new()
	settings_panel.custom_minimum_size.x = 420
	content.add_child(settings_panel)
	var settings = scroll_column(settings_panel, 16)
	section(settings, "WORLD")
	var maps = OptionButton.new()
	for world_name in game.World.LEVEL_NAMES: maps.add_item(world_name)
	maps.selected = game.selected_map
	settings.add_child(maps)
	section(settings, "OPERATION RULES")
	var mode_picker = OptionButton.new()
	var mode_ids = game.Rules.MODES.keys()
	for id in mode_ids: mode_picker.add_item(game.Rules.MODES[id].name)
	mode_picker.select(mode_ids.find("endless"))
	settings.add_child(mode_picker)
	var rule_description = label(settings, game.Rules.MODES.endless.description, 16, Color("a1b7c1"))
	var configure_rules = button(settings, "Configure Challenge rules", show_challenge_rules)
	configure_rules.visible = false
	label(settings, "SEED", 17, Color("7ed9cb"))
	var seed_input = SpinBox.new()
	seed_input.min_value = 1
	seed_input.max_value = 2147483647
	seed_input.value = game.seed_value
	settings.add_child(seed_input)
	var world_description = label(settings, "", 17, Color("a1b7c1"))
	var begin = button(settings, "Begin run", func(): deploy_run(mode_ids[mode_picker.selected]))
	var refresh_world = func():
		var mode_id = mode_ids[mode_picker.selected]
		configure_rules.visible = mode_id == "challenge"
		begin.disabled = mode_id == "siege" and game.profile.data.best < 20
		begin.text = "Reach wave 20 to unlock" if begin.disabled else ("Begin Sandbox" if mode_id == "sandbox" else "Begin run")
		if mode_id == "daily": game.seed_value = game.Rules.daily_seed(); seed_input.value = game.seed_value
		seed_input.editable = mode_id != "daily"
		rule_description.text = game.Rules.MODES[mode_id].description
		var index = absi(game.seed_value) % game.World.LEVEL_NAMES.size() if mode_id in ["seeded", "daily"] else game.selected_map
		maps.disabled = mode_id in ["seeded", "daily"]
		maps.selected = index
		game.world.load_map(game.world.preset(index, game.seed_value))
		world_description.text = "%s\n\n%d × %d tiles. Build on permitted ground away from the protected core and roads." % [game.world.map.description, game.world.map.width, game.world.map.height]
		game.visuals.rebuild()
	maps.item_selected.connect(func(index): game.selected_map = index; refresh_world.call())
	mode_picker.item_selected.connect(func(_index): refresh_world.call())
	seed_input.value_changed.connect(func(value): game.seed_value = int(value); refresh_world.call())
	refresh_world.call()
	var preview_panel = PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(preview_panel)
	var preview = Grid.new()
	preview.game = game
	preview.miniature = true
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(preview)

func deploy_run(mode_id: String) -> void:
	if mode_id == "sandbox" or game.read_run_checkpoint() == null:
		game.start_run(mode_id)
		return
	var dialog = ConfirmationDialog.new()
	dialog.title = "Replace saved run?"
	dialog.dialog_text = "Saving this new run will replace your existing checkpoint. Continue your saved run from the main menu to keep playing it."
	dialog.get_ok_button().text = "Deploy new run"
	dialog.confirmed.connect(func(): game.start_run(mode_id); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	root.add_child(dialog)
	dialog.popup_centered()

func show_challenge_rules() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Challenge rules"
	dialog.wrap_controls = false
	dialog.theme = root.theme
	var body = column(dialog)
	var fields: Dictionary = {}
	for id in game.Rules.CHALLENGES:
		var item = game.Rules.CHALLENGES[id]
		var check = CheckBox.new()
		check.text = "%s / +%.0f%% TP" % [item.name, item.weight * 100]
		check.button_pressed = game.challenge_rules.get(id, false)
		body.add_child(check)
		fields[id] = check
	label(body, "Rules are fixed when the run starts and persist in checkpoints.\nWith no modifiers, the reward multiplier is 1×.", 16, Color("9bb1bd"))
	dialog.confirmed.connect(func():
		for id in fields: game.challenge_rules[id] = fields[id].button_pressed
		notify("Challenge rules configured for the next run.")
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	root.add_child(dialog)
	dialog.popup_centered(Vector2i(650, 560))

func show_planning() -> void:
	if game.state != "preparation": return
	notice_time = 0
	selected_key = ""
	planning_action = ""
	replace_key = ""
	if not game.unlocked(game.catalog.structures[build_id]) or (not game.repairs_allowed() and game.catalog.structures[build_id].kind == "repair"): build_id = "sentry"
	overlay = "planning"
	wipe()
	var body = column(backdrop())
	var top = row(body)
	var heading = label(top, "PREPARATION / WAVE %d" % (game.wave + 1), 28)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "Supply", show_shop)
	button(top, "Rotate placement 90°", func(): build_rotation = (build_rotation + 90) % 360)
	button(top, "Return to FPS [%s]" % key_name("planning"), close_overlay)
	button(top, "Start wave [%s]" % key_name("next_wave"), func(): game.start_wave(), game.reward_pending)
	label(body, "Build on permitted tiles. Dark routes, fixed geometry, markers, and amber gates are protected. Right-click inspects. Wheel zooms; middle drag pans.", 15, Color("94aebc"))
	var preview_panel = PanelContainer.new()
	body.add_child(preview_panel)
	planning_preview = label(preview_panel, "Choose a structure and a permitted tile.", 16, Color("e8c58c"))
	planning_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content = row(body, 22)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid = Grid.new()
	grid.game = game
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	grid.selected.connect(planning_click)
	var detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size.x = 390
	content.add_child(detail_panel)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = 360
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(scroll)
	planning_detail = column(scroll)
	planning_detail.custom_minimum_size.x = 335
	refresh_planning()

func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func refresh_planning() -> void:
	if not is_instance_valid(planning_detail): return
	clear_children(planning_detail)
	label(planning_detail, "%d SCRAP" % game.scrap, 26, Color("f1c784"))
	label(planning_detail, "Next event: " + (game.upcoming_event(game.wave + 1) if game.upcoming_event(game.wave + 1) != "" else "Standard assault"), 16)
	var faction = game.Rules.faction(game.stats, game.wave + 1, game.adaptive_run)
	if faction != "None": label(planning_detail, faction + " / " + game.Rules.faction_detail(faction), 15, Color("dbb087"))
	var pending_events = game.world.map.events.filter(func(event): return event.id not in game.world.applied)
	if not pending_events.is_empty():
		button(planning_detail, "%s world schedule / %d events" % ["Hide" if planning_schedule else "Show", pending_events.size()], func(): planning_schedule = not planning_schedule; refresh_planning())
		if planning_schedule:
			for event in pending_events: label(planning_detail, "After wave %d: %s" % [event.round, event.message], 14, Color("8ca6b4"))
	if selected_key != "" and game.world.construction.has(selected_key):
		var item = game.world.construction[selected_key]
		label(planning_detail, item.name + " · L%d" % item.level, 22)
		label(planning_detail, "HP %d / %d\nDamage %.0f · Range %.1fm\n%s" % [item.health, item.max_health, item.damage, item.range, item.branch], 17)
		section(planning_detail, "SERVICE & SPECIALIZATION")
		var repair_cost = int(ceil((item.max_health - item.health) * 0.15 * (1 - game.bonus("repair_efficiency"))))
		button(planning_detail, "Repair · %d scrap" % repair_cost, func(): manage("repair"), not game.repairs_allowed() or item.health >= item.max_health or game.scrap < repair_cost)
		for branch_id in ["power", "rapid", "resonant"]:
			if branch_id != "power" and item.kind != "tower": continue
			if branch_id == "resonant" and game.perk("tower_evolution") == 0: continue
			var branch = game.catalog.structure_upgrades[branch_id]
			var price = int(item.cost * branch.cost * item.level)
			var branch_name = branch.name if item.kind == "tower" else "Reinforce"
			button(planning_detail, "%s · %d scrap" % [branch_name, price], func(): manage(branch_id), item.level >= 4 or item.get("branch_id", "") not in ["", branch_id] or game.scrap < price)
		button(planning_detail, "Target: " + game.TARGET_MODES[int(item.target_mode)], func(): manage("target"), item.kind != "tower")
		section(planning_detail, "PLACEMENT & SALVAGE")
		button(planning_detail, "Sell · %d scrap" % int(item.invested * 0.65 * maxf(0.2, item.health / item.max_health)), func(): manage("sell"))
		button(planning_detail, "Demolish", func(): manage("demolish"))
		button(planning_detail, "Rotate 90°", func(): manage("rotate"))
		button(planning_detail, "Move · %d scrap" % maxi(1, int(ceil(item.cost * 0.1))), func(): planning_action = "move"; notify("Choose a permitted destination tile."))
		button(planning_detail, "Replace using resale credit", func(): replace_key = selected_key; selected_key = ""; planning_action = "replace"; refresh_planning())
		button(planning_detail, "Construction catalog", func(): selected_key = ""; planning_action = ""; refresh_planning())
	else:
		section(planning_detail, "CONSTRUCTION")
		var categories = OptionButton.new()
		for category in ["All structures", "Attack towers", "Defenses & traps", "Support & economy"]: categories.add_item(category)
		categories.selected = planning_category
		categories.item_selected.connect(func(index): planning_category = index; refresh_planning())
		planning_detail.add_child(categories)
		var selected = game.catalog.structures[build_id]
		label(planning_detail, selected.name, 23, Color("e3bb7d"))
		label(planning_detail, "%d scrap · %d HP · %.0fm range" % [game.build_cost(selected), selected.health, selected.range], 16, Color("92abb8"))
		if selected.damage > 0:
			label(planning_detail, "%.0f damage%s" % [selected.damage, " / %.2fs" % selected.interval if selected.interval > 0 else " per trigger"], 16)
		if game.scrap < game.build_cost(selected): label(planning_detail, "Need %d more scrap" % (game.build_cost(selected) - game.scrap), 15, Color("e3bb7d"))
		for id in game.catalog.structures:
			var definition = game.catalog.structures[id]
			if planning_category == 1 and definition.kind != "tower": continue
			if planning_category == 2 and definition.kind not in ["wall", "trap", "shield"]: continue
			if planning_category == 3 and definition.kind not in ["support", "repair", "generator", "ammo"]: continue
			var text = ("> " if id == build_id else "") + definition.name + " · %d" % game.build_cost(definition)
			var item = button(planning_detail, text, func():
				build_id = id
				if planning_action == "replace":
					var reason = game.replace_structure(replace_key, id)
					notify(reason if reason != "" else "Structure replaced.")
					selected_key = replace_key
					planning_action = ""
				refresh_planning(), not game.unlocked(definition) or (not game.repairs_allowed() and definition.kind == "repair"))
			item.tooltip_text = "HP %d · damage %d · range %.0fm%s" % [definition.health, definition.damage, definition.range, "\nResearch: " + definition.tech if definition.tech != "" else ""]
			item.alignment = HORIZONTAL_ALIGNMENT_LEFT
			item.add_theme_font_size_override("font_size", 16)
			if id == build_id: item.modulate = Color("7ed9cb")

func manage(action: String) -> void:
	var reason = game.manage_structure(selected_key, action)
	if reason != "": notify(reason)
	refresh_planning()

func planning_click(p: Vector2i, mouse_button: int, dragging: bool) -> void:
	if dragging: return
	var key = game.world.cell_key(p)
	if mouse_button == MOUSE_BUTTON_RIGHT: planning_action = ""
	if planning_action == "move" and mouse_button == MOUSE_BUTTON_LEFT:
		var reason = game.move_structure(selected_key, p)
		notify(reason if reason != "" else "Structure moved.")
		if reason == "": selected_key = key; planning_action = ""
		refresh_planning()
		return
	if game.world.construction.has(key):
		selected_key = key
		refresh_planning()
	elif mouse_button == MOUSE_BUTTON_LEFT:
		var reason = game.build(p, build_id, build_rotation)
		notify(reason if reason != "" else game.catalog.structures[build_id].name + " constructed.")
		selected_key = ""
		refresh_planning()
	else:
		notify("Tile %s · %s" % [key, game.placement(p) if game.placement(p) != "" else "Construction permitted."])

func show_upgrades() -> void:
	overlay = "upgrades"
	wipe()
	var body = column(backdrop())
	spacer(body)
	label(body, "WAVE %d CLEARED" % game.wave, 36, Color("7fdfcc"))
	label(body, "LEVEL %d / %d UPGRADE CHOICE%s REMAINING" % [game.level, game.upgrade_picks, "S" if game.upgrade_picks != 1 else ""], 16, Color("e3bb7d"))
	label(body, "Choose a temporary upgrade for this run.", 20)
	var choices = row(body, 20)
	for i in game.upgrades.size():
		var upgrade = game.upgrades[i]
		var frame = PanelContainer.new()
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.add_child(frame)
		var col = column(frame, 16)
		label(col, "OPTION %02d / %s" % [i + 1, upgrade.get("rarity", "Common").to_upper()], 13, Color("e3bb7d"))
		label(col, "%s / %s" % [upgrade.get("icon", str(i + 1)), upgrade.name], 25)
		label(col, upgrade.description, 19, Color("a7bfca"))
		spacer(col)
		if upgrade.has("cap"):
			var unit = {"health": "HP", "shield": "HP", "regen": "HP/s", "burn": "damage/s"}.get(upgrade.effect, "%")
			label(col, "Maximum total bonus: %.0f%s" % [upgrade.cap * (100 if unit == "%" else 1), unit], 14, Color("809daa"))
		button(col, "Select", func(): game.choose_upgrade(i))
	spacer(body)

func show_research() -> void:
	progression.show_research()

func confirm_respec() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Reset ordinary research?"
	dialog.dialog_text = "Reset all ordinary research and receive %d TP (90%% of invested points). Loadouts return to basic weapons. Ascension purchases remain." % int(game.profile.invested_tp(game.catalog.technologies) * 0.9)
	dialog.confirmed.connect(func():
		var error = game.respec()
		notify(error if error != "" else "Research reset and points refunded.")
		show_research()
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	root.add_child(dialog)
	dialog.popup_centered()

func confirm_research(node: Dictionary) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Research " + node.name
	dialog.get_ok_button().text = "Research rank %d" % (game.profile.rank(node.id) + 1)
	dialog.dialog_text = "%s\n\nPurchase rank %d for %d Technology Points?" % [node.description, game.profile.rank(node.id) + 1, node.cost * (game.profile.rank(node.id) + 1)]
	dialog.confirmed.connect(func():
		var error = game.profile.purchase(node)
		notify("Researched " + node.name if error == "" else error)
		show_research()
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	root.add_child(dialog)
	dialog.popup_centered()

func show_loadout() -> void:
	overlay = "loadout"
	var paired = game.profile.perk("dual_loadout") > 0
	var body = page("STARTING ARSENAL", "Selections apply to your next deployment. Saved runs retain their original equipment.")
	var content = row(body, 28)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var weapons = scroll_column(content, 8)
	weapons.get_parent().custom_minimum_size.x = 340
	weapons.get_parent().size_flags_horizontal = Control.SIZE_FILL
	section(weapons, "WEAPON CATALOG")
	if not game.catalog.weapons.has(loadout_selected): loadout_selected = game.profile.data.loadout
	if not game.catalog.weapons.has(loadout_selected): loadout_selected = "rifle"
	for id in game.catalog.weapons:
		var definition = game.catalog.weapons[id]
		var unlocked = definition.tech == "" or game.profile.rank(definition.tech) > 0
		var assignment = "PRIMARY" if game.profile.data.loadout == id else ""
		if (game.profile.data.secondary_loadout if paired else "pistol") == id: assignment += " / SECONDARY" if assignment != "" else "SECONDARY"
		var entry = button(weapons, definition.name + "\n" + (assignment if assignment != "" else ("Available" if unlocked else "Research required")), func(): loadout_selected = id; show_loadout())
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.modulate = Color("7ed9cb") if id == loadout_selected else Color.WHITE
	var detail = scroll_column(content, 18)
	var selected = game.catalog.weapons[loadout_selected]
	var available = selected.tech == "" or game.profile.rank(selected.tech) > 0
	section(detail, "BASE WEAPON SPECIFICATION")
	label(detail, selected.name, 32)
	label(detail, "Deployment rolls and research bonuses modify these base values.", 15, Color("92abb8"))
	label(detail, "PROJECTILE" if selected.speed > 0 else ("CLOSE COMBAT" if selected.magazine == 0 else "HITSCAN"), 14, Color("e3bb7d"))
	readout(detail, "Damage per attack", "%d × %d pellets" % [selected.damage, selected.pellets] if selected.pellets > 1 else str(selected.damage))
	readout(detail, "Attack rate", "%.2f / second" % (1.0 / selected.interval))
	readout(detail, "Range", "%.0f m" % selected.range)
	if selected.magazine > 0:
		readout(detail, "Magazine / reserve", "%d / %d" % [selected.magazine, selected.reserve])
		readout(detail, "Reload", "%.2f s" % selected.reload)
	if selected.splash > 0: readout(detail, "Blast radius", "%.1f m" % selected.splash)
	section(detail, "ASSIGNMENT")
	button(detail, "Assigned to primary" if game.profile.data.loadout == loadout_selected else "Assign primary", func(): game.profile.data.loadout = loadout_selected; game.profile.save(); show_loadout(), not available or game.profile.data.loadout == loadout_selected)
	if paired:
		button(detail, "Assigned to secondary" if game.profile.data.secondary_loadout == loadout_selected else "Assign secondary", func(): game.profile.data.secondary_loadout = loadout_selected; game.profile.save(); show_loadout(), not available or game.profile.data.secondary_loadout == loadout_selected)
	else:
		label(detail, "Service Pistol occupies your secondary slot. Paired arsenal in Ascension unlocks a configurable secondary.", 16, Color("92abb8"))
	if not available:
		for technology in game.catalog.technologies:
			if technology.id == selected.tech:
				label(detail, "Requires " + technology.name, 17, Color("e3bb7d"))
				button(detail, "View required research", func(): research_branch = technology.branch; research_filter = ""; progression.selection = technology.id; show_research())

func show_ascension() -> void:
	progression.show_ascension()

func confirm_ascension() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Ascend and reset ordinary research?"
	dialog.get_ok_button().text = "Ascend"
	dialog.dialog_text = "All ordinary research and Technology Points will reset. Receive %d Ascension Cores. This is optional and cannot be undone." % game.profile.ascension_reward(game.catalog.technologies)
	dialog.confirmed.connect(func():
		var error = game.ascend()
		notify(error if error != "" else "Ascension complete. Spend cores or begin rebuilding your research.")
		show_ascension()
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	root.add_child(dialog)
	dialog.popup_centered()

func show_inventory() -> void:
	if overlay != "inventory": notice_time = 0
	overlay = "inventory"
	wipe()
	var body = column(backdrop())
	var top = row(body)
	var heading = label(top, "INVENTORY / %d SCRAP" % game.scrap, 28)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "Close [%s]" % key_name("inventory"), close_overlay)
	label(body, "Combat continues while your inventory is open. Select an item to inspect, equip, attach, drop, or scrap.", 16, Color("a5bbc7"))
	var equipment = row(body)
	for i in 2:
		var item = game.weapons[i]
		var slot = column(equipment, 4)
		var weapon_slot = button(slot, "%d / %s%s\n%d / %d ammo" % [i + 1, game.item_name(item), " [ACTIVE]" if i == game.active_weapon else "", item.ammo, item.reserve], func(): game.switch_weapon(i); show_inventory())
		weapon_slot.set_drag_forwarding(Callable(), func(_position, data): return data is Dictionary and data.has("inventory") and int(data.inventory) < game.backpack.size() and game.catalog.weapons.has(game.backpack[int(data.inventory)].id), func(_position, data): game.inventory_action(int(data.inventory), "equip%d" % i))
		if item.id != "": button(slot, "Unequip", func(): game.unequip_weapon(i))
	var active_modules = game.modules(game.weapons[game.active_weapon])
	if not active_modules.is_empty():
		var module_row = row(body, 8)
		for slot in active_modules: button(module_row, "Detach " + str(slot).capitalize(), func(): game.detach_module(slot))
	label(body, "Pulse [%s] · Medkits [%s]: %d · Grenades [%s]: %d\nArmor %.0f%% · Shield %.0f · Backpack %d/%d" % [key_name("ability"), key_name("heal"), game.consumables.medkit, key_name("grenade"), game.consumables.grenade, game.bonus("armor") * 100, game.shield, game.backpack.size(), game.capacity], 17)
	var content = row(body, 24)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var slots = GridContainer.new()
	slots.columns = 4
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("h_separation", 8)
	slots.add_theme_constant_override("v_separation", 8)
	scroll.add_child(slots)
	scroll.resized.connect(func(): slots.columns = clampi(int((scroll.size.x + 8) / 158), 1, 4))
	for i in game.capacity:
		var text = "%02d / Empty" % (i + 1)
		if i < game.backpack.size(): text = "%02d / %s\n%s" % [i + 1, game.item_name(game.backpack[i]), ["Common", "Uncommon", "Rare", "Epic", "Legendary"][int(game.backpack[i].get("rarity", 0))]]
		var slot = button(slots, text, func(): inventory_selected = i; show_inventory(), i >= game.backpack.size())
		slot.custom_minimum_size = Vector2(150, 78)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.clip_text = true
		slot.tooltip_text = text
		if i == inventory_selected: slot.modulate = Color("7ed9cb")
		slot.set_drag_forwarding(func(_position): return {"inventory": i} if i < game.backpack.size() else null, func(_position, data): return data is Dictionary and data.has("inventory"), func(_position, data):
				var from = int(data.inventory)
				if from >= 0 and from < game.backpack.size():
					if i < game.backpack.size():
						var temp = game.backpack[i]
						game.backpack[i] = game.backpack[from]
						game.backpack[from] = temp
					else:
						var item = game.backpack[from]
						game.backpack.remove_at(from)
						game.backpack.append(item)
					show_inventory())
	var detail_scroll = ScrollContainer.new()
	detail_scroll.custom_minimum_size.x = 320
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(detail_scroll)
	var detail = column(detail_scroll)
	detail.custom_minimum_size.x = 320
	if inventory_selected >= 0 and inventory_selected < game.backpack.size():
		var item = game.backpack[inventory_selected]
		label(detail, game.item_name(item), 25)
		if game.catalog.weapons.has(item.id):
			var definition = game.catalog.weapons[item.id]
			var resolved = game.weapon_stats(item)
			var current = game.weapon_stats(game.weapons[game.active_weapon])
			label(detail, "Damage %.1f%s (%+.1f)\nRate %.1f shots/s\nMagazine %d\nRange %.1fm\nReload %.2fs\nRolled power ×%.2f" % [resolved.damage, " × %d pellets" % definition.pellets if definition.pellets > 1 else "", resolved.damage - current.damage, 1.0 / maxf(0.01, resolved.interval), resolved.magazine, resolved.range, resolved.reload, item.roll], 18)
			if not item.get("mods", []).is_empty(): label(detail, "Modifiers: " + ", ".join(item.mods).capitalize(), 16, Color("e0c088"))
			button(detail, "Equip primary", func(): game.inventory_action(inventory_selected, "equip0"))
			button(detail, "Equip secondary", func(): game.inventory_action(inventory_selected, "equip1"))
		else:
			label(detail, {"barrel": "+20% weapon damage", "optic": "60% less weapon spread", "magazine": "+30% magazine capacity", "grip": "25% less spread and reduced camera recoil", "elemental": "Hits burn enemies for 3 damage/s for 3 seconds", "armor": "+5% damage reduction", "shield_pack": "+30 shield"}.get(item.id, "Consumable"), 18)
			button(detail, "Use / attach to active weapon", func(): game.inventory_action(inventory_selected, "use"))
		button(detail, "Scrap · %d" % (15 + int(item.get("rarity", 0)) * 12), func(): game.inventory_action(inventory_selected, "scrap"))
		button(detail, "Sell during Preparation", func(): game.inventory_action(inventory_selected, "sell"), game.state != "preparation")
		button(detail, "Drop", func(): game.inventory_action(inventory_selected, "drop"))
	else:
		label(detail, "Select a backpack item.", 19, Color("92acba"))

func show_shop() -> void:
	if game.state != "preparation": return
	overlay = "shop"
	wipe()
	var body = column(backdrop())
	var top = row(body)
	var title = label(top, "SUPPLY / %d SCRAP" % game.scrap, 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "Close", close_overlay)
	var content = row(body, 32)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var supplies = scroll_column(content, 16)
	section(supplies, "FIELD SUPPLIES")
	for pair in [["ammo", "Ammunition · refill reserves"], ["medkit", "Medkit · restore 50 health"], ["grenade", "Grenade · 120 area damage"], ["core", "Core service · restore 120 HP"]]:
		label(supplies, pair[1], 19)
		var full = (pair[0] == "core" and game.core_health >= game.max_core) or (pair[0] in ["medkit", "grenade"] and game.consumables[pair[0]] >= 99)
		if pair[0] == "ammo": full = not game.weapons.any(func(item): return item.id != "" and game.catalog.weapons[item.id].magazine > 0 and item.reserve < 9999)
		button(supplies, "Not needed" if full else "Purchase / %d scrap" % game.supply_cost(pair[0]), func(): game.buy(pair[0]), full or game.scrap < game.supply_cost(pair[0]) or (pair[0] == "core" and not game.repairs_allowed()))
	if not game.repairs_allowed(): label(supplies, "Core service is disabled by this run's rules.", 15, Color("e3bb7d"))
	var weapons = scroll_column(content, 12)
	section(weapons, "COMMON WEAPONS")
	for id in game.catalog.weapons:
		var definition = game.catalog.weapons[id]
		var item = row(weapons)
		label(item, definition.name, 19).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var full = game.backpack.size() >= game.capacity
		button(item, "Locked" if not game.unlocked(definition) else ("Backpack full" if full else "%d scrap" % game.supply_cost(id)), func(): game.buy(id), full or not game.unlocked(definition) or game.scrap < game.supply_cost(id))
	label(weapons, "Purchases go to your backpack. Manage equipment in Inventory.", 15, Color("92abb8"))

func show_pause() -> void:
	overlay = "pause"
	wipe()
	var layout = row(backdrop(0.9), 48)
	var body = column(layout, 16)
	body.custom_minimum_size.x = 360
	spacer(body)
	label(body, "PAUSED", 38)
	button(body, "Resume", func(): game.state = game.previous_state; close_overlay())
	button(body, "Save run", func():
		if game.save_run(): notify("Run saved."),
		game.previous_state not in ["preparation", "wave"] or not game.eligible)
	button(body, "Settings", show_settings)
	if not game.saved_editor.is_empty(): button(body, "Return to map editor", func(): editor.return_from_playtest())
	button(body, "Abandon run", func(): confirm_abandon())
	spacer(body)
	var summary = column(layout, 18)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer(summary)
	section(summary, "CURRENT OPERATION")
	readout(summary, "Mode", game.Rules.MODES.get(game.mode, {"name": game.mode}).name)
	readout(summary, "Wave", str(game.wave))
	readout(summary, "Time survived", "%02d:%02d" % [int(game.elapsed) / 60, int(game.elapsed) % 60])
	readout(summary, "Core integrity", "%d / %d" % [game.core_health, game.max_core])
	readout(summary, "Scrap", str(game.scrap))
	label(summary, "Simulation is paused. Save preserves this run's equipment, defenses and combat state." if game.eligible else "Sandbox progress cannot be saved and awards no permanent rewards.", 17, Color("92abb8"))
	spacer(summary)

func confirm_abandon() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Abandon this run?"
	dialog.dialog_text = "Unsaved run progress will be lost. No Technology Points are awarded for abandonment."
	dialog.confirmed.connect(func(): game.remove_run_save(); game.to_menu(); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	root.add_child(dialog)
	dialog.popup_centered()

func show_results() -> void:
	notice_time = 0
	overlay = "results"
	wipe()
	var body = column(backdrop(), 22)
	label(body, "OPERATION ENDED", 14, Color("e3bb7d"))
	label(body, game.defeat_reason.to_upper(), 36, Color("f0a17f"))
	var content = row(body, 48)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var combat = scroll_column(content, 12)
	var outcome = scroll_column(content, 16)
	var s = game.stats
	section(combat, "COMBAT REPORT")
	for entry in [["Waves cleared", str(s.get("cleared", game.completed))], ["Enemies defeated", str(s.kills)], ["Bosses defeated", str(s.bosses)], ["Best streak", str(s.streak)], ["Weapon damage", "%.0f" % s.weapon_damage], ["Tower damage", "%.0f" % s.tower_damage], ["Pulse damage", "%.0f" % s.get("ability_damage", 0)], ["Structures built", str(s.built)], ["Scrap earned / spent", "%d / %d" % [s.earned, s.spent]]]:
		readout(combat, entry[0], entry[1])
	section(combat, "DAMAGE BREAKDOWN")
	readout(combat, "Total damage", "%.0f" % s.damage)
	readout(combat, "Explosive damage", "%.0f" % s.get("explosive_damage", 0))
	readout(combat, "Elemental damage", "%.0f" % s.get("elemental_damage", 0))
	section(outcome, "DEPLOYMENT OUTCOME")
	readout(outcome, "Final wave", str(game.wave))
	readout(outcome, "Time survived", "%02d:%02d" % [int(game.elapsed) / 60, int(game.elapsed) % 60])
	readout(outcome, "Score", str(s.get("score", 0)))
	if not s.get("records", []).is_empty(): label(outcome, "Records: " + ", ".join(s.records), 17, Color("e3bb7d"))
	section(outcome, "PERMANENT PROGRESSION")
	if not game.eligible:
		label(outcome, "SANDBOX / NO PERMANENT REWARDS", 23, Color("9bb1bc"))
	elif game.last_reward < 0:
		label(outcome, "Reward could not be saved: " + game.profile.error, 20, Color("ef9b7d"))
		button(outcome, "Retry reward save", func():
			game.last_reward = game.profile.award(game.run_id, game.stats, true)
			if game.last_reward >= 0: game.remove_run_save()
			show_results())
	else:
		label(outcome, "+%d TP" % game.last_reward, 36, Color("7edcc7"))
		readout(outcome, "Available balance", "%d TP" % game.profile.data.tp)
	if not s.get("achievements", []).is_empty():
		section(outcome, "ACHIEVEMENTS EARNED")
		for achievement in s.achievements: label(outcome, achievement, 18, Color("e9c68c"))
	var controls = row(body)
	button(controls, "Technology research", show_research)
	button(controls, "New run", func(): game.to_menu(); show_selection())
	button(controls, "Main menu", func(): game.to_menu())
	if not game.saved_editor.is_empty(): button(controls, "Return to editor", func(): editor.return_from_playtest())

func show_statistics() -> void:
	overlay = "statistics"
	var body = page("SERVICE RECORD")
	var data = game.profile.data
	var content = row(body, 48)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var record = scroll_column(content, 14)
	section(record, "LIFETIME OPERATIONS")
	for entry in [["Completed runs", str(data.runs)], ["Best wave", str(data.best)], ["Highest score", str(data.high_score)], ["Survival time", "%.1f minutes" % (data.survival_time / 60)], ["Enemies defeated", str(data.kills)], ["Bosses defeated", str(data.bosses)]]:
		readout(record, entry[0], entry[1])
	section(record, "PROGRESSION")
	readout(record, "Technology Points", str(data.tp))
	readout(record, "Research nodes", "%d / %d" % [data.research.size(), game.catalog.technologies.size()])
	readout(record, "Ascensions", str(data.ascensions))
	readout(record, "Ascension Cores", str(data.cores))
	var achievements = scroll_column(content, 12)
	section(achievements, "ACHIEVEMENTS / %d EARNED" % data.achievements.size())
	if data.achievements.is_empty(): label(achievements, "No achievements yet. Complete an eligible deployment to begin your record.", 18, Color("92abb8"))
	for achievement in data.achievements: label(achievements, achievement, 20, Color("e3bb7d"))

func show_sandbox() -> void:
	if game.mode != "sandbox" or game.state not in ["preparation", "wave"] or game.reward_pending: return
	notice_time = 0
	overlay = "sandbox"
	wipe()
	var body = column(backdrop())
	var top = row(body)
	var title = label(top, "SANDBOX CONTROLS", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "Close [%s]" % key_name("pause"), close_overlay)
	label(body, "No TP, records, or permanent rewards. Simulation continues while these controls are open.", 18, Color("ebc891"))
	body = scroll_column(body, 16)
	var controls = row(body)
	label(controls, "Next wave", 18).custom_minimum_size.x = 140
	var number = SpinBox.new()
	number.custom_minimum_size.x = 160
	number.min_value = game.completed + 1
	number.max_value = 1000000
	number.value = game.wave + 1
	controls.add_child(number)
	button(controls, "Set wave", func():
		if game.state == "preparation": game.wave = int(number.value) - 1; notify("Next wave configured.")
		else: notify("Configure waves during Preparation."))
	button(controls, "Restore health / core / ammo", func():
		game.health = game.max_health
		game.core_health = game.max_core
		game.scrap = 999999
		for weapon in game.weapons: weapon.reserve = 9999
		notify("Sandbox resources restored."))
	label(body, "SPAWN AT NEAREST ACTIVE PORTAL", 17, Color("80d9c7"))
	var spawns = GridContainer.new()
	spawns.columns = 5
	spawns.add_theme_constant_override("h_separation", 12)
	spawns.add_theme_constant_override("v_separation", 12)
	body.add_child(spawns)
	for id in game.catalog.enemies:
		button(spawns, game.catalog.enemies[id].name, func():
			if game.state == "preparation":
				game.start_wave()
				game.spawn_queue.clear()
				game.spawn_reserve.clear()
			game.spawn_enemy(id)
			show_sandbox())
	label(body, "EQUIPMENT", 17, Color("80d9c7"))
	var equipment = GridContainer.new()
	equipment.columns = 5
	equipment.add_theme_constant_override("h_separation", 12)
	equipment.add_theme_constant_override("v_separation", 12)
	body.add_child(equipment)
	for id in game.catalog.weapons:
		button(equipment, game.catalog.weapons[id].name, func():
			if game.backpack.size() < game.capacity: game.backpack.append(game.make_weapon(id, 3)); notify("Equipment added to backpack.")
			else: notify("Backpack full."))
	var speed = row(body)
	label(speed, "Simulation speed", 18).custom_minimum_size.x = 180
	for value in [1, 2, 4]:
		button(speed, "×%d" % value, func(): Engine.time_scale = value)
	if not game.saved_editor.is_empty(): button(body, "Return to editor", func(): Engine.time_scale = 1; editor.return_from_playtest())

func show_settings() -> void:
	overlay = "settings"
	wipe()
	var body = column(backdrop())
	var top = row(body)
	var heading = label(top, "SETTINGS", 30)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "Save & back", func():
		game.profile.save()
		game.apply_settings()
		if game.state == "paused": show_pause()
		else: show_menu())
	var content = row(body, 36)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var navigation = column(content, 10)
	navigation.custom_minimum_size.x = 220
	for category in ["Gameplay", "Display", "Audio", "Controls"]:
		button(navigation, category, func(): settings_section = category; rebind_action = ""; show_settings(), settings_section == category)
	spacer(navigation)
	button(navigation, "Credits & licenses", show_credits)
	var settings_col = scroll_column(content, 18)
	section(settings_col, settings_section.to_upper())
	var settings = game.profile.data.settings
	for entry in [["fov", "Field of view", 60, 110, 1, "Display"], ["sensitivity", "Mouse sensitivity", 0.0005, 0.006, 0.0001, "Controls"], ["volume", "Effects volume", 0, 1, 0.05, "Audio"], ["music", "Music volume", 0, 1, 0.05, "Audio"], ["fps", "Frame limit", 30, 240, 10, "Display"], ["enemy_cap", "Active enemy cap", 25, 250, 25, "Gameplay"], ["hud_scale", "HUD scale", 0.75, 1.5, 0.05, "Display"]]:
		if entry[5] != settings_section: continue
		var line = row(settings_col)
		var name_label = label(line, entry[1], 18)
		name_label.custom_minimum_size.x = 260
		var spin = SpinBox.new()
		spin.min_value = entry[2]
		spin.max_value = entry[3]
		spin.step = entry[4]
		spin.value = settings[entry[0]]
		spin.value_changed.connect(func(value): settings[entry[0]] = value; game.apply_settings())
		line.add_child(spin)
	for entry in [["fullscreen", "Fullscreen", "Display"], ["vsync", "VSync", "Display"], ["crosshair", "Crosshair", "Display"], ["shake", "Camera recoil", "Gameplay"], ["adaptive", "Adaptive factions for new runs", "Gameplay"], ["weather", "Weather visuals", "Display"], ["camera_motion", "Head bob, landing feedback and weapon sway", "Gameplay"], ["movement_effects", "Speed lines, movement FOV and camera tilt", "Gameplay"], ["stamina", "Slide stamina", "Gameplay"]]:
		if entry[2] != settings_section: continue
		var check = CheckButton.new()
		check.text = entry[1]
		check.button_pressed = settings[entry[0]]
		check.toggled.connect(func(value): settings[entry[0]] = value; game.apply_settings())
		settings_col.add_child(check)
	if settings_section == "Gameplay":
		label(settings_col, "The active cap limits simulated actors; remaining enemies stay queued. Adaptive factions apply to new runs. Slide stamina is separate from the three dash/slam bars.", 16, Color("92abb8"))
	if settings_section == "Display":
		label(settings_col, "Lighting quality", 17)
		var quality = OptionButton.new()
		quality.add_item("Performance · no shadows")
		quality.add_item("Standard · dynamic shadows")
		quality.selected = int(settings.quality)
		quality.item_selected.connect(func(index): settings.quality = index; game.apply_settings())
		settings_col.add_child(quality)
		label(settings_col, "Scene rendering", 17)
		var display = OptionButton.new()
		for text in ["Standard rendering", "Retro · pixelated scene", "High contrast scene"]: display.add_item(text)
		display.selected = int(settings.visual_mode)
		display.item_selected.connect(func(index): settings.visual_mode = index; game.apply_settings())
		settings_col.add_child(display)
		if RenderingServer.get_current_rendering_method() == "forward_plus":
			var advanced = CheckButton.new()
			advanced.text = "Reflections, ambient occlusion and volumetric lighting"
			advanced.button_pressed = settings.advanced_lighting
			advanced.toggled.connect(func(value): settings.advanced_lighting = value; game.apply_settings())
			settings_col.add_child(advanced)
		label(settings_col, "Window resolution", 17)
		var resolutions = OptionButton.new()
		for resolution in ["1280 × 800", "1440 × 900", "1920 × 1080"]: resolutions.add_item(resolution)
		resolutions.selected = int(settings.resolution)
		resolutions.item_selected.connect(func(index): settings.resolution = index; game.apply_settings())
		settings_col.add_child(resolutions)
	if settings_section != "Controls": return
	label(settings_col, "Select an action, then press a key. Escape cancels.", 16, Color("92abb8"))
	var key_col = GridContainer.new()
	key_col.columns = 2
	key_col.add_theme_constant_override("h_separation", 12)
	key_col.add_theme_constant_override("v_separation", 8)
	settings_col.add_child(key_col)
	for action in ["forward", "back", "left", "right", "jump", "sprint", "crouch", "grapple", "punch", "reload", "interact", "ability", "restoration", "inventory", "planning", "next_wave", "weapon1", "weapon2", "heal", "grenade", "pause"]:
		var events = InputMap.action_get_events(action)
		var key = events[0].as_text_physical_keycode() if not events.is_empty() else "Unbound"
		var action_name = "Dash" if action == "sprint" else ("Crouch / slide / slam" if action == "crouch" else ("Punch / parry" if action == "punch" else action.replace("_", " ").capitalize()))
		var binding = button(key_col, action_name + " : " + key, func(): rebind_action = action; notify("Press a key for " + action_name + ". Escape cancels."))
		binding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		binding.alignment = HORIZONTAL_ALIGNMENT_LEFT
		binding.add_theme_font_size_override("font_size", 16)
	button(settings_col, "Reset bindings", func(): settings.keys.clear(); game.configure_input(); show_settings())

func show_credits() -> void:
	overlay = "credits"
	var body = page("CREDITS & LICENSES", "Third-party game assets are CC0. Open a source page below.", show_settings)
	label(body, "GAME ASSETS · CC0", 17, Color("7ed9cb"))
	var sources = row(body, 10)
	button(sources, "Kenney · Blaster Kit", func(): OS.shell_open("https://kenney.nl/assets/blaster-kit"))
	button(sources, "Rob Tuytel · Large Floor Tiles 02", func(): OS.shell_open("https://polyhaven.com/a/large_floor_tiles_02"))
	button(sources, "Poly Haven license", func(): OS.shell_open("https://polyhaven.com/license"))
	var content = RichTextLabel.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.selection_enabled = true
	content.text = "GRIDFALL\n\nTHIRD-PARTY GAME ASSETS\nKenney · Blaster Kit · CC0\nRob Tuytel · Large Floor Tiles 02 (Poly Haven) · CC0\n\nGODOT ENGINE\n\n" + Engine.get_license_text() + "\n\nTHIRD-PARTY COMPONENTS\n"
	for component in Engine.get_copyright_info():
		content.text += "\n" + component.name + "\n"
		for part in component.parts:
			content.text += "\n".join(part.copyright) + "\nLicense: " + part.license + "\n"
	for license_name in Engine.get_license_info():
		content.text += "\n\n" + license_name + "\n" + Engine.get_license_info()[license_name]
	body.add_child(content)

func _input(event: InputEvent) -> void:
	if rebind_action != "" and event is InputEventKey and event.pressed:
		if event.physical_keycode != KEY_ESCAPE:
			game.profile.data.settings.keys[rebind_action] = event.physical_keycode
			game.configure_input()
			notify("Binding updated.")
		rebind_action = ""
		get_viewport().set_input_as_handled()
		show_settings()

func _process(delta: float) -> void:
	hit_flash = maxf(0, hit_flash - delta)
	hurt_flash = maxf(0, hurt_flash - delta)
	notice_time -= delta
	notice.visible = notice_time > 0
	hud.visible = game.playing() and overlay == ""
	hud.queue_redraw()
	hud_refresh = maxf(0, hud_refresh - delta)
	if game.playing() and overlay == "" and hud_refresh <= 0:
		hud_refresh = 0.1
		boss_label.visible = false
		hud.boss_ratio = -1
		for enemy in game.enemies.values():
			if enemy.type == "boss":
				boss_label.visible = true
				boss_label.text = "SIEGE TITAN · %d / %d · PHASE %d" % [enemy.health, enemy.max_health, 3 if enemy.health < enemy.max_health * 0.25 else (2 if enemy.health < enemy.max_health * 0.5 else 1)]
				hud.boss_ratio = enemy.health / enemy.max_health
				break
		var phase = "PREPARATION" if game.state == "preparation" else game.state.to_upper()
		hud_top.text = "WAVE %02d / %s\nCORE %d / %d   ·   %d SCRAP\nHOSTILES %d + %d INBOUND" % [game.wave, phase, game.core_health, game.max_core, game.scrap, game.enemies.size(), game.queued_enemies()]
		if game.core_shield > 0: hud_top.text += " · CORE SHIELD %d" % game.core_shield
		hud_left.text = "HEALTH  %d / %d\nSHIELD  %d\nPULSE  %s" % [game.health, game.max_health, game.shield, "READY [%s]" % key_name("ability") if game.ability_timer <= 0 else "%.1fs" % game.ability_timer]
		if game.perk("pulse_matrix") > 0: hud_left.text += "\nRESTORE %s" % ("READY [%s]" % key_name("restoration") if game.restoration_timer <= 0 else "%.1fs" % game.restoration_timer)
		if game.profile.data.settings.stamina: hud_left.text += "\nSTAMINA %d" % game.player.stamina
		if not game.weapons.is_empty():
			var weapon = game.weapons[game.active_weapon]
			var reload_status = " · RELOADING %.1fs" % game.reload_timer if game.reload_timer > 0 else ""
			hud_right.text = "%s\n%d / %d%s\nLV %d · XP %d / %d" % [game.item_name(weapon).to_upper(), weapon.ammo, weapon.reserve, reload_status, game.level, game.xp, game.next_xp]
		var action_hints = "[%s] BUILD  ·  [%s] START WAVE  ·  [%s] SUPPLY" % [key_name("planning"), key_name("next_wave"), key_name("interact")]
		if game.state == "wave":
			action_hints = "LMB FIRE / RMB AIM  ·  [%s] JUMP / WALL JUMP  ·  [%s] DASH  ·  [%s] SLIDE / SLAM  ·  [%s] GRAPPLE  ·  [%s] PARRY" % [key_name("jump"), key_name("sprint"), key_name("crouch"), key_name("grapple"), key_name("punch")]
		var supplies = "[%s] MEDKIT %d  ·  [%s] GRENADE %d  ·  [%s]/[%s] WEAPONS  ·  [%s] RELOAD  ·  [%s] INVENTORY  ·  [%s] PAUSE" % [key_name("heal"), game.consumables.medkit, key_name("grenade"), game.consumables.grenade, key_name("weapon1"), key_name("weapon2"), key_name("reload"), key_name("inventory"), key_name("pause")]
		if not game.drops.is_empty() and is_instance_valid(game.player):
			var nearest_distance = 3.5 * 3.5
			var nearest_name = ""
			for drop in game.drops:
				var distance = drop.pos.distance_squared_to(game.player.position)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_name = game.item_name(drop.item).to_upper()
			if nearest_name != "": action_hints = "[%s] PICK UP %s" % [key_name("interact"), nearest_name]
		hints.text = action_hints + "\n" + supplies
	if overlay == "planning" and is_instance_valid(grid) and is_instance_valid(planning_preview):
		if not game.world.inside(grid.hover):
			planning_preview.text = "Choose a permitted tile · %s · %d scrap · %d°" % [game.catalog.structures[build_id].name, game.build_cost(game.catalog.structures[build_id]), build_rotation]
			planning_preview.modulate = Color("e8c58c")
		else:
			var key = game.world.cell_key(grid.hover)
			if key == selected_key and game.world.construction.has(key) and planning_action != "move":
				var item = game.world.construction[key]
				planning_preview.text = "%s · %s · Level %d · HP %d / %d" % [str(grid.hover), item.name, item.level, item.health, item.max_health]
				planning_preview.modulate = Color("d5e2e8")
			else:
				var reason = game.placement(grid.hover)
				planning_preview.text = "%s · %s · %d scrap · %d°%s" % [str(grid.hover), game.catalog.structures[build_id].name, game.build_cost(game.catalog.structures[build_id]), build_rotation, " · " + reason if reason != "" else " · Placement permitted"]
				planning_preview.modulate = Color("eda18b") if reason != "" else Color("7ed9cb")
	debug_label.visible = debug_visible
	if debug_visible:
		var fps = Engine.get_frames_per_second()
		var tower_count = 0
		for item in game.world.construction.values():
			if item.kind == "tower": tower_count += 1
		var memory = OS.get_static_memory_usage()
		var rendering = game.render_times()
		debug_label.text = "%d FPS / %.2f ms avg frame / %.2f ms sim\nEnemies %d/%d · Projectiles %d\nTowers %d · Structures %d · Queue %d\nNavigation %.3f ms · Memory %s\nDraw calls %d" % [fps, 1000.0 / maxf(1, fps), game.simulation_ms, game.enemies.size(), game.active_cap, game.projectiles.size(), tower_count, game.world.construction.size(), game.queued_enemies(), game.world.nav_ms, "%.1f MB" % (memory / 1048576.0) if memory > 0 else "unavailable", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]
		debug_label.text += "\nRender CPU %.2f ms · GPU %s" % [rendering.cpu_ms, "%.2f ms" % rendering.gpu_ms if rendering.gpu_ms > 0 else "unavailable"]
