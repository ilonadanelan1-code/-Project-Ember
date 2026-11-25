extends RefCounted
class_name EmberKingdomAI

const World = preload("res://scripts/world_generator.gd")
const UnitCatalog = preload("res://scripts/unit_catalog.gd")
const CityDevelopment = preload("res://scripts/city_development_catalog.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")
const FactionCatalog = preload("res://scripts/faction_catalog.gd")
const DiplomacyCatalog = preload("res://scripts/diplomacy_catalog.gd")
const WorldLocationCatalog = preload("res://scripts/world_location_catalog.gd")
const StrategicAI = preload("res://scripts/strategic_ai_planner.gd")

const KINGDOM_NAMES := [
	"Королевство Алых Парусов",
	"Северный Венец",
	"Княжество Серебряных Гор",
	"Западная Марка",
	"Королевство Трёх Рек",
	"Лесной Престол",
	"Степной Доминион",
	"Восточная Корона",
	"Королевство Чёрного Камня",
]
const RULER_NAMES := [
	"Варг",
	"Хальвар",
	"Эйрина",
	"Роланд",
	"Мирена",
	"Торвальд",
	"Кассия",
	"Дарион",
	"Морвен",
]
const CAPITAL_NAMES := [
	"Красный Приют",
	"Североград",
	"Серебряный Шпиль",
	"Западный Дозор",
	"Трибродье",
	"Дубовый Венец",
	"Степная Крепь",
	"Восточный Оплот",
	"Чёрный Утёс",
]
const BUILDING_COSTS := {
	"farm": {"name": "Ферма", "gold": 25, "production": 5},
	"market": {"name": "Рынок", "gold": 35, "production": 6},
	"workshop": {"name": "Мастерская", "gold": 45, "production": 8},
	"barracks": {"name": "Казармы", "gold": 50, "production": 8},
	"archery_range": {"name": "Стрельбище", "gold": 40, "production": 8},
	"stable": {"name": "Конюшня", "gold": 60, "production": 10},
}


static func create_initial_kingdoms(_seed: int = World.DEFAULT_SEED) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var capitals := World.kingdom_capital_cells()
	var army_offsets: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, -1),
		Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, -1),
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0),
	]
	for index in range(World.KINGDOM_COUNT):
		var capital := capitals[index]
		var army_cell := capital + army_offsets[index]
		var city := _make_city_record(0, CAPITAL_NAMES[index], capital, 5 + (index % 2), 8 + (index % 3), 95 + index * 5)
		var kingdom_faction := FactionCatalog.make_ai_selection(index, KINGDOM_NAMES[index])
		var starting_army := _make_starting_army(index)
		var starting_resources := FactionCatalog.apply_starting_bonus(
			kingdom_faction,
			{"food": int(city.get("food", 0)), "gold": int(city.get("gold", 0)), "production": int(city.get("production_bank", 0))},
			starting_army
		)
		city["food"] = int(starting_resources.get("food", city.get("food", 0)))
		city["gold"] = int(starting_resources.get("gold", city.get("gold", 0)))
		city["production_bank"] = int(starting_resources.get("production", city.get("production_bank", 0)))
		var record := {
			"id": index,
			"name": KINGDOM_NAMES[index],
			"faction": kingdom_faction,
			"ruler": RULER_NAMES[index],
			"capital_name": CAPITAL_NAMES[index],
			"capital_cell": World.cell_to_array(capital),
			"army_cell": World.cell_to_array(army_cell),
			"army": starting_army,
			"cities": [city],
			"hero": _make_hero_record(RULER_NAMES[index], "Правитель " + KINGDOM_NAMES[index]),
			"alive": true,
			"last_action": "Развивает столицу и собирает войска",
			"next_move_turn": 2 + (index % 3),
			"next_expansion_turn": 8 + (index % 4),
			"target_kingdom_id": (index + 1) % World.KINGDOM_COUNT,
			"military_doctrine": index % 4,
			"neutral_target_id": "",
		}
		result.append(record)
	return result


