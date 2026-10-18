extends RefCounted

const ENEMY_NUMBERS = ["health", "max_health", "damage", "armor", "speed", "range", "interval", "cost", "cooldown", "slow", "slow_time", "burn", "burn_time", "poison", "poison_time", "heal_timer", "summon_timer", "think_timer", "blast_resist", "status_resist"]
const MODIFIERS = ["stabilized", "overclocked", "incendiary", "frost", "vampiric", "volatile", "ricochet"]

static func vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func unpack(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

static func valid_vector(game, value: Variant, bound: float = 1000) -> bool:
	if not value is Array or value.size() != 3: return false
	for component in value:
		if not game.profile.numeric(component, -bound, bound): return false
	return true

static func snapshot(game) -> Dictionary:
	var result = {"enemies": [], "projectiles": [], "queue": game.spawn_queue.duplicate(), "reserve": game.spawn_reserve.duplicate(), "next_uid": game.next_uid, "spawn_timer": game.spawn_timer, "hazard_timer": game.hazard_timer, "kill_timer": game.kill_timer, "kill_streak": game.kill_streak, "faction": game.faction_name}
	for enemy in game.enemies.values():
		var item = {"type": enemy.type, "uid": enemy.uid, "position": vector(enemy.node.position), "velocity": vector(enemy.node.velocity), "yaw": enemy.node.rotation.y, "steering": vector(enemy.steering), "elite": enemy.elite, "ai": enemy.ai, "burn_source": enemy.burn_source}
		for field in ENEMY_NUMBERS: item[field] = enemy[field]
		item.simulation_lag = maxf(0, game.elapsed - float(enemy.get("simulated_at", game.elapsed)))
		for effect in ["burn", "poison", "slow"]:
			item[effect + "_lag"] = maxf(0, game.elapsed - float(enemy.get(effect + "_at", enemy.get("simulated_at", game.elapsed))))
		result.enemies.append(item)
	for projectile in game.projectiles:
		var effects = projectile.effects.duplicate(true)
		if effects.has("origin"): effects.origin = vector(effects.origin)
		result.projectiles.append({"position": vector(projectile.pos), "velocity": vector(projectile.velocity), "damage": projectile.damage, "splash": projectile.splash, "source": projectile.source, "life": projectile.life, "gravity": projectile.gravity, "color": projectile.color.to_html(), "effects": effects})
	return result

static func valid(game, value: Variant) -> bool:
	if not value is Dictionary: return false
	for field in ["enemies", "projectiles", "queue"]:
		if not value.get(field) is Array: return false
	if value.projectiles.size() > 128 or value.queue.size() > 601: return false
	for field in ["next_uid", "kill_streak"]:
		if not game.profile.numeric(value.get(field), 0, 1e12) or value[field] != int(value[field]): return false
	for field in ["spawn_timer", "hazard_timer", "kill_timer"]:
		if not game.profile.numeric(value.get(field), -1e12, 1e12): return false
	if value.get("faction") not in ["None", "Disruptors", "Bulwark", "Artillery", "Purifiers", "Vanguard"]: return false
	for id in value.queue:
		if not id is String or not game.catalog.enemies.has(id): return false
	var reserve = value.get("reserve", {})
	if not reserve is Dictionary: return false
	var reserve_total = 0
	for id in reserve:
		var count = reserve[id]
		if not id is String or not game.catalog.enemies.has(id): return false
		if not game.profile.numeric(count, 0, 1e12) or count != int(count): return false
		reserve_total += int(count)
		if reserve_total > 1e12: return false
	var identities: Dictionary = {}
	for enemy in value.enemies:
		if not enemy is Dictionary or not enemy.get("type") is String or not game.catalog.enemies.has(enemy.type): return false
		if not game.profile.numeric(enemy.get("uid"), 1, value.next_uid) or enemy.uid != int(enemy.uid) or identities.has(int(enemy.uid)): return false
		identities[int(enemy.uid)] = true
		for field in ["position", "velocity", "steering"]:
			if not valid_vector(game, enemy.get(field)): return false
		if not game.profile.numeric(enemy.get("yaw"), -1e6, 1e6) or not enemy.get("elite") is bool: return false
		if enemy.get("ai") not in ["navigate", "attack"] or enemy.get("burn_source") not in ["weapon", "tower"]: return false
		for field in ENEMY_NUMBERS:
			if not game.profile.numeric(enemy.get(field), -1e12 if field.ends_with("timer") or field.ends_with("time") or field == "cooldown" else 0, 1e12): return false
		if enemy.health <= 0 or enemy.health > enemy.max_health or enemy.speed > 100 or enemy.armor > 0.8 or enemy.slow > 0.9 or enemy.blast_resist > 1 or enemy.status_resist > 1: return false
		if enemy.has("simulation_lag") and not game.profile.numeric(enemy.simulation_lag, 0, 1e12): return false
		for effect in ["burn", "poison", "slow"]:
			if enemy.has(effect + "_lag") and not game.profile.numeric(enemy[effect + "_lag"], 0, 1e12): return false
	for projectile in value.projectiles:
		if not projectile is Dictionary: return false
		for field in ["position", "velocity"]:
			if not valid_vector(game, projectile.get(field)): return false
		for field in ["damage", "splash", "life", "gravity"]:
			if not game.profile.numeric(projectile.get(field), 0, 1e12): return false
		if projectile.life <= 0 or projectile.life > 60 or projectile.splash > 100: return false
		if projectile.get("source") not in ["weapon", "enemy", "tower", "consumable", "ability", "proc"]: return false
		if not projectile.get("color") is String or not Color.html_is_valid(projectile.color): return false
		var effects = projectile.get("effects")
		if not effects is Dictionary or not effects.get("mods", []) is Array or effects.get("mods", []).size() > 3: return false
		for modifier in effects.get("mods", []):
			if modifier not in MODIFIERS: return false
		if effects.has("origin") and not valid_vector(game, effects.origin): return false
		if effects.has("elemental") and not effects.elemental is bool: return false
		if effects.has("elemental_rarity") and (not game.profile.numeric(effects.elemental_rarity, 0, 4) or effects.elemental_rarity != int(effects.elemental_rarity)): return false
	return true

static func restore(game, value: Dictionary) -> void:
	game.next_uid = int(value.next_uid)
	game.spawn_queue = value.queue.duplicate()
	game.spawn_reserve = value.get("reserve", {}).duplicate()
	game.spawn_timer = float(value.spawn_timer)
	game.hazard_timer = float(value.hazard_timer)
	game.kill_timer = float(value.kill_timer)
	game.kill_streak = int(value.kill_streak)
	game.faction_name = value.faction
	for item in value.enemies:
		var enemy = game.catalog.enemies[item.type].duplicate(true)
		for field in ENEMY_NUMBERS: enemy[field] = float(item[field])
		enemy.merge({"uid": int(item.uid), "type": item.type, "elite": item.elite, "ai": item.ai, "burn_source": item.burn_source, "steering": unpack(item.steering)}, true)
		if enemy.elite: enemy.color = "d1a5ef"
		enemy.node = game.visuals.enemy(enemy)
		enemy.node.position = unpack(item.position)
		enemy.node.velocity = unpack(item.velocity)
		enemy.node.rotation.y = item.yaw
		enemy.simulated_at = game.elapsed - float(item.get("simulation_lag", 0))
		for effect in ["burn", "poison", "slow"]:
			enemy[effect + "_at"] = game.elapsed - float(item.get(effect + "_lag", item.get("simulation_lag", 0)))
		game.enemies[enemy.uid] = enemy
		game.enemy_index.add(enemy.uid, enemy.node.position, enemy.type)
		if enemy.health < enemy.max_health: game.wounded_index.add(enemy.uid, enemy.node.position, enemy.type)
		game.visuals.enemy_renderer.sync(enemy.uid)
	for item in value.projectiles:
		var effects = item.effects.duplicate(true)
		if effects.has("origin"): effects.origin = unpack(effects.origin)
		var color = Color.html(item.color)
		var position = unpack(item.position)
		game.projectiles.append({"pos": position, "velocity": unpack(item.velocity), "damage": item.damage, "splash": item.splash, "source": item.source, "life": item.life, "gravity": item.gravity, "color": color, "effects": effects, "mesh": game.visuals.obtain_bolt(position, color)})
