extends RefCounted
class_name EmberCityDevelopmentCatalog

## Data-driven city levels, specializations, province improvements and building upgrades.
## Existing resource and building IDs remain unchanged.

const CITY_LEVELS := {
	1: {"population_min": 1, "population_max": 7, "province_slots": 1, "name": "Поселение"},
	2: {"population_min": 8, "population_max": 13, "province_slots": 3, "name": "Город"},
	3: {"population_min": 14, "population_max": 20, "province_slots": 5, "name": "Метрополия"},
}

const SPECIALIZATIONS := {
	"agriculture": {"name": "Земледелие", "description": "+20% еды за ход", "food_multiplier": 1.20, "gold_multiplier": 1.0, "production_multiplier": 1.0, "recruit_gold_multiplier": 1.0},
	"commerce": {"name": "Торговля", "description": "+20% золота за ход", "food_multiplier": 1.0, "gold_multiplier": 1.20, "production_multiplier": 1.0, "recruit_gold_multiplier": 1.0},
	"industry": {"name": "Промышленность", "description": "+20% производства за ход", "food_multiplier": 1.0, "gold_multiplier": 1.0, "production_multiplier": 1.20, "recruit_gold_multiplier": 1.0},
	"military": {"name": "Военное дело", "description": "−10% золота на найм войск", "food_multiplier": 1.0, "gold_multiplier": 1.0, "production_multiplier": 1.0, "recruit_gold_multiplier": 0.90},
}

const PROVINCE_IMPROVEMENTS := {
	"farm_plot": {"name": "Полевой участок", "description": "+2 еды/ход", "terrain": ["plain", "farmland"], "gold_cost": 30, "production_cost": 6, "food": 2, "gold": 0, "production": 0},
	"trade_post": {"name": "Торговый пост", "description": "+2 золота/ход", "terrain": ["plain", "farmland"], "gold_cost": 35, "production_cost": 7, "food": 0, "gold": 2, "production": 0},
	"woodland_camp": {"name": "Лесной лагерь", "description": "+2 производства/ход", "terrain": ["forest"], "gold_cost": 30, "production_cost": 7, "food": 0, "gold": 0, "production": 2},
	"stone_quarry": {"name": "Каменоломня", "description": "+2 производства/ход", "terrain": ["hills"], "gold_cost": 40, "production_cost": 8, "food": 0, "gold": 0, "production": 2},
	"watchtower": {"name": "Сторожевая башня", "description": "Радиус влияния 8 · +1 производство/ход · +1 броня войскам в радиусе 3", "terrain": ["forest", "hills"], "gold_cost": 55, "production_cost": 12, "food": 0, "gold": 0, "production": 1},
	"arcane_conduit": {"name": "Арканный обелиск", "description": "+2 арканной силы/ход для магического восхождения", "terrain": ["plain", "forest", "hills", "farmland"], "gold_cost": 50, "production_cost": 12, "food": 0, "gold": 0, "production": 0},
}

const BUILDING_UPGRADES := {
	"farm": {
		2: {"gold_cost": 40, "production_cost": 12, "description": "+3 еды/ход"},
		3: {"gold_cost": 65, "production_cost": 20, "description": "+4 еды/ход"},
	},
	"market": {
		2: {"gold_cost": 45, "production_cost": 13, "description": "+3 золота/ход"},
		3: {"gold_cost": 70, "production_cost": 22, "description": "+4 золота/ход"},
	},
	"workshop": {
		2: {"gold_cost": 45, "production_cost": 13, "description": "+2 производства/ход"},
		3: {"gold_cost": 70, "production_cost": 22, "description": "+3 производства/ход"},
	},
	"barracks": {
		2: {"gold_cost": 45, "production_cost": 14, "description": "−5% золота на найм пехоты"},
		3: {"gold_cost": 75, "production_cost": 24, "description": "−10% золота на найм пехоты"},
	},
	"archery_range": {
		2: {"gold_cost": 40, "production_cost": 13, "description": "−5% золота на найм лучников"},
		3: {"gold_cost": 70, "production_cost": 22, "description": "−10% золота на найм лучников"},
	},
	"stable": {
		2: {"gold_cost": 50, "production_cost": 16, "description": "−5% золота на найм кавалерии"},
		3: {"gold_cost": 85, "production_cost": 26, "description": "−10% золота на найм кавалерии"},
	},
}

const IMPROVEMENT_ORDER := ["farm_plot", "trade_post", "woodland_camp", "stone_quarry", "watchtower", "arcane_conduit"]
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func get_city_level(population: int) -> int:
	if population >= 14:
		return 3
	if population >= 8:
		return 2
	return 1


