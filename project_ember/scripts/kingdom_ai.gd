extends RefCounted
class_name EmberKingdomAI

const World = preload("res://scripts/world_generator.gd")
const UnitCatalog = preload("res://scripts/unit_catalog.gd")

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
		var record := {
			"id": index,
			"name": KINGDOM_NAMES[index],
			"ruler": RULER_NAMES[index],
			"capital_name": CAPITAL_NAMES[index],
			"capital_cell": World.cell_to_array(capital),
			"army_cell": World.cell_to_array(army_cell),
			"army": _make_starting_army(index),
			"cities": [city],
			"hero": _make_hero_record(RULER_NAMES[index], "Правитель " + KINGDOM_NAMES[index]),
			"alive": true,
			"last_action": "Развивает столицу и собирает войска",
			"next_move_turn": 2 + (index % 3),
			"next_expansion_turn": 8 + (index % 4),
			"target_kingdom_id": (index + 1) % World.KINGDOM_COUNT,
			"military_doctrine": index % 4,
		}
		result.append(record)
	return result


static func normalize_kingdom(raw: Dictionary, fallback: Dictionary) -> Dictionary:
	var result: Dictionary = fallback.duplicate(true)
	var index := int(fallback.get("id", 0))
	result["name"] = str(raw.get("name", result.get("name", KINGDOM_NAMES[index % KINGDOM_NAMES.size()])))
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
			if health > 0.0 and army.size() < 24:
				army.append({"role": role, "health": health})
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
	return result


static func process_turns(
		kingdoms: Array[Dictionary],
		turn_number: int,
		player_cell: Vector2i,
		player_city_cells: Array[Vector2i],
		world_seed: int
) -> Array[String]:
	var events: Array[String] = []
	for index in range(kingdoms.size()):
		var kingdom: Dictionary = kingdoms[index]
		if not bool(kingdom.get("alive", true)):
			continue
		var action_parts: Array[String] = []
		var cities: Array = kingdom.get("cities", [])
		var army: Array = kingdom.get("army", [])
		for city_index in range(cities.size()):
			var city: Dictionary = cities[city_index]
			var buildings: Array = city.get("buildings", [])
			var food_income := 2 + (5 if buildings.has("farm") else 0)
			var gold_income := 4 + (4 if buildings.has("market") else 0)
			var production_income := 4 + (3 if buildings.has("workshop") else 0)
			city["food"] = int(city.get("food", 0)) + food_income
			city["gold"] = int(city.get("gold", 0)) + gold_income
			city["production_bank"] = int(city.get("production_bank", 0)) + production_income
			if int(city.get("population", 1)) < 20 and int(city["food"]) >= 12:
				city["food"] = int(city["food"]) - 12
				city["population"] = int(city.get("population", 1)) + 1
			var queue: Array = city.get("build_queue", [])
			if not queue.is_empty():
				var order: Dictionary = queue[0]
				var required := maxi(1, int(order.get("production_cost", 1)))
				if int(city["production_bank"]) >= required:
					city["production_bank"] = int(city["production_bank"]) - required
					queue.pop_front()
					var order_id := str(order.get("id", ""))
					if str(order.get("kind", "")) == "building" and BUILDING_COSTS.has(order_id):
						if not buildings.has(order_id):
							buildings.append(order_id)
							action_parts.append("%s построили %s" % [str(city.get("name", "Город")), str(BUILDING_COSTS[order_id]["name"])])
					elif str(order.get("kind", "")) == "recruit" and UnitCatalog.is_valid_role(order_id) and army.size() < 24:
						army.append({"role": order_id, "health": UnitCatalog.get_max_health(order_id)})
						action_parts.append("%s нанял: %s" % [str(city.get("name", "Город")), str(UnitCatalog.get_data(order_id).get("name", "отряд"))])
			city["buildings"] = buildings
			city["build_queue"] = queue
			cities[city_index] = city

		for city_index in range(cities.size()):
			var city: Dictionary = cities[city_index]
			var order_event := _queue_next_order(city, kingdom, army, turn_number, city_index)
			if not order_event.is_empty():
				action_parts.append(order_event)
			cities[city_index] = city

		kingdom["cities"] = cities
		kingdom["army"] = army
		var next_expansion := int(kingdom.get("next_expansion_turn", 8))
		if turn_number >= next_expansion and cities.size() < 3:
			var expansion := _try_found_ai_city(kingdom, kingdoms, player_cell, player_city_cells, world_seed)
			if not expansion.is_empty():
				cities = kingdom.get("cities", [])
				action_parts.append(expansion)
			kingdom["next_expansion_turn"] = turn_number + 8 + (index % 4)

		var next_move := int(kingdom.get("next_move_turn", 2))
		if turn_number >= next_move:
			var movement := _move_army(kingdom, kingdoms, player_cell, player_city_cells, world_seed)
			if not movement.is_empty():
				action_parts.append(movement)
			kingdom["next_move_turn"] = turn_number + 2 + (index % 3)

		if action_parts.is_empty():
			action_parts.append("содержит войска и пополняет казну")
		kingdom["last_action"] = "; ".join(action_parts.slice(0, 2))
		kingdoms[index] = kingdom
		events.append("%s: %s" % [str(kingdom.get("name", "Королевство")), str(kingdom["last_action"])])
	return events


