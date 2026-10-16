extends Node3D

const World = preload("res://scripts/world.gd")
const Profile = preload("res://scripts/profile.gd")
const Visuals = preload("res://scripts/visuals.gd")
const Player = preload("res://scripts/player.gd")
const Interface = preload("res://scripts/interface.gd")
const Sound = preload("res://scripts/audio.gd")
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
var max_core = 600.0
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
var enemies: Dictionary = {}
var projectiles: Array = []
var drops: Array = []
var next_uid = 0
var event_name = ""
var upgrades: Array = []
var xp = 0
var level = 1
var next_xp = 30
var reward_pending = false
var last_reward = 0
var defeat_reason = ""
var kill_streak = 0
var kill_timer = 0.0
var simulation_ms = 0.0
var hazard_timer = 0.0
var active_cap = 100
var autoplay = false
var benchmark_time = 0.0
var benchmark_stage = 0
var benchmark_stats: Array = []
var pending_map: Dictionary = {}
var saved_editor: Dictionary = {}
var resume_available = false

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
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
	apply_settings()
	resume_available = FileAccess.file_exists("user://run.json")
	world.load_map(world.preset())
	visuals.rebuild()
	menu_camera()
	ui.show_menu()
	if not profile.error.is_empty():
		ui.notify(profile.error)
	if "--benchmark" in OS.get_cmdline_user_args():
		autoplay = true
		start_run("sandbox")
		benchmark_setup()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_screen(argument.trim_prefix("--capture="))

func configure_input() -> void:
	var keys = {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "crouch": KEY_CTRL, "reload": KEY_R, "interact": KEY_E, "ability": KEY_Q, "inventory": KEY_TAB, "planning": KEY_B, "pause": KEY_ESCAPE, "next_wave": KEY_ENTER, "weapon1": KEY_1, "weapon2": KEY_2, "heal": KEY_C, "grenade": KEY_G, "debug": KEY_F3}
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
		var event = InputEventMouseButton.new()
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0], event)

func apply_settings() -> void:
	var settings = profile.data.settings
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(settings.fps)
	visuals.sun.shadow_enabled = int(settings.quality) > 0
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
	return definition.get("tech", "") == "" or profile.rank(definition.tech) > 0 or mode == "sandbox"

func bonus(key: String) -> float:
	return float(bonuses.get(key, 0))

func start_run(run_mode: String = "endless", custom: Dictionary = {}) -> void:
	if playing():
		return
	mode = run_mode
	eligible = run_mode in ["endless", "seeded", "challenge"] and custom.is_empty()
	var value = custom if not custom.is_empty() else world.preset(selected_map, seed_value)
	var issues = world.validate(value)
	if not issues.is_empty():
		ui.notify("Map rejected: " + "; ".join(issues))
		return
	clear_run()
	world.load_map(value)
	rng.seed = int(value.seed)
	run_id = str(Time.get_unix_time_from_system()) + "-" + str(rng.randi())
	bonuses.clear()
	for node in catalog.technologies:
		if node.effect not in ["weapon", "structure"]:
			bonuses[node.effect] = bonus(node.effect) + float(node.value) * profile.rank(node.id)
	wave = 0
	completed = 0
	elapsed = 0
	scrap = int(300 + bonus("scrap")) if mode != "sandbox" else 999999
	max_health = 100 + bonus("health")
	if mode == "challenge":
		max_health *= 0.65
	health = max_health
	max_core = 600 + bonus("core_health")
	core_health = max_core
	shield = bonus("shield")
	capacity = 20 + int(bonus("capacity"))
	consumables = {"medkit": 2, "grenade": 2}
	weapons = [make_weapon("rifle"), make_weapon("pistol")]
	var loadout = str(profile.data.loadout)
	if catalog.weapons.has(loadout) and unlocked(catalog.weapons[loadout]):
		weapons[0] = make_weapon(loadout)
	active_weapon = 0
	level = 1
	xp = 0
	next_xp = 30
	fire_timer = 0
	reload_timer = 0
	ability_timer = 0
	hurt_timer = 0
	kill_streak = 0
	kill_timer = 0
	reward_pending = false
	stats = {"wave": 1, "kills": 0, "bosses": 0, "damage": 0.0, "weapon_damage": 0.0, "tower_damage": 0.0, "built": 0, "earned": 0, "spent": 0, "streak": 0, "difficulty": 1.35 if mode == "challenge" else 1.0}
	visuals.rebuild()
	player = Player.new()
	add_child(player)
	player.setup(self)
	player.position = world.position(world.marker("player"), 0.1)
	state = "preparation"
	ui.close_overlay()
	ui.notify("Preparation — build defenses [B], then begin wave [Enter].")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func clear_run() -> void:
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
	backpack.clear()
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	player = null

func to_menu() -> void:
	Engine.time_scale = 1
	state = "menu"
	clear_run()
	world.load_map(world.preset(selected_map, seed_value))
	visuals.rebuild()
	menu_camera()
	ui.show_menu()

func make_weapon(id: String, rarity: int = 0) -> Dictionary:
	var definition = catalog.weapons[id]
	return {"id": id, "rarity": rarity, "roll": 1.0 + rarity * 0.12 + rng.randf_range(0, 0.08), "ammo": int(definition.magazine), "reserve": int(definition.reserve), "attachment": ""}

func weapon_def() -> Dictionary:
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
	if item.ammo >= definition.magazine or item.reserve <= 0 or definition.magazine == 0:
		return
	reload_timer = maxf(0.25, float(definition.reload) / (1 + bonus("reload")))
	audio.cue("reload")

func ray(from: Vector3, to: Vector3, mask: int = 3, exclude: Array[RID] = []) -> Dictionary:
	var query = PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query)

