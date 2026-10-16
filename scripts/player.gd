extends CharacterBody3D

var game
var camera: Camera3D
var gun: Node3D
var pitch = 0.0
var recoil = 0.0
var grounded = true
var steps = 0.0
var body_shape: CollisionShape3D
var crouched = false
var stamina = 100.0
var sprint_exhausted = false
var landing = 0.0
var motion_time = 0.0
var sway = Vector2.ZERO
var dash_energy = 3.0
var dash_timer = 0.0
var dash_direction = Vector3.ZERO
var slide_active = false
var slam_active = false
var wall_jumps = 0
var coyote_timer = 0.0
var jump_buffer = 0.0
var slam_jump_timer = 0.0
var horizontal_speed = 0.0
var impact_flash = 0.0

const RUN_SPEED = 12.0
const DASH_SPEED = 32.0
const DASH_DURATION = 0.16
const JUMP_SPEED = 10.0

func setup(owner_game) -> void:
	game = owner_game
	collision_layer = 4
	collision_mask = 1
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	body_shape = shape
	floor_snap_length = 0.4
	camera = Camera3D.new()
	camera.position.y = 1.65
	camera.near = 0.06
	camera.fov = game.profile.data.settings.fov
	add_child(camera)
	camera.current = true
	gun = Node3D.new()
	camera.add_child(gun)
	refresh_gun()

func refresh_gun() -> void:
	for child in gun.get_children():
		gun.remove_child(child)
		child.queue_free()
	if game.weapons.is_empty():
		return
	if game.weapons[game.active_weapon].id == "": return
	var definition = game.weapon_def()
	gun.position = Vector3(0.3, -0.28, -0.55)
	var color = Color(definition.color)
	game.visuals.box(gun, Vector3.ZERO, Vector3(0.18, 0.18, 0.65), Color("283d4b"))
	game.visuals.box(gun, Vector3(0, -0.12, 0.15), Vector3(0.12, 0.28, 0.14), Color("172630"))
	game.visuals.box(gun, Vector3(0, 0.1, -0.1), Vector3(0.06, 0.04, 0.25), color, 0.5)
	game.visuals.box(gun, Vector3(0, 0, -0.4), Vector3(0.09, 0.09, 0.3), Color("7b929b"))
	if game.weapons[game.active_weapon].id == "blade":
		game.visuals.box(gun, Vector3(0, 0.25, -0.4), Vector3(0.03, 0.6, 0.12), color, 1)

func _unhandled_input(event: InputEvent) -> void:
	if not game.playing() or game.state == "paused":
		return
	if event.is_action_pressed("heal"):
		game.consume("medkit")
		return
	if event.is_action_pressed("grenade"):
		game.consume("grenade")
		return
	if game.ui.overlay != "": return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity = float(game.profile.data.settings.sensitivity)
		rotate_y(-event.relative.x * sensitivity)
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.5, 1.5)
		if game.profile.data.settings.camera_motion: sway = (sway + event.relative * 0.00015).limit_length(0.015)
	if event.is_action_pressed("reload"):
		game.reload_weapon()
	if event.is_action_pressed("weapon1"):
		game.switch_weapon(0)
	if event.is_action_pressed("weapon2"):
		game.switch_weapon(1)
	if event.is_action_pressed("interact"):
		game.interact()
	if event.is_action_pressed("ability"):
		game.ability()
	if event.is_action_pressed("restoration"):
		game.restoration()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			game.switch_weapon(1 - game.active_weapon)

func begin_dash(direction: Vector3) -> bool:
	if dash_energy < 1 or dash_timer > 0: return false
	dash_energy -= 1
	dash_timer = DASH_DURATION
	dash_direction = direction.normalized()
	slam_active = false
	slide_active = false
	velocity.y = 0
	game.audio.cue("dash", global_position, 0.65)
	return true

