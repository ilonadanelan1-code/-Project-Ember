extends Node

## Shared campaign state for the strategy map, city economy and tactical battles.
## Only persistent data is stored here; scene nodes and UI remain in their own scenes.

const UNIT_CATALOG_SCRIPT = preload("res://scripts/unit_catalog.gd")
const BattlefieldBiomesScript = preload("res://scripts/battlefield_biomes.gd")
const ROLE_MELEE := "melee"
const ROLE_RANGED := "ranged"
const ROLE_SPEAR := "spear"
const ROLE_CAVALRY := "cavalry"
const ARMY_CAPACITY := 24
const SAVE_PATH := "user://project_ember_campaign.json"
const SAVE_TEMP_PATH := SAVE_PATH + ".tmp"
const SAVE_BACKUP_PATH := SAVE_PATH + ".bak"
const SAVE_VERSION := 1

const CITY_BUILDINGS := {
	"farm": {
		"name": "Ферма",
		"gold_cost": 25,
		"production_cost": 5,
		"description": "+5 еды каждый ход",
	},
	"market": {
		"name": "Рынок",
		"gold_cost": 35,
		"production_cost": 6,
		"description": "+4 золота каждый ход",
	},
	"workshop": {
		"name": "Мастерская",
		"gold_cost": 45,
		"production_cost": 8,
		"description": "+3 производства каждый ход",
	},
	"barracks": {
		"name": "Казармы",
		"gold_cost": 50,
		"production_cost": 8,
		"description": "Открывают найм мечников и копейщиков",
	},
	"archery_range": {
		"name": "Стрельбище",
		"gold_cost": 40,
		"production_cost": 8,
		"description": "Открывает найм лучников · нужны казармы",
	},
	"stable": {
		"name": "Конюшня",
		"gold_cost": 60,
		"production_cost": 10,
		"description": "Открывает найм кавалерии · нужны казармы",
	},
}

var campaign_started: bool = false
var campaign_lost: bool = false
var turn_number: int = 1
var player_moves_left: int = 1
var player_cell: Vector2i = Vector2i(-2, 0)
var enemy_cell: Vector2i = Vector2i(2, 0)
var enemy_present: bool = true
var player_units: Array[Dictionary] = []
var enemy_units: Array[Dictionary] = []
var player_hero: Dictionary = {}
var enemy_hero: Dictionary = {}

# First playable city: the capital exists from the start. Settler-based expansion
# is deliberately deferred until the basic city -> army -> battle loop is stable.
var city_founded: bool = true
var city_name: String = "Каменный Брод"
var city_cell: Vector2i = Vector2i(-3, 1)
var city_population: int = 5
var city_food: int = 8
var city_gold: int = 120
var city_production_bank: int = 0
var city_buildings: Array[String] = []
var city_build_queue: Array[Dictionary] = []
var city_last_event: String = ""
var cities: Array[Dictionary] = []
var active_city_id: int = 0
var settler_active: bool = false
var settler_cell: Vector2i = Vector2i.ZERO
var settler_moves_left: int = 1

var battle_in_progress: bool = false
var battle_origin_cell: Vector2i = Vector2i.ZERO
var battle_enemy_cell: Vector2i = Vector2i.ZERO
# Runtime-only battle presentation data; deliberately excluded from campaign saves.
var battlefield_biome_id: String = BattlefieldBiomesScript.GRASSLAND
var battlefield_seed: int = 841207
var last_battle_result: Dictionary = {}
var last_battle_report_pending: bool = false
var _prevent_save_overwrite: bool = false


func _ready() -> void:
	if load_campaign():
		return
	if FileAccess.file_exists(SAVE_PATH) and not _preserve_unreadable_save():
		push_error("Project Ember: the existing save could not be backed up; automatic saving is disabled to protect it.")
		new_campaign(false)
		return
	new_campaign()


func _preserve_unreadable_save() -> bool:
	var backup_path := SAVE_PATH + ".corrupt"
	var suffix := 1
	while FileAccess.file_exists(backup_path):
		backup_path = "%s.corrupt.%d" % [SAVE_PATH, suffix]
		suffix += 1
	var source_absolute := ProjectSettings.globalize_path(SAVE_PATH)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	var copy_error: Error = DirAccess.copy_absolute(source_absolute, backup_absolute)
	if copy_error != OK:
		push_error("Project Ember: could not preserve unreadable save. Error code: %d" % int(copy_error))
		return false
	push_warning("Project Ember: unreadable save preserved as %s before starting a fresh campaign." % backup_path)
	return true


