extends RefCounted
class_name EmberCampaignVictoryCatalog

## Campaign victory conditions. This module only reads existing campaign systems:
## three city resources, current diplomacy treaties and surviving campaign units.

const CityDevelopment = preload("res://scripts/city_development_catalog.gd")
const FactionCatalog = preload("res://scripts/faction_catalog.gd")
const DiplomacyCatalog = preload("res://scripts/diplomacy_catalog.gd")

const MIN_CAMPAIGN_TURN := 25
const MILITARY_KINGDOMS_REQUIRED := 6
const MILITARY_ARMY_REQUIRED := 8
const ECONOMIC_METROPOLISES_REQUIRED := 2
const ECONOMIC_GOLD_REQUIRED := 600
const ECONOMIC_NET_GOLD_REQUIRED := 12
const ECONOMIC_HOLD_TURNS_REQUIRED := 5
const DIPLOMATIC_FRIENDLY_REQUIRED := 5
const DIPLOMATIC_TREATIES_REQUIRED := 3
const DIPLOMATIC_MAJOR_TREATIES_REQUIRED := 2
const DIPLOMATIC_HOLD_TURNS_REQUIRED := 3
const PLAYER_ID := -1
const VICTORY_TYPES := ["military", "economic", "diplomatic"]
const VICTORY_STATUSES := ["none", "offered", "continued", "claimed"]


static func create_state() -> Dictionary:
	return {
		"military_wins": [],
		"economic_hold_turns": 0,
		"diplomatic_hold_turns": 0,
		"unlocked_types": [],
		"status": "none",
		"type": "",
		"turn": 0,
	}


static func normalize_state(raw: Variant) -> Dictionary:
	var result := create_state()
	if not raw is Dictionary:
		return result
	var source: Dictionary = raw
	var wins: Array[int] = []
	var raw_wins: Variant = source.get("military_wins", [])
	if raw_wins is Array:
		for value in raw_wins:
			var kingdom_id := int(value)
			if kingdom_id >= 0 and kingdom_id < 9 and not wins.has(kingdom_id):
				wins.append(kingdom_id)
	wins.sort()
	result["military_wins"] = wins
	result["economic_hold_turns"] = clampi(int(source.get("economic_hold_turns", 0)), 0, 1000000)
	result["diplomatic_hold_turns"] = clampi(int(source.get("diplomatic_hold_turns", 0)), 0, 1000000)
	var unlocked: Array[String] = []
	var raw_unlocked: Variant = source.get("unlocked_types", [])
	if raw_unlocked is Array:
		for value in raw_unlocked:
			var type_id := str(value)
			if VICTORY_TYPES.has(type_id) and not unlocked.has(type_id):
				unlocked.append(type_id)
	result["unlocked_types"] = unlocked
	var status := str(source.get("status", "none"))
	result["status"] = status if VICTORY_STATUSES.has(status) else "none"
	var type_id := str(source.get("type", ""))
	result["type"] = type_id if VICTORY_TYPES.has(type_id) else ""
	result["turn"] = clampi(int(source.get("turn", 0)), 0, 100000000)
	if result["status"] == "claimed" or result["status"] == "continued":
		if str(result["type"]).is_empty():
			result["status"] = "none"
			result["turn"] = 0
	return result


static func record_military_victory(state: Dictionary, kingdom_id: int) -> void:
	if kingdom_id < 0 or kingdom_id >= 9:
		return
	var normalized := normalize_state(state)
	var wins: Array = normalized.get("military_wins", [])
	if not wins.has(kingdom_id):
		wins.append(kingdom_id)
	wins.sort()
	normalized["military_wins"] = wins
	state.clear()
	state.merge(normalized, true)


