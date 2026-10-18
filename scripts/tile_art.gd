extends RefCounted

static var cache: Dictionary = {}

static func icon(kind: String) -> Texture2D:
	if cache.has(kind): return cache[kind]
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var ink = Color("a9c5cf")
	if kind in ["objective", "pad", "tower_pad", "structure_pad", "supply", "ammo", "generator", "chest", "shop", "upgrade"]: ink = Color("79d9c7")
	if kind in ["fire", "acid", "spikes", "electric", "mine", "enemy"]: ink = Color("ef9e72")
	if kind in ["vegetation", "grass", "slow"]: ink = Color("91bf8c")
	for y in range(3, 29):
		for x in range(3, 29):
			var p = Vector2(x - 15.5, y - 15.5)
			var mark = false
			match kind:
				"road": mark = absf(p.x) > 9 or absf(p.x) < 1.5 and y % 12 < 7
				"water": mark = absi(y - (9 + int(sin(x * 0.4) * 2))) < 2 or absi(y - (21 + int(sin(x * 0.4) * 2))) < 2
				"grass", "vegetation": mark = absf(p.x) < 1.5 or absf(absf(p.x) - (26 - y) * 0.55) < 1.5 and y > 10 and y < 25
				"dirt", "sand", "stone", "concrete", "metal": mark = y % 8 < 2 or x % 12 < 2 and y % 8 < 6
				"player": mark = p.y > -10 and p.y < 10 and absf(p.x) < (p.y + 10) * 0.5
				"objective": mark = absf(p.x) + absf(p.y) < 11 and absf(p.x) + absf(p.y) > 7 or absf(p.x) < 2 and absf(p.y) < 3
				"enemy": mark = absf(p.x) > 8 and absf(p.y) < 12 or absf(p.y) > 9 and absf(p.x) < 11
				"pad", "tower_pad", "structure_pad": mark = absf(p.x) > 9 or absf(p.y) > 9 or (kind == "tower_pad" and absf(p.x) < 2) or (kind == "structure_pad" and absf(p.y) < 2)
				"fire": mark = absf(p.x) < 10 - absf(p.y) * 0.45 and p.y > -9 and (p.y > 0 or p.x < 1)
				"acid", "slow": mark = p.length() < 10 and (p.y > 2 or absf(p.x) > 5 or p.y < -6)
				"electric", "generator": mark = p.y < 0 and p.x > -5 and p.x < 4 + p.y * 0.35 or p.y >= 0 and p.x < 5 and p.x > -4 + p.y * 0.35
				"spikes": mark = y > 8 and y < 26 and absi((x % 10) - 5) < (y - 8) / 4
				"mine": mark = p.length() < 8 or absf(p.x) < 2 or absf(p.y) < 2
				"ramp", "stairs": mark = p.y > 8 - (p.x + 12) * 0.65 and p.y < 11
				"door", "gate": mark = absf(p.x) > 9 or p.y < -9 or p.x > 4 and p.x < 7 and absf(p.y) < 2
				"window", "glass": mark = absf(p.x) > 9 or absf(p.y) > 9 or absf(p.x) < 1.5 or absf(p.y) < 1.5
				"pipe", "pillar": mark = absf(p.x) < 5 or absf(p.y) > 8
				"light": mark = p.length() > 5 and p.length() < 9 or absf(p.x) < 2 and p.y > 6
				"supply", "upgrade": mark = absf(p.x) < 3 or absf(p.y) < 3
				"ammo": mark = absf(p.x) < 8 and p.y > -7 and p.y < 10 and x % 7 < 4
				"shop", "chest", "crate": mark = absf(p.x) > 9 or absf(p.y) > 9 or absf(p.y) < 1.5 or kind == "crate" and absf(p.x - p.y) < 2
				"machinery": mark = absf(p.x) > 8 or absf(p.y) > 8 or p.length() < 5
				"debris": mark = p.x + p.y > 3 and absf(p.x) < 10 and p.y < 9
				"ceiling", "elevation", "platform": mark = absf(p.y) < 2 or absf(p.x) > 9 and p.y > 0
				_: mark = absf(p.y) > 9 or y % 9 < 2 or x % 11 < 2
			if mark: image.set_pixel(x, y, ink)
	var texture = ImageTexture.create_from_image(image)
	cache[kind] = texture
	return texture
