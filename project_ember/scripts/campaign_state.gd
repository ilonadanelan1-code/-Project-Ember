extends Node

## Shared campaign state for the strategy map, city economy and tactical battles.
## Only persistent data is stored here; scene nodes and UI remain in their own scenes.

const UNIT_CATALOG_SCRIPT = preload("res://scripts/unit_catalog.gd")
const ArmyUpgradeCatalogScript = preload("res://scripts/army_upgrade_catalog.gd")
const CityDevelopmentCatalogScript = preload("res://scripts/city_development_catalog.gd")
const TerritoryCatalogScript = preload("res://scripts/territory_catalog.gd")
const BattlefieldBiomesScript = preload("res://scripts/battlefield_biomes.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")
const KingdomAIScript = preload("res://scripts/kingdom_ai.gd")
const WorldLocationCatalogScript = preload("res://scripts/world_location_catalog.gd")
const WorldEventCatalogScript = preload("res://scripts/world_event_catalog.gd")
const FactionCatalogScript = preload("res://scripts/faction_catalog.gd")
const DiplomacyCatalogScript = preload("res://scripts/diplomacy_catalog.gd")
const LordCatalogScript = preload("res://scripts/lord_catalog.gd")
const ItemCatalogScript = preload("res://scripts/item_catalog.gd")
const CommanderStatsScript = preload("res://scripts/commander_stats.gd")
const SettlementCatalogScript = preload("res://scripts/settlement_catalog.gd")
const ROLE_MELEE := "melee"
const ROLE_RANGED := "ranged"
const ROLE_SPEAR := "spear"
const ROLE_CAVALRY := "cavalry"
const ARMY_CAPACITY := 24
const MAX_PLAYER_ARMIES := 4
const PRIMARY_PLAYER_ARMY_ID := "army_primary"
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
var player_armies: Array[Dictionary] = []
var selected_player_army_id: String = PRIMARY_PLAYER_ARMY_ID
var enemy_units: Array[Dictionary] = []
var player_hero: Dictionary = {}
var hero_roster: Array[Dictionary] = []
var active_hero_id: String = "hero_ruler"
var player_faction: Dictionary = FactionCatalogScript.get_legacy_selection()
var faction_setup_pending: bool = false
var enemy_hero: Dictionary = {}
var world_seed: int = WorldGeneratorScript.DEFAULT_SEED
var world_generation_version: int = WorldGeneratorScript.WORLD_GENERATION_VERSION
var kingdoms: Array[Dictionary] = []
var diplomacy_relations: Dictionary = {}
var player_diplomacy_profile: Dictionary = {}
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
var outposts: Array[Dictionary] = []
var active_city_id: int = 0
var settler_active: bool = false
var settler_cell: Vector2i = Vector2i.ZERO
var settler_moves_left: int = 1
var settler_origin_city_id: int = -1
var settlement_upkeep_last_due: int = 0
var settlement_upkeep_last_paid: int = 0

var battle_in_progress: bool = false
var battle_origin_cell: Vector2i = Vector2i.ZERO
var battle_enemy_cell: Vector2i = Vector2i.ZERO
# Runtime-only battle presentation data; deliberately excluded from campaign saves.
var battlefield_biome_id: String = BattlefieldBiomesScript.GRASSLAND
var battlefield_seed: int = 841207
var battle_territory_armor_bonus: float = 0.0
var battle_reward_counter: int = 0
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
	player_diplomacy_profile = DiplomacyCatalogScript.normalize_leader_profile(
		{},
		DiplomacyCatalogScript.PLAYER_ID,
		player_faction,
		0,
		world_seed
	)
	DiplomacyCatalogScript.refresh_player_relationships(
		diplomacy_relations,
		kingdoms,
		player_diplomacy_profile
	)
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
	battle_reward_counter = 0
	player_moves_left = 1
	player_cell = Vector2i(-2, 0)
	world_seed = WorldGeneratorScript.DEFAULT_SEED
	world_generation_version = WorldGeneratorScript.WORLD_GENERATION_VERSION
	player_units = _make_starting_army()
	army_upgrades = {"melee": 0, "ranged": 0, "spear": 0, "cavalry": 0}
	player_hero = _make_hero_record("Эдрик", "Правитель Каменного Брода")
	player_hero["id"] = "hero_ruler"
	player_hero["kind"] = "ruler"
	hero_roster = [player_hero.duplicate(true)]
	active_hero_id = "hero_ruler"
	player_armies.clear()
	selected_player_army_id = PRIMARY_PLAYER_ARMY_ID
	player_armies.append(_make_player_army_record(PRIMARY_PLAYER_ARMY_ID, "Первая армия", player_cell, player_units, active_hero_id, army_upgrades, player_moves_left))
	kingdoms = KingdomAIScript.create_initial_kingdoms(world_seed)
	player_diplomacy_profile = DiplomacyCatalogScript.create_leader_profile(
		DiplomacyCatalogScript.PLAYER_ID,
		player_faction,
		0,
		world_seed
	)
	diplomacy_relations = DiplomacyCatalogScript.create_initial_relations(
		kingdoms.size(),
		world_seed,
		kingdoms,
		player_diplomacy_profile
	)
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
	outposts.clear()
	active_city_id = 0
	cities.append(_make_city_record(0, city_name, city_cell, city_population, city_food, city_gold, city_production_bank, city_buildings, city_build_queue))
	settler_active = false
	settler_cell = Vector2i.ZERO
	settler_moves_left = 1
	settler_origin_city_id = -1
	settlement_upkeep_last_due = 0
	settlement_upkeep_last_paid = 0
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


func _make_player_army_record(
		army_id: String,
		army_name: String,
		army_cell: Vector2i,
		units: Array[Dictionary],
		hero_id: String,
		upgrades: Dictionary,
		moves_left: int
) -> Dictionary:
	return {
		"id": army_id,
		"name": army_name,
		"cell": WorldGeneratorScript.cell_to_array(army_cell),
		"units": _copy_unit_records(units),
		"hero_id": hero_id,
		"upgrades": _read_army_upgrades(upgrades),
		"moves_left": clampi(moves_left, 0, 1),
	}


func _get_player_army_index(army_id: String) -> int:
	for index in range(player_armies.size()):
		if str(player_armies[index].get("id", "")) == army_id:
			return index
	return -1


func _get_primary_player_army() -> Dictionary:
	var index := _get_player_army_index(PRIMARY_PLAYER_ARMY_ID)
	if index >= 0:
		return player_armies[index].duplicate(true)
	if not player_armies.is_empty():
		return player_armies[0].duplicate(true)
	return _make_player_army_record(PRIMARY_PLAYER_ARMY_ID, "Первая армия", player_cell, player_units, active_hero_id, army_upgrades, player_moves_left)


func _sync_selected_player_army_from_legacy() -> void:
	if player_armies.is_empty():
		return
	var index := _get_player_army_index(selected_player_army_id)
	if index < 0:
		return
	var record: Dictionary = player_armies[index]
	record["cell"] = WorldGeneratorScript.cell_to_array(player_cell)
	record["units"] = _copy_unit_records(player_units)
	record["moves_left"] = clampi(player_moves_left, 0, 1)
	record["upgrades"] = _read_army_upgrades(army_upgrades)
	record["hero_id"] = active_hero_id
	player_armies[index] = record


func _load_selected_player_army_to_legacy() -> bool:
	var index := _get_player_army_index(selected_player_army_id)
	if index < 0:
		return false
	var record: Dictionary = player_armies[index]
	player_cell = WorldGeneratorScript.array_to_cell(record.get("cell", []), player_cell)
	player_units = _read_unit_records(record.get("units", []))
	player_moves_left = clampi(int(record.get("moves_left", 1)), 0, 1)
	army_upgrades = _read_army_upgrades(record.get("upgrades", {}))
	active_hero_id = str(record.get("hero_id", ""))
	player_hero = _get_hero_record(active_hero_id)
	return true


func get_player_army_at(cell: Vector2i) -> Dictionary:
	for record in player_armies:
		var army_cell := WorldGeneratorScript.array_to_cell(record.get("cell", []), Vector2i(9999, 9999))
		if army_cell == cell:
			return record.duplicate(true)
	return {}


func get_player_army_total_units() -> int:
	_sync_selected_player_army_from_legacy()
	var total := 0
	for record in player_armies:
		var units_value: Variant = record.get("units", [])
		if units_value is Array:
			total += units_value.size()
	return total


func get_hero_assigned_army_id(hero_id: String) -> String:
	if hero_id.is_empty():
		return ""
	for record in player_armies:
		if str(record.get("hero_id", "")) == hero_id:
			return str(record.get("id", ""))
	return ""


func get_unassigned_hero_id() -> String:
	for hero in hero_roster:
		var hero_id := str(hero.get("id", ""))
		if not hero_id.is_empty() and get_hero_assigned_army_id(hero_id).is_empty():
			return hero_id
	return ""


func get_player_army_spawn_cell(origin: Vector2i) -> Vector2i:
	for offset in WorldGeneratorScript.neighbors():
		var candidate := origin + offset
		if not WorldGeneratorScript.is_inside_world(candidate) or get_world_terrain(candidate) == "water":
			continue
		if get_city_index_at(candidate) >= 0 or get_kingdom_index_at_army(candidate) >= 0:
			continue
		var occupied_by_player_army := false
		for record in player_armies:
			var army_id := str(record.get("id", ""))
			var army_cell := WorldGeneratorScript.array_to_cell(record.get("cell", []), Vector2i(9999, 9999))
			if army_cell == candidate and army_id != selected_player_army_id:
				occupied_by_player_army = true
				break
		if WorldLocationCatalogScript.has_location_at(neutral_locations, candidate):
			continue
		if settler_active and settler_cell == candidate:
			continue
		if not occupied_by_player_army:
			return candidate
	return Vector2i(9999, 9999)


func can_create_player_army() -> bool:
	_sync_selected_player_army_from_legacy()
	if battle_in_progress or campaign_lost or player_armies.size() >= MAX_PLAYER_ARMIES:
		return false
	if player_armies.size() >= hero_roster.size() or player_units.size() < 2:
		return false
	return not get_unassigned_hero_id().is_empty() and get_player_army_spawn_cell(player_cell) != Vector2i(9999, 9999)


func create_player_army(split_count: int = 0) -> bool:
	_sync_selected_player_army_from_legacy()
	if not can_create_player_army():
		return false
	var source_units := _copy_unit_records(player_units)
	var transfer_count := split_count if split_count > 0 else maxi(1, source_units.size() / 2)
	transfer_count = clampi(transfer_count, 1, source_units.size() - 1)
	var split_index := source_units.size() - transfer_count
	var remaining_units: Array[Dictionary] = []
	var transferred_units: Array[Dictionary] = []
	for index in range(source_units.size()):
		if index < split_index:
			remaining_units.append(source_units[index].duplicate(true))
		else:
			transferred_units.append(source_units[index].duplicate(true))
	var spawn_cell := get_player_army_spawn_cell(player_cell)
	if spawn_cell == Vector2i(9999, 9999):
		return false
	var assigned_hero_id := get_unassigned_hero_id()
	if assigned_hero_id.is_empty():
		return false
	var serial := 2
	var new_army_id := "army_%02d" % serial
	while _get_player_army_index(new_army_id) >= 0:
		serial += 1
		new_army_id = "army_%02d" % serial
	player_units = remaining_units
	_sync_selected_player_army_from_legacy()
	player_armies.append(_make_player_army_record(
		new_army_id,
		"Армия %d" % serial,
		spawn_cell,
		transferred_units,
		assigned_hero_id,
		army_upgrades,
		1
	))
	selected_player_army_id = new_army_id
	_load_selected_player_army_to_legacy()
	refresh_fog_of_war()
	save_campaign()
	return true


