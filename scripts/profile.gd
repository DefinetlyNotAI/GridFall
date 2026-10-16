extends RefCounted

const PATH = "user://profile.json"
var data: Dictionary = {}
var error = ""

func defaults() -> Dictionary:
	return {"version": 1, "tp": 0, "research": {}, "awarded": [], "runs": 0, "kills": 0, "best": 0, "bosses": 0, "settings": {"sensitivity": 0.002, "fov": 82.0, "volume": 0.6, "music": 0.25, "fullscreen": false, "vsync": true, "fps": 120, "quality": 1, "hud_scale": 1.0, "crosshair": true, "shake": true, "keys": {}}, "loadout": "rifle"}

func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1:
		return false
	if not value.get("tp") is float and not value.get("tp") is int:
		return false
	if not is_finite(float(value.tp)) or value.tp < 0 or value.tp > 1e12:
		return false
	if not value.get("research") is Dictionary or not value.get("awarded") is Array or not value.get("settings") is Dictionary:
		return false
	for key in value.research:
		if not key is String or not numeric(value.research[key], 0, 10): return false
	for id in value.awarded:
		if not id is String: return false
	for key in ["runs", "kills", "best", "bosses"]:
		if value.has(key) and not numeric(value[key], 0, 1e15): return false
	if value.has("loadout") and not value.loadout is String: return false
	var settings = value.settings
	if settings.has("keys"):
		if not settings.keys is Dictionary: return false
		for key in settings.keys:
			if not key is String or not numeric(settings.keys[key], 1, 2147483647): return false
	for key in ["fullscreen", "vsync", "crosshair", "shake"]:
		if settings.has(key) and not settings[key] is bool: return false
	var ranges = {"sensitivity": [0.0001, 0.02], "fov": [50, 120], "volume": [0, 1], "music": [0, 1], "fps": [30, 360], "quality": [0, 1], "hud_scale": [0.75, 1.5]}
	for key in ranges:
		if settings.has(key) and not numeric(settings[key], ranges[key][0], ranges[key][1]): return false
	return true

func numeric(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

func load_profile() -> void:
	data = defaults()
	for path in [PATH, PATH + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var value = JSON.parse_string(FileAccess.get_file_as_string(path))
		if valid(value):
			data.merge(value, true)
			var settings = defaults().settings
			settings.merge(data.settings, true)
			data.settings = settings
			if path.ends_with(".bak"):
				error = "Recovered profile from backup."
			return
		error = "Unreadable profile; original preserved. Backup recovery attempted."

func save() -> bool:
	var file = FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Cannot write profile: " + error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(PATH):
		var old = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if valid(old):
			var copied = DirAccess.copy_absolute(PATH, PATH + ".bak")
			if copied != OK:
				error = "Could not preserve profile backup."
				return false
	var result = DirAccess.rename_absolute(PATH + ".tmp", PATH)
	if result != OK:
		error = "Could not replace profile: " + error_string(result)
	return result == OK

func rank(id: String) -> int:
	return clampi(int(data.research.get(id, 0)), 0, 10)

func purchase(node: Dictionary) -> String:
	var current = rank(node.id)
	if current >= node.max_rank:
		return "Already fully researched."
	for required in node.requires:
		if rank(required) == 0:
			return "Requires " + required.capitalize() + "."
	var cost = int(node.cost * (current + 1))
	if data.tp < cost:
		return "Not enough Technology Points."
	var before = data.duplicate(true)
	data.tp -= cost
	data.research[node.id] = current + 1
	if not save():
		data = before
		return error
	return ""

func award(id: String, stats: Dictionary, eligible: bool) -> int:
	if id in data.awarded or not eligible:
		return 0
	var reward = int(minf(1e9, floor((3.0 * pow(minf(stats.wave, 1e6), 1.35) + 0.04 * stats.kills + 12.0 * stats.bosses) * stats.difficulty)))
	var before = data.duplicate(true)
	data.tp = minf(1e12, data.tp + reward)
	data.awarded.append(id)
	data.runs += 1
	data.kills += stats.kills
	data.bosses += stats.bosses
	data.best = maxi(int(data.best), stats.wave)
	if not save():
		data = before
		return -1
	return reward