func slam_impact(fall_speed: float) -> void:
	impact_flash = 1.0
	landing = 0.15
	slam_jump_timer = 0.18
	game.audio.cue("slam", global_position, 0.8)
	if game.state != "wave": return
	var damage = clampf(-fall_speed, 20, 60)
	for uid in game.enemies.keys():
		if game.enemies[uid].node.position.distance_squared_to(position) <= 25:
			game.damage_enemy(uid, damage, "ability")

func movement_snapshot() -> Dictionary:
	return {"energy": dash_energy, "dash": dash_timer, "direction": game.CombatSave.vector(dash_direction), "slide": slide_active, "slam": slam_active, "walls": wall_jumps, "coyote": coyote_timer, "jump": jump_buffer, "slam_jump": slam_jump_timer}

func restore_movement(value: Dictionary) -> void:
	dash_energy = float(value.get("energy", 3.0))
	dash_timer = float(value.get("dash", 0.0))
	dash_direction = game.CombatSave.unpack(value.get("direction", [0, 0, 0]))
	slide_active = value.get("slide", false)
	slam_active = value.get("slam", false)
	wall_jumps = int(value.get("walls", 0))
	coyote_timer = float(value.get("coyote", 0.0))
	jump_buffer = float(value.get("jump", 0.0))
	slam_jump_timer = float(value.get("slam_jump", 0.0))

