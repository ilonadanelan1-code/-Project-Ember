extends RefCounted
class_name EmberStrategicAIPlanner

const World = preload("res://scripts/world_generator.gd")
const UnitCatalog = preload("res://scripts/unit_catalog.gd")
const CityDevelopment = preload("res://scripts/city_development_catalog.gd")
const FactionCatalog = preload("res://scripts/faction_catalog.gd")
const DiplomacyCatalog = preload("res://scripts/diplomacy_catalog.gd")

const INVALID_CELL := Vector2i(9999, 9999)
const ROLE_ORDER := [
	UnitCatalog.ROLE_MELEE,
	UnitCatalog.ROLE_RANGED,
	UnitCatalog.ROLE_SPEAR,
	UnitCatalog.ROLE_CAVALRY,
]


static func evaluate_kingdom(
		kingdom: Dictionary,
		kingdoms: Array[Dictionary],
		diplomacy_relations: Dictionary,
		turn_number: int,
		player_cell: Vector2i,
		_player_city_cells: Array[Vector2i]
) -> Dictionary:
	var cities_value: Variant = kingdom.get("cities", [])
	var cities: Array = cities_value if cities_value is Array else []
	var army_value: Variant = kingdom.get("army", [])
	var army: Array = army_value if army_value is Array else []
	var faction_value: Variant = kingdom.get("faction", {})
	var faction: Dictionary = faction_value if faction_value is Dictionary else {}
	var gold_reserve := 0
	var food_reserve := 0
	var production_reserve := 0
	var gold_income := 0
	var food_income := 0
	var production_income := 0
	var population_total := 0

	for city_value in cities:
		if not city_value is Dictionary:
			continue
		var city: Dictionary = city_value
		var buildings_value: Variant = city.get("buildings", [])
		var buildings: Array = buildings_value if buildings_value is Array else []
		var levels_value: Variant = city.get("building_levels", {})
		var levels: Dictionary = levels_value if levels_value is Dictionary else {}
		var improvements_value: Variant = city.get("province_improvements", [])
		var improvements: Array = improvements_value if improvements_value is Array else []
		var income := CityDevelopment.get_city_income(
			buildings, levels, improvements, str(city.get("specialization", ""))
		)
		income = FactionCatalog.apply_income_modifiers(income, buildings, faction)
		gold_reserve += maxi(0, int(city.get("gold", 0)))
		food_reserve += maxi(0, int(city.get("food", 0)))
		production_reserve += maxi(0, int(city.get("production_bank", 0)))
		gold_income += int(income.get("gold", 0))
		food_income += int(income.get("food", 0))
		production_income += int(income.get("production", 0))
		population_total += maxi(1, int(city.get("population", 1)))

	var upkeep := 0.0
	for unit_value in army:
		if not unit_value is Dictionary:
			continue
		var role_id: String = str(unit_value.get("role", UnitCatalog.ROLE_MELEE))
		var unit_data := UnitCatalog.get_data(role_id)
		upkeep += float(unit_data.get("upkeep", 0.8)) * FactionCatalog.get_upkeep_multiplier(role_id, faction)
	var upkeep_due := ceili(upkeep)
	var army_strength := estimate_force_strength(army)
	var active_war := false
	var threatened := false
	var nearest_threat_distance := 999999
	var nearest_threat_strength := 0.0
	var kingdom_id := int(kingdom.get("id", -1))
	var own_city_cells: Array[Vector2i] = []
	for city_value in cities:
		if city_value is Dictionary:
			own_city_cells.append(World.array_to_cell(city_value.get("cell", [])))

	var player_record := DiplomacyCatalog.get_record(diplomacy_relations, DiplomacyCatalog.PLAYER_ID, kingdom_id)
	if str(player_record.get("treaty", "peace")) == "war":
		active_war = true
		var player_distance := _nearest_distance_to_cells(player_cell, own_city_cells)
		nearest_threat_distance = mini(nearest_threat_distance, player_distance)
		if player_distance <= 6:
			threatened = true

	for other_id in range(kingdoms.size()):
		if other_id == kingdom_id or not bool(kingdoms[other_id].get("alive", true)):
			continue
		var relation := DiplomacyCatalog.get_record(diplomacy_relations, kingdom_id, other_id)
		if str(relation.get("treaty", "peace")) != "war":
			continue
		active_war = true
		var enemy: Dictionary = kingdoms[other_id]
		var enemy_cell := World.array_to_cell(enemy.get("army_cell", enemy.get("capital_cell", [])))
		var city_distance := _nearest_distance_to_cells(enemy_cell, own_city_cells)
		var enemy_strength := estimate_force_strength(enemy.get("army", []))
		if city_distance < nearest_threat_distance:
			nearest_threat_distance = city_distance
			nearest_threat_strength = enemy_strength
		if city_distance <= 6 and enemy_strength >= army_strength * 0.55:
			threatened = true

	var net_gold_per_turn := gold_income - upkeep_due
	var reserve_threshold := maxi(35, upkeep_due * 5 + 25)
	var economy_focus := "balanced"
	if net_gold_per_turn < 1 or gold_reserve < reserve_threshold:
		economy_focus = "gold"
	elif food_reserve < 12 or food_income < 3:
		economy_focus = "food"
	elif production_income < 6 and production_reserve < 12:
		economy_focus = "production"
	elif active_war or threatened:
		economy_focus = "military"

	var desired_army_size := clampi(8 + cities.size() * 2 + floori(float(population_total) / 10.0), 8, 20)
	if active_war:
		desired_army_size += 3
	if threatened:
		desired_army_size += 2
	desired_army_size = clampi(desired_army_size, 8, 24)
	var can_recruit := gold_reserve >= reserve_threshold and net_gold_per_turn >= -1
	if active_war and threatened and gold_reserve >= 25:
		can_recruit = true
	if not can_recruit and not threatened:
		desired_army_size = mini(desired_army_size, army.size())

	var expansion_allowed := cities.size() < 3
	expansion_allowed = expansion_allowed and gold_reserve >= 65 + upkeep_due * 3
	expansion_allowed = expansion_allowed and net_gold_per_turn >= 0
	if threatened and army_strength < maxf(1.0, nearest_threat_strength) * 0.90:
		expansion_allowed = false

	var recruit_role := select_recruitment_role(kingdom, kingdoms, diplomacy_relations, desired_army_size)
	var recruit_data := UnitCatalog.get_data(recruit_role)
	return {
		"turn": turn_number,
		"economy_focus": economy_focus,
		"war_active": active_war,
		"threatened": threatened,
		"nearest_threat_distance": nearest_threat_distance,
		"army_strength": army_strength,
		"threat_strength": nearest_threat_strength,
		"gold_reserve": gold_reserve,
		"food_reserve": food_reserve,
		"production_reserve": production_reserve,
		"gold_income": gold_income,
		"food_income": food_income,
		"production_income": production_income,
		"upkeep": upkeep_due,
		"net_gold_per_turn": net_gold_per_turn,
		"desired_army_size": desired_army_size,
		"can_recruit": can_recruit,
		"recruit_role": recruit_role,
		"recruit_unlock_building": str(recruit_data.get("unlock_building", "barracks")),
		"expansion_allowed": expansion_allowed,
	}