func new_campaign(persist: bool = true) -> void:
	_prevent_save_overwrite = false
	campaign_started = true
	campaign_lost = false
	turn_number = 1
	player_moves_left = 1
	player_cell = Vector2i(-2, 0)
	enemy_cell = Vector2i(2, 0)
	enemy_present = true
	player_units = _make_starting_army()
	enemy_units = _make_starting_army()
	player_hero = _make_hero_record("Эдрик", "Правитель Каменного Брода")
	enemy_hero = _make_hero_record("Варг", "Воевода Красного Отряда")
	city_founded = true
	city_name = "Каменный Брод"
	city_cell = Vector2i(-3, 1)
	city_population = 5
	city_food = 8
	city_gold = 120
	city_production_bank = 0
	city_buildings.clear()
	city_build_queue.clear()
	city_last_event = ""
	cities.clear()
	active_city_id = 0
	cities.append(_make_city_record(0, city_name, city_cell, city_population, city_food, city_gold, city_production_bank, city_buildings, city_build_queue))
	settler_active = false
	settler_cell = Vector2i.ZERO
	settler_moves_left = 1
	battle_in_progress = false
	last_battle_result.clear()
	last_battle_report_pending = false
	if persist:
		save_campaign()
	else:
		_prevent_save_overwrite = true


func _make_starting_army() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for _index in range(3):
		result.append({"role": ROLE_MELEE, "health": 125.0})
	for _index in range(2):
		result.append({"role": ROLE_RANGED, "health": 72.0})
	return result


func _make_hero_record(hero_name: String, hero_title: String) -> Dictionary:
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


func get_hero_max_health(hero: Dictionary) -> float:
	var level := clampi(int(hero.get("level", 1)), 1, 30)
	var skills_value: Variant = hero.get("skills", {})
	var skills: Dictionary = skills_value if skills_value is Dictionary else {}
	var might := clampi(int(skills.get("might", 0)), 0, 5)
	return 210.0 + float(level - 1) * 16.0 + float(might) * 14.0


func get_hero_xp_to_next_level() -> int:
	var level := clampi(int(player_hero.get("level", 1)), 1, 30)
	return 100 + (level - 1) * 75


func award_hero_experience(victory: bool, kills: int, damage: float) -> int:
	if player_hero.is_empty():
		player_hero = _make_hero_record("Эдрик", "Правитель Каменного Брода")
	var gain := 35 + maxi(0, kills) * 10 + floori(maxf(0.0, damage) / 40.0)
	gain += (60 if victory else 20)
	var old_max_health := get_hero_max_health(player_hero)
	player_hero["experience"] = maxi(0, int(player_hero.get("experience", 0))) + gain
	while int(player_hero.get("level", 1)) < 30:
		var threshold := 100 + (int(player_hero.get("level", 1)) - 1) * 75
		if int(player_hero.get("experience", 0)) < threshold:
			break
		player_hero["experience"] = int(player_hero.get("experience", 0)) - threshold
		player_hero["level"] = int(player_hero.get("level", 1)) + 1
		player_hero["skill_points"] = int(player_hero.get("skill_points", 0)) + 1
		var current_health := float(player_hero.get("health", old_max_health))
		if current_health > 0.0:
			player_hero["health"] = minf(get_hero_max_health(player_hero), current_health + 20.0)
	save_campaign()
	return gain


func upgrade_hero_skill(skill_id: String) -> bool:
	if not ["leadership", "tactics", "might"].has(skill_id):
		return false
	if int(player_hero.get("skill_points", 0)) <= 0:
		return false
	var skills_value: Variant = player_hero.get("skills", {})
	var skills: Dictionary = skills_value.duplicate(true) if skills_value is Dictionary else {}
	var current_rank := clampi(int(skills.get(skill_id, 0)), 0, 5)
	if current_rank >= 5:
		return false
	var old_max_health := get_hero_max_health(player_hero)
	skills[skill_id] = current_rank + 1
	player_hero["skills"] = skills
	player_hero["skill_points"] = int(player_hero.get("skill_points", 0)) - 1
	if skill_id == "might":
		var current_health := float(player_hero.get("health", old_max_health))
		if current_health > 0.0:
			player_hero["health"] = minf(
				get_hero_max_health(player_hero),
				current_health + get_hero_max_health(player_hero) - old_max_health
			)
	save_campaign()
	return true


