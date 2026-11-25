extends SceneTree

const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const UnitCatalogScript = preload("res://scripts/unit_catalog.gd")
const ArmyUpgradeCatalogScript = preload("res://scripts/army_upgrade_catalog.gd")
const KingdomAIScript = preload("res://scripts/kingdom_ai.gd")
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
	_check(UnitCatalogScript.get_veterancy_rank(0) == 0, "new recruits start as rank-zero recruits")
	_check(UnitCatalogScript.get_veterancy_rank(40) == 1, "40 experience promotes a unit to trained")
	_check(UnitCatalogScript.get_veterancy_rank(100) == 2, "100 experience promotes a unit to veteran")
	_check(UnitCatalogScript.get_veterancy_rank(180) == 3, "180 experience promotes a unit to elite")
	_check(UnitCatalogScript.get_battle_experience(0, 0.0) == 6, "surviving units receive participation experience")
	_check(UnitCatalogScript.get_battle_experience(2, 80.0) == 24, "battle experience rewards two kills and damage")
	_check(UnitCatalogScript.get_battle_experience(1, 30.0) == 15, "battle experience formula rewards kills and damage")
	_check(UnitCatalogScript.get_battle_experience(10, 1000.0) == 30, "battle experience is capped at 30 per survivor")

	var state: Variant = CampaignStateScript.new()
	root.add_child(state)
	state.new_campaign()
	_check(state._read_unit_records([{"role": "melee", "health": 90.0}])[0].get("experience", -1) == 0, "legacy unit records default to zero experience")
	_check(not state.can_purchase_army_upgrade("melee"), "upgrade is locked until its required barracks are built")
	state.city_buildings.append("barracks")
	_check(state.can_purchase_army_upgrade("melee"), "barracks unlock the melee equipment upgrade")
	var starting_gold: int = state.city_gold
	_check(state.purchase_army_upgrade("melee"), "city can purchase the first melee upgrade")
	_check(state.get_army_upgrade_rank("melee") == 1, "first army upgrade rank is stored")
	_check(state.city_gold == starting_gold - 55, "first melee upgrade spends the catalogued gold cost")
	_check(not state.purchase_army_upgrade("ranged"), "archer upgrade requires the archery range")
	state.city_gold += 100
	_check(state.purchase_army_upgrade("melee"), "city can purchase the second melee upgrade")
	_check(state.get_army_upgrade_rank("melee") == 2, "second army upgrade rank is stored")
	_check(not state.can_purchase_army_upgrade("melee"), "army upgrade cannot exceed rank two")

	state.player_units[0]["experience"] = 120
	_check(state.save_campaign(), "unit experience and army upgrades save successfully")
	state.player_units[0]["experience"] = 0
	state.army_upgrades = {"melee": 0}
	_check(state.load_campaign(), "campaign with unit progression loads successfully")
	_check(int(state.player_units[0].get("experience", 0)) == 120, "individual unit experience survives save/load")
	_check(state.get_army_upgrade_rank("melee") == 2, "army-wide upgrade rank survives save/load")
	_check(state.get_army_upgrade_rank("ranged") == 0, "missing legacy upgrade fields default to rank zero")
	_check(state._read_army_upgrades({}).get("cavalry", -1) == 0, "legacy saves without the army upgrade dictionary default every role to zero")

	var normalized_kingdom := KingdomAIScript.normalize_kingdom(
		{"army": [{"role": "spear", "health": 80.0, "experience": 100}]},
		KingdomAIScript.create_initial_kingdoms()[0]
	)
	_check(int(normalized_kingdom["army"][0].get("experience", 0)) == 100, "AI kingdom normalization preserves unit experience")

	var elite: Variant = BattleUnitScript.new()
	elite.role = BattleUnitScript.UnitRole.MELEE
	elite.experience = 180
	elite.army_upgrade_rank = 2
	elite._apply_role_stats()
	_check(is_equal_approx(elite.attack_damage, 20.9), "elite veterancy adds ten percent base attack damage")
	_check(is_equal_approx(elite.armor, 6.0), "elite veterancy and rank-two shield upgrade add four armour")
	_check(is_equal_approx(float(ArmyUpgradeCatalogScript.get_rank_data("cavalry", 2).get("charge_bonus", 0.0)), 0.16), "cavalry rank two improves the charge multiplier by the catalog value")
	_check(is_equal_approx(float(ArmyUpgradeCatalogScript.get_rank_data("ranged", 1).get("damage_multiplier", 0.0)), 1.06), "archer upgrade values are data-driven")

	var upgraded_archer: Variant = BattleUnitScript.new()
	upgraded_archer.role = BattleUnitScript.UnitRole.RANGED
	upgraded_archer.army_upgrade_rank = 1
	upgraded_archer._apply_role_stats()
	_check(is_equal_approx(upgraded_archer.attack_damage, 13.78), "rank-one archer equipment changes actual tactical projectile damage")
	var upgraded_spearman: Variant = BattleUnitScript.new()
	upgraded_spearman.role = BattleUnitScript.UnitRole.SPEAR
	upgraded_spearman.army_upgrade_rank = 2
	upgraded_spearman._apply_role_stats()
	_check(is_equal_approx(upgraded_spearman.anti_cavalry_multiplier, 1.85), "rank-two spear equipment changes the actual anti-cavalry multiplier")
	var upgraded_cavalry: Variant = BattleUnitScript.new()
	upgraded_cavalry.role = BattleUnitScript.UnitRole.CAVALRY
	upgraded_cavalry.army_upgrade_rank = 2
	upgraded_cavalry._apply_role_stats()
	_check(is_equal_approx(upgraded_cavalry.charge_multiplier, 1.76), "rank-two cavalry equipment changes the actual charge multiplier")

	state.new_campaign()
	_check(state.begin_battle(), "progression integration test can begin a campaign battle")
	var battle_players: Array[Dictionary] = [{
		"role": "melee",
		"health": 100.0,
		"experience": 46,
		"battle_xp_gained": 6,
		"previous_veterancy_rank": 0,
	}]
	var no_enemy_survivors: Array[Dictionary] = []
	state.complete_battle(battle_players, no_enemy_survivors, true, {"player_kills": 0, "player_damage": 0.0})
	_check(int(state.last_battle_result.get("player_unit_xp_awarded", 0)) == 6, "battle completion records survivor XP")
	_check(int(state.last_battle_result.get("player_unit_promotions", 0)) == 1, "battle completion records a veterancy promotion")
	_check(int(state.player_units[0].get("experience", 0)) == 46, "battle completion retains the cumulative XP supplied by the combat result")

	state.free()
	elite.free()
	upgraded_archer.free()
	upgraded_spearman.free()
	upgraded_cavalry.free()
	if _failures > 0:
		printerr("Unit progression smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All unit progression smoke tests passed.")
		quit(0)
