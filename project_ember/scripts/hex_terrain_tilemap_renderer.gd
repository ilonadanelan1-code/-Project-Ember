extends Node2D
class_name HexTerrainTileMapRenderer

## Native TileMap renderer for the 448-tile Hex Terrain Bundle.
## The TileSet uses pointy-top, horizontal-offset hexes. StrategyMap continues
## to own fog of war, city/army markers, roads, borders and touch interaction.

const TILE_SET_PATH := "res://assets/hex_terrain/tileset_64.tres"
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")

const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const TERRAIN_IDS: Array[int] = [0, 7, 8, 10, 11, 12]
const FEATURE_RULES := {
	"plain": {
		"chance": 72,
		"tiles": ["grass_flowers_01", "grass_flowers_02", "bushes_01", "bushes_berries_01", "rocks_01"],
	},
	"forest": {
		"chance": 390,
		"tiles": ["forest_oak_01", "forest_oak_02", "forest_oak_sparse_01", "forest_pine_01", "forest_pine_02", "forest_mixed_01", "forest_autumn_01"],
	},
	"hills": {
		"chance": 170,
		"tiles": ["mountain_small_01", "boulder_field_01", "alpine_pines_01", "mountain_medium_01"],
	},
	"water": {
		"chance": 32,
		"tiles": ["kelp_01", "reef_01", "sea_stacks_01"],
	},
	"marsh": {
		"chance": 190,
		"tiles": ["reeds_01", "reeds_water_01", "cattails_01", "lily_pads_01", "mangrove_01", "willow_01"],
	},
}

var _tile_set: TileSet
var _ground_layer: TileMapLayer
var _feature_layer: TileMapLayer
var _feature_lookup: Dictionary = {}
var _last_world_seed: int = -1
var _last_generation_version: int = -1
var _last_explored_count: int = -1
var _last_rendered_count: int = 0
var _last_feature_count: int = 0
var _last_source_cell_count: int = 0
var _last_zoom: float = 1.0
var _last_rebuild_ms: float = 0.0
var _rebuild_queued: bool = false


func _ready() -> void:
	z_index = -2
	add_to_group("map_batch_renderer")
	_tile_set = load(TILE_SET_PATH) as TileSet
	if _tile_set == null:
		push_error("Hex Terrain Bundle TileSet could not be loaded.")
		return

	_ground_layer = TileMapLayer.new()
	_ground_layer.name = "HexTerrainGround"
	_ground_layer.tile_set = _tile_set
	_ground_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground_layer.rendering_quadrant_size = 16
	_ground_layer.z_index = 0
	add_child(_ground_layer)

	_feature_layer = TileMapLayer.new()
	_feature_layer.name = "HexTerrainFeatures"
	_feature_layer.tile_set = _tile_set
	_feature_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_feature_layer.rendering_quadrant_size = 16
	_feature_layer.z_index = 1
	add_child(_feature_layer)

	_build_feature_lookup()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#111710"), true)


func set_map_tiles(
		visible_cells: Array[Vector2i],
		zoom: float,
		camera_center_world: Vector2,
		viewport_size: Vector2
) -> void:
	if not is_instance_valid(_ground_layer) or not is_instance_valid(_feature_layer):
		return
	_last_source_cell_count = visible_cells.size()
	_last_zoom = zoom

	# Ember axial centers are (51.9615*q + 25.9808*r, 45*r). The bundle's
	# 64px pointy-top horizontal-offset grid advances (64*q + 32*r, 48*r).
	var tile_scale := Vector2(51.961524 / 64.0, 45.0 / 48.0) * maxf(zoom, 0.001)
	var screen_origin := viewport_size * 0.5 - camera_center_world * zoom
	var ground_zero := _ground_layer.map_to_local(Vector2i.ZERO)
	var feature_zero := _feature_layer.map_to_local(Vector2i.ZERO)
	_ground_layer.scale = tile_scale
	_feature_layer.scale = tile_scale
	_ground_layer.position = screen_origin - ground_zero * tile_scale
	_feature_layer.position = screen_origin - feature_zero * tile_scale
	_feature_layer.visible = zoom >= 0.32

	var explored_count := CampaignState.explored_cells.size()
	if (
		CampaignState.world_seed != _last_world_seed
		or CampaignState.world_generation_version != _last_generation_version
		or explored_count != _last_explored_count
	) and not _rebuild_queued:
		_rebuild_queued = true
		call_deferred("_rebuild_explored_world")


