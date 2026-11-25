extends Node

## Shared campaign state for the strategy map, city economy and tactical battles.
## Only persistent data is stored here; scene nodes and UI remain in their own scenes.

const UNIT_CATALOG_SCRIPT = preload("res://scripts/unit_catalog.gd")
const ArmyUpgradeCatalogScript = preload("res://scripts/army_upgrade_catalog.gd")
const CityDevelopmentCatalogScript = preload("res://scripts/city_development_catalog.gd")
const BattlefieldBiomesScript = preload("res://scripts/battlefield_biomes.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")
const KingdomAIScript = preload("res://scripts/kingdom_ai.gd")
const WorldLocationCatalogScript = preload("res://scripts/world_location_catalog.gd")
const WorldEventCatalogScript = preload("res://scripts/world_event_catalog.gd")
const FactionCatalogScript = preload("res://scripts/faction_catalog.gd")
const DiplomacyCatalogScript = preload("res://scripts/diplomacy_catalog.gd")
const ROLE_MELEE := "melee"
const ROLE_RANGED := "ranged"
const ROLE_SPEAR := "spear"
const ROLE_CAVALRY := "cavalry"
const ARMY_CAPACITY := 24
const SAVE_PATH := "user://project_ember_campaign.json"
const SAVE_TEMP_PATH := SAVE_PATH + ".tmp"
const SAVE_BACKUP_PATH := SAVE_PATH + ".bak"
const SAVE_VERSION := 1
const WORLD_RADIUS := WorldGeneratorScript.WORLD_RADIUS
const WORLD_HEX_COUNT := WorldGeneratorScript.WORLD_HEX_COUNT
const KINGDOM_COUNT := WorldGeneratorScript.KINGDOM_COUNT

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
var army_upgrades: Dictionary = {"melee": 0, "ranged": 0, "spear": 0, "cavalry": 0}
var enemy_units: Array[Dictionary] = []
var player_hero: Dictionary = {}
var player_faction: Dictionary = FactionCatalogScript.get_legacy_selection()
var faction_setup_pending: bool = false
var enemy_hero: Dictionary = {}
var world_seed: int = WorldGeneratorScript.DEFAULT_SEED
var world_generation_version: int = WorldGeneratorScript.WORLD_GENERATION_VERSION
var kingdoms: Array[Dictionary] = []
var diplomacy_relations: Dictionary = {}
var pending_diplomacy_offers: Array[Dictionary] = []
var last_diplomacy_events: Array[String] = []
var last_kingdom_events: Array[String] = []
var neutral_locations: Array[Dictionary] = []
var pending_world_event: Dictionary = {}
var last_world_event_text: String = ""
var world_events_resolved: int = 0
var battle_kingdom_id: int = -1
var battle_target_type: String = "kingdom"
var battle_location_id: String = ""
var explored_cells: Dictionary = {}
var visible_cells: Dictionary = {}

const ARMY_VISION_RADIUS := 9
const CITY_VISION_RADIUS := 4
const SETTLER_VISION_RADIUS := 3

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
var city_specialization: String = ""
var city_building_levels: Dictionary = {}
var city_province_improvements: Array[Dictionary] = []
var army_upkeep_last_due: int = 0
var army_upkeep_last_paid: int = 0
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
		prepare_new_campaign(true)
		return
	prepare_new_campaign(false)


func prepare_new_campaign(preserve_existing_save: bool = false) -> void:
	## Builds a fresh campaign in memory and waits for the player to choose a faction.
	## A protected unreadable save is never overwritten by the setup confirmation.
	new_campaign(false)
	player_faction = {}
	faction_setup_pending = true
	_prevent_save_overwrite = preserve_existing_save


func apply_player_faction(raw_selection: Dictionary) -> bool:
	if not faction_setup_pending or not FactionCatalogScript.is_valid_selection(raw_selection):
		return false
	player_faction = FactionCatalogScript.normalize_selection(raw_selection)
	var starting_resources := FactionCatalogScript.apply_starting_bonus(
		player_faction,
		{"food": city_food, "gold": city_gold, "production": city_production_bank},
		player_units
	)
	city_food = int(starting_resources.get("food", city_food))
	city_gold = int(starting_resources.get("gold", city_gold))
	city_production_bank = int(starting_resources.get("production", city_production_bank))
	faction_setup_pending = false
	_save_active_city()
	refresh_fog_of_war()
	save_campaign()
	return true


func get_player_faction_summary() -> String:
	if player_faction.is_empty() or str(player_faction.get("people_id", FactionCatalogScript.LEGACY_ID)) == FactionCatalogScript.LEGACY_ID:
		return "Наследная держава"
	var people_data := FactionCatalogScript.get_people(str(player_faction.get("people_id", "")))
	var culture_data := FactionCatalogScript.get_culture(str(player_faction.get("culture_id", "")))
	return "%s · %s" % [str(people_data.get("name", "Народ")), str(culture_data.get("name", "Культура"))]


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
	faction_setup_pending = false
	player_faction = FactionCatalogScript.get_legacy_selection()
	campaign_started = true
	campaign_lost = false
	turn_number = 1
	player_moves_left = 1
	player_cell = Vector2i(-2, 0)
	world_seed = WorldGeneratorScript.DEFAULT_SEED
	world_generation_version = WorldGeneratorScript.WORLD_GENERATION_VERSION
	player_units = _make_starting_army()
	army_upgrades = {"melee": 0, "ranged": 0, "spear": 0, "cavalry": 0}
	player_hero = _make_hero_record("Эдрик", "Правитель Каменного Брода")
	kingdoms = KingdomAIScript.create_initial_kingdoms(world_seed)
	diplomacy_relations = DiplomacyCatalogScript.create_initial_relations(kingdoms.size(), world_seed)
	pending_diplomacy_offers.clear()
	last_diplomacy_events.clear()
	neutral_locations = WorldLocationCatalogScript.generate_locations(world_seed, world_generation_version)
	pending_world_event.clear()
	last_world_event_text = ""
	world_events_resolved = 0
	last_kingdom_events.clear()
	battle_kingdom_id = -1
	battle_target_type = "kingdom"
	battle_location_id = ""
	_sync_primary_kingdom()
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
	city_specialization = ""
	city_building_levels.clear()
	city_province_improvements.clear()
	army_upkeep_last_due = 0
	army_upkeep_last_paid = 0
	cities.clear()
	active_city_id = 0
	cities.append(_make_city_record(0, city_name, city_cell, city_population, city_food, city_gold, city_production_bank, city_buildings, city_build_queue))
	settler_active = false
	settler_cell = Vector2i.ZERO
	settler_moves_left = 1
	battle_in_progress = false
	last_battle_result.clear()
	last_battle_report_pending = false
	explored_cells.clear()
	visible_cells.clear()
	refresh_fog_of_war()
	if persist:
		save_campaign()
	else:
		_prevent_save_overwrite = true


func _make_starting_army() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for _index in range(3):
		result.append({"role": ROLE_MELEE, "health": 125.0, "experience": 0})
	for _index in range(2):
		result.append({"role": ROLE_RANGED, "health": 72.0, "experience": 0})
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


func _recover_hero_record(hero: Dictionary) -> void:
	if hero.is_empty():
		return
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


func _ensure_hero_ready_for_battle(hero: Dictionary) -> void:
	if hero.is_empty():
		return
	var max_health := get_hero_max_health(hero)
	var current_health := clampf(float(hero.get("health", max_health)), 0.0, max_health)
	if current_health <= 0.0:
		# A defeated ruler can remain in a legacy kingdom record at zero HP.
		# Never spawn a visible, selectable but inert commander in a battle.
		hero["health"] = max_health * 0.35
		hero["wounded_turns"] = maxi(2, int(hero.get("wounded_turns", 0)))
	else:
		hero["health"] = current_health


func _recover_campaign_heroes() -> void:
	_recover_hero_record(player_hero)
	if kingdoms.is_empty():
		_recover_hero_record(enemy_hero)
		return

	# Recover the actual hero records stored on every kingdom. Recovering only
	# the convenience enemy_hero copy loses the update when _sync_primary_kingdom
	# reloads the ruler from kingdoms on the same turn.
	for index in range(kingdoms.size()):
		var kingdom: Dictionary = kingdoms[index]
		var fallback := _make_hero_record(
			str(kingdom.get("ruler", "Воевода")),
			"Правитель " + str(kingdom.get("name", "Королевства"))
		)
		var hero := _read_hero_record(kingdom.get("hero", fallback), fallback)
		_recover_hero_record(hero)
		kingdom["hero"] = hero.duplicate(true)
		kingdoms[index] = kingdom

	var primary: Dictionary = kingdoms[0]
	var primary_fallback := _make_hero_record(
		str(primary.get("ruler", "Воевода")),
		"Правитель " + str(primary.get("name", "Королевства"))
	)
	enemy_hero = _read_hero_record(primary.get("hero", primary_fallback), primary_fallback)


