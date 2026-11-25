extends RefCounted
class_name BattleFlanking

const FRONT := "front"
const SIDE := "side"
const REAR := "rear"
const SIDE_DAMAGE_MULTIPLIER := 1.10
const REAR_DAMAGE_MULTIPLIER := 1.20
const EXPOSED_DURATION := 1.8


static func classify_positions(attacker_position: Vector3, target_position: Vector3, target_facing: Vector3) -> String:
	var to_attacker := attacker_position - target_position
	to_attacker.y = 0.0
	if to_attacker.length_squared() <= 0.001:
		return FRONT
	var facing := target_facing
	facing.y = 0.0
	if facing.length_squared() <= 0.001:
		return FRONT
	var alignment := facing.normalized().dot(to_attacker.normalized())
	if alignment >= 0.45:
		return FRONT
	if alignment <= -0.45:
		return REAR
	return SIDE


static func classify_attack(attacker: Node3D, target: Node3D) -> String:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return FRONT
	var facing := Vector3.RIGHT
	if target.has_method("get_combat_facing_direction"):
		facing = target.call("get_combat_facing_direction")
	return classify_positions(attacker.global_position, target.global_position, facing)


static func get_damage_multiplier(attack_arc: String) -> float:
	match attack_arc:
		SIDE:
			return SIDE_DAMAGE_MULTIPLIER
		REAR:
			return REAR_DAMAGE_MULTIPLIER
		_:
			return 1.0


static func exposes_target(attack_arc: String) -> bool:
	return attack_arc == SIDE or attack_arc == REAR
