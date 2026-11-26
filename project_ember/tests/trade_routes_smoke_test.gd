extends SceneTree

const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")
const StrategicMapDetailsScript = preload("res://scripts/strategic_map_details.gd")

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
	var state := CampaignStateScript.new()
	root.add_child(state)
	state.new_campaign(false)
	_check(CampaignStateScript.SAVE_VERSION == 1, "roads and trade routes preserve save schema version one")
	_check(state.trade_routes.is_empty(), "new campaigns begin without player-built trade routes")
	_check(state.get_city_trade_route_count(0) == 0 and state.get_city_trade_income(0) == 0, "cities have no trade income before a route is built")

	var source_cell: Vector2i = state.city_cell
	var target_cell := Vector2i(9999, 9999)
	var target_route: Array[Vector2i] = []
	for distance in range(2, 9):
		for q in range(-distance, distance + 1):
			for r in range(-distance, distance + 1):
				var candidate := source_cell + Vector2i(q, r)
				if StrategicMapDetailsScript.axial_distance(source_cell, candidate) != distance:
					continue
				if not WorldGeneratorScript.is_inside_world(candidate) or state.get_city_index_at(candidate) >= 0 or state.get_outpost_index_at(candidate) >= 0:
					continue
				var path: Array[Vector2i] = StrategicMapDetailsScript.axial_line(source_cell, candidate)
				var valid := true
				for cell in path:
					if not WorldGeneratorScript.is_inside_world(cell) or state.get_world_terrain(cell) == "water":
						valid = false
						break
				if valid:
					target_cell = candidate
					target_route = path
					break
			if target_cell != Vector2i(9999, 9999):
				break
		if target_cell != Vector2i(9999, 9999):
			break
	_check(target_cell != Vector2i(9999, 9999), "test world contains a nearby land route candidate")
	if target_cell == Vector2i(9999, 9999):
		state.queue_free()
		quit(1)
		return

	state.cities.append(state._make_city_record(1, "Торговый Порт", target_cell, 4, 6, 40, 4, [], []))
	state._reveal_fog_area(source_cell, 9)
	state._reveal_fog_area(target_cell, 9)
	state.city_gold = 500
	state.city_production_bank = 100
	state._save_active_city()

	var quote: Dictionary = state.get_trade_route_quote(0, 1)
	_check(bool(quote.get("valid", false)), "route quote accepts a fully explored land corridor in friendly or unclaimed territory")
	_check(int(quote.get("distance", 0)) == target_route.size() - 1, "route quote uses the deterministic axial hex distance")
	_check(int(quote.get("gold_cost", 0)) == 16 + int(quote.get("distance", 0)) * 3, "road gold cost scales with route length")
	_check(int(quote.get("production_cost", 0)) == 3 + int(quote.get("distance", 0)), "road production cost scales with route length")
	_check(state.create_trade_route(1), "player can build a road and activate a trade route")
	_check(state.trade_routes.size() == 1 and state.get_city_trade_route_count(0) == 1 and state.get_city_trade_route_count(1) == 1, "one route is registered at both endpoint cities")
	_check(state.is_trade_route_operational(state.trade_routes[0]), "built road remains operational across its explored land corridor")
	_check(state.get_city_trade_income(0) == 1 and state.get_city_trade_income(1) == 1, "both connected cities gain one gold of trade income per turn")
	_check(int(state.get_city_income().get("gold", 0)) == 5, "active city economy includes its trade-route gold")
	_check(state.get_city_trade_route_summary(0).contains("Торговый Порт"), "city panel summary names the connected trade partner")
	_check(int(state.cities[0].get("gold", 0)) == 500 - int(quote.get("gold_cost", 0)), "road construction charges the source city's gold")
	_check(int(state.cities[0].get("production_bank", 0)) == 100 - int(quote.get("production_cost", 0)), "road construction charges the source city's stored production")
	_check(not state.get_trade_route_quote(0, 1).get("valid", false), "duplicate routes between the same pair are rejected")

	state.cities.append(state._make_city_record(2, "Южный Рынок", target_cell + Vector2i(3, 0), 3, 3, 30, 2, [], []))
	state.trade_routes.append({"from_city_id": 0, "to_city_id": 2})
	_check(state.get_city_trade_route_count(0) == 2, "city tracks two separate trade connections")
	_check(not state.get_trade_route_quote(0, 2).get("valid", false), "a third connection is rejected by the per-city trade route cap")
	state.trade_routes.pop_back()
	state.cities.pop_back()

	state._prevent_save_overwrite = false
	_check(state.save_campaign(), "trade route can be saved in the existing campaign format")
	var restored := CampaignStateScript.new()
	root.add_child(restored)
	_check(restored.load_campaign(), "campaign with a trade route reloads")
	_check(restored.trade_routes.size() == 1, "trade route record survives save and load")
	_check(restored.get_city_trade_income(0) == 1 and restored.get_city_trade_income(1) == 1, "both city bonuses survive save and load")
	_check(restored.is_trade_route_operational(restored.trade_routes[0]), "restored road retains its validated land path")
	_check(restored._read_trade_routes([]).is_empty(), "legacy saves without trade-route data normalize to no routes")
	_check(restored._read_trade_routes([{"from_city_id": 0, "to_city_id": 0}]).is_empty(), "malformed self-routes are ignored during normalization")

	var saved_route: Dictionary = restored.trade_routes[0].duplicate(true)
	var midpoint_index := int(saved_route.get("cells", []).size() / 2)
	if midpoint_index > 0 and midpoint_index < saved_route.get("cells", []).size() - 1:
		var midpoint: Vector2i = WorldGeneratorScript.array_to_cell(saved_route["cells"][midpoint_index])
		var old_kingdoms: Array[Dictionary] = restored.kingdoms.duplicate(true)
		var hostile_city: Dictionary = restored.kingdoms[0].get("cities", [])[0].duplicate(true)
		hostile_city["cell"] = [midpoint.x, midpoint.y]
		hostile_city["population"] = 20
		restored.kingdoms[0]["cities"] = [hostile_city]
		_check(not restored.is_trade_route_operational(saved_route), "enemy-controlled corridor suspends trade income while retaining the road")
		restored.kingdoms = old_kingdoms

	state.queue_free()
	restored.queue_free()
	await process_frame
	if _failures == 0:
		print("All %d trade route checks passed." % _checks)
		quit(0)
	else:
		push_error("Trade route smoke tests failed: %d/%d checks." % [_failures, _checks])
		quit(1)
