extends Control

var game
var hit_flash = 0.0
var hurt_flash = 0.0
var boss_ratio = -1.0

func _draw() -> void:
	if game == null or not game.playing() or game.ui.overlay != "": return
	var center = size * 0.5
	if game.spectator:
		draw_circle(center, 1.5, Color("c8d7dc"))
		return
	var player = game.player
	var movement_effects = bool(game.profile.data.settings.get("movement_effects", true))
	if movement_effects:
		_draw_movement_effects(player, center)
	var ui = game.ui
	_draw_readout_backing(ui.hud_top, Color("6bd8c6"), 240, 14)
	_draw_readout_backing(ui.hud_left, Color("6bd8c6"), 220, 23)
	var has_ammo = not game.weapons.is_empty() and game.magazine_size(game.weapons[game.active_weapon]) > 0
	_draw_readout_backing(ui.hud_right, Color("f1c784"), 250 if has_ammo else 0, 20 if has_ammo else 0)
	_draw_readout_backing(ui.hints, Color("6bd8c6"))
	if boss_ratio >= 0:
		_draw_readout_backing(ui.boss_label, Color("bc91d8"), 340, 16)
		var boss_size = ui.boss_label.get_combined_minimum_size()
		var boss_origin = _readout_position(ui.boss_label, 340)
		_draw_meter(boss_origin + Vector2(8, boss_size.y + 7), 324, boss_ratio, Color("bc91d8"), 5.0)
	_draw_status_bars()
	if game.profile.data.settings.crosshair:
		var color = Color("ffd28a") if game.ui.hit_flash > 0 else Color("e6ecec")
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + d * 5, center + d * 11, color, 1.5)
		if game.ui.hit_flash > 0:
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(center + d * 12, center + d * 17, color, 2)
	if game.ui.hurt_flash > 0:
		var alpha = game.ui.hurt_flash * 0.7
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.12, 0.07, alpha), false, 12)
	_draw_dash_bars(float(player.get("dash_energy")))

func _readout_position(label: Label, minimum_width: float = 0.0) -> Vector2:
	var content_size = label.get_combined_minimum_size()
	var width = maxf(minimum_width, content_size.x)
	if label.size.x > 0:
		width = minf(width, label.size.x)
	var origin = label.position
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT and label.size.x > 0:
		origin.x += label.size.x - width
	elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and label.size.x > 0:
		origin.x += (label.size.x - width) * 0.5
	return origin

func _draw_readout_backing(label: Label, accent: Color, minimum_width: float = 0.0, extra_height: float = 0.0) -> void:
	if not is_instance_valid(label) or not label.visible or label.text.is_empty(): return
	var content_size = label.get_combined_minimum_size()
	var origin = _readout_position(label, minimum_width)
	var width = maxf(minimum_width, content_size.x)
	if label.size.x > 0:
		width = minf(width, label.size.x)
	var height = content_size.y + extra_height
	if label.size.y > 0:
		height = minf(height, label.size.y)
	var rect = Rect2(origin - Vector2(8, 6), Vector2(width + 16, height + 12))
	draw_rect(rect, Color(0.025, 0.042, 0.052, 0.86))
	var rail = accent
	rail.a = 0.92
	draw_rect(Rect2(rect.position, Vector2(2, rect.size.y)), rail)
	draw_rect(rect, Color(0.28, 0.38, 0.42, 0.58), false, 1.0)

func _draw_meter(position: Vector2, width: float, ratio: float, fill: Color, height: float = 4.0) -> void:
	var rect = Rect2(position, Vector2(width, height))
	draw_rect(rect, Color(0.07, 0.105, 0.125, 0.98))
	var value = clampf(ratio, 0.0, 1.0)
	if value > 0:
		draw_rect(Rect2(position, Vector2(width * value, height)), fill)
	draw_rect(rect, Color("59717a"), false, 1.0)

