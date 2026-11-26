extends SceneTree

const ArcaneVictoryScript = preload("res://scripts/arcane_victory_catalog.gd")
const WorldLocationScript = preload("res://scripts/world_location_catalog.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")
const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const KingdomAIScript = preload("res://scripts/kingdom_ai.gd")
const DiplomacyCatalogScript = preload("res://scripts/diplomacy_catalog.gd")

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
	var first_world := WorldLocationScript.generate_locations(841207, WorldGeneratorScript.WORLD_GENERATION_VERSION)
	var repeated_world := WorldLocationScript.generate_locations(841207, WorldGeneratorScript.WORLD_GENERATION_VERSION)
	var nexus_count := 0
	for location in first_world:
		if str(location.get("type", "")) == ArcaneVictoryScript.NEXUS_LOCATION_ID:
			nexus_count += 1
	_check(first_world == repeated_world, "leyline nexus placement is deterministic for the same world seed")
	_check(nexus_count >= 2, "every generated world has at least two magical nexus objectives")
	var nexus_data := WorldLocationScript.get_type_data(ArcaneVictoryScript.NEXUS_LOCATION_ID)
	_check(not nexus_data.is_empty() and str(nexus_data.get("marker", "")) == "М", "leyline nexus has a distinct strategic map identity")

	var owned_sites: Array = [
		{"type": "leyline_nexus", "cleared": true, "cleared_by": -1},
		{"type": "leyline_nexus", "cleared": true, "cleared_by": -1},
		{"type": "leyline_nexus", "cleared": true, "cleared_by": 0},
	]
	var city_records: Array = [
		{"province_improvements": [{"id": "arcane_conduit", "cell": [-2, 1]}, {"id": "farm_plot", "cell": [-3, 0]}]},
	]
	var profile := {
		"affinities": {
			"order": 0, "chaos": 0, "nature": 0,
			"astral": 8, "shadow": 0, "materium": 3,
		},
	}
	_check(ArcaneVictoryScript.count_controlled_nexuses(owned_sites, -1) == 2, "only cleared nexus sites owned by the faction count")
	_check(ArcaneVictoryScript.count_arcane_conduits(city_records) == 1, "only completed arcane conduits contribute power")
	_check(ArcaneVictoryScript.get_affinity_power(profile) == 3, "astral and materium affinities increase arcane output")
	_check(
		ArcaneVictoryScript.calculate_turn_power(owned_sites, city_records, profile, -1) == 13,
		"two controlled nexuses, one conduit and affinity bonuses combine into bounded turn power"
	)
	_check(ArcaneVictoryScript.advance_progress(117, 13) == 120, "magical victory progress is capped at the victory threshold")
	_check(ArcaneVictoryScript.needs_containment(72) and not ArcaneVictoryScript.needs_containment(120), "containment pressure activates only before the final victory")
	_check(ArcaneVictoryScript.is_victory(120), "reaching the threshold ends the magical race")
	_check(ArcaneVictoryScript.get_progress_label(57) == "57/120", "magical progress has a stable compact display label")

	var state: Variant = CampaignStateScript.new()
	root.add_child(state)
	state.new_campaign(false)
	state._prevent_save_overwrite = true
	_check(state.campaign_winner_id == -2 and state.arcane_victory_progress == 0, "new campaigns start with an open magical race and no winner")
	state.player_diplomacy_profile = profile.duplicate(true)
	state.cities[0]["province_improvements"] = [{"id": "arcane_conduit", "cell": [-2, 1]}]
	state.neutral_locations.append({"id": "test_player_nexus", "type": "leyline_nexus", "cleared": true, "cleared_by": -1})
	state._advance_arcane_victory_race()
	_check(state.arcane_victory_progress == 9, "player progress advances from controlled sites, conduits and affinity")
	_check(state.last_arcane_power_gain == 9, "campaign records the player's per-turn arcane income")

	var leader: Dictionary = state.kingdoms[0]
	leader["arcane_victory_progress"] = 71
	state.kingdoms[0] = leader
	state.neutral_locations.append({"id": "test_ai_nexus", "type": "leyline_nexus", "cleared": true, "cleared_by": 0})
	state.turn_number = 3
	state._advance_arcane_victory_race()
	_check(int(state.kingdoms[0].get("arcane_victory_progress", 0)) >= 72, "AI kingdoms accumulate magical power from captured nexus sites")
	var containment_record: Dictionary = state.get_diplomacy_record(0)
	_check(
		DiplomacyCatalogScript.has_active_casus_belli(containment_record, state.turn_number, DiplomacyCatalogScript.PLAYER_ID),
		"the player receives a formal containment claim against a magical leader"
	)
	var containment_claims := DiplomacyCatalogScript.get_active_casus_belli(containment_record, state.turn_number, DiplomacyCatalogScript.PLAYER_ID)
	_check(not containment_claims.is_empty() and str(containment_claims[0].get("cause", "")) == "victory_race", "containment claim records the dedicated victory-race cause")

	var player_winner: Variant = CampaignStateScript.new()
	root.add_child(player_winner)
	player_winner.new_campaign(false)
	player_winner._prevent_save_overwrite = true
	player_winner.arcane_victory_progress = 116
	player_winner.neutral_locations.append({"id": "player-final-nexus", "type": "leyline_nexus", "cleared": true, "cleared_by": -1})
	player_winner._advance_arcane_victory_race()
	_check(player_winner.arcane_victory_progress == ArcaneVictoryScript.VICTORY_THRESHOLD, "player can complete the magical ascension race")
	_check(player_winner.campaign_winner_id == DiplomacyCatalogScript.PLAYER_ID, "player victory is stored as the campaign winner")
	var finished_turn: int = player_winner.turn_number
	player_winner.advance_campaign_turn()
	_check(player_winner.turn_number == finished_turn, "campaign turns stop after a magical victory")
	player_winner.free()

	var ai_winner: Variant = CampaignStateScript.new()
	root.add_child(ai_winner)
	ai_winner.new_campaign(false)
	ai_winner._prevent_save_overwrite = true
	var ai_leader: Dictionary = ai_winner.kingdoms[2]
	ai_leader["arcane_victory_progress"] = 119
	ai_winner.kingdoms[2] = ai_leader
	ai_winner.neutral_locations.append({"id": "ai-final-nexus", "type": "leyline_nexus", "cleared": true, "cleared_by": 2})
	ai_winner._advance_arcane_victory_race()
	_check(ai_winner.campaign_winner_id == 2, "AI kingdoms can win the magical race if the player fails to contain them")
	_check(ai_winner.get_campaign_winner_name() == str(ai_winner.kingdoms[2].get("name", "")), "AI magical victory resolves to the correct kingdom name")
	ai_winner.free()

	var fallback_kingdom: Dictionary = KingdomAIScript.create_initial_kingdoms(841207)[0]
	var legacy_kingdom := KingdomAIScript.normalize_kingdom({"name": "Старая держава"}, fallback_kingdom, 841207)
	_check(int(legacy_kingdom.get("arcane_victory_progress", -1)) == 0, "legacy AI kingdom records migrate with zero magical progress")
	_check(CampaignStateScript.SAVE_VERSION == 1, "magical race fields remain additive without a save version bump")

	state.free()
	if _failures == 0:
		print("All %d arcane victory checks passed." % _checks)
	else:
		push_error("%d of %d arcane victory checks failed." % [_failures, _checks])
	quit(0 if _failures == 0 else 1)
