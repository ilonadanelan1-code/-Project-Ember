extends SceneTree

const BattleUnitScript = preload("res://scripts/battle_unit.gd")
const CampaignStateScript = preload("res://scripts/campaign_state.gd")

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
	# Reproduce the actual save-state bug: a ruler killed in a previous battle
	# remains stored with zero HP, and the old code spawned that commander at 0.
	var campaign_state := CampaignStateScript.new()
	root.add_child(campaign_state)
	campaign_state.new_campaign(false)

	var first_kingdom: Dictionary = campaign_state.kingdoms[0]
	var stored_hero: Dictionary = first_kingdom.get("hero", {})
	stored_hero["health"] = 0.0
	stored_hero["wounded_turns"] = 2
	first_kingdom["hero"] = stored_hero
	campaign_state.kingdoms[0] = first_kingdom

	_check(campaign_state.begin_battle("", 0), "campaign starts a battle against a kingdom with a previously defeated ruler")
	var recovered_hero: Dictionary = campaign_state.enemy_hero
	var recovered_health := float(recovered_hero.get("health", 0.0))
	var expected_recovered_health := campaign_state.get_hero_max_health(recovered_hero) * 0.35
	_check(is_equal_approx(recovered_health, expected_recovered_health), "zero-health enemy ruler is restored to 35% health before combat")
	var persisted_kingdom: Dictionary = campaign_state.kingdoms[0]
	var persisted_hero: Dictionary = persisted_kingdom.get("hero", {})
	_check(float(persisted_hero.get("health", 0.0)) > 0.0, "recovered ruler health is written back into the kingdom save record")

	# Spawn the commander exactly as combat_test.gd does, using the campaign record.
	var arena := Node3D.new()
	arena.name = "BattleEngagementSmokeTestArena"
	root.add_child(arena)
	var player_unit := _make_unit(arena, 0, BattleUnitScript.UnitRole.MELEE, Vector3(-5.0, 0.0, 0.0))
	var enemy_commander := BattleUnitScript.new() as BattleUnit
	enemy_commander.team = 1
	enemy_commander.role = BattleUnitScript.UnitRole.COMMANDER
	enemy_commander.commander_level = int(recovered_hero.get("level", 1))
	var skills: Dictionary = recovered_hero.get("skills", {})
	enemy_commander.commander_leadership = int(skills.get("leadership", 0))
	enemy_commander.commander_tactics = int(skills.get("tactics", 0))
	enemy_commander.commander_might = int(skills.get("might", 0))
	enemy_commander.starting_health = recovered_health
	enemy_commander.position = Vector3(5.0, 0.0, 0.0)
	arena.add_child(enemy_commander)
	await process_frame

	_check(enemy_commander.health > 0.0, "spawned enemy commander is alive and can receive orders")
	var commander_start_health := enemy_commander.health
	var commander_start_x := enemy_commander.global_position.x
	var player_start_health := player_unit.health
	var player_start_x := player_unit.global_position.x
	await create_timer(2.4).timeout

	_check(enemy_commander._has_valid_target(), "enemy commander automatically acquires the player army at battle start")
	_check(enemy_commander.global_position.x < commander_start_x, "enemy commander advances instead of standing still")
	_check(enemy_commander.health < commander_start_health, "player army can damage the enemy commander")
	_check(player_unit.global_position.x > player_start_x, "enemy commander engages and moves toward the player")
	_check(player_unit.health < player_start_health, "enemy commander actively attacks the player army")

	# When the commander is the only enemy left, a fresh player unit beyond its
	# normal detection range must still acquire and pursue that last commander.
	player_unit.queue_free()
	await process_frame
	var last_guardian_pursuer := _make_unit(
		arena,
		0,
		BattleUnitScript.UnitRole.MELEE,
		Vector3(-15.0, 0.0, -10.0)
	)
	enemy_commander.position = Vector3(5.0, 0.0, -10.0)
	enemy_commander._target = null
	enemy_commander._order_mode = BattleUnitScript.OrderMode.AUTO
	await create_timer(0.18).timeout
	_check(
		last_guardian_pursuer._target == enemy_commander,
		"player army detects the last enemy commander beyond normal detection range"
	)
	_check(
		last_guardian_pursuer.velocity.x > 0.0,
		"player army advances toward the last enemy commander after a physics update"
	)

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
	var reengage_start_x := wounded_enemy.global_position.x
	await create_timer(0.35).timeout
	var reengage_distance := wounded_enemy.global_position.distance_to(nearby_player.global_position)
	var reengaging_in_melee := (
		wounded_enemy.velocity.x < -0.05
		or reengage_distance <= wounded_enemy.attack_range
		or wounded_enemy._pending_hit_timer >= 0.0
		or wounded_enemy._attack_animation_elapsed >= 0.0
	)
	_check(
		wounded_enemy.global_position.x < reengage_start_x or reengaging_in_melee,
		"retreated enemy closes distance or begins a melee strike instead of remaining idle"
	)

	arena.queue_free()
	campaign_state.free()
	await process_frame
	if _failures > 0:
		printerr("Battle engagement smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All battle engagement smoke tests passed.")
		quit(0)