static func evaluate_turn(
		state: Dictionary,
		turn_number: int,
		cities: Array,
		player_units: Array,
		player_faction: Dictionary,
		diplomacy_relations: Dictionary,
		kingdoms: Array,
		army_upkeep: int
) -> Dictionary:
	var normalized := normalize_state(state)
	var metrics := calculate_metrics(
		turn_number, cities, player_units, player_faction,
		diplomacy_relations, kingdoms, army_upkeep
	)
	var unlocked: Array = normalized.get("unlocked_types", [])
	if turn_number >= MIN_CAMPAIGN_TURN:
		if bool(metrics.get("military_ready", false)) and not unlocked.has("military"):
			unlocked.append("military")
		if bool(metrics.get("economic_ready", false)) and not unlocked.has("economic"):
			unlocked.append("economic")
		if bool(metrics.get("diplomatic_ready", false)) and not unlocked.has("diplomatic"):
			unlocked.append("diplomatic")
	normalized["unlocked_types"] = unlocked
	if str(normalized.get("status", "none")) == "none" and not unlocked.is_empty():
		normalized["status"] = "offered"
	state.clear()
	state.merge(normalized, true)
	metrics["unlocked_types"] = unlocked.duplicate()
	metrics["status"] = str(normalized.get("status", "none"))
	metrics["selected_type"] = str(normalized.get("type", ""))
	return metrics


static func calculate_metrics(
		turn_number: int,
		cities: Array,
		player_units: Array,
		player_faction: Dictionary,
		diplomacy_relations: Dictionary,
		kingdoms: Array,
		army_upkeep: int
) -> Dictionary:
	var military_wins: Array[int] = []
	var metropolis_count := 0
	var total_gold := 0
	var city_gold_income := 0
	for city_value in cities:
		if not city_value is Dictionary:
			continue
		var city: Dictionary = city_value
		if CityDevelopment.get_city_level(int(city.get("population", 1))) >= 3:
			metropolis_count += 1
		total_gold += maxi(0, int(city.get("gold", 0)))
		var raw_buildings: Variant = city.get("buildings", [])
		var buildings: Array = raw_buildings if raw_buildings is Array else []
		var raw_levels: Variant = city.get("building_levels", {})
		var levels: Dictionary = raw_levels if raw_levels is Dictionary else {}
		var raw_improvements: Variant = city.get("province_improvements", [])
		var improvements: Array = raw_improvements if raw_improvements is Array else []
		var income := CityDevelopment.get_city_income(
			buildings, levels, improvements, str(city.get("specialization", ""))
		)
		income = FactionCatalog.apply_income_modifiers(income, buildings, player_faction)
		city_gold_income += int(income.get("gold", 0))

	var friendly_kingdoms := 0
	var active_positive_treaties := 0
	var major_treaties := 0
	var diplomacy_gold_income := 0
	for kingdom_id in range(mini(kingdoms.size(), 9)):
		var kingdom_value: Variant = kingdoms[kingdom_id]
		if not kingdom_value is Dictionary or not bool(kingdom_value.get("alive", true)):
			continue
		var relation_record := DiplomacyCatalog.get_record(diplomacy_relations, PLAYER_ID, kingdom_id)
		if int(relation_record.get("relation", 0)) >= 55:
			friendly_kingdoms += 1
		if not DiplomacyCatalog.treaty_is_active(relation_record, turn_number):
			continue
		var treaty_id := str(relation_record.get("treaty", "peace"))
		if treaty_id == "trade" or treaty_id == "alliance":
			active_positive_treaties += 1
			diplomacy_gold_income += 2
		if treaty_id == "alliance":
			major_treaties += 1
		elif treaty_id == "vassal" and int(relation_record.get("overlord_id", -99)) == PLAYER_ID:
			active_positive_treaties += 1
			major_treaties += 1

	var net_gold_income := city_gold_income + diplomacy_gold_income - maxi(0, army_upkeep)
	var military_ready := false
	var economic_ready := false
	var diplomatic_ready := false
	var military_count := 0
	var economic_checks := 0
	var diplomatic_checks := 0
	# The persistent win list is read from state by the caller; this metric uses
	# the currently available army and the caller's stored unique-win count.
	military_count = 0
	if turn_number >= MIN_CAMPAIGN_TURN:
		economic_checks += 1 if metropolis_count >= ECONOMIC_METROPOLISES_REQUIRED else 0
		economic_checks += 1 if total_gold >= ECONOMIC_GOLD_REQUIRED else 0
		economic_checks += 1 if net_gold_income >= ECONOMIC_NET_GOLD_REQUIRED else 0
		diplomatic_checks += 1 if friendly_kingdoms >= DIPLOMATIC_FRIENDLY_REQUIRED else 0
		diplomatic_checks += 1 if active_positive_treaties >= DIPLOMATIC_TREATIES_REQUIRED else 0
		diplomatic_checks += 1 if major_treaties >= DIPLOMATIC_MAJOR_TREATIES_REQUIRED else 0
		diplomatic_ready = diplomatic_checks == 3
		economic_ready = economic_checks == 3
	return {
		"turn": turn_number,
		"military_wins": military_count,
		"military_required": MILITARY_KINGDOMS_REQUIRED,
		"army_size": player_units.size(),
		"military_army_required": MILITARY_ARMY_REQUIRED,
		"military_ready": military_ready,
		"metropolises": metropolis_count,
		"metropolises_required": ECONOMIC_METROPOLISES_REQUIRED,
		"total_gold": total_gold,
		"gold_required": ECONOMIC_GOLD_REQUIRED,
		"city_gold_income": city_gold_income,
		"diplomacy_gold_income": diplomacy_gold_income,
		"net_gold_income": net_gold_income,
		"net_gold_required": ECONOMIC_NET_GOLD_REQUIRED,
		"economic_hold_turns": 0,
		"economic_hold_required": ECONOMIC_HOLD_TURNS_REQUIRED,
		"economic_checks": economic_checks,
		"economic_ready": economic_ready,
		"friendly_kingdoms": friendly_kingdoms,
		"friendly_required": DIPLOMATIC_FRIENDLY_REQUIRED,
		"active_positive_treaties": active_positive_treaties,
		"treaties_required": DIPLOMATIC_TREATIES_REQUIRED,
		"major_treaties": major_treaties,
		"major_treaties_required": DIPLOMATIC_MAJOR_TREATIES_REQUIRED,
		"diplomatic_hold_turns": 0,
		"diplomatic_hold_required": DIPLOMATIC_HOLD_TURNS_REQUIRED,
		"diplomatic_checks": diplomatic_checks,
		"diplomatic_ready": diplomatic_ready,
	}


