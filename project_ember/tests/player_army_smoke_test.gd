extends SceneTree

const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")

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

	_check(state.player_armies.size() == 1, "new campaign creates one persistent primary army")
	_check(str(state.player_armies[0].get("id", "")) == "army_primary", "primary army uses a stable ID")
	_check(str(state.player_armies[0].get("hero_id", "")) == "hero_ruler", "ruler is assigned to the primary army")
	_check(state.get_player_army_total_units() == state.player_units.size(), "army unit total matches the legacy compatibility view")

	state.city_gold = 1000
	_check(state.recruit_lord("lord_ragnar"), "a recruitable lord can join the roster")
	var primary_id: String = state.selected_player_army_id
	var original_units: int = state.player_units.size()
	var original_cell: Vector2i = state.player_cell
	_check(state.can_create_player_army(), "army can be split when a free hero and adjacent tile exist")
	_check(state.create_player_army(), "splitting creates a second independent army")
	_check(state.player_armies.size() == 2, "second army is stored in the campaign roster")
	_check(state.selected_player_army_id != primary_id, "newly created army becomes selected")
	_check(state.get_player_army_total_units() == original_units, "splitting preserves the total number of troops")
	_check(state.player_units.size() > 0 and state.player_units.size() < original_units, "source army retains a portion of its troops")
	_check(state.get_player_army_at(original_cell).get("id", "") == primary_id, "primary army remains at its original strategic position")
	var second_army: Dictionary = state.player_armies[1]
	var second_hero_id := str(second_army.get("hero_id", ""))
	_check(not second_hero_id.is_empty() and second_hero_id != "hero_ruler", "new army receives a distinct available hero")
	_check(not state.assign_hero_to_army(primary_id, second_hero_id), "one hero cannot command two armies")
	var second_id: String = state.selected_player_army_id
	var barracks_state: bool = state.city_has_building("barracks")
	if not barracks_state:
		state.city_buildings.append("barracks")
	state.city_gold = 1000
	var second_units_before_recruit: int = state.player_units.size()
	_check(state.queue_recruit(state.ROLE_MELEE), "recruitment order can be issued for the selected army")
	var recruit_queue: Dictionary = state.city_build_queue.back()
	_check(str(recruit_queue.get("army_id", "")) == second_id, "recruitment order stores the selected army ID")
	state.city_production_bank = 100
	_check(state.select_player_army(primary_id), "primary army can be selected while another army has a recruit order")
	state._process_city_queue()
	_check(state.player_units.size() == original_units - (original_units / 2), "recruit completion does not add troops to the wrong selected army")
	_check(state.select_player_army(second_id), "army with pending recruitment can be selected again")
	_check(state.player_units.size() == second_units_before_recruit + 1, "recruit completion adds the unit to its originally assigned army")
	if not barracks_state:
		state.city_buildings.erase("barracks")
	var second_cell: Vector2i = state.player_cell
	_check(state.select_player_army(primary_id), "primary army can be selected independently")
	_check(state.player_cell == original_cell, "selecting the primary army restores its own map position")
	_check(state.select_player_army(second_id), "second army can be selected independently")
	_check(state.player_cell == second_cell, "selecting the second army restores its own map position")

	var moved := false
	for offset in WorldGeneratorScript.neighbors():
		var candidate: Vector2i = second_cell + offset
		if state.move_selected_player_army(candidate):
			moved = true
			break
	_check(moved, "selected army moves independently to a free neighboring hex")
	_check(state.get_player_army_at(original_cell).get("id", "") == primary_id, "moving the second army leaves the primary army position unchanged")
	var second_index: int = state._get_player_army_index(second_id)
	_check(second_index >= 0 and int(state.player_armies[second_index].get("moves_left", -1)) == 0, "movement allowance is stored per army")
	var moved_cell: Vector2i = state.player_cell

	var target_kingdom_id := -1
	for kingdom_index in range(state.kingdoms.size()):
		var enemy_army_value: Variant = state.kingdoms[kingdom_index].get("army", [])
		if enemy_army_value is Array and not enemy_army_value.is_empty():
			target_kingdom_id = kingdom_index
			break
	_check(target_kingdom_id >= 0, "campaign provides a target for battle handoff testing")
	if target_kingdom_id >= 0:
		_check(state.begin_battle("", target_kingdom_id), "selected player army can enter a tactical battle")
		if state.battle_in_progress:
			_check(state.battle_origin_cell == moved_cell, "battle handoff uses the selected army's map position")
			_check(state.active_hero_id == second_hero_id, "battle handoff uses the selected army's assigned hero")
			var player_survivors: Array[Dictionary] = state._copy_unit_records(state.player_units)
			var enemy_survivors: Array[Dictionary] = state._copy_unit_records(state.enemy_units)
			state.complete_battle(
				player_survivors,
				enemy_survivors,
				false,
				{"player_kills": 0, "player_damage": 0.0}
			)
			_check(not state.battle_in_progress, "battle completion returns control to the campaign")
			_check(state.player_cell == moved_cell, "defeated army returns to its own battle origin")
			var battle_army_index: int = state._get_player_army_index(second_id)
			if battle_army_index >= 0:
				var battle_army: Dictionary = state.player_armies[battle_army_index]
				var battle_army_cell := WorldGeneratorScript.array_to_cell(battle_army.get("cell", []))
				_check(battle_army_cell == moved_cell, "battle result is written back to the selected army record")

	var legacy_fallback := {
		"id": "army_primary",
		"name": "Первая армия",
		"cell": [original_cell.x, original_cell.y],
		"units": state._make_starting_army(),
		"hero_id": "hero_ruler",
		"upgrades": {"melee": 1},
		"moves_left": 0,
	}
	var migrated: Array[Dictionary] = state._read_player_armies([], legacy_fallback)
	_check(migrated.size() == 1, "legacy single-army saves migrate to one army record")
	_check(str(migrated[0].get("id", "")) == "army_primary", "legacy migration preserves the primary army identity")
	var migrated_upgrades: Dictionary = migrated[0].get("upgrades", {})
	_check(int(migrated_upgrades.get("melee", 0)) == 1, "legacy migration preserves army upgrades")

	_check(state.save_campaign(), "multi-army campaign saves successfully")
	var saved_army_count: int = state.player_armies.size()
	state.player_armies.clear()
	_check(state.load_campaign(), "multi-army campaign loads successfully")
	_check(state.player_armies.size() == saved_army_count, "save/load restores the independent army roster")
	_check(state.selected_player_army_id == second_id, "save/load restores the selected army")
	_check(state.player_cell == moved_cell, "save/load restores the selected army's strategic position")

	state.free()
	if _failures > 0:
		printerr("Player army smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All player army smoke tests passed.")
		quit(0)