static func estimate_force_strength(army_value: Variant) -> float:
	if not army_value is Array:
		return 0.0
	var total := 0.0
	for unit_value in army_value:
		if not unit_value is Dictionary:
			continue
		var role_id: String = str(unit_value.get("role", UnitCatalog.ROLE_MELEE))
		var data := UnitCatalog.get_data(role_id)
		var max_health := maxf(1.0, float(data.get("max_health", 125.0)))
		var health_ratio := clampf(float(unit_value.get("health", max_health)) / max_health, 0.0, 1.0)
		var veterancy := UnitCatalog.get_veterancy_data(int(unit_value.get("experience", 0)))
		total += (
			float(data.get("damage", 19.0)) * 1.35
			+ max_health * 0.055
			+ float(data.get("armor", 0.0)) * 0.65
		) * health_ratio * float(veterancy.get("damage_multiplier", 1.0))
	return total


static func select_recruitment_role(
		kingdom: Dictionary,
		kingdoms: Array[Dictionary],
		diplomacy_relations: Dictionary,
		desired_army_size: int
) -> String:
	var doctrine := clampi(int(kingdom.get("military_doctrine", 0)), 0, 3)
	var shares := {
		UnitCatalog.ROLE_MELEE: 0.38,
		UnitCatalog.ROLE_RANGED: 0.25,
		UnitCatalog.ROLE_SPEAR: 0.22,
		UnitCatalog.ROLE_CAVALRY: 0.15,
	}
	match doctrine:
		1:
			shares = {
				UnitCatalog.ROLE_MELEE: 0.34, UnitCatalog.ROLE_RANGED: 0.18,
				UnitCatalog.ROLE_SPEAR: 0.34, UnitCatalog.ROLE_CAVALRY: 0.14,
			}
		2:
			shares = {
				UnitCatalog.ROLE_MELEE: 0.28, UnitCatalog.ROLE_RANGED: 0.38,
				UnitCatalog.ROLE_SPEAR: 0.20, UnitCatalog.ROLE_CAVALRY: 0.14,
			}
		3:
			shares = {
				UnitCatalog.ROLE_MELEE: 0.30, UnitCatalog.ROLE_RANGED: 0.20,
				UnitCatalog.ROLE_SPEAR: 0.16, UnitCatalog.ROLE_CAVALRY: 0.34,
			}

	var enemy_cavalry := 0
	var enemy_ranged := 0
	var enemy_total := 0
	var kingdom_id := int(kingdom.get("id", -1))
	for other_id in range(kingdoms.size()):
		if other_id == kingdom_id or not bool(kingdoms[other_id].get("alive", true)):
			continue
		var relation := DiplomacyCatalog.get_record(diplomacy_relations, kingdom_id, other_id)
		if str(relation.get("treaty", "peace")) != "war":
			continue
		var enemy_army_value: Variant = kingdoms[other_id].get("army", [])
		if not enemy_army_value is Array:
			continue
		for enemy_unit in enemy_army_value:
			if not enemy_unit is Dictionary:
				continue
			enemy_total += 1
			var enemy_role: String = str(enemy_unit.get("role", UnitCatalog.ROLE_MELEE))
			if enemy_role == UnitCatalog.ROLE_CAVALRY:
				enemy_cavalry += 1
			elif enemy_role == UnitCatalog.ROLE_RANGED:
				enemy_ranged += 1
	if enemy_total > 0:
		var cavalry_ratio := float(enemy_cavalry) / float(enemy_total)
		var ranged_ratio := float(enemy_ranged) / float(enemy_total)
		if cavalry_ratio >= 0.20:
			shares[UnitCatalog.ROLE_SPEAR] = float(shares[UnitCatalog.ROLE_SPEAR]) + 0.12
			shares[UnitCatalog.ROLE_MELEE] = maxf(0.10, float(shares[UnitCatalog.ROLE_MELEE]) - 0.06)
			shares[UnitCatalog.ROLE_RANGED] = maxf(0.08, float(shares[UnitCatalog.ROLE_RANGED]) - 0.06)
		if ranged_ratio >= 0.35:
			shares[UnitCatalog.ROLE_CAVALRY] = float(shares[UnitCatalog.ROLE_CAVALRY]) + 0.10
			shares[UnitCatalog.ROLE_MELEE] = maxf(0.10, float(shares[UnitCatalog.ROLE_MELEE]) - 0.05)
			shares[UnitCatalog.ROLE_SPEAR] = maxf(0.08, float(shares[UnitCatalog.ROLE_SPEAR]) - 0.05)

	var army_value: Variant = kingdom.get("army", [])
	var army: Array = army_value if army_value is Array else []
	var counts := {
		UnitCatalog.ROLE_MELEE: 0, UnitCatalog.ROLE_RANGED: 0,
		UnitCatalog.ROLE_SPEAR: 0, UnitCatalog.ROLE_CAVALRY: 0,
	}
	for unit_value in army:
		if unit_value is Dictionary:
			var role_id: String = str(unit_value.get("role", UnitCatalog.ROLE_MELEE))
			if counts.has(role_id):
				counts[role_id] = int(counts[role_id]) + 1
	var share_total := 0.0
	for role_id in ROLE_ORDER:
		share_total += float(shares.get(role_id, 0.0))
	var best_role := UnitCatalog.ROLE_MELEE
	var best_deficit := -999999.0
	for role_index in range(ROLE_ORDER.size()):
		var role_id: String = str(ROLE_ORDER[role_index])
		var desired_count := float(desired_army_size) * float(shares.get(role_id, 0.0)) / maxf(0.01, share_total)
		var deficit := desired_count - float(counts.get(role_id, 0))
		deficit += float(posmod(kingdom_id + doctrine + role_index, 4)) * 0.001
		if deficit > best_deficit:
			best_deficit = deficit
			best_role = role_id
	return best_role