static func get_progress(
		state: Dictionary,
		turn_number: int,
		cities: Array,
		player_units: Array,
		player_faction: Dictionary,
		diplomacy_relations: Dictionary,
		kingdoms: Array,
		army_upkeep: int
) -> Dictionary:
	var normalized := normalize_state(state)
	var metrics := calculate_metrics(
		turn_number, cities, player_units, player_faction,
		diplomacy_relations, kingdoms, army_upkeep
	)
	var wins: Array = normalized.get("military_wins", [])
	metrics["military_wins"] = wins.size()
	metrics["economic_hold_turns"] = int(normalized.get("economic_hold_turns", 0))
	metrics["diplomatic_hold_turns"] = int(normalized.get("diplomatic_hold_turns", 0))
	metrics["economic_ready"] = metrics["economic_hold_turns"] >= ECONOMIC_HOLD_TURNS_REQUIRED
	metrics["diplomatic_ready"] = metrics["diplomatic_hold_turns"] >= DIPLOMATIC_HOLD_TURNS_REQUIRED
	metrics["military_ready"] = turn_number >= MIN_CAMPAIGN_TURN and wins.size() >= MILITARY_KINGDOMS_REQUIRED and player_units.size() >= MILITARY_ARMY_REQUIRED
	metrics["unlocked_types"] = normalized.get("unlocked_types", []).duplicate()
	metrics["status"] = str(normalized.get("status", "none"))
	metrics["selected_type"] = str(normalized.get("type", ""))
	return metrics


static func choose_victory(state: Dictionary, victory_type: String, continue_playing: bool, turn_number: int) -> bool:
	if not VICTORY_TYPES.has(victory_type):
		return false
	var normalized := normalize_state(state)
	if str(normalized.get("status", "none")) == "claimed":
		return false
	var unlocked: Array = normalized.get("unlocked_types", [])
	if not unlocked.has(victory_type):
		return false
	normalized["type"] = victory_type
	normalized["turn"] = maxi(1, turn_number)
	normalized["status"] = "continued" if continue_playing else "claimed"
	state.clear()
	state.merge(normalized, true)
	return true
