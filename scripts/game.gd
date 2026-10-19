extends Node3D

const World = preload("res://scripts/world.gd")
const Profile = preload("res://scripts/profile.gd")
const Visuals = preload("res://scripts/visuals.gd")
const Player = preload("res://scripts/player.gd")
const Interface = preload("res://scripts/interface.gd")
const Sound = preload("res://scripts/audio.gd")
const Rules = preload("res://scripts/run_rules.gd")
const CombatSave = preload("res://scripts/combat_save.gd")
const Campaign = preload("res://scripts/campaign.gd")
const EnemyBrain = preload("res://scripts/enemy_brain.gd")
var campaign = Campaign.new()
const EnemyIndex = preload("res://scripts/enemy_index.gd")
var enemy_index = EnemyIndex.new()
var wounded_index = EnemyIndex.new()
var hunter_targets: Dictionary = {}
var field_repair_ready_at = 0.0
var enemy_cursor = 0
var enemy_batch = 512
var spectator = false
const TARGET_MODES = ["Nearest", "Strongest", "Weakest", "First", "Last", "Lowest health", "Highest threat"]
var catalog: Dictionary
var profile = Profile.new()
var world = World.new()
var visuals
var audio
var ui
var player
var rng = RandomNumberGenerator.new()
var state = "menu"
var previous_state = "preparation"
var mode = "endless"
var selected_map = 0
var seed_value = 104729
var eligible = true
var run_id = ""
var wave = 0
var completed = 0
var scrap = 0
var health = 100.0
var max_health = 100.0
var shield = 0.0
var core_health = 600.0
var run_research: Dictionary = {}
var max_core = 600.0
var core_shield = 0.0
var restoration_timer = 0.0
var faction_name = "None"
var adaptive_run = true
var run_perks: Dictionary = {}
var challenge_rules = {"frail": true, "fast": true, "no_repair": true, "scarce_ammo": false, "pads_only": false, "ballistics_only": false, "acid_rain": false}
var active_challenges: Dictionary = {}
var stats: Dictionary = {}
var bonuses: Dictionary = {}
var weapons: Array = []
var backpack: Array = []
var consumables = {"medkit": 2, "grenade": 2}
var active_weapon = 0
var capacity = 20
var fire_timer = 0.0
var reload_timer = 0.0
var ability_timer = 0.0
var hurt_timer = 0.0
var elapsed = 0.0
var spawn_timer = 0.0
var spawn_queue: Array = []
var spawn_reserve: Dictionary = {}
var enemies: Dictionary = {}
var projectiles: Array = []
var drops: Array = []
var next_uid = 0
var event_name = ""
var upgrades: Array = []
var upgrade_picks = 0
var xp = 0
var level = 1
var next_xp = 30
var pending_levels = 0
var reward_pending = false
var contract_choice = ""
var wave_contract: Dictionary = {}
var supply_cache: Array = []
const CONTRACTS = {
	"operator": {"name": "Operator", "stat": "weapon_damage", "base": 70, "scale": 40, "cap": 4000},
	"engineer": {"name": "Engineer", "stat": "tower_damage", "base": 150, "scale": 50, "cap": 5000},
	"guardian": {"name": "Guardian", "stat": "core_damage_taken", "base": 0, "scale": 0, "cap": 0}
}
var last_reward = 0
var defeat_reason = ""
var kill_streak = 0
var kill_timer = 0.0
var simulation_ms = 0.0
var simulation_phases: Dictionary = {}
var hazard_timer = 0.0
var benchmark_population = 1000
var autoplay = false
var benchmark_time = 0.0
var benchmark_stage = 0
var benchmark_stats: Array = []
var benchmark_duration = 180.0
var benchmark_content = false
var benchmark_stress = false
var benchmark_horde = 0
var benchmark_frame_bins: Dictionary = {}
var benchmark_frames = 0
var benchmark_frame_seconds = 0.0
var benchmark_worst_frame = 0.0
var benchmark_slow_frames = 0
var benchmark_update_ms = 0.0
var benchmark_aim_cursor = 0
var benchmark_weapon = ""
var benchmark_enemy_pool: Array = []
var peak_simulation_ms = 0.0
var pending_map: Dictionary = {}
var saved_editor: Dictionary = {}
var resume_available = false
var quitting = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	var content = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	if not content is Dictionary or not content.get("weapons") is Dictionary or not content.get("enemies") is Dictionary or not content.get("structures") is Dictionary or not content.get("technologies") is Array or not content.get("upgrades") is Array or not content.get("structure_upgrades") is Dictionary:
		var layer = CanvasLayer.new()
		add_child(layer)
		var message = Label.new()
		message.text = "GRIDFALL could not load its content catalog.\nRestore data/catalog.json, then restart the game."
		message.position = Vector2(40, 40)
		message.add_theme_font_size_override("font_size", 24)
		layer.add_child(message)
		return
	catalog = content
	profile.load_profile()
	rng.randomize()
	configure_input()
	visuals = Visuals.new()
	add_child(visuals)
	visuals.setup(self)
	audio = Sound.new()
	add_child(audio)
	audio.setup(self)
	ui = Interface.new()
	add_child(ui)
	ui.setup(self)
	add_child(campaign)
	campaign.setup(self)
	apply_settings()
	resume_available = read_run_checkpoint() != null
	world.load_map(world.preset())
	visuals.rebuild()
	menu_camera()
	ui.show_menu()
	if not profile.error.is_empty():
		ui.notify(profile.error)
	benchmark_content = "--benchmark-content" in OS.get_cmdline_user_args()
	benchmark_stress = "--benchmark-stress" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--benchmark-horde="):
			benchmark_horde = clampi(int(argument.trim_prefix("--benchmark-horde=")), 1, 1000000000000)
			benchmark_stress = true
		if argument.begins_with("--benchmark-duration="):
			benchmark_duration = clampf(float(argument.trim_prefix("--benchmark-duration=")), 10, 3600)
		if argument.begins_with("--benchmark-population="):
			benchmark_population = maxi(1, int(argument.trim_prefix("--benchmark-population=")))
			benchmark_stress = true
	if "--benchmark" in OS.get_cmdline_user_args() or benchmark_content or benchmark_stress:
		autoplay = true
		start_run("sandbox")
		benchmark_setup()
	for argument in OS.get_cmdline_user_args():
		if OS.has_feature("editor") and argument.begins_with("--play="):
			start_run(argument.trim_prefix("--play="))
		if argument.begins_with("--capture="):
			capture_screen(argument.trim_prefix("--capture="))
		if OS.has_feature("editor") and argument.begins_with("--command-base64="):
			execute_developer_command(Marshalls.base64_to_utf8(argument.trim_prefix("--command-base64=")))

func configure_input() -> void:
	var keys = {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "crouch": KEY_CTRL, "reload": KEY_R, "interact": KEY_E, "ability": KEY_Q, "inventory": KEY_TAB, "planning": KEY_B, "pause": KEY_ESCAPE, "next_wave": KEY_ENTER, "weapon1": KEY_1, "weapon2": KEY_2, "heal": KEY_C, "grenade": KEY_G, "debug": KEY_F3}
	keys.restoration = KEY_X
	keys.grapple = KEY_F
	keys.punch = KEY_V
	keys.unstuck = KEY_U
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event = InputEventKey.new()
		event.physical_keycode = int(profile.data.settings.keys.get(action, keys[action]))
		InputMap.action_add_event(action, event)
	for pair in [["shoot", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		InputMap.action_erase_events(pair[0])
		var event = InputEventMouseButton.new()
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0], event)

func apply_settings() -> void:
	var settings = profile.data.settings
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not settings.fullscreen and not "--resolution" in OS.get_cmdline_args():
		DisplayServer.window_set_size([Vector2i(1280, 800), Vector2i(1440, 900), Vector2i(1920, 1080)][int(settings.resolution)])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(settings.fps)
	visuals.sun.shadow_enabled = int(settings.quality) > 0
	visuals.apply_render_settings()
	audio.apply_volume()
	if is_instance_valid(ui):
		for item in [ui.hud_top, ui.hud_left, ui.hud_right]:
			item.add_theme_font_size_override("font_size", int(22 * float(settings.hud_scale)))

func menu_camera() -> void:
	var camera = get_node_or_null("MenuCamera")
	if camera == null:
		camera = Camera3D.new()
		camera.name = "MenuCamera"
		add_child(camera)
	camera.position = Vector3(52, 40, 60)
	camera.look_at(Vector3(36, 0, 33))
	camera.current = true

func playing() -> bool:
	return state in ["preparation", "wave", "completion", "paused"]

func unlocked(definition: Dictionary) -> bool:
	if challenge("ballistics_only") and definition.has("magazine") and (definition.speed > 0 or definition.magazine == 0): return false
	var research = run_research if playing() else profile.data.research
	return definition.get("tech", "") == "" or int(research.get(definition.get("tech", ""), 0)) > 0 or mode == "sandbox"

func bonus(key: String) -> float:
	return clampf(float(bonuses.get(key, 0)), 0, float(Rules.CAPS.get(key, 1e12)))

func repairs_allowed() -> bool:
	return not challenge("no_repair")

func challenge(id: String) -> bool:
	return mode == "challenge" and bool(active_challenges.get(id, false))

func scarce_ammo() -> bool:
	return mode == "scavenger" or challenge("scarce_ammo")

func placement(point: Vector2i, id: String = "") -> String:
	if mode == "campaign" and playing(): return "Campaign chambers do not allow construction."
	if spectator: return "Spectator mode has no construction."
	var reason = world.placement(point, id if id != "" else (ui.build_id if is_instance_valid(ui) else ""))
	if reason != "": return reason
	if challenge("pads_only") and world.map.layers.markers.get(world.cell_key(point), {}).get("type", "") not in ["pad", "tower_pad", "structure_pad"]: return "Challenge construction is limited to marked pads."
	return ""

func perk(id: String) -> int:
	return int(run_perks.get(id, 0))

func structure_position(key: String) -> Vector3:
	var item: Dictionary = world.construction.get(key, {})
	return world.position(world.point(key), world.mount_height(world.point(key), item.get("id", "")))

func start_debug_world() -> void:
	start_run("sandbox", world.debug_gallery())
	if not playing(): return
	spectator = true
	eligible = false
	player.collision_layer = 0
	player.collision_mask = 0
	player.position = world.position(Vector2i(15, 20), 12)
	player.gun.visible = false
	player.fist.visible = false
	ui.close_overlay()
	ui.notify("Tile gallery · Spectator · WASD fly · Space up · Ctrl down · Shift faster · Esc exit")

func start_campaign_stage(index: int = 0) -> void:
	var progress: Dictionary = profile.data.campaign
	if index < 0 or index >= campaign.stage_count() or index >= int(progress.unlocked):
		ui.notify("Complete the previous chamber to unlock this stage.")
		return
	if eligible and playing() and not save_run(): return
	state = "menu"
	start_run("campaign", campaign.stage_map(index))

func ascend() -> String:
	if state != "menu" or read_run_checkpoint() != null: return "Finish or abandon your saved run before ascending."
	return profile.ascend(catalog.technologies)

func respec() -> String:
	if state != "menu" or read_run_checkpoint() != null: return "Finish or abandon your saved run before resetting research."
	return profile.respec(catalog.technologies)

func start_run(run_mode: String = "endless", custom: Dictionary = {}, restoring: bool = false) -> void:
	if playing():
		return
	if run_mode == "campaign" and custom.is_empty():
		start_campaign_stage(int(profile.data.campaign.stage))
		return
	if not Rules.MODES.has(run_mode):
		ui.notify("Unknown game mode.")
		return
	if not custom.is_empty() and run_mode not in ["sandbox", "campaign"]:
		ui.notify("Custom worlds can only be played in Sandbox.")
		return
	if run_mode == "siege" and profile.data.best < 20 and not restoring:
		ui.notify("Reach wave 20 to unlock Siege Protocol.")
		return
	mode = run_mode
	active_challenges = challenge_rules.duplicate() if mode == "challenge" else {}
	eligible = run_mode not in ["sandbox", "campaign"] and custom.is_empty()
	if mode == "daily": seed_value = Rules.daily_seed()
	var world_index = absi(seed_value) % World.LEVEL_NAMES.size() if mode in ["seeded", "daily"] else selected_map
	var value = custom if not custom.is_empty() else world.preset(world_index, seed_value)
	var issues = world.validate(value, mode != "campaign")
	if not issues.is_empty():
		ui.notify("Map rejected: " + "; ".join(issues))
		return
	clear_run()
	Engine.time_scale = 1.0
	reset_atmosphere()
	world.load_map(value)
	run_research = profile.data.research.duplicate()
	if challenge("pads_only"):
		for point in Rules.CHALLENGE_PADS:
			if world.placement(point) == "": world.map.layers.markers[world.cell_key(point)] = {"type": "pad"}
	rng.seed = int(value.seed)
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	bonuses.clear()
	upgrades.clear()
	for node in catalog.technologies:
		if node.effect not in ["weapon", "structure"]:
			bonuses[node.effect] = bonus(node.effect) + float(node.value) * profile.rank(node.id)
	var mutation_rank = profile.perk("mutation")
	if mutation_rank > 0:
		var mutation_effect = {"vitality": "health", "overclock": "fire_rate", "salvage": "scrap"}[profile.data.mutation]
		bonuses[mutation_effect] = bonus(mutation_effect) + mutation_rank * {"health": 20, "fire_rate": 0.08, "scrap": 60}[mutation_effect]
	adaptive_run = profile.data.settings.adaptive
	run_perks = profile.data.ascension_perks.duplicate()
	faction_name = "None"
	wave = 0
	completed = 0
	elapsed = 0
	scrap = int(300 + bonus("scrap")) if mode != "sandbox" else 999999
	max_health = 100 + bonus("health")
	if challenge("frail"):
		max_health *= 0.65
	health = max_health
	max_core = world.rule("objective_health") + bonus("core_health")
	core_health = max_core
	core_shield = bonus("core_shield")
	restoration_timer = 0
	shield = bonus("shield")
	capacity = 20 + int(bonus("capacity"))
	consumables = {"medkit": 2, "grenade": 2}
	weapons = [make_weapon("rifle"), make_weapon("pistol")]
	var loadout = str(profile.data.loadout)
	if catalog.weapons.has(loadout) and unlocked(catalog.weapons[loadout]):
		weapons[0] = make_weapon(loadout)
	var secondary = str(profile.data.secondary_loadout)
	if profile.perk("dual_loadout") > 0 and catalog.weapons.has(secondary) and unlocked(catalog.weapons[secondary]): weapons[1] = make_weapon(secondary)
	if scarce_ammo():
		for weapon in weapons: weapon.reserve = int(weapon.reserve / 2)
	if mode == "siege":
		wave = 19
		completed = 19
		scrap += 1200
		world.evolve(19)
	active_weapon = 0
	level = 1
	xp = 0
	next_xp = 30
	pending_levels = 0
	fire_timer = 0
	reload_timer = 0
	ability_timer = 0
	hurt_timer = 0
	hazard_timer = 0
	simulation_ms = 0
	kill_streak = 0
	kill_timer = 0
	reward_pending = false
	contract_choice = ""
	wave_contract.clear()
	supply_cache.clear()
	upgrade_picks = 0
	stats = {"wave": 1, "kills": 0, "bosses": 0, "damage": 0.0, "weapon_damage": 0.0, "tower_damage": 0.0, "ability_damage": 0.0, "built": 0, "earned": 0, "spent": 0, "streak": 0, "difficulty": 1.35 if mode == "challenge" else 1.0}
	stats.merge({"difficulty": Rules.MODES[mode].difficulty, "mode": mode, "explosive_damage": 0.0, "elemental_damage": 0.0, "close_damage": 0.0, "core_damage_taken": 0.0, "loot_collected": 0, "weapon_usage": {}}, true)
	if mode == "challenge":
		stats.difficulty = 1.0
		for id in active_challenges:
			if active_challenges[id]: stats.difficulty += Rules.CHALLENGES[id].weight
		stats.challenge_weight = stats.difficulty - 1
	if mode == "campaign":
		bonuses.clear()
		run_perks.clear()
		run_research.clear()
		max_health = 100
		health = 100
		shield = 0
		core_shield = 0
		scrap = 0
		consumables = {"medkit": 0, "grenade": 0}
		weapons = [{"id": "", "rarity": 0, "roll": 1.0, "ammo": 0, "reserve": 0, "attachments": {}, "mods": []}, {"id": "", "rarity": 0, "roll": 1.0, "ammo": 0, "reserve": 0, "attachments": {}, "mods": []}]
	visuals.rebuild()
	player = Player.new()
	add_child(player)
	player.setup(self)
	player.position = world.position(world.marker("player"), 0.1)
	state = "preparation"
	ui.close_overlay()
	ui.notify("Preparation — build defenses [%s], then begin wave [%s]." % [ui.key_name("planning"), ui.key_name("next_wave")])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if autoplay else Input.MOUSE_MODE_CAPTURED
	if mode == "campaign":
		state = "wave"
		campaign.start(int(value.get("campaign_stage", 0)))

func clear_run() -> void:
	if is_instance_valid(campaign): campaign.clear()
	hunter_targets.clear()
	field_repair_ready_at = 0.0
	spectator = false
	enemy_index.clear()
	wounded_index.clear()
	enemy_cursor = 0
	enemy_batch = 512
	if is_instance_valid(visuals) and is_instance_valid(visuals.enemy_renderer): visuals.enemy_renderer.clear()
	for enemy in enemies.values():
		if is_instance_valid(enemy.node):
			enemy.node.queue_free()
	enemies.clear()
	for projectile in projectiles:
		if is_instance_valid(projectile.mesh):
			visuals.release_bolt(projectile.mesh)
	projectiles.clear()
	for drop in drops:
		if is_instance_valid(drop.mesh):
			drop.mesh.queue_free()
	drops.clear()
	spawn_queue.clear()
	spawn_reserve.clear()
	backpack.clear()
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	player = null

