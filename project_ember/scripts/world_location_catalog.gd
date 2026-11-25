extends RefCounted
class_name EmberWorldLocationCatalog

## Deterministic points of interest for the strategic map.
## Location IDs are derived from encoded hexes and remain stable for a world seed.

const World = preload("res://scripts/world_generator.gd")
const UnitCatalog = preload("res://scripts/unit_catalog.gd")

const MAX_LOCATIONS := 72
const MIN_LOCATION_DISTANCE := 5
const PLAYER_START_CITY := Vector2i(-3, 1)

const LOCATION_TYPES := {
	"ancient_ruins": {
		"name": "Древние руины",
		"marker": "Р",
		"color": "#d9b66c",
		"terrain": ["plain", "forest", "hills", "farmland"],
		"base_reward": {"gold": 35, "food": 8, "production": 4},
		"description": "Разрушенные стены скрывают старые припасы и забытые ценности.",
	},
	"monster_lair": {
		"name": "Логово чудовищ",
		"marker": "Л",
		"color": "#cf7166",
		"terrain": ["forest", "hills", "marsh"],
		"base_reward": {"gold": 25, "food": 14, "production": 0},
		"description": "Опасное логово, охраняемое стаей существ.",
	},
	"abandoned_mine": {
		"name": "Заброшенная шахта",
		"marker": "Ш",
		"color": "#aab2bc",
		"terrain": ["hills"],
		"base_reward": {"gold": 55, "food": 0, "production": 12},
		"description": "Старые штольни ещё хранят золото и полезные материалы.",
	},
	"forgotten_shrine": {
		"name": "Забытое святилище",
		"marker": "С",
		"color": "#b69bd8",
		"terrain": ["plain", "forest", "hills", "farmland"],
		"base_reward": {"gold": 20, "food": 10, "production": 5},
		"description": "Тихое место силы, которое охраняют последние хранители.",
	},
	"mercenary_camp": {
		"name": "Лагерь наёмников",
		"marker": "Н",
		"color": "#8fb78b",
		"terrain": ["plain", "farmland", "forest"],
		"base_reward": {"gold": 30, "food": 4, "production": 6},
		"description": "Брошенный лагерь с обозом и запасами наёмного отряда.",
	},
}