func select_player_army(army_id: String) -> bool:
	if battle_in_progress or army_id.is_empty() or _get_player_army_index(army_id) < 0:
		return false
	_sync_selected_player_army_from_legacy()
	selected_player_army_id = army_id
	if not _load_selected_player_army_to_legacy():
		return false
	refresh_fog_of_war()
	save_campaign()
	return true


func move_selected_player_army(target_cell: Vector2i) -> bool:
	if battle_in_progress or player_moves_left <= 0:
		return false
	_sync_selected_player_army_from_legacy()
	if WorldGeneratorScript.hex_distance(player_cell, target_cell) != 1:
		return false
	if not WorldGeneratorScript.is_inside_world(target_cell) or get_world_terrain(target_cell) == "water":
		return false
	if get_city_index_at(target_cell) >= 0 or get_kingdom_index_at_army(target_cell) >= 0:
		return false
	for record in player_armies:
		if str(record.get("id", "")) == selected_player_army_id:
			continue
		if WorldGeneratorScript.array_to_cell(record.get("cell", []), Vector2i(9999, 9999)) == target_cell:
			return false
	player_cell = target_cell
	player_moves_left -= 1
	_sync_selected_player_army_from_legacy()
	refresh_fog_of_war()
	save_campaign()
	return true


func _read_player_armies(value: Variant, fallback: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var assigned_heroes: Dictionary = {}
	if value is Array:
		for index in range(mini(value.size(), MAX_PLAYER_ARMIES)):
			var raw_value: Variant = value[index]
			if not raw_value is Dictionary:
				continue
			var raw: Dictionary = raw_value
			var army_id := str(raw.get("id", "")).strip_edges()
			if army_id.is_empty() or seen_ids.has(army_id):
				army_id = "army_legacy_%d" % index
			seen_ids[army_id] = true
			var fallback_cell := WorldGeneratorScript.array_to_cell(fallback.get("cell", []), player_cell)
			var army_cell := WorldGeneratorScript.array_to_cell(raw.get("cell", []), fallback_cell)
			if not WorldGeneratorScript.is_inside_world(army_cell):
				army_cell = fallback_cell
			var units := _read_unit_records(raw.get("units", []))
			var upgrades_value: Variant = raw.get("upgrades", {})
			var upgrades: Dictionary = upgrades_value if upgrades_value is Dictionary else {}
			var hero_id := str(raw.get("hero_id", ""))
			if hero_id.is_empty() or _get_hero_record(hero_id).is_empty() or assigned_heroes.has(hero_id):
				hero_id = ""
				for hero in hero_roster:
					var candidate_id := str(hero.get("id", ""))
					if not candidate_id.is_empty() and not assigned_heroes.has(candidate_id):
						hero_id = candidate_id
						break
			if not hero_id.is_empty():
				assigned_heroes[hero_id] = true
			var army_name := str(raw.get("name", "Армия %d" % (index + 1))).strip_edges()
			if army_name.is_empty():
				army_name = "Армия %d" % (index + 1)
			result.append(_make_player_army_record(
				army_id,
				army_name,
				army_cell,
				units,
				hero_id,
				upgrades,
				clampi(int(raw.get("moves_left", 1)), 0, 1)
			))
	if result.is_empty():
		var fallback_id := str(fallback.get("id", PRIMARY_PLAYER_ARMY_ID))
		var fallback_units := _read_unit_records(fallback.get("units", []))
		var fallback_cell := WorldGeneratorScript.array_to_cell(fallback.get("cell", []), player_cell)
		var fallback_hero_id := str(fallback.get("hero_id", ""))
		if fallback_hero_id.is_empty() or _get_hero_record(fallback_hero_id).is_empty():
			fallback_hero_id = str(hero_roster[0].get("id", "")) if not hero_roster.is_empty() else ""
		var fallback_upgrades_value: Variant = fallback.get("upgrades", {})
		var fallback_upgrades: Dictionary = fallback_upgrades_value if fallback_upgrades_value is Dictionary else {}
		result.append(_make_player_army_record(
			fallback_id,
			str(fallback.get("name", "Первая армия")),
			fallback_cell,
			fallback_units,
			fallback_hero_id,
			fallback_upgrades,
			int(fallback.get("moves_left", 1))
		))
	var has_primary := false
	for record in result:
		if str(record.get("id", "")) == PRIMARY_PLAYER_ARMY_ID:
			has_primary = true
			break
	if not has_primary:
		if result.size() >= MAX_PLAYER_ARMIES:
			result.pop_back()
		var primary_fallback := fallback.duplicate(true)
		primary_fallback["id"] = PRIMARY_PLAYER_ARMY_ID
		primary_fallback["name"] = "Первая армия"
		var primary_hero_id := str(primary_fallback.get("hero_id", ""))
		if primary_hero_id.is_empty() or assigned_heroes.has(primary_hero_id):
			primary_hero_id = ""
			for hero in hero_roster:
				var candidate_id := str(hero.get("id", ""))
				if not candidate_id.is_empty() and not assigned_heroes.has(candidate_id):
					primary_hero_id = candidate_id
					break
		primary_fallback["hero_id"] = primary_hero_id
		result.push_front(_make_player_army_record(
			PRIMARY_PLAYER_ARMY_ID,
			"Первая армия",
			WorldGeneratorScript.array_to_cell(primary_fallback.get("cell", []), player_cell),
			_read_unit_records(primary_fallback.get("units", [])),
			primary_hero_id,
			primary_fallback.get("upgrades", {}),
			int(primary_fallback.get("moves_left", 1))
		))
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
		"equipment": {"weapon": "", "armor": "", "relic": ""},
		"inventory": [],
	}



func get_lord_candidate_catalog() -> Array[Dictionary]:
	return LordCatalogScript.get_candidates()


func is_lord_recruited(candidate_id: String) -> bool:
	for hero in hero_roster:
		if str(hero.get("id", "")) == candidate_id:
			return true
	return false


func can_recruit_lord(candidate_id: String) -> bool:
	var candidate := LordCatalogScript.get_candidate(candidate_id)
	if candidate.is_empty() or battle_in_progress:
		return false
	if hero_roster.size() >= LordCatalogScript.MAX_HERO_ROSTER_SIZE:
		return false
	if is_lord_recruited(candidate_id):
		return false
	return city_gold >= int(candidate.get("cost", 0))


func recruit_lord(candidate_id: String) -> bool:
	if not can_recruit_lord(candidate_id):
		return false
	var candidate := LordCatalogScript.get_candidate(candidate_id)
	if candidate.is_empty():
		return false
	var cost := maxi(0, int(candidate.get("cost", 0)))
	city_gold -= cost
	var hero := _make_hero_record(
		str(candidate.get("name", "Новый лорд")),
		str(candidate.get("title", "Командир"))
	)
	hero["id"] = candidate_id
	hero["kind"] = "lord"
	var skills_value: Variant = hero.get("skills", {})
	var skills: Dictionary = skills_value.duplicate(true) if skills_value is Dictionary else {}
	var specialty := str(candidate.get("specialty", ""))
	if ["leadership", "tactics", "might"].has(specialty):
		skills[specialty] = 1
	hero["skills"] = skills
	hero["health"] = get_hero_max_health(hero)
	hero_roster.append(hero)
	save_campaign()
	return true


func activate_hero(hero_id: String) -> bool:
	return assign_hero_to_army(selected_player_army_id, hero_id)


func assign_hero_to_army(army_id: String, hero_id: String) -> bool:
	if battle_in_progress or hero_id.is_empty():
		return false
	_sync_selected_player_army_from_legacy()
	_sync_active_hero_to_roster()
	var army_index := _get_player_army_index(army_id)
	var hero_record := _get_hero_record(hero_id)
	if army_index < 0 or hero_record.is_empty():
		return false
	for record in player_armies:
		if str(record.get("id", "")) != army_id and str(record.get("hero_id", "")) == hero_id:
			return false
	var army: Dictionary = player_armies[army_index]
	army["hero_id"] = hero_id
	player_armies[army_index] = army
	if army_id == selected_player_army_id:
		active_hero_id = hero_id
		player_hero = hero_record
	save_campaign()
	return true


func _get_hero_record(hero_id: String) -> Dictionary:
	for hero in hero_roster:
		if str(hero.get("id", "")) == hero_id:
			return hero.duplicate(true)
	return {}


func _sync_active_hero_to_roster() -> void:
	if player_hero.is_empty():
		return
	if active_hero_id.is_empty():
		active_hero_id = str(player_hero.get("id", "hero_ruler"))
	if active_hero_id.is_empty():
		active_hero_id = "hero_ruler"
	player_hero["id"] = active_hero_id
	var active_record := player_hero.duplicate(true)
	for index in range(hero_roster.size()):
		if str(hero_roster[index].get("id", "")) == active_hero_id:
			hero_roster[index] = active_record
			return
	hero_roster.append(active_record)