static func normalize_kingdom(raw: Dictionary, fallback: Dictionary) -> Dictionary:
	var result: Dictionary = fallback.duplicate(true)
	var index := int(fallback.get("id", 0))
	result["name"] = str(raw.get("name", result.get("name", KINGDOM_NAMES[index % KINGDOM_NAMES.size()])))
	result["faction"] = FactionCatalog.normalize_selection(raw.get("faction", result.get("faction", {})))
	result["ruler"] = str(raw.get("ruler", result.get("ruler", RULER_NAMES[index % RULER_NAMES.size()])))
	result["alive"] = bool(raw.get("alive", true))
	var capital := World.array_to_cell(raw.get("capital_cell", result.get("capital_cell", [])), World.array_to_cell(result.get("capital_cell", [])))
	var army_cell := World.array_to_cell(raw.get("army_cell", result.get("army_cell", [])), World.array_to_cell(result.get("army_cell", [])))
	if World.is_inside_world(capital):
		result["capital_cell"] = World.cell_to_array(capital)
	if World.is_inside_world(army_cell):
		result["army_cell"] = World.cell_to_array(army_cell)

	var raw_army: Variant = raw.get("army", result.get("army", []))
	var army: Array[Dictionary] = []
	if raw_army is Array:
		for unit_value in raw_army:
			if not unit_value is Dictionary:
				continue
			var role := str(unit_value.get("role", UnitCatalog.ROLE_MELEE))
			if not UnitCatalog.is_valid_role(role):
				continue
			var maximum := UnitCatalog.get_max_health(role)
			var health := clampf(float(unit_value.get("health", maximum)), 0.0, maximum)
			var experience := clampi(int(unit_value.get("experience", 0)), 0, 999999)
			if health > 0.0 and army.size() < 24:
				army.append({"role": role, "health": health, "experience": experience})
	result["army"] = army

	var raw_cities: Variant = raw.get("cities", result.get("cities", []))
	var cities: Array[Dictionary] = []
	if raw_cities is Array:
		for city_value in raw_cities:
			if not city_value is Dictionary:
				continue
			var cell := World.array_to_cell(city_value.get("cell", []), capital)
			if not World.is_inside_world(cell) or cities.size() >= 4:
				continue
			var city_index := cities.size()
			var city_name := str(city_value.get("name", "Поселение %d" % (city_index + 1)))
			var city := _make_city_record(
				city_index,
				city_name,
				cell,
				clampi(int(city_value.get("population", 3)), 1, 20),
				maxi(0, int(city_value.get("food", 0))),
				maxi(0, int(city_value.get("gold", 0)))
			)
			city["production_bank"] = maxi(0, int(city_value.get("production_bank", 0)))
			var raw_buildings: Variant = city_value.get("buildings", [])
			if raw_buildings is Array:
				for building in raw_buildings:
					if BUILDING_COSTS.has(str(building)) and not city["buildings"].has(str(building)):
						city["buildings"].append(str(building))
			city["building_levels"] = CityDevelopment.normalize_building_levels(city["buildings"], city_value.get("building_levels", {}))
			var specialization := str(city_value.get("specialization", ""))
			city["specialization"] = specialization if CityDevelopment.is_valid_specialization(specialization) else ""
			city["province_improvements"] = CityDevelopment.normalize_province_improvements(city_value.get("province_improvements", []))
			var raw_queue: Variant = city_value.get("build_queue", [])
			if raw_queue is Array:
				for order in raw_queue:
					if not order is Dictionary or city["build_queue"].size() >= 8:
						continue
					var kind := str(order.get("kind", ""))
					var order_id := str(order.get("id", ""))
					if kind == "building" and BUILDING_COSTS.has(order_id):
						city["build_queue"].append(order.duplicate(true))
					elif kind == "recruit" and UnitCatalog.is_valid_role(order_id):
						city["build_queue"].append(order.duplicate(true))
					elif kind == "building_upgrade" and CityDevelopment.BUILDING_UPGRADES.has(order_id) and int(order.get("target_level", 0)) in [2, 3]:
						city["build_queue"].append(order.duplicate(true))
					elif kind == "province_improvement" and CityDevelopment.PROVINCE_IMPROVEMENTS.has(order_id) and order.get("cell", []) is Array and order.get("cell", []).size() >= 2:
						city["build_queue"].append(order.duplicate(true))
			city["last_event"] = str(city_value.get("last_event", ""))
			cities.append(city)
	if cities.is_empty():
		cities = result.get("cities", [])
	result["cities"] = cities
	var raw_hero: Variant = raw.get("hero", result.get("hero", {}))
	if raw_hero is Dictionary:
		result["hero"] = raw_hero.duplicate(true)
	result["last_action"] = str(raw.get("last_action", result.get("last_action", "Развивает королевство")))
	result["next_move_turn"] = clampi(int(raw.get("next_move_turn", result.get("next_move_turn", 2))), 1, 100000000)
	result["next_expansion_turn"] = clampi(int(raw.get("next_expansion_turn", result.get("next_expansion_turn", 8))), 1, 100000000)
	result["target_kingdom_id"] = clampi(int(raw.get("target_kingdom_id", result.get("target_kingdom_id", (index + 1) % World.KINGDOM_COUNT))), 0, World.KINGDOM_COUNT - 1)
	result["military_doctrine"] = clampi(int(raw.get("military_doctrine", index % 4)), 0, 3)
	result["neutral_target_id"] = str(raw.get("neutral_target_id", result.get("neutral_target_id", "")))
	return result


