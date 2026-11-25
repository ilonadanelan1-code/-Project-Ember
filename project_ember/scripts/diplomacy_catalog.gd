extends RefCounted
class_name EmberDiplomacyCatalog

const World = preload("res://scripts/world_generator.gd")

## Lightweight, deterministic diplomacy rules for the single-player campaign.
## Pair records are stored under canonical "lower_id:higher_id" keys;
## player id is -1 and AI kingdoms keep their existing 0..8 IDs.

const PLAYER_ID := -1
const RELATION_MIN := -100
const RELATION_MAX := 100
const TRADE_DURATION := 6
const ALLIANCE_DURATION := 8
const TRIBUTE_DURATION := 5
const VASSAL_DURATION := 10
const TRUCE_DURATION := 4
const OFFER_LIFETIME := 3
const MAX_PENDING_OFFERS := 4
const BORDER_TENSION_DISTANCE := 4
const BORDER_TENSION_INTERVAL := 5
const TREATIES := ["peace", "war", "trade", "alliance", "tribute", "vassal"]

const PERSONALITIES := {
	"aggressor": {
		"name": "Завоеватель",
		"description": "Ценит силу, чаще угрожает войной и неохотно вступает в союзы.",
		"trade": -8, "alliance": -12, "peace": -3, "tribute": 4, "vassal": 8,
		"peace_drift": -2,
	},
	"merchant": {
		"name": "Торговец",
		"description": "Предпочитает торговые договоры, стабильность и взаимную выгоду.",
		"trade": 20, "alliance": 8, "peace": 8, "tribute": -8, "vassal": -15,
		"peace_drift": 1,
	},
	"isolationist": {
		"name": "Изоляционист",
		"description": "Держится в стороне, редко предлагает союзы и ценит собственные границы.",
		"trade": -5, "alliance": -18, "peace": 2, "tribute": -4, "vassal": -12,
		"peace_drift": 0,
	},
	"honorable": {
		"name": "Хранитель клятв",
		"description": "Уважает договоры, надёжных соседей и мирные соглашения.",
		"trade": 8, "alliance": 18, "peace": 15, "tribute": -10, "vassal": -18,
		"peace_drift": 1,
	},
	"expansionist": {
		"name": "Покоритель рубежей",
		"description": "Стремится расширять влияние, но уважает явное военное превосходство.",
		"trade": 0, "alliance": -4, "peace": -5, "tribute": 8, "vassal": 12,
		"peace_drift": -1,
	},
}


static func pair_key(first_id: int, second_id: int) -> String:
	var low_id := mini(first_id, second_id)
	var high_id := maxi(first_id, second_id)
	return "%d:%d" % [low_id, high_id]


static func personality_id_for_kingdom(kingdom_id: int) -> String:
	var order := ["aggressor", "merchant", "isolationist", "honorable", "expansionist", "merchant", "honorable", "aggressor", "isolationist"]
	return str(order[posmod(kingdom_id, order.size())])


static func get_personality(kingdom_id: int) -> Dictionary:
	var value: Variant = PERSONALITIES.get(personality_id_for_kingdom(kingdom_id), {})
	return value.duplicate(true) if value is Dictionary else {}


static func get_personality_name(kingdom_id: int) -> String:
	return str(get_personality(kingdom_id).get("name", "Неизвестный характер"))


static func _make_record(initial_relation: int = 0) -> Dictionary:
	return {
		"relation": clampi(initial_relation, RELATION_MIN, RELATION_MAX),
		"treaty": "peace",
		"treaty_until": 0,
		"war_exhaustion": 0,
		"overlord_id": -99,
		"war_reason": "none",
		"truce_until": 0,
		"last_offer_turn": 0,
		"last_change_turn": 1,
	}


static func _initial_player_relation(kingdom_id: int) -> int:
	match personality_id_for_kingdom(kingdom_id):
		"aggressor": return -14
		"merchant": return 18
		"isolationist": return -2
		"honorable": return 15
		"expansionist": return -8
	return 0


static func _initial_ai_relation(first_id: int, second_id: int, world_seed: int) -> int:
	var token := "diplomacy:%d:%d:%d" % [world_seed, first_id, second_id]
	var score := int(posmod(token.hash(), 31)) - 15
	var first_personality := personality_id_for_kingdom(first_id)
	var second_personality := personality_id_for_kingdom(second_id)
	if first_personality == second_personality:
		score += 8
	elif first_personality == "aggressor" or second_personality == "aggressor":
		score -= 7
	return clampi(score, -30, 30)