func begin_battle(biome_id: String = "", kingdom_id: int = -1) -> bool:
	if battle_in_progress or campaign_lost or player_units.is_empty():
		return false
	if kingdom_id < 0:
		kingdom_id = get_kingdom_index_at_army(enemy_cell)
	if kingdom_id < 0 or kingdom_id >= kingdoms.size():
		return false
	var target_kingdom: Dictionary = kingdoms[kingdom_id]
	var target_army: Array[Dictionary] = _read_unit_records(target_kingdom.get("army", []))
	if target_army.is_empty():
		return false
	var diplomatic_record := DiplomacyCatalogScript.get_record(diplomacy_relations, -1, kingdom_id)
	var current_treaty := str(diplomatic_record.get("treaty", "peace"))
	if current_treaty == "vassal" and turn_number <= int(diplomatic_record.get("treaty_until", 0)):
		return false
	if current_treaty != "war":
		if turn_number < int(diplomatic_record.get("truce_until", 0)):
			return false
		DiplomacyCatalogScript.set_treaty(diplomacy_relations, -1, kingdom_id, "war", turn_number)
		var provoked_record := DiplomacyCatalogScript.get_record(diplomacy_relations, -1, kingdom_id)
		provoked_record["war_reason"] = "battle_provocation"
		DiplomacyCatalogScript.set_record(diplomacy_relations, -1, kingdom_id, provoked_record)
		DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, -35, turn_number)
		_record_diplomacy_event("Ты нарушил мир и начал войну с державой «%s»." % str(target_kingdom.get("name", "Королевство")))
	battle_kingdom_id = kingdom_id
	battle_target_type = "kingdom"
	battle_location_id = ""
	enemy_units = target_army
	enemy_cell = WorldGeneratorScript.array_to_cell(target_kingdom.get("army_cell", []))
	var default_enemy_hero := _make_hero_record(
		str(target_kingdom.get("ruler", "Воевода")),
		"Правитель " + str(target_kingdom.get("name", "Королевства"))
	)
	enemy_hero = _read_hero_record(target_kingdom.get("hero", default_enemy_hero), default_enemy_hero)
	_ensure_hero_ready_for_battle(player_hero)
	_ensure_hero_ready_for_battle(enemy_hero)
	# Persist this safety recovery so a damaged old save cannot respawn the same
	# enemy commander at zero health on every subsequent battle.
	target_kingdom["hero"] = enemy_hero.duplicate(true)
	kingdoms[kingdom_id] = target_kingdom
	battle_origin_cell = player_cell
	battle_enemy_cell = enemy_cell
	var battle_terrain_map: Dictionary = {}
	for offset in WorldGeneratorScript.neighbors():
		var neighbor := battle_origin_cell + offset
		battle_terrain_map[neighbor] = get_world_terrain(neighbor)
	var generated_biome := BattlefieldBiomesScript.resolve_from_terrain_map(battle_terrain_map, battle_origin_cell)
	battlefield_biome_id = biome_id if BattlefieldBiomesScript.biome_ids().has(biome_id) else generated_biome
	battlefield_seed = BattlefieldBiomesScript.seed_for_cell(battle_origin_cell)
	battle_in_progress = true
	return true


func get_neutral_location_index_at(cell: Vector2i, include_cleared: bool = true) -> int:
	for index in range(neutral_locations.size()):
		var location: Dictionary = neutral_locations[index]
		if not include_cleared and bool(location.get("cleared", false)):
			continue
		if WorldGeneratorScript.array_to_cell(location.get("cell", [])) == cell:
			return index
	return -1


func get_neutral_location_by_id(location_id: String) -> Dictionary:
	for location in neutral_locations:
		if str(location.get("id", "")) == location_id:
			return location.duplicate(true)
	return {}


func begin_location_battle(location_id: String) -> bool:
	if battle_in_progress or campaign_lost or player_units.is_empty():
		return false
	var location_index := -1
	for index in range(neutral_locations.size()):
		if str(neutral_locations[index].get("id", "")) == location_id:
			location_index = index
			break
	if location_index < 0:
		return false
	var location: Dictionary = neutral_locations[location_index]
	if bool(location.get("cleared", false)):
		return false
	var location_cell := WorldGeneratorScript.array_to_cell(location.get("cell", []))
	if WorldGeneratorScript.hex_distance(player_cell, location_cell) > 1:
		return false
	var guards_value: Variant = location.get("guards", [])
	var guards := _read_unit_records(guards_value)
	var saved_guardian_health := clampf(float(location.get("guardian_health", 95.0 + float(int(location.get("guard_tier", 1)) - 1) * 30.0)), 0.0, 210.0)
	if guards.is_empty() and saved_guardian_health <= 0.0:
		return false
	battle_target_type = "location"
	battle_location_id = location_id
	battle_kingdom_id = -2
	enemy_units = guards
	enemy_cell = location_cell
	battle_origin_cell = player_cell
	battle_enemy_cell = location_cell
	var battle_terrain_map: Dictionary = {}
	for offset in WorldGeneratorScript.neighbors():
		var neighbor := location_cell + offset
		battle_terrain_map[neighbor] = get_world_terrain(neighbor)
	battlefield_biome_id = BattlefieldBiomesScript.resolve_from_terrain_map(battle_terrain_map, location_cell)
	battlefield_seed = BattlefieldBiomesScript.seed_for_cell(location_cell)
	var type_id := str(location.get("type", "ancient_ruins"))
	var guardian_name := "Старший хранитель"
	match type_id:
		"monster_lair": guardian_name = "Вожак логова"
		"abandoned_mine": guardian_name = "Главарь шахтёров"
		"forgotten_shrine": guardian_name = "Хранитель святилища"
		"mercenary_camp": guardian_name = "Капитан наёмников"
	enemy_hero = _make_hero_record(guardian_name, WorldLocationCatalogScript.get_display_name(type_id))
	enemy_hero["health"] = saved_guardian_health
	_ensure_hero_ready_for_battle(enemy_hero)
	# Keep guardian health synchronized with the recovered battle record.
	location["guardian_health"] = float(enemy_hero.get("health", saved_guardian_health))
	neutral_locations[location_index] = location
	battle_in_progress = true
	return true


func _find_nearest_player_city_index(cell: Vector2i) -> int:
	if cities.is_empty():
		return -1
	var best_city_index := 0
	var best_distance := 999999
	for index in range(cities.size()):
		var city: Dictionary = cities[index]
		var city_cell_value := WorldGeneratorScript.array_to_cell(city.get("cell", []))
		var distance := WorldGeneratorScript.hex_distance(cell, city_cell_value)
		if distance < best_distance:
			best_distance = distance
			best_city_index = index
	return best_city_index


func _grant_neutral_location_reward(location_index: int) -> String:
	if location_index < 0 or location_index >= neutral_locations.size() or cities.is_empty():
		return ""
	_save_active_city()
	var location: Dictionary = neutral_locations[location_index]
	var location_cell := WorldGeneratorScript.array_to_cell(location.get("cell", []))
	var best_city_index := _find_nearest_player_city_index(location_cell)
	if best_city_index < 0:
		return ""
	var reward: Dictionary = location.get("reward", {})
	var target_city: Dictionary = cities[best_city_index]
	var gold_gain := maxi(0, int(reward.get("gold", 0)))
	var food_gain := maxi(0, int(reward.get("food", 0)))
	var production_gain := maxi(0, int(reward.get("production", 0)))
	target_city["gold"] = maxi(0, int(target_city.get("gold", 0))) + gold_gain
	target_city["food"] = maxi(0, int(target_city.get("food", 0))) + food_gain
	target_city["production_bank"] = maxi(0, int(target_city.get("production_bank", 0))) + production_gain
	cities[best_city_index] = target_city
	if best_city_index == active_city_id:
		_load_active_city()
	return "Награда в %s: +%d золота, +%d еды, +%d производства." % [str(target_city.get("name", "город")), gold_gain, food_gain, production_gain]