static func process_turns(
		kingdoms: Array[Dictionary],
		turn_number: int,
		player_cell: Vector2i,
		player_city_cells: Array[Vector2i],
		world_seed: int,
		world_generation_version: int = World.WORLD_GENERATION_VERSION,
		neutral_location_cells: Array[Vector2i] = [],
		diplomacy_relations: Dictionary = {},
		neutral_locations: Array[Dictionary] = []
) -> Array[String]:
	var events: Array[String] = []
	for index in range(kingdoms.size()):
		var kingdom: Dictionary = kingdoms[index]
		if not bool(kingdom.get("alive", true)):
			continue
		var action_parts: Array[String] = []
		var cities: Array = kingdom.get("cities", [])
		var army: Array = kingdom.get("army", [])
		_apply_ai_mine_income(kingdom, neutral_locations)
		var faction_value: Variant = kingdom.get("faction", {})
		var kingdom_faction: Dictionary = faction_value if faction_value is Dictionary else {}
		for city_index in range(cities.size()):
			var city: Dictionary = cities[city_index]
			var buildings: Array = city.get("buildings", [])
			var base_income := CityDevelopment.get_city_income(buildings, city.get("building_levels", {}), city.get("province_improvements", []), str(city.get("specialization", "")))
			var income := FactionCatalog.apply_income_modifiers(base_income, buildings, kingdom_faction)
			city["food"] = int(city.get("food", 0)) + int(income.get("food", 2))
			city["gold"] = int(city.get("gold", 0)) + int(income.get("gold", 4))
			city["production_bank"] = int(city.get("production_bank", 0)) + int(income.get("production", 4))
			if int(city.get("population", 1)) < 20 and int(city["food"]) >= 12:
				city["food"] = int(city["food"]) - 12
				city["population"] = int(city.get("population", 1)) + 1
			if CityDevelopment.get_city_level(int(city.get("population", 1))) >= 2 and str(city.get("specialization", "")).is_empty():
				var choices := ["agriculture", "commerce", "industry", "military"]
				city["specialization"] = choices[posmod(int(kingdom.get("id", index)) + city_index + int(kingdom.get("military_doctrine", 0)), choices.size())]
			var queue: Array = city.get("build_queue", [])
			if not queue.is_empty():
				var order: Dictionary = queue[0]
				var required := maxi(1, int(order.get("production_cost", 1)))
				if int(city["production_bank"]) >= required:
					city["production_bank"] = int(city["production_bank"]) - required
					queue.pop_front()
					var order_id := str(order.get("id", ""))
					var order_kind := str(order.get("kind", ""))
					if order_kind == "building" and BUILDING_COSTS.has(order_id):
						if not buildings.has(order_id):
							buildings.append(order_id)
							var levels: Dictionary = city.get("building_levels", {})
							levels[order_id] = 1
							city["building_levels"] = levels
							action_parts.append("%s построили %s" % [str(city.get("name", "Город")), str(BUILDING_COSTS[order_id]["name"])])
					elif order_kind == "building_upgrade" and CityDevelopment.BUILDING_UPGRADES.has(order_id):
						var upgrade_levels: Dictionary = city.get("building_levels", {})
						var target_level := clampi(int(order.get("target_level", 1)), 2, 3)
						if buildings.has(order_id) and target_level == int(upgrade_levels.get(order_id, 1)) + 1 and CityDevelopment.get_city_level(int(city.get("population", 1))) >= target_level:
							upgrade_levels[order_id] = target_level
							city["building_levels"] = upgrade_levels
							action_parts.append("%s улучшили до уровня %d" % [str(BUILDING_COSTS.get(order_id, {}).get("name", order_id)), target_level])
					elif order_kind == "province_improvement" and CityDevelopment.PROVINCE_IMPROVEMENTS.has(order_id):
						var raw_cell: Variant = order.get("cell", [])
						if raw_cell is Array and raw_cell.size() >= 2:
							var xy: Vector2i = World.array_to_cell(raw_cell)
							var center: Vector2i = World.array_to_cell(city.get("cell", []))
							var improvements: Array = city.get("province_improvements", [])
							var item := CityDevelopment.get_improvement_data(order_id)
							var terrain := World.terrain_at(xy, world_seed, world_generation_version)
							var valid_terrain: Array = item.get("terrain", [])
							var faction_effects := FactionCatalog.get_effects(kingdom_faction)
							var province_slots := mini(6, CityDevelopment.get_province_slots(CityDevelopment.get_city_level(int(city.get("population", 1)))) + int(faction_effects.get("province_slot_bonus", 0)))
							if World.is_inside_world(xy) and World.hex_distance(xy, center) == 1 and improvements.size() < province_slots and valid_terrain.has(terrain):
								var duplicate_cell := false
								for existing in improvements:
									if World.array_to_cell(existing.get("cell", [])) == xy:
										duplicate_cell = true
								if not duplicate_cell:
									improvements.append({"id": order_id, "cell": [xy.x, xy.y]})
									city["province_improvements"] = improvements
					elif order_kind == "recruit" and UnitCatalog.is_valid_role(order_id) and army.size() < 24:
						army.append({"role": order_id, "health": UnitCatalog.get_max_health(order_id), "experience": 0})
						action_parts.append("%s нанял: %s" % [str(city.get("name", "Город")), str(UnitCatalog.get_data(order_id).get("name", "отряд"))])
			city["buildings"] = buildings
			city["build_queue"] = queue
			cities[city_index] = city

		kingdom["cities"] = cities
		kingdom["army"] = army
		var strategic_plan := StrategicAI.evaluate_kingdom(kingdom, kingdoms, diplomacy_relations, turn_number, player_cell, player_city_cells)
		for city_index in range(cities.size()):
			var city: Dictionary = cities[city_index]
			var order_event := _queue_next_order(city, kingdom, army, turn_number, city_index, world_seed, world_generation_version, strategic_plan)
			if not order_event.is_empty():
				action_parts.append(order_event)
			cities[city_index] = city

		var upkeep_total := 0.0
		for army_unit in army:
			var upkeep_role := str(army_unit.get("role", UnitCatalog.ROLE_MELEE))
			var upkeep_data := UnitCatalog.get_data(upkeep_role)
			upkeep_total += float(upkeep_data.get("upkeep", 0.0)) * FactionCatalog.get_upkeep_multiplier(upkeep_role, kingdom_faction)
		var upkeep_due := ceili(upkeep_total)
		var upkeep_remaining := upkeep_due
		for city_index in range(cities.size()):
			if upkeep_remaining <= 0:
				break
			var upkeep_city: Dictionary = cities[city_index]
			var available_gold := maxi(0, int(upkeep_city.get("gold", 0)))
			var payment := mini(available_gold, upkeep_remaining)
			upkeep_city["gold"] = available_gold - payment
			upkeep_remaining -= payment
			cities[city_index] = upkeep_city
		kingdom["cities"] = cities
		kingdom["army"] = army
		var next_expansion := int(kingdom.get("next_expansion_turn", 8))
		if turn_number >= next_expansion and bool(strategic_plan.get("expansion_allowed", false)):
			var expansion := _try_found_ai_city(kingdom, kingdoms, player_cell, player_city_cells, world_seed, world_generation_version, neutral_location_cells)
			if not expansion.is_empty():
				cities = kingdom.get("cities", [])
				action_parts.append(expansion)
			kingdom["next_expansion_turn"] = turn_number + 8 + (index % 4)

		var next_move := int(kingdom.get("next_move_turn", 2))
		if turn_number >= next_move:
			var movement := _move_army(kingdom, kingdoms, player_cell, player_city_cells, world_seed, world_generation_version, neutral_location_cells, diplomacy_relations, neutral_locations, turn_number)
			if not movement.is_empty():
				action_parts.append(movement)
			kingdom["next_move_turn"] = turn_number + 2 + (index % 3)

		if action_parts.is_empty():
			action_parts.append("содержит войска и пополняет казну")
		kingdom["last_action"] = "; ".join(action_parts.slice(0, 2))
		kingdoms[index] = kingdom
		events.append("%s: %s" % [str(kingdom.get("name", "Королевство")), str(kingdom["last_action"])])
	return events