func _read_hero_roster(value: Variant, fallback_hero: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	if value is Array:
		for index in range(value.size()):
			var raw_hero: Variant = value[index]
			if not raw_hero is Dictionary:
				continue
			var fallback := fallback_hero.duplicate(true)
			if index > 0:
				fallback["id"] = "hero_legacy_%d" % index
			var hero := _read_hero_record(raw_hero, fallback)
			var hero_id := str(hero.get("id", "")).strip_edges()
			if hero_id.is_empty() or seen_ids.has(hero_id):
				hero_id = "hero_legacy_%d" % index
			hero["id"] = hero_id
			if hero_id == "hero_ruler":
				hero["kind"] = "ruler"
			else:
				hero["kind"] = str(hero.get("kind", "lord"))
			seen_ids[hero_id] = true
			result.append(hero)
	if result.is_empty():
		var legacy_hero := _read_hero_record(fallback_hero, fallback_hero)
		legacy_hero["id"] = str(fallback_hero.get("id", "hero_ruler"))
		legacy_hero["kind"] = str(fallback_hero.get("kind", "ruler"))
		result.append(legacy_hero)
	return result


func get_hero_equipment_modifiers(hero: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for modifier_key in ItemCatalogScript.MODIFIER_KEYS:
		result[modifier_key] = 1.0 if modifier_key == "attack_damage_multiplier" else 0.0
	var equipment := _normalize_hero_equipment(hero.get("equipment", {}))
	for slot_id in ItemCatalogScript.SLOT_IDS:
		var item_id := str(equipment.get(slot_id, ""))
		if item_id.is_empty():
			continue
		var item := ItemCatalogScript.get_item(item_id)
		var item_modifiers_value: Variant = item.get("modifiers", {})
		if not item_modifiers_value is Dictionary:
			continue
		var item_modifiers: Dictionary = item_modifiers_value
		for modifier_key in ItemCatalogScript.MODIFIER_KEYS:
			if not item_modifiers.has(modifier_key):
				continue
			if modifier_key == "attack_damage_multiplier":
				result[modifier_key] = float(result.get(modifier_key, 1.0)) * float(item_modifiers.get(modifier_key, 1.0))
			else:
				result[modifier_key] = float(result.get(modifier_key, 0.0)) + float(item_modifiers.get(modifier_key, 0.0))
	return result


func get_hero_combat_stats(hero: Dictionary, territory_armor_bonus: float = 0.0) -> Dictionary:
	return CommanderStatsScript.calculate(hero, get_hero_equipment_modifiers(hero), territory_armor_bonus)


func get_hero_stats_with_item(hero: Dictionary, slot_id: String, item_id: String) -> Dictionary:
	if not ItemCatalogScript.SLOT_IDS.has(slot_id):
		return {}
	var item := ItemCatalogScript.get_item(item_id)
	if item.is_empty() or str(item.get("slot", "")) != slot_id:
		return {}
	var hero_copy := hero.duplicate(true)
	var equipment := _normalize_hero_equipment(hero_copy.get("equipment", {}))
	equipment[slot_id] = item_id
	hero_copy["equipment"] = equipment
	return get_hero_combat_stats(hero_copy)


func get_hero_inventory_item_ids(hero_id: String) -> Array[String]:
	var hero := _get_hero_record(hero_id)
	return _normalize_hero_inventory(hero.get("inventory", []))


func equip_item_to_hero(hero_id: String, item_id: String) -> bool:
	if battle_in_progress or not ItemCatalogScript.is_valid_item(item_id):
		return false
	var hero := _get_hero_record(hero_id)
	if hero.is_empty():
		return false
	var inventory := _normalize_hero_inventory(hero.get("inventory", []))
	var inventory_index := inventory.find(item_id)
	if inventory_index < 0:
		return false
	var item := ItemCatalogScript.get_item(item_id)
	var slot_id := str(item.get("slot", ""))
	if not ItemCatalogScript.SLOT_IDS.has(slot_id):
		return false
	var equipment := _normalize_hero_equipment(hero.get("equipment", {}))
	var current_item_id := str(equipment.get(slot_id, ""))
	if current_item_id == item_id:
		return false
	inventory.remove_at(inventory_index)
	if not current_item_id.is_empty():
		inventory.append(current_item_id)
	equipment[slot_id] = item_id
	hero["inventory"] = inventory
	hero["equipment"] = equipment
	var new_max_health := float(get_hero_combat_stats(hero).get("max_health", get_hero_max_health(hero)))
	hero["health"] = minf(float(hero.get("health", new_max_health)), new_max_health)
	_store_hero_record(hero_id, hero)
	save_campaign()
	return true


func unequip_hero_slot(hero_id: String, slot_id: String) -> bool:
	if battle_in_progress or not ItemCatalogScript.SLOT_IDS.has(slot_id):
		return false
	var hero := _get_hero_record(hero_id)
	if hero.is_empty():
		return false
	var equipment := _normalize_hero_equipment(hero.get("equipment", {}))
	var item_id := str(equipment.get(slot_id, ""))
	if item_id.is_empty():
		return false
	var inventory := _normalize_hero_inventory(hero.get("inventory", []))
	if inventory.size() >= ItemCatalogScript.MAX_HERO_INVENTORY:
		return false
	inventory.append(item_id)
	equipment[slot_id] = ""
	hero["equipment"] = equipment
	hero["inventory"] = inventory
	var new_max_health := float(get_hero_combat_stats(hero).get("max_health", get_hero_max_health(hero)))
	hero["health"] = minf(float(hero.get("health", new_max_health)), new_max_health)
	_store_hero_record(hero_id, hero)
	save_campaign()
	return true


func _store_hero_record(hero_id: String, hero: Dictionary) -> void:
	for index in range(hero_roster.size()):
		if str(hero_roster[index].get("id", "")) == hero_id:
			hero_roster[index] = hero.duplicate(true)
			break
	if active_hero_id == hero_id:
		player_hero = hero.duplicate(true)


func _add_item_to_hero_inventory(hero_id: String, item_id: String) -> bool:
	if not ItemCatalogScript.is_valid_item(item_id):
		return false
	var hero := _get_hero_record(hero_id)
	if hero.is_empty():
		return false
	var inventory := _normalize_hero_inventory(hero.get("inventory", []))
	if inventory.size() >= ItemCatalogScript.MAX_HERO_INVENTORY:
		return false
	inventory.append(item_id)
	hero["inventory"] = inventory
	_store_hero_record(hero_id, hero)
	return true


func _normalize_hero_equipment(value: Variant) -> Dictionary:
	var result := {"weapon": "", "armor": "", "relic": ""}
	if not value is Dictionary:
		return result
	for slot_id in ItemCatalogScript.SLOT_IDS:
		var item_id := str(value.get(slot_id, ""))
		var item := ItemCatalogScript.get_item(item_id)
		if not item.is_empty() and str(item.get("slot", "")) == slot_id:
			result[slot_id] = item_id
	return result


func _normalize_hero_inventory(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item_value in value:
		var item_id := str(item_value)
		if ItemCatalogScript.is_valid_item(item_id) and result.size() < ItemCatalogScript.MAX_HERO_INVENTORY:
			result.append(item_id)
	return result


func get_hero_max_health(hero: Dictionary) -> float:
	return float(get_hero_combat_stats(hero).get("max_health", 210.0))


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
	result["id"] = str(source.get("id", result.get("id", "hero_ruler")))
	result["kind"] = str(source.get("kind", result.get("kind", "ruler")))
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
	result["equipment"] = _normalize_hero_equipment(source.get("equipment", result.get("equipment", {})))
	result["inventory"] = _normalize_hero_inventory(source.get("inventory", result.get("inventory", [])))
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
	if hero_roster.is_empty():
		var ruler_fallback := _make_hero_record("Эдрик", "Правитель Каменного Брода")
		ruler_fallback["id"] = "hero_ruler"
		ruler_fallback["kind"] = "ruler"
		hero_roster = _read_hero_roster([], player_hero if not player_hero.is_empty() else ruler_fallback)
		active_hero_id = str(hero_roster[0].get("id", "hero_ruler"))
	_sync_active_hero_to_roster()
	for index in range(hero_roster.size()):
		var player_record: Dictionary = hero_roster[index]
		_recover_hero_record(player_record)
		hero_roster[index] = player_record
	var active_record := _get_hero_record(active_hero_id)
	if not active_record.is_empty():
		player_hero = active_record
	else:
		active_hero_id = str(hero_roster[0].get("id", "hero_ruler"))
		player_hero = hero_roster[0].duplicate(true)
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
		provoked_record["war_initiator_id"] = DiplomacyCatalogScript.PLAYER_ID
		provoked_record["war_target_id"] = kingdom_id
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
	battle_territory_armor_bonus = TerritoryCatalogScript.get_defensive_armor_bonus(battle_origin_cell, cities, kingdoms, outposts)
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
	battle_territory_armor_bonus = 0.0
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


func get_nearest_player_city_index(cell: Vector2i) -> int:
	return _find_nearest_player_city_index(cell)


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
			var survey_origin := _find_scout_reveal_origin(location_cell, 12, 5)
			_reveal_fog_area(survey_origin, 5)
			return "Старые карты раскрыли удалённый участок мира."
		"monster_lair":
			for unit in player_units:
				unit["experience"] = clampi(int(unit.get("experience", 0)) + 12, 0, 999999)
			return "Войска получили по 12 опыта за победу над чудовищами."
		"abandoned_mine":
			return "Шахта работает: ближайшее поселение получает +2 производства каждый ход."
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
				location["cleared_by"] = -1
				location["cleared_turn"] = turn_number
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
	last_battle_result["territory_armor_bonus"] = battle_territory_armor_bonus
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
	battle_reward_counter += 1
	var reward_target_id := battle_location_id if battle_target_type == "location" else str(battle_kingdom_id)
	var reward_item_id := ItemCatalogScript.get_deterministic_battle_reward(
		world_seed,
		turn_number,
		battle_reward_counter,
		battle_target_type,
		reward_target_id,
		active_hero_id
	) if victory else ""
	if not reward_item_id.is_empty() and _add_item_to_hero_inventory(active_hero_id, reward_item_id):
		var reward_item := ItemCatalogScript.get_item(reward_item_id)
		last_battle_result["equipment_reward_id"] = reward_item_id
		last_battle_result["equipment_reward_name"] = str(reward_item.get("name", reward_item_id))
	else:
		last_battle_result["equipment_reward_id"] = ""
		last_battle_result["equipment_reward_name"] = ""
	last_battle_result["hero_level"] = int(player_hero.get("level", 1))
	last_battle_result["hero_skill_points"] = int(player_hero.get("skill_points", 0))
	last_battle_report_pending = true

	if victory:
		player_cell = battle_enemy_cell
	else:
		player_cell = battle_origin_cell

	_sync_selected_player_army_from_legacy()
	campaign_lost = get_player_army_total_units() <= 0
	battle_in_progress = false
	battle_kingdom_id = -1
	battle_target_type = "kingdom"
	battle_location_id = ""
	battle_territory_armor_bonus = 0.0
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


func _make_outpost_record(id: int, outpost_name: String, cell: Vector2i, food: int = 0, gold: int = 0, production: int = 0, province_improvements: Array = []) -> Dictionary:
	var normalized_improvements := CityDevelopmentCatalogScript.normalize_province_improvements(province_improvements)
	var limited_improvements: Array[Dictionary] = []
	for improvement in normalized_improvements:
		if limited_improvements.size() >= SettlementCatalogScript.OUTPOST_MAX_PROVINCE_IMPROVEMENTS:
			break
		limited_improvements.append(improvement.duplicate(true))
	return {
		"id": id,
		"name": outpost_name,
		"cell": [cell.x, cell.y],
		"food": maxi(0, food),
		"gold": maxi(0, gold),
		"production_bank": maxi(0, production),
		"province_improvements": limited_improvements,
		"last_event": "",
	}


func _read_outposts(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var occupied: Dictionary = {}
	for city in cities:
		var city_cell_value := WorldGeneratorScript.array_to_cell(city.get("cell", []), Vector2i(9999, 9999))
		occupied["%d:%d" % [city_cell_value.x, city_cell_value.y]] = true
	for raw in value:
		if not raw is Dictionary or cities.size() + result.size() >= SettlementCatalogScript.MAX_PLAYER_SETTLEMENTS:
			continue
		var cell := WorldGeneratorScript.array_to_cell(raw.get("cell", []), Vector2i(9999, 9999))
		if not WorldGeneratorScript.is_inside_world(cell):
			continue
		var key := "%d:%d" % [cell.x, cell.y]
		if occupied.has(key):
			continue
		var improvements_value: Variant = raw.get("province_improvements", [])
		var improvements: Array = improvements_value if improvements_value is Array else []
		var record := _make_outpost_record(
			result.size(),
			str(raw.get("name", "Застава %d" % (result.size() + 1))),
			cell,
			maxi(0, int(raw.get("food", 0))),
			maxi(0, int(raw.get("gold", 0))),
			maxi(0, int(raw.get("production_bank", 0))),
			improvements
		)
		record["last_event"] = str(raw.get("last_event", ""))
		result.append(record)
		occupied[key] = true
	return result


func get_settlement_counts() -> Dictionary:
	return {"cities": cities.size(), "outposts": outposts.size(), "total": cities.size() + outposts.size()}


func get_settler_cost_preview() -> Dictionary:
	return SettlementCatalogScript.get_settler_cost(cities.size(), outposts.size())


func get_outpost_income(outpost_index: int) -> Dictionary:
	if outpost_index < 0 or outpost_index >= outposts.size():
		return {"food": 0, "gold": 0, "production": 0}
	var improvements_value: Variant = outposts[outpost_index].get("province_improvements", [])
	var improvements: Array = improvements_value if improvements_value is Array else []
	return SettlementCatalogScript.get_outpost_income(improvements)


func get_outpost_income_summary(outpost_index: int) -> String:
	var income := get_outpost_income(outpost_index)
	return "+%d еды · +%d золота · +%d производства за ход" % [
		int(income.get("food", 0)), int(income.get("gold", 0)), int(income.get("production", 0))
	]


func _get_settler_origin_city_index() -> int:
	if settler_origin_city_id >= 0 and settler_origin_city_id < cities.size():
		return settler_origin_city_id
	if active_city_id >= 0 and active_city_id < cities.size():
		return active_city_id
	return 0 if not cities.is_empty() else -1


func _get_city_resource_balance(city_index: int) -> Dictionary:
	if city_index < 0 or city_index >= cities.size():
		return {}
	if city_index == active_city_id:
		return {"gold": city_gold, "production": city_production_bank, "food": city_food}
	var record: Dictionary = cities[city_index]
	return {
		"gold": maxi(0, int(record.get("gold", 0))),
		"production": maxi(0, int(record.get("production_bank", 0))),
		"food": maxi(0, int(record.get("food", 0))),
	}


func _can_spend_city_resources(city_index: int, gold_cost: int, production_cost: int) -> bool:
	var balance := _get_city_resource_balance(city_index)
	return not balance.is_empty() and int(balance.get("gold", 0)) >= gold_cost and int(balance.get("production", 0)) >= production_cost


func _spend_city_resources(city_index: int, gold_cost: int, production_cost: int) -> bool:
	if not _can_spend_city_resources(city_index, gold_cost, production_cost):
		return false
	_save_active_city()
	var record: Dictionary = cities[city_index].duplicate(true)
	record["gold"] = maxi(0, int(record.get("gold", 0)) - gold_cost)
	record["production_bank"] = maxi(0, int(record.get("production_bank", 0)) - production_cost)
	cities[city_index] = record
	if city_index == active_city_id:
		_load_active_city()
	return true


func get_outpost_index_at(cell: Vector2i) -> int:
	for index in range(outposts.size()):
		var outpost_cell := WorldGeneratorScript.array_to_cell(outposts[index].get("cell", []), Vector2i(9999, 9999))
		if outpost_cell == cell:
			return index
	return -1


func get_nearest_outpost_index(cell: Vector2i, max_distance: int = 999999) -> int:
	var best_index := -1
	var best_distance := max_distance + 1
	for index in range(outposts.size()):
		var outpost_cell := WorldGeneratorScript.array_to_cell(outposts[index].get("cell", []), Vector2i(9999, 9999))
		var distance := WorldGeneratorScript.hex_distance(cell, outpost_cell)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index

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
	var cost := get_settler_cost_preview()
	return (
		not campaign_lost
		and city_population >= int(cost.get("minimum_population", SettlementCatalogScript.SETTLER_MIN_POPULATION))
		and city_gold >= int(cost.get("gold", SettlementCatalogScript.SETTLER_BASE_GOLD_COST))
		and not settler_active
		and not _has_settler_order()
	)


func queue_settler() -> bool:
	if not can_queue_settler():
		return false
	var cost := get_settler_cost_preview()
	var gold_cost := int(cost.get("gold", SettlementCatalogScript.SETTLER_BASE_GOLD_COST))
	var production_cost := int(cost.get("production", SettlementCatalogScript.SETTLER_BASE_PRODUCTION_COST))
	city_gold -= gold_cost
	city_population = maxi(1, city_population - int(cost.get("population", SettlementCatalogScript.SETTLER_POPULATION_COST)))
	city_build_queue.append({
		"kind": "settler", "id": "settler", "name": "Поселенец",
		"production_cost": production_cost, "origin_city_id": active_city_id,
	})
	city_last_event = "Поселенец добавлен в очередь. Стоимость: %d золота и %d производства." % [gold_cost, production_cost]
	save_campaign()
	return true


func _is_settlement_cell_valid(cell: Vector2i) -> bool:
	if not WorldGeneratorScript.is_inside_world(cell):
		return false
	if WorldGeneratorScript.terrain_at(cell, world_seed, world_generation_version) == "water":
		return false
	if get_city_index_at(cell) >= 0 or get_outpost_index_at(cell) >= 0:
		return false
	if not get_player_army_at(cell).is_empty() or cell == enemy_cell:
		return false
	if WorldLocationCatalogScript.has_location_at(neutral_locations, cell):
		return false
	for kingdom in kingdoms:
		if WorldGeneratorScript.array_to_cell(kingdom.get("army_cell", []), Vector2i(9999, 9999)) == cell:
			return false
		for ai_city in kingdom.get("cities", []):
			if WorldGeneratorScript.array_to_cell(ai_city.get("cell", []), Vector2i(9999, 9999)) == cell:
				return false
		for ai_outpost in kingdom.get("outposts", []):
			if WorldGeneratorScript.array_to_cell(ai_outpost.get("cell", []), Vector2i(9999, 9999)) == cell:
				return false
	return true


func _is_settlement_spacing_valid(cell: Vector2i, settlement_type: String) -> bool:
	for city_record in cities:
		var c := WorldGeneratorScript.array_to_cell(city_record.get("cell", []), Vector2i(9999, 9999))
		if WorldGeneratorScript.hex_distance(cell, c) < SettlementCatalogScript.get_minimum_spacing(settlement_type, SettlementCatalogScript.TYPE_CITY):
			return false
	for outpost_record in outposts:
		var other := WorldGeneratorScript.array_to_cell(outpost_record.get("cell", []), Vector2i(9999, 9999))
		if WorldGeneratorScript.hex_distance(cell, other) < SettlementCatalogScript.get_minimum_spacing(settlement_type, SettlementCatalogScript.TYPE_OUTPOST):
			return false
	for kingdom in kingdoms:
		for ai_city in kingdom.get("cities", []):
			var ai_city_cell := WorldGeneratorScript.array_to_cell(ai_city.get("cell", []), Vector2i(9999, 9999))
			if WorldGeneratorScript.hex_distance(cell, ai_city_cell) < SettlementCatalogScript.get_minimum_spacing(settlement_type, SettlementCatalogScript.TYPE_CITY):
				return false
		for ai_outpost in kingdom.get("outposts", []):
			var ai_outpost_cell := WorldGeneratorScript.array_to_cell(ai_outpost.get("cell", []), Vector2i(9999, 9999))
			if WorldGeneratorScript.hex_distance(cell, ai_outpost_cell) < SettlementCatalogScript.get_minimum_spacing(settlement_type, SettlementCatalogScript.TYPE_OUTPOST):
				return false
	return true


func can_found_settlement(cell: Vector2i, settlement_type: String) -> bool:
	if not settler_active or campaign_lost or battle_in_progress or not SettlementCatalogScript.is_valid_settlement_type(settlement_type):
		return false
	if cities.size() + outposts.size() >= SettlementCatalogScript.MAX_PLAYER_SETTLEMENTS:
		return false
	if not _is_settlement_cell_valid(cell) or not _is_settlement_spacing_valid(cell, settlement_type):
		return false
	var territory_owner := get_world_owner_at(cell)
	if settlement_type == SettlementCatalogScript.TYPE_CITY:
		if territory_owner == TerritoryCatalogScript.OWNER_DISPUTED or territory_owner >= 0:
			return false
	else:
		if territory_owner == TerritoryCatalogScript.OWNER_DISPUTED and not SettlementCatalogScript.OUTPOST_ALLOWED_ON_DISPUTED_TERRITORY:
			return false
		if territory_owner >= 0 and not SettlementCatalogScript.OUTPOST_ALLOWED_ON_ENEMY_TERRITORY:
			return false
		if territory_owner == TerritoryCatalogScript.OWNER_PLAYER and not SettlementCatalogScript.OUTPOST_ALLOWED_ON_PLAYER_TERRITORY:
			return false
		if territory_owner == TerritoryCatalogScript.OWNER_UNCLAIMED and not SettlementCatalogScript.OUTPOST_ALLOWED_ON_UNCLAIMED_TERRITORY:
			return false
		if territory_owner != TerritoryCatalogScript.OWNER_PLAYER and territory_owner != TerritoryCatalogScript.OWNER_UNCLAIMED and territory_owner != TerritoryCatalogScript.OWNER_DISPUTED and territory_owner < 0:
			return false
	var origin_index := _get_settler_origin_city_index()
	var cost := SettlementCatalogScript.get_foundation_cost(settlement_type)
	return _can_spend_city_resources(origin_index, int(cost.get("gold", 0)), int(cost.get("production", 0)))


func can_found_city(cell: Vector2i) -> bool:
	return can_found_settlement(cell, SettlementCatalogScript.TYPE_CITY)


func can_found_outpost(cell: Vector2i) -> bool:
	return can_found_settlement(cell, SettlementCatalogScript.TYPE_OUTPOST)


func found_settlement(cell: Vector2i, settlement_type: String) -> bool:
	if not can_found_settlement(cell, settlement_type):
		return false
	var origin_index := _get_settler_origin_city_index()
	var cost := SettlementCatalogScript.get_foundation_cost(settlement_type)
	if not _spend_city_resources(origin_index, int(cost.get("gold", 0)), int(cost.get("production", 0))):
		return false
	_save_active_city()
	if settlement_type == SettlementCatalogScript.TYPE_CITY:
		var names := ["Сосновый Дол", "Серебряный Ручей", "Солнечный Холм", "Тихая Гавань"]
		var new_id := cities.size()
		var city_name_new: String = str(names[(new_id - 1) % names.size()])
		cities.append(_make_city_record(new_id, city_name_new, cell, 2, 0, 35, 0, [], [], "", {}, []))
		active_city_id = new_id
		_load_active_city()
		city_last_event = "Основан новый город: " + city_name_new
	else:
		var outpost_names := ["Пограничный Дозор", "Старая Переправа", "Лесной Пост", "Каменный Форт", "Тихая Застава"]
		var new_outpost_id := outposts.size()
		var outpost_name: String = str(outpost_names[new_outpost_id % outpost_names.size()])
		outposts.append(_make_outpost_record(new_outpost_id, outpost_name, cell))
		_load_active_city()
		city_last_event = "Основана застава: %s." % outpost_name
	settler_active = false
	settler_cell = Vector2i.ZERO
	settler_moves_left = 1
	settler_origin_city_id = -1
	save_campaign()
	return true


func found_city(cell: Vector2i) -> bool:
	return found_settlement(cell, SettlementCatalogScript.TYPE_CITY)


func found_outpost(cell: Vector2i) -> bool:
	return found_settlement(cell, SettlementCatalogScript.TYPE_OUTPOST)


func _find_outpost_merge_target(outpost_index: int) -> int:
	if outpost_index < 0 or outpost_index >= outposts.size():
		return -1
	var outpost_cell := WorldGeneratorScript.array_to_cell(outposts[outpost_index].get("cell", []), Vector2i(9999, 9999))
	var best_index := -1
	var best_distance := SettlementCatalogScript.OUTPOST_MERGE_MAX_DISTANCE + 1
	for city_index in range(cities.size()):
		var city_cell_value := WorldGeneratorScript.array_to_cell(cities[city_index].get("cell", []), Vector2i(9999, 9999))
		var distance := WorldGeneratorScript.hex_distance(outpost_cell, city_cell_value)
		if distance < best_distance:
			best_distance = distance
			best_index = city_index
	return best_index if best_distance <= SettlementCatalogScript.OUTPOST_MERGE_MAX_DISTANCE else -1


func _get_outpost_transfer_improvements(outpost: Dictionary, target_city: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var existing_cells: Dictionary = {}
	for improvement in target_city.get("province_improvements", []):
		var cell := WorldGeneratorScript.array_to_cell(improvement.get("cell", []), Vector2i(9999, 9999))
		existing_cells["%d:%d" % [cell.x, cell.y]] = true
	for improvement in outpost.get("province_improvements", []):
		if not improvement is Dictionary:
			continue
		var cell := WorldGeneratorScript.array_to_cell(improvement.get("cell", []), Vector2i(9999, 9999))
		var key := "%d:%d" % [cell.x, cell.y]
		if existing_cells.has(key):
			continue
		result.append(improvement.duplicate(true))
		existing_cells[key] = true
	return result


func _city_province_slot_capacity(city: Dictionary) -> int:
	var level := CityDevelopmentCatalogScript.get_city_level(clampi(int(city.get("population", 2)), 1, 20))
	var faction_effects := FactionCatalogScript.get_effects(player_faction)
	return mini(SettlementCatalogScript.MAX_CITY_PROVINCE_SLOTS, CityDevelopmentCatalogScript.get_province_slots(level) + int(faction_effects.get("province_slot_bonus", 0)))


func can_annex_outpost(outpost_index: int, mode: String = "merge") -> bool:
	if campaign_lost or battle_in_progress or outpost_index < 0 or outpost_index >= outposts.size():
		return false
	if mode != "merge" and mode != "upgrade":
		return false
	var outpost: Dictionary = outposts[outpost_index]
	var payer_index := _find_nearest_player_city_index(WorldGeneratorScript.array_to_cell(outpost.get("cell", [])))
	if payer_index < 0:
		return false
	var payer := _get_city_resource_balance(payer_index)
	var gold_cost := SettlementCatalogScript.ANNEX_MERGE_GOLD_COST if mode == "merge" else SettlementCatalogScript.ANNEX_UPGRADE_GOLD_COST
	var production_cost := SettlementCatalogScript.ANNEX_MERGE_PRODUCTION_COST if mode == "merge" else SettlementCatalogScript.ANNEX_UPGRADE_PRODUCTION_COST
	if int(payer.get("gold", 0)) < gold_cost or int(payer.get("production", 0)) < production_cost:
		return false
	if mode == "merge":
		var target_index := _find_outpost_merge_target(outpost_index)
		if target_index < 0:
			return false
		var target_city: Dictionary = cities[target_index]
		var improvements := _get_outpost_transfer_improvements(outpost, target_city)
		var queued_slots := 0
		for order in target_city.get("build_queue", []):
			if str(order.get("kind", "")) == "province_improvement":
				queued_slots += 1
		return target_city.get("province_improvements", []).size() + queued_slots + improvements.size() <= _city_province_slot_capacity(target_city)
	# Преобразование заставы в город требует соблюдения городской дистанции.
	var outpost_cell := WorldGeneratorScript.array_to_cell(outpost.get("cell", []), Vector2i(9999, 9999))
	if cities.size() >= SettlementCatalogScript.MAX_PLAYER_SETTLEMENTS:
		return false
	var territory_owner := get_world_owner_at(outpost_cell)
	if territory_owner == TerritoryCatalogScript.OWNER_DISPUTED or territory_owner >= 0:
		return false
	for city in cities:
		var other_city_cell := WorldGeneratorScript.array_to_cell(city.get("cell", []), Vector2i(9999, 9999))
		if WorldGeneratorScript.hex_distance(outpost_cell, other_city_cell) < SettlementCatalogScript.CITY_MIN_CITY_DISTANCE:
			return false
	for other_index in range(outposts.size()):
		if other_index == outpost_index:
			continue
		var other_outpost_cell := WorldGeneratorScript.array_to_cell(outposts[other_index].get("cell", []), Vector2i(9999, 9999))
		if WorldGeneratorScript.hex_distance(outpost_cell, other_outpost_cell) < SettlementCatalogScript.CITY_MIN_OUTPOST_DISTANCE:
			return false
	var outpost_improvements_value: Variant = outpost.get("province_improvements", [])
	var outpost_improvements: Array = outpost_improvements_value if outpost_improvements_value is Array else []
	var new_city_record := _make_city_record(cities.size(), str(outpost.get("name", "Новый город")), outpost_cell, 2, 0, 0, 0, [], [], "", {}, outpost_improvements)
	if outpost_improvements.size() > _city_province_slot_capacity(new_city_record):
		return false
	for kingdom in kingdoms:
		for ai_city in kingdom.get("cities", []):
			var ai_city_cell := WorldGeneratorScript.array_to_cell(ai_city.get("cell", []), Vector2i(9999, 9999))
			if WorldGeneratorScript.hex_distance(outpost_cell, ai_city_cell) < SettlementCatalogScript.CITY_MIN_CITY_DISTANCE:
				return false
		for ai_outpost in kingdom.get("outposts", []):
			var ai_outpost_cell := WorldGeneratorScript.array_to_cell(ai_outpost.get("cell", []), Vector2i(9999, 9999))
			if WorldGeneratorScript.hex_distance(outpost_cell, ai_outpost_cell) < SettlementCatalogScript.CITY_MIN_OUTPOST_DISTANCE:
				return false
	return true


func annex_outpost(outpost_index: int, mode: String = "merge") -> bool:
	if not can_annex_outpost(outpost_index, mode):
		return false
	_save_active_city()
	var outpost: Dictionary = outposts[outpost_index].duplicate(true)
	var outpost_cell := WorldGeneratorScript.array_to_cell(outpost.get("cell", []), Vector2i(9999, 9999))
	var payer_index := _find_nearest_player_city_index(outpost_cell)
	var gold_cost := SettlementCatalogScript.ANNEX_MERGE_GOLD_COST if mode == "merge" else SettlementCatalogScript.ANNEX_UPGRADE_GOLD_COST
	var production_cost := SettlementCatalogScript.ANNEX_MERGE_PRODUCTION_COST if mode == "merge" else SettlementCatalogScript.ANNEX_UPGRADE_PRODUCTION_COST
	if not _spend_city_resources(payer_index, gold_cost, production_cost):
		return false
	if mode == "merge":
		var target_index := _find_outpost_merge_target(outpost_index)
		var target_city: Dictionary = cities[target_index].duplicate(true)
		var improvements := _get_outpost_transfer_improvements(outpost, target_city)
		var city_improvements: Array = target_city.get("province_improvements", []).duplicate(true)
		for improvement in improvements:
			city_improvements.append(improvement.duplicate(true))
		target_city["province_improvements"] = CityDevelopmentCatalogScript.normalize_province_improvements(city_improvements)
		target_city["food"] = maxi(0, int(target_city.get("food", 0)) + int(outpost.get("food", 0)))
		target_city["gold"] = maxi(0, int(target_city.get("gold", 0)) + int(outpost.get("gold", 0)))
		target_city["production_bank"] = maxi(0, int(target_city.get("production_bank", 0)) + int(outpost.get("production_bank", 0)))
		target_city["last_event"] = "Застава «%s» присоединена. Ресурсы и улучшения переданы городу." % str(outpost.get("name", "Застава"))
		cities[target_index] = target_city
		outposts.remove_at(outpost_index)
		for index in range(outposts.size()):
			outposts[index]["id"] = index
		if target_index == active_city_id:
			_load_active_city()
			city_last_event = str(target_city.get("last_event", "Застава присоединена."))
	else:
		var upgraded_city := _make_city_record(
			cities.size(), str(outpost.get("name", "Новый город")), outpost_cell, 2,
			int(outpost.get("food", 0)), maxi(0, int(outpost.get("gold", 0))),
			maxi(0, int(outpost.get("production_bank", 0))), [], [], "", {}, outpost.get("province_improvements", [])
		)
		upgraded_city["last_event"] = "Застава преобразована в полноценный город."
		cities.append(upgraded_city)
		outposts.remove_at(outpost_index)
		for index in range(outposts.size()):
			outposts[index]["id"] = index
		active_city_id = cities.size() - 1
		_load_active_city()
		city_last_event = "Застава преобразована в город: %s." % str(upgraded_city.get("name", "Город"))
	save_campaign()
	return true


func can_collect_outpost_income(outpost_index: int) -> bool:
	if outpost_index < 0 or outpost_index >= outposts.size() or cities.is_empty():
		return false
	var outpost: Dictionary = outposts[outpost_index]
	return int(outpost.get("food", 0)) > 0 or int(outpost.get("gold", 0)) > 0 or int(outpost.get("production_bank", 0)) > 0


func collect_outpost_income(outpost_index: int) -> bool:
	if not can_collect_outpost_income(outpost_index):
		return false
	_save_active_city()
	var outpost: Dictionary = outposts[outpost_index].duplicate(true)
	var outpost_cell := WorldGeneratorScript.array_to_cell(outpost.get("cell", []), Vector2i(9999, 9999))
	var target_index := _find_nearest_player_city_index(outpost_cell)
	if target_index < 0 or target_index >= cities.size():
		return false
	var target_city: Dictionary = cities[target_index].duplicate(true)
	var food_amount := maxi(0, int(outpost.get("food", 0)))
	var gold_amount := maxi(0, int(outpost.get("gold", 0)))
	var production_amount := maxi(0, int(outpost.get("production_bank", 0)))
	if food_amount + gold_amount + production_amount <= 0:
		return false
	target_city["food"] = maxi(0, int(target_city.get("food", 0))) + food_amount
	target_city["gold"] = maxi(0, int(target_city.get("gold", 0))) + gold_amount
	target_city["production_bank"] = maxi(0, int(target_city.get("production_bank", 0))) + production_amount
	target_city["last_event"] = "Собраны запасы заставы «%s»: +%d еды, +%d золота, +%d производства." % [str(outpost.get("name", "Застава")), food_amount, gold_amount, production_amount]
	cities[target_index] = target_city
	outpost["food"] = 0
	outpost["gold"] = 0
	outpost["production_bank"] = 0
	outpost["last_event"] = "Запасы переданы ближайшему городу."
	outposts[outpost_index] = outpost
	if target_index == active_city_id:
		_load_active_city()
		city_last_event = str(target_city.get("last_event", "Запасы заставы собраны."))
	save_campaign()
	return true


func _pay_gold_from_city_treasuries(amount: int, preferred_city_index: int = -1) -> int:
	var remaining := maxi(0, amount)
	if remaining <= 0 or cities.is_empty():
		return 0
	var order: Array[int] = []
	if preferred_city_index >= 0 and preferred_city_index < cities.size():
		order.append(preferred_city_index)
	for index in range(cities.size()):
		if index != preferred_city_index:
			order.append(index)
	for city_index in order:
		if remaining <= 0:
			break
		var city: Dictionary = cities[city_index]
		var available := maxi(0, int(city.get("gold", 0)))
		var payment := mini(available, remaining)
		city["gold"] = available - payment
		remaining -= payment
		cities[city_index] = city
	return amount - remaining


func get_settlement_upkeep_per_turn() -> int:
	return int(SettlementCatalogScript.get_upkeep(cities.size(), outposts.size()).get("total", 0))


func get_settlement_upkeep_summary() -> String:
	var due := get_settlement_upkeep_per_turn()
	return "Содержание поселений: −%d зол./ход" % due


func _advance_one_outpost_turn() -> void:
	for index in range(outposts.size()):
		var outpost: Dictionary = outposts[index]
		var improvements_value: Variant = outpost.get("province_improvements", [])
		var improvements: Array = improvements_value if improvements_value is Array else []
		var income := SettlementCatalogScript.get_outpost_income(improvements)
		outpost["food"] = maxi(0, int(outpost.get("food", 0)) + int(income.get("food", 0)))
		outpost["gold"] = maxi(0, int(outpost.get("gold", 0)) + int(income.get("gold", 0)))
		outpost["production_bank"] = maxi(0, int(outpost.get("production_bank", 0)) + int(income.get("production", 0)))
		outposts[index] = outpost


func _charge_settlement_upkeep() -> void:
	var upkeep := SettlementCatalogScript.get_upkeep(cities.size(), outposts.size())
	settlement_upkeep_last_due = int(upkeep.get("total", 0))
	settlement_upkeep_last_paid = 0

	var city_upkeep_left := int(upkeep.get("cities", 0))
	for city_index in range(SettlementCatalogScript.SOFT_CITY_LIMIT, cities.size()):
		if city_upkeep_left <= 0:
			break
		var city: Dictionary = cities[city_index]
		var available := maxi(0, int(city.get("gold", 0)))
		var payment := mini(available, SettlementCatalogScript.CITY_UPKEEP_PER_TURN_ABOVE_SOFT_LIMIT)
		city["gold"] = available - payment
		city_upkeep_left -= payment
		settlement_upkeep_last_paid += payment
		cities[city_index] = city
	if city_upkeep_left > 0:
		settlement_upkeep_last_paid += _pay_gold_from_city_treasuries(city_upkeep_left, 0)

	var outpost_upkeep_left := int(upkeep.get("outposts", 0))
	for outpost_index in range(outposts.size()):
		if outpost_upkeep_left <= 0:
			break
		var outpost: Dictionary = outposts[outpost_index]
		var available_gold := maxi(0, int(outpost.get("gold", 0)))
		var payment := mini(available_gold, SettlementCatalogScript.OUTPOST_UPKEEP_PER_TURN)
		outpost["gold"] = available_gold - payment
		settlement_upkeep_last_paid += payment
		outpost_upkeep_left -= payment
		outposts[outpost_index] = outpost
		if payment < SettlementCatalogScript.OUTPOST_UPKEEP_PER_TURN:
			var shortfall := SettlementCatalogScript.OUTPOST_UPKEEP_PER_TURN - payment
			var outpost_cell := WorldGeneratorScript.array_to_cell(outpost.get("cell", []), Vector2i(9999, 9999))
			var sponsor_index := _find_nearest_player_city_index(outpost_cell)
			var sponsored_payment := _pay_gold_from_city_treasuries(shortfall, sponsor_index)
			settlement_upkeep_last_paid += sponsored_payment
	if active_city_id >= 0 and active_city_id < cities.size():
		_load_active_city()


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
	_sync_selected_player_army_from_legacy()
	var total_upkeep := 0.0
	if player_armies.is_empty():
		for unit in player_units:
			var role_id := str(unit.get("role", ROLE_MELEE))
			var unit_data := UNIT_CATALOG_SCRIPT.get_data(role_id)
			total_upkeep += float(unit_data.get("upkeep", 0.0)) * FactionCatalogScript.get_upkeep_multiplier(role_id, player_faction)
	else:
		for army in player_armies:
			var units_value: Variant = army.get("units", [])
			if not units_value is Array:
				continue
			for unit_value in units_value:
				if not unit_value is Dictionary:
					continue
				var role_id := str(unit_value.get("role", ROLE_MELEE))
				var unit_data := UNIT_CATALOG_SCRIPT.get_data(role_id)
				total_upkeep += float(unit_data.get("upkeep", 0.0)) * FactionCatalogScript.get_upkeep_multiplier(role_id, player_faction)
	return ceili(total_upkeep)


func get_army_upkeep_summary() -> String:
	var due := get_army_upkeep_per_turn()
	if army_upkeep_last_due <= 0:
		return "Содержание армии: −%d зол./ход" % due
	return "Содержание армии: −%d зол./ход · оплачено %d/%d" % [due, army_upkeep_last_paid, army_upkeep_last_due]


func get_economy_snapshot() -> Dictionary:
	var treasury_gold := 0
	var treasury_food := 0
	var treasury_production := 0
	var income_food := 0
	var income_gold := 0
	var income_production := 0
	var low_treasury_cities := 0
	var poor_outposts := 0
	for city_value in cities:
		if not city_value is Dictionary:
			continue
		var city: Dictionary = city_value
		var buildings_value: Variant = city.get("buildings", [])
		var buildings: Array = buildings_value if buildings_value is Array else []
		var levels_value: Variant = city.get("building_levels", {})
		var levels: Dictionary = levels_value if levels_value is Dictionary else {}
		var improvements_value: Variant = city.get("province_improvements", [])
		var improvements: Array = improvements_value if improvements_value is Array else []
		var base_income := CityDevelopmentCatalogScript.get_city_income(buildings, levels, improvements, str(city.get("specialization", "")))
		var city_income := FactionCatalogScript.apply_income_modifiers(base_income, buildings, player_faction)
		treasury_gold += maxi(0, int(city.get("gold", 0)))
		treasury_food += maxi(0, int(city.get("food", 0)))
		treasury_production += maxi(0, int(city.get("production_bank", 0)))
		income_food += int(city_income.get("food", 0))
		income_gold += int(city_income.get("gold", 0))
		income_production += int(city_income.get("production", 0))
		if int(city.get("gold", 0)) < 5:
			low_treasury_cities += 1
	for outpost_value in outposts:
		if not outpost_value is Dictionary:
			continue
		var outpost: Dictionary = outpost_value
		var outpost_improvements_value: Variant = outpost.get("province_improvements", [])
		var outpost_improvements: Array = outpost_improvements_value if outpost_improvements_value is Array else []
		var outpost_income := SettlementCatalogScript.get_outpost_income(outpost_improvements)
		treasury_gold += maxi(0, int(outpost.get("gold", 0)))
		treasury_food += maxi(0, int(outpost.get("food", 0)))
		treasury_production += maxi(0, int(outpost.get("production_bank", 0)))
		income_food += int(outpost_income.get("food", 0))
		income_gold += int(outpost_income.get("gold", 0))
		income_production += int(outpost_income.get("production", 0))
		if int(outpost.get("gold", 0)) < SettlementCatalogScript.OUTPOST_UPKEEP_PER_TURN:
			poor_outposts += 1
	var army_upkeep := get_army_upkeep_per_turn()
	var settlement_upkeep := get_settlement_upkeep_per_turn()
	var net_gold := income_gold - army_upkeep - settlement_upkeep
	return {
		"city_count": cities.size(),
		"outpost_count": outposts.size(),
		"settlement_count": cities.size() + outposts.size(),
		"gold": treasury_gold,
		"food": treasury_food,
		"production": treasury_production,
		"income_gold": income_gold,
		"income_food": income_food,
		"income_production": income_production,
		"army_upkeep": army_upkeep,
		"settlement_upkeep": settlement_upkeep,
		"net_gold_per_turn": net_gold,
		"low_treasury_cities": low_treasury_cities,
		"poor_outposts": poor_outposts,
		"cash_pressure": net_gold < 0 or low_treasury_cities > 0 or poor_outposts > 0,
	}


func get_economy_summary() -> String:
	var economy := get_economy_snapshot()
	var net_gold := int(economy.get("net_gold_per_turn", 0))
	var net_label := "+%d" % net_gold if net_gold >= 0 else "−%d" % absi(net_gold)
	return "Чистый баланс: %s зол./ход · поселений: %d · застав: %d" % [net_label, int(economy.get("settlement_count", 0)), int(economy.get("outpost_count", 0))]


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
	_sync_selected_player_army_from_legacy()
	if _count_queued_recruits(selected_player_army_id) + player_units.size() >= ARMY_CAPACITY:
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
		"army_id": selected_player_army_id,
	})
	city_last_event = "%s добавлен в очередь найма выбранной армии." % recruit_name
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
	_sync_selected_player_army_from_legacy()
	turn_number += 1
	_recover_campaign_heroes()
	for army_index in range(player_armies.size()):
		var army_record: Dictionary = player_armies[army_index]
		army_record["moves_left"] = 1
		player_armies[army_index] = army_record
	_load_selected_player_army_to_legacy()
	settler_moves_left = 1
	var previous_city_id := active_city_id
	_save_active_city()
	for i in range(cities.size()):
		active_city_id = i
		_load_active_city()
		city_last_event = ""
		_advance_one_city_turn()
		_save_active_city()
	_advance_one_outpost_turn()
	_apply_neutral_mine_income()
	_charge_settlement_upkeep()
	_charge_army_upkeep()
	active_city_id = previous_city_id
	_load_active_city()
	var player_city_cells: Array[Vector2i] = []
	for city_record in cities:
		player_city_cells.append(WorldGeneratorScript.array_to_cell(city_record.get("cell", [])))
	var player_outpost_cells: Array[Vector2i] = []
	for outpost_record in outposts:
		player_outpost_cells.append(WorldGeneratorScript.array_to_cell(outpost_record.get("cell", [])))
	var neutral_location_cells: Array[Vector2i] = []
	for location in neutral_locations:
		neutral_location_cells.append(WorldGeneratorScript.array_to_cell(location.get("cell", [])))
	var diplomacy_result := DiplomacyCatalogScript.process_turn(
		diplomacy_relations,
		kingdoms,
		turn_number,
		world_seed,
		get_player_army_total_power(),
		pending_diplomacy_offers,
		_get_player_diplomacy_sources(),
		player_diplomacy_profile
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
		diplomacy_relations,
		neutral_locations,
		player_outpost_cells
	)
	_apply_diplomacy_economy()
	_sync_primary_kingdom()
	refresh_fog_of_war()
	_queue_world_event_if_due()


func _get_player_diplomacy_sources() -> Array[Vector2i]:
	_sync_selected_player_army_from_legacy()
	var sources: Array[Vector2i] = []
	for army in player_armies:
		var army_cell := WorldGeneratorScript.array_to_cell(army.get("cell", []), Vector2i(9999, 9999))
		if WorldGeneratorScript.is_inside_world(army_cell) and not sources.has(army_cell):
			sources.append(army_cell)
	if sources.is_empty():
		sources.append(player_cell)
	for city_record in cities:
		var city_cell_value := WorldGeneratorScript.array_to_cell(city_record.get("cell", []))
		if WorldGeneratorScript.is_inside_world(city_cell_value) and not sources.has(city_cell_value):
			sources.append(city_cell_value)
	for outpost_record in outposts:
		var outpost_cell_value := WorldGeneratorScript.array_to_cell(outpost_record.get("cell", []))
		if WorldGeneratorScript.is_inside_world(outpost_cell_value) and not sources.has(outpost_cell_value):
			sources.append(outpost_cell_value)
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
	var player_claims := DiplomacyCatalogScript.get_active_casus_belli(record, turn_number, DiplomacyCatalogScript.PLAYER_ID)
	var rival_claims := DiplomacyCatalogScript.get_active_casus_belli(record, turn_number, kingdom_id)
	var available := true
	var reason := ""
	match action_id:
		"declare_war":
			available = treaty != "war" and turn_number >= int(record.get("truce_until", 0)) and treaty != "vassal"
			if treaty == "vassal":
				reason = "Вассал защищён договором. Сначала договор должен закончиться."
			elif turn_number < int(record.get("truce_until", 0)):
				reason = "Перемирие действует ещё %d ход(а)." % (int(record.get("truce_until", 0)) - turn_number)
			elif not player_claims.is_empty():
				reason = "Есть действующий повод для войны: %s. Дипломатический штраф будет меньше." % str(player_claims[0].get("cause", "территориальная претензия"))
			elif not rival_claims.is_empty():
				reason = "Соперник уже выдвинул претензию против твоей державы: %s." % str(rival_claims[0].get("cause", "территориальный спор"))
			else:
				reason = "Формального повода нет. Объявление войны ухудшит отношение на 35 пунктов."
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
		var target_profile_value: Variant = kingdoms[kingdom_id].get("diplomacy_profile", {})
		var target_profile: Dictionary = target_profile_value if target_profile_value is Dictionary else {}
		chance = DiplomacyCatalogScript.acceptance_chance(
			action_id,
			record,
			kingdom_id,
			player_power,
			target_power,
			target_profile
		)
	return {"available": available, "reason": reason, "chance": chance, "relation": relation, "treaty": treaty}


func perform_diplomacy_action(action_id: String, kingdom_id: int) -> Dictionary:
	if campaign_lost or battle_in_progress or faction_setup_pending:
		return {"ok": false, "message": "Дипломатия сейчас недоступна."}
	var preview := get_diplomacy_action_preview(kingdom_id, action_id)
	if not bool(preview.get("available", false)):
		return {"ok": false, "message": str(preview.get("reason", "Действие недоступно."))}
	var kingdom_name := str(kingdoms[kingdom_id].get("name", "Королевство"))
	if action_id == "declare_war":
		var player_claims := DiplomacyCatalogScript.get_active_casus_belli(get_diplomacy_record(kingdom_id), turn_number, DiplomacyCatalogScript.PLAYER_ID)
		DiplomacyCatalogScript.set_treaty(diplomacy_relations, -1, kingdom_id, "war", turn_number)
		var declared_record := DiplomacyCatalogScript.get_record(diplomacy_relations, -1, kingdom_id)
		var war_reason := str(player_claims[0].get("cause", "border_encroachment")) if not player_claims.is_empty() else "player_declaration"
		declared_record["war_reason"] = war_reason
		declared_record["war_initiator_id"] = DiplomacyCatalogScript.PLAYER_ID
		declared_record["war_target_id"] = kingdom_id
		DiplomacyCatalogScript.set_record(diplomacy_relations, -1, kingdom_id, declared_record)
		if not player_claims.is_empty():
			DiplomacyCatalogScript.consume_casus_belli(diplomacy_relations, -1, kingdom_id, turn_number)
		var relation_penalty := -18 if not player_claims.is_empty() else -35
		DiplomacyCatalogScript.change_relation(diplomacy_relations, -1, kingdom_id, relation_penalty, turn_number)
		var reason_text := " по обоснованной претензии" if not player_claims.is_empty() else " без формального повода"
		var message := "Ты объявил войну державе «%s»%s." % [kingdom_name, reason_text]
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
		if action_id == "call_to_war":
			var enemy_id := int(offer.get("enemy_kingdom_id", -1))
			var caller_record := DiplomacyCatalogScript.get_record(diplomacy_relations, DiplomacyCatalogScript.PLAYER_ID, kingdom_id)
			var enemy_record := DiplomacyCatalogScript.get_record(diplomacy_relations, kingdom_id, enemy_id) if enemy_id >= 0 and enemy_id < kingdoms.size() else {}
			var call_is_valid := enemy_id >= 0 and enemy_id < kingdoms.size() and enemy_id != kingdom_id
			call_is_valid = call_is_valid and str(caller_record.get("treaty", "peace")) == "alliance" and DiplomacyCatalogScript.treaty_is_active(caller_record, turn_number)
			call_is_valid = call_is_valid and str(enemy_record.get("treaty", "peace")) == "war"
			call_is_valid = call_is_valid and bool(kingdoms[enemy_id].get("alive", true))
			call_is_valid = call_is_valid and str(DiplomacyCatalogScript.get_record(diplomacy_relations, DiplomacyCatalogScript.PLAYER_ID, enemy_id).get("treaty", "peace")) != "war"
			var expired_call := turn_number > int(offer.get("expires_turn", 0))
			if expired_call:
				DiplomacyCatalogScript._apply_war_call_refusal(diplomacy_relations, kingdom_id, turn_number)
				pending_diplomacy_offers.remove_at(offer_index)
				_record_diplomacy_event("Срок ответа на призыв державы «%s» истёк. Это сочтено отказом." % str(kingdoms[kingdom_id].get("name", "Держава")))
				save_campaign()
				return {"ok": true, "message": "Срок ответа истёк. Отношение союзника ухудшилось."}
			if not call_is_valid:
				pending_diplomacy_offers.remove_at(offer_index)
				save_campaign()
				return {"ok": false, "message": "Призыв больше недействителен: союз или война уже завершились."}
			var enemy_name := str(kingdoms[enemy_id].get("name", "Держава"))
			var response_message := ""
			if accept:
				DiplomacyCatalogScript.set_treaty(diplomacy_relations, DiplomacyCatalogScript.PLAYER_ID, enemy_id, "war", turn_number)
				var joined_record := DiplomacyCatalogScript.get_record(diplomacy_relations, DiplomacyCatalogScript.PLAYER_ID, enemy_id)
				joined_record["war_reason"] = "ally_call"
				var original_initiator := int(enemy_record.get("war_initiator_id", kingdom_id))
				joined_record["war_initiator_id"] = original_initiator
				joined_record["war_target_id"] = int(enemy_record.get("war_target_id", enemy_id))
				DiplomacyCatalogScript.set_record(diplomacy_relations, DiplomacyCatalogScript.PLAYER_ID, enemy_id, joined_record)
				DiplomacyCatalogScript.change_relation(diplomacy_relations, DiplomacyCatalogScript.PLAYER_ID, enemy_id, -8, turn_number)
				DiplomacyCatalogScript.change_relation(diplomacy_relations, DiplomacyCatalogScript.PLAYER_ID, kingdom_id, 5, turn_number)
				response_message = "Ты откликнулся на призыв «%s» и вступил в войну против «%s»." % [str(kingdoms[kingdom_id].get("name", "Держава")), enemy_name]
			else:
				DiplomacyCatalogScript._apply_war_call_refusal(diplomacy_relations, kingdom_id, turn_number)
				response_message = "Ты отказался поддержать «%s». Отношение союзника ухудшилось на %d пунктов." % [str(kingdoms[kingdom_id].get("name", "Держава")), DiplomacyCatalogScript.WAR_CALL_REFUSAL_PENALTY]
			pending_diplomacy_offers.remove_at(offer_index)
			_record_diplomacy_event(response_message)
			save_campaign()
			return {"ok": true, "message": response_message}
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
	if cities.is_empty() and outposts.is_empty():
		return
	for location in neutral_locations:
		if not bool(location.get("cleared", false)) or int(location.get("cleared_by", -1)) != -1 or str(location.get("type", "")) != "abandoned_mine":
			continue
		var location_cell := WorldGeneratorScript.array_to_cell(location.get("cell", []))
		var nearest_city_index := -1
		var nearest_distance := 999999
		for city_index in range(cities.size()):
			var city_cell := WorldGeneratorScript.array_to_cell(cities[city_index].get("cell", []))
			var city_distance := WorldGeneratorScript.hex_distance(location_cell, city_cell)
			if city_distance < nearest_distance:
				nearest_distance = city_distance
				nearest_city_index = city_index
		var nearest_outpost_index := -1
		for outpost_index in range(outposts.size()):
			var outpost_cell := WorldGeneratorScript.array_to_cell(outposts[outpost_index].get("cell", []))
			var outpost_distance := WorldGeneratorScript.hex_distance(location_cell, outpost_cell)
			if outpost_distance < nearest_distance:
				nearest_distance = outpost_distance
				nearest_outpost_index = outpost_index
				nearest_city_index = -1
		if nearest_outpost_index >= 0:
			var target_outpost: Dictionary = outposts[nearest_outpost_index]
			target_outpost["production_bank"] = maxi(0, int(target_outpost.get("production_bank", 0))) + 2
			outposts[nearest_outpost_index] = target_outpost
		elif nearest_city_index >= 0:
			var target_city: Dictionary = cities[nearest_city_index]
			target_city["production_bank"] = maxi(0, int(target_city.get("production_bank", 0))) + 2
			cities[nearest_city_index] = target_city


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
			reveal_origin = _find_scout_reveal_origin(player_cell, reveal_distance, reveal_radius)
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
	_sync_selected_player_army_from_legacy()
	var faction_effects := FactionCatalogScript.get_effects(player_faction)
	var army_vision := clampi(ARMY_VISION_RADIUS + int(faction_effects.get("army_vision_bonus", 0)), ARMY_VISION_RADIUS, 12)
	var armies_with_units := 0
	for army in player_armies:
		var units_value: Variant = army.get("units", [])
		var army_cell := WorldGeneratorScript.array_to_cell(army.get("cell", []), Vector2i(9999, 9999))
		if units_value is Array and not units_value.is_empty() and WorldGeneratorScript.is_inside_world(army_cell):
			_reveal_fog_area(army_cell, army_vision)
			armies_with_units += 1
	if armies_with_units == 0:
		_reveal_fog_area(city_cell, CITY_VISION_RADIUS)
	for city_record in cities:
		var cell := WorldGeneratorScript.array_to_cell(city_record.get("cell", []))
		_reveal_fog_area(cell, CITY_VISION_RADIUS)
	for outpost in outposts:
		var cell := WorldGeneratorScript.array_to_cell(outpost.get("cell", []), Vector2i(9999, 9999))
		_reveal_fog_area(cell, SettlementCatalogScript.OUTPOST_VISION_RADIUS)
	if settler_active:
		_reveal_fog_area(settler_cell, SETTLER_VISION_RADIUS)


func _find_scout_reveal_origin(origin: Vector2i, distance: int, radius: int) -> Vector2i:
	var directions := WorldGeneratorScript.neighbors()
	if directions.is_empty():
		return origin
	var start_index := posmod(world_seed + turn_number, directions.size())
	var best_cell := origin
	var best_unexplored_count := -1
	for step in range(directions.size()):
		var direction_index := posmod(start_index + step, directions.size())
		var candidate := origin + directions[direction_index] * distance
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




func get_player_army_total_power() -> float:
	_sync_selected_player_army_from_legacy()
	var total_power := 0.0
	for army_record in player_armies:
		total_power += _get_army_power(army_record.get("units", []))
	return total_power

func get_total_enemy_units() -> int:
	var total := 0
	for kingdom in kingdoms:
		total += kingdom.get("army", []).size()
	return total


func get_world_owner_at(cell: Vector2i) -> int:
	_sync_selected_player_army_from_legacy()
	return TerritoryCatalogScript.get_owner_at(cell, cities, player_cell, player_units, kingdoms, player_armies, outposts)


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
		if not WorldGeneratorScript.is_inside_world(candidate) or WorldGeneratorScript.terrain_at(candidate, world_seed, world_generation_version) == "water" or get_city_index_at(candidate) >= 0 or get_outpost_index_at(candidate) >= 0:
			continue
		if WorldLocationCatalogScript.has_location_at(neutral_locations, candidate):
			continue
		if candidate == player_cell or candidate == enemy_cell or not get_player_army_at(candidate).is_empty():
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
			var target_army_id := str(order.get("army_id", PRIMARY_PLAYER_ARMY_ID))
			var target_army_index := _get_player_army_index(target_army_id)
			if target_army_index >= 0 and UNIT_CATALOG_SCRIPT.is_valid_role(order_id):
				var target_army: Dictionary = player_armies[target_army_index]
				var target_units := _read_unit_records(target_army.get("units", []))
				if target_units.size() < ARMY_CAPACITY:
					var max_health: float = UNIT_CATALOG_SCRIPT.get_max_health(order_id)
					target_units.append({"role": order_id, "health": max_health, "experience": 0})
					target_army["units"] = target_units
					player_armies[target_army_index] = target_army
					if target_army_id == selected_player_army_id:
						_load_selected_player_army_to_legacy()
					city_last_event += "%s прибыл в армию «%s». " % [order_name, str(target_army.get("name", "Армия"))]
		elif order_kind == "settler" and not settler_active:
			settler_active = true
			settler_cell = _find_settler_spawn_cell(city_cell)
			settler_origin_city_id = clampi(int(order.get("origin_city_id", active_city_id)), 0, maxi(0, cities.size() - 1))
			city_last_event += "Поселенец готов к основанию города или заставы. "

	if city_last_event.is_empty():
		city_last_event = "Город получил ресурсы за ход."

func _count_queued_recruits(army_id: String = "") -> int:
	var target_army_id := army_id if not army_id.is_empty() else selected_player_army_id
	var count := 0
	for i in range(cities.size()):
		var orders: Array = city_build_queue if i == active_city_id else cities[i].get("build_queue", [])
		for order_value in orders:
			if not order_value is Dictionary:
				continue
			var order: Dictionary = order_value
			if str(order.get("kind", "")) != "recruit":
				continue
			var queued_army_id := str(order.get("army_id", PRIMARY_PLAYER_ARMY_ID))
			if queued_army_id == target_army_id:
				count += 1
	return count


func _remove_conflicting_neutral_locations() -> void:
	var occupied: Dictionary = {}
	_sync_selected_player_army_from_legacy()
	for army_record in player_armies:
		var player_army_cell := WorldGeneratorScript.array_to_cell(army_record.get("cell", []))
		occupied["%d:%d" % [player_army_cell.x, player_army_cell.y]] = true
	for city in cities:
		var city_cell_value := WorldGeneratorScript.array_to_cell(city.get("cell", []))
		occupied["%d:%d" % [city_cell_value.x, city_cell_value.y]] = true
	for outpost in outposts:
		var outpost_cell_value := WorldGeneratorScript.array_to_cell(outpost.get("cell", []))
		occupied["%d:%d" % [outpost_cell_value.x, outpost_cell_value.y]] = true
	for kingdom in kingdoms:
		var army_cell_value := WorldGeneratorScript.array_to_cell(kingdom.get("army_cell", []))
		occupied["%d:%d" % [army_cell_value.x, army_cell_value.y]] = true
		for city in kingdom.get("cities", []):
			var city_cell_value := WorldGeneratorScript.array_to_cell(city.get("cell", []))
			occupied["%d:%d" % [city_cell_value.x, city_cell_value.y]] = true
		for outpost in kingdom.get("outposts", []):
			var ai_outpost_cell := WorldGeneratorScript.array_to_cell(outpost.get("cell", []))
			occupied["%d:%d" % [ai_outpost_cell.x, ai_outpost_cell.y]] = true
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
	# Keep the selected army and active commander compatibility fields synchronized.
	_sync_selected_player_army_from_legacy()
	_sync_active_hero_to_roster()
	var primary_army := _get_primary_player_army()
	var primary_cell := WorldGeneratorScript.array_to_cell(primary_army.get("cell", []), player_cell)
	var primary_units := _read_unit_records(primary_army.get("units", []))
	var primary_moves_left := clampi(int(primary_army.get("moves_left", 1)), 0, 1)
	var primary_upgrades := _read_army_upgrades(primary_army.get("upgrades", {}))
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
		"battle_reward_counter": battle_reward_counter,
		"explored_cells": _serialize_explored_cells(),
		"neutral_locations": neutral_locations,
		"pending_world_event": pending_world_event,
		"last_world_event_text": last_world_event_text,
		"world_events_resolved": world_events_resolved,
		"kingdoms": kingdoms,
		"player_diplomacy_profile": player_diplomacy_profile,
		"diplomacy_relations": diplomacy_relations,
		"pending_diplomacy_offers": pending_diplomacy_offers,
		"campaign_lost": campaign_lost,
		"turn_number": turn_number,
		"player_moves_left": primary_moves_left,
		"player_cell": [primary_cell.x, primary_cell.y],
		"enemy_cell": [enemy_cell.x, enemy_cell.y],
		"enemy_present": enemy_present,
		"player_units": primary_units,
		"army_upgrades": primary_upgrades,
		"player_armies": player_armies,
		"selected_player_army_id": selected_player_army_id,
		"army_upkeep_last_due": army_upkeep_last_due,
		"army_upkeep_last_paid": army_upkeep_last_paid,
		"enemy_units": enemy_units,
		"player_hero": player_hero,
		"hero_roster": hero_roster,
		"active_hero_id": active_hero_id,
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
		"outposts": outposts,
		"active_city_id": active_city_id,
		"settler_active": settler_active,
		"settler_cell": [settler_cell.x, settler_cell.y],
		"settler_moves_left": settler_moves_left,
		"settler_origin_city_id": settler_origin_city_id,
		"settlement_upkeep_last_due": settlement_upkeep_last_due,
		"settlement_upkeep_last_paid": settlement_upkeep_last_paid,
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
	var saved_armies_value: Variant = data.get("player_armies", [])
	var has_saved_army_units := false
	if saved_armies_value is Array:
		for saved_army_value in saved_armies_value:
			if saved_army_value is Dictionary and saved_army_value.get("units", []) is Array and not saved_army_value.get("units", []).is_empty():
				has_saved_army_units = true
				break
	if loaded_player.is_empty() and not has_saved_army_units and not lost:
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
	player_hero_fallback["id"] = "hero_ruler"
	player_hero_fallback["kind"] = "ruler"
	var loaded_active_hero := _read_hero_record(
		data.get("player_hero", player_hero_fallback),
		player_hero_fallback
	)
	hero_roster = _read_hero_roster(data.get("hero_roster", []), loaded_active_hero)
	active_hero_id = str(data.get("active_hero_id", loaded_active_hero.get("id", "hero_ruler")))
	player_hero = _get_hero_record(active_hero_id)
	if player_hero.is_empty():
		active_hero_id = str(hero_roster[0].get("id", "hero_ruler"))
		player_hero = hero_roster[0].duplicate(true)
	var legacy_primary_army := {
		"id": PRIMARY_PLAYER_ARMY_ID,
		"name": "Первая армия",
		"cell": [player_cell.x, player_cell.y],
		"units": loaded_player,
		"hero_id": active_hero_id,
		"upgrades": army_upgrades,
		"moves_left": player_moves_left,
	}
	player_armies = _read_player_armies(data.get("player_armies", []), legacy_primary_army)
	selected_player_army_id = str(data.get("selected_player_army_id", PRIMARY_PLAYER_ARMY_ID))
	if _get_player_army_index(selected_player_army_id) < 0:
		selected_player_army_id = PRIMARY_PLAYER_ARMY_ID
	if not _load_selected_player_army_to_legacy():
		selected_player_army_id = str(player_armies[0].get("id", PRIMARY_PLAYER_ARMY_ID))
		_load_selected_player_army_to_legacy()
	player_faction = FactionCatalogScript.normalize_selection(data.get("player_faction", {}))
	faction_setup_pending = false
	var enemy_hero_fallback := _make_hero_record("Варг", "Воевода Красного Отряда")
	enemy_hero = _read_hero_record(data.get("enemy_hero", enemy_hero_fallback), enemy_hero_fallback)
	enemy_present = bool(data.get("enemy_present", true)) and not enemy_units.is_empty()
	world_seed = int(data.get("world_seed", WorldGeneratorScript.DEFAULT_SEED))
	battle_reward_counter = maxi(0, int(data.get("battle_reward_counter", 0)))
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
	var default_kingdoms: Array[Dictionary] = KingdomAIScript.create_initial_kingdoms(world_seed)
	kingdoms.clear()
	var saved_kingdoms: Variant = data.get("kingdoms", [])
	if saved_kingdoms is Array and saved_kingdoms.size() >= KINGDOM_COUNT:
		for index in range(KINGDOM_COUNT):
			var fallback: Dictionary = default_kingdoms[index]
			if saved_kingdoms[index] is Dictionary:
				kingdoms.append(KingdomAIScript.normalize_kingdom(saved_kingdoms[index], fallback, world_seed))
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
	player_diplomacy_profile = DiplomacyCatalogScript.normalize_leader_profile(
		data.get("player_diplomacy_profile", {}),
		DiplomacyCatalogScript.PLAYER_ID,
		player_faction,
		0,
		world_seed
	)
	diplomacy_relations = DiplomacyCatalogScript.normalize_relations(
		data.get("diplomacy_relations", {}),
		kingdoms.size(),
		world_seed,
		kingdoms,
		player_diplomacy_profile
	)
	pending_diplomacy_offers.clear()
	var saved_diplomacy_offers: Variant = data.get("pending_diplomacy_offers", [])
	if saved_diplomacy_offers is Array:
		for offer_value in saved_diplomacy_offers:
			if not offer_value is Dictionary or pending_diplomacy_offers.size() >= DiplomacyCatalogScript.MAX_PENDING_OFFERS:
				continue
			var offer_kingdom_id := int(offer_value.get("kingdom_id", -1))
			var offer_action := str(offer_value.get("action", ""))
			if offer_kingdom_id < 0 or offer_kingdom_id >= kingdoms.size() or not ["offer_trade", "offer_alliance", "offer_peace", "call_to_war"].has(offer_action):
				continue
			if offer_action == "call_to_war":
				var enemy_id := int(offer_value.get("enemy_kingdom_id", -1))
				if enemy_id < 0 or enemy_id >= kingdoms.size() or enemy_id == offer_kingdom_id:
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
	outposts = _read_outposts(data.get("outposts", []))
	active_city_id = clampi(int(data.get("active_city_id", 0)), 0, cities.size() - 1)
	settler_active = bool(data.get("settler_active", false))
	var settler_xy: Variant = data.get("settler_cell", [city_cell.x, city_cell.y + 1])
	if settler_xy is Array and settler_xy.size() >= 2:
		settler_cell = Vector2i(int(settler_xy[0]), int(settler_xy[1]))
	settler_moves_left = clampi(int(data.get("settler_moves_left", 1)), 0, 1)
	settler_origin_city_id = clampi(int(data.get("settler_origin_city_id", active_city_id)), 0, maxi(0, cities.size() - 1)) if settler_active else -1
	settlement_upkeep_last_due = maxi(0, int(data.get("settlement_upkeep_last_due", 0)))
	settlement_upkeep_last_paid = clampi(int(data.get("settlement_upkeep_last_paid", 0)), 0, settlement_upkeep_last_due)
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
		if valid_settler:
			record["origin_city_id"] = maxi(0, int(item.get("origin_city_id", active_city_id)))
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