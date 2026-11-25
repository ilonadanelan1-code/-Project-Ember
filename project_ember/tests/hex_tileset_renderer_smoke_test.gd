extends Node

const RendererScript = preload("res://scripts/hex_terrain_tilemap_renderer.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	CampaignState.new_campaign(false)
	var renderer := RendererScript.new()
	add_child(renderer)
	await process_frame

	var tile_set := renderer.get_tile_set() as TileSet
	_check(tile_set != null, "combined Hex Terrain TileSet loads")
	_check(renderer.get_atlas_source_count() == 6, "six biome atlas sources are available")
	_check(renderer.get_atlas_tile_count() == 448, "all 448 authored hex tiles are present")
	if tile_set != null:
		_check(tile_set.tile_size == Vector2i(64, 64), "renderer uses the authored 64px tile size")
		_check(int(tile_set.tile_shape) == 3, "TileSet uses pointy-top hexagons")
		_check(int(tile_set.tile_offset_axis) == 0, "TileSet uses horizontal offset rows")
		_check(tile_set.get_terrain_sets_count() == 1, "one shared TerrainConnect set spans all six atlases")

	var visible_cells: Array[Vector2i] = []
	for encoded_value in CampaignState.explored_cells.keys():
		var cell := WorldGeneratorScript.decode_cell(int(encoded_value))
		if cell != Vector2i(9999, 9999):
			visible_cells.append(cell)
	renderer.set_map_tiles(visible_cells, 0.9, Vector2.ZERO, Vector2(1280.0, 720.0))
	await process_frame
	_check(renderer.get_rendered_cell_count() == visible_cells.size(), "every explored world cell is rendered once")
	_check(renderer.get_feature_cell_count() > 0, "deterministic biome features are placed on safe interior cells")
	_check(renderer.get_feature_cell_count() < renderer.get_rendered_cell_count(), "feature layer does not replace the ground layer")
	_check(renderer.get_last_rebuild_ms() >= 0.0, "TileMap rebuild time is recorded")
	_check(renderer.get_tile_instance_count() > 0, "performance overlay receives a non-zero map count")

	renderer.queue_free()
	await process_frame
	if _failures > 0:
		printerr("Hex TileSet renderer tests failed: %d" % _failures)
		get_tree().quit(1)
	else:
		print("All Hex TileSet renderer tests passed.")
		get_tree().quit(0)
