extends SceneTree

const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const WorldScript = preload("res://scripts/world_generator.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	var state := CampaignStateScript.new()
	root.add_child(state)
	state.new_campaign()

	_check(WorldScript.WORLD_RADIUS == 89, "world radius is 89 hexes")
	_check(WorldScript.WORLD_HEX_COUNT == 24031, "hex count is exactly 24,031")
	_check(state.kingdoms.size() == 9, "a new campaign creates nine independent AI kingdoms")
	_check(state.player_cell == Vector2i(-2, 0), "new campaign preserves the player's starting army position")
	_check(state.cities.size() == 1 and state.city_name == "Каменный Брод", "new campaign preserves the player's capital")

	var occupied_army_cells: Array[Vector2i] = []
	var total_starting_units := 0
	for index in range(state.kingdoms.size()):
		var kingdom: Dictionary = state.kingdoms[index]
		var capital := WorldScript.array_to_cell(kingdom.get("capital_cell", []))
		var army_cell := WorldScript.array_to_cell(kingdom.get("army_cell", []))
		var army: Array = kingdom.get("army", [])
		_check(WorldScript.is_inside_world(capital), "kingdom %d capital lies inside the world" % (index + 1))
		_check(WorldScript.is_inside_world(army_cell), "kingdom %d army lies inside the world" % (index + 1))
		_check(not occupied_army_cells.has(army_cell), "kingdom %d has a unique army position" % (index + 1))
		occupied_army_cells.append(army_cell)
		_check(not army.is_empty(), "kingdom %d begins with a field army" % (index + 1))
		total_starting_units += army.size()
		_check(not str(kingdom.get("name", "")).is_empty(), "kingdom %d has a name" % (index + 1))
	_check(state.get_total_enemy_units() == total_starting_units, "total enemy army strength aggregates all kingdoms")
	_check(state.get_kingdom_index_at_army(WorldScript.array_to_cell(state.kingdoms[0].get("army_cell", []))) == 0, "army lookup identifies the first kingdom")
	_check(state.get_world_terrain(Vector2i(2, 0)) == "plain", "starting conflict corridor is passable")
	_check(state.get_world_terrain(Vector2i(500, 500)) == "void", "coordinates outside the world are rejected")
	_check(state.get_world_terrain(Vector2i(20, 18)) == state.get_world_terrain(Vector2i(20, 18)), "procedural terrain is deterministic")

	var first_army_before := WorldScript.array_to_cell(state.kingdoms[0].get("army_cell", []))
	state.advance_campaign_turn()
	_check(state.turn_number == 2, "campaign turn advances")
	var first_army_after := WorldScript.array_to_cell(state.kingdoms[0].get("army_cell", []))
	_check(first_army_after != first_army_before, "first kingdom moves its army on its scheduled AI turn")
	for index in range(state.kingdoms.size()):
		var kingdom: Dictionary = state.kingdoms[index]
		_check(not str(kingdom.get("last_action", "")).is_empty(), "kingdom %d performs an AI turn" % (index + 1))
		var cities: Array = kingdom.get("cities", [])
		_check(not cities.is_empty(), "kingdom %d retains at least one city" % (index + 1))
		var capital: Dictionary = cities[0]
		_check(not capital.get("build_queue", []).is_empty() or not capital.get("buildings", []).is_empty(), "kingdom %d begins autonomous development" % (index + 1))

	for _turn in range(12):
		state.advance_campaign_turn()
	_check(state.turn_number == 14, "AI economy and development progress over repeated turns")
	_check(state.get_total_enemy_units() >= total_starting_units, "AI kingdoms do not lose units during peaceful development")
	var developed_count := 0
	for kingdom in state.kingdoms:
		var cities: Array = kingdom.get("cities", [])
		if cities.size() > 1:
			developed_count += 1
		if not cities.is_empty():
			var buildings: Array = cities[0].get("buildings", [])
			if buildings.has("barracks"):
				developed_count += 1
	_check(developed_count > 0, "AI kingdoms construct buildings and/or found additional cities")

	var expected_kingdom_name := str(state.kingdoms[3].get("name", ""))
	_check(state.save_campaign(), "expanded world and all kingdoms save successfully")
	state.kingdoms[3]["name"] = "Повреждённое название"
	_check(state.load_campaign(), "expanded campaign reloads successfully")
	_check(str(state.kingdoms[3].get("name", "")) == expected_kingdom_name, "save/load preserves kingdom identities")
	_check(state.kingdoms.size() == 9, "save/load preserves all nine AI kingdoms")
	_check(state.get_total_enemy_units() >= total_starting_units, "save/load preserves AI armies")

	state.queue_free()
	await process_frame
	if _failures > 0:
		printerr("World campaign smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All world campaign smoke tests passed.")
		quit(0)