func to_menu() -> void:
	Engine.time_scale = 1
	state = "menu"
	clear_run()
	saved_editor.clear()
	reset_atmosphere()
	world.load_map(world.preset(selected_map, seed_value))
	visuals.rebuild()
	menu_camera()
	ui.show_menu()

func reset_atmosphere() -> void:
	event_name = ""
	visuals.clear_weather()
	visuals.apply_render_settings()

func make_weapon(id: String, rarity: int = 0) -> Dictionary:
	var definition = catalog.weapons[id]
	var pool: Array = []
	var mechanism = str(definition.loot_mechanism)
	for modifier in catalog.loot.weapon_modifiers:
		if mechanism in modifier.mechanisms:
			pool.append(str(modifier.id))
	var modifiers: Array = []
	for i in mini(mini(rarity, 3), pool.size()):
		var index = rng.randi_range(0, pool.size() - 1)
		modifiers.append(pool[index])
		pool.remove_at(index)
	return {"id": id, "rarity": rarity, "roll": 1.0 + rarity * 0.12 + rng.randf_range(0, 0.08), "ammo": int(definition.magazine), "reserve": int(definition.reserve), "attachments": {}, "mods": modifiers}

func modules(item: Dictionary) -> Dictionary:
	if not item.has("attachments"):
		item.attachments = {}
		if item.get("attachment", "") != "": item.attachments[item.attachment] = item.attachment
		item.erase("attachment")
	return item.attachments

func magazine_size(item: Dictionary) -> int:
	if not catalog.weapons.has(item.id): return 0
	return int(ceil(catalog.weapons[item.id].magazine * float(weapon_traits(item).get("magazine_mult", 1.0))))

func combine_traits(definitions: Array) -> Dictionary:
	var result: Dictionary = {}
	for definition in definitions:
		for key in definition.get("stats", {}):
			var value = float(definition.stats[key])
			if str(key).ends_with("_mult"): result[key] = float(result.get(key, 1.0)) * value
			elif str(key).ends_with("_duration"): result[key] = maxf(float(result.get(key, 0.0)), value)
			else: result[key] = float(result.get(key, 0.0)) + value
	return result

func modifier_definitions(ids: Array) -> Array:
	var result: Array = []
	for definition in catalog.loot.weapon_modifiers:
		if definition.id in ids: result.append(definition)
	return result

func weapon_traits(item: Dictionary) -> Dictionary:
	var definitions = modifier_definitions(item.get("mods", []))
	if catalog.weapons.has(item.id): definitions.append({"stats": catalog.weapons[item.id].get("intrinsic_stats", {})})
	var equipped = modules(item)
	for slot in equipped:
		var id = str(equipped[slot])
		if catalog.get("attachments", {}).has(id): definitions.append(attachment_definition(id, int(item.get("attachment_rarities", {}).get(slot, 0))))
	return combine_traits(definitions)

func attachment_definition(id: String, rarity: int = 0) -> Dictionary:
	var definition: Dictionary = catalog.attachments[id].duplicate(true)
	var strength = 1.0 + clampi(rarity, 0, 4) * 0.25
	for key in definition.stats:
		var value = float(definition.stats[key])
		if str(key).ends_with("_mult"):
			var beneficial = (key in ["damage_mult", "magazine_mult"] and value > 1) or (key not in ["damage_mult", "magazine_mult"] and value < 1)
			if beneficial: definition.stats[key] = (1 + (value - 1) * strength) if value > 1 else pow(value, strength)
		elif not str(key).ends_with("_duration"): definition.stats[key] = value * strength
	return definition

func hit_traits(ids: Array, elemental: bool, elemental_rarity: int = 0) -> Dictionary:
	var definitions = modifier_definitions(ids)
	if elemental: definitions.append(attachment_definition("elemental", elemental_rarity))
	return combine_traits(definitions)

func attachment_compatible(id: String, item: Dictionary) -> bool:
	if not catalog.weapons.has(item.id) or not catalog.get("attachments", {}).has(id): return false
	return catalog.weapons[item.id].loot_mechanism in catalog.attachments[id].compatible_mechanisms

func weapon_stats(item: Dictionary) -> Dictionary:
	if not catalog.weapons.has(item.id): return {"damage": 0, "interval": 0, "magazine": 0, "reload": 0, "range": 0, "spread": 0}
	var definition = catalog.weapons[item.id]
	var traits = weapon_traits(item)
	return {
		"damage": definition.damage * item.roll * (1 + bonus("damage")) * (1 + minf(1.5, maxf(0, level - 1) * 0.06)) * float(traits.get("damage_mult", 1.0)),
		"interval": maxf(0.06, definition.interval / (1 + bonus("fire_rate")) * float(traits.get("interval_mult", 1.0))),
		"magazine": magazine_size(item),
		"reload": maxf(0.25, definition.reload / (1 + bonus("reload")) * float(traits.get("reload_mult", 1.0))) if definition.magazine > 0 else 0.0,
		"range": definition.range * (1 + bonus("range")),
		"spread": definition.spread * float(traits.get("spread_mult", 1.0)),
		"recoil_mult": float(traits.get("recoil_mult", 1.0))
	}

func weapon_def() -> Dictionary:
	if weapons[active_weapon].id == "": return {"name": "Unarmed", "damage": 0, "magazine": 0, "reserve": 0, "reload": 0, "range": 0}
	return catalog.weapons[weapons[active_weapon].id]

func switch_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or reload_timer > 0:
		return
	active_weapon = index
	if is_instance_valid(player):
		player.refresh_gun()

func reload_weapon() -> void:
	if not playing() or state == "paused" or reload_timer > 0:
		return
	var item = weapons[active_weapon]
	var definition = weapon_def()
	if item.ammo >= magazine_size(item) or item.reserve <= 0 or definition.magazine == 0:
		return
	reload_timer = weapon_stats(item).reload
	audio.cue("reload")

func ray(from: Vector3, to: Vector3, mask: int = 3, exclude: Array[RID] = [], through_barricades: bool = false) -> Dictionary:
	if mask & 1 and not through_barricades: mask |= 8
	var query = PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query)

func sight(from: Vector3, to: Vector3, exclude: Array[RID] = [], through_barricades: bool = false) -> bool:
	return ray(from, to, 1, exclude, through_barricades).is_empty()

func fire(direction: Vector3 = Vector3.ZERO) -> void:
	if state not in ["preparation", "wave"] or fire_timer > 0 or reload_timer > 0:
		return
	if weapons[active_weapon].id == "": return
	var definition = weapon_def()
	var item = weapons[active_weapon]
	var modifiers: Array = item.get("mods", [])
	var equipped = modules(item)
	var resolved = weapon_stats(item)
	var traits = weapon_traits(item)
	if definition.magazine > 0 and item.ammo <= 0:
		reload_weapon()
		return
	if definition.magazine > 0:
		item.ammo -= 1
	fire_timer = resolved.interval
	player.shot_feedback()
	var from: Vector3 = player.camera.global_position
	var aim = -player.camera.global_basis.z if direction == Vector3.ZERO else direction.normalized()
	var spread = deg_to_rad(float(resolved.spread)) * (0.3 if Input.is_action_pressed("aim") or autoplay else 1.0)
	var amount = float(resolved.damage)
	if rng.randf() < 0.05 + bonus("critical"):
		amount *= 1.75
	stats.weapon_usage[item.id] = int(stats.weapon_usage.get(item.id, 0)) + 1
	for i in int(definition.pellets) + int(bonus("projectiles")):
		var shot = (aim + player.camera.global_basis.x * rng.randf_range(-spread, spread) + player.camera.global_basis.y * rng.randf_range(-spread, spread)).normalized()
		if definition.speed > 0:
			launch(from + shot * 0.7, shot * float(definition.speed), amount, definition.splash + float(traits.get("splash_bonus", 0)), "weapon", Color(definition.color), float(resolved.range) / definition.speed)
		else:
			var end = from + shot * float(resolved.range)
			var cursor = from
			var ignored: Array[RID] = []
			for penetration in (3 if item.id == "sniper" else 1):
				var hit = ray(cursor, end, 3, ignored)
				if hit.is_empty(): break
				var is_enemy = hit.collider.has_meta("enemy")
				var uid = int(hit.collider.get_meta("enemy")) if is_enemy else -1
				ignored.append(hit.collider.get_rid())
				if not is_enemy: visuals.impact(hit.position, hit.normal, hit.collider)
				var hit_damage = amount * (1.5 if is_enemy and hit.position.y - hit.collider.global_position.y > 1.4 else 1.0)
				if item.id == "shotgun" and enemies.has(uid) and enemies[uid].slow > 0: hit_damage *= 1.25
				hit_body(hit.collider, hit_damage, "weapon", from, {"traits": traits, "mods": modifiers, "origin": from})
				visuals.burst(hit.position, Color(definition.color), 3, 0.3)
				if traits.get("proc_damage_ratio", 0) > 0 and is_enemy: explosion(hit.position, amount * float(traits.proc_damage_ratio), float(traits.get("proc_radius", 2.5)), "weapon")
				if not is_enemy and rng.randf() < minf(1.0, bonus("ricochet") + float(traits.get("bounce_chance", 0))):
					var reflected = shot.bounce(hit.normal)
					var bounce_from = hit.position + hit.normal * 0.06
					var bounce_end = bounce_from + reflected * resolved.range * float(traits.get("bounce_range_mult", 0.6))
					var bounce_hit = ray(bounce_from, bounce_end)
					if not bounce_hit.is_empty():
						bounce_end = bounce_hit.position
						hit_body(bounce_hit.collider, amount * float(traits.get("bounce_damage_mult", 0.65)), "weapon", from, {"traits": traits, "mods": modifiers, "origin": from})
					visuals.beam(bounce_from, bounce_end, Color(definition.color))
				if not is_enemy or penetration == (2 if item.id == "sniper" else 0):
					end = hit.position
					break
				cursor = hit.position + shot * 0.05
			visuals.beam(from + player.camera.global_basis.x * 0.2 - Vector3(0, 0.1, 0), end, Color(definition.color))
	if profile.data.settings.shake:
		player.recoil = minf(0.05, player.recoil + 0.012 * resolved.recoil_mult)
	audio.cue("shot", from, 0.5)

func punch() -> void:
	if state not in ["preparation", "wave"] or ui.overlay != "" or player.punch_timer > 0: return
	player.punch_timer = 0.55
	player.parry_timer = 0.16
	player.shot_feedback()
	audio.cue("wall_jump", player.position, 0.45)
	if state != "wave": return
	parry_projectiles()
	var from = player.camera.global_position
	var forward = -player.camera.global_basis.z
	var nearest = -1
	var distance = 3.4
	for uid in enemy_index.nearby(from, distance):
		var target = enemies[uid].node.position + Vector3.UP
		var offset = target - from
		if offset.length() < distance and offset.normalized().dot(forward) > 0.45 and sight(from, target):
			distance = offset.length()
			nearest = uid
	if nearest >= 0:
		var target = enemies[nearest]
		target.slow = maxf(target.slow, 0.65)
		target.slow_time = maxf(target.slow_time, 0.25)
		target.slow_at = elapsed
		visuals.beam(from, target.node.position + Vector3.UP, Color("ffd28a"))
		damage_enemy(nearest, 24 * (1 + bonus("damage")), "ability", player.position)
		ui.hit_flash = 0.12

func parry_reward(position: Vector3) -> void:
	player.parry_timer = 0
	health = minf(max_health, health + 5)
	player.dash_energy = minf(3, player.dash_energy + 0.35)
	player.impact_flash = 0.5
	stats.parries = int(stats.get("parries", 0)) + 1
	visuals.burst(position, Color("6bd8c6"), 8, 0.6)
	audio.cue("build", position, 0.4)
	ui.notify("PARRY · +5 health · dash energy restored")

func parry_projectiles() -> void:
	if player.parry_timer <= 0: return
	var from = player.camera.global_position
	var forward = -player.camera.global_basis.z
	for projectile in projectiles:
		if projectile.source != "enemy": continue
		var offset = projectile.pos - from
		if offset.length_squared() > 16 or offset.normalized().dot(forward) < 0.2 or not sight(from, projectile.pos): continue
		projectile.source = "weapon"
		projectile.gravity = 0.0
		projectile.velocity = forward * maxf(35, projectile.velocity.length() * 1.5)
		projectile.damage *= 2
		projectile.life = maxf(1.5, projectile.life)
		projectile.effects = {"mods": [], "elemental": false, "origin": from}
		projectile.color = Color("6bd8c6")
		projectile.mesh.material_override = visuals.material(projectile.color, 2)
		parry_reward(projectile.pos)
		return

func hit_body(body: Object, amount: float, source: String, origin: Vector3 = Vector3.ZERO, effects: Dictionary = {}) -> void:
	if not is_instance_valid(body):
		return
	if body.has_meta("enemy"):
		damage_enemy(int(body.get_meta("enemy")), amount, source, origin, effects)
	elif body.has_meta("structure"):
		if source == "enemy": damage_structure(str(body.get_meta("structure")), amount)
	elif body.has_meta("tile"):
		var key = str(body.get_meta("tile"))
		var tile = world.map.layers.structure.get(key, {})
		if world.can_destroy(world.point(key)):
			var definition = world.WALL_DEFS[tile.type]
			var modifiers: Array = effects.get("mods", weapons[active_weapon].get("mods", [])) if source == "weapon" else []
			var fire_damage = "incendiary" in modifiers
			tile.health -= amount * (float(tile.get("fire", definition.fire)) if fire_damage else 1 - float(tile.get("resistance", definition.resistance)))
			if tile.health <= 0:
				world.remove_structure(key)
				visuals.remove_fixed(key)
			else:
				var ratio = tile.health / maxf(1, tile.get("max_health", definition.health))
				var shade = 0.0 if ratio > 0.66 else (0.15 if ratio > 0.33 else 0.3)
				for mesh in body.get_children():
					if mesh is MeshInstance3D: mesh.material_override = visuals.material(Color(definition.color).darkened(shade))
	elif body == player:
		if source == "enemy": damage_player(amount)
	elif body.has_meta("core"):
		if source == "enemy": damage_core(amount)

func launch(pos: Vector3, velocity: Vector3, damage: float, splash: float, source: String, color: Color, life: float = 4.0, gravity: float = 0.0) -> void:
	if projectiles.size() >= 128:
		return
	var mesh = visuals.obtain_bolt(pos, color)
	var effects = {"mods": weapons[active_weapon].get("mods", []).duplicate(), "elemental": modules(weapons[active_weapon]).has("elemental"), "elemental_rarity": int(weapons[active_weapon].get("attachment_rarities", {}).get("elemental", 0)), "origin": player.camera.global_position} if source == "weapon" else {}
	if source == "weapon": effects.traits = weapon_traits(weapons[active_weapon])
	projectiles.append({"pos": pos, "velocity": velocity, "gravity": gravity, "damage": damage, "splash": splash, "source": source, "effects": effects, "life": life, "mesh": mesh, "color": color})

func explosion(pos: Vector3, damage: float, radius: float, source: String, effects: Dictionary = {}) -> void:
	visuals.burst(pos, Color("ffab58"), 16, radius)
	audio.cue("explosion", pos)
	if source in ["weapon", "tower", "ability", "consumable", "proc"]:
		var blast_effects = effects.duplicate()
		blast_effects.blast = true
		if source == "weapon" and not blast_effects.has("origin"): blast_effects.origin = player.camera.global_position
		for uid in enemy_index.nearby(pos, radius):
			if not enemies.has(uid): continue
			var enemy = enemies[uid]
			var center = enemy.node.position + Vector3.UP * (1.8 if enemy.type == "boss" else 1.0)
			var distance = center.distance_to(pos)
			if distance <= radius and sight(pos + Vector3.UP * 0.2, center, [], source == "tower"):
				damage_enemy(uid, damage * (1 - 0.5 * distance / radius), source, pos, blast_effects)
	else:
		if player.position.distance_to(pos) < radius:
			damage_player(damage)
		if world.position(world.marker("objective")).distance_to(pos) < radius:
			damage_core(damage)
		for key in world.construction.keys():
			if (structure_position(key) + Vector3.UP).distance_to(pos) < radius:
				damage_structure(key, damage)

func advance_enemy_dots(uid: int) -> bool:
	if not enemies.has(uid): return false
	var enemy = enemies[uid]
	for effect in ["burn", "poison"]:
		if enemy[effect] <= 0: continue
		var effect_delta = maxf(0, elapsed - float(enemy.get(effect + "_at", enemy.get("simulated_at", elapsed))))
		var active_delta = minf(effect_delta, maxf(0, enemy[effect + "_time"]))
		enemy[effect + "_time"] -= effect_delta
		enemy[effect + "_at"] = elapsed
		var source = "poison" if effect == "poison" else ("tower_dot" if enemy.burn_source == "tower" else "dot")
		damage_enemy(uid, enemy[effect] * active_delta, source)
		if enemy[effect + "_time"] <= 0: enemy[effect] = 0.0
		if not enemies.has(uid): return false
	return true