func _apply_neutral_location_special_reward(location: Dictionary) -> String:
	var type_id := str(location.get("type", ""))
	var location_cell := WorldGeneratorScript.array_to_cell(location.get("cell", []))
	match type_id:
		"ancient_ruins":
			_reveal_fog_area(location_cell, 5)
			return "Старые карты раскрыли окрестности руин."
		"monster_lair":
			for unit in player_units:
				unit["experience"] = clampi(int(unit.get("experience", 0)) + 12, 0, 999999)
			return "Войска получили по 12 опыта за победу над чудовищами."
		"abandoned_mine":
			return "Шахта работает: ближайший город получает +2 производства каждый ход."
		"forgotten_shrine":
			player_hero["health"] = get_hero_max_health(player_hero)
			player_hero["wounded_turns"] = 0
			return "Святилище полностью восстановило здоровье правителя."
		"mercenary_camp":
			if player_units.size() < 24:
				player_units.append({
					"role": UNIT_CATALOG_SCRIPT.ROLE_MELEE,
					"health": UNIT_CATALOG_SCRIPT.get_max_health(UNIT_CATALOG_SCRIPT.ROLE_MELEE),
					"experience": 0,
				})
				return "Один мечник-наёмник присоединился к армии."
			city_gold += 25
			_save_active_city()
			return "Армия заполнена: за снаряжение лагеря получено 25 золота."
	return ""


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

	var player_progression := _summarize_unit_progression(player_survivors)
	var enemy_progression := _summarize_unit_progression(enemy_survivors)
	player_units = _read_unit_records(player_survivors)
	enemy_units = _read_unit_records(enemy_survivors)
	var defeated_kingdom_name := "Вражеское королевство"
	var location_index := -1
	var location_for_special_reward: Dictionary = {}
	if battle_target_type == "location":
		for index in range(neutral_locations.size()):
			if str(neutral_locations[index].get("id", "")) == battle_location_id:
				location_index = index
				break
		if location_index >= 0:
			var location: Dictionary = neutral_locations[location_index]
			defeated_kingdom_name = WorldLocationCatalogScript.get_display_name(str(location.get("type", "ancient_ruins")))
			location["guards"] = _copy_unit_records(enemy_units)
			if enemy_commander_health >= 0.0:
				location["guardian_health"] = clampf(enemy_commander_health, 0.0, 210.0)
			if victory:
				location["cleared"] = true
				location["guards"] = []
				location["guardian_health"] = 0.0
				neutral_locations[location_index] = location
				location_for_special_reward = location.duplicate(true)
				last_world_event_text = _grant_neutral_location_reward(location_index)
			else:
				neutral_locations[location_index] = location
	if battle_kingdom_id >= 0 and battle_kingdom_id < kingdoms.size():
		var defeated_kingdom: Dictionary = kingdoms[battle_kingdom_id]
		defeated_kingdom_name = str(defeated_kingdom.get("name", defeated_kingdom_name))
		defeated_kingdom["army"] = _copy_unit_records(enemy_units)
		defeated_kingdom["army_cell"] = WorldGeneratorScript.cell_to_array(battle_enemy_cell)
		if enemy_commander_health >= 0.0:
			var kingdom_hero: Dictionary = defeated_kingdom.get("hero", {})
			kingdom_hero["health"] = clampf(enemy_commander_health, 0.0, 210.0)
			if enemy_commander_health <= 0.0:
				kingdom_hero["wounded_turns"] = 2
			defeated_kingdom["hero"] = kingdom_hero
		defeated_kingdom["last_action"] = "Армия потерпела поражение" if victory else "Армия удержала позиции"
		kingdoms[battle_kingdom_id] = defeated_kingdom
		DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, battle_kingdom_id, -6 if victory else -2, turn_number)
	last_battle_result = stats.duplicate(true)
	last_battle_result["kingdom_id"] = battle_kingdom_id if battle_target_type == "kingdom" else -1
	last_battle_result["kingdom_name"] = defeated_kingdom_name
	last_battle_result["target_type"] = battle_target_type
	if battle_target_type == "location":
		last_battle_result["location_id"] = battle_location_id
		last_battle_result["location_reward"] = last_world_event_text if victory else ""
	last_battle_result["victory"] = victory
	last_battle_result["player_survivors"] = player_units.size()
	last_battle_result["enemy_survivors"] = enemy_units.size()
	last_battle_result["player_unit_xp_awarded"] = int(player_progression.get("xp_awarded", 0))
	last_battle_result["player_unit_promotions"] = int(player_progression.get("promotions", 0))
	last_battle_result["enemy_unit_xp_awarded"] = int(enemy_progression.get("xp_awarded", 0))
	last_battle_result["enemy_unit_promotions"] = int(enemy_progression.get("promotions", 0))
	if player_commander_health >= 0.0:
		player_hero["health"] = clampf(player_commander_health, 0.0, get_hero_max_health(player_hero))
		if player_commander_health <= 0.0:
			player_hero["wounded_turns"] = 2
	if enemy_commander_health >= 0.0:
		enemy_hero["health"] = clampf(enemy_commander_health, 0.0, get_hero_max_health(enemy_hero))
		if enemy_commander_health <= 0.0:
			enemy_hero["wounded_turns"] = 2
	if victory and not location_for_special_reward.is_empty():
		var special_reward_text := _apply_neutral_location_special_reward(location_for_special_reward)
		if not special_reward_text.is_empty():
			last_world_event_text += " " + special_reward_text
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
		player_cell = battle_enemy_cell
	else:
		player_cell = battle_origin_cell

	campaign_lost = player_units.is_empty()
	battle_in_progress = false
	battle_kingdom_id = -1
	battle_target_type = "kingdom"
	battle_location_id = ""
	player_moves_left = 0
	_sync_primary_kingdom()
	save_campaign()