static func _queue_next_order(city: Dictionary, kingdom: Dictionary, army: Array, turn_number: int, city_index: int) -> String:
	var queue: Array = city.get("build_queue", [])
	if not queue.is_empty() or army.size() >= 24:
		return ""
	var buildings: Array = city.get("buildings", [])
	var gold := int(city.get("gold", 0))
	var city_name := str(city.get("name", "Город"))
	var order_id := ""
	var order_kind := ""
	var order_name := ""
	var cost_gold := 0
	var cost_production := 0

	if not buildings.has("barracks") and gold >= 50:
		order_id = "barracks"
	elif city_index > 0 and not buildings.has("farm") and gold >= 25:
		order_id = "farm"
	elif city_index == 0 and army.size() < 9 and buildings.has("barracks"):
		order_kind = "recruit"
		order_id = UnitCatalog.ROLE_MELEE if (turn_number + int(kingdom.get("id", 0))) % 3 != 0 else UnitCatalog.ROLE_SPEAR
	elif not buildings.has("farm") and gold >= 25:
		order_id = "farm"
	elif city_index == 0 and army.size() >= 9 and not buildings.has("archery_range") and gold >= 40:
		order_id = "archery_range"
	elif city_index == 0 and army.size() >= 12 and not buildings.has("stable") and gold >= 60:
		order_id = "stable"
	elif not buildings.has("market") and gold >= 35:
		order_id = "market"
	elif not buildings.has("workshop") and gold >= 45:
		order_id = "workshop"
	elif city_index == 0 and army.size() < 20:
		order_kind = "recruit"
		if buildings.has("stable") and (turn_number + int(kingdom.get("id", 0))) % 5 == 0:
			order_id = UnitCatalog.ROLE_CAVALRY
		elif buildings.has("archery_range") and (turn_number + int(kingdom.get("id", 0))) % 3 == 0:
			order_id = UnitCatalog.ROLE_RANGED
		elif (turn_number + int(kingdom.get("id", 0))) % 4 == 0:
			order_id = UnitCatalog.ROLE_SPEAR
		else:
			order_id = UnitCatalog.ROLE_MELEE
		if not _role_is_unlocked(order_id, buildings):
			order_id = UnitCatalog.ROLE_MELEE
	else:
		return ""

	if order_kind == "recruit":
		if not UnitCatalog.is_valid_role(order_id):
			return ""
		var unit_data := UnitCatalog.get_data(order_id)
		cost_gold = int(unit_data.get("gold_cost", 20))
		cost_production = int(unit_data.get("production_cost", 3))
		order_name = str(unit_data.get("name", "отряд"))
	else:
		if order_id.is_empty() or not BUILDING_COSTS.has(order_id):
			return ""
		order_kind = "building"
		var building: Dictionary = BUILDING_COSTS[order_id]
		cost_gold = int(building["gold"])
		cost_production = int(building["production"])
		order_name = str(building["name"])
	if gold < cost_gold:
		return ""
	city["gold"] = gold - cost_gold
	queue.append({
		"kind": order_kind,
		"id": order_id,
		"name": order_name,
		"production_cost": cost_production,
	})
	city["build_queue"] = queue
	return "%s заказал: %s" % [city_name, order_name]


