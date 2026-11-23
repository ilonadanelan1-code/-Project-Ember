extends RefCounted
class_name BattlefieldBiomes

const GRASSLAND := "grassland"
const WOODLAND := "woodland"
const HIGHLANDS := "highlands"
const MARSH := "marsh"

const _PROFILES := {
	GRASSLAND: {
		"name": "Равнина",
		"ground": Color("#607b43"),
		"highlight": Color("#93a75b"),
		"dirt": Color("#66523c"),
		"grass": Color("#93a75b"),
		"stone": Color("#77766d"),
		"tree": Color("#294d35"),
		"tree_light": Color("#47734a"),
		"sky": Color("#252d28"),
		"ambient": Color("#b5c1ad"),
		"water": Color("#315b78"),
		"tree_density": 0.82,
		"grass_density": 1.0,
		"stone_density": 1.0,
		"rock_density": 0.35,
		"pool_density": 0.0,
		"reed_density": 0.0,
	},
	WOODLAND: {
		"name": "Лесная чаща",
		"ground": Color("#465f3f"),
		"highlight": Color("#7d9360"),
		"dirt": Color("#514638"),
		"grass": Color("#8a9a5b"),
		"stone": Color("#686e60"),
		"tree": Color("#233f30"),
		"tree_light": Color("#3d6748"),
		"sky": Color("#202b29"),
		"ambient": Color("#aabbab"),
		"water": Color("#426b68"),
		"tree_density": 1.72,
		"grass_density": 0.78,
		"stone_density": 0.78,
		"rock_density": 0.25,
		"pool_density": 0.08,
		"reed_density": 0.0,
	},
	HIGHLANDS: {
		"name": "Каменистые высоты",
		"ground": Color("#746951"),
		"highlight": Color("#a18e68"),
		"dirt": Color("#5f4e3d"),
		"grass": Color("#858a68"),
		"stone": Color("#89867e"),
		"tree": Color("#3d5943"),
		"tree_light": Color("#637454"),
		"sky": Color("#2d3233"),
		"ambient": Color("#c0c3b8"),
		"water": Color("#516f7e"),
		"tree_density": 0.46,
		"grass_density": 0.58,
		"stone_density": 1.75,
		"rock_density": 1.72,
		"pool_density": 0.0,
		"reed_density": 0.0,
	},
	MARSH: {
		"name": "Топи",
		"ground": Color("#52624b"),
		"highlight": Color("#86916a"),
		"dirt": Color("#554b38"),
		"grass": Color("#75814a"),
		"stone": Color("#6e7265"),
		"tree": Color("#344c3a"),
		"tree_light": Color("#59704b"),
		"sky": Color("#263638"),
		"ambient": Color("#aebfba"),
		"water": Color("#4e7b7b"),
		"tree_density": 0.48,
		"grass_density": 0.72,
		"stone_density": 0.55,
		"rock_density": 0.22,
		"pool_density": 1.55,
		"reed_density": 1.15,
	},
}

static func biome_ids() -> Array[String]:
	return [GRASSLAND, WOODLAND, HIGHLANDS, MARSH]


static func get_profile(biome_id: String) -> Dictionary:
	var profile: Dictionary = _PROFILES.get(biome_id, _PROFILES[GRASSLAND])
	return profile.duplicate(true)


static func get_display_name(biome_id: String) -> String:
	return str(get_profile(biome_id).get("name", "Равнина"))


## Derive a tactical biome from the six neighboring strategic hexes.
## The tactical map itself is not written to the campaign save.
static func resolve_for_cell(cell: Vector2i) -> String:
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
	]
	var counts := {"forest": 0, "hills": 0, "water": 0}
	for offset in offsets:
		var terrain := _terrain_for_cell(cell + offset)
		counts[terrain] = int(counts.get(terrain, 0)) + 1

	var forest_count := int(counts["forest"])
	var hills_count := int(counts["hills"])
	var water_count := int(counts["water"])
	if water_count >= 2:
		return MARSH
	if forest_count >= 2 and forest_count >= hills_count:
		return WOODLAND
	if hills_count >= 2:
		return HIGHLANDS
	if forest_count > hills_count:
		return WOODLAND
	return GRASSLAND


static func seed_for_cell(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 + cell.y * 19349663 + 8349271)


static func _terrain_for_cell(cell: Vector2i) -> String:
	# Match StrategyMap._generate_terrain(): the central approach is always plain.
	if cell.y == 0:
		return "plain"
	var value := absi(cell.x * 17 + cell.y * 29 + cell.x * cell.y * 7)
	if value % 13 == 0:
		return "water"
	if value % 5 == 0:
		return "forest"
	if value % 7 == 0:
		return "hills"
	return "plain"
