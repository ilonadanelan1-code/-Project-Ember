extends SceneTree

const RendererScript = preload("res://scripts/hex_map_batch_renderer.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	var renderer := RendererScript.new()
	root.add_child(renderer)
	await process_frame

	_check(renderer.get_texture() is ImageTexture, "terrain atlas is generated once at runtime")
	_check(renderer.get_texture().get_width() == 64 * 9 and renderer.get_texture().get_height() == 72, "nine atlas columns contain four terrain motifs, two orientations and continent LOD")
	_check(renderer.get_terrain_variant_count() == 5, "four terrain motifs plus one continent-scale motif are available")
	_check(renderer.get_atlas_column_count() == 9, "terrain atlas exposes nine style columns")
	_check(renderer.get_batched_draw_count() == 0, "empty viewport submits no terrain draw batch")

	var centers := PackedVector2Array()
	var colors := PackedColorArray()
	var cells: Array[Vector2i] = []
	var styles := PackedColorArray()
	for index in range(1024):
		var column := index % 32
		var row := int(index / 32)
		var cell := Vector2i(column, row)
		centers.append(Vector2(float(column) * 52.0, float(row) * 45.0))
		colors.append(Color(0.35 + float(index % 3) * 0.1, 0.55, 0.35, 1.0))
		cells.append(cell)
		styles.append(Color(float(index % 4), float(posmod(index, 6)) / 6.0, 0.0, 1.0))

	renderer.set_tiles(centers, colors, Vector2(56.0, 64.0), 0.9, styles)
	_check(renderer.get_tile_instance_count() == 1024, "1024 visible hexes use 1024 instances")
	_check(renderer.get_batched_draw_count() == 1, "all visible hexes share one terrain draw batch")
	_check(renderer.get_instance_atlas_index(0) == 0, "grass instance selects its first atlas orientation")
	_check(renderer.get_instance_atlas_index(1) == 2, "forest instance selects its first atlas orientation")
	_check(renderer.get_instance_atlas_index(2) == 4, "highland instance selects its first atlas orientation")
	_check(renderer.get_instance_atlas_index(3) == 6, "water instance selects its first atlas orientation")
	_check(renderer.get_instance_atlas_index(5) in [0, 1], "cell coordinates deterministically select a grass motif orientation")

	var small_centers := PackedVector2Array([Vector2(100.0, 100.0), Vector2(160.0, 100.0)])
	var small_colors := PackedColorArray([Color.WHITE, Color(0.2, 0.4, 0.8, 1.0)])
	renderer.set_tiles(small_centers, small_colors, Vector2(56.0, 64.0), 0.5)
	_check(renderer.get_tile_instance_count() == 2, "renderer correctly resizes to a smaller visible region")
	_check(renderer.get_batched_draw_count() == 1, "smaller view remains one batch")

	renderer.set_map_tiles(cells, centers, colors, Vector2(56.0, 64.0), 0.9, styles)
	_check(renderer.get_lod_chunk_size() == 1, "close zoom keeps individual hex detail")
	_check(renderer.get_tile_instance_count() == 1024, "close zoom renders every supplied discovered hex")

	renderer.set_map_tiles(cells, centers, colors, Vector2(56.0, 64.0), 0.1, styles)
	_check(renderer.get_lod_chunk_size() == 6, "continent zoom activates six-hex LOD chunks")
	_check(renderer.get_tile_instance_count() <= 36, "1,024 discovered tiles collapse into at most 36 LOD chunks")
	_check(renderer.get_batched_draw_count() == 1, "LOD chunks remain a single terrain batch")
	_check(renderer.get_instance_atlas_index(0) == 8, "continent LOD selects simplified topographic atlas motif")

	renderer.set_tiles(PackedVector2Array(), PackedColorArray(), Vector2(56.0, 64.0), 0.5)
	_check(renderer.get_tile_instance_count() == 0, "renderer releases visible instances when no cells are visible")
	_check(renderer.get_batched_draw_count() == 0, "empty region submits no terrain draw batch")

	renderer.queue_free()
	await process_frame
	if _failures > 0:
		printerr("Map batch renderer tests failed: %d" % _failures)
		quit(1)
	else:
		print("All map batch renderer tests passed.")
		quit(0)