func _read_hero_record(value: Variant, fallback: Dictionary) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else fallback
	var result := fallback.duplicate(true)
	result["name"] = str(source.get("name", result.get("name", "Командир")))
	result["title"] = str(source.get("title", result.get("title", "Правитель")))
	result["level"] = clampi(int(source.get("level", 1)), 1, 30)
	result["experience"] = maxi(0, int(source.get("experience", 0)))
	result["skill_points"] = clampi(int(source.get("skill_points", 0)), 0, 99)
	var raw_skills: Variant = source.get("skills", {})
	var skills: Dictionary = raw_skills.duplicate(true) if raw_skills is Dictionary else {}
	for skill_id in ["leadership", "tactics", "might"]:
		skills[skill_id] = clampi(int(skills.get(skill_id, 0)), 0, 5)
	result["skills"] = skills
	result["wounded_turns"] = clampi(int(source.get("wounded_turns", 0)), 0, 5)
	result["health"] = clampf(
		float(source.get("health", get_hero_max_health(result))),
		0.0,
		get_hero_max_health(result)
	)
	return result


func _recover_campaign_heroes() -> void:
	for hero in [player_hero, enemy_hero]:
		if hero.is_empty():
			continue
		var max_health := get_hero_max_health(hero)
		var current_health := clampf(float(hero.get("health", max_health)), 0.0, max_health)
		if current_health <= 0.0:
			hero["health"] = max_health * 0.35
			hero["wounded_turns"] = 2
		elif int(hero.get("wounded_turns", 0)) > 0:
			hero["health"] = minf(max_health, current_health + max_health * 0.12)
			hero["wounded_turns"] = maxi(0, int(hero.get("wounded_turns", 0)) - 1)
		else:
			hero["health"] = minf(max_health, current_health + max_health * 0.18)


func begin_battle(biome_id: String = "") -> bool:
	if battle_in_progress or campaign_lost or not enemy_present:
		return false
	if player_units.is_empty() or enemy_units.is_empty():
		return false
	battle_origin_cell = player_cell
	battle_enemy_cell = enemy_cell
	battlefield_biome_id = biome_id if BattlefieldBiomesScript.biome_ids().has(biome_id) else BattlefieldBiomesScript.resolve_for_cell(battle_origin_cell)
	battlefield_seed = BattlefieldBiomesScript.seed_for_cell(battle_origin_cell)
	battle_in_progress = true
	return true


func complete_battle(
		player_survivors: Array[Dictionary],
		enemy_survivors: Array[Dictionary],
		victory: bool,
		stats: Dictionary,
		player_commander_health: float = -1.0,
		enemy_commander_health: float = -1.0
) -> void:
	if not battle_in_progress:
		return

	player_units = _copy_unit_records(player_survivors)
	enemy_units = _copy_unit_records(enemy_survivors)
	last_battle_result = stats.duplicate(true)
	last_battle_result["victory"] = victory
	last_battle_result["player_survivors"] = player_units.size()
	last_battle_result["enemy_survivors"] = enemy_units.size()
	if player_commander_health >= 0.0:
		player_hero["health"] = clampf(player_commander_health, 0.0, get_hero_max_health(player_hero))
		if player_commander_health <= 0.0:
			player_hero["wounded_turns"] = 2
	if enemy_commander_health >= 0.0:
		enemy_hero["health"] = clampf(enemy_commander_health, 0.0, get_hero_max_health(enemy_hero))
		if enemy_commander_health <= 0.0:
			enemy_hero["wounded_turns"] = 2
	var hero_xp_gained := award_hero_experience(
		victory,
		int(stats.get("player_kills", 0)),
		float(stats.get("player_damage", 0.0))
	)
	last_battle_result["hero_xp_gained"] = hero_xp_gained
	last_battle_result["hero_level"] = int(player_hero.get("level", 1))
	last_battle_result["hero_skill_points"] = int(player_hero.get("skill_points", 0))
	last_battle_report_pending = true

	if victory:
		enemy_present = false
		player_cell = battle_enemy_cell
	else:
		enemy_present = not enemy_units.is_empty()
		player_cell = battle_origin_cell

	campaign_lost = player_units.is_empty()
	battle_in_progress = false
	player_moves_left = 0
	save_campaign()