func sight(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> bool:
	return ray(from, to, 1, exclude).is_empty()

func fire(direction: Vector3 = Vector3.ZERO) -> void:
	if state not in ["preparation", "wave"] or fire_timer > 0 or reload_timer > 0:
		return
	var definition = weapon_def()
	var item = weapons[active_weapon]
	if definition.magazine > 0 and item.ammo <= 0:
		reload_weapon()
		return
	if definition.magazine > 0:
		item.ammo -= 1
	fire_timer = maxf(0.06, definition.interval / (1 + bonus("fire_rate")))
	var from: Vector3 = player.camera.global_position
	var aim = -player.camera.global_basis.z if direction == Vector3.ZERO else direction.normalized()
	var spread = deg_to_rad(float(definition.spread)) * (0.3 if Input.is_action_pressed("aim") or autoplay else 1.0)
	var amount = float(definition.damage) * float(item.roll) * (1 + bonus("damage"))
	if item.attachment == "barrel":
		amount *= 1.2
	if item.attachment == "optic":
		spread *= 0.4
	if rng.randf() < 0.05 + bonus("critical"):
		amount *= 1.75
	for i in int(definition.pellets):
		var shot = (aim + player.camera.global_basis.x * rng.randf_range(-spread, spread) + player.camera.global_basis.y * rng.randf_range(-spread, spread)).normalized()
		if definition.speed > 0:
			launch(from + shot * 0.7, shot * float(definition.speed), amount, definition.splash, "weapon", Color(definition.color), float(definition.range) / definition.speed)
		else:
			var end = from + shot * float(definition.range) * (1 + bonus("range"))
			var hit = ray(from, end)
			if not hit.is_empty():
				end = hit.position
				hit_body(hit.collider, amount * (1.5 if hit.collider.has_meta("enemy") and hit.position.y - hit.collider.global_position.y > 1.4 else 1.0), "weapon", from)
				visuals.burst(end, Color(definition.color), 3, 0.3)
			visuals.beam(from + player.camera.global_basis.x * 0.2 - Vector3(0, 0.1, 0), end, Color(definition.color))
	if profile.data.settings.shake:
		player.recoil = minf(0.05, player.recoil + 0.012)
	audio.cue("shot", from, 0.5)

func hit_body(body: Object, amount: float, source: String, origin: Vector3 = Vector3.ZERO) -> void:
	if not is_instance_valid(body):
		return
	if body.has_meta("enemy"):
		damage_enemy(int(body.get_meta("enemy")), amount, source, origin)
	elif body.has_meta("structure"):
		damage_structure(str(body.get_meta("structure")), amount)
	elif body.has_meta("tile"):
		var key = str(body.get_meta("tile"))
		var tile = world.map.layers.structure.get(key, {})
		if tile.get("health", 0) > 0:
			tile.health -= amount
			if tile.health <= 0:
				world.map.layers.structure.erase(key)
				body.queue_free()
				world.rebuild_flow()
	elif body == player:
		damage_player(amount)
	elif body.has_meta("core"):
		damage_core(amount)

func launch(pos: Vector3, velocity: Vector3, damage: float, splash: float, source: String, color: Color, life: float = 4.0) -> void:
	if projectiles.size() >= 128:
		return
	var mesh = visuals.obtain_bolt(pos, color)
	projectiles.append({"pos": pos, "velocity": velocity, "damage": damage, "splash": splash, "source": source, "life": life, "mesh": mesh, "color": color})

func explosion(pos: Vector3, damage: float, radius: float, source: String) -> void:
	visuals.burst(pos, Color("ffab58"), 16, radius)
	audio.cue("explosion", pos)
	if source in ["weapon", "tower", "ability"]:
		for uid in enemies.keys():
			var enemy = enemies[uid]
			var distance = enemy.node.position.distance_to(pos)
			if distance <= radius and sight(pos + Vector3.UP * 0.2, enemy.node.position + Vector3.UP):
				damage_enemy(uid, damage * (1 - 0.5 * distance / radius), source, pos)
	else:
		if player.position.distance_to(pos) < radius:
			damage_player(damage)
		if world.position(world.marker("objective")).distance_to(pos) < radius:
			damage_core(damage)
		for key in world.construction.keys():
			if world.position(world.point(key)).distance_to(pos) < radius:
				damage_structure(key, damage)

func damage_enemy(uid: int, amount: float, source: String, origin: Vector3 = Vector3.ZERO) -> void:
	if not enemies.has(uid) or state != "wave":
		return
	var enemy = enemies[uid]
	if enemy.health <= 0:
		return
	var armor = float(enemy.armor)
	if enemy.type == "shielded" and origin != Vector3.ZERO:
		var incoming = (origin - enemy.node.position).normalized()
		if incoming.dot(-enemy.node.basis.z) > 0.3:
			armor += 0.45
	var actual = minf(enemy.health, amount * (1 - minf(0.8, armor)))
	enemy.health -= actual
	stats.damage += actual
	if source == "tower":
		stats.tower_damage += actual
	else:
		stats.weapon_damage += actual
	if source == "weapon":
		ui.hit_flash = 0.12
		if bonus("burn") > 0:
			enemy.burn = maxf(enemy.burn, bonus("burn"))
		if bonus("slow") > 0:
			enemy.slow = maxf(enemy.slow, bonus("slow"))
			enemy.slow_time = 2.0
		if bonus("lifesteal") > 0:
			health = minf(max_health, health + actual * bonus("lifesteal"))
	if enemy.health > 0:
		return
	stats.kills += 1
	if enemy.type == "boss":
		stats.bosses += 1
	kill_streak += 1
	kill_timer = 4.0
	stats.streak = maxi(int(stats.streak), kill_streak)
	var reward = int(6 + enemy.cost * 0.4)
	scrap += reward
	stats.earned += reward
	xp += int(enemy.cost)
	visuals.burst(enemy.node.position + Vector3.UP, Color(enemy.color), 8)
	if rng.randf() < 0.18 + bonus("loot") or enemy.type == "boss":
		drop_loot(enemy.node.position, enemy.type == "boss")
	audio.cue("kill", enemy.node.position, 0.35)
	enemy.node.queue_free()
	enemies.erase(uid)

func damage_player(amount: float) -> void:
	if state != "wave":
		return
	amount *= 1 - minf(0.65, bonus("armor"))
	var absorbed = minf(shield, amount)
	shield -= absorbed
	health = maxf(0, health - amount + absorbed)
	hurt_timer = 2.5
	ui.hurt_flash = 0.3
	audio.cue("hurt", player.position, 0.6)
	if health <= 0:
		defeat("Player defeated")

func damage_core(amount: float) -> void:
	if state != "wave":
		return
	for key in world.construction:
		var item = world.construction[key]
		if item.kind == "shield" and world.point(key).distance_to(world.marker("objective")) * 3 < item.range:
			amount *= 0.75
			break
	core_health = maxf(0, core_health - amount)
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
		world.rebuild_flow()

func build(p: Vector2i, id: String) -> String:
	if state != "preparation":
		return "Construction is available only during Preparation."
	if not catalog.structures.has(id):
		return "Unknown structure."
	var definition = catalog.structures[id]
	if not unlocked(definition):
		return "Research required: " + definition.tech.replace("_", " ")
	var reason = world.placement(p)
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
	item.cooldown = 0.0
	item.target_mode = 0
	item.invested = cost
	item.last_target = -1
	item.focus = 0.0
	world.construction[world.cell_key(p)] = item
	scrap -= cost
	stats.spent += cost
	stats.built += 1
	world.rebuild_flow()
	visuals.structure(world.cell_key(p))
	audio.cue("build", world.position(p), 0.5)
	return ""

func build_cost(definition: Dictionary) -> int:
	return maxi(1, int(definition.cost * (1 - minf(0.5, bonus("discount")))))

func manage_structure(key: String, action: String) -> String:
	if state != "preparation" or not world.construction.has(key):
		return "Structure management requires Preparation."
	var item = world.construction[key]
	if action in ["sell", "demolish"]:
		if action == "sell":
			scrap += int(item.invested * 0.65 * maxf(0.2, item.health / item.max_health))
		world.construction.erase(key)
		visuals.structure(key)
		world.rebuild_flow()
		return ""
	if action == "target":
		item.target_mode = (int(item.target_mode) + 1) % TARGET_MODES.size()
		return ""
	if action == "repair":
		if mode == "challenge":
			return "Repairs disabled in Challenge mode."
		var price = int(ceil((item.max_health - item.health) * 0.15))
		if scrap < price:
			return "Not enough scrap."
		scrap -= price
		stats.spent += price
		item.health = item.max_health
		return ""
	if item.level >= 4:
		return "Maximum upgrade level reached."
	var price = int(item.cost * 0.6 * item.level)
	if scrap < price:
		return "Not enough scrap."
	scrap -= price
	stats.spent += price
	item.invested += price
	item.level += 1
	item.max_health *= 1.3
	item.health = item.max_health
	if action == "rapid":
		item.interval = maxf(0.08, item.interval * 0.7)
		item.branch = "Gatling"
	else:
		item.damage *= 1.5
		item.range *= 1.12
		item.branch = "Precision"
	visuals.structure(key)
	return ""

func start_wave() -> bool:
	if state != "preparation" or reward_pending:
		return false
	wave += 1
	stats.wave = wave
	state = "wave"
	ui.close_overlay()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spawn_queue.clear()
	var budget = minf(12000, 28 + wave * 16 + pow(minf(wave, 5000), 1.15) * 2)
	if wave % 10 == 0:
		spawn_queue.append("boss")
		budget -= 120
	var pool: Array = []
	for id in catalog.enemies:
		if id != "boss" and catalog.enemies[id].min_wave <= wave:
			pool.append(id)
	var count = 0
	while budget >= 7 and count < 600:
		var id = pool[rng.randi_range(0, pool.size() - 1)]
		if catalog.enemies[id].cost > budget:
			id = "grunt"
		spawn_queue.append(id)
		budget -= catalog.enemies[id].cost
		count += 1
	spawn_timer = 0.2
	event_name = upcoming_event(wave)
	visuals.atmosphere.environment.fog_density = 0.025 if event_name == "Heavy fog" else 0.006
	visuals.sun.light_energy = 0.25 if event_name == "Blackout" else 1.5
	ui.notify("WAVE %d%s" % [wave, " · " + event_name if event_name != "" else ""])
	audio.cue("wave")
	return true

func upcoming_event(number: int) -> String:
	if number % 10 == 0: return "Siege Titan"
	if number % 9 == 0: return "Tower interference"
	if number % 7 == 0: return "Heavy fog"
	if number % 6 == 0: return "Blackout"
	if number % 5 == 0: return "Armored assault"
	return ""

func spawn_enemy(id: String, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	if not catalog.enemies.has(id) or enemies.size() >= active_cap:
		return
	var definition = catalog.enemies[id]
	var enemy = definition.duplicate(true)
	var scale_factor = 1 + log(1 + maxf(0, wave - 1) * 0.13) * 0.8
	enemy.health *= scale_factor
	enemy.max_health = enemy.health
	enemy.damage *= 1 + log(1 + maxf(0, wave - 1) * 0.06)
	enemy.speed *= minf(1.8, 1 + wave * 0.008)
	if mode == "challenge":
		enemy.speed *= 1.25
	if event_name == "Armored assault":
		enemy.armor = minf(0.7, enemy.armor + 0.15)
	next_uid += 1
	enemy.uid = next_uid
	enemy.type = id
	enemy.cooldown = 0.5
	enemy.slow = 0.0
	enemy.slow_time = 0.0
	enemy.burn = 0.0
	enemy.ai = "navigate"
	enemy.heal_timer = 1.0
	var node = visuals.enemy(enemy)
	enemy.node = node
	if spawn_pos == Vector3.ZERO:
		var points = world.spawns(completed)
		if points.is_empty():
			node.queue_free()
			return
		spawn_pos = world.position(points[rng.randi_range(0, points.size() - 1)])
	node.position = spawn_pos + Vector3(rng.randf_range(-0.5, 0.5), 0.1, rng.randf_range(-0.5, 0.5))
	enemies[enemy.uid] = enemy

func finish_wave() -> void:
	if state != "wave" or completed >= wave:
		return
	completed = wave
	state = "completion"
	var reward = 65 + mini(wave * 12, 4000)
	scrap += reward
	stats.earned += reward
	for key in world.construction:
		var item = world.construction[key]
		if item.kind == "generator":
			var generated = 40 * int(item.level)
			scrap += generated
			stats.earned += generated
		if item.kind == "ammo":
			for weapon in weapons:
				weapon.reserve = mini(int(weapon.reserve + 60 * item.level), 9999)
	for weapon in weapons:
		weapon.reserve = mini(int(weapon.reserve + catalog.weapons[weapon.id].magazine * 2), 9999)
	health = minf(max_health, health + 10)
	var messages = world.evolve(completed)
	if not messages.is_empty():
		visuals.rebuild()
	ui.notify("Wave %d cleared · +%d scrap%s" % [wave, reward, "\n" + "\n".join(messages) if not messages.is_empty() else ""])
	if xp >= next_xp:
		xp -= next_xp
		level += 1
		next_xp = int(next_xp * 1.35 + 10)
	state = "preparation"
	reward_pending = true
	upgrades = catalog.upgrades.duplicate(true)
	for i in range(upgrades.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = upgrades[i]
		upgrades[i] = upgrades[j]
		upgrades[j] = temp
	upgrades = upgrades.slice(0, 3)
	ui.show_upgrades()
	if eligible:
		save_run()

func choose_upgrade(index: int) -> void:
	if not reward_pending or index < 0 or index >= upgrades.size():
		return
	var upgrade = upgrades[index]
	bonuses[upgrade.effect] = bonus(upgrade.effect) + float(upgrade.value)
	if upgrade.effect == "health":
		max_health += upgrade.value
		health = minf(max_health, health + upgrade.value)
	if upgrade.effect == "shield":
		shield += upgrade.value
	reward_pending = false
	ui.close_overlay()
	if eligible:
		save_run()

func defeat(reason: String) -> void:
	if state != "wave":
		return
	state = "results"
	defeat_reason = reason
	last_reward = profile.award(run_id, stats, eligible)
	if last_reward >= 0:
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
		launch(player.camera.global_position, -player.camera.global_basis.z * 18, 120, 6, "weapon", Color("ffb265"), 2)
	consumables[id] -= 1
	audio.cue("build")

func ability() -> void:
	if state != "wave" or ability_timer > 0:
		return
	ability_timer = 18 / (1 + bonus("ability"))
	explosion(player.position + Vector3.UP, 55, 8, "ability")
	for enemy in enemies.values():
		if enemy.node.position.distance_to(player.position) < 8:
			enemy.slow = 0.85
			enemy.slow_time = 3
	ui.notify("Pulse discharged")

func interact() -> void:
	if not playing() or state == "paused":
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
	if not hit.is_empty() and hit.collider.has_meta("tile"):
		var key = str(hit.collider.get_meta("tile"))
		var tile = world.map.layers.structure.get(key, {})
		if tile.get("type") == "door" and not tile.get("locked", false):
			world.map.layers.structure.erase(key)
			hit.collider.queue_free()
			world.rebuild_flow()
			audio.cue("build", hit.position)
			return
	if state == "preparation":
		for key in world.map.layers.objects:
			if world.position(world.point(key)).distance_to(player.position) < 4:
				var tile = world.map.layers.objects[key]
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
	var roll = rng.randf()
	if roll > 0.98: rarity = 4
	elif roll > 0.9: rarity = 3
	elif roll > 0.68: rarity = 2
	elif roll > 0.35: rarity = 1
	if boss: rarity = maxi(2, rarity)
	var item: Dictionary
	if rng.randf() < 0.55 or boss:
		item = make_weapon(available[rng.randi_range(0, available.size() - 1)], rarity)
	else:
		var kinds = ["medkit", "grenade", "barrel", "optic", "armor", "shield_pack"]
		item = {"id": kinds[rng.randi_range(0, kinds.size() - 1)], "count": 1, "rarity": rarity}
	var colors = [Color("c5ced2"), Color("97c86d"), Color("69bae9"), Color("bf89e1"), Color("ffbc62")]
	var mesh = visuals.box(visuals, pos + Vector3(0, 0.5, 0), Vector3(0.5, 0.5, 0.5), colors[rarity], 0.7)
	drops.append({"item": item, "pos": pos, "mesh": mesh})

func pickup(index: int) -> void:
	if index < 0 or index >= drops.size():
		return
	var drop = drops[index]
	var item = drop.item
	if item.id in ["medkit", "grenade"]:
		consumables[item.id] = mini(99, consumables[item.id] + int(item.get("count", 1)))
	else:
		if backpack.size() >= capacity:
			ui.notify("Backpack full. Scrap, drop, or equip an item.")
			return
		backpack.append(item)
	ui.notify("Collected " + item_name(item))
	drop.mesh.queue_free()
	drops.remove_at(index)
	audio.cue("ui")

func item_name(item: Dictionary) -> String:
	return catalog.weapons[item.id].name if catalog.weapons.has(item.id) else str(item.id).replace("_", " ").capitalize()

func inventory_action(index: int, action: String) -> void:
	if not playing() or state == "paused" or index < 0 or index >= backpack.size():
		return
	var item = backpack[index]
	if action in ["equip0", "equip1"] and catalog.weapons.has(item.id):
		if not unlocked(catalog.weapons[item.id]):
			return
		var slot = int(action.right(1))
		var old = weapons[slot]
		weapons[slot] = item
		backpack[index] = old
		reload_timer = 0
		player.refresh_gun()
	elif action == "use":
		if item.id in ["barrel", "optic"]:
			var old = weapons[active_weapon].attachment
			weapons[active_weapon].attachment = item.id
			backpack.remove_at(index)
			if old != "": backpack.append({"id": old, "count": 1, "rarity": 0})
		elif item.id == "armor":
			bonuses.armor = minf(0.65, bonus("armor") + 0.05)
			backpack.remove_at(index)
		elif item.id == "shield_pack":
			shield = minf(200, shield + 30)
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
		var mesh = visuals.box(visuals, pos + Vector3.UP * 0.5, Vector3.ONE * 0.5, Color("8ccbd9"), 0.5)
		drops.append({"item": item.duplicate(true), "pos": pos, "mesh": mesh})
		backpack.remove_at(index)
	ui.show_inventory()

func buy(id: String) -> void:
	if state != "preparation":
		return
	var cost = 35
	if catalog.weapons.has(id):
		cost = 80
		if not unlocked(catalog.weapons[id]) or backpack.size() >= capacity:
			ui.notify("Research required or backpack full.")
			return
	if scrap < cost:
		ui.notify("Not enough scrap.")
		return
	scrap -= cost
	stats.spent += cost
	if id == "ammo":
		for weapon in weapons:
			weapon.reserve = mini(9999, int(weapon.reserve + catalog.weapons[weapon.id].magazine * 4))
	elif id == "core":
		if mode != "challenge": core_health = minf(max_core, core_health + 120)
	elif id in ["medkit", "grenade"]:
		consumables[id] += 1
	elif catalog.weapons.has(id):
		backpack.append(make_weapon(id))
	ui.show_shop()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F4 and mode == "sandbox" and playing():
		ui.show_sandbox()
	if event.is_action_pressed("debug"):
		ui.debug_visible = not ui.debug_visible
	if event.is_action_pressed("pause"):
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
	if playing() and state != "paused":
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
		benchmark_update(delta)
	if state not in ["preparation", "wave"]:
		return
	var start = Time.get_ticks_usec()
	elapsed += delta
	fire_timer = maxf(0, fire_timer - delta)
	ability_timer = maxf(0, ability_timer - delta)
	hurt_timer = maxf(0, hurt_timer - delta)
	kill_timer -= delta
	if kill_timer <= 0: kill_streak = 0
	if hurt_timer <= 0:
		health = minf(max_health, health + bonus("regen") * delta)
		shield = minf(bonus("shield"), shield + delta * 2) if shield < bonus("shield") else shield
	if reload_timer > 0:
		reload_timer -= delta
		if reload_timer <= 0:
			var item = weapons[active_weapon]
			var amount = mini(int(weapon_def().magazine - item.ammo), int(item.reserve))
			item.ammo += amount
			item.reserve -= amount
	for drop in drops:
		drop.mesh.rotation.y += delta
		drop.mesh.position.y = 0.6 + sin(elapsed * 2) * 0.1
	if state != "wave":
		return
	spawn_timer -= delta
	if spawn_timer <= 0 and not spawn_queue.is_empty() and enemies.size() < active_cap:
		spawn_enemy(spawn_queue.pop_front())
		spawn_timer = maxf(0.12, 1.0 / (1 + wave * 0.08))
	update_enemies(delta)
	if state != "wave": return
	update_towers(delta)
	update_projectiles(delta)
	hazard_timer -= delta
	if hazard_timer <= 0:
		hazard_timer = 0.5
		update_hazards()
	if spawn_queue.is_empty() and enemies.is_empty():
		finish_wave()
	simulation_ms = (Time.get_ticks_usec() - start) / 1000.0

func update_enemies(delta: float) -> void:
	var objective_pos = world.position(world.marker("objective"))
	var buckets: Dictionary = {}
	for enemy in enemies.values():
		var key = world.cell_key(world.cell(enemy.node.position))
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(enemy.uid)
	for uid in enemies.keys():
		if not enemies.has(uid) or state != "wave": continue
		var enemy = enemies[uid]
		var node: CharacterBody3D = enemy.node
		var pos = node.position
		enemy.cooldown -= delta
		enemy.slow_time -= delta
		if enemy.slow_time <= 0: enemy.slow = 0.0
		if enemy.burn > 0:
			damage_enemy(uid, enemy.burn * delta, "weapon")
			if not enemies.has(uid): continue
		var target = objective_pos
		var target_kind = "core"
		var target_key = ""
		if enemy.type in ["runner", "boss", "spitter", "exploder"] and pos.distance_to(player.position) < (18 if enemy.type == "runner" else 12):
			if sight(pos + Vector3.UP, player.position + Vector3.UP):
				target = player.position
				target_kind = "player"
		if enemy.type in ["breaker", "saboteur"]:
			var best = 18.0
			for key in world.construction:
				var p = world.position(world.point(key))
				var distance = p.distance_to(pos)
				if distance < best and (enemy.type == "breaker" or world.construction[key].kind == "tower"):
					best = distance
					target = p
					target_kind = "structure"
					target_key = key
		if enemy.type == "support":
			enemy.heal_timer -= delta
			if enemy.heal_timer <= 0:
				enemy.heal_timer = 2
				for ally in enemies.values():
					if ally.node.position.distance_squared_to(pos) < 64:
						ally.health = minf(ally.max_health, ally.health + 8)
		var destination = target
		var target_distance = pos.distance_to(target)
		var reach = float(enemy.range) + (1 if target_kind in ["core", "structure"] else 0)
		var can_see = true
		if reach > 4:
			var hit = ray(pos + Vector3.UP * 1.2, target + Vector3.UP * 1.2, 5, [node.get_rid()])
			can_see = hit.is_empty() or (target_kind == "core" and hit.collider.has_meta("core")) or hit.collider == player
		if target_distance > reach or not can_see:
			var cell = world.cell(pos)
			var next = world.next_toward(cell, world.cell(target))
			destination = world.position(next)
			var next_key = world.cell_key(next)
			if world.construction.has(next_key) and world.construction[next_key].kind != "trap":
				target_kind = "structure"
				target_key = next_key
				target = destination
				target_distance = pos.distance_to(target)
				reach = maxf(2.8, float(enemy.range))
				can_see = true
			elif world.fixed_solid(next):
				var tile = world.map.layers.structure.get(next_key, {})
				if tile.get("health", 0) > 0:
					target_kind = "tile"
					target_key = next_key
					target_distance = pos.distance_to(destination)
					reach = 3
					can_see = true
		var direction = destination - pos
		direction.y = 0
		if direction.length_squared() > 0.01:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-direction.x, -direction.z), delta * 7)
		if target_distance <= reach and can_see:
			enemy.ai = "attack"
			node.velocity = Vector3(0, -2, 0)
			if enemy.cooldown <= 0:
				enemy.cooldown = maxf(0.3, enemy.interval / minf(1.8, 1 + wave * 0.004))
				if enemy.type == "exploder":
					explosion(pos + Vector3.UP, enemy.damage, 5, "enemy")
					damage_enemy(uid, 100000, "weapon")
					continue
				elif enemy.type == "spitter" or (enemy.type == "boss" and enemy.health < enemy.max_health * 0.5):
					launch(pos + Vector3.UP * 1.6, (target + Vector3.UP - pos - Vector3.UP * 1.6).normalized() * 15, enemy.damage, 1.8, "enemy", Color("a7dd66"))
				elif target_kind == "player": damage_player(enemy.damage)
				elif target_kind == "core": damage_core(enemy.damage)
				elif target_kind == "structure": damage_structure(target_key, enemy.damage)
				elif target_kind == "tile":
					var tile = world.map.layers.structure.get(target_key, {})
					tile.health -= enemy.damage
					if tile.health <= 0:
						world.map.layers.structure.erase(target_key)
						world.rebuild_flow()
						visuals.rebuild()
				visuals.beam(pos + Vector3.UP, target + Vector3.UP, Color(enemy.color), 0.05, 0.12)
		else:
			enemy.ai = "navigate"
			var steering = direction.normalized()
			var current = world.cell(pos)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for other_uid in buckets.get(world.cell_key(current + Vector2i(dx, dy)), []):
						if other_uid == uid or not enemies.has(other_uid): continue
						var away = pos - enemies[other_uid].node.position
						away.y = 0
						if away.length_squared() < 1.6 and away.length_squared() > 0.001:
							steering += away.normalized() * (1.2 - away.length()) * 0.7
			var speed = float(enemy.speed) * (1 - minf(0.9, enemy.slow))
			node.velocity = steering.limit_length(1) * speed
			node.velocity.y = -2
		node.move_and_slide()
		var model = node.get_node("Model")
		model.position.y = sin(elapsed * enemy.speed * 4 + uid) * 0.035 if enemy.ai == "navigate" else 0

func update_towers(delta: float) -> void:
	for key in world.construction.keys():
		if not world.construction.has(key): continue
		var tower = world.construction[key]
		tower.cooldown -= delta
		if tower.cooldown > 0: continue
		var pos = world.position(world.point(key), 2.1)
		if tower.kind == "repair" and mode != "challenge":
			tower.cooldown = 1
			for other_key in world.construction:
				var other = world.construction[other_key]
				if world.point(other_key).distance_to(world.point(key)) * 3 <= tower.range:
					other.health = minf(other.max_health, other.health + tower.damage)
			continue
		if tower.kind not in ["tower", "trap"]: continue
		var target = -1
		var best_score = -1e20
		for uid in enemies:
			var enemy = enemies[uid]
			var ep = enemy.node.position + Vector3.UP
			var distance = pos.distance_to(ep)
			if distance > tower.range * (1 + bonus("range")): continue
			var exclude: Array[RID] = []
			if visuals.structures.has(key): exclude.append(visuals.structures[key].get_rid())
			if tower.id != "mortar" and not sight(pos, ep, exclude): continue
			var score = -distance
			match int(tower.target_mode):
				1: score = enemy.max_health
				2: score = -enemy.max_health
				3: score = -float(world.flow.get(world.cell_key(world.cell(enemy.node.position)), 9999))
				4: score = float(world.flow.get(world.cell_key(world.cell(enemy.node.position)), 9999))
				5: score = -enemy.health
				6: score = enemy.damage * enemy.speed
			if score > best_score:
				best_score = score
				target = uid
		if target < 0: continue
		var target_pos = enemies[target].node.position + Vector3.UP
		var amount = float(tower.damage) * (1 + bonus("tower_damage"))
		var interval = maxf(0.1, float(tower.interval))
		if event_name == "Tower interference": interval *= 1.7
		for support_key in world.construction:
			var support = world.construction[support_key]
			if support.kind == "support" and world.point(key).distance_to(world.point(support_key)) * 3 <= support.range:
				amount *= 1.2
				interval *= 0.85
				break
		tower.cooldown = interval
		if tower.id == "laser":
			tower.focus = minf(2.0, tower.focus + 0.2) if tower.last_target == target else 0.0
			amount *= 1 + tower.focus
		tower.last_target = target
		if tower.slow > 0:
			enemies[target].slow = maxf(enemies[target].slow, tower.slow)
			enemies[target].slow_time = 2.0
		if tower.id == "flame": enemies[target].burn = maxf(enemies[target].burn, 8.0)
		if tower.id in ["rocket", "mortar"]:
			var distance = pos.distance_to(target_pos)
			launch(pos, (target_pos - pos).normalized() * 28, amount, tower.splash, "tower", Color(tower.color), distance / 28 + 0.2)
		elif tower.id == "tesla":
			var previous = target_pos
			var struck: Array = [target]
			damage_enemy(target, amount, "tower", pos)
			for i in 3:
				var closest = -1
				var distance = 5.0
				for uid in enemies:
					var ep = enemies[uid].node.position + Vector3.UP
					if uid not in struck and ep.distance_to(previous) < distance and sight(previous, ep):
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
				for enemy in enemies.values():
					if enemy.node.position.distance_to(target_pos) < tower.splash:
						enemy.slow = maxf(enemy.slow, tower.slow)
						enemy.slow_time = 2
		else:
			damage_enemy(target, amount, "tower", pos)
		if tower.id == "rail":
			var aim = (target_pos - pos).normalized()
			for uid in enemies.keys():
				if uid == target: continue
				var diff = enemies[uid].node.position + Vector3.UP - pos
				var along = diff.dot(aim)
				if along > 0 and along < tower.range and (diff - aim * along).length() < 0.8:
					damage_enemy(uid, amount * 0.65, "tower", pos)
		if tower.id == "mine":
			world.construction.erase(key)
			visuals.structure(key)
		else:
			visuals.beam(pos, target_pos, Color(tower.color), 0.045, 0.15)
			if visuals.structures.has(key):
				var head = visuals.structures[key].get_node_or_null("Head")
				if head and head.global_position.distance_squared_to(target_pos) > 0.01:
					head.look_at(Vector3(target_pos.x, head.global_position.y, target_pos.z))

func update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p = projectiles[i]
		var end = p.pos + p.velocity * delta
		var hit = ray(p.pos, end, 5 if p.source == "enemy" else 3)
		p.life -= delta
		if not hit.is_empty() or p.life <= 0:
			var impact = hit.position if not hit.is_empty() else end
			if p.splash > 0:
				explosion(impact, p.damage, p.splash, p.source)
			elif not hit.is_empty():
				hit_body(hit.collider, p.damage, p.source, p.pos)
			visuals.release_bolt(p.mesh)
			projectiles.remove_at(i)
		else:
			p.pos = end
			p.mesh.position = end

func update_hazards() -> void:
	for key in world.map.layers.objects.keys():
		var tile = world.map.layers.objects[key]
		if tile.type not in world.HAZARDS: continue
		var pos = world.position(world.point(key))
		var affected = false
		if player.position.distance_to(pos) < 1.8:
			if tile.type != "slow": damage_player(8 if tile.type != "mine" else 45)
			affected = true
		for uid in enemies.keys():
			var enemy = enemies[uid]
			if enemy.node.position.distance_to(pos) < 1.8:
				if tile.type == "slow": enemy.slow = 0.5; enemy.slow_time = 1
				else: damage_enemy(uid, 10 if tile.type != "mine" else 95, "tower", pos)
				affected = true
		if tile.type == "mine" and affected:
			world.map.layers.objects.erase(key)
			visuals.burst(pos, Color("ffad69"), 12, 3)

func save_run() -> bool:
	if not eligible or state not in ["preparation", "paused"] or (state == "paused" and previous_state != "preparation"):
		ui.notify("Save between waves in a standard run.")
		return false
	var record = {"version": 1, "id": run_id, "mode": mode, "world": world.map, "construction": world.construction, "applied": world.applied, "wave": wave, "completed": completed, "scrap": scrap, "health": health, "max_health": max_health, "shield": shield, "core": core_health, "max_core": max_core, "stats": stats, "bonuses": bonuses, "weapons": weapons, "backpack": backpack, "consumables": consumables, "active": active_weapon, "elapsed": elapsed, "position": [player.position.x, player.position.y, player.position.z], "yaw": player.rotation.y, "pitch": player.pitch, "rng": str(rng.state), "level": level, "xp": xp, "next_xp": next_xp, "reward_pending": reward_pending, "upgrades": upgrades, "capacity": capacity}
	var result = write_json("user://run.json", record)
	resume_available = result
	if not result: ui.notify("Cannot save run. Existing save preserved.")
	return result

func write_json(path: String, value: Dictionary) -> bool:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path, path + ".bak") != OK: return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func load_run() -> void:
	var record: Variant = null
	for path in ["user://run.json", "user://run.json.bak"]:
		if FileAccess.file_exists(path):
			var value = JSON.parse_string(FileAccess.get_file_as_string(path))
			if valid_run(value):
				record = value
				break
	if record == null:
		ui.notify("No valid unfinished run found; saved files preserved.")
		return
	var r: Dictionary = record
	start_run(r.mode)
	world.load_map(r.world)
	world.construction = r.construction
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
	bonuses = r.bonuses
	weapons = r.weapons
	backpack = r.backpack
	consumables = r.consumables
	active_weapon = clampi(int(r.active), 0, 1)
	elapsed = float(r.elapsed)
	player.position = Vector3(r.position[0], r.position[1], r.position[2])
	player.rotation.y = r.yaw
	player.pitch = r.pitch
	rng.state = int(r.rng)
	level = int(r.level)
	xp = int(r.xp)
	next_xp = int(r.next_xp)
	reward_pending = r.reward_pending
	upgrades = r.upgrades
	capacity = int(r.capacity)
	visuals.rebuild()
	player.refresh_gun()
	if reward_pending: ui.show_upgrades()
	ui.notify("Run restored at preparation for wave %d." % (wave + 1))

