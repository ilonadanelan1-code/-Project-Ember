extends SceneTree

const BattleEstimatorScript = preload("res://scripts/battle_estimator.gd")

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
	var balanced_player: Array = [
		{"role": "melee", "health": 125.0, "experience": 0},
		{"role": "melee", "health": 125.0, "experience": 0},
		{"role": "ranged", "health": 72.0, "experience": 0},
	]
	var balanced_enemy: Array = [
		{"role": "melee", "health": 125.0, "experience": 0},
		{"role": "melee", "health": 125.0, "experience": 0},
		{"role": "ranged", "health": 72.0, "experience": 0},
	]
	var balanced_player_copy := balanced_player.duplicate(true)
	var balanced_enemy_copy := balanced_enemy.duplicate(true)
	var equal_result := BattleEstimatorScript.estimate(balanced_player, balanced_enemy)
	_check(bool(equal_result.get("valid", false)), "balanced non-empty forces produce a valid battle forecast")
	_check(int(equal_result.get("player_win_chance", -1)) == 50, "identical armies receive a symmetric 50 percent forecast")
	_check(equal_result == BattleEstimatorScript.estimate(balanced_player, balanced_enemy), "the same force data produces a deterministic forecast")
	_check(balanced_player == balanced_player_copy and balanced_enemy == balanced_enemy_copy, "estimating a battle does not modify unit health, experience or source arrays")
	_check(int(equal_result.get("confidence_low", 0)) < 50 and int(equal_result.get("confidence_high", 100)) > 50, "the forecast exposes an uncertainty interval rather than claiming certainty")

	var reinforced_player: Array = balanced_player.duplicate(true)
	reinforced_player.append({"role": "spear", "health": 108.0, "experience": 40})
	reinforced_player.append({"role": "cavalry", "health": 155.0, "experience": 100})
	var reinforced_result := BattleEstimatorScript.estimate(reinforced_player, balanced_enemy)
	_check(int(reinforced_result.get("player_win_chance", 50)) > 50, "additional healthy troops improve the estimated chance of victory")
	_check(int(reinforced_result.get("player_units", 0)) == 5, "the forecast includes the complete supplied army roster")

	var cavalry_force: Array = [{"role": "cavalry", "health": 155.0, "experience": 0}]
	var spear_force: Array = [{"role": "spear", "health": 108.0, "experience": 0}]
	var melee_force: Array = [{"role": "melee", "health": 125.0, "experience": 0}]
	var spear_counter := BattleEstimatorScript.estimate(spear_force, cavalry_force)
	var melee_comparison := BattleEstimatorScript.estimate(melee_force, cavalry_force)
	_check(
		float(spear_counter.get("player_dps", 0.0)) > float(melee_comparison.get("player_dps", 0.0)),
		"the estimator applies the spear unit's real anti-cavalry multiplier"
	)

	var novice_force: Array = [{"role": "melee", "health": 125.0, "experience": 0}]
	var elite_force: Array = [{"role": "melee", "health": 125.0, "experience": 180}]
	var no_upgrade: Dictionary = {"melee": 0, "ranged": 0, "spear": 0, "cavalry": 0}
	var elite_upgrade: Dictionary = {"melee": 2, "ranged": 0, "spear": 0, "cavalry": 0}
	var novice_vs_equal := BattleEstimatorScript.estimate(novice_force, melee_force)
	var elite_vs_equal := BattleEstimatorScript.estimate(elite_force, melee_force)
	var upgrade_vs_equal := BattleEstimatorScript.estimate(novice_force, melee_force, {}, {}, {}, {}, elite_upgrade, no_upgrade)
	_check(float(elite_vs_equal.get("player_dps", 0.0)) > float(novice_vs_equal.get("player_dps", 0.0)), "veterancy damage bonuses are included in the estimated attack output")
	_check(float(upgrade_vs_equal.get("enemy_dps", 0.0)) < float(novice_vs_equal.get("enemy_dps", 0.0)), "purchased armour upgrades reduce the expected damage received")

	var healthy_result := BattleEstimatorScript.estimate(novice_force, melee_force)
	var wounded_force: Array = [{"role": "melee", "health": 25.0, "experience": 0}]
	var wounded_result := BattleEstimatorScript.estimate(wounded_force, melee_force)
	_check(float(wounded_result.get("player_dps", 0.0)) < float(healthy_result.get("player_dps", 0.0)), "current troop health reduces the effective combat output")

	var ranged_force: Array = [{"role": "ranged", "health": 72.0, "experience": 0}]
	var archer_plain := BattleEstimatorScript.estimate(melee_force, ranged_force, {}, {}, {}, {}, {}, {}, "grassland")
	var archer_forest := BattleEstimatorScript.estimate(melee_force, ranged_force, {}, {}, {}, {}, {}, {}, "woodland")
	_check(float(archer_forest.get("enemy_dps", 0.0)) < float(archer_plain.get("enemy_dps", 0.0)), "woodland cover reduces expected damage from ranged units")
	var cavalry_plain := BattleEstimatorScript.estimate(cavalry_force, melee_force, {}, {}, {}, {}, {}, {}, "grassland")
	var cavalry_marsh := BattleEstimatorScript.estimate(cavalry_force, melee_force, {}, {}, {}, {}, {}, {}, "marsh")
	_check(float(cavalry_marsh.get("player_dps", 0.0)) < float(cavalry_plain.get("player_dps", 0.0)), "marsh terrain reduces the expected value of cavalry charges")

	var player_hero := {
		"id": "hero_test",
		"health": 210.0,
		"level": 4,
		"skills": {"leadership": 2, "tactics": 1, "might": 2},
	}
	var commander_stats: Dictionary = {
		"max_health": 272.0,
		"attack_damage": 39.0,
		"attack_cooldown": 0.88,
		"armor": 5.6,
		"leadership": 2,
		"tactics": 1,
	}
	var commander_result := BattleEstimatorScript.estimate(
		novice_force,
		melee_force,
		player_hero,
		player_hero,
		commander_stats,
		commander_stats
	)
	_check(int(commander_result.get("player_units", 0)) == 2 and bool(commander_result.get("player_hero_included", false)), "a living commander is included as a separate tactical combatant")
	_check(float(commander_result.get("player_strength", 0.0)) > float(healthy_result.get("player_strength", 0.0)), "commander combat stats contribute to the estimated battle strength")

	var recovered_hero := {"id": "hero_defeated", "health": 0.0}
	var recovered_result := BattleEstimatorScript.estimate(novice_force, melee_force, recovered_hero, {}, {
		"max_health": 210.0, "attack_damage": 24.0, "attack_cooldown": 0.88, "armor": 4.0,
	}, {})
	_check(int(recovered_result.get("player_units", 0)) == 2, "a defeated commander uses the 35 percent recovery rule applied at tactical battle entry")

	var empty_result := BattleEstimatorScript.estimate([], melee_force)
	_check(not bool(empty_result.get("valid", true)), "empty armies are rejected without manufacturing a forecast")
	_check(str(equal_result.get("estimate_note", "")).contains("Расстановка"), "the result explains the tactical factors not modelled by a strategic forecast")

	if _failures == 0:
		print("All %d battle estimator checks passed." % _checks)
	else:
		push_error("Battle estimator checks failed: %d/%d" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)