static func create_initial_relations(kingdom_count: int, world_seed: int) -> Dictionary:
	var result: Dictionary = {}
	for kingdom_id in range(kingdom_count):
		result[pair_key(PLAYER_ID, kingdom_id)] = _make_record(_initial_player_relation(kingdom_id))
		for other_id in range(kingdom_id + 1, kingdom_count):
			result[pair_key(kingdom_id, other_id)] = _make_record(_initial_ai_relation(kingdom_id, other_id, world_seed))
	return result


static func normalize_relations(raw: Variant, kingdom_count: int, world_seed: int) -> Dictionary:
	var result := create_initial_relations(kingdom_count, world_seed)
	if not raw is Dictionary:
		return result
	for key_value in result.keys():
		var key := str(key_value)
		var raw_record: Variant = raw.get(key, {})
		if not raw_record is Dictionary:
			continue
		var record: Dictionary = result[key]
		record["relation"] = clampi(int(raw_record.get("relation", record.get("relation", 0))), RELATION_MIN, RELATION_MAX)
		var treaty := str(raw_record.get("treaty", "peace"))
		record["treaty"] = treaty if TREATIES.has(treaty) else "peace"
		record["treaty_until"] = clampi(int(raw_record.get("treaty_until", 0)), 0, 100000000)
		record["war_exhaustion"] = clampi(int(raw_record.get("war_exhaustion", 0)), 0, 100)
		record["overlord_id"] = clampi(int(raw_record.get("overlord_id", -99)), -99, kingdom_count - 1)
		var war_reason := str(raw_record.get("war_reason", "none"))
		record["war_reason"] = war_reason if ["none", "player_declaration", "battle_provocation", "border_tension", "resolved"].has(war_reason) else "none"
		record["truce_until"] = clampi(int(raw_record.get("truce_until", 0)), 0, 100000000)
		record["last_offer_turn"] = clampi(int(raw_record.get("last_offer_turn", 0)), 0, 100000000)
		record["last_change_turn"] = clampi(int(raw_record.get("last_change_turn", 1)), 1, 100000000)
		if record["treaty"] != "tribute" and record["treaty"] != "vassal":
			record["overlord_id"] = -99
		result[key] = record
	return result


static func get_record(relations: Dictionary, first_id: int, second_id: int) -> Dictionary:
	var value: Variant = relations.get(pair_key(first_id, second_id), _make_record())
	return value.duplicate(true) if value is Dictionary else _make_record()


static func set_record(relations: Dictionary, first_id: int, second_id: int, record: Dictionary) -> void:
	relations[pair_key(first_id, second_id)] = record.duplicate(true)


static func set_treaty(
		relations: Dictionary,
		first_id: int,
		second_id: int,
		treaty_id: String,
		turn_number: int,
		duration: int = 0,
		overlord_id: int = -99
) -> void:
	if not TREATIES.has(treaty_id):
		return
	var record := get_record(relations, first_id, second_id)
	record["treaty"] = treaty_id
	record["treaty_until"] = turn_number + duration if duration > 0 else 0
	record["overlord_id"] = overlord_id if treaty_id == "tribute" or treaty_id == "vassal" else -99
	record["last_change_turn"] = turn_number
	if treaty_id != "war":
		record["war_exhaustion"] = 0
	set_record(relations, first_id, second_id, record)


static func change_relation(relations: Dictionary, first_id: int, second_id: int, delta: int, turn_number: int) -> int:
	var record := get_record(relations, first_id, second_id)
	var next_value := clampi(int(record.get("relation", 0)) + delta, RELATION_MIN, RELATION_MAX)
	record["relation"] = next_value
	record["last_change_turn"] = turn_number
	set_record(relations, first_id, second_id, record)
	return next_value


static func relation_label(value: int) -> String:
	if value >= 60:
		return "Дружба"
	if value >= 25:
		return "Расположение"
	if value >= -24:
		return "Нейтралитет"
	if value >= -59:
		return "Недоверие"
	return "Враждебность"


static func treaty_label(treaty_id: String) -> String:
	match treaty_id:
		"war": return "Война"
		"trade": return "Торговый договор"
		"alliance": return "Союз"
		"tribute": return "Выплата дани"
		"vassal": return "Вассалитет"
	return "Мир"


