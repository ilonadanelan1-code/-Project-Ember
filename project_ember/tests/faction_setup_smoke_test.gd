extends SceneTree

const FactionCatalogScript = preload("res://scripts/faction_catalog.gd")
const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const KingdomAIScript = preload("res://scripts/kingdom_ai.gd")

var _checks: int = 0
var _failures: int = 0


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
	_check(FactionCatalogScript.people_ids().size() == 4, "four starter peoples are available")
	_check(FactionCatalogScript.culture_ids().size() == 4, "four starter cultures are available")
	_check(FactionCatalogScript.trait_ids().size() >= 6, "at least six selectable faction traits are available")

	var default_selection := FactionCatalogScript.get_default_selection()
	_check(FactionCatalogScript.is_valid_selection(default_selection), "default faction has one people, one culture and two different traits")
	_check(FactionCatalogScript.normalize_selection(default_selection) == default_selection, "valid faction selection survives normalization")
	var legacy_selection := FactionCatalogScript.normalize_selection({})
	_check(str(legacy_selection.get("people_id", "")) == FactionCatalogScript.LEGACY_ID, "saves without faction data receive a neutral legacy identity")

	var river_selection := {
		"people_id": "riverfolk",
		"culture_id": "agrarian",
		"trait_ids": ["veteran_cadre", "public_granaries"],
		"kingdom_name": "Речная держава",
	}
	var river_effects := FactionCatalogScript.get_effects(river_selection)
	_check(int(river_effects.get("farm_food_bonus", 0)) == 3, "Riverfolk and Agrarian combine their farm bonuses additively")
	_check(int(river_effects.get("starting_food_bonus", 0)) == 12, "Riverfolk starting food bonus is data-driven")
	_check(int(river_effects.get("starting_unit_experience", 0)) == 20, "Veteran Cadre starting unit experience is data-driven")
	var income := FactionCatalogScript.apply_income_modifiers({"food": 7, "gold": 4, "production": 4}, ["farm"], river_selection)
	_check(int(income.get("food", 0)) == 11, "farm income includes people, culture and public granary bonuses")

	var steppe_selection := {
		"people_id": "steppe_clans",
		"culture_id": "warrior",
		"trait_ids": ["disciplined", "guild_charters"],
		"kingdom_name": "Степной союз",
	}
	_check(FactionCatalogScript.get_recruit_multiplier("cavalry", steppe_selection) < FactionCatalogScript.get_recruit_multiplier("melee", steppe_selection), "Steppe Clans provide a focused cavalry recruitment discount")
	_check(FactionCatalogScript.get_upkeep_multiplier("cavalry", steppe_selection) < FactionCatalogScript.get_upkeep_multiplier("melee", steppe_selection), "Steppe Clans provide a focused cavalry upkeep discount")
	_check(FactionCatalogScript.get_recruit_multiplier("cavalry", steppe_selection) >= 0.75, "combined recruitment bonuses respect the 25 percent discount cap")

	var state: Variant = CampaignStateScript.new()
	root.add_child(state)
	state.prepare_new_campaign(true)
	var starting_food := int(state.city_food)
	var starting_xp := int(state.player_units[0].get("experience", 0))
	_check(state.faction_setup_pending, "new campaign waits for faction confirmation")
	_check(state.apply_player_faction(river_selection), "valid faction can be confirmed")
	_check(not state.faction_setup_pending, "faction confirmation releases the campaign setup gate")
	_check(not state.apply_player_faction(river_selection), "starting faction bonuses cannot be applied a second time")
	_check(int(state.city_food) == starting_food + 12, "one-time starting resource bonus is applied exactly once")
	_check(int(state.player_units[0].get("experience", 0)) == starting_xp + 20, "starting unit experience is applied to the initial army")
	_check(state.get_player_faction_summary().contains("Речные люди"), "player faction summary reflects the selected people and culture")

	state.city_buildings.clear()
	state.city_buildings.append("farm")
	state.city_building_levels = {"farm": 1}
	_check(int(state.get_city_income().get("food", 0)) == 11, "campaign city income applies selected faction effects")
	_check(state.get_city_province_slots() == 1, "legacy faction has the original province slot count")
	state.player_faction = FactionCatalogScript.normalize_selection({
		"people_id": "riverfolk", "culture_id": "agrarian",
		"trait_ids": ["provincial_charters", "public_granaries"],
		"kingdom_name": "Речная держава",
	})
	_check(state.get_city_province_slots() == 2, "Provincial Charters add one province slot without a new resource")
	_check(CampaignStateScript.SAVE_VERSION == 1, "optional faction fields do not require a save schema version bump")

	var ai_kingdoms := KingdomAIScript.create_initial_kingdoms()
	var distinct_factions: Dictionary = {}
	var all_ai_valid := ai_kingdoms.size() == CampaignStateScript.KINGDOM_COUNT
	for kingdom in ai_kingdoms:
		var faction_value: Variant = kingdom.get("faction", {})
		var faction_data: Dictionary = faction_value if faction_value is Dictionary else {}
		all_ai_valid = all_ai_valid and FactionCatalogScript.is_valid_selection(faction_data)
		distinct_factions[str(faction_data.get("people_id", "")) + ":" + str(faction_data.get("culture_id", ""))] = true
	_check(all_ai_valid, "all nine AI kingdoms receive valid data-driven faction identities")
	_check(distinct_factions.size() >= 4, "AI kingdoms use multiple people and culture combinations")
	var stoneborn_ai: Dictionary = ai_kingdoms[5]
	var stoneborn_cities: Array = stoneborn_ai.get("cities", [])
	var stoneborn_capital: Dictionary = stoneborn_cities[0] if not stoneborn_cities.is_empty() else {}
	var stoneborn_army: Array = stoneborn_ai.get("army", [])
	var veteran_starting_xp := false
	for ai_unit in stoneborn_army:
		if int(ai_unit.get("experience", 0)) >= 20:
			veteran_starting_xp = true
	_check(int(stoneborn_capital.get("production_bank", 0)) >= 8, "Stoneborn AI capital receives its one-time starting production bonus")
	_check(veteran_starting_xp, "AI kingdoms apply the Veteran Cadre starting experience trait")
	var normalized_ai := KingdomAIScript.normalize_kingdom({"name": "Legacy Realm"}, ai_kingdoms[0])
	_check(FactionCatalogScript.is_valid_selection(normalized_ai.get("faction", {})), "legacy AI kingdom saves inherit a stable fallback faction identity")

	state.free()
	if _failures > 0:
		printerr("Faction setup checks failed: %d/%d" % [_failures, _checks])
		quit(1)
	else:
		print("All %d faction setup checks passed." % _checks)
		quit(0)
