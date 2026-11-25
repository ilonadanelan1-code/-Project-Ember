extends SceneTree

const VictoryCatalog = preload("res://scripts/campaign_victory_catalog.gd")
const DiplomacyCatalog = preload("res://scripts/diplomacy_catalog.gd")
const FactionCatalog = preload("res://scripts/faction_catalog.gd")
const CampaignStateScript = preload("res://scripts/campaign_state.gd")

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
	var state := VictoryCatalog.create_state()
	_check(state.get("status", "") == "none", "new campaign starts without a declared victory")
	_check(VictoryCatalog.normalize_state({}).get("unlocked_types", []).is_empty(), "legacy saves receive empty victory progress")
	_check(CampaignStateScript.SAVE_VERSION == 1, "victory system keeps the existing save schema version")

	for kingdom_id in range(5):
		VictoryCatalog.record_military_victory(state, kingdom_id, 24, 8)
	VictoryCatalog.record_military_victory(state, 0, 24, 8)
	_check(state.get("military_wins", []).size() == 5, "military wins count unique kingdoms only")
	_check(not state.get("unlocked_types", []).has("military"), "victory checks remain inactive before turn 25")
	VictoryCatalog.record_military_victory(state, 6, 25, 8)
	_check(state.get("military_wins", []).size() == 6, "sixth unique kingdom victory is stored exactly once")
	_check(state.get("unlocked_types", []).has("military"), "six unique victories and eight survivors unlock military victory")

	var player_units: Array = []
	for index in range(8):
		player_units.append({"role": "melee", "health": 50.0, "experience": 0})
	var cities := [
		{
			"name": "Столица",
			"population": 14,
			"gold": 300,
			"buildings": ["market"],
			"building_levels": {"market": 1},
			"province_improvements": [],
			"specialization": "commerce",
		},
		{
			"name": "Вторая столица",
			"population": 14,
			"gold": 300,
			"buildings": ["market"],
			"building_levels": {"market": 1},
			"province_improvements": [],
			"specialization": "commerce",
		},
	]
	var kingdoms: Array = []
	for kingdom_id in range(9):
		kingdoms.append({"id": kingdom_id, "alive": true})
	var relations := DiplomacyCatalog.create_initial_relations(9, 842173)
	for kingdom_id in range(5):
		var record := DiplomacyCatalog.get_record(relations, -1, kingdom_id)
		record["relation"] = 60
		record["treaty"] = "alliance" if kingdom_id < 2 else ("trade" if kingdom_id == 2 else "peace")
		record["treaty_until"] = 100
		DiplomacyCatalog.set_record(relations, -1, kingdom_id, record)

	var faction := FactionCatalog.get_legacy_selection()
	var final_metrics: Dictionary = {}
	for turn_value in range(25, 30):
		final_metrics = VictoryCatalog.evaluate_turn(
			state, turn_value, cities, player_units, faction, relations, kingdoms, 8
		)
		if turn_value == 27:
			_check(state.get("unlocked_types", []).has("diplomatic"), "three positive treaties and three stable turns unlock diplomatic victory")
		if turn_value == 29:
			_check(state.get("unlocked_types", []).has("economic"), "two metropolises, 600 gold and five stable turns unlock economic victory")

	_check(int(final_metrics.get("metropolises", 0)) == 2, "economic metrics count player metropolises")
	_check(int(final_metrics.get("total_gold", 0)) == 600, "economic metrics sum gold across all player cities")
	_check(int(final_metrics.get("net_gold_income", 0)) >= 12, "economic metrics subtract army upkeep from recurring gold income")
	_check(int(final_metrics.get("friendly_kingdoms", 0)) == 5, "diplomatic metrics count friendly living kingdoms")
	_check(int(final_metrics.get("active_positive_treaties", 0)) == 3, "diplomatic metrics count active trade and alliance contracts")
	_check(int(final_metrics.get("major_treaties", 0)) == 2, "diplomatic metrics require two alliances or player-led vassals")

	var unlocked_before: Array = state.get("unlocked_types", []).duplicate()
	var weakened_cities := [{"population": 5, "gold": 20, "buildings": [], "building_levels": {}, "province_improvements": [], "specialization": ""}]
	var weakened_relations := DiplomacyCatalog.create_initial_relations(9, 842173)
	VictoryCatalog.evaluate_turn(state, 30, weakened_cities, player_units, faction, weakened_relations, kingdoms, 8)
	_check(int(state.get("economic_hold_turns", 0)) == 0, "economic hold counter resets when a requirement is lost")
	_check(int(state.get("diplomatic_hold_turns", 0)) == 0, "diplomatic hold counter resets when a requirement is lost")
	_check(state.get("unlocked_types", []) == unlocked_before, "already unlocked victory paths remain available after progress changes")

	_check(VictoryCatalog.choose_victory(state, "economic", true, 30), "player can continue after declaring a victory")
	_check(state.get("status", "") == "continued", "freeplay decision is persisted")
	_check(VictoryCatalog.choose_victory(state, "military", false, 31), "player can later end a continued campaign")
	_check(state.get("status", "") == "claimed", "final campaign victory is persisted")
	_check(not VictoryCatalog.choose_victory(state, "diplomatic", true, 32), "a completed campaign cannot be reopened by another victory choice")

	var normalized := VictoryCatalog.normalize_state({
		"military_wins": [1, 1, -1, 12, 2],
		"unlocked_types": ["military", "unknown", "military"],
		"status": "not_a_status",
		"type": "not_a_type",
		"economic_hold_turns": -20,
	})
	_check(normalized.get("military_wins", []).size() == 2, "legacy or malformed win IDs are normalized")
	_check(normalized.get("unlocked_types", []).size() == 1, "unknown and duplicate victory IDs are discarded")
	_check(normalized.get("status", "") == "none", "unknown completion status is normalized")
	_check(int(normalized.get("economic_hold_turns", 0)) == 0, "negative hold counters are clamped")

	if _failures == 0:
		print("All %d campaign victory checks passed." % _checks)
	else:
		push_error("%d of %d campaign victory checks failed." % [_failures, _checks])
	quit(0 if _failures == 0 else 1)