static func acceptance_chance(
		action_id: String,
		record: Dictionary,
		kingdom_id: int,
		player_power: float,
		target_power: float
) -> int:
	var personality := get_personality(kingdom_id)
	var relation := int(record.get("relation", 0))
	var ratio := player_power / maxf(1.0, target_power)
	var pressure := clampf((ratio - 1.0) * 20.0, -18.0, 25.0)
	var score := 45.0 + float(relation) * 0.35
	match action_id:
		"offer_trade":
			score += float(personality.get("trade", 0))
		"offer_alliance":
			score = 30.0 + float(relation) * 0.52 + float(personality.get("alliance", 0))
			score += clampf((ratio - 1.0) * 8.0, -8.0, 10.0)
		"offer_peace":
			score = 20.0 + float(record.get("war_exhaustion", 0)) * 0.62 + float(relation) * 0.20
			score += clampf((ratio - 1.0) * 12.0, -12.0, 16.0) + float(personality.get("peace", 0))
		"demand_tribute":
			score = 22.0 + float(relation) * 0.18 + pressure * 1.35 + float(personality.get("tribute", 0))
		"demand_vassalage":
			score = 8.0 + float(relation) * 0.14 + pressure * 1.8
			score += float(record.get("war_exhaustion", 0)) * 0.28 + float(personality.get("vassal", 0))
	return clampi(roundi(score), 5, 95)


static func deterministic_acceptance(action_id: String, kingdom_id: int, turn_number: int, world_seed: int, chance: int) -> bool:
	var token := "%s:%d:%d:%d" % [action_id, kingdom_id, turn_number, world_seed]
	var roll := int(posmod(token.hash(), 100))
	return roll < clampi(chance, 0, 100)