func damage_enemy(uid: int, amount: float, source: String, origin: Vector3 = Vector3.ZERO, effects: Dictionary = {}) -> void:
	if not enemies.has(uid) or state != "wave":
		return
	if source == "weapon" and not advance_enemy_dots(uid): return
	var enemy = enemies[uid]
	if enemy.health <= 0:
		return
	var armor = float(enemy.armor)
	if source == "weapon" and enemy.slow > 0: amount *= 1 + bonus("shatter")
	if source in ["weapon", "proc"]: armor = maxf(0, armor - bonus("penetration"))
	if enemy.type == "shielded" and origin != Vector3.ZERO:
		var incoming = (origin - enemy.node.position).normalized()
		if incoming.dot(-enemy.node.basis.z) > 0.3:
			armor += 0.45
	var actual = minf(enemy.health, amount * (1 - minf(0.8, armor)) * (1 - float(enemy.get("blast_resist", 0)) if effects.get("blast", false) else 1.0))
	enemy.health -= actual
	if actual > 0 and enemy.type == "regenerator": enemy.regen_ready_at = elapsed + 4.0
	if enemy.health > 0 and enemy.health < enemy.max_health and not wounded_index.entries.has(uid): wounded_index.add(uid, enemy.node.position, enemy.type)
	stats.damage += actual
	if effects.get("blast", false): stats.explosive_damage = stats.get("explosive_damage", 0.0) + actual
	if source in ["dot", "tower_dot", "poison"]: stats.elemental_damage = stats.get("elemental_damage", 0.0) + actual
	if source == "weapon" and effects.get("origin", origin).distance_to(enemy.node.position) < 9: stats.close_damage = stats.get("close_damage", 0.0) + actual
	if source in ["tower", "tower_dot"]:
		stats.tower_damage += actual
	elif source == "ability":
		stats.ability_damage = stats.get("ability_damage", 0.0) + actual
	else:
		stats.weapon_damage += actual
	if source == "weapon":
		ui.hit_flash = 0.12
		if actual > 1: audio.cue("hit", enemy.node.position, 0.12)
		visuals.damage_number(enemy.node.position + Vector3.UP * 2.2, actual)
		var modifiers: Array = effects.get("mods", weapons[active_weapon].get("mods", []))
		var elemental = effects.get("elemental", modules(weapons[active_weapon]).has("elemental"))
		var traits: Dictionary
		if effects.has("traits"): traits = effects.traits
		elif effects.has("mods"): traits = hit_traits(modifiers, elemental, int(effects.get("elemental_rarity", 0)))
		else: traits = weapon_traits(weapons[active_weapon])
		if bonus("burn") > 0 or traits.get("burn_dps", 0) > 0:
			var burn = (bonus("burn") + float(traits.get("burn_dps", 0))) * (1 - enemy.status_resist)
			if burn >= enemy.burn:
				enemy.burn = burn
				enemy.burn_source = "weapon"
			enemy.burn_time = maxf(3.0, float(traits.get("burn_duration", 0)))
			enemy.burn_at = elapsed
		if bonus("slow") + bonus("freeze") + float(traits.get("slow", 0)) > 0:
			var applied_slow = (bonus("slow") + bonus("freeze") + float(traits.get("slow", 0))) * (1 - enemy.status_resist)
			enemy.slow = minf(0.9, maxf(enemy.slow, applied_slow))
			enemy.slow_time = maxf(2.0, float(traits.get("slow_duration", 0)))
			enemy.slow_at = elapsed
		if bonus("poison") > 0:
			enemy.poison = bonus("poison") * (1 - enemy.status_resist)
			enemy.poison_time = 4.0
			enemy.poison_at = elapsed
		var leech = bonus("lifesteal") + float(traits.get("lifesteal", 0))
		if leech > 0: health = minf(max_health, health + actual * minf(0.3, leech))
		var chains_left = mini(2, int(traits.get("chain_targets", 0)))
		if chains_left > 0:
			var chain_radius = float(traits.get("chain_radius", 5.0))
			for other_id in enemy_index.nearby(enemy.node.position, chain_radius, 16):
				if other_id == uid or not enemies.has(other_id): continue
				var other_pos: Vector3 = enemies[other_id].node.position
				if other_pos.distance_squared_to(enemy.node.position) > chain_radius * chain_radius or not sight(enemy.node.position + Vector3.UP, other_pos + Vector3.UP): continue
				visuals.beam(enemy.node.position + Vector3.UP, other_pos + Vector3.UP, Color("6bd8ef"))
				damage_enemy(other_id, actual * float(traits.get("chain_damage_mult", 0.5)), "proc", enemy.node.position)
				chains_left -= 1
				if chains_left <= 0: break
		if bonus("chain") > 0 and rng.randf() < bonus("chain"):
			for other_id in enemy_index.nearby(enemy.node.position, 8):
				if other_id != uid and enemies[other_id].node.position.distance_squared_to(enemy.node.position) < 64 and sight(enemy.node.position + Vector3.UP, enemies[other_id].node.position + Vector3.UP):
					visuals.beam(enemy.node.position + Vector3.UP, enemies[other_id].node.position + Vector3.UP, Color("7bd7f2"))
					damage_enemy(other_id, actual * 0.4 * (1.5 if enemies[other_id].slow > 0 else 1.0), "proc", enemy.node.position)
					break
		if bonus("explosive") > 0 and rng.randf() < bonus("explosive"):
			explosion(enemy.node.position + Vector3.UP, actual * (0.5 if enemy.burn > 0 else 0.3), 3.5, "proc")
	if not enemies.has(uid): return
	if enemy.health > 0:
		return
	stats.kills += 1
	if source in ["weapon", "ability"] and player.position.distance_squared_to(enemy.node.position) <= 25 and sight(player.camera.global_position, enemy.node.position + Vector3.UP):
		health = minf(max_health, health + 3 + max_health * 0.02)
	if enemy.type == "boss":
		stats.bosses += 1
	kill_streak += 1
	kill_timer = 4.0
	stats.streak = maxi(int(stats.streak), kill_streak)
	var reward = int((6 + enemy.cost * 0.4) * (1 + bonus("production") * (0.2 if source in ["tower", "tower_dot"] else 0.0)))
	scrap += reward
	stats.earned += reward
	add_xp(int(enemy.cost))
	visuals.burst(enemy.node.position + Vector3.UP, Color(enemy.color), 8)
	if rng.randf() < 0.18 + bonus("loot") or enemy.type == "boss":
		drop_loot(enemy.node.position, enemy.type == "boss")
	audio.cue("kill", enemy.node.position, 0.35)
	EnemyBrain.release_hunt(self, enemy)
	enemy.node.queue_free()
	enemy_index.remove(uid)
	wounded_index.remove(uid)
	enemies.erase(uid)

func damage_player(amount: float, status_damage: bool = false) -> void:
	if state != "wave":
		return
	if not status_damage and player.dash_timer > 0: return
	amount *= 1 - minf(0.65, bonus("armor"))
	if status_damage: amount *= 1 - bonus("status_resist")
	var absorbed = minf(shield, amount)
	shield -= absorbed
	health = maxf(0, health - amount + absorbed)
	hurt_timer = 2.5
	ui.hurt_flash = 0.3
	audio.cue("hurt", player.position, 0.6)
	if health <= 0:
		if mode == "campaign": campaign.retry()
		else: defeat("Player defeated")

func damage_core(amount: float) -> void:
	if state != "wave":
		return
	for key in world.construction:
		var item = world.construction[key]
		if item.kind == "shield" and world.point(key).distance_to(world.marker("objective")) * 3 < item.range:
			amount *= 0.75
			break
	amount *= 1 - bonus("core_armor")
	var absorbed = minf(core_shield, amount)
	core_shield -= absorbed
	stats.core_damage_taken = stats.get("core_damage_taken", 0) + amount - absorbed
	core_health = maxf(0, core_health - amount + absorbed)
	visuals.burst(world.position(world.marker("objective"), 2), Color("ff7b59"), 4)
	if core_health <= 0:
		defeat("Objective destroyed")

func damage_structure(key: String, amount: float) -> void:
	if not world.construction.has(key) or state != "wave":
		return
	var item = world.construction[key]
	item.health -= amount
	if item.health <= 0:
		visuals.burst(world.position(world.point(key), 1), Color(item.color), 10)
		world.construction.erase(key)
		visuals.structure(key)

func repair_cost(item: Dictionary, amount: float, in_field: bool = false) -> int:
	return maxi(1, ceili(float(item.invested) * (0.5 if in_field else 0.35) * amount / maxf(1, item.max_health) * (1 - bonus("repair_efficiency"))))

func field_repair(key: String) -> String:
	if mode == "campaign" or state not in ["preparation", "wave"] or not world.construction.has(key): return "No defense to repair."
	if not repairs_allowed(): return "Repairs disabled in Challenge mode."
	var item: Dictionary = world.construction[key]
	var pos = structure_position(key) + Vector3.UP
	var excluded: Array[RID] = []
	if visuals.structures.has(key): excluded.append(visuals.structures[key].get_rid())
	if player.camera.global_position.distance_to(pos) > 5 or not sight(player.camera.global_position, pos, excluded): return "Move closer to repair this defense."
	if item.health >= item.max_health: return "Defense is already at full integrity."
	if elapsed < field_repair_ready_at: return "Field repair ready in %.1fs." % (field_repair_ready_at - elapsed)
	var amount = minf(item.max_health - item.health, item.max_health * 0.2)
	var price = repair_cost(item, amount, true)
	if scrap < price: return "Need %d scrap for field repair." % price
	scrap -= price
	stats.spent += price
	item.health += amount
	field_repair_ready_at = elapsed + 2.5
	visuals.burst(pos, Color("80d7a1"), 4, 0.6)
	audio.cue("build", pos, 0.4)
	return "Repaired %.0f integrity / %d scrap." % [amount, price]

func build(p: Vector2i, id: String, facing: int = 0) -> String:
	if state != "preparation":
		return "Construction is available only during Preparation."
	if not catalog.structures.has(id):
		return "Unknown structure."
	var definition = catalog.structures[id]
	if not repairs_allowed() and definition.kind == "repair": return "Repair stations are disabled by Challenge rules."
	var marker = world.map.layers.markers.get(world.cell_key(p), {}).get("type", "")
	if marker == "tower_pad" and definition.kind != "tower": return "This pad permits attack towers only."
	if marker == "structure_pad" and definition.kind == "tower": return "This pad is reserved for non-tower structures."
	if not unlocked(definition):
		return "Research required: " + definition.tech.replace("_", " ")
	var reason = placement(p, id)
	if reason != "":
		return reason
	if player != null and world.cell(player.position) == p:
		return "Move away from this tile before building."
	var cost = build_cost(definition)
	if scrap < cost:
		return "Not enough scrap."
	var item = definition.duplicate(true)
	item.id = id
	item.max_health = definition.health
	item.level = 1
	item.branch = ""
	item.branch_id = ""
	item.rotation = facing % 360
	item.cooldown = 0.0
	item.target_mode = 0
	item.invested = cost
	item.last_target = -1
	item.focus = 0.0
	world.construction[world.cell_key(p)] = item
	scrap -= cost
	stats.spent += cost
	stats.built += 1
	visuals.structure(world.cell_key(p))
	audio.cue("build", world.position(p), 0.5)
	return ""

func build_cost(definition: Dictionary) -> int:
	return maxi(1, int(definition.cost * (1 - minf(0.5, bonus("discount")))))

func manage_structure(key: String, action: String) -> String:
	if state != "preparation" or not world.construction.has(key):
		return "Structure management requires Preparation."
	var item = world.construction[key]
	if action == "rotate":
		item.rotation = (int(item.get("rotation", 0)) + 90) % 360
		visuals.structure(key)
		return ""
	if action in ["sell", "demolish"]:
		if action == "sell":
			scrap += int(item.invested * 0.65 * maxf(0.2, item.health / item.max_health))
		world.construction.erase(key)
		visuals.structure(key)
		return ""
	if action == "target":
		if item.id == "interceptor": return "Interceptor Arrays target hostile projectiles."
		item.target_mode = (int(item.target_mode) + 1) % TARGET_MODES.size()
		return ""
	if action == "repair":
		if not repairs_allowed():
			return "Repairs disabled in Challenge mode."
		if item.health >= item.max_health: return "Defense is already at full integrity."
		var price = repair_cost(item, item.max_health - item.health)
		if scrap < price:
			return "Not enough scrap."
		scrap -= price
		stats.spent += price
		item.health = item.max_health
		return ""
	if item.level >= 4:
		return "Maximum upgrade level reached."
	if not catalog.structure_upgrades.has(action): return "Unknown upgrade specialization."
	if action == "resonant" and (perk("tower_evolution") == 0 or item.kind != "tower"): return "Requires Resonant architecture and an attack tower."
	var branch = catalog.structure_upgrades[action]
	var current_branch = item.get("branch_id", "")
	if current_branch != "" and current_branch != action: return "This structure is already specialized in " + item.branch + "."
	if action == "rapid" and item.kind != "tower": return "Gatling specialization requires an attack tower."
	var price = int(item.cost * branch.cost * item.level)
	if scrap < price:
		return "Not enough scrap."
	scrap -= price
	stats.spent += price
	item.invested += price
	item.level += 1
	item.max_health *= branch.health
	item.health = item.max_health
	item.interval = maxf(0.08, item.interval * branch.interval) if item.interval > 0 else 0
	item.damage *= branch.damage
	item.range *= branch.range
	item.branch = branch.name if item.kind == "tower" else "Reinforced"
	item.branch_id = action
	visuals.structure(key)
	return ""

func move_structure(key: String, destination: Vector2i) -> String:
	if state != "preparation" or not world.construction.has(key): return "Moving structures requires Preparation."
	var item = world.construction[key]
	var reason = placement(destination, item.id)
	if reason != "": return reason
	if world.cell(player.position) == destination: return "Move away from the destination tile."
	var marker = world.map.layers.markers.get(world.cell_key(destination), {}).get("type", "")
	if marker == "tower_pad" and item.kind != "tower": return "This pad permits attack towers only."
	if marker == "structure_pad" and item.kind == "tower": return "This pad is reserved for non-tower structures."
	var price = maxi(1, int(ceil(item.cost * 0.1)))
	if scrap < price: return "Not enough scrap to move this structure."
	var next_key = world.cell_key(destination)
	world.construction.erase(key)
	world.construction[next_key] = item
	scrap -= price
	stats.spent += price
	visuals.structure(key)
	visuals.structure(next_key)
	return ""

func replace_structure(key: String, id: String) -> String:
	if state != "preparation" or not world.construction.has(key): return "Replacement requires Preparation."
	if not catalog.structures.has(id) or not unlocked(catalog.structures[id]): return "Research required for this structure."
	var p = world.point(key)
	if world.cell(player.position) == p: return "Move away from the structure before replacing it."
	var old = world.construction[key]
	world.construction.erase(key)
	var reason = world.placement(p, id)
	world.construction[key] = old
	if reason != "": return reason
	var refund = int(old.invested * 0.65 * maxf(0.2, old.health / old.max_health))
	if scrap + refund < build_cost(catalog.structures[id]): return "Not enough scrap, including the old structure's resale value."
	world.construction.erase(key)
	scrap += refund
	var result = build(p, id, int(old.get("rotation", 0)))
	if result != "":
		world.construction[key] = old
		scrap -= refund
	return result

func queued_enemies() -> int:
	var total = spawn_queue.size()
	for count in spawn_reserve.values(): total += int(count)
	return total

func reserve_budget(budget: float, pool: Array) -> Dictionary:
	var reserve: Dictionary = {}
	if budget < 7 or pool.is_empty(): return reserve
	var weights: Dictionary = {}
	var cost = 0.0
	for id in pool:
		weights[id] = int(weights.get(id, 0)) + 1
		cost += float(catalog.enemies[id].cost)
	var population = int(floor(budget / (cost / pool.size())))
	for id in weights:
		var count = int(floor(float(population) * weights[id] / pool.size()))
		if count > 0: reserve[id] = count
	return reserve

func refill_spawns() -> void:
	if not spawn_queue.is_empty(): return
	var remaining = queued_enemies()
	for i in mini(64, remaining):
		var roll = int(minf(float(remaining - 1), rng.randf() * remaining))
		for id in spawn_reserve:
			var count = int(spawn_reserve[id])
			if roll < count:
				spawn_queue.append(id)
				spawn_reserve[id] = count - 1
				remaining -= 1
				break
			roll -= count
	if remaining == 0: spawn_reserve.clear()

func compose_wave(number: int, random: RandomNumberGenerator) -> Dictionary:
	var queue: Array = []
	var budget = minf(1e12, (28 + number * 16 + pow(minf(number, 5000), 1.15) * 2) * world.rule("budget_multiplier"))
	if mode == "siege": budget = minf(1e12, budget * 1.25)
	var faction = Rules.faction(stats, number, adaptive_run)
	if number % int(world.rule("boss_interval")) == 0:
		queue.append("boss")
		budget -= 120
	var pool: Array = []
	for id in catalog.enemies:
		if id != "boss" and catalog.enemies[id].min_wave <= number:
			pool.append(id)
			if id == Rules.favored(faction): pool.append_array([id, id])
	var scheduled_event = upcoming_event(number)
	if scheduled_event in ["Explosive swarm", "Elite invasion"]:
		var replacement = "exploder" if scheduled_event == "Explosive swarm" else "tank"
		var extra_weight = maxi(1, ceili(float(pool.size()) / (2 if scheduled_event == "Explosive swarm" else 3)))
		for i in extra_weight: pool.append(replacement)
		if scheduled_event == "Elite invasion": budget /= 1.45
	var count = 0
	while budget >= 7 and count < 600:
		var id = pool[random.randi_range(0, pool.size() - 1)]
		if catalog.enemies[id].cost > budget:
			var affordable = pool.filter(func(candidate): return catalog.enemies[candidate].cost <= budget)
			if affordable.is_empty(): break
			id = affordable[random.randi_range(0, affordable.size() - 1)]
		queue.append(id)
		budget -= catalog.enemies[id].cost
		count += 1
	var reserve = reserve_budget(budget, pool)
	var counts = reserve.duplicate()
	for id in queue: counts[id] = int(counts.get(id, 0)) + 1
	var total = 0
	for count_value in counts.values(): total += int(count_value)
	return {"queue": queue, "reserve": reserve, "counts": counts, "total": total, "event": scheduled_event, "faction": faction, "active_spawns": world.spawns(completed).size()}

