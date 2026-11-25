extends RefCounted
class_name BattleAITactics

# Role values mirror BattleUnit.UnitRole and do not alter campaign/save IDs.
const ROLE_MELEE := 0
const ROLE_RANGED := 1
const ROLE_SPEAR := 2
const ROLE_CAVALRY := 3
const ROLE_COMMANDER := 4

static func get_target_score(attacker_role: int, target_role: int, distance: float, target_health_ratio: float) -> float:
	var preference := _get_role_preference(attacker_role, target_role)
	var missing_health := 1.0 - clampf(target_health_ratio, 0.0, 1.0)
	return 100.0 * preference - 4.0 * maxf(0.0, distance) + 10.0 * missing_health


static func _get_role_preference(attacker_role: int, target_role: int) -> float:
	match attacker_role:
		ROLE_RANGED:
			if target_role == ROLE_CAVALRY:
				return 1.22
			if target_role == ROLE_RANGED:
				return 1.05
			if target_role == ROLE_COMMANDER:
				return 0.95
		ROLE_SPEAR:
			if target_role == ROLE_CAVALRY:
				return 1.45
		ROLE_CAVALRY:
			if target_role == ROLE_RANGED:
				return 1.35
			if target_role == ROLE_COMMANDER:
				return 1.05
			if target_role == ROLE_SPEAR:
				return 0.90
			return 0.95
		ROLE_MELEE:
			if target_role == ROLE_COMMANDER:
				return 1.03
		ROLE_COMMANDER:
			if target_role == ROLE_CAVALRY:
				return 1.10
			if target_role == ROLE_RANGED:
				return 1.05
	return 1.0
