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
	arena.name = "BattleEngagementSmokeTestArena"
	root.add_child(arena)

	# Reproduce the stuck final commander: the enemy has no soldiers left,
	# only a critically wounded commander remains outside normal detection range.
	var player_unit := _make_unit(arena, 0, BattleUnitScript.UnitRole.MELEE, Vector3(-8.0, 0.0, 0.0))
	var enemy_commander := _make_unit(arena, 1, BattleUnitScript.UnitRole.COMMANDER, Vector3(8.0, 0.0, 0.0))
	await process_frame
	enemy_commander.health = 40.0
	enemy_commander._update_health_bar()

	player_unit.order_attack(enemy_commander)
	_check(player_unit._order_mode == BattleUnitScript.OrderMode.ATTACK, "player attack command accepts the enemy commander as a valid enemy target")
	_check(player_unit._target == enemy_commander, "player keeps the commanded enemy commander as its target")
	_check(enemy_commander._has_valid_target() or enemy_commander._find_nearest_enemy(30.0) == player_unit, "enemy commander can acquire the remaining player army at long range")

	var commander_start_x := enemy_commander.global_position.x
	var player_start_x := player_unit.global_position.x
	await create_timer(2.25).timeout

	_check(enemy_commander._order_mode != BattleUnitScript.OrderMode.RETREAT, "critically wounded enemy commander does not retreat out of the battle")
	_check(enemy_commander.global_position.x < commander_start_x, "enemy commander advances toward the player instead of standing still")
	_check(player_unit.global_position.x > player_start_x, "player unit automatically pursues the last remaining enemy commander")
	_check(is_instance_valid(enemy_commander) and enemy_commander.health > 0.0 and enemy_commander.health < 40.0, "player unit successfully damages the last enemy commander")

	# Ordinary wounded enemy troops may still retreat, but they must re-enter
	# AUTO after reaching the rear line rather than remain parked in HOLD forever.
	var nearby_player := _make_unit(arena, 0, BattleUnitScript.UnitRole.MELEE, Vector3(10.0, 0.0, 6.0))
	var wounded_enemy := _make_unit(arena, 1, BattleUnitScript.UnitRole.MELEE, Vector3(14.0, 0.0, 6.0))
	await process_frame
	wounded_enemy.health = 20.0
	wounded_enemy._update_health_bar()
	await create_timer(0.85).timeout

	_check(wounded_enemy._order_mode == BattleUnitScript.OrderMode.AUTO, "wounded enemy returns to AUTO after completing its retreat")
	_check(wounded_enemy._retreat_cooldown_timer > 0.0, "enemy retreat has a recovery delay that prevents immediate retreat loops")
	_check(wounded_enemy._target == nearby_player, "retreated enemy reacquires and re-engages the nearby player")
	_check(wounded_enemy.velocity.x < 0.0, "retreated enemy moves back toward the player instead of remaining stationary")

	arena.queue_free()
	await process_frame
	if _failures > 0:
		printerr("Battle engagement smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All battle engagement smoke tests passed.")
		quit(0)
