extends SceneTree

const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const WorldEventScript = preload("res://scripts/world_event_catalog.gd")
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
	_check(WorldEventScript.EVENT_INTERVAL == 5, "world events are scheduled every five campaign turns")
	_check(not WorldEventScript.is_event_turn(4) and WorldEventScript.is_event_turn(5) and WorldEventScript.is_event_turn(10), "event cadence is stable at turns five and ten")
	_check(WorldEventScript.EVENTS.size() >= 6, "world event catalog contains at least six authored events")
	for event in WorldEventScript.EVENTS:
		_check(event.get("choices", []).size() == 2, "each world event offers two concise choices")
		for choice in event.get("choices", []):
			var effect: Dictionary = choice.get("effect", {})
			_check(not effect.has("mana") and not effect.has("wood") and not effect.has("stone"), "world events do not introduce unimplemented resources")

	var state: Variant = CampaignStateScript.new()
	root.add_child(state)
	state.new_campaign(false)
	state._prevent_save_overwrite = true
	var initial_gold: int = state.city_gold
	state.pending_world_event = WorldEventScript.get_event_by_id("merchant_caravan")
	_check(state.can_resolve_world_event("trade"), "merchant offer validates its gold cost")
	_check(state.resolve_world_event("trade"), "merchant caravan choice resolves")
	_check(state.city_gold == initial_gold + 20, "merchant exchange applies the net gold gain correctly")
	_check(state.pending_world_event.is_empty() and state.world_events_resolved == 1, "resolved event is removed and counted once")

	state.pending_world_event = WorldEventScript.get_event_by_id("refugees")
	state.city_food = 20
	var population_before: int = state.city_population
	_check(state.resolve_world_event("shelter"), "refugee shelter choice resolves when food is available")
	_check(state.city_food == 10 and state.city_population == population_before + 1, "refugee choice spends food and increases population")
	state.pending_world_event = WorldEventScript.get_event_by_id("refugees")
	state.city_food = 30
	state.city_population = 20
	_check(not state.can_resolve_world_event("shelter"), "refugee event is disabled when the active city is at its population cap")

	state.pending_world_event = WorldEventScript.get_event_by_id("scout_report")
	state.city_gold = 100
	var reveal_cell: Vector2i = state.player_cell + Vector2i(12, 0)
	_check(not state.is_cell_explored(reveal_cell), "scout test target begins outside current exploration")
	_check(state.resolve_world_event("hire_scouts"), "scout report choice resolves")
	_check(state.is_cell_explored(reveal_cell), "scout choice reveals a radius-four area around the army")

	state.pending_world_event = WorldEventScript.get_event_by_id("veteran_instructor")
	state.city_gold = 100
	var old_xp := int(state.player_units[0].get("experience", 0))
	_check(state.resolve_world_event("hire_instructor"), "veteran instructor choice resolves")
	_check(int(state.player_units[0].get("experience", 0)) == old_xp + 12, "instructor applies experience to existing troops")

	state.pending_world_event = WorldEventScript.get_event_by_id("workshop_wagon")
	state.city_gold = 100
	var production_before: int = state.city_production_bank
	_check(state.resolve_world_event("hire_masters"), "workshop wagon choice resolves")
	_check(state.city_production_bank == production_before + 15, "workshop wagon adds stored production")

	state.pending_world_event = WorldEventScript.get_event_by_id("abandoned_wagon")
	var wagon_food_before: int = state.city_food
	_check(state.resolve_world_event("keep_food"), "abandoned wagon food choice resolves")
	_check(state.city_food == wagon_food_before + 12, "abandoned wagon adds the selected food reward")
	state.pending_world_event = WorldEventScript.get_event_by_id("abandoned_wagon")
	var wagon_gold_before: int = state.city_gold
	_check(state.resolve_world_event("sell_goods"), "abandoned wagon trade choice resolves")
	_check(state.city_gold == wagon_gold_before + 18, "abandoned wagon adds the selected gold reward")

	state.pending_world_event = WorldEventScript.get_event_by_id("merchant_caravan")
	_check(not state.can_resolve_world_event("not_a_real_choice"), "unknown event choices are rejected")
	_check(WorldEventScript.normalize_event({}).is_empty(), "old saves without a pending event normalize to an empty event")
	_check(CampaignStateScript.SAVE_VERSION == 1, "campaign events do not change the save schema version")

	state._prevent_save_overwrite = false
	_check(state.save_campaign(), "pending world event can be saved in the existing campaign format")
	state.pending_world_event.clear()
	_check(state.load_campaign(), "campaign with a pending world event reloads")
	_check(str(state.pending_world_event.get("id", "")) == "merchant_caravan", "pending event survives save and load")
	_check(state.world_events_resolved == 7, "resolved event count survives save and load")

	if _failures == 0:
		print("All %d world event checks passed." % _checks)
	else:
		push_error("%d of %d world event checks failed." % [_failures, _checks])
	quit(0 if _failures == 0 else 1)
