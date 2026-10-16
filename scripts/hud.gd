extends Control

var game
var hit_flash = 0.0
var hurt_flash = 0.0
var boss_ratio = -1.0

func _draw() -> void:
	if game == null or not game.playing() or game.ui.overlay != "": return
	var center = size * 0.5
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
