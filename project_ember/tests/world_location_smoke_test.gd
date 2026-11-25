extends SceneTree

const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const WorldLocationScript = preload("res://scripts/world_location_catalog.gd")
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
	var seed_value := WorldGeneratorScript.DEFAULT_SEED
	var generation_version := WorldGeneratorScript.WORLD_GENERATION_VERSION
	var locations := WorldLocationScript.generate_locations(seed_value, generation_version)
	var repeated := WorldLocationScript.generate_locations(seed_value, generation_version)
	_check(locations == repeated, "neutral locations are deterministic for the same world seed")
	_check(locations.size() >= 50 and locations.size() <= WorldLocationScript.MAX_LOCATIONS, "world receives a broad but capped set of points of interest")

	var local_count := 0
	var ids: Dictionary = {}
	var cells: Dictionary = {}
	var capitals := WorldGeneratorScript.kingdom_capital_cells()
	var supported_roles := ["melee", "ranged", "spear", "cavalry"]
	var valid_ids := true
	var unique_cells := true
	var inside_world := true
	var valid_terrain := true
	var clear_of_cities := true
	var clear_of_capitals := true
	var enough_spacing := true
	var valid_guards := true
	var valid_rewards := true
	var valid_location_terrain := true
	for index in range(locations.size()):
		var location: Dictionary = locations[index]
		var location_id := str(location.get("id", ""))
		var cell := WorldGeneratorScript.array_to_cell(location.get("cell", []))
		var distance_from_start := WorldGeneratorScript.hex_distance(cell, Vector2i(-2, 0))
		if distance_from_start <= 13:
			local_count += 1
		if location_id.is_empty() or ids.has(location_id):
			valid_ids = false
		ids[location_id] = true
		var cell_key := "%d:%d" % [cell.x, cell.y]
		if cells.has(cell_key):
			unique_cells = false
		cells[cell_key] = true
		inside_world = inside_world and WorldGeneratorScript.is_inside_world(cell)
		var terrain_id := WorldGeneratorScript.terrain_at(cell, seed_value, generation_version)
		valid_terrain = valid_terrain and terrain_id not in ["water", "void"]
		var type_id := str(location.get("type", ""))
		var type_data := WorldLocationScript.get_type_data(type_id)
		var allowed_terrain: Array = type_data.get("terrain", [])
		valid_location_terrain = valid_location_terrain and allowed_terrain.has(terrain_id)
		clear_of_cities = clear_of_cities and WorldGeneratorScript.hex_distance(cell, Vector2i(-3, 1)) >= 3
		for capital in capitals:
			if WorldGeneratorScript.hex_distance(cell, capital) < 3:
				clear_of_capitals = false
		for other_index in range(index):
			var other_cell := WorldGeneratorScript.array_to_cell(locations[other_index].get("cell", []))
			if WorldGeneratorScript.hex_distance(cell, other_cell) < WorldLocationScript.MIN_LOCATION_DISTANCE:
				enough_spacing = false
		var guard_tier := int(location.get("guard_tier", 0))
		var guards: Array = location.get("guards", [])
		if guard_tier not in [1, 2, 3] or guards.is_empty():
			valid_guards = false
		for guard in guards:
			if not guard is Dictionary or not supported_roles.has(str(guard.get("role", ""))):
				valid_guards = false
		if not location.get("reward", {}) is Dictionary:
			valid_rewards = false
	_check(valid_ids, "location IDs are present and unique")
	_check(unique_cells, "location hexes are unique")
	_check(inside_world, "all locations are inside the generated world")
	_check(valid_terrain, "locations never occupy water or void")
	_check(valid_location_terrain, "each neutral location type matches its catalogued terrain")
	_check(clear_of_cities and clear_of_capitals, "locations respect starting city and AI capital exclusion rings")
	_check(enough_spacing, "locations respect the minimum five-hex spacing")
	_check(valid_guards, "all neutral guard rosters use valid tiers and stable campaign role IDs")
	_check(valid_rewards, "all location rewards use the existing resource dictionary")
	_check(local_count >= 4 and local_count <= 10, "at least four neutral locations are placed within the opening exploration ring")
	for alternate_seed in [1, 17, 842173, 1902407]:
		var alternate_locations := WorldLocationScript.generate_locations(int(alternate_seed), generation_version)
		var alternate_local_count := 0
		for alternate_location in alternate_locations:
			var alternate_cell := WorldGeneratorScript.array_to_cell(alternate_location.get("cell", []))
			var alternate_distance := WorldGeneratorScript.hex_distance(alternate_cell, Vector2i(-2, 0))
			if alternate_distance >= 4 and alternate_distance <= 13:
				alternate_local_count += 1
		_check(alternate_local_count >= 4, "world seed %d keeps four nearby exploration targets" % int(alternate_seed))

	if not locations.is_empty():
		var sample: Dictionary = locations[0]
		var sample_id := str(sample.get("id", ""))
		var survivor_data := [{"role": "melee", "health": 37.0, "experience": 24}]
		var raw_saved := [{"id": sample_id, "cleared": false, "guards": survivor_data}]
		var normalized := WorldLocationScript.normalize_locations(raw_saved, seed_value, generation_version)
		var normalized_sample := _find_location(normalized, sample_id)
		_check(not normalized_sample.is_empty(), "location normalization restores generated location records from saves")
		_check(normalized_sample.get("guards", []).size() == 1, "remaining neutral guards survive save normalization")
		if not normalized_sample.is_empty() and not normalized_sample.get("guards", []).is_empty():
			_check(int(normalized_sample["guards"][0].get("experience", 0)) == 24, "neutral guard experience survives normalization")
		_check(is_equal_approx(float(normalized_sample.get("guardian_health", 0.0)), float(sample.get("guardian_health", 0.0))), "neutral guardian health survives save normalization")
		var exhausted_guards := WorldLocationScript.normalize_locations([{"id": sample_id, "cleared": false, "guards": [], "guardian_health": 61.0}], seed_value, generation_version)
		var exhausted_sample := _find_location(exhausted_guards, sample_id)
		_check(exhausted_sample.get("guards", []).is_empty() and is_equal_approx(float(exhausted_sample.get("guardian_health", 0.0)), 61.0), "empty guard roster and surviving guardian health are preserved")
		var cleared := WorldLocationScript.normalize_locations([{"id": sample_id, "cleared": true, "guards": []}], seed_value, generation_version)
		var cleared_sample := _find_location(cleared, sample_id)
		_check(bool(cleared_sample.get("cleared", false)) and cleared_sample.get("guards", []).is_empty(), "cleared locations remain cleared after save normalization")

	var state: Variant = CampaignStateScript.new()
	root.add_child(state)
	state.new_campaign(false)
	state._prevent_save_overwrite = true
	_check(state.neutral_locations.size() == locations.size(), "new campaigns initialize the deterministic neutral location catalog")
	_check(CampaignStateScript.SAVE_VERSION == 1, "neutral locations do not require a save schema version bump")
	if not state.neutral_locations.is_empty():
		var target: Dictionary = state.neutral_locations[0]
		var target_cell := WorldGeneratorScript.array_to_cell(target.get("cell", []))
		state.settler_active = true
		_check(not state.can_found_city(target_cell), "settlers cannot found a city on a neutral point of interest")
		state.settler_active = false
		state.player_cell = target_cell + Vector2i(1, 0)
		var target_id := str(target.get("id", ""))
		_check(state.begin_location_battle(target_id), "army can engage neutral guards from an adjacent hex")
		_check(state.battle_target_type == "location" and state.battle_location_id == target_id, "neutral battle is distinguished from a kingdom battle")
		_check(state.enemy_units.size() == target.get("guards", []).size(), "neutral battle loads the location guard roster")
		var gold_before: int = state.city_gold
		var food_before: int = state.city_food
		var production_before: int = state.city_production_bank
		var no_enemy_survivors: Array[Dictionary] = []
		state.complete_battle(state.player_units, no_enemy_survivors, true, {"player_kills": 3, "player_damage": 30.0}, 210.0, 0.0)
		var cleared_after_battle: Dictionary = state.get_neutral_location_by_id(target_id)
		_check(bool(cleared_after_battle.get("cleared", false)), "victory permanently clears the neutral location")
		_check(state.city_gold >= gold_before and state.city_food >= food_before and state.city_production_bank >= production_before, "neutral victory grants only non-negative existing resources")
		_check(not str(state.last_battle_result.get("location_reward", "")).is_empty(), "neutral battle report includes its resource reward")
		state._remove_conflicting_neutral_locations()
		_check(not state.get_neutral_location_by_id(target_id).is_empty(), "cleared location remains in map history when the victorious army occupies its hex")

	if state.neutral_locations.size() > 1:
		var defended_location: Dictionary = state.neutral_locations[1]
		var defended_id := str(defended_location.get("id", ""))
		var defended_cell := WorldGeneratorScript.array_to_cell(defended_location.get("cell", []))
		state.player_cell = defended_cell + Vector2i(1, 0)
		_check(state.begin_location_battle(defended_id), "second neutral site starts a battle for retreat-persistence test")
		var surviving_guard: Array[Dictionary] = [{"role": "melee", "health": 28.0, "experience": 18}]
		state.complete_battle(state.player_units, surviving_guard, false, {"player_kills": 1, "player_damage": 12.0}, 160.0, 61.0)
		var damaged_location: Dictionary = state.get_neutral_location_by_id(defended_id)
		_check(damaged_location.get("guards", []).size() == 1, "defeat saves the surviving neutral guards")
		_check(is_equal_approx(float(damaged_location.get("guardian_health", 0.0)), 61.0), "defeat saves the neutral guardian's remaining health")
		state.player_cell = defended_cell + Vector2i(1, 0)
		_check(state.begin_location_battle(defended_id), "a damaged neutral site can be attacked again")
		_check(state.enemy_units.size() == 1 and is_equal_approx(float(state.enemy_hero.get("health", 0.0)), 61.0), "rematch reloads the reduced guard roster and guardian health")
		state.battle_in_progress = false
		state.battle_kingdom_id = -1
		state.battle_target_type = "kingdom"
		state.battle_location_id = ""

	if state.neutral_locations.size() > 1:
		var conflicting: Dictionary = state.neutral_locations[1]
		var conflicting_cell := WorldGeneratorScript.array_to_cell(conflicting.get("cell", []))
		state.player_cell = conflicting_cell
		state._remove_conflicting_neutral_locations()
		_check(state.get_neutral_location_index_at(conflicting_cell) == -1, "legacy occupied hexes cannot overlap regenerated neutral locations")

	# Each neutral site type has a distinct post-victory consequence.
	state.explored_cells.clear()
	state.visible_cells.clear()
	state.player_cell = Vector2i(-2, 0)
	state.refresh_fog_of_war()
	var ruins_cell: Vector2i = state.player_cell + Vector2i(1, 0)
	state._apply_neutral_location_special_reward({"type": "ancient_ruins", "cell": WorldGeneratorScript.cell_to_array(ruins_cell)})
	var ruins_remote_cells := 0
	for q in range(-22, 23):
		for r in range(-22, 23):
			var sample: Vector2i = state.player_cell + Vector2i(q, r)
			if WorldGeneratorScript.hex_distance(state.player_cell, sample) <= CampaignStateScript.ARMY_VISION_RADIUS:
				continue
			if WorldGeneratorScript.is_inside_world(sample) and state.is_cell_explored(sample):
				ruins_remote_cells += 1
	_check(ruins_remote_cells >= 15, "ancient ruins reveal a remote five-hex survey beyond normal army vision")
	var unit_xp_before_special := int(state.player_units[0].get("experience", 0))
	state._apply_neutral_location_special_reward({"type": "monster_lair", "cell": [0, 0]})
	_check(int(state.player_units[0].get("experience", 0)) == unit_xp_before_special + 12, "monster lair victory grants extra experience to surviving troops")
	state.player_hero["health"] = 1.0
	state.player_hero["wounded_turns"] = 2
	state._apply_neutral_location_special_reward({"type": "forgotten_shrine", "cell": [0, 0]})
	_check(is_equal_approx(float(state.player_hero.get("health", 0.0)), state.get_hero_max_health(state.player_hero)) and int(state.player_hero.get("wounded_turns", 0)) == 0, "forgotten shrine restores and recovers the ruler")
	var saved_test_army: Array[Dictionary] = state._copy_unit_records(state.player_units)
	var army_size_before_mercenary: int = state.player_units.size()
	state._apply_neutral_location_special_reward({"type": "mercenary_camp", "cell": [0, 0]})
	_check(state.player_units.size() == army_size_before_mercenary + 1, "mercenary camp recruits a swordsman while army capacity is available")
	while state.player_units.size() < 24:
		state.player_units.append({"role": "melee", "health": 100.0, "experience": 0})
	var full_army_gold_before: int = state.city_gold
	state._apply_neutral_location_special_reward({"type": "mercenary_camp", "cell": [0, 0]})
	_check(state.player_units.size() == 24 and state.city_gold == full_army_gold_before + 25, "full mercenary camp falls back to a gold payment without exceeding army capacity")
	state.player_units = saved_test_army

	# A cleared mine adds two stored production without requiring a new resource or save field.
	if not state.neutral_locations.is_empty():
		var original_mine_record: Dictionary = state.neutral_locations[0].duplicate(true)
		var mine_probe: Dictionary = original_mine_record.duplicate(true)
		mine_probe["type"] = "abandoned_mine"
		mine_probe["cleared"] = true
		mine_probe["cell"] = WorldGeneratorScript.cell_to_array(state.player_cell + Vector2i(10, 0))
		state.neutral_locations[0] = mine_probe
		state._save_active_city()
		var mine_city_before: int = state.city_production_bank
		state._apply_neutral_mine_income()
		state._load_active_city()
		_check(state.city_production_bank == mine_city_before + 2, "cleared abandoned mine adds two production to the nearest city")
		state.neutral_locations[0] = original_mine_record

	_check(state.neutral_locations.size() <= WorldLocationScript.MAX_LOCATIONS, "normalized campaign remains within the location cap")
	if _failures == 0:
		print("All %d world location checks passed." % _checks)
	else:
		push_error("%d of %d world location checks failed." % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _find_location(source: Array[Dictionary], location_id: String) -> Dictionary:
	for location in source:
		if str(location.get("id", "")) == location_id:
			return location
	return {}
