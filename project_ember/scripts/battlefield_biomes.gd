extends RefCounted
class_name BattlefieldBiomes

const Palette = preload("res://scripts/art_palette.gd")

const GRASSLAND := "grassland"
const WOODLAND := "woodland"
const HIGHLANDS := "highlands"
const MARSH := "marsh"

const _PROFILES := {
	GRASSLAND: {
		"id": GRASSLAND,
		"name": "Равнина",
		"ground": Palette.GRASS,
		"highlight": Palette.GRASS_LIGHT,
		"dirt": Palette.EARTH,
		"grass": Palette.GRASS_LIGHT,
		"stone": Palette.STONE,
		"tree": Palette.FOREST,
		"tree_light": Palette.FOREST_LIGHT,
		"sky": Palette.SKY_BACKGROUND,
		"ambient": Palette.AMBIENT_COOL,
		"water": Palette.WATER,
		"tree_density": 0.82,
		"grass_density": 1.0,
		"stone_density": 1.0,
		"rock_density": 0.35,
		"pool_density": 0.0,
		"reed_density": 0.0,
	},
	WOODLAND: {
		"id": WOODLAND,
		"name": "Лесная чаща",
		"ground": Palette.WOODLAND_GROUND,
		"highlight": Palette.WOODLAND_GROUND_LIGHT,
		"dirt": Palette.WOODLAND_EARTH,
		"grass": Palette.WOODLAND_GRASS,
		"stone": Palette.STONE,
		"tree": Palette.FOREST,
		"tree_light": Palette.FOREST_LIGHT,
		"sky": Palette.WOODLAND_SKY,
		"ambient": Palette.AMBIENT_COOL,
		"water": Palette.WATER,
		"tree_density": 1.72,
		"grass_density": 0.78,
		"stone_density": 0.78,
		"rock_density": 0.25,
		"pool_density": 0.08,
		"reed_density": 0.0,
	},
	HIGHLANDS: {
		"id": HIGHLANDS,
		"name": "Каменистые высоты",
		"ground": Palette.HIGHLAND_GROUND,
		"highlight": Palette.HIGHLAND_GROUND_LIGHT,
		"dirt": Palette.HIGHLAND_EARTH,
		"grass": Palette.HIGHLAND_GRASS,
		"stone": Palette.HIGHLAND_STONE,
		"tree": Palette.FOREST,
		"tree_light": Palette.FOREST_LIGHT,
		"sky": Palette.HIGHLAND_SKY,
		"ambient": Palette.AMBIENT_COOL,
		"water": Palette.WATER,
		"tree_density": 0.46,
		"grass_density": 0.58,
		"stone_density": 1.75,
		"rock_density": 1.72,
		"pool_density": 0.0,
		"reed_density": 0.0,
	},
	MARSH: {
		"id": MARSH,
		"name": "Топи",
		"ground": Palette.MARSH_GROUND,
		"highlight": Palette.MARSH_GROUND_LIGHT,
		"dirt": Palette.MARSH_EARTH,
		"grass": Palette.MARSH_GRASS,
		"stone": Palette.STONE,
		"tree": Palette.FOREST,
		"tree_light": Palette.FOREST_LIGHT,
		"sky": Palette.MARSH_SKY,
		"ambient": Palette.AMBIENT_COOL,
		"water": Palette.MARSH_WATER,
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
	if hills_count >= 1 and hills_count >= forest_count:
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
