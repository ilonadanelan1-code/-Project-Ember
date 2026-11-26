extends SceneTree

const Territory = preload("res://scripts/territory_catalog.gd")
const CityDevelopment = preload("res://scripts/city_development_catalog.gd")
const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const SettlementCatalogScript = preload("res://scripts/settlement_catalog.gd")

var _checks := 0
var _failures := 0


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
	var city: Dictionary = {
		"name": "Пограничный оплот",
		"cell": [0, 0],
		"population": 8,
		"specialization": "military",
		"province_improvements": [],
	}
	var player_cities: Array[Dictionary] = [city]
	var no_kingdoms: Array[Dictionary] = []
	var no_army_cell := Vector2i(9999, 9999)
	var no_army: Array[Dictionary] = []
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 0), Vector2i(9, 0), Vector2i(15, 0)]
	var city_lookup := Territory.build_owner_lookup(cells, player_cities, no_army_cell, no_army, no_kingdoms)
	_check(int(city_lookup.get(Vector2i(0, 0), -1)) == Territory.OWNER_PLAYER, "city hex is owned by its kingdom")
	_check(int(city_lookup.get(Vector2i(5, 0), -1)) == Territory.OWNER_PLAYER, "city influence claims land beyond the immediate province ring")
	_check(int(city_lookup.get(Vector2i(9, 0), -1)) == Territory.OWNER_UNCLAIMED, "city influence has a deterministic outer limit")

	city["province_improvements"] = [{"id": "watchtower", "cell": [1, 0]}]
	player_cities[0] = city
	var tower_lookup := Territory.build_owner_lookup(cells, player_cities, no_army_cell, no_army, no_kingdoms)
	_check(int(tower_lookup.get(Vector2i(9, 0), -1)) == Territory.OWNER_PLAYER, "frontier watchtower projects control beyond the city influence radius")
	_check(Territory.get_watchtower_count(city.get("province_improvements", [])) == 1, "watchtower count comes from existing province records")
	_check(is_equal_approx(Territory.get_defensive_armor_bonus(Vector2i(4, 0), player_cities, no_kingdoms), 1.0), "friendly watchtower grants one armour near a defended position")

	var plain_city: Dictionary = city.duplicate(true)
	plain_city["province_improvements"] = []
	var plain_cities: Array[Dictionary] = [plain_city]
	_check(is_equal_approx(Territory.get_defensive_armor_bonus(Vector2i(4, 0), plain_cities, no_kingdoms), 0.0), "unfortified friendly territory receives no watchtower armour bonus")

	var enemy_city: Dictionary = {
		"name": "Соседнее королевство",
		"cell": [10, 0],
		"population": 8,
		"specialization": "military",
		"province_improvements": [],
	}
	var kingdoms: Array[Dictionary] = [{"id": 0, "alive": true, "cities": [enemy_city], "army": [], "army_cell": [10, 0]}]
	var border_lookup := Territory.build_owner_lookup([Vector2i(5, 0)], plain_cities, no_army_cell, no_army, kingdoms)
	_check(int(border_lookup.get(Vector2i(5, 0), -1)) == Territory.OWNER_DISPUTED, "overlapping rival influence creates a disputed border")
	_check(Territory.get_owner_at(Vector2i(10, 0), plain_cities, no_army_cell, no_army, kingdoms) == 0, "AI city projects its kingdom ownership")

	var field_army: Array[Dictionary] = []
	for _unit in range(10):
		field_army.append({"role": "melee", "health": 125.0, "experience": 0})
	var army_lookup := Territory.build_owner_lookup(
		[Vector2i(20, 0), Vector2i(23, 0), Vector2i(25, 0)],
		[],
		Vector2i(20, 0),
		field_army,
		no_kingdoms
	)
	_check(int(army_lookup.get(Vector2i(23, 0), -1)) == Territory.OWNER_PLAYER, "field army projects temporary control around its position")
	_check(int(army_lookup.get(Vector2i(25, 0), -1)) == Territory.OWNER_UNCLAIMED, "army influence fades beyond its bounded radius")

	var player_outposts: Array[Dictionary] = [{
		"id": 0, "name": "Западный дозор", "cell": [20, 0], "food": 0, "gold": 0,
		"production_bank": 0, "province_improvements": [],
	}]
	var outpost_lookup := Territory.build_owner_lookup(
		[Vector2i(20, 0), Vector2i(25, 0), Vector2i(26, 0)],
		[], no_army_cell, no_army, no_kingdoms, [], player_outposts
	)
	_check(int(outpost_lookup.get(Vector2i(20, 0), Territory.OWNER_UNCLAIMED)) == Territory.OWNER_PLAYER, "player outpost owns its foundation hex")
	_check(int(outpost_lookup.get(Vector2i(25, 0), Territory.OWNER_UNCLAIMED)) == Territory.OWNER_PLAYER, "outpost influence reaches exactly its configured outer ring")
	_check(int(outpost_lookup.get(Vector2i(26, 0), Territory.OWNER_UNCLAIMED)) == Territory.OWNER_UNCLAIMED, "outpost control is bounded by its configured radius")
	var ai_outpost_kingdoms: Array[Dictionary] = [
		{"id": 0, "alive": false, "cities": [], "outposts": [], "army": [], "army_cell": [9999, 9999]},
		{"id": 1, "alive": false, "cities": [], "outposts": [], "army": [], "army_cell": [9999, 9999]},
		{"id": 2, "alive": true, "cities": [], "outposts": [{"cell": [30, 0]}], "army": [], "army_cell": [9999, 9999]},
	]
	var ai_outpost_owner := Territory.get_owner_at(Vector2i(30, 0), [], no_army_cell, no_army, ai_outpost_kingdoms)
	_check(ai_outpost_owner == 2, "AI outposts project ownership for their kingdom index")
	_check(SettlementCatalogScript.OUTPOST_INFLUENCE_POWER > SettlementCatalogScript.get_army_influence_power(24), "outpost influence is stronger than a full field army")
	_check(SettlementCatalogScript.get_city_influence_power(1, 0, "") > SettlementCatalogScript.OUTPOST_INFLUENCE_POWER, "even a level-one city is stronger than an outpost")

	var normalized_towers := CityDevelopment.normalize_province_improvements([{"id": "watchtower", "cell": [1, 0]}])
	_check(normalized_towers.size() == 1 and str(normalized_towers[0].get("id", "")) == "watchtower", "watchtower survives improvement normalization")
	var tower_income := CityDevelopment.get_city_income([], {}, normalized_towers, "")
	_check(int(tower_income.get("production", 0)) == 5, "watchtower adds one production per turn")

	var state := CampaignStateScript.new()
	root.add_child(state)
	state.new_campaign(false)
	_check(state.get_world_owner_at(state.city_cell) == Territory.OWNER_PLAYER, "campaign state delegates ownership to the territory catalog")
	_check(CampaignStateScript.SAVE_VERSION == 1, "territory control keeps the existing campaign save schema")
	state.queue_free()
	await process_frame

	if _failures == 0:
		print("All %d territorial control checks passed." % _checks)
		quit(0)
	else:
		push_error("Territorial control smoke tests failed: %d/%d." % [_failures, _checks])
		quit(1)