static func generate_locations(world_seed: int, generation_version: int) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var local_candidates: Array[Dictionary] = []
	var capitals := World.kingdom_capital_cells()
	for q in range(-World.WORLD_RADIUS, World.WORLD_RADIUS + 1):
		for r in range(-World.WORLD_RADIUS, World.WORLD_RADIUS + 1):
			var cell := Vector2i(q, r)
			if not World.is_inside_world(cell):
				continue
			var score := _cell_hash(cell, world_seed)
			var start_distance := World.hex_distance(cell, Vector2i(-2, 0))
			var is_local_ring := start_distance >= 4 and start_distance <= 13
			var is_local_candidate := is_local_ring and posmod(score, 11) == 0
			var is_world_candidate := posmod(score, 173) == 0
			if not is_local_ring and not is_world_candidate:
				continue
			if World.hex_distance(cell, PLAYER_START_CITY) < 3:
				continue
			var near_capital := false
			for capital in capitals:
				if World.hex_distance(cell, capital) < 3:
					near_capital = true
					break
			if near_capital:
				continue
			var terrain := World.terrain_at(cell, world_seed, generation_version)
			if terrain == "water" or terrain == "void":
				continue
			if is_local_ring:
				local_candidates.append({"cell": cell, "terrain": terrain, "score": score, "preferred": is_local_candidate})
			if is_world_candidate:
				candidates.append({"cell": cell, "terrain": terrain, "score": score})

	local_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := 0 if bool(a.get("preferred", false)) else 1
		var b_priority := 0 if bool(b.get("preferred", false)) else 1
		if a_priority != b_priority:
			return a_priority < b_priority
		return int(a.get("score", 0)) < int(b.get("score", 0))
	)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) < int(b.get("score", 0))
	)

	var selected_candidates: Array[Dictionary] = []
	for candidate in local_candidates:
		if selected_candidates.size() >= 4:
			break
		var local_cell: Vector2i = candidate.get("cell", Vector2i.ZERO)
		var local_too_close := false
		for selected in selected_candidates:
			if World.hex_distance(local_cell, selected.get("cell", Vector2i.ZERO)) < MIN_LOCATION_DISTANCE:
				local_too_close = true
				break
		if not local_too_close:
			selected_candidates.append(candidate)

	var result: Array[Dictionary] = []
	for candidate in selected_candidates + candidates:
		if result.size() >= MAX_LOCATIONS:
			break
		var cell: Vector2i = candidate.get("cell", Vector2i.ZERO)
		var too_close := false
		for existing in result:
			var existing_cell := World.array_to_cell(existing.get("cell", []))
			if World.hex_distance(cell, existing_cell) < MIN_LOCATION_DISTANCE:
				too_close = true
				break
		if too_close:
			continue
		var score := int(candidate.get("score", 0))
		var terrain := str(candidate.get("terrain", "plain"))
		var type_id := _choose_type(terrain, score)
		var start_distance := World.hex_distance(cell, Vector2i(-2, 0))
		var guard_tier := 1 if start_distance <= 13 else (2 if start_distance <= 34 else 3)
		var encoded := World.encode_cell(cell)
		result.append({
			"id": "loc_%d" % encoded,
			"type": type_id,
			"cell": World.cell_to_array(cell),
			"guard_tier": guard_tier,
			"guards": _make_guard_roster(guard_tier, type_id),
			"guardian_health": 95.0 + float(guard_tier - 1) * 30.0,
			"cleared": false,
			"reward": get_reward(type_id, guard_tier),
		})
	return result


static func normalize_locations(raw: Variant, world_seed: int, generation_version: int) -> Array[Dictionary]:
	var generated := generate_locations(world_seed, generation_version)
	var saved_by_id: Dictionary = {}
	if raw is Array:
		for item in raw:
			if not item is Dictionary:
				continue
			var location_id := str(item.get("id", ""))
			if not location_id.is_empty():
				saved_by_id[location_id] = item

	var result: Array[Dictionary] = []
	for base_value in generated:
		var location: Dictionary = base_value.duplicate(true)
		var location_id := str(location.get("id", ""))
		if saved_by_id.has(location_id):
			var saved: Dictionary = saved_by_id[location_id]
			location["cleared"] = bool(saved.get("cleared", false))
			var saved_guards: Variant = saved.get("guards", location.get("guards", []))
			location["guards"] = _normalize_guard_roster(saved_guards, int(location.get("guard_tier", 1)), str(location.get("type", "ancient_ruins")))
			location["guardian_health"] = clampf(
				float(saved.get("guardian_health", location.get("guardian_health", 95.0))),
				0.0,
				210.0
			)
			if location["cleared"]:
				location["guards"] = []
				location["guardian_health"] = 0.0
		result.append(location)
	return result


static func has_location_at(locations: Array, cell: Vector2i, include_cleared: bool = true) -> bool:
	for location in locations:
		if not location is Dictionary:
			continue
		if not include_cleared and bool(location.get("cleared", false)):
			continue
		if World.array_to_cell(location.get("cell", [])) == cell:
			return true
	return false


static func get_type_data(type_id: String) -> Dictionary:
	if not LOCATION_TYPES.has(type_id):
		return {}
	return LOCATION_TYPES[type_id].duplicate(true)


static func get_display_name(type_id: String) -> String:
	return str(LOCATION_TYPES.get(type_id, {}).get("name", "Неизвестная локация"))


static func get_marker(type_id: String) -> String:
	return str(LOCATION_TYPES.get(type_id, {}).get("marker", "?"))


static func get_color(type_id: String) -> Color:
	return Color(str(LOCATION_TYPES.get(type_id, {}).get("color", "#d9b66c")))


