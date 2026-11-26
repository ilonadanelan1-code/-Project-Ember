extends SceneTree

const SettlementCatalog = preload("res://scripts/settlement_catalog.gd")
const Territory = preload("res://scripts/territory_catalog.gd")
const KingdomAI = preload("res://scripts/kingdom_ai.gd")
const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const World = preload("res://scripts/world_generator.gd")

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
	var base_settler_cost := SettlementCatalog.get_settler_cost(1, 0)
	var expanded_settler_cost := SettlementCatalog.get_settler_cost(2, 1)
	_check(int(base_settler_cost.get("gold", 0)) == 45, "first settler uses the centralized base cost")
	_check(int(expanded_settler_cost.get("gold", 0)) == 65, "settler gold price scales with total settlements")
	_check(int(expanded_settler_cost.get("production", 0)) == 14, "settler production price scales with total settlements")
	_check(SettlementCatalog.OUTPOST_INFLUENCE_POWER > SettlementCatalog.get_army_influence_power(24), "outpost influence remains above the strongest field army")
	_check(SettlementCatalog.get_city_influence_power(1, 0, "") > SettlementCatalog.OUTPOST_INFLUENCE_POWER, "even a level-one city remains stronger than an outpost")
	_check(SettlementCatalog.OUTPOST_BASE_GOLD_INCOME - SettlementCatalog.OUTPOST_UPKEEP_PER_TURN == 1, "an outpost retains one net gold per turn after its own upkeep")

	var no_army_cell := Vector2i(9999, 9999)
	var no_units: Array[Dictionary] = []
	var no_kingdoms: Array[Dictionary] = []
	var player_outposts: Array[Dictionary] = [{
		"id": 0, "name": "Западный пост", "cell": [20, 0], "gold": 0,
		"food": 0, "production_bank": 0, "province_improvements": [],
	}]
	var outpost_lookup := Territory.build_owner_lookup(
		[Vector2i(20, 0), Vector2i(25, 0), Vector2i(26, 0)],
		[], no_army_cell, no_units, no_kingdoms, [], player_outposts
	)
	_check(int(outpost_lookup.get(Vector2i(20, 0), Territory.OWNER_UNCLAIMED)) == Territory.OWNER_PLAYER, "player outpost claims its foundation hex")
	_check(int(outpost_lookup.get(Vector2i(25, 0), Territory.OWNER_UNCLAIMED)) == Territory.OWNER_PLAYER, "outpost influence reaches its configured radius")
	_check(int(outpost_lookup.get(Vector2i(26, 0), Territory.OWNER_UNCLAIMED)) == Territory.OWNER_UNCLAIMED, "outpost influence stops at its configured radius")

	var state := CampaignStateScript.new()
	root.add_child(state)
	# This test includes a save/load round-trip, so initialize a writable campaign.
	state.new_campaign()
	_check(CampaignStateScript.SAVE_VERSION == 1, "settlement additions preserve campaign save version one")
	_check(state.get_settler_cost_preview().get("gold", 0) == 45, "campaign preview uses the initial settler price")
	state.city_gold = 500
	state.city_production_bank = 200
	state.city_food = 12
	state._save_active_city()
	state.settler_active = true
	state.settler_origin_city_id = state.active_city_id
	var found_cell := Vector2i(9999, 9999)
	for distance in range(2, 12):
		for q in range(-distance, distance + 1):
			for r in range(-distance, distance + 1):
				var candidate := state.city_cell + Vector2i(q, r)
				if World.hex_distance(state.city_cell, candidate) != distance:
					continue
				if state.can_found_outpost(candidate):
					found_cell = candidate
					break
			if found_cell != Vector2i(9999, 9999):
				break
		if found_cell != Vector2i(9999, 9999):
			break
	_check(found_cell != Vector2i(9999, 9999), "at least one legal nearby outpost foundation cell is available")
	if found_cell != Vector2i(9999, 9999):
		_check(state.found_outpost(found_cell), "settler can establish an outpost through the campaign API")
	else:
		_check(false, "settler can establish an outpost through the campaign API")
	_check(state.outposts.size() == 1 and not state.settler_active, "outpost foundation consumes the settler and stores a separate record")
	_check(state.get_settler_cost_preview().get("gold", 0) == 55, "campaign price responds to a newly established outpost")
	_check(int(state.get_outpost_income(0).get("gold", 0)) == SettlementCatalog.OUTPOST_BASE_GOLD_INCOME, "outpost receives its catalogued passive income")
	_check(state.save_campaign(), "campaign save writes a state containing an outpost")
	var restored_state := CampaignStateScript.new()
	root.add_child(restored_state)
	_check(restored_state.load_campaign(), "campaign save containing an outpost can be loaded again")
	_check(restored_state.outposts.size() == 1 and restored_state.outposts[0].get("cell", []) == [found_cell.x, found_cell.y], "outpost coordinates and record survive a v1 save round-trip")
	_check(restored_state.cities.size() == state.cities.size() and restored_state.active_city_id == state.active_city_id, "existing city records remain intact after outpost save migration")
	restored_state.queue_free()
	state.outposts[0]["food"] = 3
	state.outposts[0]["gold"] = 5
	state.outposts[0]["production_bank"] = 2
	state._save_active_city()
	var stock_before := int(state.cities[state.active_city_id].get("gold", 0))
	_check(state.collect_outpost_income(0), "outpost stock can be collected into the nearest city")
	_check(int(state.cities[state.active_city_id].get("gold", 0)) == stock_before + 5, "collected outpost gold reaches the city treasury")
	_check(int(state.outposts[0].get("gold", -1)) == 0, "collected outpost stock is not duplicated")
	var annex_cell := state.city_cell + Vector2i(2, 0)
	state.outposts[0]["cell"] = [annex_cell.x, annex_cell.y]
	state.outposts[0]["food"] = 4
	state.outposts[0]["gold"] = 9
	state.outposts[0]["production_bank"] = 3
	state.city_gold = 500
	state.city_production_bank = 200
	state._save_active_city()
	var merge_food_before := state.city_food
	_check(state.can_annex_outpost(0, "merge"), "nearby outpost can be annexed when city resources and province capacity allow it")
	_check(state.annex_outpost(0, "merge"), "outpost annexation merges its treasury into the nearest city")
	_check(state.outposts.is_empty(), "annexed outpost is removed from the map state")
	_check(int(state.cities[state.active_city_id].get("gold", 0)) == 474, "annexation deducts the price and transfers outpost gold")
	_check(int(state.cities[state.active_city_id].get("production_bank", 0)) == 195, "annexation transfers stored production after the fee")
	_check(state.city_food == merge_food_before + 4, "annexation transfers outpost food to the city")
	_check(state.get_settlement_upkeep_per_turn() == 0, "outpost upkeep disappears after its annexation")

	# Legacy kingdoms that have no outposts field must normalize to an empty array.
	var fallback_kingdoms := KingdomAI.create_initial_kingdoms(991)
	var normalized_legacy := KingdomAI.normalize_kingdom({"id": 0, "cities": fallback_kingdoms[0].get("cities", [])}, fallback_kingdoms[0])
	_check(normalized_legacy.get("outposts", []) is Array and normalized_legacy.get("outposts", []).is_empty(), "old AI kingdom records load without an outposts field")
	var restored_outposts := state._read_outposts([])
	_check(restored_outposts.is_empty(), "old campaign saves load safely when outposts are absent")
	var ai_annex_kingdom: Dictionary = {
		"id": 1, "name": "Северное королевство",
		"cities": [{"cell": [30, 0], "gold": 300, "food": 7, "production_bank": 30, "population": 8, "province_improvements": []}],
		"outposts": [{"id": 0, "name": "Северный пост", "cell": [32, 0], "gold": 11, "food": 2, "production_bank": 5, "province_improvements": []}],
	}
	var ai_annex_event := KingdomAI._try_annex_ai_outpost(ai_annex_kingdom)
	var ai_annex_city: Dictionary = ai_annex_kingdom["cities"][0]
	_check(not ai_annex_event.is_empty() and ai_annex_kingdom["outposts"].is_empty(), "AI annexes a nearby outpost when treasury and distance allow it")
	_check(int(ai_annex_city.get("gold", 0)) == 276 and int(ai_annex_city.get("production_bank", 0)) == 27, "AI annexation pays the configured fee and transfers outpost reserves")
	var low_reserve_kingdom: Dictionary = {
		"id": 2, "name": "Бедное королевство",
		"cities": [{"cell": [0, 0], "gold": 100, "production_bank": 50, "population": 8}],
		"outposts": [],
	}
	var low_reserve_kingdoms: Array[Dictionary] = [low_reserve_kingdom]
	var no_player_cities: Array[Vector2i] = []
	var no_player_outposts: Array[Vector2i] = []
	var no_neutral_cells: Array[Vector2i] = []
	var ai_foundation_event := KingdomAI._try_found_ai_outpost(
		low_reserve_kingdom, low_reserve_kingdoms, Vector2i(20, 20),
		no_player_cities, no_player_outposts, 991, World.WORLD_GENERATION_VERSION,
		no_neutral_cells, false, 999999
	)
	_check(ai_foundation_event.is_empty() and low_reserve_kingdom["outposts"].is_empty(), "AI refuses to found an outpost when doing so would break its gold reserve")

	state.queue_free()
	await process_frame
	if _failures == 0:
		print("All %d settlement economy checks passed." % _checks)
		quit(0)
	else:
		push_error("Settlement economy smoke tests failed: %d/%d checks." % [_failures, _checks])
		quit(1)