static func process_turn(
		relations: Dictionary,
		kingdoms: Array[Dictionary],
		turn_number: int,
		world_seed: int,
		_player_power: float,
		pending_offers: Array[Dictionary],
		player_sources: Array[Vector2i] = []
) -> Dictionary:
	var events: Array[String] = []
	for offer_index in range(pending_offers.size() - 1, -1, -1):
		if int(pending_offers[offer_index].get("expires_turn", 0)) < turn_number:
			pending_offers.remove_at(offer_index)

	for kingdom_id in range(kingdoms.size()):
		if not bool(kingdoms[kingdom_id].get("alive", true)):
			continue
		var player_record := get_record(relations, PLAYER_ID, kingdom_id)
		_tick_record(player_record, turn_number)
		set_record(relations, PLAYER_ID, kingdom_id, player_record)
		var personality_id := personality_id_for_kingdom(kingdom_id)
		var current_treaty := str(player_record.get("treaty", "peace"))
		if current_treaty == "peace":
			if turn_number % 3 == 0:
				var drift := int(get_personality(kingdom_id).get("peace_drift", 0))
				if drift != 0:
					change_relation(relations, PLAYER_ID, kingdom_id, drift, turn_number)
					player_record = get_record(relations, PLAYER_ID, kingdom_id)
			var player_border_distance := _nearest_sources_to_cities(player_sources, kingdoms[kingdom_id].get("cities", []))
			if (personality_id == "aggressor" or personality_id == "expansionist") and player_border_distance <= BORDER_TENSION_DISTANCE and turn_number % BORDER_TENSION_INTERVAL == posmod(kingdom_id, BORDER_TENSION_INTERVAL):
				var player_border_penalty := 2 if player_border_distance <= 2 else 1
				change_relation(relations, PLAYER_ID, kingdom_id, -player_border_penalty, turn_number)
				player_record = get_record(relations, PLAYER_ID, kingdom_id)
		if current_treaty == "peace" and int(player_record.get("relation", 0)) <= -55 and (personality_id == "aggressor" or personality_id == "expansionist") and turn_number % 4 == posmod(kingdom_id, 4):
			if turn_number >= int(player_record.get("truce_until", 0)):
				set_treaty(relations, PLAYER_ID, kingdom_id, "war", turn_number)
				var war_record := get_record(relations, PLAYER_ID, kingdom_id)
				war_record["war_reason"] = "border_tension"
				set_record(relations, PLAYER_ID, kingdom_id, war_record)
				change_relation(relations, PLAYER_ID, kingdom_id, -8, turn_number)
				events.append("%s объявило тебе войну." % str(kingdoms[kingdom_id].get("name", "Королевство")))
				player_record = get_record(relations, PLAYER_ID, kingdom_id)
		_maybe_create_player_offer(
				pending_offers,
				relations,
				kingdoms[kingdom_id],
				kingdom_id,
				turn_number
		)

	for first_id in range(kingdoms.size()):
		if not bool(kingdoms[first_id].get("alive", true)):
			continue
		for second_id in range(first_id + 1, kingdoms.size()):
			if not bool(kingdoms[second_id].get("alive", true)):
				continue
			var record := get_record(relations, first_id, second_id)
			_tick_record(record, turn_number)
			if turn_number % 3 == 0:
				var drift_total := int(get_personality(first_id).get("peace_drift", 0)) + int(get_personality(second_id).get("peace_drift", 0))
				if drift_total != 0:
					record["relation"] = clampi(int(record.get("relation", 0)) + signi(drift_total), RELATION_MIN, RELATION_MAX)
			if str(record.get("treaty", "peace")) == "peace":
				var rival_border_distance := _nearest_city_distance(kingdoms[first_id].get("cities", []), kingdoms[second_id].get("cities", []))
				var first_personality_id := personality_id_for_kingdom(first_id)
				var second_personality_id := personality_id_for_kingdom(second_id)
				var rivalry := first_personality_id in ["aggressor", "expansionist"] or second_personality_id in ["aggressor", "expansionist"]
				if rivalry and rival_border_distance <= BORDER_TENSION_DISTANCE and turn_number % BORDER_TENSION_INTERVAL == posmod(first_id * 7 + second_id * 3, BORDER_TENSION_INTERVAL):
					var ai_border_penalty := 2 if rival_border_distance <= 2 else 1
					record["relation"] = clampi(int(record.get("relation", 0)) - ai_border_penalty, RELATION_MIN, RELATION_MAX)
			# Persist the just-ticked record before set_treaty reads and updates it.
			set_record(relations, first_id, second_id, record)
			var ai_treaty := str(record.get("treaty", "peace"))
			var ai_relation := int(record.get("relation", 0))
			if ai_treaty == "peace" and ai_relation >= 35 and turn_number > 1 and posmod(turn_number + first_id * 7 + second_id * 11, 13) == 0:
				set_treaty(relations, first_id, second_id, "trade", turn_number, TRADE_DURATION)
				events.append("%s и %s заключили торговый договор." % [str(kingdoms[first_id].get("name", "Держава")), str(kingdoms[second_id].get("name", "Держава"))])
			elif ai_treaty == "trade" and ai_relation >= 60 and posmod(turn_number + first_id * 5 + second_id * 3, 17) == 0:
				set_treaty(relations, first_id, second_id, "alliance", turn_number, ALLIANCE_DURATION)
				events.append("%s и %s заключили союз." % [str(kingdoms[first_id].get("name", "Держава")), str(kingdoms[second_id].get("name", "Держава"))])
			elif ai_treaty == "peace" and ai_relation <= -60 and turn_number % 4 == posmod(first_id + second_id, 4):
				var first_personality := personality_id_for_kingdom(first_id)
				var second_personality := personality_id_for_kingdom(second_id)
				if first_personality == "aggressor" or first_personality == "expansionist" or second_personality == "aggressor" or second_personality == "expansionist":
					set_treaty(relations, first_id, second_id, "war", turn_number)
					var war_record := get_record(relations, first_id, second_id)
					war_record["war_reason"] = "border_tension"
					set_record(relations, first_id, second_id, war_record)
					change_relation(relations, first_id, second_id, -8, turn_number)
					events.append("%s и %s начали войну из-за пограничной напряжённости." % [str(kingdoms[first_id].get("name", "Держава")), str(kingdoms[second_id].get("name", "Держава"))])
			elif ai_treaty == "war" and int(record.get("war_exhaustion", 0)) >= 50 and turn_number % 4 == posmod(first_id + second_id, 4):
				var first_peace := float(get_personality(first_id).get("peace", 0))
				var second_peace := float(get_personality(second_id).get("peace", 0))
				var peace_score := 25.0 + float(record.get("war_exhaustion", 0)) * 0.55 + float(ai_relation) * 0.12 + (first_peace + second_peace) * 0.5
				var peace_chance := clampi(roundi(peace_score), 5, 95)
				if deterministic_acceptance("ai_peace", second_id, turn_number + first_id * 13, world_seed, peace_chance):
					set_treaty(relations, first_id, second_id, "peace", turn_number)
					var peace_record := get_record(relations, first_id, second_id)
					peace_record["truce_until"] = turn_number + TRUCE_DURATION
					peace_record["war_reason"] = "resolved"
					set_record(relations, first_id, second_id, peace_record)
					change_relation(relations, first_id, second_id, 8, turn_number)
					events.append("%s и %s заключили мир после истощительной войны." % [str(kingdoms[first_id].get("name", "Держава")), str(kingdoms[second_id].get("name", "Держава"))])

	return {"events": events, "offers": pending_offers}


