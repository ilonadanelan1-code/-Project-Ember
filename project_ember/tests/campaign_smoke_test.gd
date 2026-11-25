extends SceneTree

const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	var state: Variant = CampaignStateScript.new()
	root.add_child(state)
	state.new_campaign()

	_check(state.player_units.size() == 5, "new campaign creates the starting army")
	_check(state.get_city_queue_summary() == "Очередь пуста", "empty production queue has a valid summary")

	_check(state.queue_building("barracks"), "city accepts a barracks order")
	_check(state.get_city_queue_summary().contains("Казармы"), "queue summary names the active order")
	state.city_production_bank = 8
	state._process_city_queue()
	_check(state.city_has_building("barracks"), "completed building is added to the city")

	_check(state.queue_recruit(state.ROLE_MELEE), "city accepts a melee recruitment order")
	_check(state.city_last_event.contains("Мечник"), "recruitment message uses the selected unit name")
	state.city_production_bank = 3
	state._process_city_queue()
	_check(state.player_units.size() == 6, "completed recruitment adds a unit to the army")

	while state.player_units.size() < state.ARMY_CAPACITY:
		state.player_units.append({"role": state.ROLE_MELEE, "health": 125.0})
	_check(not state.can_queue_recruit(state.ROLE_MELEE), "recruitment respects the global army cap")
	_check(state.player_units.size() == state.ARMY_CAPACITY, "army can grow to the expanded capacity")
	state.player_units = state._make_starting_army()

	state.settler_active = true
	state.settler_cell = Vector2i(0, 3)
	var neutral_founding_cell := Vector2i(9999, 9999)
	for radius in range(3, 25):
		for q in range(-radius, radius + 1):
			for r in range(-radius, radius + 1):
				var offset := Vector2i(q, r)
				if WorldGeneratorScript.hex_distance(Vector2i.ZERO, offset) != radius:
					continue
				var candidate: Vector2i = state.city_cell + offset
				if state.can_found_city(candidate):
					neutral_founding_cell = candidate
					break
			if neutral_founding_cell != Vector2i(9999, 9999):
				break
		if neutral_founding_cell != Vector2i(9999, 9999):
			break
	_check(neutral_founding_cell != Vector2i(9999, 9999), "campaign contains neutral land legally available for settlement")
	if neutral_founding_cell != Vector2i(9999, 9999):
		state.settler_cell = neutral_founding_cell
		_check(state.found_city(neutral_founding_cell), "settler can found a city on neutral land")
	_check(state.cities.size() == 2, "new city is added to the campaign")
	_check(state.city_name == "Сосновый Дол", "new city becomes the active city")

	var capital_gold_before: int = int(state.cities[0].get("gold", 0))
	var new_city_gold_before: int = int(state.cities[1].get("gold", 0))
	var upkeep_due: int = state.get_army_upkeep_per_turn()
	state.advance_campaign_turn()
	_check(int(state.cities[0].get("gold", 0)) == capital_gold_before + 4 - upkeep_due, "capital receives its income before paying army upkeep")
	_check(int(state.cities[1].get("gold", 0)) == new_city_gold_before + 4, "new city receives independent turn income")

	_check(state.save_campaign(), "campaign saves successfully")
	var saved_gold: int = state.city_gold
	state.city_gold = 999
	_check(state.load_campaign(), "saved campaign loads successfully")
	_check(state.city_gold == saved_gold, "loading restores the saved active-city economy")

	state.free()
	if _failures > 0:
		printerr("Campaign smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All campaign smoke tests passed.")
		quit(0)