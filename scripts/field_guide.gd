extends RefCounted

const CATEGORIES = ["Weapons", "Enemies", "Defenses", "Attachments", "Weapon modifiers", "Equipment", "Special upgrades", "Research", "Worlds", "Tiles", "Field manual"]
const ENEMY_TACTICS = {
	"grunt": "A frontline attacker. Use cover and thin the pack before it reaches the core.",
	"runner": "Fast and fragile. Slow fields and close-range weapons stop flanking packs.",
	"tank": "Heavy armor and high health. Concentrate fire and use penetration rather than scattering damage.",
	"spitter": "A ranged projectile attacker. Break sight lines, dash through danger, or punch to reflect a frontal shot.",
	"breaker": "Hunts visible defenses within 12 m, retaining its target out to 14 m. At most two hunters commit to one defense; the rest follow the core road. An amber beam warns of its first strike. Repair coverage and focused fire counter it.",
	"saboteur": "Hunts attack towers within 10 m and retains its target out to 12 m. Shares the two-hunter assignment limit with Breakers. Fragile, with slower strikes; intercept it before it reaches a tower.",
	"lancer": "Road-bound ranged attacker. An amber targeting line warns before a slow precision bolt; cover and frontal parries counter it. Starts at wave 8.",
	"bombardier": "Road-bound siege attacker. After a 0.9 s first-strike warmup it lobs a slow, parryable shell that bursts across a 3 m radius. Parry the shell before it lands. Its 3.6 s attack interval is affected by wave scaling. Starts at wave 10.",
	"regenerator": "Road-bound bruiser. After four seconds without damage it recovers 4% of maximum health per second. Focus fire or keep a burn on it to interrupt recovery. Starts at wave 9.",
	"shielded": "Its frontal shield reduces incoming damage. Flank it or use explosives.",
	"support": "Heals nearby allies. Prioritize the mender before attacking a dense pack.",
	"exploder": "Detonates at close range. Kill it from a distance and avoid grouping around it.",
	"boss": "A three-phase siege enemy. Gains aggression and ranged pressure as health falls; keep moving and protect the core."
}
const WEAPON_TACTICS = {
	"pistol": "Efficient precision sidearm. Aim for heads and keep it as a reliable reserve weapon.",
	"smg": "High firing speed for close pressure; control spread and watch ammunition.",
	"rifle": "Versatile midrange fire. A stable platform for attachment builds.",
	"shotgun": "Seven pellets reward close positioning. Deals 25% extra damage against slowed targets.",
	"sniper": "Penetrates up to three enemies. Line up a corridor before firing.",
	"lmg": "Sustained defensive fire. Large reserves offset a longer reload.",
	"rocket": "Projectile splash punishes crowds. Lead moving targets and respect cover.",
	"plasma": "Travelling energy shots. Combine elemental effects with crowd control.",
	"arc": "Accurate energy carbine. Each hit arcs to up to two visible enemies within 5 m for half the primary hit's damage. Arcs cannot recursively chain. Plasma Caster research unlocks it.",
	"frost_launcher": "Explosive cryogenic rounds slow blast victims by 35% for 2.5 seconds. Use it to set up a shotgun or hold a road choke. Cryo Emitter research unlocks it.",
	"blade": "Ammunition-free close combat. Grapple into position, strike, then dash away. Accepts an elemental module."
}
var ui
var game
var category = "Weapons"
var selected_id = ""
var query = ""
var listing: ItemList
var detail: VBoxContainer
var shown: Array = []
var achievement_filter = 0

func back() -> void:
	if game.state == "paused": ui.show_pause()
	else: ui.show_menu()