static func get_province_slots(city_level: int) -> int:
	var data: Dictionary = CITY_LEVELS.get(clampi(city_level, 1, 3), CITY_LEVELS[1])
	return int(data.get("province_slots", 1))


static func is_valid_specialization(specialization_id: String) -> bool:
	return SPECIALIZATIONS.has(specialization_id)


static func normalize_building_levels(buildings: Array, raw_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var raw: Dictionary = raw_value if raw_value is Dictionary else {}
	for building_value in buildings:
		var building_id := str(building_value)
		if BUILDING_UPGRADES.has(building_id):
			result[building_id] = clampi(int(raw.get(building_id, 1)), 1, 3)
	return result


static func normalize_province_improvements(raw_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_value is Array:
		return result
	var used_cells: Dictionary = {}
	for item in raw_value:
		if not item is Dictionary:
			continue
		var improvement_id := str(item.get("id", ""))
		var cell_value: Variant = item.get("cell", [])
		if not PROVINCE_IMPROVEMENTS.has(improvement_id) or not cell_value is Array or cell_value.size() < 2:
			continue
		var q := int(cell_value[0])
		var r := int(cell_value[1])
		var key := "%d:%d" % [q, r]
		if used_cells.has(key):
			continue
		result.append({"id": improvement_id, "cell": [q, r]})
		used_cells[key] = true
		if result.size() >= 6:
			break
	return result


static func get_improvement_data(improvement_id: String) -> Dictionary:
	if not PROVINCE_IMPROVEMENTS.has(improvement_id):
		return {}
	return PROVINCE_IMPROVEMENTS[improvement_id].duplicate(true)


static func get_building_upgrade_data(building_id: String, target_level: int) -> Dictionary:
	if not BUILDING_UPGRADES.has(building_id):
		return {}
	var levels: Dictionary = BUILDING_UPGRADES[building_id]
	if not levels.has(target_level):
		return {}
	var result: Dictionary = levels[target_level].duplicate(true)
	result["building_id"] = building_id
	result["target_level"] = target_level
	result["building_name"] = _building_name(building_id)
	return result


static func get_next_improvement_for_terrain(terrain_id: String) -> String:
	for improvement_id in IMPROVEMENT_ORDER:
		var data: Dictionary = PROVINCE_IMPROVEMENTS[improvement_id]
		if (data.get("terrain", []) as Array).has(terrain_id):
			return improvement_id
	return ""


static func get_city_income(buildings: Array, building_levels: Dictionary, improvements: Array, specialization: String) -> Dictionary:
	var food_income := 2
	var gold_income := 4
	var production_income := 4
	if buildings.has("farm"):
		var farm_level := clampi(int(building_levels.get("farm", 1)), 1, 3)
		food_income += 5
		if farm_level >= 2:
			food_income += 3
		if farm_level >= 3:
			food_income += 4
	if buildings.has("market"):
		var market_level := clampi(int(building_levels.get("market", 1)), 1, 3)
		gold_income += 4
		if market_level >= 2:
			gold_income += 3
		if market_level >= 3:
			gold_income += 4
	if buildings.has("workshop"):
		var workshop_level := clampi(int(building_levels.get("workshop", 1)), 1, 3)
		production_income += 3
		if workshop_level >= 2:
			production_income += 2
		if workshop_level >= 3:
			production_income += 3
	for improvement in improvements:
		if not improvement is Dictionary:
			continue
		var data := get_improvement_data(str(improvement.get("id", "")))
		food_income += int(data.get("food", 0))
		gold_income += int(data.get("gold", 0))
		production_income += int(data.get("production", 0))
	var spec: Dictionary = SPECIALIZATIONS.get(specialization, {})
	food_income = roundi(float(food_income) * float(spec.get("food_multiplier", 1.0)))
	gold_income = roundi(float(gold_income) * float(spec.get("gold_multiplier", 1.0)))
	production_income = roundi(float(production_income) * float(spec.get("production_multiplier", 1.0)))
	return {"food": food_income, "gold": gold_income, "production": production_income}


static func get_recruit_gold_multiplier(specialization: String, building_id: String, building_levels: Dictionary) -> float:
	var multiplier := float(SPECIALIZATIONS.get(specialization, {}).get("recruit_gold_multiplier", 1.0))
	var building_level := clampi(int(building_levels.get(building_id, 1)), 1, 3)
	multiplier *= 1.0 - 0.05 * float(building_level - 1)
	return maxf(0.70, multiplier)


static func _building_name(building_id: String) -> String:
	var names := {
		"farm": "Ферма", "market": "Рынок", "workshop": "Мастерская",
		"barracks": "Казармы", "archery_range": "Стрельбище", "stable": "Конюшня",
	}
	return str(names.get(building_id, "Здание"))
