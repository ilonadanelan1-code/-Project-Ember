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

	var gift_target_profile := {
		"alignment": "good",
		"personality_id": "honorable",
		"likes": ["generous", "gift"],
		"dislikes": ["treaty_breach"],
	}
	var gift_reaction := DiplomacyCatalogScript.calculate_action_reaction(gift_target_profile, ["gift", "generous"])
	_check(gift_reaction >= 4, "a ruler's stated likes and honorable personality improve the response to a gift")
	gift_target_profile["dislikes"] = ["treaty_breach", "evil", "chaos"]
	var hostile_actor_profile := {"alignment": "evil", "personality_id": "aggressor", "affinities": {"chaos": 4, "order": 0, "nature": 0, "astral": 0, "shadow": 0, "materium": 0}}
	var affinity_reaction := DiplomacyCatalogScript.calculate_action_reaction(gift_target_profile, ["gift", "generous"], hostile_actor_profile)
	_check(affinity_reaction < gift_reaction, "action reactions also account for the actor's alignment, personality and leading affinity")
	var memory_relations := DiplomacyCatalogScript.create_initial_relations(1, 841207)
	var gift_action := DiplomacyCatalogScript.apply_relationship_action(memory_relations, -1, 0, 4, "gift_small", ["gift", "generous"], 4, "Игрок отправил небольшой подарок.", gift_target_profile, "gift_relation_gained", DiplomacyCatalogScript.MAX_GIFT_RELATION_GAIN)
	_check(bool(gift_action.get("applied", false)) and int(gift_action.get("delta", 0)) > 4, "diplomatic action reaction adds a personality and preference modifier to a gift")
	var gift_memory_record := DiplomacyCatalogScript.get_record(memory_relations, -1, 0)
	_check(gift_memory_record.get("relationship_history", []) is Array and gift_memory_record.get("relationship_history", []).size() == 1, "gift is stored in the relationship's persistent event history")
	var duplicate_gift_action := DiplomacyCatalogScript.apply_relationship_action(memory_relations, -1, 0, 4, "gift_small", ["gift", "generous"], 4, "Повторный подарок.", gift_target_profile, "gift_relation_gained", DiplomacyCatalogScript.MAX_GIFT_RELATION_GAIN)
	_check(not bool(duplicate_gift_action.get("applied", true)), "the same diplomatic action cannot be applied twice in one turn")
	DiplomacyCatalogScript.apply_relationship_action(memory_relations, -1, 0, 5, "gift_medium", ["gift", "generous"], 20, "Игрок отправил щедрый подарок.", gift_target_profile, "gift_relation_gained", DiplomacyCatalogScript.MAX_GIFT_RELATION_GAIN)
	DiplomacyCatalogScript.apply_relationship_action(memory_relations, -1, 0, 6, "gift_large", ["gift", "generous"], 20, "Игрок отправил королевский дар.", gift_target_profile, "gift_relation_gained", DiplomacyCatalogScript.MAX_GIFT_RELATION_GAIN)
	gift_memory_record = DiplomacyCatalogScript.get_record(memory_relations, -1, 0)
	_check(int(gift_memory_record.get("gift_relation_gained", 0)) == DiplomacyCatalogScript.MAX_GIFT_RELATION_GAIN, "lifetime positive relation gain from gifts is capped")
	_check(gift_memory_record.get("relationship_history", []).size() <= DiplomacyCatalogScript.MAX_RELATIONSHIP_HISTORY, "relationship history has a strict per-pair size limit")

	var statement_relations := DiplomacyCatalogScript.create_initial_relations(1, 841207)
	var statement_record := DiplomacyCatalogScript.get_record(statement_relations, -1, 0)
	statement_record["relation"] = 70
	DiplomacyCatalogScript.set_record(statement_relations, -1, 0, statement_record)
	var friendship_statement := DiplomacyCatalogScript.update_public_statement(statement_relations, 0, -1, 8, "Северный Венец", "твоей державой")
	_check(str(friendship_statement.get("type", "")) == "friendship", "a ruler publicly declares friendship after crossing the relation threshold")
	var saved_statement_record := DiplomacyCatalogScript.get_record(statement_relations, 0, -1)
	_check(str(saved_statement_record.get("public_statement", {}).get("type", "")) == "friendship", "public diplomatic statements are stored in the persistent pair record")

	var migrated_memory := DiplomacyCatalogScript.normalize_relations({
		"-1:0": {
			"relation": 12,
			"relationship_history": [{"actor_id": -1, "target_id": 0, "turn": 3, "action": "gift_small", "message": "Legacy gift", "relation_delta": 5}],
			"last_gift_turn": 3,
			"gift_relation_gained": 5,
			"public_statement": {"type": "friendship", "text": "Старое заявление", "turn": 3},
		},
	}, 1, 841207)
	var migrated_memory_record := DiplomacyCatalogScript.get_record(migrated_memory, -1, 0)
	_check(migrated_memory_record.get("relationship_history", []).size() == 1, "legacy save migration preserves and normalizes diplomatic memories")
	_check(int(migrated_memory_record.get("last_gift_turn", 0)) == 3 and int(migrated_memory_record.get("gift_relation_gained", 0)) == 5, "gift cooldown and gift cap survive save normalization")
	_check(str(migrated_memory_record.get("public_statement", {}).get("type", "")) == "friendship", "legacy public diplomatic statements survive normalization")

	var gift_kingdoms := KingdomAIScript.create_initial_kingdoms(841207)
	var merchant_gift_kingdom: Dictionary = gift_kingdoms[1]
	merchant_gift_kingdom["diplomacy_profile"] = {"personality_id": "merchant", "likes": ["generous"], "dislikes": []}
	var gift_cities: Array = merchant_gift_kingdom.get("cities", [])
	var gift_capital: Dictionary = gift_cities[0]
	gift_capital["gold"] = 60
	gift_cities[0] = gift_capital
	merchant_gift_kingdom["cities"] = gift_cities
	gift_kingdoms[1] = merchant_gift_kingdom
	var ai_gift_relations := DiplomacyCatalogScript.create_initial_relations(gift_kingdoms.size(), 841207)
	var ai_gift_record := DiplomacyCatalogScript.get_record(ai_gift_relations, -1, 1)
	ai_gift_record["relation"] = 50
	DiplomacyCatalogScript.set_record(ai_gift_relations, -1, 1, ai_gift_record)
	var ai_gift_offers: Array[Dictionary] = []
	var ai_gift_result := DiplomacyCatalogScript.process_turn(ai_gift_relations, gift_kingdoms, 21, 841207, 100.0, ai_gift_offers, [], {"likes": ["generous"], "personality_id": "honorable"})
	_check(ai_gift_result.get("gift_transfers", []).size() == 1, "a friendly merchant AI can send a real gold gift to the player")
	_check(int(gift_kingdoms[1].get("cities", [])[0].get("gold", 0)) == 40, "AI gift is paid from the sender's capital treasury")
	_check(not DiplomacyCatalogScript.get_record(ai_gift_relations, -1, 1).get("relationship_history", []).is_empty(), "AI gifts are also recorded in relationship memory")


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

	var merchant_kingdom: Dictionary = kingdoms[1]
	merchant_kingdom["diplomacy_profile"] = DiplomacyCatalogScript.normalize_leader_profile(
		{"personality_id": "merchant"},
		1,
		merchant_kingdom.get("faction", {}),
		int(merchant_kingdom.get("military_doctrine", 0)),
		841207
	)
	kingdoms[1] = merchant_kingdom
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

	var border_claims := DiplomacyCatalogScript.get_active_casus_belli(
		DiplomacyCatalogScript.get_record(border_relations, -1, 0),
		5,
		0
	)
	_check(not border_claims.is_empty(), "aggressive border pressure creates a visible casus belli")
	_check(str(border_claims[0].get("cause", "")) == "border_encroachment", "border claim records its concrete reason")
	var outpost_claim_relations := DiplomacyCatalogScript.create_initial_relations(1, 841207)
	var outpost_claim_kingdoms: Array[Dictionary] = [
		{"id": 0, "alive": true, "name": "Пограничная держава", "cities": [{"cell": [3, 0]}], "outposts": [], "army": []},
	]
	var player_outpost_sources: Array[Vector2i] = [Vector2i(2, 0)]
	DiplomacyCatalogScript.process_turn(
		outpost_claim_relations,
		outpost_claim_kingdoms,
		5,
		841207,
		100.0,
		no_offers,
		border_player_sources,
		{},
		player_outpost_sources
	)
	var outpost_claims := DiplomacyCatalogScript.get_active_casus_belli(
		DiplomacyCatalogScript.get_record(outpost_claim_relations, -1, 0),
		5,
		0
	)
	_check(not outpost_claims.is_empty() and str(outpost_claims[0].get("cause", "")) == "outpost_encroachment", "a player outpost near an AI city creates a distinct outpost encroachment claim")

	var no_claim_legacy := DiplomacyCatalogScript.normalize_relations({"-1:0": {"relation": 10}}, 2, 841207)
	_check(DiplomacyCatalogScript.get_record(no_claim_legacy, -1, 0).get("casus_belli", []) is Array, "legacy relationship records receive an empty casus belli list")
	var manual_claim_relations := DiplomacyCatalogScript.create_initial_relations(2, 841207)
	var first_claim := DiplomacyCatalogScript.create_casus_belli(manual_claim_relations, 0, 1, "treaty_breach", 4, 3)
	var duplicate_claim := DiplomacyCatalogScript.create_casus_belli(manual_claim_relations, 0, 1, "treaty_breach", 5, 2)
	_check(not first_claim.is_empty() and first_claim == duplicate_claim, "duplicate causes do not stack multiple active claims")
	_check(DiplomacyCatalogScript.has_active_casus_belli(DiplomacyCatalogScript.get_record(manual_claim_relations, 0, 1), 12, 0), "casus belli remains active through its eighth turn")
	_check(not DiplomacyCatalogScript.has_active_casus_belli(DiplomacyCatalogScript.get_record(manual_claim_relations, 0, 1), 13, 0), "casus belli expires after its eight-turn window")


	var ai_war_relations := DiplomacyCatalogScript.create_initial_relations(2, 841207)
	var hostile_ai_record := DiplomacyCatalogScript.get_record(ai_war_relations, 0, 1)
	hostile_ai_record["relation"] = -62
	DiplomacyCatalogScript.set_record(ai_war_relations, 0, 1, hostile_ai_record)
	DiplomacyCatalogScript.process_turn(ai_war_relations, ai_deal_kingdoms, 5, 841207, 100.0, no_offers)
	_check(str(DiplomacyCatalogScript.get_record(ai_war_relations, 0, 1).get("treaty", "")) == "war", "aggressive AI can declare war on a hostile neighbouring realm")
	var ai_war_record := DiplomacyCatalogScript.get_record(ai_war_relations, 0, 1)
	_check(str(ai_war_record.get("war_reason", "")) == "border_encroachment", "AI war record stores the casus belli that justified the declaration")
	_check(DiplomacyCatalogScript.get_active_casus_belli(ai_war_record, 5).is_empty(), "declaring war consumes the claim used as its justification")
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

	var call_to_war_kingdoms: Array[Dictionary] = [
		{"id": 0, "alive": true, "name": "Союзник", "cities": [{"cell": [0, 0]}], "army": []},
		{"id": 1, "alive": true, "name": "Противник", "cities": [{"cell": [2, 0]}], "army": []},
	]
	var call_to_war_relations := DiplomacyCatalogScript.create_initial_relations(2, 841207)
	DiplomacyCatalogScript.set_treaty(call_to_war_relations, -1, 0, "alliance", 1, 8)
	var call_war_record := DiplomacyCatalogScript.get_record(call_to_war_relations, 0, 1)
	call_war_record["relation"] = -62
	DiplomacyCatalogScript.set_record(call_to_war_relations, 0, 1, call_war_record)
	var call_offers: Array[Dictionary] = []
	DiplomacyCatalogScript.process_turn(call_to_war_relations, call_to_war_kingdoms, 5, 841207, 100.0, call_offers)
	_check(str(DiplomacyCatalogScript.get_record(call_to_war_relations, 0, 1).get("treaty", "")) == "war", "border claim can trigger the AI-AI war that activates allied calls")
	var war_call_offer: Dictionary = {}
	for offer_value in call_offers:
		if str(offer_value.get("action", "")) == "call_to_war":
			war_call_offer = offer_value
			break
	_check(not war_call_offer.is_empty(), "AI ally sends a formal call to war to the player")
	_check(str(war_call_offer.get("war_cause", "")) == "border_encroachment", "war call preserves the original border claim after declaration consumes it")
	_check(int(war_call_offer.get("expires_turn", 0)) == 8, "war call gives the player three turns to answer")


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
	_check(not state.player_diplomacy_profile.is_empty(), "new campaigns initialize a persistent player diplomatic profile")
	_check(state.player_diplomacy_profile.has("alignment") and state.player_diplomacy_profile.has("affinities"), "player profile includes alignment and affinity data")
	_check(state.get_diplomacy_action_preview(0, "declare_war").get("available", false), "player can declare war when no truce blocks it")
	var declaration: Dictionary = state.perform_diplomacy_action("declare_war", 0)
	_check(bool(declaration.get("ok", false)), "player war declaration succeeds through campaign state")
	_check(str(state.get_diplomacy_record(0).get("treaty", "")) == "war", "war declaration updates the persisted pair record")
	_check(str(state.get_diplomacy_record(0).get("war_reason", "")) == "player_declaration", "war record stores the declared cause")
	_check(state.get_diplomacy_action_preview(0, "offer_peace").get("available", false), "peace proposal becomes available while at war")
	_check(CampaignStateScript.SAVE_VERSION == 1, "optional diplomacy fields preserve legacy save schema version")

	var call_state: Variant = CampaignStateScript.new()
	root.add_child(call_state)
	call_state.prepare_new_campaign(true)
	call_state.faction_setup_pending = false
	call_state.turn_number = 5
	DiplomacyCatalogScript.set_treaty(call_state.diplomacy_relations, -1, 1, "alliance", 5, 8)
	var defending_war := DiplomacyCatalogScript.get_record(call_state.diplomacy_relations, 1, 0)
	defending_war["treaty"] = "war"
	defending_war["war_initiator_id"] = 0
	defending_war["war_target_id"] = 1
	DiplomacyCatalogScript.set_record(call_state.diplomacy_relations, 1, 0, defending_war)
	var ally_relation_before := int(call_state.get_diplomacy_record(1).get("relation", 0))
	call_state.pending_diplomacy_offers.append({
		"offer_id": "ally-call-decline",
		"kingdom_id": 1,
		"enemy_kingdom_id": 0,
		"action": "call_to_war",
		"war_cause": "ally_attacked",
		"created_turn": 5,
		"expires_turn": 8,
	})
	var declined_call: Dictionary = call_state.respond_to_diplomacy_offer("ally-call-decline", false)
	_check(bool(declined_call.get("ok", false)), "player can explicitly decline a formal allied war call")
	_check(
		int(call_state.get_diplomacy_record(1).get("relation", 0)) == ally_relation_before - DiplomacyCatalogScript.WAR_CALL_REFUSAL_PENALTY,
		"refusing a call to war reduces the caller's diplomatic relation"
	)
	call_state.pending_diplomacy_offers.append({
		"offer_id": "ally-call-accept",
		"kingdom_id": 1,
		"enemy_kingdom_id": 0,
		"action": "call_to_war",
		"war_cause": "ally_attacked",
		"created_turn": 5,
		"expires_turn": 8,
	})
	var accepted_call: Dictionary = call_state.respond_to_diplomacy_offer("ally-call-accept", true)
	_check(bool(accepted_call.get("ok", false)), "player can accept an allied war call while the alliance and war remain active")
	_check(str(call_state.get_diplomacy_record(0).get("treaty", "")) == "war", "accepting a call to war enters the player into the ally's conflict")
	_check(str(call_state.get_diplomacy_record(0).get("war_reason", "")) == "ally_attacked", "joined war retains the original conflict cause")
	_check(str(call_state.get_diplomacy_record(0).get("war_join_reason", "")) == "ally_call", "joined war separately records that the player entered through an allied call")
	call_state.free()


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