func preview_wave() -> Dictionary:
	if state != "preparation" or mode == "campaign" or spectator: return {}
	var preview_rng = RandomNumberGenerator.new()
	preview_rng.seed = rng.seed
	preview_rng.state = rng.state
	return compose_wave(wave + 1, preview_rng)

func start_wave() -> bool:
	if mode == "campaign" or spectator or state != "preparation" or reward_pending:
		return false
	var checkpoint_ok = save_run() if eligible else true
	wave += 1
	wave_contract.clear()
	if CONTRACTS.has(contract_choice):
		var definition: Dictionary = CONTRACTS[contract_choice]
		wave_contract = {"id": contract_choice, "wave": wave, "baseline": float(stats.get(definition.stat, 0)), "target": contract_target(contract_choice, wave), "status": "active"}
	stats.wave = wave
	state = "wave"
	ui.close_overlay()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if autoplay else Input.MOUSE_MODE_CAPTURED
	var plan = compose_wave(wave, rng)
	spawn_queue = plan.queue
	spawn_reserve = plan.reserve
	faction_name = plan.faction
	spawn_timer = 0.2
	event_name = plan.event
	visuals.set_weather("Acid rain" if challenge("acid_rain") else event_name, wave)
	ui.notify("WAVE %d%s%s" % [wave, " · " + event_name if event_name != "" else "", "\nCheckpoint could not be saved; the current run is still active." if not checkpoint_ok else ""])
	audio.cue("wave")
	return true

func contract_target(id: String, number: int) -> float:
	var definition: Dictionary = CONTRACTS[id]
	return minf(definition.cap, definition.base + number * definition.scale)

func select_contract(id: String) -> void:
	if state != "preparation" or reward_pending or mode == "campaign" or spectator: return
	if id != "" and not CONTRACTS.has(id): return
	contract_choice = id
	if eligible: save_run()
	ui.show_planning()

func contract_description(id: String, number: int) -> String:
	if id == "guardian": return "Clear the wave without core integrity damage"
	return "Deal %d %s damage this wave" % [contract_target(id, number), "weapon" if id == "operator" else "tower"]

func contract_progress() -> float:
	if wave_contract.is_empty(): return 0
	var key: String = CONTRACTS[wave_contract.id].stat
	return maxf(0, float(stats.get(key, 0)) - float(wave_contract.baseline))

func resolve_contract() -> void:
	if wave_contract.is_empty() or wave_contract.status != "active" or int(wave_contract.wave) != wave: return
	var success = contract_progress() <= 0 if wave_contract.id == "guardian" else contract_progress() >= float(wave_contract.target)
	wave_contract.status = "complete" if success else "failed"
	if not success: return
	var reward = 30 + mini(wave * 8, 600)
	scrap += reward
	stats.earned += reward
	var rarity = mini(3, wave / 8)
	supply_cache = [
		{"id": "ammo_cell", "rarity": rarity, "count": 1},
		{"id": "trauma_kit", "rarity": rarity, "count": 1},
		{"id": "repair_kit" if repairs_allowed() else "shield_pack", "rarity": rarity, "count": 1}
	]
	ui.notify("%s contract complete · +%d scrap and a supply cache" % [CONTRACTS[wave_contract.id].name, reward])

func claim_supply(index: int) -> void:
	if state != "preparation" or not reward_pending or supply_cache.is_empty(): return
	if index < -1 or index >= supply_cache.size(): return
	if index >= 0 and backpack.size() >= capacity:
		ui.notify("Backpack full. Salvage the cache to continue.")
		return
	if index == -1:
		var value = 25 + int(supply_cache[0].rarity) * 15
		scrap += value
		stats.earned += value
	else:
		backpack.append(supply_cache[index].duplicate(true))
	supply_cache.clear()
	refresh_wave_rewards()

func refresh_wave_rewards() -> void:
	reward_pending = upgrade_picks > 0 or not supply_cache.is_empty()
	if reward_pending: ui.show_upgrades()
	else: ui.close_overlay()
	if eligible: save_run()

func upcoming_event(number: int) -> String:
	if number % int(world.rule("boss_interval")) == 0: return "Siege Titan"
	if challenge("acid_rain"): return "Acid rain"
	if number % 17 == 0: return "Acid rain"
	if number % 13 == 0: return "Elite invasion"
	if number % 11 == 0: return "Explosive swarm"
	if number % 9 == 0: return "Tower interference"
	if number % 7 == 0: return "Heavy fog"
	if number % 6 == 0: return "Blackout"
	if number % 5 == 0: return "Armored assault"
	return ""

func spawn_enemy(id: String, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	if not catalog.enemies.has(id):
		return
	var definition = catalog.enemies[id]
	var enemy = definition.duplicate(true)
	var scale_factor = 1 + log(1 + maxf(0, wave - 1) * 0.13) * 0.8
	enemy.health *= scale_factor * world.rule("enemy_health")
	enemy.max_health = enemy.health
	enemy.damage *= 1 + log(1 + maxf(0, wave - 1) * 0.06)
	enemy.speed *= minf(1.8, 1 + wave * 0.008)
	if challenge("fast"):
		enemy.speed *= 1.25
	if event_name == "Armored assault":
		enemy.armor = minf(0.7, enemy.armor + 0.15)
	enemy.blast_resist = 0.2 if faction_name == "Bulwark" else 0.0
	enemy.status_resist = 0.2 if faction_name == "Purifiers" else 0.0
	enemy.elite = id != "boss" and (event_name == "Elite invasion" or rng.randf() < minf(0.3, maxf(0, wave - 15) * 0.003))
	if enemy.elite:
		enemy.health *= 1.45
		enemy.max_health = enemy.health
		enemy.damage *= 1.2
		enemy.speed *= 1.1
		enemy.color = "d1a5ef"
	next_uid += 1
	enemy.uid = next_uid
	enemy.type = id
	enemy.cooldown = 0.5
	enemy.slow = 0.0
	enemy.slow_time = 0.0
	enemy.burn = 0.0
	enemy.burn_time = 0.0
	enemy.burn_source = "weapon"
	enemy.poison = 0.0
	enemy.poison_time = 0.0
	enemy.summon_timer = 6.0
	enemy.think_timer = float(next_uid % 6) / 60.0
	enemy.steering = Vector3.ZERO
	enemy.ai = "navigate"
	enemy.heal_timer = 0.5 + float(next_uid % 30) / 30.0
	if id == "regenerator": enemy.regen_ready_at = elapsed + 4.0
	var node = visuals.enemy(enemy)
	enemy.node = node
	enemy.simulated_at = elapsed
	enemy.simulation_ticks = 0
	if spawn_pos == Vector3.ZERO:
		var points = world.spawns(completed)
		if points.is_empty():
			node.queue_free()
			return
		spawn_pos = world.position(points[rng.randi_range(0, points.size() - 1)])
	node.position = spawn_pos + Vector3(rng.randf_range(-0.5, 0.5), 0.1, rng.randf_range(-0.5, 0.5))
	enemy_index.add(enemy.uid, node.position, enemy.type)
	visuals.enemy_renderer.sync(enemy.uid)
	enemies[enemy.uid] = enemy

func finish_wave() -> void:
	if state != "wave" or completed >= wave or queued_enemies() > 0 or not enemies.is_empty():
		return
	completed = wave
	state = "completion"
	clear_projectiles()
	reset_atmosphere()
	var reward = 65 + mini(wave * 12, 4000)
	scrap += reward
	stats.earned += reward
	resolve_contract()
	for key in world.construction:
		var item = world.construction[key]
		if item.kind == "generator":
			var generated = int(40 * int(item.level) * (1 + bonus("production")))
			scrap += generated
			stats.earned += generated
		if item.kind == "ammo" and not scarce_ammo():
			for weapon in weapons:
				if weapon.id == "": continue
				weapon.reserve = mini(int(weapon.reserve + 60 * item.level), 9999)
	for weapon in weapons:
		if weapon.id == "": continue
		if not scarce_ammo(): weapon.reserve = mini(int(weapon.reserve + catalog.weapons[weapon.id].magazine * 2), 9999)
	for tile in world.interactive_tiles().values():
		if tile.type == "generator":
			var generated = int(25 * (1 + bonus("production")))
			scrap += generated
			stats.earned += generated
	health = minf(max_health, health + 10)
	var messages = world.evolve(completed)
	if mode == "frontier" and completed % 4 == 0:
		var expansion = World.Levels.expand(world, completed)
		if not expansion.is_empty(): messages.append(expansion)
	if not messages.is_empty():
		visuals.rebuild()
	ui.notify("Wave %d cleared · +%d scrap%s" % [wave, reward, "\n" + "\n".join(messages) if not messages.is_empty() else ""])
	add_xp(0)
	state = "preparation"
	reward_pending = true
	upgrade_picks = maxi(1, pending_levels)
	pending_levels = 0
	roll_upgrades()
	ui.show_upgrades()
	if eligible:
		save_run()

func add_xp(amount: int) -> void:
	xp += maxi(0, amount)
	var gained = 0
	while xp >= next_xp:
		xp -= next_xp
		level += 1
		gained += 1
		if level <= 31:
			max_health += 6
			health = minf(max_health, health + 6)
		next_xp = mini(250000, int(next_xp * 1.24 + 8))
	pending_levels += gained
	if gained > 0: ui.notify("Level %d · %d upgrade choice%s at wave clear" % [level, pending_levels, "s" if pending_levels != 1 else ""])

func upgrade_effect_available(effect: String) -> bool:
	if bonus(effect) > 0: return true
	for item in weapons:
		if item.id == "": continue
		var traits = weapon_traits(item)
		if effect == "burn" and traits.get("burn_dps", 0) > 0: return true
		if effect in ["slow", "freeze"] and traits.get("slow", 0) > 0: return true
	for tower in world.construction.values():
		if effect in ["slow", "freeze"] and tower.slow > 0: return true
		if effect == "burn" and tower.id == "flame": return true
	return false

func roll_upgrades() -> void:
	var pool: Array = []
	for upgrade in catalog.upgrades:
		if upgrade.effect == "medkit_reward" and consumables.medkit >= 99: continue
		if upgrade.effect == "reserve_reward" and not weapons.any(func(item): return item.id != "" and catalog.weapons[item.id].magazine > 0 and item.reserve < 9999): continue
		var limit = minf(float(upgrade.get("cap", 1e12)), float(Rules.CAPS.get(upgrade.effect, 1e12)))
		if bonus(upgrade.effect) >= limit: continue
		var requirements: Array = upgrade.get("requires_effects", [])
		if not requirements.is_empty() and not requirements.any(func(effect): return upgrade_effect_available(effect)): continue
		pool.append(upgrade.duplicate(true))
	upgrades = []
	for slot in mini(3, pool.size()):
		var candidates: Array = []
		for index in pool.size():
			if slot > 0 or not str(pool[index].effect).ends_with("_reward"): candidates.append(index)
		if candidates.is_empty():
			for index in pool.size(): candidates.append(index)
		var weights: Dictionary = catalog.get("upgrade_rarity_weights", {"Common": 60, "Uncommon": 28, "Rare": 12})
		var total = 0.0
		for index in candidates: total += float(weights.get(pool[index].get("rarity", "Common"), 12))
		var roll = rng.randf() * total
		for index in candidates:
			roll -= float(weights.get(pool[index].get("rarity", "Common"), 12))
			if roll <= 0:
				upgrades.append(pool[index])
				pool.remove_at(index)
				break

func choose_upgrade(index: int) -> void:
	if state != "preparation" or not reward_pending or upgrade_picks <= 0 or index < 0 or index >= upgrades.size():
		return
	var upgrade = upgrades[index]
	var applied = float(upgrade.value)
	if upgrade.effect == "scrap_reward":
		scrap += int(upgrade.value)
		stats.earned += int(upgrade.value)
	elif upgrade.effect == "reserve_reward":
		for item in weapons:
			if item.id != "" and catalog.weapons[item.id].magazine > 0: item.reserve = mini(9999, int(item.reserve + upgrade.value))
	elif upgrade.effect == "medkit_reward": consumables.medkit = mini(99, int(consumables.medkit + upgrade.value))
	else:
		var before = bonus(upgrade.effect)
		bonuses[upgrade.effect] = minf(before + float(upgrade.value), minf(float(upgrade.get("cap", 1e12)), float(Rules.CAPS.get(upgrade.effect, 1e12))))
		applied = bonus(upgrade.effect) - before
	if upgrade.effect == "health":
		max_health += applied
		health = minf(max_health, health + applied)
	if upgrade.effect == "shield":
		shield += applied
	upgrade_picks = maxi(0, upgrade_picks - 1)
	if upgrade_picks > 0: roll_upgrades()
	else: upgrades.clear()
	refresh_wave_rewards()

func defeat(reason: String) -> void:
	if state != "wave":
		return
	state = "results"
	clear_projectiles()
	reset_atmosphere()
	defeat_reason = reason
	stats.duration = elapsed
	stats.completed = completed
	stats.cleared = maxi(0, completed - (19 if mode == "siege" else 0))
	stats.reward_wave = maxi(1, wave - (19 if mode == "siege" else 0))
	stats.score = int(stats.kills * 10 + stats.bosses * 100 + stats.cleared * 50)
	stats.records = []
	stats.achievements = []
	if eligible:
		if wave > profile.data.best: stats.records.append("Personal best wave")
		if stats.score > profile.data.high_score: stats.records.append("Personal best score")
		var milestones = Rules.achievements(stats)
		for name_value in milestones:
			if milestones[name_value] and not profile.data.achievements.has(name_value): stats.achievements.append(name_value)
	last_reward = profile.award(run_id, stats, eligible)
	if eligible and last_reward >= 0:
		remove_run_save()
	ui.show_results()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if autoplay:
		print("BENCHMARK defeat ", JSON.stringify(stats), " tp=", last_reward)

func consume(id: String) -> void:
	if state not in ["preparation", "wave"] or consumables.get(id, 0) <= 0:
		return
	if id == "medkit":
		if health >= max_health:
			ui.notify("Health is already full.")
			return
		health = minf(max_health, health + 50)
	else:
		if state != "wave":
			return
		launch(player.camera.global_position, -player.camera.global_basis.z * 18 + Vector3.UP * 4, 120, 6, "consumable", Color("ffb265"), 2, 9.8)
	consumables[id] -= 1
	audio.cue("build")

func ability() -> void:
	if mode == "campaign": return
	if state != "wave" or ability_timer > 0:
		return
	ability_timer = 18 / (1 + bonus("ability")) * (1 - bonus("ability_rate"))
	explosion(player.position + Vector3.UP, 55 * (1 + bonus("ability_power")), 8, "ability")
	for uid in enemy_index.nearby(player.position, 8):
		var enemy = enemies[uid]
		if enemy.node.position.distance_to(player.position) < 8:
			enemy.slow = 0.85
			enemy.slow_time = 3
			enemy.slow_at = elapsed
	ui.notify("Pulse discharged")

func restoration() -> void:
	var rank_value = perk("pulse_matrix")
	if state != "wave" or restoration_timer > 0 or rank_value == 0: return
	restoration_timer = 30
	health = minf(max_health, health + 25 * rank_value)
	if repairs_allowed():
		for key in world.construction:
			if world.position(world.point(key)).distance_to(player.position) < 10:
				world.construction[key].health = minf(world.construction[key].max_health, world.construction[key].health + 35 * rank_value)
	visuals.burst(player.position + Vector3.UP, Color("70dfba"), 12, 3)
	ui.notify("Restoration matrix discharged")

func interact() -> void:
	if not playing() or state == "paused":
		return
	if mode == "campaign":
		campaign.interact()
		return
	var nearest = -1
	var distance = 3.5
	for i in drops.size():
		var d = drops[i].pos.distance_to(player.position)
		if d < distance:
			nearest = i
			distance = d
	if nearest >= 0:
		pickup(nearest)
		return
	var hit = ray(player.camera.global_position, player.camera.global_position - player.camera.global_basis.z * 4, 1)
	if not hit.is_empty() and hit.collider.has_meta("structure"):
		ui.notify(field_repair(str(hit.collider.get_meta("structure"))))
		return
	if not hit.is_empty() and hit.collider.has_meta("tile"):
		var key = str(hit.collider.get_meta("tile"))
		var tile = world.map.layers.structure.get(key, {})
		if tile.get("type") == "door" and not tile.get("locked", false):
			world.remove_structure(key)
			hit.collider.queue_free()
			audio.cue("build", hit.position)
			return
	if state == "preparation":
		var interactive = world.interactive_tiles()
		for key in interactive:
			var tile = interactive[key]
			if world.position(world.point(key), float(tile.get("elevation", 0))).distance_to(player.position) < 4:
				if tile.type == "chest":
					if not tile.get("opened", false):
						tile.opened = true
						drop_loot(world.position(world.point(key)) + Vector3(1.8, 0, 0), true)
						ui.notify("Supply chest opened.")
					else: ui.notify("This chest is empty.")
					return
				if tile.type in ["supply", "shop", "ammo", "upgrade"]:
					ui.show_shop()
					return

func drop_loot(pos: Vector3, boss: bool = false) -> void:
	if drops.size() >= 80:
		return
	var available: Array = []
	for id in catalog.weapons:
		if unlocked(catalog.weapons[id]):
			available.append(id)
	var rarity = 0
	var weights: Array = catalog.loot.rarity_weights
	var total_weight = 0
	for weight in weights: total_weight += int(weight)
	var roll = rng.randf() * total_weight
	var threshold = 0
	for i in range(weights.size()):
		threshold += int(weights[i])
		if roll <= threshold:
			rarity = i
			break
	if boss: rarity = maxi(2, rarity)
	var item: Dictionary
	if rng.randf() < 0.55 or boss:
		item = make_weapon(available[rng.randi_range(0, available.size() - 1)], rarity)
	else:
		var kinds: Array = ["medkit", "grenade"] + catalog.equipment.keys() + catalog.attachments.keys()
		item = {"id": kinds[rng.randi_range(0, kinds.size() - 1)], "count": 1, "rarity": rarity}
	place_drop(item, pos)

func place_drop(item: Dictionary, pos: Vector3) -> bool:
	if drops.size() >= 80: return false
	var colors = [Color("c5ced2"), Color("97c86d"), Color("69bae9"), Color("bf89e1"), Color("ffbc62")]
	var mesh = visuals.box(visuals, pos + Vector3(0, 0.5, 0), Vector3(0.5, 0.5, 0.5), colors[int(item.rarity)], 0.7)
	drops.append({"item": item, "pos": pos, "mesh": mesh})
	return true

func pickup(index: int) -> void:
	if index < 0 or index >= drops.size():
		return
	var drop = drops[index]
	var item = drop.item
	if item.id in ["medkit", "grenade"]:
		if consumables[item.id] >= 99:
			ui.notify("This consumable stack is full.")
			return
		consumables[item.id] = mini(99, consumables[item.id] + int(item.get("count", 1)))
	else:
		if backpack.size() >= capacity:
			ui.notify("Backpack full. Scrap, drop, or equip an item.")
			return
		backpack.append(item)
	ui.notify("Collected " + item_name(item))
	stats.loot_collected = stats.get("loot_collected", 0) + 1
	drop.mesh.queue_free()
	drops.remove_at(index)
	audio.cue("ui")

func item_name(item: Dictionary) -> String:
	if item.id == "": return "Unarmed"
	for group in ["weapons", "attachments", "equipment"]:
		if catalog.get(group, {}).has(item.id): return catalog[group][item.id].name
	return str(item.id).replace("_", " ").capitalize()

func equipment_blocked(id: String) -> String:
	if mode == "campaign" or spectator: return "Unavailable in this mode"
	if id == "armor" and bonus("armor") >= 0.65: return "Armor at maximum"
	if id == "shield_pack" and shield >= bonus("shield") + 200: return "Shield overcharge full"
	if id == "trauma_kit" and health >= max_health: return "Health already full"
	if id == "repair_kit":
		if not repairs_allowed(): return "Repairs disabled by run rules"
		if core_health >= max_core: return "Core integrity already full"
	if id == "ammo_cell":
		var active: Dictionary = weapons[active_weapon]
		if active.id == "" or magazine_size(active) == 0: return "Equip a firearm first"
		if active.reserve >= 9999: return "Reserve ammunition full"
	return ""

func equipment_effect(item: Dictionary) -> float:
	var values: Dictionary = catalog.equipment[item.id].stats
	return float(values.get("amount", values.get("magazines", 0))) + int(item.get("rarity", 0)) * float(values.get("rarity_bonus", 0))

func inventory_action(index: int, action: String) -> void:
	if not playing() or state == "paused" or mode == "campaign" or spectator or index < 0 or index >= backpack.size():
		return
	var item = backpack[index]
	if action in ["equip0", "equip1"] and catalog.weapons.has(item.id):
		if not unlocked(catalog.weapons[item.id]):
			return
		var slot = int(action.right(1))
		var old = weapons[slot]
		weapons[slot] = item
		if old.id == "": backpack.remove_at(index)
		else: backpack[index] = old
		reload_timer = 0
		player.refresh_gun()
	elif action == "use":
		if catalog.equipment.has(item.id):
			var blocked = equipment_blocked(item.id)
			if blocked != "":
				ui.notify(blocked)
				return
		if catalog.attachments.has(item.id):
			if weapons[active_weapon].id == "":
				ui.notify("Equip a weapon before attaching a module.")
				return
			if not attachment_compatible(item.id, weapons[active_weapon]):
				ui.notify("This module is incompatible with the active weapon.")
				return
			var equipped = modules(weapons[active_weapon])
			var module_slot = str(catalog.attachments[item.id].slot)
			var old = equipped.get(module_slot, "")
			if not weapons[active_weapon].has("attachment_rarities"): weapons[active_weapon].attachment_rarities = {}
			var rarities: Dictionary = weapons[active_weapon].attachment_rarities
			var old_rarity = int(rarities.get(module_slot, 0))
			equipped[module_slot] = item.id
			rarities[module_slot] = int(item.get("rarity", 0))
			backpack.remove_at(index)
			if old != "": backpack.append({"id": old, "count": 1, "rarity": old_rarity})
		elif item.id == "armor":
			bonuses.armor = minf(0.65, bonus("armor") + 0.05)
			backpack.remove_at(index)
		elif item.id == "shield_pack":
			shield = minf(bonus("shield") + 200, shield + 30)
			backpack.remove_at(index)
		elif item.id in ["ammo_cell", "trauma_kit", "repair_kit"]:
			var amount = equipment_effect(item)
			if item.id == "trauma_kit": health = minf(max_health, health + amount)
			elif item.id == "repair_kit": core_health = minf(max_core, core_health + amount)
			else:
				var active: Dictionary = weapons[active_weapon]
				active.reserve = mini(9999, int(active.reserve + magazine_size(active) * amount))
			backpack.remove_at(index)
	elif action in ["scrap", "sell"]:
		if action == "sell" and state != "preparation": return
		var value = 15 + int(item.get("rarity", 0)) * 12
		if action == "sell": value = int(value * 1.5)
		scrap += value
		stats.earned += value
		backpack.remove_at(index)
	elif action == "drop":
		if drops.size() >= 80: return
		var pos = player.position + -player.basis.z * 2
		place_drop(item.duplicate(true), pos)
		backpack.remove_at(index)
	ui.show_inventory()

func unequip_weapon(index: int) -> void:
	if not playing() or state == "paused" or index < 0 or index > 1: return
	if weapons[index].id == "": return
	if backpack.size() >= capacity:
		ui.notify("Backpack full.")
		return
	backpack.append(weapons[index])
	weapons[index] = {"id": "", "rarity": 0, "roll": 1, "ammo": 0, "reserve": 0, "attachments": {}, "mods": []}
	reload_timer = 0
	player.refresh_gun()
	ui.show_inventory()

func detach_module(slot: String) -> void:
	if not playing() or state == "paused": return
	var item = weapons[active_weapon]
	var equipped = modules(item)
	if not equipped.has(slot): return
	if backpack.size() >= capacity:
		ui.notify("Backpack full.")
		return
	backpack.append({"id": equipped[slot], "count": 1, "rarity": int(item.get("attachment_rarities", {}).get(slot, 0))})
	if item.has("attachment_rarities"): item.attachment_rarities.erase(slot)
	equipped.erase(slot)
	var excess = maxi(0, int(item.ammo) - magazine_size(item))
	item.ammo -= excess
	item.reserve += excess
	ui.show_inventory()

func supply_cost(id: String) -> int:
	return maxi(1, int(ceil((80 if catalog.weapons.has(id) else 35) * (1 - bonus("supply")) * (1.5 if mode == "scavenger" else 1.0))))

func buy(id: String) -> void:
	if state != "preparation":
		return
	if not catalog.weapons.has(id) and id not in ["ammo", "core", "medkit", "grenade"]: return
	if id == "core" and not repairs_allowed(): return
	if id == "core" and core_health >= max_core:
		ui.notify("Core integrity is already full.")
		return
	if id == "ammo" and not weapons.any(func(item): return item.id != "" and catalog.weapons[item.id].magazine > 0 and item.reserve < 9999):
		ui.notify("No equipped firearm needs reserve ammunition.")
		return
	if id in ["medkit", "grenade"] and consumables[id] >= 99:
		ui.notify("This consumable stack is full.")
		return
	var cost = 35
	if catalog.weapons.has(id):
		cost = 80
		if not unlocked(catalog.weapons[id]) or backpack.size() >= capacity:
			ui.notify("Research required or backpack full.")
			return
	cost = supply_cost(id)
	if scrap < cost:
		ui.notify("Not enough scrap.")
		return
	scrap -= cost
	stats.spent += cost
	if id == "ammo":
		for weapon in weapons:
			if weapon.id == "": continue
			weapon.reserve = mini(9999, int(weapon.reserve + catalog.weapons[weapon.id].magazine * 4))
	elif id == "core":
		if repairs_allowed(): core_health = minf(max_core, core_health + 120)
	elif id in ["medkit", "grenade"]:
		consumables[id] += 1
	elif catalog.weapons.has(id):
		backpack.append(make_weapon(id))
	ui.show_shop()

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(ui): return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F4 and mode == "sandbox" and not spectator and state in ["preparation", "wave"] and not reward_pending:
		if ui.overlay == "sandbox": ui.close_overlay()
		else: ui.show_sandbox()
	if event.is_action_pressed("debug"):
		ui.debug_visible = not ui.debug_visible
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), ui.debug_visible or autoplay)
	if event.is_action_pressed("pause"):
		if mode == "campaign" and campaign.finished:
			ui.show_campaign_complete()
			return
		if state == "paused":
			state = previous_state
			ui.close_overlay()
		elif playing():
			if ui.overlay != "":
				if not reward_pending: ui.close_overlay()
			else:
				previous_state = state
				state = "paused"
				ui.show_pause()
		elif state == "editor":
			ui.editor.authoring = world.map.duplicate(true)
			ui.show_menu()
	if playing() and state != "paused" and not spectator:
		if event.is_action_pressed("unstuck") and ui.overlay == "": player.unstuck()
		if mode == "campaign": return
		if event.is_action_pressed("inventory") and not reward_pending:
			if ui.overlay == "inventory": ui.close_overlay()
			else: ui.show_inventory()
		if event.is_action_pressed("planning") and not reward_pending:
			if state != "preparation": ui.notify("Planning opens between waves.")
			elif ui.overlay == "planning": ui.close_overlay()
			else: ui.show_planning()
		if event.is_action_pressed("next_wave") and ui.overlay in ["", "planning"]:
			start_wave()

