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
	var stale_response := stale_offer_state.respond_to_diplomacy_offer("stale:trade:1", true)
	_check(not bool(stale_response.get("ok", false)), "stale trade offers are rejected after diplomatic conditions change")
	_check(stale_offer_state.pending_diplomacy_offers.is_empty(), "invalid pending offers are removed after failed acceptance")
	stale_offer_state.free()

	var state: Variant = CampaignStateScript.new()
	root.add_child(state)
	state.prepare_new_campaign(true)
	state.faction_setup_pending = false
	_check(state.diplomacy_relations.size() == 45, "new campaigns initialize all diplomacy relationships")
	_check(state.get_diplomacy_action_preview(0, "declare_war").get("available", false), "player can declare war when no truce blocks it")
	var declaration := state.perform_diplomacy_action("declare_war", 0)
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
	var response := state.respond_to_diplomacy_offer("1:offer_trade:4", true)
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