func _copy_unit_records(source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in source:
		result.append(record.duplicate(true))
	return result


func _make_city_record(id: int, city_display_name: String, cell: Vector2i, population: int, food: int, gold: int, production: int, buildings: Array, queue: Array, specialization: String = "", building_levels: Dictionary = {}, province_improvements: Array = []) -> Dictionary:
	return {
		"id": id, "name": city_display_name, "cell": [cell.x, cell.y], "population": population,
		"food": food, "gold": gold, "production_bank": production,
		"buildings": buildings.duplicate(), "build_queue": queue.duplicate(true),
		"specialization": specialization,
		"building_levels": CityDevelopmentCatalogScript.normalize_building_levels(buildings, building_levels),
		"province_improvements": CityDevelopmentCatalogScript.normalize_province_improvements(province_improvements),
		"last_event": "",
	}

func _save_active_city() -> void:
	if cities.is_empty() or active_city_id < 0 or active_city_id >= cities.size():
		return
	cities[active_city_id] = _make_city_record(active_city_id, city_name, city_cell, city_population, city_food, city_gold, city_production_bank, city_buildings, city_build_queue, city_specialization, city_building_levels, city_province_improvements)
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
	city_specialization = str(c.get("specialization", "")) if CityDevelopmentCatalogScript.is_valid_specialization(str(c.get("specialization", ""))) else ""
	city_building_levels = CityDevelopmentCatalogScript.normalize_building_levels(city_buildings, c.get("building_levels", {}))
	city_province_improvements = CityDevelopmentCatalogScript.normalize_province_improvements(c.get("province_improvements", []))
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
		var d: int = WorldGeneratorScript.hex_distance(cell, c)
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
	if not settler_active or not WorldGeneratorScript.is_inside_world(cell) or WorldGeneratorScript.terrain_at(cell, world_seed, world_generation_version) == "water":
		return false
	if get_city_index_at(cell) >= 0 or cities.size() >= 5 or cell == player_cell or cell == enemy_cell:
		return false
	if WorldLocationCatalogScript.has_location_at(neutral_locations, cell):
		return false
	for kingdom in kingdoms:
		for ai_city in kingdom.get("cities", []):
			if WorldGeneratorScript.array_to_cell(ai_city.get("cell", [])) == cell:
				return false
		if WorldGeneratorScript.array_to_cell(kingdom.get("army_cell", [])) == cell:
			return false
	for c in cities:
		var xy: Array = c.get("cell", [])
		if xy.size() < 2:
			continue
		var other := Vector2i(int(xy[0]), int(xy[1]))
		var d: int = WorldGeneratorScript.hex_distance(cell, other)
		if d < 3:
			return false
	for kingdom in kingdoms:
		for ai_city in kingdom.get("cities", []):
			var other_cell := WorldGeneratorScript.array_to_cell(ai_city.get("cell", []))
			if WorldGeneratorScript.hex_distance(cell, other_cell) < 3:
				return false
	return true

func found_city(cell: Vector2i) -> bool:
	if not can_found_city(cell):
		return false
	_save_active_city()
	var new_id := cities.size()
	var names := ["Сосновый Дол", "Серебряный Ручей", "Солнечный Холм", "Тихая Гавань"]
	cities.append(_make_city_record(new_id, names[(new_id - 1) % names.size()], cell, 2, 0, 35, 0, [], [], "", {}, []))
	settler_active = false
	settler_moves_left = 1
	active_city_id = new_id
	_load_active_city()
	city_last_event = "Основан новый город: " + city_name
	save_campaign()
	return true

func _charge_army_upkeep() -> void:
	var remaining := get_army_upkeep_per_turn()
	army_upkeep_last_due = remaining
	army_upkeep_last_paid = 0
	for city_index in range(cities.size()):
		if remaining <= 0:
			break
		var city: Dictionary = cities[city_index]
		var available := maxi(0, int(city.get("gold", 0)))
		var payment := mini(available, remaining)
		city["gold"] = available - payment
		army_upkeep_last_paid += payment
		remaining -= payment
		cities[city_index] = city


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


func get_city_level() -> int:
	return CityDevelopmentCatalogScript.get_city_level(city_population)


func get_city_level_name() -> String:
	return str(CityDevelopmentCatalogScript.CITY_LEVELS[get_city_level()].get("name", "Поселение"))


func can_choose_city_specialization(specialization_id: String) -> bool:
	return not campaign_lost and city_specialization.is_empty() and get_city_level() >= 2 and CityDevelopmentCatalogScript.is_valid_specialization(specialization_id)


func choose_city_specialization(specialization_id: String) -> bool:
	if not can_choose_city_specialization(specialization_id):
		return false
	city_specialization = specialization_id
	var data: Dictionary = CityDevelopmentCatalogScript.SPECIALIZATIONS[specialization_id]
	city_last_event = "Город специализируется: %s." % str(data.get("name", specialization_id))
	save_campaign()
	return true


func get_city_building_level(building_id: String) -> int:
	if not city_has_building(building_id):
		return 0
	return clampi(int(city_building_levels.get(building_id, 1)), 1, 3)


func get_next_city_building_upgrade_data(building_id: String) -> Dictionary:
	var current_level := get_city_building_level(building_id)
	if current_level <= 0:
		return {}
	return CityDevelopmentCatalogScript.get_building_upgrade_data(building_id, current_level + 1)


func city_building_upgrade_is_queued(building_id: String) -> bool:
	for order in city_build_queue:
		if str(order.get("kind", "")) == "building_upgrade" and str(order.get("id", "")) == building_id:
			return true
	return false


func can_queue_city_building_upgrade(building_id: String) -> bool:
	if campaign_lost or battle_in_progress or city_building_upgrade_is_queued(building_id):
		return false
	var target_level := get_city_building_level(building_id) + 1
	var data := CityDevelopmentCatalogScript.get_building_upgrade_data(building_id, target_level)
	if data.is_empty() or get_city_level() < target_level:
		return false
	return city_gold >= int(data.get("gold_cost", 0))


func queue_city_building_upgrade(building_id: String) -> bool:
	if not can_queue_city_building_upgrade(building_id):
		return false
	var target_level := get_city_building_level(building_id) + 1
	var data := CityDevelopmentCatalogScript.get_building_upgrade_data(building_id, target_level)
	city_gold -= int(data.get("gold_cost", 0))
	city_build_queue.append({
		"kind": "building_upgrade", "id": building_id,
		"name": "%s · уровень %d" % [str(data.get("building_name", "Здание")), target_level],
		"target_level": target_level,
		"production_cost": int(data.get("production_cost", 1)),
	})
	city_last_event = "Улучшение здания добавлено в очередь."
	save_campaign()
	return true


func get_city_province_slots() -> int:
	var base_slots := CityDevelopmentCatalogScript.get_province_slots(get_city_level())
	var effects := FactionCatalogScript.get_effects(player_faction)
	return mini(6, base_slots + int(effects.get("province_slot_bonus", 0)))


func get_city_available_province_slots() -> int:
	var queued := 0
	for order in city_build_queue:
		if str(order.get("kind", "")) == "province_improvement":
			queued += 1
	return maxi(0, get_city_province_slots() - city_province_improvements.size() - queued)


func get_next_province_cell(improvement_id: String) -> Vector2i:
	var data := CityDevelopmentCatalogScript.get_improvement_data(improvement_id)
	if data.is_empty():
		return Vector2i(9999, 9999)
	var used: Dictionary = {}
	for improvement in city_province_improvements:
		var cell: Vector2i = WorldGeneratorScript.array_to_cell(improvement.get("cell", []))
		used["%d:%d" % [cell.x, cell.y]] = true
	for order in city_build_queue:
		if str(order.get("kind", "")) == "province_improvement":
			var cell: Vector2i = WorldGeneratorScript.array_to_cell(order.get("cell", []))
			used["%d:%d" % [cell.x, cell.y]] = true
	for offset in WorldGeneratorScript.neighbors():
		var candidate := city_cell + offset
		var key := "%d:%d" % [candidate.x, candidate.y]
		if used.has(key) or not WorldGeneratorScript.is_inside_world(candidate):
			continue
		if get_city_owner_at(candidate) != active_city_id:
			continue
		var terrain := get_world_terrain(candidate)
		if (data.get("terrain", []) as Array).has(terrain):
			return candidate
	return Vector2i(9999, 9999)


func can_queue_province_improvement(improvement_id: String) -> bool:
	if campaign_lost or battle_in_progress or get_city_available_province_slots() <= 0:
		return false
	var data := CityDevelopmentCatalogScript.get_improvement_data(improvement_id)
	if data.is_empty() or city_gold < int(data.get("gold_cost", 0)):
		return false
	return get_next_province_cell(improvement_id) != Vector2i(9999, 9999)


func queue_province_improvement(improvement_id: String) -> bool:
	if not can_queue_province_improvement(improvement_id):
		return false
	var data := CityDevelopmentCatalogScript.get_improvement_data(improvement_id)
	var cell := get_next_province_cell(improvement_id)
	city_gold -= int(data.get("gold_cost", 0))
	city_build_queue.append({
		"kind": "province_improvement", "id": improvement_id,
		"name": str(data.get("name", "Улучшение провинции")),
		"cell": [cell.x, cell.y],
		"production_cost": int(data.get("production_cost", 1)),
	})
	city_last_event = "%s строится в провинции." % str(data.get("name", "Улучшение"))
	save_campaign()
	return true


func get_army_upkeep_per_turn() -> int:
	var total_upkeep := 0.0
	for unit in player_units:
		var role_id := str(unit.get("role", ROLE_MELEE))
		var unit_data := UNIT_CATALOG_SCRIPT.get_data(role_id)
		var base_upkeep := float(unit_data.get("upkeep", 0.0))
		total_upkeep += base_upkeep * FactionCatalogScript.get_upkeep_multiplier(role_id, player_faction)
	return ceili(total_upkeep)


func get_army_upkeep_summary() -> String:
	var due := get_army_upkeep_per_turn()
	if army_upkeep_last_due <= 0:
		return "Содержание армии: −%d зол./ход" % due
	return "Содержание армии: −%d зол./ход · оплачено %d/%d" % [due, army_upkeep_last_paid, army_upkeep_last_due]


func get_city_income() -> Dictionary:
	var base_income := CityDevelopmentCatalogScript.get_city_income(
		city_buildings, city_building_levels, city_province_improvements, city_specialization
	)
	return FactionCatalogScript.apply_income_modifiers(base_income, city_buildings, player_faction)


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
	var data := UNIT_CATALOG_SCRIPT.get_data(role_name)
	if data.is_empty():
		return data
	var unlock_building := str(data.get("unlock_building", "barracks"))
	var multiplier := CityDevelopmentCatalogScript.get_recruit_gold_multiplier(city_specialization, unlock_building, city_building_levels)
	multiplier *= FactionCatalogScript.get_recruit_multiplier(role_name, player_faction)
	data["gold_cost"] = maxi(1, roundi(float(data.get("gold_cost", 0)) * multiplier))
	return data


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


func get_army_upgrade_rank(role_id: String) -> int:
	return clampi(int(army_upgrades.get(role_id, 0)), 0, ArmyUpgradeCatalogScript.MAX_RANK)


func get_next_army_upgrade_data(role_id: String) -> Dictionary:
	return ArmyUpgradeCatalogScript.get_rank_data(role_id, get_army_upgrade_rank(role_id) + 1)


func can_purchase_army_upgrade(role_id: String) -> bool:
	if campaign_lost or battle_in_progress:
		return false
	var upgrade_data := get_next_army_upgrade_data(role_id)
	if upgrade_data.is_empty():
		return false
	if not city_has_building(str(upgrade_data.get("building_id", "barracks"))):
		return false
	return city_gold >= int(upgrade_data.get("gold_cost", 0))


func purchase_army_upgrade(role_id: String) -> bool:
	if not can_purchase_army_upgrade(role_id):
		return false
	var upgrade_data := get_next_army_upgrade_data(role_id)
	var next_rank := get_army_upgrade_rank(role_id) + 1
	city_gold -= int(upgrade_data.get("gold_cost", 0))
	army_upgrades[role_id] = next_rank
	city_last_event = "%s: %s (ранг %d/%d)." % [
		str(upgrade_data.get("role_name", "Войска")),
		str(upgrade_data.get("name", "Улучшение")),
		next_rank,
		ArmyUpgradeCatalogScript.MAX_RANK,
	]
	save_campaign()
	return true


func get_army_veterancy_summary() -> String:
	var counts := [0, 0, 0, 0]
	for unit_record in player_units:
		var rank := UNIT_CATALOG_SCRIPT.get_veterancy_rank(int(unit_record.get("experience", 0)))
		counts[clampi(rank, 0, 3)] += 1
	return "Новобранцы %d · обученные %d · ветераны %d · элита %d" % [counts[0], counts[1], counts[2], counts[3]]


func _summarize_unit_progression(records: Array[Dictionary]) -> Dictionary:
	var xp_awarded := 0
	var promotions := 0
	for record in records:
		xp_awarded += maxi(0, int(record.get("battle_xp_gained", 0)))
		var before_rank := clampi(int(record.get("previous_veterancy_rank", 0)), 0, 3)
		var after_rank := UNIT_CATALOG_SCRIPT.get_veterancy_rank(int(record.get("experience", 0)))
		if after_rank > before_rank:
			promotions += 1
	return {"xp_awarded": xp_awarded, "promotions": promotions}


func _read_army_upgrades(value: Variant) -> Dictionary:
	var result := {"melee": 0, "ranged": 0, "spear": 0, "cavalry": 0}
	if not value is Dictionary:
		return result
	for role_id in ArmyUpgradeCatalogScript.role_ids():
		result[role_id] = clampi(int(value.get(role_id, 0)), 0, ArmyUpgradeCatalogScript.MAX_RANK)
	return result


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
	_apply_neutral_mine_income()
	_charge_army_upkeep()
	active_city_id = previous_city_id
	_load_active_city()
	var player_city_cells: Array[Vector2i] = []
	for city_record in cities:
		player_city_cells.append(WorldGeneratorScript.array_to_cell(city_record.get("cell", [])))
	var neutral_location_cells: Array[Vector2i] = []
	for location in neutral_locations:
		neutral_location_cells.append(WorldGeneratorScript.array_to_cell(location.get("cell", [])))
	var diplomacy_result := DiplomacyCatalogScript.process_turn(
		diplomacy_relations,
		kingdoms,
		turn_number,
		world_seed,
		_get_army_power(player_units),
		pending_diplomacy_offers,
		_get_player_diplomacy_sources()
	)
	last_diplomacy_events.clear()
	for event_text in diplomacy_result.get("events", []):
		last_diplomacy_events.append(str(event_text))
	last_kingdom_events = KingdomAIScript.process_turns(
		kingdoms,
		turn_number,
		player_cell,
		player_city_cells,
		world_seed,
		world_generation_version,
		neutral_location_cells,
		diplomacy_relations
	)
	_apply_diplomacy_economy()
	_sync_primary_kingdom()
	refresh_fog_of_war()
	_queue_world_event_if_due()


func _get_player_diplomacy_sources() -> Array[Vector2i]:
	var sources: Array[Vector2i] = [player_cell]
	for city_record in cities:
		var city_cell_value := WorldGeneratorScript.array_to_cell(city_record.get("cell", []))
		if not sources.has(city_cell_value):
			sources.append(city_cell_value)
	return sources


func get_diplomacy_record(kingdom_id: int) -> Dictionary:
	if kingdom_id < 0 or kingdom_id >= kingdoms.size():
		return {}
	return DiplomacyCatalogScript.get_record(diplomacy_relations, DiplomacyCatalogScript.PLAYER_ID, kingdom_id)


func get_diplomacy_action_preview(kingdom_id: int, action_id: String) -> Dictionary:
	if kingdom_id < 0 or kingdom_id >= kingdoms.size() or not bool(kingdoms[kingdom_id].get("alive", true)):
		return {"available": false, "reason": "Держава больше не существует.", "chance": 0}
	var record := get_diplomacy_record(kingdom_id)
	var treaty := str(record.get("treaty", "peace"))
	var relation := int(record.get("relation", 0))
	var player_power := _get_army_power(player_units)
	var target_power := _get_army_power(kingdoms[kingdom_id].get("army", []))
	var available := true
	var reason := ""
	match action_id:
		"declare_war":
			available = treaty != "war" and turn_number >= int(record.get("truce_until", 0)) and treaty != "vassal"
			if treaty == "vassal":
				reason = "Вассал защищён договором. Сначала договор должен закончиться."
			elif turn_number < int(record.get("truce_until", 0)):
				reason = "Перемирие действует ещё %d ход(а)." % (int(record.get("truce_until", 0)) - turn_number)
			else:
				reason = "Начнётся война; отношение ухудшится на 35 пунктов."
		"offer_trade":
			available = treaty == "peace" and int(record.get("truce_until", 0)) <= turn_number
			reason = "Договор на 6 ходов: +2 золота каждый ход обеим сторонам." if available else "Торговля возможна только в мирное время."
		"offer_alliance":
			available = treaty == "trade" and relation >= 35
			reason = "Союз на 8 ходов и общий торговый доход." if available else "Нужен торговый договор и отношение не ниже 35."
		"offer_peace":
			available = treaty == "war"
			reason = "При успехе война закончится и начнётся перемирие на 4 хода." if available else "Сейчас между державами нет войны."
		"demand_tribute":
			available = treaty == "peace" and player_power >= target_power * 1.15
			reason = "Дань: до 3 золота за ход в течение 5 ходов." if available else "Нужно мирное время и военное превосходство хотя бы 15%."
		"demand_vassalage":
			available = treaty != "vassal" and player_power >= target_power * 1.65 and (treaty == "war" or relation <= 25 or int(record.get("war_exhaustion", 0)) >= 50)
			reason = "Вассал платит до 3 золота за ход в течение 10 ходов." if available else "Нужно превосходство 65% и ослабленный или недоверчивый соперник."
		_:
			available = false
			reason = "Неизвестное дипломатическое действие."
	var chance := 100
	if action_id in ["offer_trade", "offer_alliance", "offer_peace", "demand_tribute", "demand_vassalage"]:
		chance = DiplomacyCatalogScript.acceptance_chance(action_id, record, kingdom_id, player_power, target_power)
	return {"available": available, "reason": reason, "chance": chance, "relation": relation, "treaty": treaty}


func perform_diplomacy_action(action_id: String, kingdom_id: int) -> Dictionary:
	if campaign_lost or battle_in_progress or faction_setup_pending:
		return {"ok": false, "message": "Дипломатия сейчас недоступна."}
	var preview := get_diplomacy_action_preview(kingdom_id, action_id)
	if not bool(preview.get("available", false)):
		return {"ok": false, "message": str(preview.get("reason", "Действие недоступно."))}
	var kingdom_name := str(kingdoms[kingdom_id].get("name", "Королевство"))
	if action_id == "declare_war":
		DiplomacyCatalogScript.set_treaty(diplomacy_relations, -1, kingdom_id, "war", turn_number)
		var declared_record := DiplomacyCatalogScript.get_record(diplomacy_relations, -1, kingdom_id)
		declared_record["war_reason"] = "player_declaration"
		DiplomacyCatalogScript.set_record(diplomacy_relations, -1, kingdom_id, declared_record)
		DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, -35, turn_number)
		var message := "Ты объявил войну державе «%s»." % kingdom_name
		_record_diplomacy_event(message)
		save_campaign()
		return {"ok": true, "accepted": true, "message": message, "chance": 100}
	var chance := int(preview.get("chance", 0))
	var accepted := DiplomacyCatalogScript.deterministic_acceptance(action_id, kingdom_id, turn_number, world_seed, chance)
	var message := ""
	if accepted:
		match action_id:
			"offer_trade":
				DiplomacyCatalogScript.set_treaty(diplomacy_relations, -1, kingdom_id, "trade", turn_number, DiplomacyCatalogScript.TRADE_DURATION)
				DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, 8, turn_number)
				message = "%s приняло торговый договор на 6 ходов." % kingdom_name
			"offer_alliance":
				DiplomacyCatalogScript.set_treaty(diplomacy_relations, -1, kingdom_id, "alliance", turn_number, DiplomacyCatalogScript.ALLIANCE_DURATION)
				DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, 12, turn_number)
				message = "%s заключило с тобой союз на 8 ходов." % kingdom_name
			"offer_peace":
				DiplomacyCatalogScript.set_treaty(diplomacy_relations, -1, kingdom_id, "peace", turn_number, 0)
				var peace_record := DiplomacyCatalogScript.get_record(diplomacy_relations, -1, kingdom_id)
				peace_record["truce_until"] = turn_number + DiplomacyCatalogScript.TRUCE_DURATION
				peace_record["war_reason"] = "resolved"
				DiplomacyCatalogScript.set_record(diplomacy_relations, -1, kingdom_id, peace_record)
				DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, 15, turn_number)
				message = "С %s заключён мир. Перемирие действует 4 хода." % kingdom_name
			"demand_tribute":
				DiplomacyCatalogScript.set_treaty(diplomacy_relations, -1, kingdom_id, "tribute", turn_number, DiplomacyCatalogScript.TRIBUTE_DURATION, -1)
				DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, -10, turn_number)
				message = "%s согласилось платить дань до 3 золота за ход в течение 5 ходов." % kingdom_name
			"demand_vassalage":
				DiplomacyCatalogScript.set_treaty(diplomacy_relations, -1, kingdom_id, "vassal", turn_number, DiplomacyCatalogScript.VASSAL_DURATION, -1)
				DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, -8, turn_number)
				message = "%s признало твоё верховенство на 10 ходов." % kingdom_name
	else:
		DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, -3, turn_number)
		message = "%s отклонило предложение. Шанс принятия был %d%%." % [kingdom_name, chance]
	_record_diplomacy_event(message)
	save_campaign()
	return {"ok": true, "accepted": accepted, "message": message, "chance": chance}


