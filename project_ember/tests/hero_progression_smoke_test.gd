extends SceneTree

const CampaignStateScript = preload("res://scripts/campaign_state.gd")
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


func _run() -> void:
	var state: Variant = CampaignStateScript.new()
	root.add_child(state)
	state.new_campaign()

	_check(not state.player_hero.is_empty(), "new campaign creates a persistent ruler hero")
	_check(int(state.player_hero.get("level", 0)) == 1, "new ruler starts at level one")
	_check(is_equal_approx(state.get_hero_max_health(state.player_hero), 210.0), "ruler starts with the correct commander health")
	_check(state.begin_battle(), "campaign can start a battle with its commander")

	var player_survivors: Array[Dictionary] = state._copy_unit_records(state.player_units)
	var enemy_survivors: Array[Dictionary] = state._copy_unit_records(state.enemy_units)
	var battle_stats := {"player_kills": 5, "player_damage": 260.0, "enemy_kills": 3, "enemy_damage": 140.0}
	state.complete_battle(player_survivors, enemy_survivors, true, battle_stats, 0.0, state.get_hero_max_health(state.enemy_hero))

	_check(int(state.player_hero.get("experience", 0)) > 0, "battle result awards commander experience")
	_check(int(state.player_hero.get("level", 1)) >= 2, "battle experience can level up the commander")
	_check(int(state.player_hero.get("skill_points", 0)) > 0, "commander level-up grants a skill point")
	_check(is_equal_approx(float(state.player_hero.get("health", -1.0)), 0.0), "a defeated commander remains wounded instead of being revived by level-up")

	var saved_level := int(state.player_hero.get("level", 1))
	var saved_experience := int(state.player_hero.get("experience", 0))
	_check(state.upgrade_hero_skill("leadership"), "commander can spend a skill point on leadership")
	var skill_data: Dictionary = state.player_hero.get("skills", {})
	_check(int(skill_data.get("leadership", 0)) == 1, "leadership rank is recorded")
	_check(int(state.player_hero.get("skill_points", 0)) == 0, "spending a skill point reduces the available points")

	_check(state.save_campaign(), "hero progression is included in the campaign save")
	state.player_hero["name"] = "BROKEN"
	state.player_hero["skills"] = {}
	_check(state.load_campaign(), "campaign with hero progression can be loaded")
	_check(str(state.player_hero.get("name", "")) == "Эдрик", "hero identity survives save and load")
	_check(int(state.player_hero.get("level", 1)) == saved_level, "hero level survives save and load")
	_check(int(state.player_hero.get("experience", 0)) == saved_experience, "hero experience survives save and load")
	var loaded_skills: Dictionary = state.player_hero.get("skills", {})
	_check(int(loaded_skills.get("leadership", 0)) == 1, "hero skill ranks survive save and load")

	state.advance_campaign_turn()
	_check(float(state.player_hero.get("health", 0.0)) > 0.0, "a wounded commander recovers after the campaign advances a turn")

	var fallback := state._make_hero_record("Старый правитель", "Правитель")
	var legacy_hero: Dictionary = state._read_hero_record({}, fallback)
	_check(int(legacy_hero.get("level", 0)) == 1, "legacy campaigns can receive a default hero record")

	var commander: Variant = BattleUnitScript.new()
	commander.team = 0
	commander.role = BattleUnitScript.UnitRole.COMMANDER
	commander.commander_level = 3
	commander.commander_leadership = 2
	commander.commander_tactics = 2
	commander.commander_might = 1
	root.add_child(commander)

	var ally: Variant = BattleUnitScript.new()
	ally.team = 0
	ally.role = BattleUnitScript.UnitRole.MELEE
	ally.position = Vector3(2.0, 0.0, 0.0)
	root.add_child(ally)
	await process_frame

	_check(commander.max_health > 210.0, "commander combat stats scale with level and might")
	commander._refresh_commander_aura()
	_check(ally.command_damage_bonus > 0.0, "commander aura increases nearby allied damage")
	_check(ally.command_speed_bonus > 0.0, "commander aura increases nearby allied movement")

	ally.take_damage(40.0, commander)
	var health_before_rally: float = ally.health
	_check(commander.activate_rally(), "commander can activate the battle cry")
	_check(ally.health > health_before_rally, "battle cry heals nearby allies")
	_check(ally.rally_timer > 0.0 and ally.rally_damage_bonus > 0.0, "battle cry grants a temporary combat buff")
	_check(not commander.activate_rally(), "battle cry respects its cooldown")

	commander.free()
	ally.free()
	state.free()

	if _failures > 0:
		printerr("Hero progression smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All hero progression smoke tests passed.")
		quit(0)
