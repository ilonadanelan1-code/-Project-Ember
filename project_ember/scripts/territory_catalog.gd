extends RefCounted
class_name EmberTerritoryCatalog

const World = preload("res://scripts/world_generator.gd")

const OWNER_UNCLAIMED := -1
const OWNER_PLAYER := -2
const OWNER_DISPUTED := -3
const CONTEST_MARGIN := 6.0
const CITY_FALLOFF := 9.25
const ARMY_FALLOFF := 10.0
const WATCHTOWER_FALLOFF := 10.5
const WATCHTOWER_RADIUS := 4


static func build_owner_lookup(
		cells: Array[Vector2i],
		player_cities: Array[Dictionary],
		player_army_cell: Vector2i,
		player_army: Array[Dictionary],
		kingdoms: Array[Dictionary]
) -> Dictionary:
	var sources: Array[Dictionary] = []
	_append_city_sources(sources, player_cities, OWNER_PLAYER)
	_append_army_source(sources, player_army_cell, player_army, OWNER_PLAYER)
	for kingdom_index in range(kingdoms.size()):
		var kingdom: Dictionary = kingdoms[kingdom_index]
		if not bool(kingdom.get("alive", true)):
			continue
		var city_values: Variant = kingdom.get("cities", [])
		_append_city_sources(sources, city_values, kingdom_index)
		var army_values: Variant = kingdom.get("army", [])
		var army: Array[Dictionary] = []
		if army_values is Array:
			for unit_value in army_values:
				if unit_value is Dictionary:
					army.append(unit_value)
		var army_cell := World.array_to_cell(kingdom.get("army_cell", []), Vector2i(9999, 9999))
		_append_army_source(sources, army_cell, army, kingdom_index)

	var result: Dictionary = {}
	for cell in cells:
		if not World.is_inside_world(cell):
			result[cell] = OWNER_UNCLAIMED
			continue
		var owner_scores: Dictionary = {}
		for source in sources:
			var source_cell: Vector2i = source.get("cell", Vector2i(9999, 9999))
			var distance := World.hex_distance(cell, source_cell)
			if distance > int(source.get("radius", 0)):
				continue
			var score := float(source.get("power", 0.0)) - float(source.get("falloff", CITY_FALLOFF)) * float(distance)
			if score <= 0.0:
				continue
			var owner_id := int(source.get("owner", OWNER_UNCLAIMED))
			var previous_score := float(owner_scores.get(owner_id, 0.0))
			if score > previous_score:
				owner_scores[owner_id] = score

		var best_owner := OWNER_UNCLAIMED
		var best_score := 0.0
		var second_score := 0.0
		for owner_value in owner_scores.keys():
			var owner_id := int(owner_value)
			var score := float(owner_scores[owner_id])
			if score > best_score:
				second_score = best_score
				best_score = score
				best_owner = owner_id
			elif score > second_score:
				second_score = score
		if best_score <= 0.0:
			result[cell] = OWNER_UNCLAIMED
		elif second_score > 0.0 and best_score - second_score <= CONTEST_MARGIN:
			result[cell] = OWNER_DISPUTED
		else:
			result[cell] = best_owner
	return result


static func get_owner_at(
		cell: Vector2i,
		player_cities: Array[Dictionary],
		player_army_cell: Vector2i,
		player_army: Array[Dictionary],
		kingdoms: Array[Dictionary]
) -> int:
	var probe: Array[Vector2i] = [cell]
	var lookup := build_owner_lookup(probe, player_cities, player_army_cell, player_army, kingdoms)
	return int(lookup.get(cell, OWNER_UNCLAIMED))


static func _append_city_sources(sources: Array[Dictionary], city_value: Variant, owner_id: int) -> void:
	if not city_value is Array:
		return
	var city_index := 0
	for raw_city in city_value:
		if not raw_city is Dictionary:
			city_index += 1
			continue
		var city: Dictionary = raw_city
		var center := World.array_to_cell(city.get("cell", []), Vector2i(9999, 9999))
		if not World.is_inside_world(center):
			city_index += 1
			continue
		var population := clampi(int(city.get("population", 1)), 1, 20)
		var specialization := str(city.get("specialization", ""))
		var power := 46.0 + float(population) * 1.8
		if city_index == 0:
			power += 12.0
		if specialization == "military":
			power += 5.0
		var radius := clampi(floori(power / CITY_FALLOFF), 3, 8)
		sources.append({
			"cell": center,
			"owner": owner_id,
			"power": power,
			"falloff": CITY_FALLOFF,
			"radius": radius,
			"kind": "city",
		})
		var improvements_value: Variant = city.get("province_improvements", [])
		if improvements_value is Array:
			for improvement in improvements_value:
				if not improvement is Dictionary or str(improvement.get("id", "")) != "watchtower":
					continue
				var tower_cell := World.array_to_cell(improvement.get("cell", []), center)
				sources.append({
					"cell": tower_cell,
					"owner": owner_id,
					"power": 52.0,
					"falloff": WATCHTOWER_FALLOFF,
					"radius": WATCHTOWER_RADIUS,
					"kind": "watchtower",
				})
		city_index += 1


static func _append_army_source(
		sources: Array[Dictionary],
		army_cell: Vector2i,
		army: Array[Dictionary],
		owner_id: int
) -> void:
	if army.is_empty() or not World.is_inside_world(army_cell):
		return
	var power := 24.0 + minf(36.0, float(army.size()) * 2.0)
	var radius := clampi(floori(power / ARMY_FALLOFF), 2, 5)
	sources.append({
		"cell": army_cell,
		"owner": owner_id,
		"power": power,
		"falloff": ARMY_FALLOFF,
		"radius": radius,
		"kind": "army",
	})


static func get_city_influence_radius(population: int, city_index: int, specialization: String) -> int:
	var power := 46.0 + float(clampi(population, 1, 20)) * 1.8
	if city_index == 0:
		power += 12.0
	if specialization == "military":
		power += 5.0
	return clampi(floori(power / CITY_FALLOFF), 3, 8)


static func get_watchtower_count(improvements: Array) -> int:
	var count := 0
	for improvement in improvements:
		if improvement is Dictionary and str(improvement.get("id", "")) == "watchtower":
			count += 1
	return count


static func get_defensive_armor_bonus(
		battle_cell: Vector2i,
		player_cities: Array[Dictionary],
		kingdoms: Array[Dictionary]
) -> float:
	var no_field_army := Vector2i(9999, 9999)
	var no_units: Array[Dictionary] = []
	if get_owner_at(battle_cell, player_cities, no_field_army, no_units, kingdoms) != OWNER_PLAYER:
		return 0.0
	for city_value in player_cities:
		var center := World.array_to_cell(city_value.get("cell", []), Vector2i(9999, 9999))
		var improvements_value: Variant = city_value.get("province_improvements", [])
		if not improvements_value is Array:
			continue
		for improvement in improvements_value:
			if not improvement is Dictionary or str(improvement.get("id", "")) != "watchtower":
				continue
			var tower_cell := World.array_to_cell(improvement.get("cell", []), center)
			if World.hex_distance(battle_cell, tower_cell) <= 3:
				return 1.0
	return 0.0
