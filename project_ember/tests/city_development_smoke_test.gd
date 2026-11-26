extends SceneTree

const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const CityDevelopmentScript = preload("res://scripts/city_development_catalog.gd")
const UnitCatalogScript = preload("res://scripts/unit_catalog.gd")
const KingdomAIScript = preload("res://scripts/kingdom_ai.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	_check(CityDevelopmentScript.get_city_level(5) == 1, "population five remains a settlement")
	_check(CityDevelopmentScript.get_city_level(8) == 2, "population eight unlocks city level two")
	_check(CityDevelopmentScript.get_city_level(14) == 3, "population fourteen unlocks city level three")
	_check(CityDevelopmentScript.get_province_slots(1) == 1 and CityDevelopmentScript.get_province_slots(2) == 3 and CityDevelopmentScript.get_province_slots(3) == 5, "city levels grant one, three and five province slots")
	_check(CityDevelopmentScript.SPECIALIZATIONS.size() == 4, "four mutually exclusive city specializations exist")
	_check(CityDevelopmentScript.PROVINCE_IMPROVEMENTS.size() == 6, "six data-driven province improvements include the arcane conduit")
	_check(CityDevelopmentScript.BUILDING_UPGRADES.size() == 6, "all six existing buildings have upgrade data")

	var state: Variant = CampaignStateScript.new()
	root.add_child(state)
	state.new_campaign(false)
	_check(state.get_city_level() == 1 and state.get_city_level_name() == "Поселение", "new campaign starts with a settlement")
	_check(not state.can_choose_city_specialization("agriculture"), "specialization remains locked below population eight")
	state.city_population = 8
	state.city_gold = 500
	state.city_buildings.append("farm")
	state.city_building_levels = {"farm": 1}
	_check(state.get_city_level() == 2 and state.get_city_level_name() == "Город", "population upgrade changes the city level label")
	_check(state.choose_city_specialization("agriculture"), "city can choose agriculture at level two")
	_check(not state.choose_city_specialization("commerce"), "city specialization cannot be replaced")
	var level_one_income: Dictionary = state.get_city_income()
	_check(int(level_one_income.get("food", 0)) == 8, "agriculture adds twenty percent to current food income")

	_check(state.can_queue_city_building_upgrade("farm"), "level-two city can queue a farm upgrade")
	_check(state.queue_city_building_upgrade("farm"), "farm upgrade charges gold and enters the production queue")
	state.city_production_bank = 12
	state._process_city_queue()
	_check(state.get_city_building_level("farm") == 2, "completed farm project raises building rank to two")
	var level_two_income: Dictionary = state.get_city_income()
	_check(int(level_two_income.get("food", 0)) == 12, "farm rank two and agriculture specialization combine correctly")

	var province_cell: Vector2i = state.get_next_province_cell("stone_quarry")
	_check(province_cell != Vector2i(9999, 9999), "city finds an eligible adjacent quarry hex")
	_check(state.can_queue_province_improvement("stone_quarry"), "eligible province project can be queued")
	_check(state.queue_province_improvement("stone_quarry"), "province project charges gold and enters the queue")
	state.city_production_bank = 8
	state._process_city_queue()
	_check(state.city_province_improvements.size() == 1, "completed province project is stored in the city record")
	var developed_income: Dictionary = state.get_city_income()
	_check(int(developed_income.get("production", 0)) == 6, "quarry contributes two additional production per turn")
	var normalized_watchtower := CityDevelopmentScript.normalize_province_improvements([{"id": "watchtower", "cell": [-2, 1]}])
	_check(normalized_watchtower.size() == 1 and str(normalized_watchtower[0].get("id", "")) == "watchtower", "watchtower is accepted by province improvement normalization")
	var watchtower_income := CityDevelopmentScript.get_city_income([], {}, normalized_watchtower, "")
	_check(int(watchtower_income.get("production", 0)) == 5, "watchtower adds one production per turn")

	var conduit_data := CityDevelopmentScript.get_improvement_data("arcane_conduit")
	_check(not conduit_data.is_empty() and int(conduit_data.get("gold_cost", 0)) == 50, "arcane conduit has a bounded gold and production cost")
	_check(str(conduit_data.get("description", "")).contains("арканной силы"), "arcane conduit clearly explains its magical victory contribution")
	_check(state.get_next_province_cell("arcane_conduit") != Vector2i(9999, 9999), "city can find an eligible province hex for an arcane conduit")
	_check(state.can_queue_province_improvement("arcane_conduit"), "arcane conduit can be queued through the normal province workflow")
	_check(state.queue_province_improvement("arcane_conduit"), "arcane conduit charges resources and enters the existing production queue")
	state.city_production_bank = 12
	state._process_city_queue()
	var has_arcane_conduit := false
	for improvement in state.city_province_improvements:
		if str(improvement.get("id", "")) == "arcane_conduit":
			has_arcane_conduit = true
	_check(has_arcane_conduit, "completed arcane conduit is stored in the city province record")


	_check(state.get_army_upkeep_per_turn() == 4, "starting army costs four gold per turn")
	var old_gold: int = state.city_gold
	state.advance_campaign_turn()
	_check(state.army_upkeep_last_due == 4 and state.army_upkeep_last_paid == 4, "campaign turn records full army upkeep payment")
	_check(state.city_gold == old_gold + 4 - 4, "city income is collected before army upkeep is charged")

	var legacy_city: Dictionary = state._make_city_record(0, "Legacy", Vector2i(-3, 1), 5, 8, 120, 0, [], [])
	_check(str(legacy_city.get("specialization", "x")).is_empty(), "legacy city records default to no specialization")
	_check(legacy_city.get("building_levels", {}) is Dictionary and legacy_city.get("province_improvements", []) is Array, "legacy city records default building levels and province improvements")
	_check(CampaignStateScript.SAVE_VERSION == 1, "city development does not change the campaign save schema")
	_check(state._read_city_queue([{"kind": "building_upgrade", "id": "farm", "target_level": 2, "production_cost": 12}]).size() == 1, "building upgrades survive queue normalization")
	_check(state._read_city_queue([{"kind": "province_improvement", "id": "farm_plot", "cell": [ -3, 0 ], "production_cost": 6}]).size() == 1, "province improvements survive queue normalization")

	var ai_fallback: Dictionary = KingdomAIScript.create_initial_kingdoms(WorldGeneratorScript.DEFAULT_SEED)[0]
	var ai_legacy: Dictionary = ai_fallback.duplicate(true)
	ai_legacy["cities"] = [{"name": "Старая столица", "cell": ai_legacy.get("capital_cell", [3, 0]), "population": 8, "food": 8, "gold": 100, "buildings": ["farm"]}]
	var normalized_ai: Dictionary = KingdomAIScript.normalize_kingdom(ai_legacy, ai_fallback)
	var normalized_city: Dictionary = normalized_ai.get("cities", [])[0]
	_check(str(normalized_city.get("specialization", "x")).is_empty(), "legacy AI cities default to an unselected specialization")
	_check(int(normalized_city.get("building_levels", {}).get("farm", 0)) == 1, "legacy AI buildings default to level one")
	_check(normalized_city.get("province_improvements", []) is Array, "legacy AI cities receive an empty province list")

	var ai_kingdoms: Array[Dictionary] = KingdomAIScript.create_initial_kingdoms(WorldGeneratorScript.DEFAULT_SEED)
	var no_player_cities: Array[Vector2i] = []
	var ai_events := KingdomAIScript.process_turns(ai_kingdoms, 1, Vector2i.ZERO, no_player_cities, WorldGeneratorScript.DEFAULT_SEED, WorldGeneratorScript.WORLD_GENERATION_VERSION)
	_check(ai_events.size() == 9, "all nine AI kingdoms process a turn with the new city economy")
	for kingdom in ai_kingdoms:
		var city: Dictionary = kingdom.get("cities", [])[0]
		_check(city.has("specialization") and city.has("building_levels") and city.has("province_improvements"), "AI city records retain all city development fields")

	_check(UnitCatalogScript.get_data("melee").has("upkeep") and UnitCatalogScript.get_data("ranged").has("upkeep") and UnitCatalogScript.get_data("spear").has("upkeep") and UnitCatalogScript.get_data("cavalry").has("upkeep"), "all stable unit role IDs define upkeep")
	_check(state.get_army_upkeep_per_turn() >= 0, "army upkeep remains non-negative")
	state._prevent_save_overwrite = false
	_check(state.save_campaign(), "city development and upkeep fields save in the existing campaign format")
	var expected_city_specialization: String = state.city_specialization
	var expected_city_building_level: int = state.get_city_building_level("farm")
	var expected_province_count: int = state.city_province_improvements.size()
	var expected_upkeep_due: int = state.army_upkeep_last_due
	state.city_specialization = ""
	state.city_building_levels.clear()
	state.city_province_improvements.clear()
	state.army_upkeep_last_due = 0
	_check(state.load_campaign(), "campaign with city development fields reloads")
	_check(state.city_specialization == expected_city_specialization, "city specialization survives save and load")
	_check(state.get_city_building_level("farm") == expected_city_building_level, "building upgrade rank survives save and load")
	_check(state.city_province_improvements.size() == expected_province_count, "province improvements survive save and load")
	_check(state.army_upkeep_last_due == expected_upkeep_due, "last upkeep calculation survives save and load")

	if _failures == 0:
		print("All %d passed." % _checks)
	else:
		push_error("%d of %d checks failed." % [_failures, _checks])
	quit(0 if _failures == 0 else 1)