func _copy_unit_records(source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in source:
		result.append(record.duplicate(true))
	return result


func _make_city_record(id: int, name: String, cell: Vector2i, population: int, food: int, gold: int, production: int, buildings: Array, queue: Array) -> Dictionary:
	return {"id": id, "name": name, "cell": [cell.x, cell.y], "population": population, "food": food, "gold": gold, "production_bank": production, "buildings": buildings.duplicate(), "build_queue": queue.duplicate(true), "last_event": ""}

func _save_active_city() -> void:
	if cities.is_empty() or active_city_id < 0 or active_city_id >= cities.size():
		return
	cities[active_city_id] = _make_city_record(active_city_id, city_name, city_cell, city_population, city_food, city_gold, city_production_bank, city_buildings, city_build_queue)
	cities[active_city_id]["last_event"] = city_last_event

func _load_active_city() -> void:
	if cities.is_empty():
		return
	active_city_id = clampi(active_city_id, 0, cities.size() - 1)
	var c: Dictionary = cities[active_city_id]
	city_name = str(c.get("name", "Поселение"))
	var xy: Array = c.get("cell", [-3, 1])
	city_cell = Vector2i(int(xy[0]), int(xy[1]))
	city_population = clampi(int(c.get("population", 2)), 1, 20)
	city_food = maxi(0, int(c.get("food", 0)))
	city_gold = maxi(0, int(c.get("gold", 0)))
	city_production_bank = maxi(0, int(c.get("production_bank", 0)))
	city_buildings.clear()
	for id in c.get("buildings", []):
		if CITY_BUILDINGS.has(str(id)) and not city_buildings.has(str(id)):
			city_buildings.append(str(id))
	city_build_queue = _read_city_queue(c.get("build_queue", []))
	city_last_event = str(c.get("last_event", ""))

func select_city_at(cell: Vector2i) -> bool:
	_save_active_city()
	for i in range(cities.size()):
		var xy: Array = cities[i].get("cell", [])
		if xy.size() >= 2 and Vector2i(int(xy[0]), int(xy[1])) == cell:
			active_city_id = i
			_load_active_city()
			return true
	return false

func get_city_index_at(cell: Vector2i) -> int:
	for i in range(cities.size()):
		var xy: Array = cities[i].get("cell", [])
		if xy.size() >= 2 and Vector2i(int(xy[0]), int(xy[1])) == cell:
			return i
	return -1

func get_city_owner_at(cell: Vector2i) -> int:
	var best := -1
	var best_distance := 99
	for i in range(cities.size()):
		var xy: Array = cities[i].get("cell", [])
		if xy.size() < 2:
			continue
		var c := Vector2i(int(xy[0]), int(xy[1]))
		var d := int((absi(cell.x-c.x)+absi(cell.y-c.y)+absi((cell.x+cell.y)-(c.x+c.y)))/2)
		if d <= 1 and d < best_distance:
			best = i
			best_distance = d
	return best

func _has_settler_order() -> bool:
	for c in cities:
		for order in c.get("build_queue", []):
			if str(order.get("kind", "")) == "settler":
				return true
	for order in city_build_queue:
		if str(order.get("kind", "")) == "settler":
			return true
	return false

func can_queue_settler() -> bool:
	return not campaign_lost and city_population >= 3 and city_gold >= 45 and not settler_active and not _has_settler_order()

func queue_settler() -> bool:
	if not can_queue_settler():
		return false
	city_gold -= 45
	city_population -= 1
	city_build_queue.append({"kind": "settler", "id": "settler", "name": "Поселенец", "production_cost": 10})
	city_last_event = "Поселенец добавлен в очередь."
	save_campaign()
	return true

func can_found_city(cell: Vector2i) -> bool:
	if not settler_active or get_city_index_at(cell) >= 0 or cities.size() >= 5 or cell == player_cell or (enemy_present and cell == enemy_cell):
		return false
	for c in cities:
		var xy: Array = c.get("cell", [])
		if xy.size() < 2:
			continue
		var other := Vector2i(int(xy[0]), int(xy[1]))
		var d := int((absi(cell.x-other.x)+absi(cell.y-other.y)+absi((cell.x+cell.y)-(other.x+other.y)))/2)
		if d < 3:
			return false
	return true

func found_city(cell: Vector2i) -> bool:
	if not can_found_city(cell):
		return false
	_save_active_city()
	var new_id := cities.size()
	var names := ["Сосновый Дол", "Серебряный Ручей", "Солнечный Холм", "Тихая Гавань"]
	cities.append(_make_city_record(new_id, names[(new_id - 1) % names.size()], cell, 2, 0, 35, 0, [], []))
	settler_active = false
	settler_moves_left = 1
	active_city_id = new_id
	_load_active_city()
	city_last_event = "Основан новый город: " + city_name
	save_campaign()
	return true

func _advance_one_city_turn() -> void:
	var income := get_city_income()
	city_food += int(income["food"])
	city_gold += int(income["gold"])
	city_production_bank += int(income["production"])
	if city_population < 20 and city_food >= 12:
		city_food -= 12
		city_population += 1
	_process_city_queue()

# -----------------------------------------------------------------------------
# City economy and production queue
# -----------------------------------------------------------------------------

func city_has_building(building_id: String) -> bool:
	return building_id in city_buildings


func city_is_building_queued(building_id: String) -> bool:
	for order in city_build_queue:
		if str(order.get("kind", "")) == "building" and str(order.get("id", "")) == building_id:
			return true
	return false


func get_city_building_data(building_id: String) -> Dictionary:
	if not CITY_BUILDINGS.has(building_id):
		return {}
	var building_data: Dictionary = CITY_BUILDINGS[building_id]
	return building_data.duplicate(true)


func get_city_income() -> Dictionary:
	var food_income := 2
	var gold_income := 4
	var production_income := 4
	if city_has_building("farm"):
		food_income += 5
	if city_has_building("market"):
		gold_income += 4
	if city_has_building("workshop"):
		production_income += 3
	return {
		"food": food_income,
		"gold": gold_income,
		"production": production_income,
	}


func can_queue_building(building_id: String) -> bool:
	if campaign_lost or not city_founded or not CITY_BUILDINGS.has(building_id):
		return false
	if city_has_building(building_id) or city_is_building_queued(building_id):
		return false
	if (building_id == "archery_range" or building_id == "stable") and not city_has_building("barracks"):
		return false
	var data: Dictionary = CITY_BUILDINGS[building_id]
	return city_gold >= int(data["gold_cost"])


func queue_building(building_id: String) -> bool:
	if not can_queue_building(building_id):
		return false
	var data: Dictionary = CITY_BUILDINGS[building_id]
	city_gold -= int(data["gold_cost"])
	city_build_queue.append({
		"kind": "building",
		"id": building_id,
		"name": str(data["name"]),
		"production_cost": int(data["production_cost"]),
	})
	city_last_event = "%s добавлена в очередь строительства." % str(data["name"])
	save_campaign()
	return true


func get_recruit_data(role_name: String) -> Dictionary:
	return UNIT_CATALOG_SCRIPT.get_data(role_name)


func can_queue_recruit(role_name: String) -> bool:
	if campaign_lost or not city_founded:
		return false
	var data: Dictionary = get_recruit_data(role_name)
	if data.is_empty():
		return false
	var unlock_building := str(data.get("unlock_building", "barracks"))
	if not city_has_building(unlock_building):
		return false
	if _count_queued_recruits() + player_units.size() >= ARMY_CAPACITY:
		return false
	return city_gold >= int(data.get("gold_cost", 0))


func queue_recruit(role_name: String) -> bool:
	if not can_queue_recruit(role_name):
		return false
	var data: Dictionary = get_recruit_data(role_name)
	var recruit_name := str(data.get("name", "Отряд"))
	city_gold -= int(data.get("gold_cost", 0))
	city_build_queue.append({
		"kind": "recruit",
		"id": role_name,
		"name": recruit_name,
		"production_cost": int(data.get("production_cost", 1)),
	})
	city_last_event = "%s добавлен в очередь найма." % recruit_name
	save_campaign()
	return true


func get_city_queue_summary() -> String:
	if city_build_queue.is_empty():
		return "Очередь пуста"
	var current: Dictionary = city_build_queue[0]
	var item_name := str(current.get("name", "Заказ"))
	var required := maxi(1, int(current.get("production_cost", 1)))
	return "В очереди: %s · производство %d/%d · заказов: %d" % [
		item_name,
		mini(city_production_bank, required),
		required,
		city_build_queue.size(),
	]


func advance_campaign_turn() -> void:
	turn_number += 1
	_recover_campaign_heroes()
	player_moves_left = 1
	settler_moves_left = 1
	var previous_city_id := active_city_id
	_save_active_city()
	for i in range(cities.size()):
		active_city_id = i
		_load_active_city()
		city_last_event = ""
		_advance_one_city_turn()
		_save_active_city()
	active_city_id = previous_city_id
	_load_active_city()


func _find_settler_spawn_cell(origin: Vector2i) -> Vector2i:
	# Keep settlers on the playable 91-hex map, including when a new city is
	# founded at the map edge. StrategyMap will make the selected tile passable.
	var offsets: Array[Vector2i] = [
		Vector2i(0, 1),
		Vector2i(1, 0),
		Vector2i(1, -1),
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(-1, 1),
	]
	for offset in offsets:
		var candidate: Vector2i = origin + offset
		var radius_distance := int((absi(candidate.x) + absi(candidate.y) + absi(candidate.x + candidate.y)) / 2)
		if radius_distance > 5 or get_city_index_at(candidate) >= 0:
			continue
		if candidate == player_cell or (enemy_present and candidate == enemy_cell):
			continue
		return candidate
	return origin


func _process_city_queue() -> void:
	# Bound queue processing so malformed save data can never lock the main thread.
	var orders_to_check: int = mini(city_build_queue.size(), 32)
	for _index in range(orders_to_check):
		if city_build_queue.is_empty():
			break
		var order: Dictionary = city_build_queue[0]
		var required: int = maxi(1, int(order.get("production_cost", 1)))
		if city_production_bank < required:
			break
		city_production_bank -= required
		city_build_queue.pop_front()
		var order_kind := str(order.get("kind", ""))
		var order_id := str(order.get("id", ""))
		var order_name := str(order.get("name", "Заказ"))
		if order_kind == "building":
			if CITY_BUILDINGS.has(order_id) and not city_has_building(order_id):
				city_buildings.append(order_id)
				city_last_event += "%s построена. " % order_name
		elif order_kind == "recruit":
			if UNIT_CATALOG_SCRIPT.is_valid_role(order_id) and player_units.size() < ARMY_CAPACITY:
				var max_health: float = UNIT_CATALOG_SCRIPT.get_max_health(order_id)
				player_units.append({"role": order_id, "health": max_health})
				city_last_event += "%s прибыл в армию. " % order_name
		elif order_kind == "settler" and not settler_active:
			settler_active = true
			settler_cell = _find_settler_spawn_cell(city_cell)
			city_last_event += "Поселенец готов к основанию нового города. "

	if city_last_event.is_empty():
		city_last_event = "Город получил ресурсы за ход."

func _count_queued_recruits() -> int:
	var count := 0
	for i in range(cities.size()):
		var orders: Array = city_build_queue if i == active_city_id else cities[i].get("build_queue", [])
		for order in orders:
			if str(order.get("kind", "")) == "recruit":
				count += 1
	return count


func save_campaign() -> bool:
	# Do not overwrite the last safe strategic state during an unfinished tactical battle
	# or when a damaged save could not be preserved during startup.
	if battle_in_progress or _prevent_save_overwrite:
		return false
	_save_active_city()
	var save_data := {
		"version": SAVE_VERSION,
		"campaign_lost": campaign_lost,
		"turn_number": turn_number,
		"player_moves_left": player_moves_left,
		"player_cell": [player_cell.x, player_cell.y],
		"enemy_cell": [enemy_cell.x, enemy_cell.y],
		"enemy_present": enemy_present,
		"player_units": player_units,
		"enemy_units": enemy_units,
		"player_hero": player_hero,
		"enemy_hero": enemy_hero,
		"last_battle_result": last_battle_result,
		"last_battle_report_pending": last_battle_report_pending,
		"city_founded": city_founded,
		"city_name": city_name,
		"city_cell": [city_cell.x, city_cell.y],
		"city_population": city_population,
		"city_food": city_food,
		"city_gold": city_gold,
		"city_production_bank": city_production_bank,
		"city_buildings": city_buildings,
		"city_build_queue": city_build_queue,
		"cities": cities,
		"active_city_id": active_city_id,
		"settler_active": settler_active,
		"settler_cell": [settler_cell.x, settler_cell.y],
		"settler_moves_left": settler_moves_left,
	}
	var file := FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Project Ember: could not open temporary campaign save.")
		return false
	file.store_string(JSON.stringify(save_data))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TEMP_PATH))
		push_warning("Project Ember: temporary campaign save write failed.")
		return false

	var verification := _read_save_dictionary(SAVE_TEMP_PATH)
	if verification.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TEMP_PATH))
		push_warning("Project Ember: temporary campaign save did not validate.")
		return false

	var main_absolute := ProjectSettings.globalize_path(SAVE_PATH)
	var temporary_absolute := ProjectSettings.globalize_path(SAVE_TEMP_PATH)
	var backup_absolute := ProjectSettings.globalize_path(SAVE_BACKUP_PATH)
	if FileAccess.file_exists(SAVE_BACKUP_PATH):
		var remove_backup_error: Error = DirAccess.remove_absolute(backup_absolute)
		if remove_backup_error != OK:
			DirAccess.remove_absolute(temporary_absolute)
			push_warning("Project Ember: could not rotate the previous backup.")
			return false
	if FileAccess.file_exists(SAVE_PATH):
		var rotate_error: Error = DirAccess.rename_absolute(main_absolute, backup_absolute)
		if rotate_error != OK:
			DirAccess.remove_absolute(temporary_absolute)
			push_warning("Project Ember: could not preserve the previous campaign save.")
			return false

	var replace_error: Error = DirAccess.rename_absolute(temporary_absolute, main_absolute)
	if replace_error != OK:
		if FileAccess.file_exists(SAVE_BACKUP_PATH) and not FileAccess.file_exists(SAVE_PATH):
			DirAccess.rename_absolute(backup_absolute, main_absolute)
		push_warning("Project Ember: could not atomically replace the campaign save.")
		return false
	return true