func _physics_process(delta: float) -> void:
	if autoplay:
		var benchmark_start = Time.get_ticks_usec()
		benchmark_update(delta)
		benchmark_update_ms = (Time.get_ticks_usec() - benchmark_start) / 1000.0
	if state not in ["preparation", "wave"]:
		return
	var start = Time.get_ticks_usec()
	elapsed += delta
	if spectator: return
	if mode == "campaign":
		hurt_timer = maxf(0, hurt_timer - delta)
		campaign.update(delta)
		return
	fire_timer = maxf(0, fire_timer - delta)
	ability_timer = maxf(0, ability_timer - delta)
	restoration_timer = maxf(0, restoration_timer - delta)
	hurt_timer = maxf(0, hurt_timer - delta)
	kill_timer -= delta
	if kill_timer <= 0: kill_streak = 0
	if hurt_timer <= 0:
		health = minf(max_health, health + (bonus("regen") + minf(2.0, maxf(0, level - 1) * 0.1)) * delta)
		shield = minf(bonus("shield"), shield + delta * 2) if shield < bonus("shield") else shield
	if reload_timer > 0:
		reload_timer -= delta
		if reload_timer <= 0:
			reload_timer = 0
			var item = weapons[active_weapon]
			var amount = mini(magazine_size(item) - int(item.ammo), int(item.reserve))
			item.ammo += amount
			item.reserve -= amount
	for drop in drops:
		drop.mesh.rotation.y += delta
		drop.mesh.position.y = 0.6 + sin(elapsed * 2) * 0.1
	if state != "wave":
		core_shield = minf(bonus("core_shield"), core_shield + delta * 3)
		for item in world.construction.values(): item.cooldown = maxf(0, item.cooldown - delta)
		return
	spawn_timer -= delta
	if spawn_timer <= 0 and not spawn_queue.is_empty():
		spawn_enemy(spawn_queue.pop_front())
		spawn_timer = maxf(0.12, world.rule("spawn_interval") / (1 + wave * 0.08))
	elif spawn_timer <= 0 and spawn_queue.is_empty() and not spawn_reserve.is_empty():
		refill_spawns()
	var phase_start = Time.get_ticks_usec()
	if player.parry_timer > 0: parry_projectiles()
	update_enemies(delta)
	simulation_phases.enemies = (Time.get_ticks_usec() - phase_start) / 1000.0
	if state != "wave": return
	phase_start = Time.get_ticks_usec()
	update_towers(delta)
	simulation_phases.towers = (Time.get_ticks_usec() - phase_start) / 1000.0
	phase_start = Time.get_ticks_usec()
	update_projectiles(delta)
	simulation_phases.projectiles = (Time.get_ticks_usec() - phase_start) / 1000.0
	hazard_timer -= delta
	if hazard_timer <= 0:
		hazard_timer = 0.5
		update_hazards()
	if queued_enemies() == 0 and enemies.is_empty():
		finish_wave()
	simulation_ms = (Time.get_ticks_usec() - start) / 1000.0
	peak_simulation_ms = maxf(peak_simulation_ms, simulation_ms)

func move_enemy(node: CharacterBody3D, delta: float) -> void:
	var needs_floor_sweep = not world.flat_floor and (not world.complete_floor or world.sloped_cells.has(world.cell_key(world.cell(node.position))))
	if needs_floor_sweep or not node.is_on_floor() or absf(node.position.y) > 0.01:
		var scale_delta = delta * Engine.physics_ticks_per_second
		var original_velocity = node.velocity
		node.velocity *= scale_delta
		node.move_and_slide()
		node.velocity = original_velocity
		return
	var motion = Vector3(node.velocity.x, 0, node.velocity.z) * delta
	if motion.length_squared() <= 0.000001: return
	var collision = node.move_and_collide(motion)
	if collision:
		var remainder = collision.get_remainder().slide(collision.get_normal())
		if remainder.length_squared() > 0.000001: node.move_and_collide(remainder)