static func _queue_next_order(
		city: Dictionary,
		kingdom: Dictionary,
		army: Array,
		turn_number: int,
		city_index: int,
		world_seed: int,
		world_generation_version: int,
		strategic_plan: Dictionary = {}
) -> String:
	var queue: Array = city.get("build_queue", [])
	if not queue.is_empty():
		return ""
	var buildings: Array = city.get("buildings", [])
	var gold := int(city.get("gold", 0))
	var city_name := str(city.get("name", "Город"))
	var order_id := ""
	var order_kind := "building"
	var order_name := ""
	var cost_gold := 0
	var cost_production := 0
	var target_level := 0
	var province_cell := Vector2i(9999, 9999)
	var levels: Dictionary = city.get("building_levels", {})
	var economy_focus := str(strategic_plan.get("economy_focus", "balanced"))
	var upgrade_id := _get_ai_building_upgrade_id(city, economy_focus)
	var upgrade_data: Dictionary = {}
	if not upgrade_id.is_empty():
		target_level = int(levels.get(upgrade_id, 1)) + 1
		upgrade_data = CityDevelopment.get_building_upgrade_data(upgrade_id, target_level)
	var faction_value: Variant = kingdom.get("faction", {})
	var kingdom_faction: Dictionary = faction_value if faction_value is Dictionary else {}
	var province_order := _get_ai_province_build_order(city, kingdom_faction, world_seed, world_generation_version)
	var desired_army_size := clampi(int(strategic_plan.get("desired_army_size", 10)), 0, 24)
	var can_recruit := bool(strategic_plan.get("can_recruit", false))
	var recruit_role := str(strategic_plan.get("recruit_role", UnitCatalog.ROLE_MELEE))
	if not UnitCatalog.is_valid_role(recruit_role):
		recruit_role = UnitCatalog.ROLE_MELEE
	var recruit_data := UnitCatalog.get_data(recruit_role)
	var recruit_unlock := str(recruit_data.get("unlock_building", "barracks"))
	var should_recruit := city_index == 0 and can_recruit and army.size() < desired_army_size

	if not buildings.has("barracks") and gold >= 50:
		order_id = "barracks"
	elif city_index == 0 and not buildings.has("market") and gold >= 35:
		order_id = "market"
	elif city_index > 0 and not buildings.has("farm") and gold >= 25:
		order_id = "farm"
	elif economy_focus == "gold" and not buildings.has("market") and gold >= 35:
		order_id = "market"
	elif economy_focus == "food" and not buildings.has("farm") and gold >= 25:
		order_id = "farm"
	elif should_recruit and not buildings.has(recruit_unlock) and BUILDING_COSTS.has(recruit_unlock) and gold >= int(BUILDING_COSTS[recruit_unlock].get("gold", 999999)):
		order_id = recruit_unlock
	elif should_recruit and buildings.has(recruit_unlock):
		order_kind = "recruit"
		order_id = recruit_role
	elif economy_focus == "production" and not buildings.has("workshop") and gold >= 45:
		order_id = "workshop"
	elif not buildings.has("farm") and gold >= 25:
		order_id = "farm"
	elif not buildings.has("market") and gold >= 35:
		order_id = "market"
	elif not buildings.has("workshop") and gold >= 45:
		order_id = "workshop"
	elif not upgrade_data.is_empty() and gold >= int(upgrade_data.get("gold_cost", 999999)):
		order_kind = "building_upgrade"
		order_id = upgrade_id
		cost_gold = int(upgrade_data.get("gold_cost", 0))
		cost_production = int(upgrade_data.get("production_cost", 1))
		order_name = "%s · уровень %d" % [str(upgrade_data.get("building_name", "Здание")), target_level]
	elif not province_order.is_empty() and gold >= int(province_order.get("gold_cost", 999999)):
		order_kind = "province_improvement"
		order_id = str(province_order.get("id", ""))
		cost_gold = int(province_order.get("gold_cost", 0))
		cost_production = int(province_order.get("production_cost", 1))
		order_name = str(province_order.get("name", "Улучшение провинции"))
		province_cell = World.array_to_cell(province_order.get("cell", []))
	elif should_recruit and buildings.has(recruit_unlock):
		order_kind = "recruit"
		order_id = recruit_role
	else:
		return ""

	if order_kind == "recruit":
		if not UnitCatalog.is_valid_role(order_id):
			return ""
		var unit_data := UnitCatalog.get_data(order_id)
		var building_id := str(unit_data.get("unlock_building", "barracks"))
		var recruit_multiplier := CityDevelopment.get_recruit_gold_multiplier(str(city.get("specialization", "")), building_id, levels)
		recruit_multiplier *= FactionCatalog.get_recruit_multiplier(order_id, kingdom_faction)
		cost_gold = maxi(1, roundi(float(unit_data.get("gold_cost", 20)) * recruit_multiplier))
		cost_production = int(unit_data.get("production_cost", 3))
		order_name = str(unit_data.get("name", "отряд"))
	elif order_kind == "building":
		if order_id.is_empty() or not BUILDING_COSTS.has(order_id):
			return ""
		var building: Dictionary = BUILDING_COSTS[order_id]
		cost_gold = int(building["gold"])
		cost_production = int(building["production"])
		order_name = str(building["name"])
	elif order_kind == "province_improvement":
		if order_id.is_empty() or province_cell == Vector2i(9999, 9999):
			return ""
	else:
		if order_id.is_empty() or upgrade_data.is_empty():
			return ""
	if gold < cost_gold:
		return ""
	city["gold"] = gold - cost_gold
	var order_record := {
		"kind": order_kind,
		"id": order_id,
		"name": order_name,
		"production_cost": cost_production,
	}
	if order_kind == "building_upgrade":
		order_record["target_level"] = target_level
	if order_kind == "province_improvement":
		order_record["cell"] = [province_cell.x, province_cell.y]
	queue.append(order_record)
	city["build_queue"] = queue
	return "%s заказал: %s" % [city_name, order_name]