func valid_run(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1: return false
	for key in ["world", "construction", "stats", "bonuses", "consumables"]:
		if not value.get(key) is Dictionary: return false
	for key in ["weapons", "backpack", "applied", "position", "upgrades"]:
		if not value.get(key) is Array: return false
	if not value.get("id") is String or not value.get("mode") is String or not value.get("rng") is String or not value.rng.is_valid_int(): return false
	if value.id in profile.data.awarded or value.mode not in ["endless", "seeded", "challenge"]: return false
	if not value.get("reward_pending") is bool: return false
	for key in ["wave", "completed", "scrap", "health", "max_health", "shield", "core", "max_core", "active", "elapsed", "level", "xp", "next_xp", "capacity"]:
		if not profile.numeric(value.get(key), 0, 1e12): return false
	for key in ["yaw", "pitch"]:
		if not profile.numeric(value.get(key), -1000000, 1000000): return false
	if value.weapons.size() != 2 or value.position.size() != 3 or value.capacity < 20 or value.capacity > 100 or value.backpack.size() > value.capacity: return false
	if value.active > 1 or value.completed != value.wave or value.health <= 0 or value.core <= 0: return false
	if not world.validate(value.world).is_empty(): return false
	for number in value.position:
		if not profile.numeric(number, -10, 1000): return false
	for key in ["medkit", "grenade"]:
		if not profile.numeric(value.consumables.get(key), 0, 9999): return false
	for key in value.bonuses:
		if not key is String or not profile.numeric(value.bonuses[key], 0, 1e9): return false
	for key in ["wave", "kills", "bosses", "damage", "weapon_damage", "tower_damage", "built", "earned", "spent", "streak", "difficulty"]:
		if not profile.numeric(value.stats.get(key), 0, 1e15): return false
	for item in value.weapons + value.backpack:
		if not item is Dictionary or not item.get("id") is String: return false
		if not profile.numeric(item.get("rarity"), 0, 4): return false
		if catalog.weapons.has(item.id):
			var definition = catalog.weapons[item.id]
			if definition.tech != "" and profile.rank(definition.tech) == 0: return false
			for key in ["ammo", "reserve", "roll"]:
				if not profile.numeric(item.get(key), 0, 100000): return false
			if item.get("attachment") not in ["", "barrel", "optic"]: return false
		elif item.id not in ["barrel", "optic", "armor", "shield_pack", "medkit", "grenade"]: return false
	for key in value.construction:
		if not key is String or key.split(",").size() != 2: return false
		var item = value.construction[key]
		if not item is Dictionary or not catalog.structures.has(item.get("id", "")): return false
		for field in ["health", "max_health", "level", "cooldown", "target_mode", "invested", "focus", "damage", "interval", "range", "splash", "slow", "cost"]:
			if not profile.numeric(item.get(field), 0, 1e12): return false
		if item.get("kind") != catalog.structures[item.id].kind or not item.get("color") is String or not item.get("name") is String or not item.get("branch") is String: return false
		if not profile.numeric(item.get("last_target"), -1, 1e12) or item.target_mode >= TARGET_MODES.size(): return false
	for id in value.applied:
		if not id is String: return false
	for item in value.upgrades:
		if not item is Dictionary or not item.get("name") is String or not item.get("description") is String or not item.get("effect") is String or not profile.numeric(item.get("value"), 0, 1000): return false
	return not value.reward_pending or value.upgrades.size() == 3

func remove_run_save() -> void:
	for path in ["user://run.json", "user://run.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	resume_available = false

func benchmark_setup() -> void:
	for p in [Vector2i(11, 3), Vector2i(13, 3), Vector2i(11, 5), Vector2i(13, 5), Vector2i(11, 8), Vector2i(13, 8), Vector2i(10, 11), Vector2i(14, 11)]:
		var result = build(p, "sentry")
		print("BENCHMARK build ", p, " ", "OK" if result == "" else result)
	print("BENCHMARK fixed tile rejection: ", build(Vector2i(12, 12), "wall"))
	player.position = world.position(Vector2i(12, 10), 0.1)
	player.rotation.y = 0
	print("BENCHMARK initialized engine=", Engine.get_version_info().string)

func benchmark_update(delta: float) -> void:
	benchmark_time += delta
	if benchmark_time > 180 or (state == "results" and benchmark_time > 10):
		print("BENCHMARK FINAL ", JSON.stringify({"seconds": elapsed, "completed": completed, "stats": stats, "enemies": enemies.size(), "fps": Engine.get_frames_per_second(), "simulation_ms": simulation_ms, "nav_ms": world.nav_ms, "memory": OS.get_static_memory_usage()}))
		for enemy in enemies.values(): print("BENCHMARK survivor ", enemy.type, " hp=", enemy.health, " position=", enemy.node.position, " cell=", world.cell(enemy.node.position), " next=", world.next_cell(world.cell(enemy.node.position)), " ai=", enemy.ai)
		get_tree().quit()
		return
	if state == "preparation":
		if reward_pending:
			choose_upgrade(0)
		if completed > benchmark_stage:
			benchmark_stage = completed
			print("BENCHMARK wave cleared=", completed, " core=", core_health, " kills=", stats.kills, " evolved=", world.applied)
		start_wave()
	elif state == "wave":
		var nearest = -1
		var distance = 40.0
		for uid in enemies:
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
		"research": ui.show_research()
		"editor": ui.editor.open()
		"settings": ui.show_settings()
		"selection": ui.show_selection()
		"planning", "inventory", "wave", "results", "sandbox":
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
			else:
				build(Vector2i(11, 8), "sentry")
				build(Vector2i(13, 8), "tesla")
				start_wave()
				for i in 8: spawn_enemy("grunt", world.position(Vector2i(12, 5 + i)))
	for i in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/captures")
	var result = get_viewport().get_texture().get_image().save_png("res://.godot/captures/" + target + ".png")
	print("CAPTURE ", target, " ", error_string(result))
	get_tree().quit()