func update_enemies(frame_delta: float) -> void:
	var update_start = Time.get_ticks_usec()
	var movement_us = 0
	var crowd_us = 0
	var maximum_step = 0.0
	var objective_pos = world.position(world.marker("objective"))
	var work: Array = []
	var selected: Dictionary = {}
	var population = enemy_index.ids.size()
	var count = mini(population, enemy_batch)
	for uid in enemy_index.nearby(player.position, 18, mini(32, maxi(1, count / 4))) + enemy_index.nearby(objective_pos, 6, mini(16, maxi(1, count / 8))):
		if not selected.has(uid) and work.size() < count:
			work.append(uid)
			selected[uid] = true
	for i in population:
		if work.size() >= count: break
		enemy_cursor = posmod(enemy_cursor, population)
		var uid = enemy_index.ids[enemy_cursor]
		enemy_cursor += 1
		if not selected.has(uid):
			work.append(uid)
			selected[uid] = true
	for uid in work:
		if not enemies.has(uid) or state != "wave": continue
		var enemy = enemies[uid]
		var delta = maxf(frame_delta, elapsed - float(enemy.get("simulated_at", elapsed - frame_delta)))
		maximum_step = maxf(maximum_step, delta)
		var was_attacking = enemy.ai == "attack"
		if not advance_enemy_dots(uid): continue
		enemy.simulated_at = elapsed
		if enemy.type == "regenerator" and enemy.health < enemy.max_health:
			var regen_delta = minf(delta, maxf(0, elapsed - float(enemy.get("regen_ready_at", elapsed + 4.0))))
			enemy.health = minf(enemy.max_health, enemy.health + enemy.max_health * 0.04 * regen_delta)
			if enemy.health >= enemy.max_health: wounded_index.remove(uid)
		enemy.simulation_ticks = int(enemy.get("simulation_ticks", 0)) + 1
		var node: CharacterBody3D = enemy.node
		if node.position.y < -10:
			var portals = world.spawns(completed)
			node.position = world.position(portals[uid % portals.size()], 0.1)
			node.velocity = Vector3.ZERO
			enemy.steering = Vector3.ZERO
			enemy.think_timer = 0
		var pos = node.position
		enemy.cooldown -= delta
		if enemy.type == "support": enemy.heal_timer -= delta
		enemy.slow_time -= maxf(0, elapsed - float(enemy.get("slow_at", elapsed - delta)))
		enemy.slow_at = elapsed
		if enemy.slow_time <= 0: enemy.slow = 0.0
		if enemy.type == "boss" and enemy.health < enemy.max_health * 0.25:
			enemy.summon_timer -= delta
			if enemy.summon_timer <= 0:
				enemy.summon_timer = 10
				for i in 3: spawn_enemy("runner")
				ui.notify("Siege Titan / reinforcement pulse")
		enemy.think_timer -= delta
		if enemy.think_timer > 0 and not (enemy.ai == "attack" and enemy.cooldown <= 0):
			var cached_speed = enemy.speed * (1 - minf(0.9, enemy.slow))
			cached_speed /= world.movement_cost(world.cell(pos))
			node.velocity = enemy.steering * cached_speed
			node.velocity.y = -2
			if enemy.steering.length_squared() > 0.001 or not node.is_on_floor():
				var movement_start = Time.get_ticks_usec()
				move_enemy(node, delta)
				movement_us += Time.get_ticks_usec() - movement_start
			node.get_node("Model").position.y = sin(elapsed * enemy.speed * 4 + uid) * 0.035 if enemy.ai == "navigate" else 0
			enemy_index.move(uid, node.position)
			wounded_index.move(uid, node.position)
			visuals.enemy_renderer.sync(uid)
			continue
		enemy.think_timer = 0.1
		var target = objective_pos
		var target_kind = "core"
		var target_key = ""
		if enemy.type in ["runner", "exploder"]:
			var visible = pos.distance_squared_to(player.position) <= 441 and sight(pos + Vector3.UP, player.position + Vector3.UP)
			if EnemyBrain.wants_player_target(enemy, pos, player.position, visible):
				target = player.position
				target_kind = "player"
		if enemy.type in ["breaker", "saboteur"]:
			var hunt_key = EnemyBrain.structure_target(self, enemy, pos)
			if hunt_key != "":
				target = structure_position(hunt_key)
				target_kind = "structure"
				target_key = hunt_key
		var support_positions: Array = []
		if enemy.type == "support":
			for ally_uid in wounded_index.nearby(pos, 12, 8):
				if enemies.has(ally_uid) and ally_uid != uid: support_positions.append(enemies[ally_uid].node.position)
			if enemy.heal_timer <= 0:
				enemy.heal_timer = 2
				for ally_uid in wounded_index.nearby(pos, 8, 32):
					var ally = enemies[ally_uid]
					if ally.node.position.distance_squared_to(pos) < 64:
						ally.health = minf(ally.max_health, ally.health + 8)
						if ally.health >= ally.max_health: wounded_index.remove(ally_uid)
		var destination = target
		enemy.target_key = target_key
		var target_distance = pos.distance_to(target)
		var reach = float(enemy.range) + (1 if target_kind in ["core", "structure"] else 0)
		if enemy.type == "boss" and enemy.health < enemy.max_health * 0.5: reach = 14
		var can_see = target_distance > reach or EnemyBrain.attack_visible(self, enemy, pos, target, target_kind, target_key)
		# Visible nearby players can be pursued directly on continuous ground.
		# This avoids rebuilding a whole-world field for every player tile crossed.
		if (target_distance > reach or not can_see) and not (target_kind == "player" and world.complete_floor):
			var cell = world.cell(pos)
			var follows_road = target_kind == "core" and enemy.type not in ["runner", "exploder"]
			var next = world.next_cell(cell) if follows_road else world.next_toward(cell, world.cell(target))
			destination = world.position(next)
			var next_key = world.cell_key(next)
			if world.construction.has(next_key) and world.construction[next_key].kind != "trap":
				target_kind = "structure"
				target_key = next_key
				target = structure_position(next_key)
				target_distance = pos.distance_to(target)
				reach = maxf(2.8, float(enemy.range))
				can_see = target_distance > reach or EnemyBrain.attack_visible(self, enemy, pos, target, target_kind, target_key)
				var mount = world.mount_height(next, world.construction[next_key].id)
				if world.can_destroy(next) and (not can_see or (mount > 0 and float(enemy.range) < mount + 1.5)):
					target_kind = "tile"
					target = destination
					target_distance = pos.distance_to(target)
					reach = maxf(3, float(enemy.range))
					can_see = EnemyBrain.attack_visible(self, enemy, pos, target, target_kind, target_key)
			elif world.fixed_solid(next):
				var tile = world.map.layers.structure.get(next_key, {})
				if world.can_destroy(next):
					target_kind = "tile"
					target_key = next_key
					target = destination
					target_distance = pos.distance_to(destination)
					reach = 3
					can_see = target_distance > reach or EnemyBrain.attack_visible(self, enemy, pos, target, target_kind, target_key)
		if enemy.type in ["breaker", "saboteur"] and world.construction.has(target_key) and world.construction[target_key].kind != "wall" and enemy.get("hunt_key", "") != target_key:
			can_see = false
			destination = world.position(world.next_cell(world.cell(pos)))
		var follows_road = target_kind == "core" and enemy.type not in ["runner", "exploder"]
		if enemy.type == "support" and target_kind == "core" and target_distance > reach and not support_positions.is_empty():
			var anchor = EnemyBrain.support_anchor(world, pos, target, support_positions)
			if anchor.distance_squared_to(pos) < 4: destination = pos
			elif anchor != target:
				var current_cell = world.cell(pos)
				var best_anchor = pos.distance_squared_to(anchor)
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var candidate = current_cell + offset
					if world.solid(candidate) or world.map.layers.ground.get(world.cell_key(candidate), {}).get("type", "") != "road": continue
					var point = world.position(candidate)
					if point.distance_squared_to(anchor) < best_anchor:
						best_anchor = point.distance_squared_to(anchor)
						destination = point
		if target_distance > reach or not can_see:
			destination = EnemyBrain.movement_waypoint(enemy, world, pos, destination, target_kind, target_key, delta, follows_road)
		var direction = destination - pos
		direction.y = 0
		if direction.length_squared() > 0.01:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * 42))
		if target_distance <= reach and can_see:
			var attack_target = target_kind + ":" + target_key
			was_attacking = was_attacking and enemy.get("attack_target", "") == attack_target
			if not was_attacking and enemy.type in ["breaker", "saboteur"]: enemy.cooldown = maxf(enemy.cooldown, 0.65)
			if not was_attacking and enemy.type == "bombardier": enemy.cooldown = maxf(enemy.cooldown, float(enemy.warmup))
			enemy.attack_target = attack_target
			enemy.ai = "attack"
			enemy.steering = Vector3.ZERO
			node.velocity = Vector3(0, -2, 0)
			if enemy.type in ["breaker", "saboteur"] and enemy.cooldown > 0 and enemy.cooldown <= 0.65:
				visuals.beam(pos + Vector3.UP, target + Vector3.UP, Color("e7a276"), 0.025, 0.12)
			if enemy.type == "lancer" and enemy.cooldown > 0 and enemy.cooldown <= 0.6:
				visuals.beam(pos + Vector3.UP * 1.6, target + Vector3.UP, Color("e5b874"), 0.025, 0.16)
			if enemy.type == "bombardier" and enemy.cooldown > 0 and enemy.cooldown <= float(enemy.warmup):
				visuals.beam(pos + Vector3.UP * 1.6, target + Vector3.UP, Color("e5b874"), 0.04, 0.16)
			if enemy.cooldown <= 0:
				var interval = maxf(0.3, enemy.interval / minf(1.8, 1 + wave * 0.004))
				var strikes = 1 + (maxi(0, int(floor(-enemy.cooldown / interval))) if was_attacking else 0)
				enemy.cooldown = enemy.cooldown + interval * strikes if was_attacking else interval
				var attack_damage = enemy.damage * strikes
				if enemy.type == "exploder":
					explosion(pos + Vector3.UP, enemy.damage, 5, "enemy")
					damage_enemy(uid, 100000, "weapon")
					continue
				elif enemy.type == "bombardier":
					var origin = pos + Vector3.UP * 1.6
					var travel = clampf(origin.distance_to(target + Vector3.UP) / 12.0, 0.8, 1.8)
					var velocity = (target + Vector3.UP - origin) / travel + Vector3.UP * 0.5 * float(enemy.gravity) * travel
					launch(origin, velocity, attack_damage, float(enemy.splash), "enemy", Color(enemy.color), travel + 0.25, float(enemy.gravity))
				elif enemy.type in ["spitter", "lancer"] or (enemy.type == "boss" and enemy.health < enemy.max_health * 0.5):
					launch(pos + Vector3.UP * 1.6, (target + Vector3.UP - pos - Vector3.UP * 1.6).normalized() * (22 if enemy.type == "lancer" else 15), attack_damage, 0 if enemy.type == "lancer" else 1.8, "enemy", Color(enemy.color))
				elif target_kind == "player":
					if player.parry_timer > 0 and (pos - player.position).normalized().dot(-player.camera.global_basis.z) > 0.2:
						parry_reward(pos + Vector3.UP)
						damage_enemy(uid, enemy.damage * 1.5, "ability", player.position)
					else: damage_player(attack_damage)
				elif target_kind == "core": damage_core(attack_damage)
				elif target_kind == "structure": damage_structure(target_key, attack_damage)
				elif target_kind == "tile":
					var tile = world.map.layers.structure.get(target_key, {})
					var resistance = float(tile.get("resistance", world.WALL_DEFS[tile.type].resistance))
					tile.health -= attack_damage * (1 - resistance)
					if tile.health <= 0:
						world.remove_structure(target_key)
						visuals.remove_fixed(target_key)
				visuals.beam(pos + Vector3.UP, target + Vector3.UP, Color(enemy.color), 0.05, 0.12)
		else:
			enemy.ai = "navigate"
			var steering = direction.normalized()
			var separation = Vector3.ZERO
			var current = world.cell(pos)
			var crowd_start = Time.get_ticks_usec()
			for other_uid in enemy_index.nearby(pos, 1.5, 16):
				if other_uid == uid or not enemies.has(other_uid): continue
				var away = pos - enemies[other_uid].node.position
				away.y = 0
				var squared = away.length_squared()
				if squared < 1.6 and squared > 0.001:
					var distance = sqrt(squared)
					separation += away * ((1.2 - distance) * 0.7 / distance)
			steering += separation.limit_length(0.55)
			crowd_us += Time.get_ticks_usec() - crowd_start
			var speed = float(enemy.speed) * (1 - minf(0.9, enemy.slow))
			speed /= world.movement_cost(current)
			node.velocity = steering.limit_length(1) * speed
			enemy.steering = steering.limit_length(1)
			if target_kind == "core" and enemy.type not in ["runner", "exploder"]:
				var distance_to_waypoint = Vector2(destination.x - pos.x, destination.z - pos.z).length()
				node.velocity = node.velocity.limit_length(distance_to_waypoint / maxf(delta, 0.001))
			node.velocity.y = -2
		var movement_start = Time.get_ticks_usec()
		move_enemy(node, delta)
		movement_us += Time.get_ticks_usec() - movement_start
		var model = node.get_node("Model")
		model.position.y = sin(elapsed * enemy.speed * 4 + uid) * 0.035 if enemy.ai == "navigate" else 0
		enemy_index.move(uid, node.position)
		wounded_index.move(uid, node.position)
		visuals.enemy_renderer.sync(uid)
	simulation_phases.enemy_movement = movement_us / 1000.0
	simulation_phases.enemy_crowd = crowd_us / 1000.0
	var update_us = maxi(1, Time.get_ticks_usec() - update_start)
	if not work.is_empty(): enemy_batch = maxi(48, mini(population + 32, int(lerpf(enemy_batch, work.size() * 3500.0 / update_us, 0.15))))
	simulation_phases.enemy_updates = work.size()
	simulation_phases.enemy_step_ms = maximum_step * 1000.0

func intercept_projectile(key: String, tower: Dictionary, pos: Vector3) -> void:
	tower.cooldown = 0.1
	var radius = float(tower.range) * (1 + bonus("range") + bonus("tower_range"))
	var closest = radius * radius
	var target = -1
	var excluded: Array[RID] = []
	if visuals.structures.has(key): excluded.append(visuals.structures[key].get_rid())
	for i in projectiles.size():
		var projectile: Dictionary = projectiles[i]
		if projectile.source != "enemy": continue
		var distance = pos.distance_squared_to(projectile.pos)
		if distance > closest or not sight(pos, projectile.pos, excluded, true): continue
		closest = distance
		target = i
	if target < 0:
		tower.cooldown = 0.0 if projectiles.is_empty() else 0.1
		return
	var projectile: Dictionary = projectiles[target]
	var target_pos: Vector3 = projectile.pos
	visuals.beam(pos, target_pos, Color(tower.color), 0.055, 0.18)
	visuals.burst(target_pos, Color(tower.color), 5, 0.45)
	visuals.release_bolt(projectile.mesh)
	projectiles.remove_at(target)
	stats.interceptions = int(stats.get("interceptions", 0)) + 1
	tower.cooldown = maxf(0.08, float(tower.interval) / (1 + bonus("tower_rate")))
	if event_name == "Tower interference": tower.cooldown *= 1.7
	for support_key in world.construction:
		var support: Dictionary = world.construction[support_key]
		if support.kind == "support" and world.point(key).distance_to(world.point(support_key)) * 3 <= support.range:
			tower.cooldown *= 0.85
			break
	if visuals.structures.has(key):
		var head = visuals.structures[key].get_node_or_null("Head")
		if head and Vector2(target_pos.x, target_pos.z).distance_squared_to(Vector2(head.global_position.x, head.global_position.z)) > 0.01:
			head.set_meta("aim_lock", 0.8)
			head.look_at(Vector3(target_pos.x, head.global_position.y, target_pos.z))
	audio.cue("shot", pos, 0.1)

func update_towers(delta: float) -> void:
	for key in world.construction.keys():
		if not world.construction.has(key): continue
		var tower = world.construction[key]
		tower.cooldown = maxf(0, tower.cooldown - delta)
		if tower.cooldown > 0: continue
		var pos = structure_position(key) + Vector3.UP * 2.1
		if tower.id == "interceptor":
			intercept_projectile(key, tower, pos)
			continue
		if tower.kind == "repair" and repairs_allowed():
			tower.cooldown = 1
			for other_key in world.construction:
				var other = world.construction[other_key]
				if world.point(other_key).distance_to(world.point(key)) * 3 <= tower.range:
					other.health = minf(other.max_health, other.health + tower.damage)
			continue
		if tower.kind not in ["tower", "trap"]: continue
		var target = -1
		var best_score = -1e20
		var targeting_range = tower.range * (1 + bonus("range") + bonus("tower_range"))
		var exclude: Array[RID] = []
		if visuals.structures.has(key): exclude.append(visuals.structures[key].get_rid())
		for uid in enemy_index.nearby(pos, targeting_range):
			var enemy = enemies[uid]
			var ep = enemy.node.position + Vector3.UP
			var distance = pos.distance_to(ep)
			if distance > targeting_range: continue
			var score = -distance
			match int(tower.target_mode):
				1: score = enemy.max_health
				2: score = -enemy.max_health
				3: score = -float(world.flow.get(world.cell_key(world.cell(enemy.node.position)), 9999))
				4: score = float(world.flow.get(world.cell_key(world.cell(enemy.node.position)), 9999))
				5: score = -enemy.health
				6: score = enemy.damage * enemy.speed
			if score > best_score:
				if tower.id != "mortar" and not sight(pos, ep, exclude, true): continue
				best_score = score
				target = uid
		if target < 0:
			tower.cooldown = 0.1
			continue
		var target_pos = enemies[target].node.position + Vector3.UP
		audio.cue("shot", pos, 0.1)
		var amount = float(tower.damage) * (1 + bonus("tower_damage"))
		var interval = maxf(0.08, float(tower.interval) / (1 + bonus("tower_rate")))
		if event_name == "Tower interference": interval *= 1.7
		for support_key in world.construction:
			var support = world.construction[support_key]
			if support.kind == "support" and world.point(key).distance_to(world.point(support_key)) * 3 <= support.range:
				amount *= 1.2
				interval *= 0.85
				break
		tower.cooldown = interval
		if tower.id == "laser":
			tower.focus = minf(1.0, tower.focus + 0.15) if tower.last_target == target else 0.0
			amount *= 1 + tower.focus
		tower.last_target = target
		if tower.slow > 0:
			enemies[target].slow = maxf(enemies[target].slow, tower.slow)
			enemies[target].slow_time = 2.0
			enemies[target].slow_at = elapsed
		if tower.id == "flame":
			if not advance_enemy_dots(target): continue
			if enemies[target].burn <= 8:
				enemies[target].burn = 8.0
				enemies[target].burn_source = "tower"
			enemies[target].burn_time = 3
			enemies[target].burn_at = elapsed
		if tower.id == "mortar":
			var travel_time = maxf(0.5, pos.distance_to(target_pos) / 18)
			var velocity = (target_pos - pos) / travel_time + Vector3.UP * 0.5 * 16 * travel_time
			launch(pos, velocity, amount, tower.splash, "tower", Color(tower.color), travel_time + 0.2, 16)
		elif tower.id == "rocket":
			var distance = pos.distance_to(target_pos)
			launch(pos, (target_pos - pos).normalized() * 28, amount, tower.splash, "tower", Color(tower.color), distance / 28 + 0.2)
		elif tower.id == "tesla":
			var previous = target_pos
			var struck: Array = [target]
			damage_enemy(target, amount, "tower", pos)
			for i in 3:
				var closest = -1
				var distance = 5.0
				for uid in enemy_index.nearby(previous, 5):
					var ep = enemies[uid].node.position + Vector3.UP
					if uid not in struck and ep.distance_to(previous) < distance and sight(previous, ep, [], true):
						closest = uid
						distance = ep.distance_to(previous)
				if closest < 0: break
				var ep = enemies[closest].node.position + Vector3.UP
				visuals.beam(previous, ep, Color(tower.color), 0.055, 0.15)
				struck.append(closest)
				previous = ep
				damage_enemy(closest, amount * 0.65, "tower", pos)
		elif tower.splash > 0:
			explosion(target_pos, amount, tower.splash, "tower")
			if tower.slow > 0:
				for uid in enemy_index.nearby(target_pos, tower.splash):
					var enemy = enemies[uid]
					if enemy.node.position.distance_to(target_pos) < tower.splash:
						enemy.slow = maxf(enemy.slow, tower.slow)
						enemy.slow_time = 2
						enemy.slow_at = elapsed
		else:
			damage_enemy(target, amount, "tower", pos)
		if tower.get("branch_id", "") == "resonant":
			for uid in enemy_index.nearby(target_pos, 6):
				if uid != target and (enemies[uid].node.position + Vector3.UP).distance_to(target_pos) < 6 and sight(target_pos, enemies[uid].node.position + Vector3.UP, [], true):
					visuals.beam(target_pos, enemies[uid].node.position + Vector3.UP, Color("cb9df1"))
					damage_enemy(uid, amount * 0.35, "tower", pos)
					break
		if tower.id == "rail":
			var aim = (target_pos - pos).normalized()
			for uid in enemy_index.nearby(pos, tower.range):
				if uid == target: continue
				var diff = enemies[uid].node.position + Vector3.UP - pos
				var along = diff.dot(aim)
				if along > 0 and along < tower.range and (diff - aim * along).length() < 0.8 and sight(pos, pos + diff, [visuals.structures[key].get_rid()], true):
					damage_enemy(uid, amount * 0.65, "tower", pos)
		if tower.id == "mine":
			world.construction.erase(key)
			visuals.structure(key)
		else:
			visuals.beam(pos, target_pos, Color(tower.color), 0.045, 0.15)
			if visuals.structures.has(key):
				var head = visuals.structures[key].get_node_or_null("Head")
				if head and head.global_position.distance_squared_to(target_pos) > 0.01:
					head.set_meta("aim_lock", 0.8)
					head.look_at(Vector3(target_pos.x, head.global_position.y, target_pos.z))