static func _role_is_unlocked(role_id: String, buildings: Array) -> bool:
	var unit_data := UnitCatalog.get_data(role_id)
	var unlock := str(unit_data.get("unlock_building", "barracks"))
	return buildings.has(unlock)


static func _try_found_ai_city(
		kingdom: Dictionary,
		all_kingdoms: Array[Dictionary],
		player_cell: Vector2i,
		player_city_cells: Array[Vector2i],
		world_seed: int
) -> String:
	var cities: Array = kingdom.get("cities", [])
	if cities.size() >= 3 or cities.is_empty():
		return ""
	var capital: Dictionary = cities[0]
	if int(capital.get("population", 1)) < 6 or int(capital.get("gold", 0)) < 65:
		return ""
	var capital_cell := World.array_to_cell(capital.get("cell", []))
	var candidate := _find_expansion_cell(capital_cell, all_kingdoms, player_cell, player_city_cells, world_seed)
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
		world_seed: int
) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for q in range(-8, 9):
		for r in range(-8, 9):
			var offset := Vector2i(q, r)
			var distance := World.hex_distance(Vector2i.ZERO, offset)
			if distance < 4 or distance > 7:
				continue
			var candidate := capital_cell + offset
			if not World.is_inside_world(candidate) or World.terrain_at(candidate, world_seed) == "water":
				continue
			if _cell_occupied(candidate, kingdoms, player_cell, player_city_cells):
				continue
			candidates.append(candidate)
	if candidates.is_empty():
		return Vector2i(9999, 9999)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ah := absi(a.x * 31 + a.y * 17) % 97
		var bh := absi(b.x * 31 + b.y * 17) % 97
		return ah < bh
	)
	return candidates[0]


static func _move_army(
		kingdom: Dictionary,
		kingdoms: Array[Dictionary],
		player_cell: Vector2i,
		player_city_cells: Array[Vector2i],
		world_seed: int
) -> String:
	var army: Array = kingdom.get("army", [])
	if army.is_empty():
		return ""
	var index := int(kingdom.get("id", 0))
	var current := World.array_to_cell(kingdom.get("army_cell", []))
	var target := player_cell
	if index != 0 and kingdoms.size() > 1:
		var target_id := int(kingdom.get("target_kingdom_id", (index + 1) % kingdoms.size()))
		var target_kingdom: Dictionary = kingdoms[target_id]
		target = World.array_to_cell(target_kingdom.get("capital_cell", []))
	var current_distance := World.hex_distance(current, target)
	if current_distance <= 2:
		return ""
	var best := current
	var best_distance := current_distance
	for offset in World.neighbors():
		var candidate := current + offset
		if not World.is_inside_world(candidate) or World.terrain_at(candidate, world_seed) == "water":
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
	return "армия вышла к гексу %d:%d" % [best.x, best.y]


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
		"last_event": "",
	}


static func _make_starting_army(index: int) -> Array[Dictionary]:
	var army: Array[Dictionary] = []
	for _i in range(3):
		army.append({"role": UnitCatalog.ROLE_MELEE, "health": UnitCatalog.get_max_health(UnitCatalog.ROLE_MELEE)})
	if index == 0:
		for _i in range(2):
			army.append({"role": UnitCatalog.ROLE_RANGED, "health": UnitCatalog.get_max_health(UnitCatalog.ROLE_RANGED)})
	else:
		army.append({"role": UnitCatalog.ROLE_RANGED, "health": UnitCatalog.get_max_health(UnitCatalog.ROLE_RANGED)})
	if index % 2 == 0 and index != 0:
		army.append({"role": UnitCatalog.ROLE_SPEAR, "health": UnitCatalog.get_max_health(UnitCatalog.ROLE_SPEAR)})
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