func entries() -> Array:
	var result: Array = []
	var source: Variant = {}
	match category:
		"Weapons": source = game.catalog.weapons
		"Enemies": source = game.catalog.enemies
		"Defenses": source = game.catalog.structures
		"Attachments": source = game.catalog.get("attachments", {})
		"Weapon modifiers": source = game.catalog.loot.weapon_modifiers
		"Equipment":
			source = game.catalog.get("equipment", {}).duplicate(true)
			source.medkit = {"name": "Medkit", "description": "Restore player health. Use the Heal binding; medkits are consumed only when healing is needed."}
			source.grenade = {"name": "Grenade", "description": "Throw an arcing explosive with the Grenade binding. Finite charges; buy more from field supplies."}
		"Special upgrades": source = game.catalog.upgrades
		"Research": source = game.catalog.technologies
		"Worlds":
			for i in game.world.LEVEL_NAMES.size():
				var map = game.world.preset(i)
				result.append({"id": str(i), "name": map.name, "description": map.description, "width": map.width, "height": map.height})
			return result
		"Tiles":
			for kind in game.world.TERRAIN + game.world.WALLS + game.world.MARKERS + game.world.HAZARDS + ["ceiling", "elevation", "vegetation", "crate", "debris", "pipe", "machinery", "light"]:
				result.append({"id": kind, "name": str(kind).replace("_", " ").capitalize()})
			return result
		"Field manual":
			return [
				{"id": "movement", "name": "Movement & survival", "description": "Run, jump, dash and slide to preserve momentum. Hold Grapple to pull toward a surface or enemy within 48 m. Release to coast; jumping, dashing or slamming cancels the hook. A ground slam consumes one of the three dash/stamina bars. Falling below the world recovers you at deployment, even during combat. Enemy damage can still end the run."},
				{"id": "combat", "name": "Parries & close combat", "description": "Punch opens a 0.16-second frontal parry window with a 0.55-second cooldown. Reflect one projectile at double damage, or retaliate against a melee strike. A successful parry restores 5 health and 0.35 dash energy. A visible weapon or ability kill within 5 m restores 3 health plus 2% of maximum health."},
				{"id": "planning", "name": "Construction & supplies", "description": "Build during preparation on permitted ground. Use the planning grid to inspect, repair, specialize, move, replace or sell defenses. Aim at damaged construction within 4 m and press Interact for a field repair: up to 20% integrity, paid in scrap, with a 2.5-second shared cooldown. Field repairs work in combat; no-repair challenges disable them. Planning repairs cost less. Marked tower pads accept attack towers; structure pads accept other construction. Fixed terrain belongs to the world. Supplies and chests are used during preparation."},
				{"id": "levels", "name": "Experience & upgrade drafts", "description": "Kills grant XP based on enemy threat cost. At each wave clear, earned levels are converted into upgrade choices. Each of the first 30 earned levels adds 6 maximum health. Levels add 6% weapon damage, capped at +150%, and delayed recovery up to 2 HP/s. Every cleared wave grants at least one draft; multiple earned levels grant multiple choices. Unresolved choices survive checkpoints. XP, level and run upgrades reset on a new deployment."},
				{"id": "progression", "name": "Permanent progression", "description": "Eligible defeats award Technology Points and record achievements. Research unlocks equipment and permanent bonuses for future deployments. Ascension needs wave 25 and 20 technologies, resets ordinary research, and awards cores for permanent Ascension perks. Sandbox grants no TP or achievements."},
				{"id": "frontier", "name": "World evolution & Frontier", "description": "Authored routes and portals change after waves 4, 8 and 12. Expanding Frontier adds eight tiles east and south every four cleared waves, relocating outer approaches while preserving your defenses. Territory stops growing at 96 by 96; waves remain endless."},
				{"id": "equipment", "name": "Loot & equipment", "description": "Weapons can carry rarity bonuses, compatible special modifiers and one attachment per slot. Inventory shows resolved weapon stats. Attachment rarity strengthens beneficial values while keeping drawbacks, and survives replacing or detaching modules. Detaching a magazine returns excess loaded ammunition to reserve. Armor and shield packs apply to the current run. Drop or scrap unused gear to free backpack space."},
				{"id": "saves", "name": "Saving & audio", "description": "Eligible runs save at wave boundaries and when closed during active play. Combat saves resume paused. Settings are separate from run progress. Audio starts at 70% on new profiles; audio changes save immediately. All game audio is muted in the background, then restores your chosen preference when focused."}
			]
	if source is Array:
		for value in source: result.append(value.duplicate(true))
	else:
		for id in source:
			var value: Dictionary = source[id].duplicate(true)
			value.id = id
			result.append(value)
	return result

func show_wiki() -> void:
	ui.overlay = "wiki"
	var body = ui.page("FIELD GUIDE", "Base catalog values. Research, attachments, rarity, wave scaling and run upgrades modify combat stats.", back)
	var controls = ui.row(body, 14)
	var picker = OptionButton.new()
	for name_value in CATEGORIES: picker.add_item(name_value)
	picker.select(CATEGORIES.find(category))
	picker.custom_minimum_size.x = 230
	picker.item_selected.connect(func(index): category = CATEGORIES[index]; selected_id = ""; refresh())
	controls.add_child(picker)
	var search = LineEdit.new()
	search.placeholder_text = "Search this category"
	search.text = query
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(value): query = value; refresh())
	controls.add_child(search)
	var content = ui.row(body, 28)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing = ItemList.new()
	listing.custom_minimum_size.x = 300
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(func(index): selected_id = str(shown[index].id); show_entry(shown[index]))
	content.add_child(listing)
	detail = ui.scroll_column(content, 14)
	refresh()