func respond_to_diplomacy_offer(offer_id: String, accept: bool) -> Dictionary:
	for offer_index in range(pending_diplomacy_offers.size()):
		var offer: Dictionary = pending_diplomacy_offers[offer_index]
		if str(offer.get("offer_id", "")) != offer_id:
			continue
		var kingdom_id := int(offer.get("kingdom_id", -1))
		var action_id := str(offer.get("action", ""))
		if kingdom_id < 0 or kingdom_id >= kingdoms.size():
			pending_diplomacy_offers.remove_at(offer_index)
			save_campaign()
			return {"ok": false, "message": "Предложение больше не действительно."}
		if not bool(kingdoms[kingdom_id].get("alive", true)):
			pending_diplomacy_offers.remove_at(offer_index)
			save_campaign()
			return {"ok": false, "message": "Держава больше не существует. Предложение отменено."}
		var current_record := get_diplomacy_record(kingdom_id)
		var current_treaty := str(current_record.get("treaty", "peace"))
		var offer_still_valid := (action_id == "offer_trade" and current_treaty == "peace" and int(current_record.get("truce_until", 0)) <= turn_number) or (action_id == "offer_alliance" and current_treaty == "trade") or (action_id == "offer_peace" and current_treaty == "war")
		if accept and not offer_still_valid:
			pending_diplomacy_offers.remove_at(offer_index)
			save_campaign()
			return {"ok": false, "message": "Условия изменились. Предложение больше недействительно."}
		var kingdom_name := str(kingdoms[kingdom_id].get("name", "Королевство"))
		var message := ""
		if accept:
			match action_id:
				"offer_trade":
					DiplomacyCatalogScript.set_treaty(diplomacy_relations, -1, kingdom_id, "trade", turn_number, DiplomacyCatalogScript.TRADE_DURATION)
					DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, 8, turn_number)
					message = "Ты принял торговое предложение державы «%s»." % kingdom_name
				"offer_alliance":
					DiplomacyCatalogScript.set_treaty(diplomacy_relations, -1, kingdom_id, "alliance", turn_number, DiplomacyCatalogScript.ALLIANCE_DURATION)
					DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, 12, turn_number)
					message = "Ты заключил союз с державой «%s»." % kingdom_name
				"offer_peace":
					DiplomacyCatalogScript.set_treaty(diplomacy_relations, -1, kingdom_id, "peace", turn_number, 0)
					var peace_record := DiplomacyCatalogScript.get_record(diplomacy_relations, -1, kingdom_id)
					peace_record["truce_until"] = turn_number + DiplomacyCatalogScript.TRUCE_DURATION
					peace_record["war_reason"] = "resolved"
					DiplomacyCatalogScript.set_record(diplomacy_relations, -1, kingdom_id, peace_record)
					DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, 15, turn_number)
					message = "Ты заключил мир с державой «%s»." % kingdom_name
		else:
			DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, -2, turn_number)
			message = "Ты отклонил предложение державы «%s»." % kingdom_name
		pending_diplomacy_offers.remove_at(offer_index)
		_record_diplomacy_event(message)
		save_campaign()
		return {"ok": true, "message": message}
	return {"ok": false, "message": "Предложение уже истекло или было обработано."}