static func _get_ai_building_upgrade_id(city: Dictionary, economy_focus: String = "balanced") -> String:
	if not city.get("build_queue", []).is_empty():
		return ""
	var city_level := CityDevelopment.get_city_level(int(city.get("population", 1)))
	var buildings: Array = city.get("buildings", [])
	var levels: Dictionary = city.get("building_levels", {})
	var priorities: Array[String] = ["market", "farm", "workshop", "barracks", "archery_range", "stable"]
	match economy_focus:
		"food":
			priorities = ["farm", "market", "workshop", "barracks", "archery_range", "stable"]
		"production":
			priorities = ["workshop", "market", "farm", "barracks", "archery_range", "stable"]
		"military":
			priorities = ["barracks", "archery_range", "stable", "market", "farm", "workshop"]
	for building_id in priorities:
		if buildings.has(building_id):
			var next_level := int(levels.get(building_id, 1)) + 1
			if next_level <= city_level and not CityDevelopment.get_building_upgrade_data(building_id, next_level).is_empty():
				return building_id
	return ""


static func _get_ai_province_build_order(city: Dictionary, kingdom_faction: Dictionary, world_seed: int, world_generation_version: int) -> Dictionary:
	var improvements: Array = city.get("province_improvements", [])
	var city_level := CityDevelopment.get_city_level(int(city.get("population", 1)))
	var faction_effects := FactionCatalog.get_effects(kingdom_faction)
	var province_slots := mini(6, CityDevelopment.get_province_slots(city_level) + int(faction_effects.get("province_slot_bonus", 0)))
	if improvements.size() >= province_slots:
		return {}
	var center := World.array_to_cell(city.get("cell", []))
	var used: Dictionary = {}
	for item in improvements:
		var cell := World.array_to_cell(item.get("cell", []))
		used["%d:%d" % [cell.x, cell.y]] = true
	for offset in World.neighbors():
		var cell := center + offset
		var key := "%d:%d" % [cell.x, cell.y]
		if used.has(key) or not World.is_inside_world(cell):
			continue
		var terrain := World.terrain_at(cell, world_seed, world_generation_version)
		var improvement_id := CityDevelopment.get_next_improvement_for_terrain(terrain)
		if terrain in ["plain", "farmland"] and str(city.get("specialization", "")) == "commerce":
			improvement_id = "trade_post"
		if not improvement_id.is_empty():
			var data := CityDevelopment.get_improvement_data(improvement_id)
			return {"id": improvement_id, "cell": [cell.x, cell.y], "name": data.get("name", "Улучшение"), "gold_cost": int(data.get("gold_cost", 0)), "production_cost": int(data.get("production_cost", 1))}
	return {}


static func _role_is_unlocked(role_id: String, buildings: Array) -> bool:
	var unit_data := UnitCatalog.get_data(role_id)
	var unlock := str(unit_data.get("unlock_building", "barracks"))
	return buildings.has(unlock)


static func _try_found_ai_city(
		kingdom: Dictionary,
		all_kingdoms: Array[Dictionary],
		player_cell: Vector2i,
		player_city_cells: Array[Vector2i],
		world_seed: int,
		world_generation_version: int,
		neutral_location_cells: Array[Vector2i] = []
) -> String:
	var cities: Array = kingdom.get("cities", [])
	if cities.size() >= 3 or cities.is_empty():
		return ""
	var capital: Dictionary = cities[0]
	if int(capital.get("population", 1)) < 6 or int(capital.get("gold", 0)) < 65:
		return ""
	var capital_cell := World.array_to_cell(capital.get("cell", []))
	var candidate := _find_expansion_cell(capital_cell, all_kingdoms, player_cell, player_city_cells, world_seed, world_generation_version, neutral_location_cells, cities, int(kingdom.get("id", -1)))
	if candidate == Vector2i(9999, 9999):
		return ""
	capital["gold"] = int(capital.get("gold", 0)) - 65
	cities[0] = capital
	var new_city_id := cities.size()
	var new_name := "Новый посад %d" % new_city_id
	cities.append(_make_city_record(new_city_id, new_name, candidate, 3, 5, 40))
	kingdom["cities"] = cities
	return "%s основал %s" % [str(kingdom.get("name", "Король")), new_name]


static func _find_expansion_cell(
		capital_cell: Vector2i,
		kingdoms: Array[Dictionary],
		player_cell: Vector2i,
		player_city_cells: Array[Vector2i],
		world_seed: int,
		world_generation_version: int,
		neutral_location_cells: Array[Vector2i] = [],
		own_city_records: Array = [],
		current_kingdom_id: int = -1
) -> Vector2i:
	var best_cell := Vector2i(9999, 9999)
	var best_score := -999999.0
	for q in range(-8, 9):
		for r in range(-8, 9):
			var offset := Vector2i(q, r)
			var distance := World.hex_distance(Vector2i.ZERO, offset)
			if distance < 4 or distance > 7:
				continue
			var candidate := capital_cell + offset
			if not World.is_inside_world(candidate) or World.terrain_at(candidate, world_seed, world_generation_version) == "water":
				continue
			if neutral_location_cells.has(candidate) or _cell_occupied(candidate, kingdoms, player_cell, player_city_cells):
				continue
			var valid_spacing := true
			for own_city_value in own_city_records:
				if not own_city_value is Dictionary:
					continue
				var own_city_cell := World.array_to_cell(own_city_value.get("cell", []))
				if own_city_cell != capital_cell and World.hex_distance(candidate, own_city_cell) < 5:
					valid_spacing = false
					break
			if not valid_spacing:
				continue
			var candidate_score := StrategicAI.score_expansion_cell(
				candidate, capital_cell, own_city_records, kingdoms, current_kingdom_id,
				player_cell, player_city_cells, world_seed, world_generation_version, neutral_location_cells
			)
			if candidate_score > best_score:
				best_score = candidate_score
				best_cell = candidate
	return best_cell