func _physics_process(delta: float) -> void:
	if not game.playing() or game.state == "paused" or not is_instance_valid(camera):
		return
	var enabled = game.ui.overlay == "" and not game.autoplay
	var move = Input.get_vector("left", "right", "forward", "back") if enabled else Vector2.ZERO
	var direction = (transform.basis * Vector3(move.x, 0, move.y)).normalized()
	var was_grounded = is_on_floor()
	coyote_timer = 0.1 if was_grounded else maxf(0, coyote_timer - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	slam_jump_timer = maxf(0, slam_jump_timer - delta)
	dash_energy = minf(3, dash_energy + delta * 0.9)
	impact_flash = maxf(0, impact_flash - delta * 4)
	if was_grounded: wall_jumps = 0
	if enabled and Input.is_action_just_pressed("jump"): jump_buffer = 0.12
	if enabled and Input.is_action_just_pressed("sprint"):
		begin_dash(direction if move.length() > 0 else -transform.basis.z)
	if enabled and Input.is_action_just_pressed("crouch") and not was_grounded:
		slam_active = true
		dash_timer = 0
		slide_active = false
	if not enabled:
		dash_timer = 0
		slide_active = false
		slam_active = false
		jump_buffer = 0
	var speed = RUN_SPEED * (1 + game.bonus("movement"))
	if stamina <= 5: sprint_exhausted = true
	elif stamina >= 25: sprint_exhausted = false
	var crouch = enabled and Input.is_action_pressed("crouch")
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	var was_sliding = slide_active
	slide_active = crouch and was_grounded and horizontal.length_squared() > 36 and (not game.profile.data.settings.stamina or not sprint_exhausted) and dash_timer <= 0
	if game.profile.data.settings.stamina:
		stamina = clampf(stamina + delta * (-18 if slide_active else 22), 0, 100)
	if crouched and not crouch:
		crouch = not game.ray(global_position + Vector3.UP * 1.05, global_position + Vector3.UP * 1.85, 1).is_empty()
	if crouch != crouched:
		crouched = crouch
		body_shape.shape.height = 1.1 if crouched else 1.8
		body_shape.position.y = 0.55 if crouched else 0.9
	if crouch and not slide_active: speed *= 0.35
	var tile_key = game.world.cell_key(game.world.cell(position))
	var movement_cost = game.world.movement_cost(game.world.cell(position))
	if game.world.map.layers.objects.get(tile_key, {}).get("type") == "slow": movement_cost = maxf(2, movement_cost)
	speed /= movement_cost
	if slide_active and not was_sliding:
		horizontal = horizontal.normalized() * maxf(horizontal.length(), speed * 1.5)
		game.audio.cue("slide", global_position, 0.4)
	var jumped = false
	if jump_buffer > 0 and not slam_active:
		if coyote_timer > 0 or slam_jump_timer > 0:
			velocity.y = 16.0 if slam_jump_timer > 0 else JUMP_SPEED
			coyote_timer = 0
			slam_jump_timer = 0
			jumped = true
		elif is_on_wall() and wall_jumps < 3:
			var normal = get_wall_normal()
			normal.y = 0
			horizontal = normal.normalized() * 12 + direction * 5
			velocity.y = JUMP_SPEED
			wall_jumps += 1
			jumped = true
			game.audio.cue("wall_jump", global_position, 0.45)
		if jumped:
			jump_buffer = 0
			dash_timer = 0
			slide_active = false
	if dash_timer > 0:
		horizontal = dash_direction * DASH_SPEED * (1 + game.bonus("movement")) / movement_cost
		velocity.y = 0
		dash_timer = maxf(0, dash_timer - delta)
	elif slide_active:
		var slide_direction = horizontal.normalized()
		if direction.length_squared() > 0:
			slide_direction = slide_direction.lerp(direction, delta * 2).normalized()
		horizontal = slide_direction * move_toward(horizontal.length(), speed, delta * 2.5 * movement_cost)
	elif was_grounded and not jumped:
		horizontal = horizontal.move_toward(direction * speed, 100 * delta)
	else:
		var along = horizontal.dot(direction)
		if along < speed:
			horizontal += direction * minf(30 * delta, speed - along)
		horizontal = horizontal.limit_length(DASH_SPEED * (1 + game.bonus("movement")))
	if slam_active:
		horizontal = horizontal.move_toward(Vector3.ZERO, 45 * delta)
		velocity.y = -42
	elif dash_timer <= 0 and not was_grounded and not jumped:
		velocity.y = maxf(-52, velocity.y - 28 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var fall_speed = velocity.y
	move_and_slide()
	horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if is_on_wall(): dash_timer = 0
	if not was_grounded and is_on_floor():
		if slam_active: slam_impact(fall_speed)
		elif fall_speed < -5: landing = minf(0.1, -fall_speed * 0.003)
		slam_active = false
	if position.y < -20:
		if game.state == "wave": game.damage_player(1000000, true)
		else:
			position = game.world.position(game.world.marker("player"), 0.1)
			velocity = Vector3.ZERO
			game.ui.notify("Returned to spawn after falling outside the world.")
	camera.position.y = lerpf(camera.position.y, 1.0 if crouched else 1.65, 12 * delta)
	landing = move_toward(landing, 0, delta * 0.3)
	if game.profile.data.settings.camera_motion:
		motion_time += delta * 12 * move.length()
		camera.position.y += (sin(motion_time) * 0.003 if is_on_floor() else 0) - landing * delta * 5
	var aiming = enabled and Input.is_action_pressed("aim")
	var effects = game.profile.data.settings.get("movement_effects", true)
	var speed_fov = clampf((horizontal_speed - RUN_SPEED) * 0.8, 0, 16) if effects else 0.0
	camera.fov = lerpf(camera.fov, minf(135, float(game.profile.data.settings.fov) * (0.75 if aiming else 1.0) + speed_fov), 12 * delta)
	var roll = -move.x * (0.045 if slide_active else 0.02) if effects and enabled else 0.0
	camera.rotation.z = lerpf(camera.rotation.z, roll, delta * 10)
	recoil = move_toward(recoil, 0, delta * 0.25)
	camera.rotation.x = pitch + recoil
	sway = sway.lerp(Vector2.ZERO, delta * 10)
	gun.position = gun.position.lerp(Vector3((0.08 if aiming else 0.3) + sway.x, (-0.22 if aiming else -0.28) - sway.y, -0.55 + recoil), delta * 12)
	if enabled and Input.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		game.fire()
	steps += direction.length() * delta
	if steps > 0.45 and is_on_floor():
		steps = 0
		game.audio.cue("step", global_position, 0.15)
