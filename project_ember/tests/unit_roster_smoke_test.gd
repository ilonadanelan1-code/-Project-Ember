extends SceneTree

const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const UnitCatalogScript = preload("res://scripts/unit_catalog.gd")
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
	state.city_gold = 500

	_check(UnitCatalogScript.role_ids().size() == 4, "unit catalog contains four stable role identifiers")
	_check(not state.can_queue_recruit(state.ROLE_RANGED), "archers remain locked before an archery range is built")
	_check(not state.can_queue_recruit(state.ROLE_CAVALRY), "cavalry remains locked before a stable is built")
	_check(not state.can_queue_recruit(state.ROLE_MELEE), "swordsmen require completed barracks")
	_check(not state.can_queue_recruit(state.ROLE_SPEAR), "spearmen require completed barracks")

	_check(not state.can_queue_building("archery_range"), "archery range requires barracks")
	_check(not state.can_queue_building("stable"), "stable requires barracks")
	_check(state.queue_building("barracks"), "barracks can be queued")
	state.city_production_bank = 8
	state._process_city_queue()
	_check(state.city_has_building("barracks"), "barracks unlock prerequisite is applied on completion")
	_check(state.can_queue_recruit(state.ROLE_MELEE), "completed barracks unlock swordsmen")
	_check(state.can_queue_recruit(state.ROLE_SPEAR), "completed barracks unlock spearmen")

	_check(state.queue_building("archery_range"), "archery range can be queued after barracks")
	_check(state.queue_building("stable"), "stable can be queued after barracks")
	state.city_production_bank = 18
	state._process_city_queue()
	_check(state.city_has_building("archery_range"), "archery range is constructed")
	_check(state.city_has_building("stable"), "stable is constructed")
	_check(state.can_queue_recruit(state.ROLE_RANGED), "archery range unlocks archers")
	_check(state.can_queue_recruit(state.ROLE_CAVALRY), "stable unlocks cavalry")

	var starting_size := state.player_units.size()
	for role_id in UnitCatalogScript.role_ids():
		_check(state.queue_recruit(role_id), "city accepts recruitment: " + role_id)
	state.city_production_bank = 64
	state._process_city_queue()
	_check(state.player_units.size() == starting_size + 4, "all four new recruit orders create army records")

	var normalized := state._read_unit_records(state.player_units)
	var found_roles: Dictionary = {}
	for record in normalized:
		found_roles[str(record.get("role", ""))] = true
	_check(found_roles.has(UnitCatalogScript.ROLE_MELEE), "save validation preserves melee units")
	_check(found_roles.has(UnitCatalogScript.ROLE_RANGED), "save validation preserves ranged units")
	_check(found_roles.has(UnitCatalogScript.ROLE_SPEAR), "save validation preserves spearmen")
	_check(found_roles.has(UnitCatalogScript.ROLE_CAVALRY), "save validation preserves cavalry")
	_check(state.save_campaign(), "campaign persists the expanded four-role army")
	state.player_units.clear()
	_check(state.load_campaign(), "campaign reloads the expanded army")
	var loaded_roles: Dictionary = {}
	for record in state.player_units:
		loaded_roles[str(record.get("role", ""))] = true
	_check(loaded_roles.has(UnitCatalogScript.ROLE_SPEAR), "save/load round-trip preserves spearmen")
	_check(loaded_roles.has(UnitCatalogScript.ROLE_CAVALRY), "save/load round-trip preserves cavalry")

	var spear: Variant = BattleUnitScript.new()
	spear.role = 2
	spear._apply_role_stats()
	_check(is_equal_approx(spear.max_health, 108.0), "spearman receives its role-specific health")
	_check(spear.attack_range > 2.0, "spearman has an extended melee reach")
	_check(spear.armor > 0.0, "spearman receives armor")
	spear.free()

	var cavalry: Variant = BattleUnitScript.new()
	cavalry.role = 3
	cavalry._apply_role_stats()
	_check(cavalry.move_speed > 5.0, "cavalry is the fastest unit role")
	_check(cavalry.charge_multiplier > 1.0, "cavalry receives a charge damage bonus")
	_check(is_equal_approx(cavalry.get_strike_damage_against(spear), 22.0), "cavalry deals normal damage without a charge")
	cavalry._charge_armed = true
	_check(is_equal_approx(cavalry.get_strike_damage_against(spear), 35.2), "cavalry gets its charge multiplier after a running approach")
	_check(is_equal_approx(spear.get_strike_damage_against(cavalry), 29.7), "spearmen deal bonus damage against cavalry")

	var armored_target: Variant = BattleUnitScript.new()
	armored_target.role = 2
	armored_target._apply_role_stats()
	armored_target.health = armored_target.max_health
	armored_target.take_damage(10.0, cavalry)
	_check(is_equal_approx(armored_target.health, 102.0), "unit armor reduces incoming damage")
	armored_target.free()
	cavalry.free()

	state.free()
	if _failures > 0:
		printerr("Unit roster smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All unit roster smoke tests passed.")
		quit(0)