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

func _physics_process(delta: float) -> void:
	if not game.playing() or game.state == "paused" or not is_instance_valid(camera):
		return
	var enabled = game.ui.overlay == "" and not game.autoplay
	var move = Input.get_vector("left", "right", "forward", "back") if enabled else Vector2.ZERO
	var direction = (transform.basis * Vector3(move.x, 0, move.y)).normalized()
	var speed = 6.5
	if stamina <= 5: sprint_exhausted = true
	elif stamina >= 25: sprint_exhausted = false
	var sprinting = enabled and Input.is_action_pressed("sprint") and move.length() > 0 and (not game.profile.data.settings.stamina or not sprint_exhausted)
	if sprinting:
		speed = 10
	if game.profile.data.settings.stamina:
		stamina = clampf(stamina + delta * (-18 if sprinting else 22), 0, 100)
	var crouch = enabled and Input.is_action_pressed("crouch")
	if crouched and not crouch:
		crouch = not game.ray(global_position + Vector3.UP * 1.05, global_position + Vector3.UP * 1.85, 1).is_empty()
	if crouch != crouched:
		crouched = crouch
		body_shape.shape.height = 1.1 if crouched else 1.8
		body_shape.position.y = 0.55 if crouched else 0.9
	if crouch:
		speed = 3.4
	speed *= 1 + game.bonus("movement")
	var tile_key = game.world.cell_key(game.world.cell(position))
	var movement_cost = game.world.movement_cost(game.world.cell(position))
	if game.world.map.layers.objects.get(tile_key, {}).get("type") == "slow": movement_cost = maxf(2, movement_cost)
	speed /= movement_cost
	velocity.x = move_toward(velocity.x, direction.x * speed, 35 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 35 * delta)
	if not is_on_floor():
		velocity.y -= 22 * delta
	elif enabled and Input.is_action_just_pressed("jump"):
		velocity.y = 8
	var was_grounded = is_on_floor()
	var fall_speed = velocity.y
	move_and_slide()
	if not was_grounded and is_on_floor() and fall_speed < -5: landing = minf(0.08, -fall_speed * 0.003)
	if position.y < -20:
		if game.state == "wave": game.damage_player(1000000)
		else:
			position = game.world.position(game.world.marker("player"), 0.1)
			velocity = Vector3.ZERO
			game.ui.notify("Returned to spawn after falling outside the world.")
	camera.position.y = lerpf(camera.position.y, 1.0 if crouch else 1.65, 12 * delta)
	landing = move_toward(landing, 0, delta * 0.3)
	if game.profile.data.settings.camera_motion:
		motion_time += delta * (14 if sprinting else 9) * move.length()
		camera.position.y += (sin(motion_time) * 0.003 if is_on_floor() else 0) - landing * delta * 5
	var aiming = enabled and Input.is_action_pressed("aim")
	camera.fov = lerpf(camera.fov, float(game.profile.data.settings.fov) * (0.75 if aiming else 1.0), 12 * delta)
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