static func select_war_target(
		kingdom: Dictionary,
		kingdoms: Array[Dictionary],
		diplomacy_relations: Dictionary,
		player_cell: Vector2i,
		_player_city_cells: Array[Vector2i]
) -> Dictionary:
	var kingdom_id := int(kingdom.get("id", -1))
	var current := World.array_to_cell(kingdom.get("army_cell", []))
	var cities_value: Variant = kingdom.get("cities", [])
	var cities: Array = cities_value if cities_value is Array else []
	var own_city_cells: Array[Vector2i] = []
	for city_value in cities:
		if city_value is Dictionary:
			own_city_cells.append(World.array_to_cell(city_value.get("cell", [])))
	var own_strength := estimate_force_strength(kingdom.get("army", []))
	var war_active := false
	var best_score := -999999.0
	var best_cell := INVALID_CELL
	var best_target_id := -99

	var player_record := DiplomacyCatalog.get_record(diplomacy_relations, DiplomacyCatalog.PLAYER_ID, kingdom_id)
	if str(player_record.get("treaty", "peace")) == "war":
		war_active = true
		var player_distance := World.hex_distance(current, player_cell)
		var pressure_distance := _nearest_distance_to_cells(player_cell, own_city_cells)
		var score := 78.0 - float(player_distance) * 1.8
		if pressure_distance <= 6:
			score += 42.0 + float(6 - pressure_distance) * 2.0
		score += minf(12.0, own_strength * 0.02)
		best_score = score
		best_cell = player_cell
		best_target_id = DiplomacyCatalog.PLAYER_ID

	for other_id in range(kingdoms.size()):
		if other_id == kingdom_id or not bool(kingdoms[other_id].get("alive", true)):
			continue
		var relation := DiplomacyCatalog.get_record(diplomacy_relations, kingdom_id, other_id)
		if str(relation.get("treaty", "peace")) != "war":
			continue
		war_active = true
		var enemy: Dictionary = kingdoms[other_id]
		var enemy_army_value: Variant = enemy.get("army", [])
		var enemy_cell := World.array_to_cell(
			enemy.get("army_cell", enemy.get("capital_cell", [])),
			World.array_to_cell(enemy.get("capital_cell", []))
		)
		if not enemy_army_value is Array or enemy_army_value.is_empty():
			enemy_cell = World.array_to_cell(enemy.get("capital_cell", []), enemy_cell)
		var distance := World.hex_distance(current, enemy_cell)
		var pressure_distance := _nearest_distance_to_cells(enemy_cell, own_city_cells)
		var enemy_strength := estimate_force_strength(enemy_army_value)
		var power_ratio := own_strength / maxf(1.0, enemy_strength)
		var score := 76.0 - float(distance) * 1.8
		if pressure_distance <= 6:
			score += 42.0 + float(6 - pressure_distance) * 2.0
		score += clampf((power_ratio - 1.0) * 24.0, -30.0, 22.0)
		if enemy_army_value is Array and enemy_army_value.is_empty():
			score += 8.0
		if score > best_score:
			best_score = score
			best_cell = enemy_cell
			best_target_id = other_id
	return {
		"war_active": war_active,
		"has_target": best_cell != INVALID_CELL,
		"cell": best_cell,
		"kingdom_id": best_target_id,
		"score": best_score,
	}


