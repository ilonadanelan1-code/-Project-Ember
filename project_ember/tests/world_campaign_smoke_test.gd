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
	_check(state.world_generation_version == WorldScript.WORLD_GENERATION_VERSION, "new campaigns use the coherent biome generator")
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
	_check(state.get_world_terrain(Vector2i(-10, 4)) == "water", "new campaign contains a visible starter lake outside the opening corridor")
	_check(state.get_world_terrain(Vector2i(500, 500)) == "void", "coordinates outside the world are rejected")
	_check(state.get_world_terrain(Vector2i(20, 18)) == state.get_world_terrain(Vector2i(20, 18)), "procedural terrain is deterministic")
	_check(WorldScript.terrain_at(Vector2i(2, 0), state.world_seed, 1) == "plain", "legacy generation keeps the original playable corridor")
	_check(
		WorldScript.terrain_at(Vector2i(0, -12), state.world_seed, 2) == "plain",
		"generator v2 remains stable for existing coherent-world saves"
	)
	_check(
		WorldScript.terrain_at(Vector2i(0, -12), state.world_seed, 3) == "farmland",
		"generator v3 reshapes the opening region without changing the outer world"
	)
	var opening_region_counts := {"plain": 0, "forest": 0, "hills": 0, "water": 0, "farmland": 0, "marsh": 0}
	for q in range(-18, 15):
		for r in range(-18, 19):
			var opening_cell := Vector2i(q, r)
			if WorldScript.hex_distance(opening_cell, Vector2i(-2, 0)) > 16:
				continue
			var opening_kind := WorldScript.terrain_at(opening_cell, state.world_seed, 3)
			opening_region_counts[opening_kind] = int(opening_region_counts[opening_kind]) + 1
	_check(int(opening_region_counts["plain"]) > 250, "opening region has broad traversable meadow zones")
	_check(int(opening_region_counts["farmland"]) > 150, "opening region has visible cultivated field belts")
	_check(int(opening_region_counts["forest"]) > 50, "opening region contains substantial forest pockets")
	_check(int(opening_region_counts["hills"]) < 180, "opening region avoids the previous mountain-heavy starting view")
	var biome_counts: Dictionary = {"plain": 0, "forest": 0, "hills": 0, "water": 0, "farmland": 0, "marsh": 0}
	var same_biome_edges := 0
	var sampled_edges := 0
	var legacy_terrain_differences := 0
	var adjacency_offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1)]
	for q in range(-WorldScript.WORLD_RADIUS, WorldScript.WORLD_RADIUS + 1):
		for r in range(-WorldScript.WORLD_RADIUS, WorldScript.WORLD_RADIUS + 1):
			var sample := Vector2i(q, r)
			if not WorldScript.is_inside_world(sample):
				continue
			var sample_kind := WorldScript.terrain_at(sample, state.world_seed, state.world_generation_version)
			if sample_kind != WorldScript.terrain_at(sample, state.world_seed, 1):
				legacy_terrain_differences += 1
			if biome_counts.has(sample_kind):
				biome_counts[sample_kind] = int(biome_counts[sample_kind]) + 1
			for offset in adjacency_offsets:
				var neighbor := sample + offset
				if not WorldScript.is_inside_world(neighbor):
					continue
				sampled_edges += 1
				if sample_kind == WorldScript.terrain_at(neighbor, state.world_seed, state.world_generation_version):
					same_biome_edges += 1
	_check(int(biome_counts["farmland"]) > 1000, "new world contains substantial farmland regions")
	_check(int(biome_counts["marsh"]) > 100, "new world contains marsh regions")
	_check(float(same_biome_edges) / float(maxi(1, sampled_edges)) > 0.55, "adjacent hexes form coherent biome regions instead of random noise")
	_check(legacy_terrain_differences > 1000, "generator v3 differs materially while versions 1 and 2 remain available for old saves")
	_check(WorldScript.decode_cell(WorldScript.encode_cell(Vector2i(-11, 0))) == Vector2i(-11, 0), "fog cell coordinates encode and decode safely")
	_check(state.is_cell_visible(state.player_cell), "player army has active vision around its current position")
	_check(state.is_cell_explored(state.player_cell), "current player position is permanently explored")
	_check(not state.is_cell_explored(Vector2i(20, 20)), "distant terrain starts hidden by fog of war")
	var initial_explored_count := state.get_explored_cell_count()
	_check(initial_explored_count > 250 and initial_explored_count < 450, "initial vision reveals only a compact local region")

	var first_army_before := WorldScript.array_to_cell(state.kingdoms[0].get("army_cell", []))
	state.advance_campaign_turn()
	_check(state.turn_number == 2, "campaign turn advances")
	var first_army_after := WorldScript.array_to_cell(state.kingdoms[0].get("army_cell", []))
	_check(first_army_after != first_army_before, "first kingdom moves its army on its scheduled AI turn")

	var remembered_cell := Vector2i(-11, 0)
	state.player_cell = Vector2i(15, 0)
	state.refresh_fog_of_war()
	_check(state.is_cell_visible(Vector2i(24, 0)), "moving the army reveals newly visible terrain")
	_check(state.is_cell_explored(remembered_cell), "previously discovered terrain remains remembered")
	_check(not state.is_cell_visible(remembered_cell), "remembered terrain is no longer currently visible")
	_check(not state.is_cell_explored(Vector2i(40, 35)), "unvisited distant terrain remains hidden")
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
	_check(state.world_generation_version == WorldScript.WORLD_GENERATION_VERSION, "save/load preserves the coherent terrain generation version")
	_check(state.get_total_enemy_units() >= total_starting_units, "save/load preserves AI armies")
	_check(state.is_cell_explored(remembered_cell), "save/load preserves previously explored fog cells")
	_check(state.is_cell_visible(state.player_cell), "save/load restores current player vision")
	_check(not state.is_cell_visible(remembered_cell), "save/load does not mark distant memories as currently visible")
	_check(not state.is_cell_explored(Vector2i(40, 35)), "save/load keeps unknown terrain hidden")

	state.queue_free()
	await process_frame
	if _failures > 0:
		printerr("World campaign smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All world campaign smoke tests passed.")
		quit(0)