func update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p = projectiles[i]
		var end = p.pos + p.velocity * delta - Vector3.UP * 0.5 * p.gravity * delta * delta
		p.velocity.y -= p.gravity * delta
		var hit = ray(p.pos, end, 5 if p.source == "enemy" else 3, [], p.source == "tower")
		p.life -= delta
		if not hit.is_empty() or p.life <= 0:
			var impact = hit.position if not hit.is_empty() else end
			if p.splash > 0:
				explosion(impact, p.damage, p.splash, p.source, p.effects)
			elif not hit.is_empty():
				hit_body(hit.collider, p.damage, p.source, p.pos, p.effects)
			if state != "wave": return
			visuals.release_bolt(p.mesh)
			projectiles.remove_at(i)
		else:
			p.pos = end
			p.mesh.position = end
			if p.velocity.length_squared() > 0.01:
				p.mesh.look_at(end + p.velocity, Vector3.RIGHT if absf(p.velocity.normalized().y) > 0.99 else Vector3.UP)

func clear_projectiles() -> void:
	for projectile in projectiles:
		visuals.release_bolt(projectile.mesh)
	projectiles.clear()

func update_hazards() -> void:
	if (event_name == "Acid rain" or challenge("acid_rain")) and not world.map.layers.height.has(world.cell_key(world.cell(player.position))): damage_player(2 * world.rule("hazard_damage"), true)
	for key in world.map.layers.objects.keys():
		var tile = world.map.layers.objects[key]
		if tile.type not in world.HAZARDS: continue
		var pos = world.position(world.point(key), float(tile.get("elevation", 0)))
		var affected = false
		if player.position.distance_to(pos) < 1.8:
			if tile.type != "slow": damage_player((8 if tile.type != "mine" else 45) * world.rule("hazard_damage"), true)
			affected = true
		for uid in enemy_index.nearby(pos, 1.8):
			if not enemies.has(uid): continue
			var enemy = enemies[uid]
			if enemy.node.position.distance_to(pos) < 1.8:
				if tile.type == "slow": enemy.slow = 0.5; enemy.slow_time = 1; enemy.slow_at = elapsed
				else: damage_enemy(uid, (10 if tile.type != "mine" else 95) * world.rule("hazard_damage"), "tower", pos)
				affected = true
		if tile.type == "mine" and affected:
			world.map.layers.objects.erase(key)
			visuals.burst(pos, Color("ffad69"), 12, 3)

func save_run() -> bool:
	var phase = previous_state if state == "paused" else state
	if not eligible or phase not in ["preparation", "wave"] or state not in ["preparation", "wave", "paused"]:
		ui.notify("Save an active standard run or a preparation checkpoint.")
		return false
	var record = {"version": 2, "id": run_id, "mode": mode, "world": world.map, "construction": world.construction, "applied": world.applied, "wave": wave, "completed": completed, "scrap": scrap, "health": health, "max_health": max_health, "shield": shield, "core": core_health, "max_core": max_core, "stats": stats, "bonuses": bonuses, "weapons": weapons, "backpack": backpack, "consumables": consumables, "active": active_weapon, "elapsed": elapsed, "position": [player.position.x, player.position.y, player.position.z], "yaw": player.rotation.y, "pitch": player.pitch, "rng": str(rng.state), "level": level, "xp": xp, "next_xp": next_xp, "reward_pending": reward_pending, "upgrades": upgrades, "capacity": capacity}
	record.upgrade_picks = upgrade_picks
	record.operator_growth = true
	record.fortified_structures = true
	record.pending_levels = pending_levels
	record.phase = phase
	if phase == "wave": record.combat = CombatSave.snapshot(self)
	record.drops = []
	for drop in drops: record.drops.append({"item": drop.item, "position": [drop.pos.x, drop.pos.y, drop.pos.z]})
	record.timers = [fire_timer, reload_timer, ability_timer, hurt_timer]
	record.extended = {"core_shield": core_shield, "restoration_timer": restoration_timer, "adaptive": adaptive_run, "stamina": player.stamina, "perks": run_perks}
	record.extended.velocity = CombatSave.vector(player.velocity)
	record.extended.crouched = player.crouched
	record.extended.exhausted = player.sprint_exhausted
	record.extended.movement = player.movement_snapshot()
	record.extended.challenges = active_challenges
	record.extended.research = run_research
	record.extended.field_repair_delay = maxf(0, field_repair_ready_at - elapsed)
	record.contract_choice = contract_choice
	record.wave_contract = wave_contract
	record.supply_cache = supply_cache
	if not valid_run(record):
		ui.notify("Run checkpoint failed validation. The previous save is preserved.")
		return false
	var result = write_json("user://run.json", record)
	resume_available = result or read_run_checkpoint() != null
	if not result: ui.notify("Cannot save run. Existing save preserved.")
	return result

func write_json(path: String, value: Dictionary) -> bool:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		var old = JSON.parse_string(FileAccess.get_file_as_string(path))
		var valid_old = valid_run(old) if path == "user://run.json" else world.validate(old, false).is_empty()
		if valid_old and DirAccess.copy_absolute(path, path + ".bak") != OK: return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func read_run_checkpoint() -> Variant:
	for path in ["user://run.json", "user://run.json.bak"]:
		if FileAccess.file_exists(path):
			var value = JSON.parse_string(FileAccess.get_file_as_string(path))
			if valid_run(value):
				return value
	return null

func load_run() -> void:
	var record: Variant = read_run_checkpoint()
	if record == null:
		ui.notify("No valid unfinished run found; saved files preserved.")
		return
	var r: Dictionary = record
	start_run(r.mode, {}, true)
	world.load_map(r.world)
	world.construction = r.construction
	if not r.get("fortified_structures", false):
		for item in world.construction.values():
			var branch_id = str(item.get("branch_id", ""))
			if branch_id == "":
				for id in catalog.structure_upgrades:
					if item.branch == catalog.structure_upgrades[id].name: branch_id = id
			var multiplier = float(catalog.structure_upgrades.get(branch_id, {"health": 1.3}).health)
			var fortified_health = float(catalog.structures[item.id].health) * pow(multiplier, maxi(0, int(item.level) - 1))
			if fortified_health > item.max_health:
				item.health = fortified_health * clampf(float(item.health) / maxf(1, item.max_health), 0, 1)
				item.max_health = fortified_health
	for item in world.construction.values(): item.cooldown = maxf(0, float(item.cooldown))
	world.applied = r.applied
	world.rebuild_flow()
	run_id = r.id
	wave = int(r.wave)
	completed = int(r.completed)
	scrap = int(r.scrap)
	health = float(r.health)
	max_health = float(r.max_health)
	shield = float(r.shield)
	core_health = float(r.core)
	max_core = float(r.max_core)
	stats = r.stats
	contract_choice = r.get("contract_choice", "")
	wave_contract = r.get("wave_contract", {}).duplicate(true)
	supply_cache = r.get("supply_cache", []).duplicate(true)
	for key in ["explosive_damage", "elemental_damage", "close_damage", "core_damage_taken", "loot_collected"]:
		if not stats.has(key): stats[key] = 0
	if not stats.has("weapon_usage"): stats.weapon_usage = {}
	stats.mode = mode
	bonuses = r.bonuses
	weapons = r.weapons
	backpack = r.backpack
	consumables = r.consumables
	active_weapon = clampi(int(r.active), 0, 1)
	elapsed = float(r.elapsed)
	player.position = Vector3(r.position[0], r.position[1], r.position[2])
	player.rotation.y = r.yaw
	player.pitch = r.pitch
	player.camera.rotation.x = player.pitch
	seed_value = int(r.world.seed)
	rng.seed = seed_value
	rng.state = int(r.rng)
	level = int(r.level)
	if not r.get("operator_growth", false):
		var earned_health = mini(30, maxi(0, level - 1)) * 6
		max_health += earned_health
		health += earned_health
	xp = int(r.xp)
	next_xp = int(r.next_xp)
	pending_levels = int(r.get("pending_levels", 0))
	reward_pending = r.reward_pending
	upgrades = r.upgrades
	upgrade_picks = int(r.get("upgrade_picks", 1 if reward_pending else 0))
	capacity = int(r.capacity)
	var timers = r.get("timers", [0, 0, 0, 0])
	fire_timer = float(timers[0])
	reload_timer = float(timers[1])
	ability_timer = float(timers[2])
	hurt_timer = float(timers[3])
	var extended = r.get("extended", {})
	field_repair_ready_at = elapsed + float(extended.get("field_repair_delay", 0.0))
	core_shield = float(extended.get("core_shield", bonus("core_shield")))
	restoration_timer = float(extended.get("restoration_timer", 0))
	adaptive_run = bool(extended.get("adaptive", true))
	run_perks = extended.get("perks", {}).duplicate()
	run_research = extended.get("research", profile.data.research).duplicate()
	active_challenges = extended.get("challenges", {"frail": true, "fast": true, "no_repair": true} if mode == "challenge" else {}).duplicate()
	player.stamina = float(extended.get("stamina", 100))
	player.velocity = CombatSave.unpack(extended.get("velocity", [0, 0, 0]))
	player.crouched = extended.get("crouched", false)
	player.sprint_exhausted = extended.get("exhausted", false)
	player.restore_movement(extended.get("movement", {}))
	player.body_shape.shape.height = 1.1 if player.crouched else 1.8
	player.body_shape.position.y = 0.55 if player.crouched else 0.9
	player.camera.position.y = 1.0 if player.crouched else 1.65
	for drop in r.get("drops", []): place_drop(drop.item, Vector3(drop.position[0], drop.position[1], drop.position[2]))
	visuals.rebuild()
	player.refresh_gun()
	if r.get("phase", "preparation") == "wave":
		CombatSave.restore(self, r.combat)
		event_name = upcoming_event(wave)
		visuals.set_weather("Acid rain" if challenge("acid_rain") else event_name, wave)
		previous_state = "wave"
		state = "paused"
		ui.show_pause()
		ui.notify("Wave %d restored and paused. Resume when ready." % wave)
	else:
		if reward_pending: ui.show_upgrades()
		ui.notify("Run restored at preparation for wave %d." % (wave + 1))

func valid_run(value: Variant) -> bool:
	if not value is Dictionary or (value.get("version") != 1 and value.get("version") != 2): return false
	if value.has("operator_growth") and not value.operator_growth is bool: return false
	if value.has("fortified_structures") and not value.fortified_structures is bool: return false
	for key in ["world", "construction", "stats", "bonuses", "consumables"]:
		if not value.get(key) is Dictionary: return false
	for key in ["weapons", "backpack", "applied", "position", "upgrades"]:
		if not value.get(key) is Array: return false
	if not value.get("id") is String or not value.get("mode") is String or not value.get("rng") is String or not value.rng.is_valid_int(): return false
	if value.id in profile.data.awarded or not Rules.MODES.has(value.mode) or value.mode == "sandbox": return false
	if not value.get("extended", {}) is Dictionary: return false
	var extended = value.get("extended", {})
	if not extended.get("movement", {}) is Dictionary: return false
	var movement = extended.get("movement", {})
	var limits = {"energy": 3.0, "dash": 0.16, "coyote": 0.1, "jump": 0.12, "slam_jump": 0.18, "walls": 3.0, "hook_cooldown": 0.4, "punch": 0.55, "parry": 0.16}
	for key in limits:
		if movement.has(key) and not profile.numeric(movement[key], 0, limits[key]): return false
	if movement.has("walls") and movement.walls != int(movement.walls): return false
	for key in ["slide", "slam", "hook"]:
		if movement.has(key) and not movement[key] is bool: return false
	if movement.has("direction") and not CombatSave.valid_vector(self, movement.direction, 1): return false
	if movement.has("anchor") and not CombatSave.valid_vector(self, movement.anchor): return false
	if movement.has("target") and (not profile.numeric(movement.target, -1, 1e12) or movement.target != int(movement.target)): return false
	if not extended.get("research", {}) is Dictionary: return false
	for id in extended.get("research", {}):
		var nodes = catalog.technologies.filter(func(node): return node.id == id)
		if nodes.is_empty() or not profile.numeric(extended.research[id], 0, nodes[0].max_rank): return false
	for key in ["core_shield", "restoration_timer", "stamina"]:
		if extended.has(key) and not profile.numeric(extended[key], 0, 1000000): return false
	if extended.has("field_repair_delay") and not profile.numeric(extended.field_repair_delay, 0, 2.5): return false
	if extended.has("adaptive") and not extended.adaptive is bool: return false
	if extended.has("velocity") and not CombatSave.valid_vector(self, extended.velocity): return false
	for key in ["crouched", "exhausted"]:
		if extended.has(key) and not extended[key] is bool: return false
	if not extended.get("challenges", {}) is Dictionary: return false
	for id in extended.get("challenges", {}):
		if not Rules.CHALLENGES.has(id) or not extended.challenges[id] is bool: return false
	if not extended.get("perks", {}) is Dictionary: return false
	for key in extended.get("perks", {}):
		if not profile.ASCENSION_PERKS.has(key) or not profile.numeric(extended.perks[key], 0, profile.ASCENSION_PERKS[key].max_rank): return false
	for key in ["explosive_damage", "elemental_damage", "close_damage", "core_damage_taken", "loot_collected", "parries", "interceptions"]:
		if value.stats.has(key) and not profile.numeric(value.stats[key], 0, 1e15): return false
	for key in ["challenge_weight", "cleared", "reward_wave"]:
		if value.stats.has(key) and not profile.numeric(value.stats[key], 0, 1e12): return false
	if value.stats.has("weapon_usage"):
		if not value.stats.weapon_usage is Dictionary: return false
		for key in value.stats.weapon_usage:
			if not catalog.weapons.has(key) or not profile.numeric(value.stats.weapon_usage[key], 0, 1e15): return false
	if not value.get("reward_pending") is bool: return false
	var pending_picks = value.get("upgrade_picks", 1 if value.reward_pending else 0)
	var saved_levels = value.get("pending_levels", 0)
	if not profile.numeric(saved_levels, 0, 1e6) or saved_levels != int(saved_levels): return false
	if not profile.numeric(pending_picks, 0, 1000000) or pending_picks != int(pending_picks): return false
	if not valid_contract_save(value): return false
	if value.reward_pending != (pending_picks > 0 or not value.get("supply_cache", []).is_empty()): return false
	if not value.get("timers", []) is Array or value.get("timers", [0, 0, 0, 0]).size() != 4: return false
	for timer in value.get("timers", [0, 0, 0, 0]):
		if not profile.numeric(timer, 0, 3600): return false
	for key in ["wave", "completed", "scrap", "health", "max_health", "shield", "core", "max_core", "active", "elapsed", "level", "xp", "next_xp", "capacity"]:
		if not profile.numeric(value.get(key), 0, 1e12): return false
	for key in ["yaw", "pitch"]:
		if not profile.numeric(value.get(key), -1000000, 1000000): return false
	if value.weapons.size() != 2 or value.position.size() != 3 or value.capacity < 20 or value.capacity > 100 or value.backpack.size() > value.capacity: return false
	if value.active > 1 or value.health <= 0 or value.core <= 0: return false
	var phase = value.get("phase", "preparation")
	if phase not in ["preparation", "wave"]: return false
	if phase == "preparation" and value.completed != value.wave: return false
	if phase == "wave" and (value.completed + 1 != value.wave or value.reward_pending or not CombatSave.valid(self, value.get("combat"))): return false
	if not world.validate(value.world).is_empty(): return false
	var saved_world = World.new()
	saved_world.load_map(value.world)
	saved_world.applied = value.applied
	for number in value.position:
		if not profile.numeric(number, -10, 1000): return false
	for key in ["medkit", "grenade"]:
		if not profile.numeric(value.consumables.get(key), 0, 9999): return false
	for key in value.bonuses:
		if not key is String or not profile.numeric(value.bonuses[key], 0, 1e9): return false
	for key in ["wave", "kills", "bosses", "damage", "weapon_damage", "tower_damage", "built", "earned", "spent", "streak", "difficulty"]:
		if not profile.numeric(value.stats.get(key), 0, 1e15): return false
	for item in value.weapons:
		if not valid_item(item, true) or (item.id != "" and not catalog.weapons.has(item.id)): return false
	for item in value.backpack:
		if not valid_item(item): return false
	if not value.get("drops", []) is Array or value.get("drops", []).size() > 80: return false
	for drop in value.get("drops", []):
		if not drop is Dictionary or not valid_item(drop.get("item"), false, true) or not drop.get("position") is Array or drop.position.size() != 3: return false
		for number in drop.position:
			if not profile.numeric(number, -10, 1000): return false
	for key in value.construction:
		if not key is String or key.split(",").size() != 2: return false
		if not key.split(",")[0].is_valid_int() or not key.split(",")[1].is_valid_int(): return false
		var item = value.construction[key]
		if not item is Dictionary or not catalog.structures.has(item.get("id", "")): return false
		var saved_point = saved_world.point(key)
		var placement_reason = saved_world.placement(saved_point, item.id)
		if placement_reason != "":
			var legacy_site = key in value.world.build and not saved_world.fixed_solid(saved_point) and not value.world.layers.objects.has(key) and not value.world.layers.markers.has(key)
			if not legacy_site: return false
		for field in ["health", "max_health", "level", "target_mode", "invested", "focus", "damage", "interval", "range", "splash", "slow", "cost"]:
			if not profile.numeric(item.get(field), 0, 1e12): return false
		if not profile.numeric(item.get("cooldown"), -1e12, 1e12): return false
		if item.get("kind") != catalog.structures[item.id].kind or not item.get("color") is String or not item.get("name") is String or not item.get("branch") is String: return false
		if item.has("rotation") and not profile.numeric(item.rotation, 0, 359): return false
		if item.has("branch_id") and item.branch_id not in ["", "power", "rapid", "resonant"]: return false
		if not profile.numeric(item.get("last_target"), -1, 1e12) or item.target_mode >= TARGET_MODES.size(): return false
	for id in value.applied:
		if not id is String: return false
	for item in value.upgrades:
		if not item is Dictionary or not item.get("name") is String or not item.get("description") is String or not item.get("effect") is String or not profile.numeric(item.get("value"), 0, 1000): return false
		if item.has("cap") and not profile.numeric(item.cap, 0, 1000): return false
	return pending_picks <= 0 or value.upgrades.size() in [1, 2, 3]