static func _move_army(
		kingdom: Dictionary,
		kingdoms: Array[Dictionary],
		player_cell: Vector2i,
		player_city_cells: Array[Vector2i],
		world_seed: int,
		world_generation_version: int,
		neutral_location_cells: Array[Vector2i] = [],
		diplomacy_relations: Dictionary = {},
		neutral_locations: Array[Dictionary] = [],
		turn_number: int = 1
) -> String:
	var army: Array = kingdom.get("army", [])
	if army.is_empty():
		return ""
	var index := int(kingdom.get("id", 0))
	var current := World.array_to_cell(kingdom.get("army_cell", []))
	var target := Vector2i(9999, 9999)
	var nearest_distance := 999999
	var pursuing_neutral := false
	var war_plan := StrategicAI.select_war_target(kingdom, kingdoms, diplomacy_relations, player_cell, player_city_cells)
	var war_active := bool(war_plan.get("war_active", false))
	if war_active:
		target = war_plan.get("cell", Vector2i(9999, 9999))
		nearest_distance = World.hex_distance(current, target) if target != Vector2i(9999, 9999) else 999999
		kingdom["target_kingdom_id"] = int(war_plan.get("kingdom_id", -99))
		kingdom["neutral_target_id"] = ""
		if target == Vector2i(9999, 9999):
			return "армия удерживает оборону и не отвлекается на экспедиции"
	else:
		var location_index := _choose_neutral_expedition_target(kingdom, kingdoms, current, neutral_locations)
		if location_index < 0:
			kingdom["neutral_target_id"] = ""
			return ""
		var location: Dictionary = neutral_locations[location_index]
		var location_cell := World.array_to_cell(location.get("cell", []))
		var location_distance := World.hex_distance(current, location_cell)
		kingdom["neutral_target_id"] = str(location.get("id", ""))
		pursuing_neutral = true
		if location_distance <= 1:
			var result := _resolve_ai_neutral_battle(army, location, turn_number)
			army = result.get("army", [])
			kingdom["army"] = army
			location["guards"] = result.get("guards", [])
			location["guardian_health"] = float(result.get("guardian_health", location.get("guardian_health", 0.0)))
			if bool(result.get("victory", false)):
				location["cleared"] = true
				location["cleared_by"] = index
				location["cleared_turn"] = turn_number
				location["guards"] = []
				location["guardian_health"] = 0.0
				_grant_ai_location_reward(kingdom, location, army)
				kingdom["last_action"] = "Экспедиция очистила %s" % WorldLocationCatalog.get_display_name(str(location.get("type", "ancient_ruins")))
				kingdom["neutral_target_id"] = ""
				neutral_locations[location_index] = location
				return str(kingdom["last_action"])
			kingdom["neutral_target_id"] = ""
			neutral_locations[location_index] = location
			return "экспедиция потерпела поражение у %s; охрана ослаблена" % WorldLocationCatalog.get_display_name(str(location.get("type", "ancient_ruins")))
		target = location_cell
		nearest_distance = location_distance

	if nearest_distance <= 1:
		return ""
	var best := current
	var best_distance := nearest_distance
	for offset in World.neighbors():
		var candidate := current + offset
		if not World.is_inside_world(candidate) or World.terrain_at(candidate, world_seed, world_generation_version) == "water":
			continue
		if neutral_location_cells.has(candidate):
			continue
		if _cell_occupied(candidate, kingdoms, player_cell, player_city_cells):
			continue
		var distance := World.hex_distance(candidate, target)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	if best == current:
		return ""
	kingdom["army_cell"] = World.cell_to_array(best)
	if pursuing_neutral:
		return "экспедиция движется к нейтральной точке"
	return "армия выступила против противника по военному договору"


static func _choose_neutral_expedition_target(
		kingdom: Dictionary,
		kingdoms: Array[Dictionary],
		current: Vector2i,
		neutral_locations: Array[Dictionary]
) -> int:
	if neutral_locations.is_empty():
		return -1
	var kingdom_id := int(kingdom.get("id", -1))
	var army: Array = kingdom.get("army", [])
	var reserved_ids: Dictionary = {}
	for other in kingdoms:
		var other_army_value: Variant = other.get("army", [])
		if int(other.get("id", -1)) == kingdom_id or not bool(other.get("alive", true)):
			continue
		if not other_army_value is Array or other_army_value.is_empty():
			continue
		var reserved_id := str(other.get("neutral_target_id", ""))
		if not reserved_id.is_empty():
			reserved_ids[reserved_id] = true
	var current_target_id := str(kingdom.get("neutral_target_id", ""))
	var best_index := -1
	var best_score := 999999
	for location_index in range(neutral_locations.size()):
		var location: Dictionary = neutral_locations[location_index]
		if bool(location.get("cleared", false)):
			continue
		var location_id := str(location.get("id", ""))
		if reserved_ids.has(location_id):
			continue
		var location_cell := World.array_to_cell(location.get("cell", []))
		var distance := World.hex_distance(current, location_cell)
		if distance < 1 or distance > 24:
			continue
		var guard_tier := clampi(int(location.get("guard_tier", 1)), 1, 3)
		var required_units := 2 + guard_tier
		if army.size() < required_units:
			continue
		var attack_strength := _estimate_force_strength(army)
		var defense_strength := _estimate_location_strength(location)
		if defense_strength > 0.0 and attack_strength < defense_strength * 0.72:
			continue
		var reward: Dictionary = location.get("reward", {})
		var reward_value := int(reward.get("gold", 0)) + int(reward.get("production", 0)) * 2 + int(reward.get("food", 0))
		var score := distance + guard_tier * 3 - mini(4, floori(float(reward_value) / 35.0))
		if location_id == current_target_id:
			score -= 5
		if score < best_score:
			best_score = score
			best_index = location_index
	return best_index