func invalidate_world() -> void:
	# A fresh campaign can have the same seed and explored-cell count as the
	# previous run. Explicit invalidation prevents stale TileMap cells surviving.
	_last_world_seed = -1
	_last_generation_version = -1
	_last_explored_count = -1


func _rebuild_explored_world() -> void:
	_rebuild_queued = false
	if not is_instance_valid(_ground_layer) or not is_instance_valid(_feature_layer):
		return
	var started_usec := Time.get_ticks_usec()
	_ground_layer.clear()
	_feature_layer.clear()
	_last_rendered_count = 0
	_last_feature_count = 0

	var cells: Array[Vector2i] = []
	var terrain_by_cell: Dictionary = {}
	for encoded_value in CampaignState.explored_cells.keys():
		var cell := WorldGeneratorScript.decode_cell(int(encoded_value))
		if cell == Vector2i(9999, 9999):
			continue
		cells.append(cell)
		terrain_by_cell[cell] = CampaignState.get_world_terrain(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x == b.x:
			return a.y < b.y
		return a.x < b.x
	)

	var ground_by_cell: Dictionary = {}
	var groups: Dictionary = {}
	for terrain_id in TERRAIN_IDS:
		var terrain_cells: Array[Vector2i] = []
		groups[terrain_id] = terrain_cells

	for cell in cells:
		var terrain_kind := str(terrain_by_cell.get(cell, "plain"))
		var ground_id := _terrain_id_for_cell(cell, terrain_kind, terrain_by_cell)
		ground_by_cell[cell] = ground_id
		var group: Array[Vector2i] = groups[ground_id]
		group.append(_axial_to_offset(cell))

	# TerrainConnect chooses the authored edge/corner transition tiles from the
	# shared 13-terrain set. It paints only explored cells; fog remains external.
	for terrain_id in TERRAIN_IDS:
		var terrain_cells: Array[Vector2i] = groups[terrain_id]
		if not terrain_cells.is_empty():
			_ground_layer.set_cells_terrain_connect(terrain_cells, 0, terrain_id, false)

	# Detail art is only placed well inside one uniform ground type, so a tree,
	# rock or reed cannot hide a coastline or a grass/rock transition.
	for cell in cells:
		if not _is_uniform_ground_cell(cell, ground_by_cell):
			continue
		_try_place_feature(cell, str(terrain_by_cell.get(cell, "plain")))

	_ground_layer.update_internals()
	_feature_layer.update_internals()
	_last_rendered_count = _ground_layer.get_used_cells().size()
	_last_feature_count = _feature_layer.get_used_cells().size()
	_last_world_seed = CampaignState.world_seed
	_last_generation_version = CampaignState.world_generation_version
	_last_explored_count = CampaignState.explored_cells.size()
	_last_rebuild_ms = float(Time.get_ticks_usec() - started_usec) / 1000.0


func _terrain_id_for_cell(cell: Vector2i, terrain_kind: String, terrain_by_cell: Dictionary) -> int:
	match terrain_kind:
		"water":
			return 8 if _has_explored_land_neighbor(cell, terrain_by_cell) else 7
		"farmland":
			# Dirt blends into grass. Where it would touch an unsupported ground
			# (rock, marsh or water), use grass for this edge cell as a connector.
			return 11 if _has_neighbor_kind(cell, terrain_by_cell, ["hills", "marsh", "water"]) else 0
		"hills":
			return 11 if _has_neighbor_kind(cell, terrain_by_cell, ["water", "marsh", "farmland"]) else 12
		"marsh":
			return 11 if _has_neighbor_kind(cell, terrain_by_cell, ["hills", "farmland"]) else 10
		_:
			return 11