func _record_diplomacy_event(message: String) -> void:
	last_diplomacy_events.append(message)
	while last_diplomacy_events.size() > 8:
		last_diplomacy_events.pop_front()


func _get_army_power(army_value: Variant) -> float:
	if not army_value is Array:
		return 1.0
	var total := 0.0
	for unit_value in army_value:
		if not unit_value is Dictionary:
			continue
		var role_id := str(unit_value.get("role", ROLE_MELEE))
		var unit_data := UNIT_CATALOG_SCRIPT.get_data(role_id)
		var max_health := maxf(1.0, float(unit_data.get("max_health", 100.0)))
		var current_health := clampf(float(unit_value.get("health", max_health)), 0.0, max_health)
		var veteran_rank := UNIT_CATALOG_SCRIPT.get_veterancy_rank(int(unit_value.get("experience", 0)))
		var unit_power := float(unit_data.get("damage", 10.0)) * 1.8 + max_health * 0.12 + float(unit_data.get("armor", 0.0)) * 3.0 + float(veteran_rank) * 4.0
		total += unit_power * (current_health / max_health)
	return maxf(1.0, total)


func _capital_gold_change(city_records: Array, delta: int) -> int:
	if city_records.is_empty() or delta == 0:
		return 0
	var capital: Dictionary = city_records[0]
	var before := maxi(0, int(capital.get("gold", 0)))
	var after := maxi(0, before + delta)
	capital["gold"] = after
	city_records[0] = capital
	return after - before


func _apply_diplomacy_economy() -> void:
	if cities.is_empty():
		return
	_save_active_city()
	for kingdom_id in range(kingdoms.size()):
		if not bool(kingdoms[kingdom_id].get("alive", true)):
			continue
		var player_relation_record := DiplomacyCatalogScript.get_record(diplomacy_relations, -1, kingdom_id)
		if not DiplomacyCatalogScript.treaty_is_active(player_relation_record, turn_number):
			continue
		var player_treaty := str(player_relation_record.get("treaty", "peace"))
		var ai_cities: Array = kingdoms[kingdom_id].get("cities", [])
		if player_treaty == "trade" or player_treaty == "alliance":
			_capital_gold_change(cities, 2)
			_capital_gold_change(ai_cities, 2)
		elif player_treaty == "tribute" or player_treaty == "vassal":
			if int(player_relation_record.get("overlord_id", -99)) == -1:
				var paid := -_capital_gold_change(ai_cities, -3)
				_capital_gold_change(cities, paid)
		kingdoms[kingdom_id]["cities"] = ai_cities
	for first_id in range(kingdoms.size()):
		if not bool(kingdoms[first_id].get("alive", true)):
			continue
		for second_id in range(first_id + 1, kingdoms.size()):
			if not bool(kingdoms[second_id].get("alive", true)):
				continue
			var ai_relation_record := DiplomacyCatalogScript.get_record(diplomacy_relations, first_id, second_id)
			if not DiplomacyCatalogScript.treaty_is_active(ai_relation_record, turn_number):
				continue
			var ai_treaty := str(ai_relation_record.get("treaty", "peace"))
			var first_cities: Array = kingdoms[first_id].get("cities", [])
			var second_cities: Array = kingdoms[second_id].get("cities", [])
			if ai_treaty == "trade" or ai_treaty == "alliance":
				_capital_gold_change(first_cities, 2)
				_capital_gold_change(second_cities, 2)
			elif ai_treaty == "tribute" or ai_treaty == "vassal":
				var overlord_id := int(ai_relation_record.get("overlord_id", -99))
				if overlord_id == first_id:
					var second_paid := -_capital_gold_change(second_cities, -3)
					_capital_gold_change(first_cities, second_paid)
				elif overlord_id == second_id:
					var first_paid := -_capital_gold_change(first_cities, -3)
					_capital_gold_change(second_cities, first_paid)
			kingdoms[first_id]["cities"] = first_cities
			kingdoms[second_id]["cities"] = second_cities
	_load_active_city()


func _apply_neutral_mine_income() -> void:
	if cities.is_empty():
		return
	for location in neutral_locations:
		if not bool(location.get("cleared", false)) or str(location.get("type", "")) != "abandoned_mine":
			continue
		var location_cell := WorldGeneratorScript.array_to_cell(location.get("cell", []))
		var city_index := _find_nearest_player_city_index(location_cell)
		if city_index < 0:
			continue
		var target_city: Dictionary = cities[city_index]
		target_city["production_bank"] = maxi(0, int(target_city.get("production_bank", 0))) + 2
		cities[city_index] = target_city


func _queue_world_event_if_due() -> void:
	if not pending_world_event.is_empty() or not WorldEventCatalogScript.is_event_turn(turn_number):
		return
	pending_world_event = WorldEventCatalogScript.get_event_for_turn(world_seed, turn_number)


func can_resolve_world_event(choice_id: String) -> bool:
	if pending_world_event.is_empty():
		return false
	var choice := WorldEventCatalogScript.get_choice(pending_world_event, choice_id)
	if choice.is_empty():
		return false
	var effect: Dictionary = choice.get("effect", {})
	if city_gold < int(effect.get("gold_cost", 0)) or city_food < int(effect.get("food_cost", 0)):
		return false
	if int(effect.get("population_gain", 0)) > 0 and city_population >= 20:
		return false
	return true


func resolve_world_event(choice_id: String) -> bool:
	if not can_resolve_world_event(choice_id):
		return false
	var choice := WorldEventCatalogScript.get_choice(pending_world_event, choice_id)
	var effect: Dictionary = choice.get("effect", {})
	city_gold = maxi(0, city_gold - int(effect.get("gold_cost", 0)) + int(effect.get("gold_gain", 0)))
	city_food = maxi(0, city_food - int(effect.get("food_cost", 0)) + int(effect.get("food_gain", 0)))
	city_production_bank = maxi(0, city_production_bank + int(effect.get("production_gain", 0)))
	city_population = clampi(city_population + int(effect.get("population_gain", 0)), 1, 20)
	var unit_xp_gain := maxi(0, int(effect.get("unit_xp_gain", 0)))
	if unit_xp_gain > 0:
		for unit in player_units:
			unit["experience"] = clampi(int(unit.get("experience", 0)) + unit_xp_gain, 0, 999999)
	var reveal_radius := clampi(int(effect.get("reveal_radius", 0)), 0, 8)
	var reveal_distance := clampi(int(effect.get("reveal_distance", 0)), 0, 24)
	if reveal_radius > 0:
		var reveal_origin := player_cell
		if reveal_distance > 0:
			reveal_origin = _find_scout_reveal_origin(reveal_distance, reveal_radius)
		_reveal_fog_area(reveal_origin, reveal_radius)
	last_world_event_text = str(choice.get("result", "Событие завершено."))
	pending_world_event.clear()
	world_events_resolved += 1
	_save_active_city()
	_sync_primary_kingdom()
	save_campaign()
	return true


