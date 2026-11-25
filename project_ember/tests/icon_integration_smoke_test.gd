extends SceneTree

const IconCatalogScript = preload("res://scripts/game_icon_catalog.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _is_valid_texture(texture: Texture2D) -> bool:
	return texture != null and texture.get_width() > 0 and texture.get_height() > 0


func _run() -> void:
	_check(_is_valid_texture(IconCatalogScript.resource_icon("gold")), "Gridwright gold icon resolves")
	_check(_is_valid_texture(IconCatalogScript.resource_icon("food")), "Gridwright food icon resolves")
	_check(_is_valid_texture(IconCatalogScript.resource_icon("production")), "production uses the supplied build icon")
	_check(_is_valid_texture(IconCatalogScript.command_icon("attack")), "Gridwright attack command icon resolves")

	for role_id in ["melee", "ranged", "spear", "cavalry", "worker", "settler"]:
		_check(_is_valid_texture(IconCatalogScript.unit_icon(role_id)), "unit icon resolves for %s" % role_id)

	for building_id in ["farm", "market", "workshop", "barracks", "archery_range", "stable"]:
		_check(_is_valid_texture(IconCatalogScript.building_icon(building_id)), "building icon resolves for %s" % building_id)

	for settlement_id in ["castle_blue", "castle_red", "town", "village"]:
		_check(_is_valid_texture(IconCatalogScript.settlement_icon(settlement_id)), "compact map icon resolves for %s" % settlement_id)
		_check(_is_valid_texture(IconCatalogScript.settlement_icon(settlement_id, true)), "high-resolution map icon resolves for %s" % settlement_id)

	_check(_is_valid_texture(IconCatalogScript.map_marker_icon("crossed_swords")), "Pixel Fantasy army marker icon resolves")
	_check(IconCatalogScript.resource_icon("wood") == null, "unimplemented resources are not shown as real campaign stocks")
	_check(IconCatalogScript.unit_icon("unknown") == null, "unknown unit roles safely return no icon")

	if _failures > 0:
		printerr("Icon integration tests failed: %d" % _failures)
		quit(1)
	else:
		print("All icon integration smoke tests passed.")
		quit(0)