func _has_neighbor_kind(cell: Vector2i, terrain_by_cell: Dictionary, kinds: Array) -> bool:
	for direction in NEIGHBORS:
		var neighbor: Vector2i = cell + direction
		if terrain_by_cell.has(neighbor) and kinds.has(str(terrain_by_cell[neighbor])):
			return true
	return false


func _has_explored_land_neighbor(cell: Vector2i, terrain_by_cell: Dictionary) -> bool:
	for direction in NEIGHBORS:
		var neighbor: Vector2i = cell + direction
		if not terrain_by_cell.has(neighbor):
			continue
		if str(terrain_by_cell[neighbor]) != "water":
			return true
	return false


func _is_uniform_ground_cell(cell: Vector2i, ground_by_cell: Dictionary) -> bool:
	if not ground_by_cell.has(cell):
		return false
	var center_ground := int(ground_by_cell[cell])
	for direction in NEIGHBORS:
		var neighbor: Vector2i = cell + direction
		if not ground_by_cell.has(neighbor) or int(ground_by_cell[neighbor]) != center_ground:
			return false
	return true


func _axial_to_offset(cell: Vector2i) -> Vector2i:
	# Odd rows shift right by half a tile. floori also handles negative rows.
	return Vector2i(cell.x + floori(float(cell.y) / 2.0), cell.y)


func _build_feature_lookup() -> void:
	_feature_lookup.clear()
	for source_index in range(_tile_set.get_source_count()):
		var source_id := _tile_set.get_source_id(source_index)
		var atlas := _tile_set.get_source(source_id) as TileSetAtlasSource
		if atlas == null:
			continue
		# TileSetAtlasSource inherits TileSetSource; enumerate its indexed tile IDs.
		for tile_index in range(atlas.get_tiles_count()):
			var atlas_coords: Vector2i = atlas.get_tile_id(tile_index)
			var tile_data := atlas.get_tile_data(atlas_coords, 0)
			if tile_data == null:
				continue
			var full_name := str(tile_data.get_custom_data("tile_name"))
			if full_name.is_empty():
				continue
			var name_parts := full_name.split("/")
			var short_name := str(name_parts[name_parts.size() - 1])
			_feature_lookup[short_name] = {
				"source_id": source_id,
				"atlas_coords": atlas_coords,
			}


func _try_place_feature(cell: Vector2i, terrain_kind: String) -> void:
	if not FEATURE_RULES.has(terrain_kind):
		return
	var rule: Dictionary = FEATURE_RULES[terrain_kind]
	var mixed := (cell.x * 73856093) ^ (cell.y * 19349663) ^ (CampaignState.world_seed * 83492791)
	if posmod(mixed, 1000) >= int(rule["chance"]):
		return
	var choices: Array = rule["tiles"]
	var tile_name := str(choices[posmod(floori(float(mixed) / 1009.0), choices.size())])
	if not _feature_lookup.has(tile_name):
		return
	var info: Dictionary = _feature_lookup[tile_name]
	_feature_layer.set_cell(_axial_to_offset(cell), int(info["source_id"]), info["atlas_coords"])


func get_tile_set() -> TileSet:
	return _tile_set


func get_atlas_source_count() -> int:
	return _tile_set.get_source_count() if is_instance_valid(_tile_set) else 0


func get_atlas_tile_count() -> int:
	if not is_instance_valid(_tile_set):
		return 0
	var total := 0
	for source_index in range(_tile_set.get_source_count()):
		var source_id := _tile_set.get_source_id(source_index)
		var atlas := _tile_set.get_source(source_id) as TileSetAtlasSource
		if atlas != null:
			total += atlas.get_tiles_count()
	return total


func get_rendered_cell_count() -> int:
	return _last_rendered_count


func get_feature_cell_count() -> int:
	return _last_feature_count


func get_last_rebuild_ms() -> float:
	return _last_rebuild_ms


# Compatibility methods keep the existing performance report useful.
func get_tile_instance_count() -> int:
	return _last_rendered_count


func get_source_cell_count() -> int:
	return _last_source_cell_count


func get_lod_chunk_size() -> int:
	return 1


func get_last_zoom() -> float:
	return _last_zoom


func get_batched_draw_count() -> int:
	return 2 if _last_rendered_count > 0 else 0
