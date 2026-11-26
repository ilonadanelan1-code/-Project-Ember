extends RefCounted
class_name GameIconCatalog

const VisualAssetCatalogScript = preload("res://scripts/visual_asset_catalog.gd")

## One place for all supplied strategy-game icon packs.
## UI uses the Gridwright 2x set; map settlements use the high-resolution
## Pixel Fantasy set while compact button icons use its 32x32 sprites.

const _PIXEL_UI_ROOT := "res://assets/icons/pixel_fantasy/PNG/32x32/"

const _RESOURCE_GOLD: Texture2D = preload("res://assets/icons/gridwright/PNG/2x/icons_resource_16/gold.png")
const _RESOURCE_FOOD: Texture2D = preload("res://assets/icons/gridwright/PNG/2x/icons_resource_16/food.png")
const _COMMAND_ATTACK: Texture2D = preload("res://assets/icons/gridwright/PNG/2x/icons_command_16/attack.png")
const _COMMAND_BUILD: Texture2D = preload("res://assets/icons/gridwright/PNG/2x/icons_command_16/build.png")
const _UNIT_INFANTRY: Texture2D = preload("res://assets/icons/gridwright/PNG/2x/icons_unit_16/infantry.png")
const _UNIT_ARCHER: Texture2D = preload("res://assets/icons/gridwright/PNG/2x/icons_unit_16/archer.png")
const _UNIT_CAVALRY: Texture2D = preload("res://assets/icons/gridwright/PNG/2x/icons_unit_16/cavalry.png")
const _UNIT_WORKER: Texture2D = preload("res://assets/icons/gridwright/PNG/2x/icons_unit_16/worker.png")

const _MAP_CASTLE_BLUE: Texture2D = preload("res://assets/icons/pixel_fantasy/PNG/128x128_x4/settlements/castle_blue.png")
const _MAP_CASTLE_RED: Texture2D = preload("res://assets/icons/pixel_fantasy/PNG/128x128_x4/settlements/castle_red.png")
const _MAP_TOWN: Texture2D = preload("res://assets/icons/pixel_fantasy/PNG/128x128_x4/settlements/town.png")
const _MAP_VILLAGE: Texture2D = preload("res://assets/icons/pixel_fantasy/PNG/128x128_x4/settlements/village.png")
const _MAP_CROSSED_SWORDS: Texture2D = preload("res://assets/icons/pixel_fantasy/PNG/128x128_x4/markers/crossed_swords.png")


static func resource_icon(icon_id: String) -> Texture2D:
	match icon_id:
		"gold":
			return _RESOURCE_GOLD
		"food":
			return _RESOURCE_FOOD
		"production":
			return _COMMAND_BUILD
	return null


static func command_icon(icon_id: String) -> Texture2D:
	match icon_id:
		"attack":
			return _COMMAND_ATTACK
		"build":
			return _COMMAND_BUILD
	return null


static func unit_icon(role_id: String) -> Texture2D:
	var medieval_icon_id := ""
	match role_id:
		"melee": medieval_icon_id = "knight"
		"ranged": medieval_icon_id = "archer"
		"spear": medieval_icon_id = "guard"
		"cavalry": medieval_icon_id = "horse"
		"worker", "settler": medieval_icon_id = "peasant"
	if not medieval_icon_id.is_empty():
		var medieval_icon := VisualAssetCatalogScript.get_frame("castle", medieval_icon_id)
		if is_instance_valid(medieval_icon):
			return medieval_icon
	match role_id:
		"melee":
			return _UNIT_INFANTRY
		"ranged":
			return _UNIT_ARCHER
		"spear":
			return _UNIT_INFANTRY
		"cavalry":
			return _UNIT_CAVALRY
		"worker", "settler":
			return _UNIT_WORKER
	return null


static func settlement_icon(settlement_id: String, high_resolution: bool = false) -> Texture2D:
	if high_resolution:
		match settlement_id:
			"castle_blue":
				return _MAP_CASTLE_BLUE
			"castle_red":
				return _MAP_CASTLE_RED
			"town":
				return _MAP_TOWN
			"village":
				return _MAP_VILLAGE
	else:
		var path := _PIXEL_UI_ROOT + "settlements/" + settlement_id + ".png"
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


static func medieval_prop_icon(prop_id: String) -> Texture2D:
	return VisualAssetCatalogScript.get_frame("castle", prop_id)


static func faction_banner_icon(faction_index: int) -> Texture2D:
	return VisualAssetCatalogScript.get_faction_banner(faction_index)


static func map_marker_icon(marker_id: String) -> Texture2D:
	if marker_id == "crossed_swords":
		return _MAP_CROSSED_SWORDS
	return null


static func building_icon(building_id: String) -> Texture2D:
	var icon_id := ""
	match building_id:
		"farm":
			icon_id = "farm"
		"market":
			icon_id = "market"
		"workshop":
			icon_id = "windmill"
		"barracks":
			icon_id = "fort"
		"archery_range":
			icon_id = "tower"
		"stable":
			icon_id = "camp"
	if icon_id.is_empty():
		return null
	return settlement_icon(icon_id)