func refresh_fog_of_war() -> void:
	visible_cells.clear()
	if not campaign_started:
		return
	if not player_units.is_empty():
		var faction_effects := FactionCatalogScript.get_effects(player_faction)
		var army_vision := clampi(ARMY_VISION_RADIUS + int(faction_effects.get("army_vision_bonus", 0)), ARMY_VISION_RADIUS, 12)
		_reveal_fog_area(player_cell, army_vision)
	else:
		_reveal_fog_area(city_cell, CITY_VISION_RADIUS)
	for city_record in cities:
		var cell := WorldGeneratorScript.array_to_cell(city_record.get("cell", []))
		_reveal_fog_area(cell, CITY_VISION_RADIUS)
	if settler_active:
		_reveal_fog_area(settler_cell, SETTLER_VISION_RADIUS)


func _find_scout_reveal_origin(distance: int, radius: int) -> Vector2i:
	var directions := WorldGeneratorScript.neighbors()
	if directions.is_empty():
		return player_cell
	var start_index := posmod(world_seed + turn_number, directions.size())
	var best_cell := player_cell
	var best_unexplored_count := -1
	for step in range(directions.size()):
		var direction_index := posmod(start_index + step, directions.size())
		var candidate := player_cell + directions[direction_index] * distance
		if not WorldGeneratorScript.is_inside_world(candidate):
			continue
		var unexplored_count := 0
		for q in range(-radius, radius + 1):
			for r in range(-radius, radius + 1):
				var offset := Vector2i(q, r)
				if WorldGeneratorScript.hex_distance(Vector2i.ZERO, offset) > radius:
					continue
				var sample := candidate + offset
				if WorldGeneratorScript.is_inside_world(sample) and not is_cell_explored(sample):
					unexplored_count += 1
		if unexplored_count > best_unexplored_count:
			best_unexplored_count = unexplored_count
			best_cell = candidate
	return best_cell


func _reveal_fog_area(origin: Vector2i, radius: int) -> void:
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var offset := Vector2i(q, r)
			if WorldGeneratorScript.hex_distance(Vector2i.ZERO, offset) > radius:
				continue
			var cell := origin + offset
			if not WorldGeneratorScript.is_inside_world(cell):
				continue
			var encoded := WorldGeneratorScript.encode_cell(cell)
			if encoded < 0:
				continue
			visible_cells[encoded] = true
			explored_cells[encoded] = true


func is_cell_visible(cell: Vector2i) -> bool:
	var encoded := WorldGeneratorScript.encode_cell(cell)
	return encoded >= 0 and visible_cells.has(encoded)


func is_cell_explored(cell: Vector2i) -> bool:
	var encoded := WorldGeneratorScript.encode_cell(cell)
	return encoded >= 0 and explored_cells.has(encoded)


func get_explored_cell_count() -> int:
	return explored_cells.size()


func _serialize_explored_cells() -> Array[int]:
	var result: Array[int] = []
	for value in explored_cells.keys():
		result.append(int(value))
	result.sort()
	return result


func _load_explored_cells(value: Variant) -> void:
	explored_cells.clear()
	visible_cells.clear()
	if value is Array:
		for raw_value in value:
			var encoded := int(raw_value)
			var cell := WorldGeneratorScript.decode_cell(encoded)
			if cell != Vector2i(9999, 9999):
				explored_cells[encoded] = true


func get_world_terrain(cell: Vector2i) -> String:
	return WorldGeneratorScript.terrain_at(cell, world_seed, world_generation_version)


func get_kingdom_index_at_army(cell: Vector2i) -> int:
	for index in range(kingdoms.size()):
		var kingdom: Dictionary = kingdoms[index]
		if not bool(kingdom.get("alive", true)) or kingdom.get("army", []).is_empty():
			continue
		if WorldGeneratorScript.array_to_cell(kingdom.get("army_cell", [])) == cell:
			return index
	return -1


func get_total_enemy_units() -> int:
	var total := 0
	for kingdom in kingdoms:
		total += kingdom.get("army", []).size()
	return total


func get_world_owner_at(cell: Vector2i) -> int:
	for city_record in cities:
		var player_city_hex: Vector2i = WorldGeneratorScript.array_to_cell(city_record.get("cell", []))
		if WorldGeneratorScript.hex_distance(cell, player_city_hex) <= 1:
			return -2
	for index in range(kingdoms.size()):
		var kingdom: Dictionary = kingdoms[index]
		for city_record in kingdom.get("cities", []):
			var kingdom_city_hex: Vector2i = WorldGeneratorScript.array_to_cell(city_record.get("cell", []))
			if WorldGeneratorScript.hex_distance(cell, kingdom_city_hex) <= 1:
				return index
	return -1


func _sync_primary_kingdom() -> void:
	if kingdoms.is_empty():
		enemy_present = false
		enemy_units.clear()
		return
	var primary: Dictionary = kingdoms[0]
	enemy_cell = WorldGeneratorScript.array_to_cell(primary.get("army_cell", [2, 0]))
	enemy_units = _read_unit_records(primary.get("army", []))
	enemy_present = not enemy_units.is_empty()
	var fallback := _make_hero_record(str(primary.get("ruler", "Варг")), "Правитель " + str(primary.get("name", "Королевства")))
	enemy_hero = _read_hero_record(primary.get("hero", fallback), fallback)


func _find_settler_spawn_cell(origin: Vector2i) -> Vector2i:
	# Find a nearby passable spawn anywhere in the expanded world.
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
		if not WorldGeneratorScript.is_inside_world(candidate) or WorldGeneratorScript.terrain_at(candidate, world_seed, world_generation_version) == "water" or get_city_index_at(candidate) >= 0:
			continue
		if WorldLocationCatalogScript.has_location_at(neutral_locations, candidate):
			continue
		if candidate == player_cell or candidate == enemy_cell:
			continue
		var occupied_by_kingdom := false
		for kingdom in kingdoms:
			if WorldGeneratorScript.array_to_cell(kingdom.get("army_cell", [])) == candidate:
				occupied_by_kingdom = true
			for ai_city in kingdom.get("cities", []):
				if WorldGeneratorScript.array_to_cell(ai_city.get("cell", [])) == candidate:
					occupied_by_kingdom = true
		if occupied_by_kingdom:
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
				city_building_levels[order_id] = 1
				city_last_event += "%s построена. " % order_name
		elif order_kind == "building_upgrade":
			var target_level := clampi(int(order.get("target_level", 1)), 2, 3)
			if city_has_building(order_id) and target_level == get_city_building_level(order_id) + 1 and get_city_level() >= target_level:
				city_building_levels[order_id] = target_level
				city_last_event += "%s улучшено до уровня %d. " % [order_name, target_level]
		elif order_kind == "province_improvement":
			var cell := WorldGeneratorScript.array_to_cell(order.get("cell", []))
			var data := CityDevelopmentCatalogScript.get_improvement_data(order_id)
			if not data.is_empty() and WorldGeneratorScript.hex_distance(cell, city_cell) == 1 and city_province_improvements.size() < get_city_province_slots():
				var valid_terrain: Array = data.get("terrain", [])
				if valid_terrain.has(get_world_terrain(cell)):
					city_province_improvements.append({"id": order_id, "cell": [cell.x, cell.y]})
					city_last_event += "%s завершено. " % order_name
		elif order_kind == "recruit":
			if UNIT_CATALOG_SCRIPT.is_valid_role(order_id) and player_units.size() < ARMY_CAPACITY:
				var max_health: float = UNIT_CATALOG_SCRIPT.get_max_health(order_id)
				player_units.append({"role": order_id, "health": max_health, "experience": 0})
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


func _remove_conflicting_neutral_locations() -> void:
	var occupied: Dictionary = {}
	occupied["%d:%d" % [player_cell.x, player_cell.y]] = true
	for city in cities:
		var city_cell_value := WorldGeneratorScript.array_to_cell(city.get("cell", []))
		occupied["%d:%d" % [city_cell_value.x, city_cell_value.y]] = true
	for kingdom in kingdoms:
		var army_cell_value := WorldGeneratorScript.array_to_cell(kingdom.get("army_cell", []))
		occupied["%d:%d" % [army_cell_value.x, army_cell_value.y]] = true
		for city in kingdom.get("cities", []):
			var city_cell_value := WorldGeneratorScript.array_to_cell(city.get("cell", []))
			occupied["%d:%d" % [city_cell_value.x, city_cell_value.y]] = true
	if settler_active:
		occupied["%d:%d" % [settler_cell.x, settler_cell.y]] = true
	var filtered: Array[Dictionary] = []
	for location in neutral_locations:
		var location_cell := WorldGeneratorScript.array_to_cell(location.get("cell", []))
		# Cleared sites are inert map history and may share the player's hex after victory.
		if occupied.has("%d:%d" % [location_cell.x, location_cell.y]) and not bool(location.get("cleared", false)):
			continue
		filtered.append(location)
	neutral_locations = filtered