static func _estimate_force_strength(units: Array) -> float:
	var total := 0.0
	for unit_value in units:
		if not unit_value is Dictionary:
			continue
		var role_id := str(unit_value.get("role", UnitCatalog.ROLE_MELEE))
		var data := UnitCatalog.get_data(role_id)
		var max_health := maxf(1.0, float(data.get("max_health", 125.0)))
		var health_ratio := clampf(float(unit_value.get("health", max_health)) / max_health, 0.0, 1.0)
		var experience := int(unit_value.get("experience", 0))
		var veterancy: Dictionary = UnitCatalog.get_veterancy_data(experience)
		total += (float(data.get("damage", 19.0)) * 1.35 + max_health * 0.055) * health_ratio * float(veterancy.get("damage_multiplier", 1.0))
	return total


static func _estimate_location_strength(location: Dictionary) -> float:
	var guards_value: Variant = location.get("guards", [])
	var guards: Array = guards_value if guards_value is Array else []
	var total := _estimate_force_strength(guards)
	var tier := clampi(int(location.get("guard_tier", 1)), 1, 3)
	total += maxf(0.0, float(location.get("guardian_health", 95.0))) * 0.12 + float(16 + tier * 3)
	return total


static func _resolve_ai_neutral_battle(army_source: Array, location: Dictionary, turn_number: int) -> Dictionary:
	var army: Array[Dictionary] = []
	for unit in army_source:
		if unit is Dictionary:
			army.append(unit.duplicate(true))
	var guards: Array[Dictionary] = []
	var raw_guards: Variant = location.get("guards", [])
	if raw_guards is Array:
		for unit in raw_guards:
			if unit is Dictionary:
				guards.append(unit.duplicate(true))
	var guardian_health := clampf(float(location.get("guardian_health", 95.0)), 0.0, 210.0)
	var tier := clampi(int(location.get("guard_tier", 1)), 1, 3)
	for round_index in range(24):
		if army.is_empty() or (guards.is_empty() and guardian_health <= 0.0):
			break
		# The first strike alternates by turn to avoid giving every expedition
		# an unconditional initiative advantage.
		if posmod(round_index + turn_number, 2) == 0:
			for unit in army:
				if guards.is_empty() and guardian_health <= 0.0:
					break
				var damage := _get_strategic_unit_damage(unit)
				if not guards.is_empty():
					_damage_weakest_unit(guards, damage)
				else:
					guardian_health = maxf(0.0, guardian_health - damage)
			_cleanup_dead_units(guards)
			for unit in guards:
				if army.is_empty():
					break
				_damage_weakest_unit(army, _get_strategic_unit_damage(unit))
			_cleanup_dead_units(army)
			if guardian_health > 0.0 and not army.is_empty():
				_damage_weakest_unit(army, 17.0 + float(tier * 3))
			_cleanup_dead_units(army)
		else:
			for unit in guards:
				if army.is_empty():
					break
				_damage_weakest_unit(army, _get_strategic_unit_damage(unit))
			_cleanup_dead_units(army)
			if guardian_health > 0.0 and not army.is_empty():
				_damage_weakest_unit(army, 17.0 + float(tier * 3))
			_cleanup_dead_units(army)
			for unit in army:
				if guards.is_empty() and guardian_health <= 0.0:
					break
				var damage := _get_strategic_unit_damage(unit)
				if not guards.is_empty():
					_damage_weakest_unit(guards, damage)
				else:
					guardian_health = maxf(0.0, guardian_health - damage)
			_cleanup_dead_units(guards)
	var victory := not army.is_empty() and guards.is_empty() and guardian_health <= 0.0
	return {
		"army": army,
		"guards": guards,
		"guardian_health": guardian_health,
		"victory": victory,
	}


static func _get_strategic_unit_damage(unit: Dictionary) -> float:
	var role_id := str(unit.get("role", UnitCatalog.ROLE_MELEE))
	var data := UnitCatalog.get_data(role_id)
	var veterancy: Dictionary = UnitCatalog.get_veterancy_data(int(unit.get("experience", 0)))
	return float(data.get("damage", 19.0)) * float(veterancy.get("damage_multiplier", 1.0))


static func _damage_weakest_unit(units: Array[Dictionary], raw_damage: float) -> void:
	if units.is_empty():
		return
	var target_index := 0
	var lowest_ratio := 2.0
	for unit_index in range(units.size()):
		var unit: Dictionary = units[unit_index]
		var max_health := maxf(1.0, UnitCatalog.get_max_health(str(unit.get("role", UnitCatalog.ROLE_MELEE))))
		var ratio := float(unit.get("health", max_health)) / max_health
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			target_index = unit_index
	var target: Dictionary = units[target_index]
	var armor := float(UnitCatalog.get_data(str(target.get("role", UnitCatalog.ROLE_MELEE))).get("armor", 0.0))
	target["health"] = maxf(0.0, float(target.get("health", 1.0)) - maxf(1.0, raw_damage - armor * 0.35))
	if float(target["health"]) <= 0.0:
		units.remove_at(target_index)
	else:
		units[target_index] = target


