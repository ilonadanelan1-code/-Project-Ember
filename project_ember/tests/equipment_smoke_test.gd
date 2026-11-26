extends SceneTree

const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const ItemCatalogScript = preload("res://scripts/item_catalog.gd")
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
	state.new_campaign(false)
	state._prevent_save_overwrite = false

	var hero_id: String = state.active_hero_id
	var hero: Dictionary = state.player_hero.duplicate(true)
	_check(hero.get("equipment", {}) is Dictionary, "new heroes start with equipment slots")
	_check(hero.get("inventory", []) is Array and hero.get("inventory", []).is_empty(), "new heroes start with an empty inventory")
	_check(ItemCatalogScript.SLOT_IDS.size() == 3, "item catalog defines weapon, armor and relic slots")
	_check(ItemCatalogScript.get_item_ids().size() >= 12, "item catalog contains a data-driven equipment set")

	var legacy_fallback: Dictionary = state._make_hero_record("Старый правитель", "Правитель")
	var legacy_hero: Dictionary = state._read_hero_record({"id": "legacy_hero", "name": "Старый правитель"}, legacy_fallback)
	var legacy_equipment: Dictionary = legacy_hero.get("equipment", {})
	_check(legacy_equipment.size() == 3, "legacy hero records receive all missing equipment slots")
	_check(legacy_hero.get("inventory", []) is Array and legacy_hero.get("inventory", []).is_empty(), "legacy hero records receive a safe empty inventory")

	var base_stats: Dictionary = state.get_hero_combat_stats(hero)
	_check(is_equal_approx(float(base_stats.get("max_health", 0.0)), 210.0), "shared commander stats preserve legacy base health")

	_check(state._add_item_to_hero_inventory(hero_id, "iron_edge"), "test item can enter the hero inventory")
	var iron_stats: Dictionary = state.get_hero_stats_with_item(state.player_hero, "weapon", "iron_edge")
	_check(is_equal_approx(float(iron_stats.get("attack_damage", 0.0)) - float(base_stats.get("attack_damage", 0.0)), 3.0), "weapon comparison calculates its expected damage change")
	_check(state.equip_item_to_hero(hero_id, "iron_edge"), "weapon can be equipped from the hero inventory")
	_check(str(state.player_hero.get("equipment", {}).get("weapon", "")) == "iron_edge", "equipped weapon is stored on its hero")
	_check(not state.get_hero_inventory_item_ids(hero_id).has("iron_edge"), "equipped item is removed from the carried inventory")

	_check(state._add_item_to_hero_inventory(hero_id, "rune_blade"), "replacement weapon can be added")
	_check(state.equip_item_to_hero(hero_id, "rune_blade"), "a better weapon can replace the current slot item")
	_check(str(state.player_hero.get("equipment", {}).get("weapon", "")) == "rune_blade", "replacement weapon becomes the equipped item")
	_check(state.get_hero_inventory_item_ids(hero_id).has("iron_edge"), "replaced equipment returns to the inventory")
	_check(state.unequip_hero_slot(hero_id, "weapon"), "equipped weapon can be unequipped")
	_check(str(state.player_hero.get("equipment", {}).get("weapon", "")).is_empty(), "unequipping clears the selected slot")
	_check(state.get_hero_inventory_item_ids(hero_id).has("rune_blade"), "unequipped items return to the inventory")
	_check(state.equip_item_to_hero(hero_id, "rune_blade"), "the weapon can be equipped again")

	_check(state._add_item_to_hero_inventory(hero_id, "guardian_plate"), "armor reward can be stored")
	_check(state.equip_item_to_hero(hero_id, "guardian_plate"), "armor can be equipped")
	_check(state._add_item_to_hero_inventory(hero_id, "war_banner"), "relic reward can be stored")
	_check(state.equip_item_to_hero(hero_id, "war_banner"), "relic can be equipped")
	var equipped_stats: Dictionary = state.get_hero_combat_stats(state.player_hero)
	_check(float(equipped_stats.get("max_health", 0.0)) >= 222.0, "armor health modifiers affect shared commander stats")
	_check(float(equipped_stats.get("armor", 0.0)) >= 7.0, "armor modifiers affect commander protection")
	_check(int(equipped_stats.get("leadership", 0)) == 1, "relic skill bonuses affect effective commander leadership")

	var unit: Variant = BattleUnitScript.new()
	unit.role = BattleUnitScript.UnitRole.COMMANDER
	unit.commander_level = int(state.player_hero.get("level", 1))
	var skills_value: Variant = state.player_hero.get("skills", {})
	var skills: Dictionary = skills_value if skills_value is Dictionary else {}
	unit.commander_leadership = int(skills.get("leadership", 0))
	unit.commander_tactics = int(skills.get("tactics", 0))
	unit.commander_might = int(skills.get("might", 0))
	unit.commander_equipment_modifiers = state.get_hero_equipment_modifiers(state.player_hero)
	unit._apply_role_stats()
	_check(is_equal_approx(unit.max_health, float(equipped_stats.get("max_health", 0.0))), "tactical commander health uses the shared equipment calculation")
	_check(is_equal_approx(unit.attack_damage, float(equipped_stats.get("attack_damage", 0.0))), "tactical commander damage uses the shared equipment calculation")
	_check(is_equal_approx(unit.armor, float(equipped_stats.get("armor", 0.0))), "tactical commander armor uses the shared equipment calculation")
	_check(is_equal_approx(unit.move_speed, float(equipped_stats.get("move_speed", 0.0))), "tactical commander speed uses the shared equipment calculation")
	unit.free()

	_check(state.save_campaign(), "hero equipment and inventory campaign state saves")
	state.player_hero["equipment"] = {}
	state.player_hero["inventory"] = []
	_check(state.load_campaign(), "campaign with hero equipment loads")
	_check(str(state.player_hero.get("equipment", {}).get("weapon", "")) == "rune_blade", "equipped weapon survives save and load")
	_check(str(state.player_hero.get("equipment", {}).get("armor", "")) == "guardian_plate", "equipped armor survives save and load")
	_check(str(state.player_hero.get("equipment", {}).get("relic", "")) == "war_banner", "equipped relic survives save and load")
	_check(state.get_hero_inventory_item_ids(hero_id).has("iron_edge"), "carried inventory survives save and load")

	var repeat_reward_a := ItemCatalogScript.get_deterministic_battle_reward(12345, 7, 3, "kingdom", "2", hero_id)
	var repeat_reward_b := ItemCatalogScript.get_deterministic_battle_reward(12345, 7, 3, "kingdom", "2", hero_id)
	_check(repeat_reward_a == repeat_reward_b, "battle loot is deterministic for identical campaign inputs")

	_check(state.begin_battle(), "campaign battle can begin for loot integration testing")
	if state.battle_in_progress:
		var reward_sequence := 1
		var expected_reward := ""
		while reward_sequence < 500:
			expected_reward = ItemCatalogScript.get_deterministic_battle_reward(
				state.world_seed,
				state.turn_number,
				reward_sequence,
				state.battle_target_type,
				str(state.battle_location_id if state.battle_target_type == "location" else state.battle_kingdom_id),
				state.active_hero_id
			)
			if not expected_reward.is_empty():
				break
			reward_sequence += 1
		state.battle_reward_counter = reward_sequence - 1
		var survivors: Array[Dictionary] = state._copy_unit_records(state.player_units)
		var enemy_survivors: Array[Dictionary] = state._copy_unit_records(state.enemy_units)
		state.complete_battle(
			survivors,
			enemy_survivors,
			true,
			{"player_kills": 1, "player_damage": 60.0},
			state.get_hero_max_health(state.player_hero),
			state.get_hero_max_health(state.enemy_hero)
		)
		_check(not expected_reward.is_empty(), "deterministic battle loot seed resolves to an item")
		_check(str(state.last_battle_result.get("equipment_reward_id", "")) == expected_reward, "victory result reports its deterministic equipment reward")
		_check(state.get_hero_inventory_item_ids(hero_id).has(expected_reward), "battle victory adds the reward to the assigned commander inventory")

	state.free()
	if _failures > 0:
		printerr("Equipment smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All equipment smoke tests passed.")
		quit(0)
