extends SceneTree
const Campaign = preload("res://scripts/campaign_state.gd")
const World = preload("res://scripts/world_generator.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var state = Campaign.new()
	root.add_child(state)
	state.new_campaign(false)
	state.city_gold = 500
	state.city_production_bank = 200
	state._save_active_city()
	state.settler_active = true
	state.settler_origin_city_id = state.active_city_id
	var found = Vector2i(9999,9999)
	for distance in range(2,12):
		for q in range(-distance,distance+1):
			for r in range(-distance,distance+1):
				var candidate = state.city_cell + Vector2i(q,r)
				if World.hex_distance(state.city_cell,candidate) == distance and state.can_found_outpost(candidate):
					found = candidate
					break
			if found != Vector2i(9999,9999): break
		if found != Vector2i(9999,9999): break
	print("path=", ProjectSettings.globalize_path("user://project_ember_campaign.json"))
	print("found=",found," can=",state.can_found_outpost(found))
	print("battle=",state.battle_in_progress," prevent=",state._prevent_save_overwrite)
	print("found_result=",state.found_outpost(found))
	print("save_again=",state.save_campaign())
	print("battle=",state.battle_in_progress," prevent=",state._prevent_save_overwrite)
	print("file_exists=",FileAccess.file_exists("user://project_ember_campaign.json")," temp=",FileAccess.file_exists("user://project_ember_campaign.json.tmp")," bak=",FileAccess.file_exists("user://project_ember_campaign.json.bak"))
	print("path_exists=",FileAccess.open("user://project_ember_campaign.json",FileAccess.READ))
	quit(0)
