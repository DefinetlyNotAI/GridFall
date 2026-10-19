extends RefCounted

static func wants_player_target(enemy: Dictionary, pos: Vector3, player_pos: Vector3, player_visible: bool) -> bool:
	if enemy.get("type", "") not in ["runner", "exploder"] or not player_visible:
		enemy.player_target = false
		return false
	var acquire_range = 18.0 if enemy.type == "runner" else 12.0
	var release_range = acquire_range + 3.0
	var limit = release_range if enemy.get("player_target", false) else acquire_range
	enemy.player_target = pos.distance_to(player_pos) <= limit
	return enemy.player_target

static func attack_visible(game: Variant, enemy: Dictionary, pos: Vector3, target: Vector3, target_kind: String, target_key: String) -> bool:
	var node: CharacterBody3D = enemy.get("node")
	if not is_instance_valid(node): return false
	var excluded: Array[RID] = [node.get_rid()]
	var hit: Dictionary = game.ray(pos + Vector3.UP * 1.2, target + Vector3.UP * 1.2, 5, excluded)
	if hit.is_empty(): return true
	var collider: Object = hit.get("collider")
	if not is_instance_valid(collider): return false
	match target_kind:
		"player": return collider == game.player
		"core": return collider.has_meta("core")
		"structure": return collider.has_meta("structure") and str(collider.get_meta("structure")) == target_key
		"tile": return collider.has_meta("tile") and str(collider.get_meta("tile")) == target_key
	return false

static func support_anchor(world: Variant, pos: Vector3, objective_pos: Vector3, wounded_positions: Array) -> Vector3:
	if wounded_positions.is_empty(): return objective_pos
	var center = Vector3.ZERO
	for ally_pos in wounded_positions:
		var ally_position: Vector3 = ally_pos
		center += ally_position
	center /= wounded_positions.size()
	var current_cell: Vector2i = world.cell(pos)
	var current_key: String = world.cell_key(current_cell)
	if pos.distance_to(center) <= 6.0 and world.map.layers.ground.get(current_key, {}).get("type", "") == "road" and not world.solid(current_cell):
		return pos
	var behind = center - objective_pos
	behind.y = 0
	if behind.length_squared() < 0.01:
		behind = center - pos
		behind.y = 0
	if behind.length_squared() > 0.01: behind = behind.normalized() * 3.0
	var desired = center + behind
	var origin: Vector2i = world.cell(desired)
	var best = objective_pos
	var best_distance = INF
	for y in range(origin.y - 1, origin.y + 2):
		for x in range(origin.x - 1, origin.x + 2):
			var cell = Vector2i(x, y)
			if not world.inside(cell) or world.solid(cell): continue
			var key: String = world.cell_key(cell)
			if world.map.layers.ground.get(key, {}).get("type", "") != "road": continue
			var candidate: Vector3 = world.position(cell)
			var distance = candidate.distance_squared_to(desired)
			if distance >= best_distance: continue
			best = candidate
			best_distance = distance
	return best

static func movement_waypoint(enemy: Dictionary, world: Variant, pos: Vector3, destination: Vector3, target_kind: String, target_key: String, delta: float, road_follow: bool) -> Vector3:
	var signature = target_kind + ":" + target_key
	if enemy.get("stuck_target", "") != signature:
		enemy.stuck_target = signature
		enemy.stuck_time = 0.0
		enemy.stuck_position = pos
		enemy.recovery_target = ""
		enemy.recovery_cell = ""
		return destination
	var previous: Vector3 = enemy.get("stuck_position", pos)
	if pos.distance_to(previous) >= 0.025:
		enemy.stuck_time = 0.0
		enemy.stuck_position = pos
	else:
		enemy.stuck_time = float(enemy.get("stuck_time", 0.0)) + maxf(0.0, delta)
	var current: Vector2i = world.cell(pos)
	var recovery_cell: String = str(enemy.get("recovery_cell", ""))
	if enemy.get("recovery_target", "") == signature and not recovery_cell.is_empty():
		if world.cell_key(current) == recovery_cell:
			enemy.recovery_target = ""
			enemy.recovery_cell = ""
			enemy.stuck_time = 0.0
		else:
			return world.position(world.point(recovery_cell))
	if float(enemy.get("stuck_time", 0.0)) < 0.45 or pos.distance_squared_to(destination) < 0.25:
		return destination
	var forward = destination - pos
	forward.y = 0
	if forward.length_squared() < 0.01: return destination
	var side = Vector3(-forward.z, 0, forward.x).normalized()
	var current_flow = float(world.flow.get(world.cell_key(current), INF)) if road_follow else 0.0
	var best_cell = current
	var best_score = INF
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var side_dot = Vector3(offset.x, 0, offset.y).dot(side)
		if absf(side_dot) < 0.6: continue
		var candidate_cell = current + offset
		if not world.inside(candidate_cell) or world.solid(candidate_cell): continue
		var candidate_key: String = world.cell_key(candidate_cell)
		var flow_cost = 0.0
		if road_follow:
			if world.map.layers.ground.get(candidate_key, {}).get("type", "") != "road": continue
			flow_cost = float(world.flow.get(candidate_key, INF))
			if flow_cost >= INF or flow_cost > current_flow + 8.0: continue
		var candidate: Vector3 = world.position(candidate_cell)
		var progress = candidate.distance_to(destination)
		if not road_follow and progress > pos.distance_to(destination) + 4.5: continue
		var score = flow_cost if road_follow else progress
		score += 0.001 if (int(enemy.get("uid", 0)) % 2 == 0) == (side_dot > 0) else 0.002
		if score >= best_score: continue
		best_score = score
		best_cell = candidate_cell
	if best_cell == current: return destination
	var waypoint: String = world.cell_key(best_cell)
	enemy.recovery_target = signature
	enemy.recovery_cell = waypoint
	return world.position(best_cell)