func save_campaign() -> bool:
	# Do not overwrite the last safe strategic state during an unfinished tactical battle
	# or when a damaged save could not be preserved during startup.
	if battle_in_progress or _prevent_save_overwrite:
		return false
	_save_active_city()
	refresh_fog_of_war()
	var save_data := {
		"version": SAVE_VERSION,
		"world_seed": world_seed,
		"world_generation_version": world_generation_version,
		"explored_cells": _serialize_explored_cells(),
		"neutral_locations": neutral_locations,
		"pending_world_event": pending_world_event,
		"last_world_event_text": last_world_event_text,
		"world_events_resolved": world_events_resolved,
		"kingdoms": kingdoms,
		"diplomacy_relations": diplomacy_relations,
		"pending_diplomacy_offers": pending_diplomacy_offers,
		"campaign_lost": campaign_lost,
		"turn_number": turn_number,
		"player_moves_left": player_moves_left,
		"player_cell": [player_cell.x, player_cell.y],
		"enemy_cell": [enemy_cell.x, enemy_cell.y],
		"enemy_present": enemy_present,
		"player_units": player_units,
		"army_upgrades": army_upgrades,
		"army_upkeep_last_due": army_upkeep_last_due,
		"army_upkeep_last_paid": army_upkeep_last_paid,
		"enemy_units": enemy_units,
		"player_hero": player_hero,
		"player_faction": player_faction,
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
	var parser := JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {}
	var parsed: Variant = parser.data
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
			var primary_absolute := ProjectSettings.globalize_path(SAVE_PATH)
			if FileAccess.file_exists(SAVE_PATH):
				var remove_primary_error: Error = DirAccess.remove_absolute(primary_absolute)
				if remove_primary_error != OK:
					_prevent_save_overwrite = true
			if not _prevent_save_overwrite:
				var restore_error: Error = DirAccess.copy_absolute(
					ProjectSettings.globalize_path(SAVE_BACKUP_PATH),
					primary_absolute
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
	army_upkeep_last_due = maxi(0, int(data.get("army_upkeep_last_due", 0)))
	army_upkeep_last_paid = clampi(int(data.get("army_upkeep_last_paid", 0)), 0, army_upkeep_last_due)
	army_upgrades = _read_army_upgrades(data.get("army_upgrades", {}))
	var player_hero_fallback := _make_hero_record("Эдрик", "Правитель Каменного Брода")
	var enemy_hero_fallback := _make_hero_record("Варг", "Воевода Красного Отряда")
	player_hero = _read_hero_record(data.get("player_hero", player_hero_fallback), player_hero_fallback)
	player_faction = FactionCatalogScript.normalize_selection(data.get("player_faction", {}))
	faction_setup_pending = false
	enemy_hero = _read_hero_record(data.get("enemy_hero", enemy_hero_fallback), enemy_hero_fallback)
	enemy_present = bool(data.get("enemy_present", true)) and not enemy_units.is_empty()
	world_seed = int(data.get("world_seed", WorldGeneratorScript.DEFAULT_SEED))
	# Saves without this field were made with the original per-cell terrain algorithm.
	world_generation_version = clampi(
		int(data.get("world_generation_version", 1)),
		1,
		WorldGeneratorScript.WORLD_GENERATION_VERSION
	)
	neutral_locations = WorldLocationCatalogScript.normalize_locations(
		data.get("neutral_locations", []), world_seed, world_generation_version
	)
	pending_world_event = WorldEventCatalogScript.normalize_event(data.get("pending_world_event", {}))
	last_world_event_text = str(data.get("last_world_event_text", ""))
	world_events_resolved = maxi(0, int(data.get("world_events_resolved", 0)))
	var default_kingdoms := KingdomAIScript.create_initial_kingdoms(world_seed)
	kingdoms.clear()
	var saved_kingdoms: Variant = data.get("kingdoms", [])
	if saved_kingdoms is Array and saved_kingdoms.size() >= KINGDOM_COUNT:
		for index in range(KINGDOM_COUNT):
			var fallback: Dictionary = default_kingdoms[index]
			if saved_kingdoms[index] is Dictionary:
				kingdoms.append(KingdomAIScript.normalize_kingdom(saved_kingdoms[index], fallback))
			else:
				kingdoms.append(fallback.duplicate(true))
	else:
		# v0.9.x saves have no kingdom data. Preserve the existing enemy army
		# as realm zero and create the remaining realms around the current campaign.
		kingdoms = default_kingdoms
		var migrated_primary: Dictionary = kingdoms[0]
		migrated_primary["army_cell"] = WorldGeneratorScript.cell_to_array(enemy_cell)
		migrated_primary["army"] = _copy_unit_records(enemy_units) if enemy_present else []
		migrated_primary["hero"] = enemy_hero.duplicate(true)
		kingdoms[0] = migrated_primary
	diplomacy_relations = DiplomacyCatalogScript.normalize_relations(data.get("diplomacy_relations", {}), kingdoms.size(), world_seed)
	pending_diplomacy_offers.clear()
	var saved_diplomacy_offers: Variant = data.get("pending_diplomacy_offers", [])
	if saved_diplomacy_offers is Array:
		for offer_value in saved_diplomacy_offers:
			if not offer_value is Dictionary or pending_diplomacy_offers.size() >= DiplomacyCatalogScript.MAX_PENDING_OFFERS:
				continue
			var offer_kingdom_id := int(offer_value.get("kingdom_id", -1))
			var offer_action := str(offer_value.get("action", ""))
			if offer_kingdom_id < 0 or offer_kingdom_id >= kingdoms.size() or not ["offer_trade", "offer_alliance", "offer_peace"].has(offer_action):
				continue
			pending_diplomacy_offers.append(offer_value.duplicate(true))
	last_diplomacy_events.clear()
	battle_kingdom_id = -1
	battle_target_type = "kingdom"
	battle_location_id = ""
	last_kingdom_events.clear()
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
			# Keep this name distinct from the legacy capital's loaded_buildings local above.
			var city_buildings_data: Array = raw.get("buildings", []) if raw.get("buildings", []) is Array else []
			var record := _make_city_record(city_id, str(raw.get("name", "Поселение %d" % (city_id + 1))), Vector2i(int(xy[0]), int(xy[1])), clampi(int(raw.get("population", 2)), 1, 20), maxi(0, int(raw.get("food", 0))), maxi(0, int(raw.get("gold", 0))), maxi(0, int(raw.get("production_bank", 0))), city_buildings_data, _read_city_queue(raw.get("build_queue", [])), str(raw.get("specialization", "")), raw.get("building_levels", {}), raw.get("province_improvements", []))
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
	# Generated neutral points must not overlap locations already occupied in older campaigns.
	_remove_conflicting_neutral_locations()
	# Old saves predate the world map. Their player capital and army remain in place;
	# the new world and the eight additional realms are generated around them.
	if kingdoms.size() == KINGDOM_COUNT:
		_sync_primary_kingdom()
	_load_explored_cells(data.get("explored_cells", []))
	# Old campaigns have no exploration array; reveal the area around current
	# player sources while keeping all prior save fields and campaign data intact.
	refresh_fog_of_war()
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
		var valid_building_upgrade: bool = kind == "building_upgrade" and CityDevelopmentCatalogScript.BUILDING_UPGRADES.has(item_id) and int(item.get("target_level", 0)) in [2, 3]
		var province_cell_value: Variant = item.get("cell", [])
		var province_cell_array: Array = province_cell_value if province_cell_value is Array else []
		var valid_province: bool = kind == "province_improvement" and CityDevelopmentCatalogScript.PROVINCE_IMPROVEMENTS.has(item_id) and province_cell_value is Array and province_cell_array.size() >= 2
		if not valid_building and not valid_recruit and not valid_settler and not valid_building_upgrade and not valid_province:
			continue
		var record := {
			"kind": kind,
			"id": item_id,
			"name": str(item.get("name", "Заказ")),
			"production_cost": maxi(1, int(item.get("production_cost", 1))),
		}
		if valid_building_upgrade:
			record["target_level"] = clampi(int(item.get("target_level", 2)), 2, 3)
		if valid_province:
			record["cell"] = [int(province_cell_array[0]), int(province_cell_array[1])]
		result.append(record)
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
		var experience_value := clampi(int(item.get("experience", 0)), 0, 999999)
		if health_value > 0.0:
			result.append({"role": role_name, "health": health_value, "experience": experience_value})
	return result