func _read_save_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", -1)) != SAVE_VERSION:
		return {}
	var player_cell_data: Variant = data.get("player_cell", [])
	var enemy_cell_data: Variant = data.get("enemy_cell", [])
	if not player_cell_data is Array or player_cell_data.size() < 2:
		return {}
	if not enemy_cell_data is Array or enemy_cell_data.size() < 2:
		return {}
	return data


func load_campaign() -> bool:
	var data := _read_save_dictionary(SAVE_PATH)
	if data.is_empty():
		data = _read_save_dictionary(SAVE_BACKUP_PATH)
		if data.is_empty():
			return false
		# Preserve an unreadable primary file before attempting recovery.
		if FileAccess.file_exists(SAVE_PATH):
			if not _preserve_unreadable_save():
				_prevent_save_overwrite = true
		if not _prevent_save_overwrite:
			var restore_error: Error = DirAccess.copy_absolute(
				ProjectSettings.globalize_path(SAVE_BACKUP_PATH),
				ProjectSettings.globalize_path(SAVE_PATH)
			)
			if restore_error != OK:
				_prevent_save_overwrite = true
				push_warning("Project Ember: loaded the backup in memory; restoring the primary save failed.")
	var player_cell_data: Variant = data.get("player_cell", [])
	var enemy_cell_data: Variant = data.get("enemy_cell", [])
	var loaded_player := _read_unit_records(data.get("player_units", []))
	var loaded_enemy := _read_unit_records(data.get("enemy_units", []))
	var lost := bool(data.get("campaign_lost", false))
	if loaded_player.is_empty() and not lost:
		return false

	campaign_started = true
	campaign_lost = lost
	turn_number = maxi(1, int(data.get("turn_number", 1)))
	player_moves_left = clampi(int(data.get("player_moves_left", 1)), 0, 1)
	player_cell = Vector2i(int(player_cell_data[0]), int(player_cell_data[1]))
	enemy_cell = Vector2i(int(enemy_cell_data[0]), int(enemy_cell_data[1]))
	player_units = loaded_player
	enemy_units = loaded_enemy
	var player_hero_fallback := _make_hero_record("Эдрик", "Правитель Каменного Брода")
	var enemy_hero_fallback := _make_hero_record("Варг", "Воевода Красного Отряда")
	player_hero = _read_hero_record(data.get("player_hero", player_hero_fallback), player_hero_fallback)
	enemy_hero = _read_hero_record(data.get("enemy_hero", enemy_hero_fallback), enemy_hero_fallback)
	enemy_present = bool(data.get("enemy_present", true)) and not enemy_units.is_empty()
	var loaded_result: Variant = data.get("last_battle_result", {})
	if loaded_result is Dictionary:
		last_battle_result = loaded_result
	else:
		last_battle_result.clear()
	last_battle_report_pending = bool(data.get("last_battle_report_pending", false))

	# Older v0.3.0 saves do not contain city fields. Supply the initial city data
	# when loading those saves so existing campaigns remain usable.
	city_founded = bool(data.get("city_founded", true))
	city_name = str(data.get("city_name", "Каменный Брод"))
	var city_cell_data: Variant = data.get("city_cell", [-3, 1])
	if city_cell_data is Array and city_cell_data.size() >= 2:
		city_cell = Vector2i(int(city_cell_data[0]), int(city_cell_data[1]))
	else:
		city_cell = Vector2i(-3, 1)
	city_population = clampi(int(data.get("city_population", 5)), 1, 20)
	city_food = maxi(0, int(data.get("city_food", 8)))
	city_gold = maxi(0, int(data.get("city_gold", 120)))
	city_production_bank = maxi(0, int(data.get("city_production_bank", 0)))
	city_buildings.clear()
	var loaded_buildings: Variant = data.get("city_buildings", [])
	if loaded_buildings is Array:
		for building_id in loaded_buildings:
			if CITY_BUILDINGS.has(str(building_id)) and not city_buildings.has(str(building_id)):
				city_buildings.append(str(building_id))
	city_build_queue = _read_city_queue(data.get("city_build_queue", []))
	city_last_event = ""
	cities.clear()
	var loaded_cities: Variant = data.get("cities", [])
	if loaded_cities is Array:
		for raw in loaded_cities:
			if not raw is Dictionary:
				continue
			var xy: Variant = raw.get("cell", [])
			if not xy is Array or xy.size() < 2:
				continue
			var city_id := cities.size()
			var record := _make_city_record(city_id, str(raw.get("name", "Поселение %d" % (city_id + 1))), Vector2i(int(xy[0]), int(xy[1])), clampi(int(raw.get("population", 2)), 1, 20), maxi(0, int(raw.get("food", 0))), maxi(0, int(raw.get("gold", 0))), maxi(0, int(raw.get("production_bank", 0))), raw.get("buildings", []), _read_city_queue(raw.get("build_queue", [])))
			record["last_event"] = str(raw.get("last_event", ""))
			cities.append(record)
	if cities.is_empty():
		cities.append(_make_city_record(0, city_name, city_cell, city_population, city_food, city_gold, city_production_bank, city_buildings, city_build_queue))
	active_city_id = clampi(int(data.get("active_city_id", 0)), 0, cities.size() - 1)
	settler_active = bool(data.get("settler_active", false))
	var settler_xy: Variant = data.get("settler_cell", [city_cell.x, city_cell.y + 1])
	if settler_xy is Array and settler_xy.size() >= 2:
		settler_cell = Vector2i(int(settler_xy[0]), int(settler_xy[1]))
	settler_moves_left = clampi(int(data.get("settler_moves_left", 1)), 0, 1)
	_load_active_city()
	battle_in_progress = false
	return true


func _read_city_queue(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for item in value:
		if not item is Dictionary:
			continue
		var kind := str(item.get("kind", ""))
		var item_id := str(item.get("id", ""))
		var valid_building := kind == "building" and CITY_BUILDINGS.has(item_id)
		var valid_recruit := kind == "recruit" and UNIT_CATALOG_SCRIPT.is_valid_role(item_id)
		var valid_settler := kind == "settler" and item_id == "settler"
		if not valid_building and not valid_recruit and not valid_settler:
			continue
		result.append({
			"kind": kind,
			"id": item_id,
			"name": str(item.get("name", "Заказ")),
			"production_cost": maxi(1, int(item.get("production_cost", 1))),
		})
	return result


func _read_unit_records(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for item in value:
		if not item is Dictionary:
			continue
		var role_name := str(item.get("role", ROLE_MELEE))
		if not UNIT_CATALOG_SCRIPT.is_valid_role(role_name):
			continue
		var max_health: float = UNIT_CATALOG_SCRIPT.get_max_health(role_name)
		var default_health := max_health
		var health_value := clampf(float(item.get("health", default_health)), 0.0, max_health)
		if health_value > 0.0:
			result.append({"role": role_name, "health": health_value})
	return result