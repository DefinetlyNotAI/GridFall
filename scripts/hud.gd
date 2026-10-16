extends Control

var game
var hit_flash = 0.0
var hurt_flash = 0.0
var boss_ratio = -1.0

func _draw() -> void:
	if game == null or not game.playing() or game.ui.overlay != "": return
	var center = size * 0.5
	var player = game.player
	var movement_effects = bool(game.profile.data.settings.get("movement_effects", true))
	if boss_ratio >= 0:
		draw_rect(Rect2(Vector2(30, 170), Vector2(330, 6)), Color("20303b"))
		draw_rect(Rect2(Vector2(30, 170), Vector2(330 * boss_ratio, 6)), Color("bc91d8"))
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
	if movement_effects:
		_draw_movement_effects(player, center)

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