func refresh() -> void:
	listing.clear()
	shown.clear()
	for entry in entries():
		if query != "" and not (str(entry.name) + " " + str(entry.get("description", "")) + " " + str(entry.id)).to_lower().contains(query.to_lower()): continue
		shown.append(entry)
		listing.add_item(entry.name)
	var index = -1
	for i in shown.size():
		if str(shown[i].id) == selected_id: index = i
	if index < 0 and not shown.is_empty(): index = 0
	if index >= 0:
		listing.select(index)
		selected_id = str(shown[index].id)
		show_entry(shown[index])
	else:
		ui.clear_children(detail)
		ui.label(detail, "No matching entries.", 22)

func stat(title: String, value: Variant) -> void:
	ui.readout(detail, title, str(value))

func show_entry(entry: Dictionary) -> void:
	ui.clear_children(detail)
	ui.section(detail, category.to_upper())
	ui.label(detail, entry.name, 30, Color("e3bb7d"))
	var description = str(entry.get("description", ""))
	if category == "Weapons": description = WEAPON_TACTICS.get(entry.id, description)
	if category == "Enemies": description = ENEMY_TACTICS.get(entry.id, description)
	if category == "Tiles": description = tile_detail(entry.id)
	if description != "": ui.label(detail, description, 18)
	if category in ["Weapons", "Enemies", "Defenses", "Attachments", "Equipment", "Tiles"]:
		catalog_preview(category, entry)
	match category:
		"Weapons":
			for pair in [["Damage per pellet", entry.damage], ["Pellets", entry.pellets], ["Shot interval", "%.2f s" % entry.interval], ["Magazine / starting reserve", "%d / %d" % [entry.magazine, entry.reserve]], ["Reload", "%.2f s" % entry.reload], ["Range", "%.1f m" % entry.range], ["Spread", "%.1f degrees" % entry.spread]]: stat(pair[0], pair[1])
			stat("Mechanism", str(entry.loot_mechanism).capitalize())
			if entry.splash > 0: stat("Splash radius", "%.1f m" % entry.splash)
			if entry.speed > 0: stat("Projectile speed", "%.1f m/s" % entry.speed)
		"Enemies":
			for pair in [["First available wave", entry.min_wave], ["Base health", entry.health], ["Base damage", entry.damage], ["Speed", "%.1f m/s" % entry.speed], ["Attack range", "%.1f m" % entry.range], ["Attack interval", "%.1f s" % entry.interval], ["Armor reduction", "%.0f%%" % (entry.armor * 100)], ["Threat cost / kill XP", entry.cost]]: stat(pair[0], pair[1])
			ui.label(detail, "Health, damage and speed scale with waves. Elite and faction modifiers can change these values.", 16, Color("92abb8"))
		"Defenses":
			for pair in [["Role", str(entry.kind).capitalize()], ["Scrap cost", entry.cost], ["Health", entry.health], ["Damage / production value", entry.damage], ["Interval", "%.1f s" % entry.interval], ["Range", "%.1f m" % entry.range]]: stat(pair[0], pair[1])
			if entry.splash > 0: stat("Splash radius", "%.1f m" % entry.splash)
			if entry.slow > 0: stat("Slow", "%.0f%%" % (entry.slow * 100))
			ui.label(detail, defense_detail(entry.id), 18)
		"Attachments":
			stat("Slot", entry.get("slot", entry.id))
			stat("Compatible mechanisms", ", ".join(entry.compatible_mechanisms))
			for rarity in 5:
				var values: Array[String] = []
				var definition = game.attachment_definition(entry.id, rarity)
				for key in definition.stats:
					var value = float(definition.stats[key])
					values.append("%s %s" % [str(key).replace("_mult", "").replace("_", " "), "%+.1f%%" % ((value - 1) * 100) if str(key).ends_with("_mult") else "%.1f" % value])
				stat(["Common", "Uncommon", "Rare", "Epic", "Legendary"][rarity], "; ".join(values))
			ui.label(detail, "One module per slot. Attach from Inventory; replacing returns the previous module. The Shock Blade accepts only elemental modules.", 16, Color("92abb8"))
		"Weapon modifiers": stat("Compatible mechanisms", ", ".join(entry.mechanisms))
		"Special upgrades":
			stat("Rarity", entry.get("rarity", "Common"))
			stat("Effect", str(entry.effect).replace("_", " ").capitalize())
			if entry.has("cap"): stat("Maximum bonus", entry.cap)
			if entry.has("requires_effects"): stat("Needs an active source of", " or ".join(entry.requires_effects))
			ui.label(detail, "Chosen during preparation; lasts for this deployment. Capped and ineligible choices are omitted from drafts.", 16, Color("92abb8"))
		"Research":
			stat("Branch", entry.get("branch", ""))
			stat("Base TP cost", entry.cost)
			stat("Maximum rank", entry.max_rank)
			var prerequisites: Array = []
			for id in entry.requires:
				for node in game.catalog.technologies:
					if node.id == id: prerequisites.append(node.name)
			stat("Requires", "None" if prerequisites.is_empty() else ", ".join(prerequisites))
			ui.label(detail, "Each successive rank costs base cost multiplied by its rank. Purchases affect future deployments.", 16, Color("92abb8"))
		"Worlds": stat("Dimensions", "%d × %d tiles" % [entry.width, entry.height])
	var tech = str(entry.get("tech", ""))
	if tech != "":
		for node in game.catalog.technologies:
			if node.id == tech: stat("Required research", node.name)

