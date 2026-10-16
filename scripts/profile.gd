extends RefCounted

const PATH = "user://profile.json"
const ASCENSION_PERKS = {
	"dual_loadout": {"name": "Paired arsenal", "description": "Choose a researched starting secondary weapon.", "max_rank": 1},
	"pulse_matrix": {"name": "Restoration matrix", "description": "Unlock a second ability: restore 25 health and repair nearby defenses by 35 per rank. 30-second cooldown.", "max_rank": 3},
	"tower_evolution": {"name": "Resonant architecture", "description": "Unlock the Resonant tower evolution: stronger, faster attacks chain to a second target.", "max_rank": 1},
	"mutation": {"name": "Inherited mutation", "description": "Choose a starting mutation: health, firing speed, or salvage. Strength increases per rank.", "max_rank": 3}
}
var data: Dictionary = {}
var error = ""

func defaults() -> Dictionary:
	return {"version": 1, "tp": 0, "research": {}, "awarded": [], "runs": 0, "kills": 0, "best": 0, "bosses": 0, "high_score": 0, "survival_time": 0, "achievements": {}, "ascensions": 0, "cores": 0, "ascension_perks": {}, "secondary_loadout": "pistol", "mutation": "vitality", "settings": {"sensitivity": 0.002, "fov": 82.0, "volume": 0.6, "music": 0.25, "fullscreen": false, "resolution": 0, "vsync": true, "fps": 120, "quality": 1, "enemy_cap": 100, "hud_scale": 1.0, "crosshair": true, "shake": true, "adaptive": true, "weather": true, "camera_motion": false, "movement_effects": true, "stamina": false, "visual_mode": 0, "advanced_lighting": false, "keys": {}}, "loadout": "rifle"}

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
	for key in ["runs", "kills", "best", "bosses", "high_score", "survival_time"]:
		if value.has(key) and not numeric(value[key], 0, 1e15): return false
	if value.has("loadout") and not value.loadout is String: return false
	if value.has("profile_id") and (not value.profile_id is String or value.profile_id.length() != 32 or not value.profile_id.is_valid_hex_number(false)): return false
	for key in ["ascensions", "cores"]:
		if value.has(key) and not numeric(value[key], 0, 1000000): return false
	if value.has("secondary_loadout") and not value.secondary_loadout is String: return false
	if value.has("mutation") and value.mutation not in ["vitality", "overclock", "salvage"]: return false
	if value.has("ascension_perks"):
		if not value.ascension_perks is Dictionary: return false
		for key in value.ascension_perks:
			if not ASCENSION_PERKS.has(key) or not numeric(value.ascension_perks[key], 0, ASCENSION_PERKS[key].max_rank): return false
	if value.has("achievements"):
		if not value.achievements is Dictionary: return false
		for key in value.achievements:
			if not key is String or not value.achievements[key] is bool: return false
	var settings = value.settings
	if settings.has("keys"):
		if not settings.keys is Dictionary: return false
		for key in settings.keys:
			if not key is String or not numeric(settings.keys[key], 1, 2147483647): return false
	for key in ["fullscreen", "vsync", "crosshair", "shake", "adaptive", "weather", "camera_motion", "movement_effects", "stamina", "advanced_lighting", "respec_enabled"]:
		if settings.has(key) and not settings[key] is bool: return false
	var ranges = {"sensitivity": [0.0001, 0.02], "fov": [50, 120], "volume": [0, 1], "music": [0, 1], "fps": [30, 360], "quality": [0, 1], "resolution": [0, 2], "enemy_cap": [25, 250], "hud_scale": [0.75, 1.5], "visual_mode": [0, 2]}
	for key in ranges:
		if settings.has(key) and not numeric(settings[key], ranges[key][0], ranges[key][1]): return false
	return true

func numeric(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

func respec(nodes: Array) -> String:
	if not data.settings.get("respec_enabled", true): return "Research respec is disabled in settings."
	var refund = int(invested_tp(nodes) * 0.9)
	if data.research.is_empty(): return "No ordinary research to reset."
	var before = data.duplicate(true)
	data.tp = minf(1e12, data.tp + refund)
	data.research.clear()
	data.loadout = "rifle"
	data.secondary_loadout = "pistol"
	if not save():
		data = before
		return error
	return ""

func load_profile() -> void:
	data = defaults()
	data.profile_id = Crypto.new().generate_random_bytes(16).hex_encode()
	for path in [PATH, PATH + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var value = JSON.parse_string(FileAccess.get_file_as_string(path))
		if valid(value):
			data.merge(value, true)
			var settings = defaults().settings
			settings.merge(data.settings, true)
			data.settings = settings
			if not data.settings.has("respec_enabled"): data.settings.respec_enabled = true
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
		elif DirAccess.copy_absolute(PATH, PATH + ".corrupt-" + str(Time.get_ticks_usec())) != OK:
			error = "Could not preserve the damaged profile."
			return false
	var result = DirAccess.rename_absolute(PATH + ".tmp", PATH)
	if result != OK:
		error = "Could not replace profile: " + error_string(result)
	return result == OK

func rank(id: String) -> int:
	return clampi(int(data.research.get(id, 0)), 0, 10)

func perk(id: String) -> int:
	return int(data.ascension_perks.get(id, 0))

func invested_tp(nodes: Array) -> int:
	var total = 0
	for node in nodes:
		var ranks = mini(rank(node.id), int(node.max_rank))
		total += int(node.cost * ranks * (ranks + 1) / 2)
	return total

func ascension_reward(nodes: Array) -> int:
	if data.best < 25 or data.research.size() < 20: return 0
	return maxi(1, int(sqrt((invested_tp(nodes) + data.tp) / 1000.0)))

func ascend(nodes: Array) -> String:
	var reward = ascension_reward(nodes)
	if reward <= 0: return "Reach wave 25 and research 20 technologies before ascending."
	var before = data.duplicate(true)
	data.cores += reward
	data.ascensions += 1
	data.tp = 0
	data.research.clear()
	data.loadout = "rifle"
	data.secondary_loadout = "pistol"
	data.achievements["Ascendant"] = true
	if not save():
		data = before
		return error
	return ""

func purchase_perk(id: String) -> String:
	if not ASCENSION_PERKS.has(id): return "Unknown Ascension research."
	var current = perk(id)
	if current >= ASCENSION_PERKS[id].max_rank: return "Already fully researched."
	if data.cores < current + 1: return "Not enough Ascension Cores."
	var before = data.duplicate(true)
	data.cores -= current + 1
	data.ascension_perks[id] = current + 1
	if not save():
		data = before
		return error
	return ""

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
	var reward = int(minf(1e9, floor((3.0 * pow(minf(stats.get("reward_wave", stats.wave), 1e6), 1.35) + 0.04 * stats.kills + 12.0 * stats.bosses) * stats.difficulty)))
	var before = data.duplicate(true)
	data.tp = minf(1e12, data.tp + reward)
	data.awarded.append(id)
	data.runs += 1
	data.kills += stats.kills
	data.bosses += stats.bosses
	data.best = maxi(int(data.best), stats.wave)
	data.high_score = maxf(data.high_score, float(stats.get("score", 0)))
	data.survival_time += float(stats.get("duration", 0))
	for achievement in stats.get("achievements", []): data.achievements[achievement] = true
	if not save():
		data = before
		return -1
	return reward