func _draw_status_bars() -> void:
	var ui = game.ui
	var top_size = ui.hud_top.get_combined_minimum_size()
	var top_origin = _readout_position(ui.hud_top, 240)
	var core_ratio = float(game.core_health) / maxf(1.0, float(game.max_core))
	if game.mode != "campaign": _draw_meter(top_origin + Vector2(8, top_size.y + 7), 224, core_ratio, Color("6bd8c6"), 4.0)

	var left_size = ui.hud_left.get_combined_minimum_size()
	var left_origin = _readout_position(ui.hud_left, 220)
	var health_ratio = float(game.health) / maxf(1.0, float(game.max_health))
	var health_color = Color("e88773") if health_ratio < 0.25 else (Color("edc27d") if health_ratio < 0.5 else Color("6bd8c6"))
	_draw_meter(left_origin + Vector2(8, left_size.y + 7), 204, health_ratio, health_color, 4.0)
	if game.mode == "campaign": return
	var ability_cooldown = maxf(0.1, 18.0 / (1 + game.bonus("ability")) * (1 - game.bonus("ability_rate")))
	var ability_ratio = 1.0 - clampf(float(game.ability_timer) / ability_cooldown, 0.0, 1.0)
	var ability_color = Color("6bd8c6") if game.ability_timer <= 0 else Color("b5a17d")
	_draw_meter(left_origin + Vector2(8, left_size.y + 14), 204, ability_ratio, ability_color, 3.0)

	if game.weapons.is_empty(): return
	var weapon = game.weapons[game.active_weapon]
	var magazine = game.magazine_size(weapon)
	if magazine <= 0: return
	var right_size = ui.hud_right.get_combined_minimum_size()
	var right_origin = _readout_position(ui.hud_right, 250)
	var meter_position = right_origin + Vector2(8, right_size.y + 7)
	var ammo_ratio = float(weapon.ammo) / float(magazine)
	var ammo_color = Color("ed9877") if ammo_ratio < 0.2 else Color("f1c784")
	_draw_meter(meter_position, 234, ammo_ratio, ammo_color, 4.0)
	if game.reload_timer > 0:
		var reload_length = maxf(0.01, float(game.weapon_stats(weapon).reload))
		var reload_progress = 1.0 - clampf(float(game.reload_timer) / reload_length, 0.0, 1.0)
		_draw_meter(meter_position + Vector2(0, 7), 234, reload_progress, Color("6bd8c6"), 3.0)

func _draw_dash_bars(energy: float) -> void:
	var width = 34.0
	var gap = 7.0
	var height = 8.0
	var total_width = width * 3 + gap * 2
	var origin = Vector2((size.x - total_width) * 0.5, size.y - 108)
	for index in 3:
		var rect = Rect2(origin + Vector2(index * (width + gap), 0), Vector2(width, height))
		draw_rect(rect, Color("20303b"))
		var fill = clampf(energy - index, 0.0, 1.0)
		if fill > 0:
			draw_rect(Rect2(rect.position, Vector2(width * fill, height)), Color("6bd8c6"))
		draw_rect(rect, Color("59717a"), false, 1.0)

func _draw_movement_effects(player, center: Vector2) -> void:
	var speed = float(player.get("horizontal_speed"))
	var dash = clampf(float(player.get("dash_timer")) / 0.16, 0.0, 1.0)
	var slam = bool(player.get("slam_active"))
	var impact = clampf(float(player.get("impact_flash")), 0.0, 1.0)
	var intensity = maxf(maxf(clampf((speed - 12.0) / 13.0, 0.0, 1.0), dash), 0.9 if slam else 0.0)
	if speed > 12.0 or dash > 0.0 or slam:
		var line_count = clampi(int(5 + intensity * 15), 5, 20)
		var clock = float(Time.get_ticks_msec()) * 0.001
		var color = Color("ffd28a") if dash > 0.0 or slam else Color("6bd8c6")
		for index in line_count:
			var phase = fposmod(float(index) * 0.618 + clock * (0.9 + intensity), 1.0)
			var side = index % 4
			var length = 12.0 + intensity * 44.0
			var point: Vector2
			var end: Vector2
			match side:
				0:
					point = Vector2(phase * size.x, 0)
					end = point + Vector2((0.5 - phase) * length * 0.35, length)
				1:
					point = Vector2(size.x, phase * size.y)
					end = point - Vector2(length, (phase - 0.5) * length * 0.35)
				2:
					point = Vector2(phase * size.x, size.y)
					end = point - Vector2((0.5 - phase) * length * 0.35, length)
				_:
					point = Vector2(0, phase * size.y)
					end = point + Vector2(length, (phase - 0.5) * length * 0.35)
			color.a = 0.14 + intensity * 0.32
			draw_line(point, end, color, 1.0 + intensity * 1.2)
	if impact > 0.0:
		var flash = minf(impact * 0.18, 0.18)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.67, 0.32, flash))
		var radius = 24.0 + (1.0 - impact) * minf(size.x, size.y) * 0.28
		var ring_color = Color(1.0, 0.76, 0.43, impact * 0.75)
		draw_arc(center, radius, 0.0, TAU, 48, ring_color, 2.0 + impact * 2.0, true)