func catalog_preview(category_name: String, entry: Dictionary) -> void:
	var frame = SubViewportContainer.new()
	frame.custom_minimum_size.y = 180
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(frame)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(640, 180)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	frame.add_child(viewport)
	var model = game.visuals.catalog_model(category_name, entry)
	if model == null: return
	viewport.add_child(model)
	var light = DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, -0.6, 0)
	light.light_energy = 1.8
	viewport.add_child(light)
	var focus = Vector3(0, 1.1, 0)
	var offset = Vector3(2.8, 1.8, -4.0)
	if category_name in ["Weapons", "Attachments"]:
		focus.y = 0.25
		offset = Vector3(1.7, 0.8, -2.6)
	elif category_name == "Enemies":
		focus.y = 0.85
		offset = Vector3(1.8, 0.7, -2.7)
	elif category_name == "Equipment":
		focus.y = 0.35
		offset = Vector3(2.0, 1.0, -3.0)
	elif category_name == "Tiles":
		focus.y = 0.75
		offset = Vector3(3.0, 1.8, -4.2)
	var camera = Camera3D.new()
	var bounds = AABB()
	var has_bounds = false
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_bounds: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	if has_bounds:
		focus = bounds.get_center()
		offset = offset.normalized() * maxf(0.35, bounds.size.length() * 0.65 / tan(deg_to_rad(19.0)))
	camera.position = focus + offset
	camera.fov = 38
	viewport.add_child(camera)
	camera.look_at(focus)
	camera.current = true
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101d25")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b9d6e1")
	environment.environment.ambient_light_energy = 0.5
	viewport.add_child(environment)

func defense_detail(id: String) -> String:
	return {"wall": "Destructible cover; enemies can break through instead of losing their route.", "sentry": "General-purpose automatic fire.", "rocket": "Travelling rockets with explosive splash.", "tesla": "Chains to nearby enemies; a strong answer to packs.", "laser": "Damage rises while focusing on the same enemy, up to twice base damage.", "flame": "Short-range area damage and burning.", "rail": "Long-range fire pierces aligned secondary targets.", "mortar": "Arcing explosive shells punish packed approaches.", "cryo": "Area slowing sets up shotgun and chain synergies.", "interceptor": "Intercepts one visible hostile projectile per shot within 11 m and never damages enemies. Tower-rate upgrades and nearby support improve its firing cadence; interference can slow it. Barrier Field research unlocks it alongside the Shield Projector.", "support": "Nearby attack towers deal 20% more damage and fire with 15% shorter intervals.", "repair": "Repairs nearby damaged construction. Disabled by no-repair Challenge rules.", "generator": "Produces scrap at wave boundaries; production bonuses apply.", "ammo": "Replenishes ammunition during preparation.", "mine": "One-use explosive trap; does not block enemy passage.", "spikes": "Repeated close-range trap damage and slow.", "shield": "Reduces damage to the nearby core by 25%; multiple projectors do not stack."}.get(id, "Inspect and manage this defense in the planning grid.")

