extends SceneTree

const BattlefieldRulesScript = preload("res://scripts/battlefield_rules.gd")
const BattlefieldBiomesScript = preload("res://scripts/battlefield_biomes.gd")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	var field_size := Vector2(38.0, 26.0)
	var seed_value := 20261125
	var grass_zones := BattlefieldRulesScript.get_zones(BattlefieldBiomesScript.GRASSLAND, field_size, seed_value)
	_check(grass_zones.is_empty(), "grassland has no special terrain zones")

	for biome_id in [BattlefieldBiomesScript.WOODLAND, BattlefieldBiomesScript.HIGHLANDS, BattlefieldBiomesScript.MARSH]:
		var zones := BattlefieldRulesScript.get_zones(biome_id, field_size, seed_value)
		_check(zones.size() == 4, "%s creates four gameplay zones" % biome_id)
		BattlefieldRulesScript.get_zones(biome_id, field_size, seed_value + 1)
		var regenerated_zones := BattlefieldRulesScript.get_zones(biome_id, field_size, seed_value)
		_check(zones == regenerated_zones, "%s zone placement regenerates deterministically after cache replacement" % biome_id)
		_check(_zones_are_mirrored(zones), "%s zone layout is symmetric for both armies" % biome_id)

	var woodland_zones := BattlefieldRulesScript.get_zones(BattlefieldBiomesScript.WOODLAND, field_size, seed_value)
	var forest_center: Vector3 = woodland_zones[0].get("center", Vector3.ZERO)
	var forest_effects := BattlefieldRulesScript.get_effects_at_position(forest_center, BattlefieldBiomesScript.WOODLAND, field_size, seed_value, 0)
	_check(is_equal_approx(float(forest_effects.get("movement_multiplier", 0.0)), 0.90), "forest reduces movement speed by ten percent")
	_check(is_equal_approx(float(forest_effects.get("ranged_damage_taken_multiplier", 0.0)), 0.82), "forest cover reduces incoming ranged damage by eighteen percent")

	var highland_zones := BattlefieldRulesScript.get_zones(BattlefieldBiomesScript.HIGHLANDS, field_size, seed_value)
	var high_center: Vector3 = highland_zones[0].get("center", Vector3.ZERO)
	var high_archer := BattlefieldRulesScript.get_effects_at_position(high_center, BattlefieldBiomesScript.HIGHLANDS, field_size, seed_value, 1)
	_check(is_equal_approx(float(high_archer.get("ranged_damage_dealt_multiplier", 0.0)), 1.10), "archers on high ground deal ten percent more damage")
	_check(is_equal_approx(float(high_archer.get("ranged_damage_taken_multiplier", 0.0)), 0.92), "high ground reduces incoming ranged damage by eight percent")

	var marsh_zones := BattlefieldRulesScript.get_zones(BattlefieldBiomesScript.MARSH, field_size, seed_value)
	var marsh_center: Vector3 = marsh_zones[0].get("center", Vector3.ZERO)
	var marsh_infantry := BattlefieldRulesScript.get_effects_at_position(marsh_center, BattlefieldBiomesScript.MARSH, field_size, seed_value, 0)
	var marsh_cavalry := BattlefieldRulesScript.get_effects_at_position(marsh_center, BattlefieldBiomesScript.MARSH, field_size, seed_value, 3)
	_check(is_equal_approx(float(marsh_infantry.get("movement_multiplier", 0.0)), 0.82), "marsh reduces infantry movement by eighteen percent")
	_check(is_equal_approx(float(marsh_cavalry.get("movement_multiplier", 0.0)), 0.65), "marsh reduces cavalry movement by thirty-five percent")
	_check(not bool(marsh_cavalry.get("charge_allowed", true)), "cavalry charge is disabled inside marsh zones")

	var open_ground := BattlefieldRulesScript.get_effects_at_position(Vector3.ZERO, BattlefieldBiomesScript.WOODLAND, field_size, seed_value, 1)
	_check(str(open_ground.get("zone_type", "")) == "open_ground", "units outside zones receive neutral terrain effects")
	_check(is_equal_approx(float(open_ground.get("movement_multiplier", 0.0)), 1.0), "open ground preserves original movement speed")

	if _failures > 0:
		printerr("Battlefield rules smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All battlefield rules smoke tests passed.")
		quit(0)


func _zones_are_mirrored(zones: Array[Dictionary]) -> bool:
	if zones.size() != 4:
		return false
	var points: Array[Vector2] = []
	for zone in zones:
		var center: Vector3 = zone.get("center", Vector3.ZERO)
		points.append(Vector2(center.x, center.z))
	for point in points:
		if not _contains_point(points, Vector2(-point.x, point.y)):
			return false
		if not _contains_point(points, Vector2(point.x, -point.y)):
			return false
	return true


func _contains_point(points: Array[Vector2], expected: Vector2) -> bool:
	for point in points:
		if point.distance_to(expected) <= 0.001:
			return true
	return false
