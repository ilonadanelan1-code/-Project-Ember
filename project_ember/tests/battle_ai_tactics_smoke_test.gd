extends SceneTree

const BattleAITacticsScript = preload("res://scripts/battle_ai_tactics.gd")

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
	var cavalry_score := BattleAITacticsScript.get_target_score(1, 3, 8.0, 1.0)
	var infantry_score := BattleAITacticsScript.get_target_score(1, 0, 8.0, 1.0)
	_check(cavalry_score > infantry_score, "archers prefer cavalry over an equally distant infantry target")

	var spear_cavalry_score := BattleAITacticsScript.get_target_score(2, 3, 8.0, 1.0)
	var spear_infantry_score := BattleAITacticsScript.get_target_score(2, 0, 8.0, 1.0)
	_check(spear_cavalry_score > spear_infantry_score, "spearmen strongly prioritize cavalry")

	var cavalry_archer_score := BattleAITacticsScript.get_target_score(3, 1, 8.0, 1.0)
	var cavalry_spear_score := BattleAITacticsScript.get_target_score(3, 2, 8.0, 1.0)
	_check(cavalry_archer_score > cavalry_spear_score, "cavalry prioritize ranged units")

	var wounded_target_score := BattleAITacticsScript.get_target_score(0, 0, 8.0, 0.2)
	var healthy_target_score := BattleAITacticsScript.get_target_score(0, 0, 8.0, 1.0)
	_check(wounded_target_score > healthy_target_score, "AI mildly prefers a wounded target of the same role")
	_check(BattleAITacticsScript.get_target_score(0, 0, 10.0, 1.0) < BattleAITacticsScript.get_target_score(0, 0, 5.0, 1.0), "AI still prefers a closer target when role preference is equal")

	if _failures > 0:
		printerr("Battle AI tactics smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All battle AI tactics smoke tests passed.")
		quit(0)
