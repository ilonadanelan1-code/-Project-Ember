extends SceneTree

const BattleFlankingScript = preload("res://scripts/battle_flanking.gd")
const CombatStatusCatalogScript = preload("res://scripts/combat_status_catalog.gd")

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
	var target := Vector3.ZERO
	var facing := Vector3.RIGHT
	_check(BattleFlankingScript.classify_positions(Vector3(3.0, 0.0, 0.0), target, facing) == BattleFlankingScript.FRONT, "attack from the facing direction is classified as frontal")
	_check(BattleFlankingScript.classify_positions(Vector3(0.0, 0.0, 3.0), target, facing) == BattleFlankingScript.SIDE, "perpendicular attack is classified as a flank")
	_check(BattleFlankingScript.classify_positions(Vector3(-3.0, 0.0, 0.0), target, facing) == BattleFlankingScript.REAR, "attack from behind is classified as rear")
	_check(is_equal_approx(BattleFlankingScript.get_damage_multiplier(BattleFlankingScript.FRONT), 1.0), "frontal attacks have no damage bonus")
	_check(is_equal_approx(BattleFlankingScript.get_damage_multiplier(BattleFlankingScript.SIDE), 1.10), "side attacks gain ten percent damage")
	_check(is_equal_approx(BattleFlankingScript.get_damage_multiplier(BattleFlankingScript.REAR), 1.20), "rear attacks gain twenty percent damage")
	_check(BattleFlankingScript.exposes_target(BattleFlankingScript.SIDE), "side attacks expose the target")
	_check(BattleFlankingScript.exposes_target(BattleFlankingScript.REAR), "rear attacks expose the target")
	_check(not BattleFlankingScript.exposes_target(BattleFlankingScript.FRONT), "frontal attacks do not expose the target")
	var exposed := CombatStatusCatalogScript.get_data(CombatStatusCatalogScript.EXPOSED)
	_check(is_equal_approx(float(exposed.get("duration", 0.0)), 1.8), "exposed status lasts 1.8 seconds")
	_check(is_equal_approx(float(exposed.get("incoming_damage_multiplier", 0.0)), 1.10), "exposed target receives ten percent more damage")

	if _failures > 0:
		printerr("Battle flanking smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All battle flanking smoke tests passed.")
		quit(0)