func valid_contract_save(value: Dictionary) -> bool:
	var choice: Variant = value.get("contract_choice", "")
	if not choice is String or (choice != "" and not CONTRACTS.has(choice)): return false
	var contract: Variant = value.get("wave_contract", {})
	var cache: Variant = value.get("supply_cache", [])
	if not contract is Dictionary or not cache is Array: return false
	if not contract.is_empty():
		if not contract.get("id") is String or not CONTRACTS.has(contract.id): return false
		if contract.get("status") not in ["active", "complete", "failed"]: return false
		if not profile.numeric(contract.get("wave"), 1, 1e12) or contract.wave != value.get("wave"): return false
		if not profile.numeric(contract.get("baseline"), 0, 1e15): return false
		if not profile.numeric(contract.get("target"), 0, 5000) or contract.target != contract_target(contract.id, int(contract.wave)): return false
		if contract.status == "active" and value.get("phase", "preparation") != "wave": return false
		if contract.status != "active" and value.get("phase", "preparation") != "preparation": return false
	if not cache.is_empty():
		if contract.is_empty() or contract.get("status") != "complete" or cache.size() != 3: return false
		for item in cache:
			if not valid_item(item) or item.id not in ["ammo_cell", "trauma_kit", "repair_kit", "shield_pack"]: return false
	return true

func valid_item(item: Variant, allow_empty: bool = false, allow_consumables: bool = false) -> bool:
	if not item is Dictionary or not item.get("id") is String or not profile.numeric(item.get("rarity"), 0, 4): return false
	if item.rarity != int(item.rarity): return false
	if catalog.weapons.has(item.id) or (item.id == "" and allow_empty):
		var definition = catalog.weapons.get(item.id, {})
		if definition.get("tech", "") != "" and profile.rank(definition.tech) == 0: return false
		for key in ["ammo", "reserve", "roll"]:
			if not profile.numeric(item.get(key), 0, 100000): return false
		if item.get("attachment", "") not in ["", "barrel", "optic"] or not item.get("attachments", {}) is Dictionary or not item.get("mods", []) is Array or item.get("mods", []).size() > 3: return false
		for slot in item.get("attachments", {}):
			var module_id: Variant = item.attachments[slot]
			if not module_id is String or not catalog.attachments.has(module_id): return false
			if catalog.attachments[module_id].slot != slot or not attachment_compatible(module_id, item): return false
		if not item.get("attachment_rarities", {}) is Dictionary: return false
		for slot in item.get("attachment_rarities", {}):
			if not item.get("attachments", {}).has(slot) or not profile.numeric(item.attachment_rarities[slot], 0, 4) or item.attachment_rarities[slot] != int(item.attachment_rarities[slot]): return false
		for modifier in item.get("mods", []):
			if modifier not in ["stabilized", "overclocked", "incendiary", "frost", "vampiric", "volatile", "ricochet"]: return false
		return true
	return catalog.attachments.has(item.id) or catalog.equipment.has(item.id) or (allow_consumables and item.id in ["medkit", "grenade"] and profile.numeric(item.get("count", 1), 1, 99))

func remove_run_save() -> void:
	for path in ["user://run.json", "user://run.json.bak"]:
		if not FileAccess.file_exists(path): continue
		var record = JSON.parse_string(FileAccess.get_file_as_string(path))
		if record is Dictionary and record.get("id") == run_id: DirAccess.remove_absolute(path)
	resume_available = read_run_checkpoint() != null

func render_times() -> Dictionary:
	var viewport = get_viewport().get_viewport_rid()
	return {"cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport), "gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport)}

func benchmark_setup() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var cells: Array = []
	for key in world.map.build:
		var p = world.point(key)
		if placement(p, "sentry") == "" and p != world.cell(player.position) and p != Vector2i(12, 10): cells.append(p)
	cells.sort_custom(func(a, b): return a.distance_squared_to(world.marker("objective")) < b.distance_squared_to(world.marker("objective")))
	for p in cells.slice(0, 8):
		var result = build(p, "sentry")
		print("BENCHMARK build ", p, " ", "OK" if result == "" else result)
	print("BENCHMARK fixed tile rejection: ", build(Vector2i(12, 12), "wall"))
	player.position = world.position(Vector2i(12, 10), 0.1)
	player.rotation.y = 0
	if benchmark_content:
		world.construction.clear()
		var ids = catalog.structures.keys()
		for i in mini(ids.size(), cells.size()): print("BENCHMARK content ", ids[i], " ", build(cells[i], ids[i]))
		wave = 9
		completed = 9
		world.evolve(9)
		visuals.rebuild()
		max_core = 6000
		core_health = max_core
	if benchmark_stress:
		max_core = 1000000000
		core_health = max_core
		max_health = 1000000000
		health = max_health
		wave = 49
		completed = 49
		world.evolve(49)
		visuals.rebuild()
		start_wave()
		benchmark_enemy_pool = catalog.enemies.keys().filter(func(id): return id != "boss" and int(catalog.enemies[id].min_wave) <= wave)
		for i in mini(64, benchmark_population): spawn_enemy(benchmark_enemy_pool[i % benchmark_enemy_pool.size()])
		if benchmark_horde > 0:
			spawn_queue.clear()
			spawn_reserve = {"grunt": benchmark_horde}
	print("BENCHMARK initialized engine=", Engine.get_version_info().string)

func _process(delta: float) -> void:
	if not autoplay or benchmark_time < 2 or quitting: return
	var milliseconds = mini(1000, int(ceil(delta * 1000.0)))
	benchmark_frame_bins[milliseconds] = int(benchmark_frame_bins.get(milliseconds, 0)) + 1
	benchmark_frames += 1
	benchmark_frame_seconds += delta
	benchmark_worst_frame = maxf(benchmark_worst_frame, delta * 1000.0)
	if delta > 0.033 and benchmark_slow_frames < 12:
		benchmark_slow_frames += 1
		print("BENCHMARK SLOW ", JSON.stringify({"seconds": benchmark_time, "frame_ms": delta * 1000.0, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "benchmark_ms": benchmark_update_ms, "collision_pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), "simulation_ms": simulation_ms, "phases": simulation_phases, "render": render_times(), "projectiles": projectiles.size(), "enemies": enemies.size()}))

func benchmark_frame_summary() -> Dictionary:
	var result = {"frames": benchmark_frames, "average_fps": benchmark_frames / maxf(0.001, benchmark_frame_seconds), "worst_ms": benchmark_worst_frame, "warmup_seconds": 2}
	var bins = benchmark_frame_bins.keys()
	bins.sort()
	var cumulative = 0
	var slow_frames = 0
	for milliseconds in bins:
		cumulative += int(benchmark_frame_bins[milliseconds])
		if milliseconds > 33: slow_frames += int(benchmark_frame_bins[milliseconds])
		if not result.has("p95_ms") and cumulative >= ceili(benchmark_frames * 0.95): result.p95_ms = milliseconds
		if not result.has("p99_ms") and cumulative >= ceili(benchmark_frames * 0.99): result.p99_ms = milliseconds
	result.over_33ms_percent = slow_frames * 100.0 / maxi(1, benchmark_frames)
	return result

func benchmark_update(delta: float) -> void:
	if quitting: return
	benchmark_time += delta
	if benchmark_time > benchmark_duration or (state == "results" and benchmark_time > 10):
		print("BENCHMARK FRAMES ", JSON.stringify(benchmark_frame_summary()))
		var coverage = {"updated_enemies": 0, "oldest_update_ms": 0.0, "render_batches": visuals.enemy_renderer.groups.size()}
		for enemy in enemies.values():
			if enemy.get("simulation_ticks", 0) > 0: coverage.updated_enemies += 1
			coverage.oldest_update_ms = maxf(coverage.oldest_update_ms, (elapsed - float(enemy.get("simulated_at", elapsed))) * 1000.0)
		print("BENCHMARK COVERAGE ", JSON.stringify(coverage))
		print("BENCHMARK FINAL ", JSON.stringify({"seconds": elapsed, "completed": completed, "stats": stats, "enemies": enemies.size(), "fps": Engine.get_frames_per_second(), "simulation_ms": simulation_ms, "peak_simulation_ms": peak_simulation_ms, "nav_ms": world.nav_ms, "memory": OS.get_static_memory_usage(), "resolution": str(DisplayServer.window_get_size()), "samples": benchmark_stats}))
		for enemy in enemies.values().slice(0, 10): print("BENCHMARK survivor ", enemy.type, " hp=", enemy.health, " position=", enemy.node.position, " cell=", world.cell(enemy.node.position), " next=", world.next_cell(world.cell(enemy.node.position)), " ai=", enemy.ai)
		quit_game()
		return
	if int(benchmark_time / 10) > benchmark_stats.size():
		benchmark_stats.append({"seconds": benchmark_time, "enemies": enemies.size(), "fps": Engine.get_frames_per_second(), "sim_ms": simulation_ms, "memory": OS.get_static_memory_usage(), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)})
		benchmark_stats[-1].render = render_times()
		benchmark_stats[-1].phases = simulation_phases.duplicate()
		benchmark_stats[-1].physics_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		benchmark_stats[-1].benchmark_ms = benchmark_update_ms
		benchmark_stats[-1].collision_pairs = Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
		benchmark_stats[-1].queued = queued_enemies()
		benchmark_stats[-1].spawn_buffer = spawn_queue.size()
	if benchmark_content and state == "wave":
		var id = catalog.weapons.keys()[mini(catalog.weapons.size() - 1, int(benchmark_time / 20))]
		if id != benchmark_weapon:
			benchmark_weapon = id
			weapons[0] = make_weapon(id, 3)
			active_weapon = 0
			reload_timer = 0
			player.refresh_gun()
			print("BENCHMARK weapon ", id)
	if benchmark_stress and state == "wave" and enemies.size() < benchmark_population:
		var spawn_start = Time.get_ticks_usec()
		for i in mini(64, benchmark_population - enemies.size()):
			spawn_enemy(benchmark_enemy_pool[next_uid % benchmark_enemy_pool.size()])
			if Time.get_ticks_usec() - spawn_start > 2000: break
	if state == "preparation":
		if reward_pending:
			if not supply_cache.is_empty(): claim_supply(-1)
			choose_upgrade(0)
		if eligible:
			for p in [Vector2i(11, 3), Vector2i(13, 3), Vector2i(11, 5), Vector2i(13, 5), Vector2i(11, 8), Vector2i(13, 8), Vector2i(10, 11), Vector2i(14, 11)]:
				if not world.construction.has(world.cell_key(p)) and scrap >= 80: build(p, "sentry")
		if completed > benchmark_stage:
			benchmark_stage = completed
			print("BENCHMARK wave cleared=", completed, " core=", core_health, " kills=", stats.kills, " evolved=", world.applied)
		start_wave()
	elif state == "wave":
		if fire_timer <= 0 and reload_timer <= 0:
			var nearest = -1
			var distance = 40.0
			var population = enemy_index.ids.size()
			for i in mini(64, population):
				benchmark_aim_cursor = posmod(benchmark_aim_cursor, population)
				var uid = enemy_index.ids[benchmark_aim_cursor]
				benchmark_aim_cursor += 1
				var target = enemies[uid].node.position + Vector3.UP * 1.3
				var d = player.camera.global_position.distance_to(target)
				if d < distance and sight(player.camera.global_position, target):
					distance = d
					nearest = uid
			if nearest >= 0:
				fire(enemies[nearest].node.position + Vector3.UP * 1.3 - player.camera.global_position)
		if health < 40: consume("medkit")

func capture_screen(target: String) -> void:
	match target:
		"menu": ui.show_menu()
		"continue": load_run()
		"research": ui.show_research()
		"ascension": ui.show_ascension()
		"credits": ui.show_credits()
		"editor": ui.editor.open()
		"editor-properties": ui.editor.layer = "structure"; ui.editor.open(); ui.editor.inspect(Vector2i(7, 6))
		"editor-rules": ui.editor.open(); ui.editor.world_rules_dialog()
		"editor-events": ui.editor.open(); ui.editor.evolution_events_dialog()
		"editor-event-edit":
			ui.editor.open()
			ui.editor.evolution_events_dialog()
			ui.editor.evolution_event_form(0, ui.root.get_children()[-1])
		"editor-new": ui.editor.open(); ui.editor.new_map_dialog()
		"editor-metadata": ui.editor.open(); ui.editor.metadata_dialog()
		"editor-generate": ui.editor.open(); ui.editor.generated_map_dialog()
		"editor-templates": ui.editor.open(); ui.editor.templates_dialog()
		"editor-share": ui.editor.open(); ui.editor.share_dialog()
		"settings": ui.show_settings()
		"selection": ui.show_selection()
		"challenge-rules": ui.show_selection(); ui.show_challenge_rules()
		"weather", "retro", "contrast", "lighting":
			start_run("sandbox")
			profile.data.settings.visual_mode = 1 if target == "retro" else (2 if target == "contrast" else 0)
			profile.data.settings.advanced_lighting = target == "lighting"
			wave = 16
			completed = 16
			apply_settings()
			start_wave()
		"planning", "inventory", "wave", "results", "sandbox", "boss":
			start_run("sandbox")
			if target == "planning": ui.show_planning()
			elif target == "inventory":
				backpack = [make_weapon("shotgun", 2), make_weapon("plasma", 4), {"id": "barrel", "rarity": 1, "count": 1}]
				ui.inventory_selected = 0
				ui.show_inventory()
			elif target == "sandbox": ui.show_sandbox()
			elif target == "results":
				wave = 10
				completed = 9
				state = "wave"
				defeat("Objective destroyed")
			elif target == "boss":
				wave = 9
				completed = 9
				world.evolve(9)
				visuals.rebuild()
				player.position = world.position(Vector2i(12, 10), 0.1)
				start_wave()
			else:
				build(Vector2i(11, 8), "sentry")
				build(Vector2i(13, 8), "tesla")
				start_wave()
				for i in 8: spawn_enemy("grunt", world.position(Vector2i(12, 5 + i)))
	for i in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var capture_dir = "res://.godot/captures" if OS.has_feature("editor") else "user://captures"
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var result = get_viewport().get_texture().get_image().save_png(capture_dir + "/" + target + ".png")
	print("CAPTURE ", target, " ", error_string(result))
	quit_game()

func execute_developer_command(source: String) -> void:
	for i in 15: await get_tree().physics_frame
	var expression = Expression.new()
	var error = expression.parse(source, ["input", "os", "time"])
	if error != OK:
		push_error(expression.get_error_text())
		quit_game(1)
		return
	var result = expression.execute([Input, OS, Time], self, false)
	if expression.has_execute_failed():
		push_error(expression.get_error_text())
		quit_game(1)
		return
	print("COMMAND ", var_to_str(result))
	var frames = 3
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--command-frames="): frames = clampi(int(argument.trim_prefix("--command-frames=")), 3, 600)
	for i in frames: await get_tree().physics_frame
	var enemy_summary: Array = []
	for enemy in enemies.values().slice(0, 3): enemy_summary.append({"type": enemy.type, "health": enemy.health, "burn": enemy.burn, "slow": enemy.slow})
	print("STATE ", JSON.stringify({"state": state, "wave": wave, "completed": completed, "health": health, "core": core_health, "scrap": scrap, "enemies": enemies.size(), "enemy_details": enemy_summary, "research": profile.data.research, "tp": profile.data.tp, "bonuses": bonuses, "weapons": weapons, "user_dir": OS.get_user_data_dir(), "player": str(player.position) if is_instance_valid(player) else "none", "grounded": player.is_on_floor() if is_instance_valid(player) else false, "crouched": player.crouched if is_instance_valid(player) else false, "projectiles": projectiles.size(), "stats": stats}))
	if "--command-stay" in OS.get_cmdline_user_args(): return
	quit_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_game()

func quit_game(code: int = 0) -> void:
	if quitting: return
	quitting = true
	if eligible and (state in ["preparation", "wave"] or (state == "paused" and previous_state in ["preparation", "wave"])): save_run()
	state = "quitting"
	if is_instance_valid(audio): audio.stop_all()
	await get_tree().create_timer(0.12, true, false, true).timeout
	get_tree().quit(code)
