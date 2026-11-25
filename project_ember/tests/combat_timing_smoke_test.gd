extends SceneTree

const BattleUnitScript = preload("res://scripts/battle_unit.gd")
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _make_unit(parent: Node3D, team_id: int, role_id: int, point: Vector3) -> BattleUnit:
	var unit := BattleUnitScript.new() as BattleUnit
	unit.team = team_id
	unit.role = role_id
	unit.position = point
	parent.add_child(unit)
	return unit


func _run() -> void:
	var arena := Node3D.new()
	arena.name = "CombatTimingSmokeTestArena"
	root.add_child(arena)
	var attacker := _make_unit(arena, 0, 0, Vector3.ZERO)
	var target := _make_unit(arena, 1, 0, Vector3(1.0, 0.0, 0.0))
	await process_frame

	var health_before: float = target.health
	attacker._begin_melee_attack(target, 17.0, false)
	var contact_time: float = attacker._pending_hit_timer
	_check(contact_time > 0.0, "melee hit is queued for weapon contact")
	_check(is_equal_approx(target.health, health_before), "starting a swing does not apply damage immediately")
	attacker._tick_pending_combat(maxf(0.01, contact_time - 0.02))
	_check(is_equal_approx(target.health, health_before), "target remains unharmed before contact")
	attacker._tick_pending_combat(0.04)
	_check(target.health < health_before, "damage applies when contact timer reaches zero")
	_check(is_equal_approx(attacker._get_melee_engagement_range(), attacker.attack_range), "melee wind-up starts at the original role attack range")

	var moving_target := _make_unit(arena, 1, 0, Vector3(attacker.attack_range, 0.0, 1.0))
	var moving_target_health := moving_target.health
	attacker._begin_melee_attack(moving_target, 17.0, false)
	moving_target.position.x += 0.55
	attacker._tick_pending_combat(0.20)
	_check(moving_target.health < moving_target_health, "committed melee swing still connects after small target movement during wind-up")

	attacker._target = target
	attacker._begin_melee_attack(target, 25.0, false)
	var damage_before_death: float = attacker.damage_dealt
	target.take_damage(target.max_health + 1000.0)
	attacker._tick_pending_combat(0.20)
	_check(not attacker._has_valid_target(), "dead unit is no longer a valid target")
	_check(is_equal_approx(attacker.damage_dealt, damage_before_death), "pending swing cannot damage a corpse")

	var replacement := _make_unit(arena, 1, 0, Vector3(1.0, 0.0, 1.0))
	attacker._begin_melee_attack(replacement, 20.0, false)
	attacker.order_stop()
	attacker._tick_pending_combat(0.25)
	_check(is_equal_approx(replacement.health, replacement.max_health), "stop order cancels an unfinished attack")
	_check(attacker._pending_hit_timer < 0.0, "cancelling an order clears pending hit state")

	var archer := _make_unit(arena, 0, 1, Vector3(-1.0, 0.0, 0.0))
	archer._begin_ranged_attack(replacement)
	_check(archer._pending_projectile_timer > 0.0, "projectile is queued for bow release")
	archer._tick_pending_combat(maxf(0.01, archer._pending_projectile_timer - 0.02))
	_check(archer._pending_projectile_timer > 0.0, "arrow is not spawned before release")
	archer.order_stop()
	_check(archer._pending_projectile_timer < 0.0, "new order cancels a queued projectile")

	arena.queue_free()
	await process_frame
	if _failures > 0:
		printerr("Combat timing smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All combat timing smoke tests passed.")
		quit(0)