static func get_reward(type_id: String, guard_tier: int) -> Dictionary:
	var data: Dictionary = LOCATION_TYPES.get(type_id, LOCATION_TYPES["ancient_ruins"])
	var base: Dictionary = data.get("base_reward", {})
	var multiplier := 1.0 if guard_tier <= 1 else (1.5 if guard_tier == 2 else 2.0)
	return {
		"gold": roundi(float(base.get("gold", 0)) * multiplier),
		"food": roundi(float(base.get("food", 0)) * multiplier),
		"production": roundi(float(base.get("production", 0)) * multiplier),
	}


static func _choose_type(terrain: String, score: int) -> String:
	var roll := posmod(floori(float(score) / 997.0), 100)
	if roll < 24 and LOCATION_TYPES["monster_lair"]["terrain"].has(terrain):
		return "monster_lair"
	if roll < 43 and LOCATION_TYPES["abandoned_mine"]["terrain"].has(terrain):
		return "abandoned_mine"
	if roll < 62 and LOCATION_TYPES["mercenary_camp"]["terrain"].has(terrain):
		return "mercenary_camp"
	if roll < 80 and LOCATION_TYPES["forgotten_shrine"]["terrain"].has(terrain):
		return "forgotten_shrine"
	if LOCATION_TYPES["ancient_ruins"]["terrain"].has(terrain):
		return "ancient_ruins"
	for type_id in LOCATION_TYPES:
		if LOCATION_TYPES[type_id]["terrain"].has(terrain):
			return str(type_id)
	return "ancient_ruins"


static func _make_guard_roster(guard_tier: int, _type_id: String) -> Array[Dictionary]:
	var roles: Array[String] = []
	match clampi(guard_tier, 1, 3):
		1:
			roles = [UnitCatalog.ROLE_MELEE, UnitCatalog.ROLE_MELEE, UnitCatalog.ROLE_RANGED]
		2:
			roles = [UnitCatalog.ROLE_MELEE, UnitCatalog.ROLE_MELEE, UnitCatalog.ROLE_MELEE, UnitCatalog.ROLE_RANGED, UnitCatalog.ROLE_SPEAR]
		_:
			roles = [UnitCatalog.ROLE_MELEE, UnitCatalog.ROLE_MELEE, UnitCatalog.ROLE_MELEE, UnitCatalog.ROLE_MELEE, UnitCatalog.ROLE_RANGED, UnitCatalog.ROLE_RANGED, UnitCatalog.ROLE_SPEAR, UnitCatalog.ROLE_CAVALRY]
	var result: Array[Dictionary] = []
	var veteran_xp := 0 if guard_tier == 1 else (20 if guard_tier == 2 else 45)
	for role_id in roles:
		result.append({
			"role": role_id,
			"health": UnitCatalog.get_max_health(role_id),
			"experience": veteran_xp,
		})
	return result


static func _normalize_guard_roster(raw: Variant, guard_tier: int, type_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw is Array:
		for item in raw:
			if not item is Dictionary:
				continue
			var role_id := str(item.get("role", UnitCatalog.ROLE_MELEE))
			if not UnitCatalog.is_valid_role(role_id):
				continue
			var maximum := UnitCatalog.get_max_health(role_id)
			var health := clampf(float(item.get("health", maximum)), 0.0, maximum)
			if health <= 0.0:
				continue
			result.append({
				"role": role_id,
				"health": health,
				"experience": clampi(int(item.get("experience", 0)), 0, 999999),
			})
	return result if raw is Array else _make_guard_roster(guard_tier, type_id)


static func _cell_hash(cell: Vector2i, world_seed: int) -> int:
	var mixed := posmod(cell.x * 92837111 + cell.y * 689287499 + world_seed * 283923481, 2147483647)
	mixed = mixed ^ (mixed >> 13)
	mixed = posmod(mixed * 1274126177, 2147483647)
	mixed = mixed ^ (mixed >> 16)
	return posmod(mixed, 2147483647)