func tile_detail(id: String) -> String:
	if id in game.world.TERRAIN: return "Ground supports player and enemy physics. Missing ground is a real hole. Water has double navigation cost by default; ground movement cost can be edited from 1 to 8. Terrain does not grant construction permission automatically."
	if id in game.world.WALLS:
		var definition: Dictionary = game.world.WALL_DEFS[id]
		return "Physical structure / base health %d / height %.1f m / damage resistance %.0f%%. %s" % [definition.health, definition.height, definition.resistance * 100, "Indestructible." if definition.health == 0 else "Can be damaged and destroyed."] + (" Sloped collision supports walking up to raised surfaces." if id in ["ramp", "stairs"] else "")
	if id in game.world.HAZARDS: return "Affects nearby actors during combat. Fire, acid, spikes and electricity deal periodic damage. Slow fields hinder enemies; mines detonate once. Hazard markers are low ground effects rather than solid walls."
	if id in ["crate", "machinery", "pipe"]: return "Solid environmental prop with matching collision. Blocks enemy routing and construction in its tile. Use it as cover or a grapple target; leave nearby routes open."
	if id in ["vegetation", "debris", "light"]: return "Cosmetic dressing; does not block movement. Use the lighting layer for an actual light source."
	if id in ["ceiling", "elevation"]: return "An elevated physical slab. Configure elevation in tile properties; combine with stairs or ramps for access."
	return {"player": "The unique deployment and fall-recovery point. Keep its route to the objective clear.", "objective": "The unique core. Its destruction ends the deployment.", "enemy": "Enemy portal. Optional unlock wave delays activation until that wave has been cleared.", "pad": "A marked construction site; its tile must also have building permission.", "tower_pad": "Accepts attack towers only.", "structure_pad": "Reserved for walls, machines and other non-tower defenses.", "generator": "Produces 25 scrap per cleared wave, increased by production bonuses.", "chest": "A supply cache. Interact during preparation; each cache opens once per run.", "supply": "Opens field supplies during preparation.", "shop": "Purchase equipment and refills during preparation.", "ammo": "A resupply station accessible during preparation.", "upgrade": "An equipment station accessible during preparation."}.get(id, "A world marker; configure it in the map editor.")

func show_achievements() -> void:
	ui.overlay = "achievements"
	var definitions: Dictionary = game.Profile.ACHIEVEMENTS
	var earned = 0
	for name_value in definitions:
		if game.profile.data.achievements.get(name_value, false): earned += 1
	var body = ui.page("ACHIEVEMENTS / %d OF %d" % [earned, definitions.size()], "Requirements are for one eligible deployment. Best completed-run progress is saved; sandbox does not count.", back)
	var tabs = ui.row(body, 10)
	for i in 3:
		var tab = ui.button(tabs, ["All", "Earned", "Locked"][i], func(): achievement_filter = i; show_achievements())
		tab.disabled = i == achievement_filter
	var list = ui.scroll_column(body, 18)
	var count = 0
	for name_value in definitions:
		var unlocked = bool(game.profile.data.achievements.get(name_value, false))
		if achievement_filter == 1 and not unlocked or achievement_filter == 2 and unlocked: continue
		count += 1
		var definition: Dictionary = definitions[name_value]
		var line = ui.row(list, 24)
		var info = ui.column(line, 4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui.label(info, name_value, 22, Color("e3bb7d") if unlocked else Color("d5e2e8"))
		ui.label(info, definition.detail, 16, Color("92abb8"))
		var progress = float(game.profile.data.get("achievement_progress", {}).get(name_value, 0))
		if name_value == "Ascendant": progress = game.profile.data.ascensions
		if game.playing() and game.eligible:
			var current: Dictionary = game.stats.duplicate()
			current.cleared = maxi(0, game.completed - (19 if game.mode == "siege" else 0))
			current.duration = game.elapsed
			progress = maxf(progress, game.profile.achievement_value(name_value, current))
		if unlocked: progress = definition.target
		var meter = ui.column(line, 4)
		meter.custom_minimum_size.x = 220
		ui.label(meter, "EARNED" if unlocked else "%.0f / %.0f" % [progress, definition.target], 16, Color("7ed9cb") if unlocked else Color("92abb8"))
		var bar = ProgressBar.new()
		bar.max_value = definition.target
		bar.value = minf(progress, definition.target)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(220, 6)
		meter.add_child(bar)
	if count == 0: ui.label(list, "No achievements in this filter yet.", 20, Color("92abb8"))
