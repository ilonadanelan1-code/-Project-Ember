extends SceneTree

const DetailRendererScript = preload("res://scripts/world_detail_batch_renderer.gd")

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
    var renderer := DetailRendererScript.new()
    root.add_child(renderer)
    await process_frame
    var texture := renderer.get_texture()
    _check(texture is Texture2D, "painted detail sprite atlas loads")
    if texture is Texture2D:
        _check(texture.get_width() == 3072 and texture.get_height() == 2048, "24 feathered biome details fit a 3072x2048 atlas")
    _check(renderer.get_batched_draw_count() == 0, "empty detail layer submits no draw batch")

    var cells: Array[Vector2i] = []
    var centers := PackedVector2Array()
    var kinds := PackedStringArray()
    var colors := PackedColorArray()
    var terrain_kinds := ["plain", "forest", "hills", "water", "farmland", "marsh"]
    for family in range(terrain_kinds.size()):
        for index in range(40):
            var cell := Vector2i(index - 20 + family * 3, family * 7)
            cells.append(cell)
            centers.append(Vector2(52.0 * float(cell.x), 45.0 * float(cell.y)))
            kinds.append(terrain_kinds[family])
            colors.append(Color.WHITE)
    var expected_ranges := [Vector2i(0, 4), Vector2i(4, 8), Vector2i(8, 12), Vector2i(12, 16), Vector2i(16, 20), Vector2i(20, 24)]
    var sample_cells := [Vector2i(-30, 3), Vector2i(-30, -8), Vector2i(-30, -13), Vector2i(-30, 3), Vector2i(-30, -8), Vector2i(-30, -8)]
    for index in range(terrain_kinds.size()):
        var picked_sprite := DetailRendererScript.choose_sprite(sample_cells[index], terrain_kinds[index], 842173)
        _check(picked_sprite >= expected_ranges[index].x and picked_sprite < expected_ranges[index].y, "%s details resolve into their dedicated atlas quadrant" % terrain_kinds[index])

    renderer.set_visible_cells(cells, centers, kinds, colors, 0.9, 842173)
    _check(renderer.get_source_cell_count() == 240, "detail layer receives all explored source cells")
    _check(renderer.get_detail_instance_count() > 0, "deterministic terrain details are populated")
    _check(renderer.get_detail_instance_count() < 240, "details are selective rather than stamped on every hex")
    _check(renderer.get_batched_draw_count() == 1, "all foreground details use one MultiMesh batch")

    renderer.set_visible_cells(cells, centers, kinds, colors, 0.1, 842173)
    _check(renderer.get_detail_instance_count() == 0, "foreground details are culled for continent zoom")
    _check(renderer.get_batched_draw_count() == 0, "culled details submit no draw call")

    if _failures > 0:
        printerr("World detail renderer tests failed: %d" % _failures)
        quit(1)
    else:
        print("All world detail renderer tests passed.")
        quit(0)