static func _cleanup_dead_units(units: Array[Dictionary]) -> void:
	for unit_index in range(units.size() - 1, -1, -1):
		if float(units[unit_index].get("health", 0.0)) <= 0.0:
			units.remove_at(unit_index)


static func _grant_ai_location_reward(kingdom: Dictionary, location: Dictionary, army: Array) -> void:
	var location_cell := World.array_to_cell(location.get("cell", []))
	var cities: Array = kingdom.get("cities", [])
	if cities.is_empty():
		return
	var best_city_index := 0
	var best_distance := 999999
	for city_index in range(cities.size()):
		var city: Dictionary = cities[city_index]
		var distance := World.hex_distance(location_cell, World.array_to_cell(city.get("cell", [])))
		if distance < best_distance:
			best_distance = distance
			best_city_index = city_index
	var best_city_record: Dictionary = cities[best_city_index]
	var reward: Dictionary = location.get("reward", {})
	best_city_record["gold"] = maxi(0, int(best_city_record.get("gold", 0))) + maxi(0, int(reward.get("gold", 0)))
	best_city_record["food"] = maxi(0, int(best_city_record.get("food", 0))) + maxi(0, int(reward.get("food", 0)))
	best_city_record["production_bank"] = maxi(0, int(best_city_record.get("production_bank", 0))) + maxi(0, int(reward.get("production", 0)))
	cities[best_city_index] = best_city_record
	kingdom["cities"] = cities
	var type_id := str(location.get("type", ""))
	if type_id == "monster_lair":
		for unit in army:
			unit["experience"] = clampi(int(unit.get("experience", 0)) + 12, 0, 999999)
	elif type_id == "abandoned_mine":
		pass # The mine's persistent +2 production is applied each AI turn.
	elif type_id == "forgotten_shrine":
		for unit in army:
			unit["health"] = UnitCatalog.get_max_health(str(unit.get("role", UnitCatalog.ROLE_MELEE)))
	elif type_id == "mercenary_camp":
		if army.size() < 24:
			army.append({"role": UnitCatalog.ROLE_MELEE, "health": UnitCatalog.get_max_health(UnitCatalog.ROLE_MELEE), "experience": 0})
		else:
			best_city_record["gold"] = int(best_city_record.get("gold", 0)) + 25
			cities[best_city_index] = best_city_record
		kingdom["army"] = army
		kingdom["cities"] = cities


static func _apply_ai_mine_income(kingdom: Dictionary, neutral_locations: Array[Dictionary]) -> void:
	var kingdom_id := int(kingdom.get("id", -1))
	var cities: Array = kingdom.get("cities", [])
	if cities.is_empty():
		return
	var changed := false
	for location in neutral_locations:
		if not bool(location.get("cleared", false)) or int(location.get("cleared_by", -2)) != kingdom_id or str(location.get("type", "")) != "abandoned_mine":
			continue
		var location_cell := World.array_to_cell(location.get("cell", []))
		var best_city_index := 0
		var best_distance := 999999
		for city_index in range(cities.size()):
			var city: Dictionary = cities[city_index]
			var distance := World.hex_distance(location_cell, World.array_to_cell(city.get("cell", [])))
			if distance < best_distance:
				best_distance = distance
				best_city_index = city_index
		var target_city: Dictionary = cities[best_city_index]
		target_city["production_bank"] = maxi(0, int(target_city.get("production_bank", 0))) + 2
		cities[best_city_index] = target_city
		changed = true
	if changed:
		kingdom["cities"] = cities

static func _cell_occupied(
		cell: Vector2i,
		kingdoms: Array[Dictionary],
		player_cell: Vector2i,
		player_city_cells: Array[Vector2i]
) -> bool:
	if cell == player_cell or player_city_cells.has(cell):
		return true
	for kingdom in kingdoms:
		var capital := World.array_to_cell(kingdom.get("capital_cell", []))
		if capital == cell:
			return true
		var army_cell := World.array_to_cell(kingdom.get("army_cell", []))
		if army_cell == cell:
			return true
		for city in kingdom.get("cities", []):
			var city_cell := World.array_to_cell(city.get("cell", []))
			if city_cell == cell:
				return true
	return false


static func _make_city_record(id: int, city_name: String, cell: Vector2i, population: int, food: int, gold: int) -> Dictionary:
	return {
		"id": id,
		"name": city_name,
		"cell": World.cell_to_array(cell),
		"population": population,
		"food": food,
		"gold": gold,
		"production_bank": 0,
		"buildings": [],
		"build_queue": [],
		"specialization": "",
		"building_levels": {},
		"province_improvements": [],
		"last_event": "",
	}


static func _make_starting_army(index: int) -> Array[Dictionary]:
	var army: Array[Dictionary] = []
	for _i in range(3):
		army.append({"role": UnitCatalog.ROLE_MELEE, "health": UnitCatalog.get_max_health(UnitCatalog.ROLE_MELEE), "experience": 0})
	if index == 0:
		for _i in range(2):
			army.append({"role": UnitCatalog.ROLE_RANGED, "health": UnitCatalog.get_max_health(UnitCatalog.ROLE_RANGED), "experience": 0})
	else:
		army.append({"role": UnitCatalog.ROLE_RANGED, "health": UnitCatalog.get_max_health(UnitCatalog.ROLE_RANGED), "experience": 0})
	if index % 2 == 0 and index != 0:
		army.append({"role": UnitCatalog.ROLE_SPEAR, "health": UnitCatalog.get_max_health(UnitCatalog.ROLE_SPEAR), "experience": 0})
	return army


static func _make_hero_record(hero_name: String, hero_title: String) -> Dictionary:
	return {
		"name": hero_name,
		"title": hero_title,
		"level": 1,
		"experience": 0,
		"skill_points": 0,
		"skills": {"leadership": 0, "tactics": 0, "might": 0},
		"health": 210.0,
		"wounded_turns": 0,
	}
