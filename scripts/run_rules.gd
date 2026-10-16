extends RefCounted

const MODES = {
	"endless": {"name": "Endless Defense", "description": "Standard endless defense.", "difficulty": 1.0},
	"seeded": {"name": "Seeded Survival", "description": "Reproducible world and wave seed.", "difficulty": 1.0},
	"challenge": {"name": "Challenge Defense", "description": "Configure rule modifiers before deployment. TP multiplier reflects their combined difficulty.", "difficulty": 1.35},
	"siege": {"name": "Siege Protocol", "description": "Unlock at wave 20. Start at wave 20 with 1,500 scrap and open approaches; +25% threat. TP uses waves survived.", "difficulty": 1.5},
	"scavenger": {"name": "Scavenger", "description": "Half starting reserves, no free ammunition; supplies cost 50% more. 25% extra TP.", "difficulty": 1.25},
	"daily": {"name": "Daily Defense", "description": "A shared UTC daily seed and world. Research applies; no online leaderboard.", "difficulty": 1.1},
	"sandbox": {"name": "Sandbox", "description": "Unlimited scrap, all equipment; no permanent rewards.", "difficulty": 0.0}
}
const CAPS = {"damage": 3.0, "fire_rate": 2.0, "reload": 2.0, "range": 1.5, "critical": 0.45, "armor": 0.65, "health": 500.0, "regen": 8.0, "shield": 300.0, "core_health": 3000.0, "scrap": 2000.0, "capacity": 80.0, "discount": 0.5, "loot": 0.3, "tower_damage": 3.0, "tower_rate": 2.0, "tower_range": 1.5, "repair_efficiency": 0.65, "lifesteal": 0.08, "burn": 20.0, "freeze": 0.5, "poison": 15.0, "chain": 0.5, "explosive": 0.5, "projectiles": 2.0, "core_armor": 0.65, "core_shield": 300.0, "ability_power": 3.0, "ability_rate": 0.65, "supply": 0.6, "production": 2.0, "penetration": 0.6, "status_resist": 0.75, "movement": 0.35}

const CHALLENGES = {
	"frail": {"name": "Starting player health reduced to 65%", "weight": 0.15},
	"fast": {"name": "Faster enemies (+25%)", "weight": 0.1},
	"no_repair": {"name": "No structure or core repairs", "weight": 0.1},
	"scarce_ammo": {"name": "Half reserves; no free wave ammunition", "weight": 0.1},
	"pads_only": {"name": "Build only on marked pads", "weight": 0.15},
	"ballistics_only": {"name": "Ballistic firearms only", "weight": 0.1},
	"acid_rain": {"name": "Acid rain on every wave", "weight": 0.1}
}
const CHALLENGE_PADS = [Vector2i(11, 3), Vector2i(13, 3), Vector2i(11, 5), Vector2i(13, 5), Vector2i(11, 8), Vector2i(13, 8), Vector2i(10, 11), Vector2i(14, 11), Vector2i(10, 13), Vector2i(14, 13), Vector2i(10, 15), Vector2i(14, 15)]

static func daily_seed() -> int:
	return absi(str(Time.get_datetime_string_from_system(true).substr(0, 10)).hash()) % 2147483646 + 1

static func faction(stats: Dictionary, next_wave: int, enabled: bool) -> String:
	if not enabled or next_wave < 12: return "None"
	var total = maxf(1, float(stats.get("damage", 0)))
	if float(stats.get("tower_damage", 0)) / total > 0.55: return "Disruptors"
	if float(stats.get("explosive_damage", 0)) / total > 0.35: return "Bulwark"
	if float(stats.get("close_damage", 0)) / total > 0.35: return "Artillery"
	if float(stats.get("elemental_damage", 0)) / total > 0.3: return "Purifiers"
	return "Vanguard"

static func favored(faction_name: String) -> String:
	return {"Disruptors": "saboteur", "Bulwark": "tank", "Artillery": "spitter", "Purifiers": "support", "Vanguard": "runner"}.get(faction_name, "")

static func faction_detail(faction_name: String) -> String:
	return {"None": "No adaptation", "Disruptors": "More saboteurs respond to tower reliance", "Bulwark": "More tanks; 20% blast resistance responds to explosives", "Artillery": "More spitters respond to close combat", "Purifiers": "More support units; 20% status resistance responds to elemental damage", "Vanguard": "More runners pressure balanced defenses"}.get(faction_name, "")

static func achievements(stats: Dictionary) -> Dictionary:
	var cleared = int(stats.get("cleared", stats.get("completed", 0)))
	return {"First stand": cleared >= 1, "Tenacious": cleared >= 10, "Siege breaker": stats.bosses >= 1, "Field engineer": stats.built >= 20, "Century": stats.kills >= 100,
		"Long watch": cleared >= 25, "Unbroken": cleared >= 50, "Millennium": stats.kills >= 1000, "Titan hunter": stats.bosses >= 5, "Lasting defense": stats.get("duration", 0) >= 1800,
		"Arsenal specialist": stats.get("weapon_damage", 0) >= 25000, "Automation": stats.get("tower_damage", 0) >= 25000, "Demolitionist": stats.get("explosive_damage", 0) >= 15000, "Elementalist": stats.get("elemental_damage", 0) >= 10000, "Pulse engineer": stats.get("ability_damage", 0) >= 5000,
		"Untouchable core": cleared >= 10 and stats.get("core_damage_taken", 0) == 0, "Iron survivor": stats.get("mode", "") == "challenge" and cleared >= 10 and stats.get("challenge_weight", 0.35) >= 0.3499, "Siege veteran": stats.get("mode", "") == "siege" and cleared >= 10,
		"Scavenger veteran": stats.get("mode", "") == "scavenger" and cleared >= 10, "Daily defender": stats.get("mode", "") == "daily" and cleared >= 10, "Collector": stats.get("loot_collected", 0) >= 30, "Fortress": stats.built >= 50, "Supply chain": stats.earned >= 10000, "Chain of command": stats.streak >= 30}
