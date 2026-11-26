extends SceneTree

const VisualAssetCatalogScript = preload("res://scripts/visual_asset_catalog.gd")
const WorldLocationCatalogScript = preload("res://scripts/world_location_catalog.gd")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	_check(VisualAssetCatalogScript.has_assets(), "compressed licensed visual atlas payload is available")

	var prop_ids := [
		"castle_tower", "castle_gate", "cottage", "market_stall", "windmill",
		"stone_well", "signpost", "campfire", "gravestone", "statue", "torch",
		"banner_blue", "banner_red", "knight", "king", "archer", "guard",
		"wizard", "merchant", "blacksmith", "horse", "dragon", "oak_tree",
		"pine_tree", "rock", "wood_fence", "barrel", "crate",
	]
	for prop_id in prop_ids:
		_check(
			is_instance_valid(VisualAssetCatalogScript.get_frame("castle", prop_id)),
			"Pixel Castle sprite resolves: " + prop_id
		)

	for banner_index in range(15):
		_check(
			is_instance_valid(VisualAssetCatalogScript.get_faction_banner(banner_index)),
			"faction heraldry banner %d resolves" % banner_index
		)

	var monster_ids := [
		"bat", "eyeball", "ghost", "goblin", "golem", "imp", "mushroom",
		"pumpkin", "skeleton", "slime_blue", "slime_green", "slime_red",
		"snake", "spider", "wyrm", "boar", "dark_knight", "demon",
		"fire_elemental", "ice_elemental", "lich", "mimic", "mummy", "orc",
		"scorpion", "storm_elemental", "vampire", "water_elemental", "wolf",
		"zombie",
	]
	for monster_id in monster_ids:
		var frames := VisualAssetCatalogScript.get_monster_frames(monster_id)
		var valid_frames := is_instance_valid(frames)
		_check(valid_frames, "monster SpriteFrames load: " + monster_id)
		if valid_frames:
			_check(
				frames.has_animation("idle")
				and frames.has_animation("attack")
				and frames.get_frame_count("idle") == 4
				and frames.get_frame_count("attack") == 4,
				"monster idle/attack animation frames are complete: " + monster_id
			)

	var red_knight := VisualAssetCatalogScript.get_red_knight_frames()
	_check(is_instance_valid(red_knight), "medieval red knight SpriteFrames load")
	if is_instance_valid(red_knight):
		_check(
			red_knight.has_animation("idle")
			and red_knight.has_animation("run")
			and red_knight.has_animation("attack")
			and red_knight.get_frame_count("idle") == 8
			and red_knight.get_frame_count("run") == 8
			and red_knight.get_frame_count("attack") == 10,
			"red knight idle, run and attack animations use the expected frame counts"
		)

	var location_types := [
		"ancient_ruins", "monster_lair", "abandoned_mine",
		"forgotten_shrine", "mercenary_camp", "leyline_nexus",
	]
	for location_type in location_types:
		var icon_id := WorldLocationCatalogScript.get_map_icon(location_type)
		_check(
			is_instance_valid(VisualAssetCatalogScript.get_frame("castle", icon_id)),
			"neutral location marker resolves: " + location_type
		)
		var guard_ids := WorldLocationCatalogScript.get_guard_visual_ids(location_type)
		_check(not guard_ids.is_empty(), "neutral location has a themed guard roster: " + location_type)
		for guard_id in guard_ids:
			if guard_id == "red_knight":
				_check(
					is_instance_valid(VisualAssetCatalogScript.get_red_knight_frames()),
					"red knight guard visual resolves"
				)
			else:
				_check(
					is_instance_valid(VisualAssetCatalogScript.get_monster_frames(guard_id)),
					"site guard visual resolves: " + guard_id
				)
		var guardian_id := WorldLocationCatalogScript.get_guardian_visual_id(location_type)
		if guardian_id == "red_knight":
			_check(is_instance_valid(red_knight), "mercenary camp guardian visual resolves")
		else:
			_check(
				is_instance_valid(VisualAssetCatalogScript.get_monster_frames(guardian_id)),
				"neutral site guardian visual resolves: " + location_type
			)

	print("\nVisual asset checks: %d passed / %d failed / %d total" % [_checks - _failures, _failures, _checks])
	print("All %d passed." % [_checks - _failures] if _failures == 0 else "Visual asset smoke test failed.")
	quit(0 if _failures == 0 else 1)