static func _nearest_sources_to_cities(sources: Array[Vector2i], city_values: Variant) -> int:
	if sources.is_empty() or not city_values is Array:
		return 999999
	var nearest := 999999
	for city_value in city_values:
		if not city_value is Dictionary:
			continue
		var city_cell := World.array_to_cell(city_value.get("cell", []))
		for source_cell in sources:
			nearest = mini(nearest, World.hex_distance(source_cell, city_cell))
	return nearest


static func _nearest_city_distance(first_values: Variant, second_values: Variant) -> int:
	if not first_values is Array or not second_values is Array:
		return 999999
	var nearest := 999999
	for first_value in first_values:
		if not first_value is Dictionary:
			continue
		var first_cell := World.array_to_cell(first_value.get("cell", []))
		for second_value in second_values:
			if not second_value is Dictionary:
				continue
			var second_cell := World.array_to_cell(second_value.get("cell", []))
			nearest = mini(nearest, World.hex_distance(first_cell, second_cell))
	return nearest


static func _tick_record(record: Dictionary, turn_number: int) -> void:
	var treaty := str(record.get("treaty", "peace"))
	var expires := int(record.get("treaty_until", 0))
	if treaty != "war" and expires > 0 and turn_number > expires:
		record["treaty"] = "peace"
		record["treaty_until"] = 0
		record["overlord_id"] = -99
		record["last_change_turn"] = turn_number
		record["relation"] = clampi(int(record.get("relation", 0)) - 5, RELATION_MIN, RELATION_MAX)
		treaty = "peace"
	if treaty == "war":
		record["war_exhaustion"] = clampi(int(record.get("war_exhaustion", 0)) + 5, 0, 100)
	elif treaty == "trade":
		record["relation"] = clampi(int(record.get("relation", 0)) + 1, RELATION_MIN, RELATION_MAX)
	elif treaty == "alliance":
		record["relation"] = clampi(int(record.get("relation", 0)) + 2, RELATION_MIN, RELATION_MAX)
	elif treaty == "vassal":
		record["relation"] = clampi(int(record.get("relation", 0)) + 1, RELATION_MIN, RELATION_MAX)
	elif treaty == "tribute":
		record["relation"] = clampi(int(record.get("relation", 0)) + 1, RELATION_MIN, RELATION_MAX)


static func _maybe_create_player_offer(
		pending_offers: Array[Dictionary],
		relations: Dictionary,
		_kingdom: Dictionary,
		kingdom_id: int,
		turn_number: int
) -> void:
	if pending_offers.size() >= MAX_PENDING_OFFERS:
		return
	for existing in pending_offers:
		if int(existing.get("kingdom_id", -1)) == kingdom_id:
			return
	var record := get_record(relations, PLAYER_ID, kingdom_id)
	var treaty := str(record.get("treaty", "peace"))
	var relation := int(record.get("relation", 0))
	var last_offer := int(record.get("last_offer_turn", 0))
	if turn_number - last_offer < 4:
		return
	var action_id := ""
	var personality := personality_id_for_kingdom(kingdom_id)
	if treaty == "war" and int(record.get("war_exhaustion", 0)) >= 35 and turn_number % 2 == 0:
		action_id = "offer_peace"
	elif treaty == "trade" and relation >= 55 and turn_number % 5 == 2:
		action_id = "offer_alliance"
	elif treaty == "peace" and relation >= 18 and (personality == "merchant" or personality == "honorable") and turn_number % 4 == 1:
		action_id = "offer_trade"
	if action_id.is_empty():
		return
	var offer := {
		"offer_id": "%d:%s:%d" % [kingdom_id, action_id, turn_number],
		"kingdom_id": kingdom_id,
		"action": action_id,
		"created_turn": turn_number,
		"expires_turn": turn_number + OFFER_LIFETIME,
	}
	pending_offers.append(offer)
	record["last_offer_turn"] = turn_number
	set_record(relations, PLAYER_ID, kingdom_id, record)


static func treaty_is_active(record: Dictionary, turn_number: int) -> bool:
	var treaty := str(record.get("treaty", "peace"))
	if treaty == "war" or treaty == "peace":
		return true
	var expires := int(record.get("treaty_until", 0))
	return expires <= 0 or turn_number <= expires
