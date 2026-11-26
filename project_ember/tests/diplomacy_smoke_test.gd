extends SceneTree

const DiplomacyCatalogScript = preload("res://scripts/diplomacy_catalog.gd")
const KingdomAIScript = preload("res://scripts/kingdom_ai.gd")
const CampaignStateScript = preload("res://scripts/campaign_state.gd")

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
	var kingdoms := KingdomAIScript.create_initial_kingdoms(841207)
	var relations := DiplomacyCatalogScript.create_initial_relations(kingdoms.size(), 841207)
	_check(kingdoms.size() == 9, "diplomacy starts with the existing nine AI kingdoms")
	_check(relations.size() == 45, "relationship matrix contains nine player pairs and 36 AI pairs")
	_check(relations.has("-1:0") and relations.has("7:8"), "pair keys are canonical and include player and AI pairs")
	_check(DiplomacyCatalogScript.personality_id_for_kingdom(0) == "aggressor", "first realm receives the deterministic Aggressor personality")
	_check(DiplomacyCatalogScript.personality_id_for_kingdom(1) == "merchant", "second realm receives the deterministic Merchant personality")

	var player_profile := DiplomacyCatalogScript.create_leader_profile(
		DiplomacyCatalogScript.PLAYER_ID,
		{"people_id": "riverfolk", "culture_id": "mercantile", "trait_ids": ["disciplined", "guild_charters"]},
		0,
		841207
	)
	var saved_profile: Dictionary = kingdoms[0].get("diplomacy_profile", {})
	_check(DiplomacyCatalogScript.ALIGNMENTS.has(str(saved_profile.get("alignment", ""))), "every AI ruler receives a valid persistent alignment")
	_check(saved_profile.get("affinities", {}) is Dictionary and saved_profile.get("affinities", {}).size() == 6, "every AI ruler receives all six affinity scores")
	_check(DiplomacyCatalogScript.PERSONALITY_IDS.has(str(saved_profile.get("personality_id", ""))), "AI ruler personality is derived and stored in the kingdom profile")
	var repeated_kingdoms := KingdomAIScript.create_initial_kingdoms(841207)
	_check(saved_profile == repeated_kingdoms[0].get("diplomacy_profile", {}), "leader profiles are deterministic for the same world seed")
	var personality_diversity: Dictionary = {}
	for kingdom in kingdoms:
		var profile_value: Variant = kingdom.get("diplomacy_profile", {})
		if profile_value is Dictionary:
			personality_diversity[str(profile_value.get("personality_id", ""))] = true
	_check(personality_diversity.size() >= 2, "different rulers can develop different personalities from alignment and affinity")

	var normalized_legacy_kingdom := KingdomAIScript.normalize_kingdom({"id": 0, "name": "Старое королевство"}, kingdoms[0], 841207)
	var migrated_profile: Dictionary = normalized_legacy_kingdom.get("diplomacy_profile", {})
	_check(DiplomacyCatalogScript.ALIGNMENTS.has(str(migrated_profile.get("alignment", ""))), "legacy AI kingdom records gain a valid profile during normalization")
	_check(migrated_profile == saved_profile, "legacy profile migration is deterministic and does not reroll rulers")

	var profile_relations := DiplomacyCatalogScript.create_initial_relations(
		kingdoms.size(),
		841207,
		kingdoms,
		player_profile
	)
	var profiled_record := DiplomacyCatalogScript.get_record(profile_relations, DiplomacyCatalogScript.PLAYER_ID, 0)
	var opinion_value: Variant = profiled_record.get("opinion_modifiers", {})
	var opinion: Dictionary = opinion_value if opinion_value is Dictionary else {}
	_check(opinion.has("alignment") and opinion.has("affinity") and opinion.has("personality") and opinion.has("preferences"), "relationship record explains alignment, affinity, personality and preference modifiers")
	var profiled_relation_before := int(profiled_record.get("relation", 0))
	DiplomacyCatalogScript.refresh_relationship_modifiers(profile_relations, kingdoms, player_profile)
	DiplomacyCatalogScript.refresh_relationship_modifiers(profile_relations, kingdoms, player_profile)
	_check(int(DiplomacyCatalogScript.get_record(profile_relations, DiplomacyCatalogScript.PLAYER_ID, 0).get("relation", 0)) == profiled_relation_before, "refreshing relationship modifiers never stacks the same bonus twice")

	var migrated_profile_relations := DiplomacyCatalogScript.normalize_relations(
		{"-1:0": {"relation": 40, "treaty": "peace"}},
		kingdoms.size(),
		841207,
		kingdoms,
		player_profile
	)
	var migrated_opinion_record := DiplomacyCatalogScript.get_record(migrated_profile_relations, DiplomacyCatalogScript.PLAYER_ID, 0)
	var migrated_opinion_value: Variant = migrated_opinion_record.get("opinion_modifiers", {})
	var migrated_opinion: Dictionary = migrated_opinion_value if migrated_opinion_value is Dictionary else {}
	_check(migrated_opinion.has("total"), "legacy diplomatic records are upgraded with an opinion breakdown")
	_check(
		int(migrated_opinion_record.get("relation", 0)) == clampi(40 + int(migrated_opinion.get("total", 0)), -100, 100),
		"legacy relation receives profile compatibility exactly once"
	)

	var compatible_profile := {
		"alignment": "good",
		"affinities": {"order": 5, "chaos": 0, "nature": 2, "astral": 0, "shadow": 0, "materium": 1},
		"personality_id": "honorable",
		"likes": ["honorable", "order"],
		"dislikes": ["aggressor"],
	}
	var opposed_profile := {
		"alignment": "evil",
		"affinities": {"order": 0, "chaos": 5, "nature": 0, "astral": 0, "shadow": 3, "materium": 0},
		"personality_id": "aggressor",
		"likes": ["aggressor", "chaos"],
		"dislikes": ["honorable", "good"],
	}
	var compatible_opinion := DiplomacyCatalogScript.calculate_relationship_modifiers(compatible_profile, compatible_profile)
	var opposed_opinion := DiplomacyCatalogScript.calculate_relationship_modifiers(compatible_profile, opposed_profile)
	_check(int(compatible_opinion.get("total", 0)) > int(opposed_opinion.get("total", 0)), "aligned leaders with compatible affinities prefer each other over opposing personalities")

	var common_ally_relations := DiplomacyCatalogScript.create_initial_relations(3, 841207)
	DiplomacyCatalogScript.set_treaty(common_ally_relations, 0, 2, "alliance", 1, 8)
	DiplomacyCatalogScript.set_treaty(common_ally_relations, 1, 2, "alliance", 1, 8)
	var common_ally_opinion := DiplomacyCatalogScript.calculate_relationship_modifiers(
		compatible_profile,
		compatible_profile,
		common_ally_relations,
		0,
		1
	)
	_check(int(common_ally_opinion.get("shared_allies", 0)) == 2, "leaders gain affinity when they share a formal ally")
	var common_enemy_relations := DiplomacyCatalogScript.create_initial_relations(3, 841207)
	DiplomacyCatalogScript.set_treaty(common_enemy_relations, 0, 2, "war", 1)
	DiplomacyCatalogScript.set_treaty(common_enemy_relations, 1, 2, "war", 1)
	var common_enemy_opinion := DiplomacyCatalogScript.calculate_relationship_modifiers(
		compatible_profile,
		compatible_profile,
		common_enemy_relations,
		0,
		1
	)
	_check(int(common_enemy_opinion.get("shared_enemies", 0)) == 3, "leaders gain affinity when they share an active enemy")


	var initial_record := DiplomacyCatalogScript.get_record(relations, -1, 1)
	_check(int(initial_record.get("relation", -100)) == 18, "merchant begins with a modest positive player relationship")
	DiplomacyCatalogScript.set_treaty(relations, -1, 1, "trade", 3, DiplomacyCatalogScript.TRADE_DURATION)
	var trade_record := DiplomacyCatalogScript.get_record(relations, -1, 1)
	_check(str(trade_record.get("treaty", "")) == "trade", "trade treaty is stored for the correct pair")
	_check(int(trade_record.get("treaty_until", 0)) == 9, "trade treaty uses the six-turn duration")
	_check(DiplomacyCatalogScript.treaty_is_active(trade_record, 9), "trade remains active through its final contracted turn")
	_check(not DiplomacyCatalogScript.treaty_is_active(trade_record, 10), "trade is inactive after its expiry turn")

	var alliance_chance := DiplomacyCatalogScript.acceptance_chance("offer_alliance", {"relation": 60}, 3, 100.0, 80.0)
	_check(alliance_chance >= 5 and alliance_chance <= 95, "AI acceptance chance is clamped to five through 95 percent")
	var deterministic_a := DiplomacyCatalogScript.deterministic_acceptance("offer_trade", 1, 8, 841207, 55)
	var deterministic_b := DiplomacyCatalogScript.deterministic_acceptance("offer_trade", 1, 8, 841207, 55)
	_check(deterministic_a == deterministic_b, "AI negotiation rolls are deterministic for the same campaign state")

	var normalized := DiplomacyCatalogScript.normalize_relations({"-1:1": {"relation": 999, "treaty": "unknown"}}, 9, 841207)
	var normalized_record := DiplomacyCatalogScript.get_record(normalized, -1, 1)
	_check(int(normalized_record.get("relation", 0)) == 100, "relationship values are clamped when loading saves")
	_check(str(normalized_record.get("treaty", "")) == "peace", "unknown treaty IDs fall back to peace")
	_check(normalized.size() == 45, "legacy or partial relationship data receives every missing pair")

	var pending: Array[Dictionary] = []
	var offer_relations := DiplomacyCatalogScript.create_initial_relations(kingdoms.size(), 841207)
	var processed := DiplomacyCatalogScript.process_turn(offer_relations, kingdoms, 5, 841207, 100.0, pending)
	_check(processed.has("events") and processed.has("offers"), "diplomacy turn processor returns events and pending offers")
	_check(not pending.is_empty() and str(pending[0].get("action", "")) == "offer_trade", "merchant AI can send a concrete trade proposal")

	var ai_deal_kingdoms: Array[Dictionary] = [
		{"id": 0, "alive": true, "name": "Первая держава", "cities": [{"cell": [0, 0]}]},
		{"id": 1, "alive": true, "name": "Вторая держава", "cities": [{"cell": [2, 0]}]},
	]
	var ai_deal_relations := DiplomacyCatalogScript.create_initial_relations(2, 841207)
	var no_offers: Array[Dictionary] = []
	var ai_pair := DiplomacyCatalogScript.get_record(ai_deal_relations, 0, 1)
	ai_pair["relation"] = 35
	DiplomacyCatalogScript.set_record(ai_deal_relations, 0, 1, ai_pair)
	DiplomacyCatalogScript.process_turn(ai_deal_relations, ai_deal_kingdoms, 2, 841207, 100.0, no_offers)
	var ai_trade_record := DiplomacyCatalogScript.get_record(ai_deal_relations, 0, 1)
	_check(str(ai_trade_record.get("treaty", "")) == "trade", "two AI realms can sign a trade agreement from their relation score")
	_check(int(ai_trade_record.get("relation", 0)) >= 35, "AI-AI treaty creation preserves the relation score updated this turn")

	var border_kingdoms: Array[Dictionary] = [
		{"id": 0, "alive": true, "name": "Пограничная держава", "cities": [{"cell": [1, 0]}], "army": []},
		{"id": 1, "alive": true, "name": "Соседняя держава", "cities": [{"cell": [2, 0]}], "army": []},
	]
	var border_relations := DiplomacyCatalogScript.create_initial_relations(2, 841207)
	var border_player_sources: Array[Vector2i] = [Vector2i.ZERO]
	var border_record := DiplomacyCatalogScript.get_record(border_relations, -1, 0)
	border_record["relation"] = -40
	DiplomacyCatalogScript.set_record(border_relations, -1, 0, border_record)
	DiplomacyCatalogScript.process_turn(border_relations, border_kingdoms, 5, 841207, 100.0, no_offers, border_player_sources)
	_check(int(DiplomacyCatalogScript.get_record(border_relations, -1, 0).get("relation", 0)) == -42, "aggressive AI applies deterministic border tension near player territory")

	var ai_war_relations := DiplomacyCatalogScript.create_initial_relations(2, 841207)
	var hostile_ai_record := DiplomacyCatalogScript.get_record(ai_war_relations, 0, 1)
	hostile_ai_record["relation"] = -62
	DiplomacyCatalogScript.set_record(ai_war_relations, 0, 1, hostile_ai_record)
	DiplomacyCatalogScript.process_turn(ai_war_relations, ai_deal_kingdoms, 5, 841207, 100.0, no_offers)
	_check(str(DiplomacyCatalogScript.get_record(ai_war_relations, 0, 1).get("treaty", "")) == "war", "aggressive AI can declare war on a hostile neighbouring realm")
	var exhausted_record := DiplomacyCatalogScript.get_record(ai_war_relations, 0, 1)
	exhausted_record["war_exhaustion"] = 60
	DiplomacyCatalogScript.set_record(ai_war_relations, 0, 1, exhausted_record)
	var ai_peace_resolved := false
	for peace_turn in range(6, 40):
		DiplomacyCatalogScript.process_turn(ai_war_relations, ai_deal_kingdoms, peace_turn, 841207, 100.0, no_offers)
		if str(DiplomacyCatalogScript.get_record(ai_war_relations, 0, 1).get("treaty", "")) == "peace":
			ai_peace_resolved = true
			break
	_check(ai_peace_resolved, "AI-AI wars can resolve into a four-turn truce after war exhaustion")

	var player_war_relations := DiplomacyCatalogScript.create_initial_relations(1, 841207)
	var hostile_player_record := DiplomacyCatalogScript.get_record(player_war_relations, -1, 0)
	hostile_player_record["relation"] = -53
	DiplomacyCatalogScript.set_record(player_war_relations, -1, 0, hostile_player_record)
	var one_kingdom: Array[Dictionary] = [border_kingdoms[0]]
	DiplomacyCatalogScript.process_turn(player_war_relations, one_kingdom, 20, 841207, 100.0, no_offers, border_player_sources)
	_check(str(DiplomacyCatalogScript.get_record(player_war_relations, -1, 0).get("treaty", "")) == "war", "aggressive AI can declare war after sustained border tension")

	var stale_offer_state: Variant = CampaignStateScript.new()
	root.add_child(stale_offer_state)
	stale_offer_state.prepare_new_campaign(true)
	stale_offer_state.faction_setup_pending = false
	var stale_kingdom_id := 2
	DiplomacyCatalogScript.set_treaty(stale_offer_state.diplomacy_relations, -1, stale_kingdom_id, "war", stale_offer_state.turn_number)
	stale_offer_state.pending_diplomacy_offers.append({
		"offer_id": "stale:trade:1",
		"kingdom_id": stale_kingdom_id,
		"action": "offer_trade",
		"created_turn": stale_offer_state.turn_number,
		"expires_turn": stale_offer_state.turn_number + 2,
	})
	var stale_response: Dictionary = stale_offer_state.respond_to_diplomacy_offer("stale:trade:1", true)
	_check(not bool(stale_response.get("ok", false)), "stale trade offers are rejected after diplomatic conditions change")
	_check(stale_offer_state.pending_diplomacy_offers.is_empty(), "invalid pending offers are removed after failed acceptance")
	stale_offer_state.free()

	var state: Variant = CampaignStateScript.new()
	root.add_child(state)
	state.prepare_new_campaign(true)
	state.faction_setup_pending = false
	_check(state.diplomacy_relations.size() == 45, "new campaigns initialize all diplomacy relationships")
	_check(state.get_diplomacy_action_preview(0, "declare_war").get("available", false), "player can declare war when no truce blocks it")
	var declaration: Dictionary = state.perform_diplomacy_action("declare_war", 0)
	_check(bool(declaration.get("ok", false)), "player war declaration succeeds through campaign state")
	_check(str(state.get_diplomacy_record(0).get("treaty", "")) == "war", "war declaration updates the persisted pair record")
	_check(str(state.get_diplomacy_record(0).get("war_reason", "")) == "player_declaration", "war record stores the declared cause")
	_check(state.get_diplomacy_action_preview(0, "offer_peace").get("available", false), "peace proposal becomes available while at war")
	_check(CampaignStateScript.SAVE_VERSION == 1, "optional diplomacy fields preserve legacy save schema version")

	var offer := {
		"offer_id": "1:offer_trade:4",
		"kingdom_id": 1,
		"action": "offer_trade",
		"created_turn": state.turn_number,
		"expires_turn": state.turn_number + 2,
	}
	state.pending_diplomacy_offers.append(offer)
	var response: Dictionary = state.respond_to_diplomacy_offer("1:offer_trade:4", true)
	_check(bool(response.get("ok", false)), "player can accept an AI trade offer")
	_check(str(state.get_diplomacy_record(1).get("treaty", "")) == "trade", "accepted AI trade offer activates the trade treaty")
	_check(state.pending_diplomacy_offers.is_empty(), "accepted offer is removed from the pending queue")
	_check(str(state.get_diplomacy_record(1).get("treaty", "")) == "trade", "accepted offers are reflected in the current relationship record")

	state.free()
	if _failures > 0:
		printerr("Diplomacy checks failed: %d/%d" % [_failures, _checks])
		quit(1)
	else:
		print("All %d diplomacy checks passed." % _checks)
		quit(0)