static func score_expansion_cell(
		candidate: Vector2i,
		capital_cell: Vector2i,
		own_city_records: Array,
		kingdoms: Array[Dictionary],
		current_kingdom_id: int,
		player_cell: Vector2i,
		player_city_cells: Array[Vector2i],
		world_seed: int,
		world_generation_version: int,
		neutral_location_cells: Array[Vector2i]
) -> float:
	if not World.is_inside_world(candidate):
		return -999999.0
	var terrain := World.terrain_at(candidate, world_seed, world_generation_version)
	if terrain == "water" or terrain == "void":
		return -999999.0
	var terrain_score := 0.0
	match terrain:
		"farmland":
			terrain_score = 24.0
		"plain":
			terrain_score = 15.0
		"forest":
			terrain_score = 12.0
		"hills":
			terrain_score = 10.0
		"marsh":
			terrain_score = 2.0
	var capital_distance := World.hex_distance(candidate, capital_cell)
	var score := terrain_score + 18.0 - absf(float(capital_distance) - 5.5) * 3.5
	var favorable_neighbors := 0
	for offset in World.neighbors():
		var neighbor_terrain := World.terrain_at(candidate + offset, world_seed, world_generation_version)
		if neighbor_terrain == "farmland":
			favorable_neighbors += 2
		elif neighbor_terrain in ["plain", "forest", "hills"]:
			favorable_neighbors += 1
	score += float(favorable_neighbors) * 1.2
	for city_value in own_city_records:
		if not city_value is Dictionary:
			continue
		var own_cell := World.array_to_cell(city_value.get("cell", []))
		if own_cell == capital_cell:
			continue
		var own_distance := World.hex_distance(candidate, own_cell)
		if own_distance < 5:
			return -999999.0
		score += minf(4.0, float(own_distance) * 0.25)
	for other in kingdoms:
		if int(other.get("id", -1)) == current_kingdom_id or not bool(other.get("alive", true)):
			continue
		var other_cities_value: Variant = other.get("cities", [])
		if not other_cities_value is Array:
			continue
		for other_city in other_cities_value:
			if not other_city is Dictionary:
				continue
			var other_cell := World.array_to_cell(other_city.get("cell", []))
			var enemy_distance := World.hex_distance(candidate, other_cell)
			if enemy_distance < 3:
				return -999999.0
			if enemy_distance < 7:
				score -= float(7 - enemy_distance) * 3.0
	for player_city in player_city_cells:
		var player_distance := World.hex_distance(candidate, player_city)
		if player_distance < 3:
			return -999999.0
		if player_distance < 7:
			score -= float(7 - player_distance) * 3.0
	var player_army_distance := World.hex_distance(candidate, player_cell)
	if player_army_distance < 3:
		score -= 18.0
	elif player_army_distance < 7:
		score -= float(7 - player_army_distance) * 1.5
	var nearest_neutral := 999999
	for neutral_cell in neutral_location_cells:
		nearest_neutral = mini(nearest_neutral, World.hex_distance(candidate, neutral_cell))
	if nearest_neutral <= 3:
		score += 7.0
	elif nearest_neutral <= 6:
		score += 3.0
	var tie_break := float(posmod(candidate.x * 31 + candidate.y * 17 + world_seed, 97)) * 0.001
	return score + tie_break


static func _nearest_distance_to_cells(cell: Vector2i, cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return 999999
	var nearest := 999999
	for other_cell in cells:
		nearest = mini(nearest, World.hex_distance(cell, other_cell))
	return nearest
