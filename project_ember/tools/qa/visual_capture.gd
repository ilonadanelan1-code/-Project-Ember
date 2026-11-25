extends SceneTree

## Runs the real strategic map scene and records repeatable screenshots at four zoom levels.
## Run with a display (Xvfb + Mesa in CI), not --headless, because the dummy renderer has no image.

const STRATEGY_SCENE := "res://scenes/strategy_map.tscn"
const ZOOM_LEVELS: Array[float] = [0.075, 0.76, 0.90, 1.25]

var _failures: int = 0
var _map: Node


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var output_dir := "artifacts/visual" if args.is_empty() else str(args[0])
    if output_dir.begins_with("user://"):
        output_dir = ProjectSettings.globalize_path(output_dir)
    var dir_error := DirAccess.make_dir_recursive_absolute(output_dir)
    if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
        push_error("Could not create visual QA output directory: %s" % output_dir)
        quit(1)
        return

    # Deterministic, isolated campaign: never read or overwrite a developer's save.
    CampaignState.new_campaign(false)
    GameSettings.show_fps_overlay = false
    var packed_scene := load(STRATEGY_SCENE) as PackedScene
    if packed_scene == null:
        push_error("Cannot load strategic map scene: " + STRATEGY_SCENE)
        quit(1)
        return

    _map = packed_scene.instantiate()
    root.add_child(_map)
    for _frame in range(8):
        await process_frame

    var center: Vector2 = _map.call("_hex_world_position", CampaignState.player_cell)
    var zoom_reports: Array[Dictionary] = []
    for zoom in ZOOM_LEVELS:
        _map.set("_camera_center_world", center)
        _map.set("_map_zoom", zoom)
        _map.queue_redraw()
        for _frame in range(10):
            await process_frame
        await RenderingServer.frame_post_draw

        var image := _map.get_viewport().get_texture().get_image()
        if image == null or image.is_empty():
            _failures += 1
            push_error("Screenshot is empty at zoom %.3f" % zoom)
            continue

        var tag := ("%.3f" % zoom).replace(".", "_")
        var image_name := "strategy_zoom_%s.png" % tag
        var image_path := output_dir.path_join(image_name)
        var save_error := image.save_png(image_path)
        if save_error != OK:
            _failures += 1
            push_error("Failed to write screenshot: " + image_path)
            continue

        var visible_cells: Array = _map.call("_get_visible_map_cells")
        var terrain_renderer: Object = _map.get("_terrain_renderer")
        var detail_renderer: Object = _map.get("_world_detail_renderer")
        var unique_samples := _count_sampled_colors(image)
        if image.get_width() < 640 or image.get_height() < 360 or unique_samples < 24:
            _failures += 1
            push_error("Visual capture looks blank or incomplete at zoom %.3f" % zoom)

        var terrain_instances := int(terrain_renderer.call("get_tile_instance_count")) if is_instance_valid(terrain_renderer) else 0
        var detail_instances := int(detail_renderer.call("get_detail_instance_count")) if is_instance_valid(detail_renderer) else 0
        var snapshot := {
            "zoom": zoom,
            "screenshot": image_name,
            "width": image.get_width(),
            "height": image.get_height(),
            "sampled_unique_colors": unique_samples,
            "visible_cells": visible_cells.size(),
            "terrain_instances": terrain_instances,
            "detail_instances": detail_instances,
            "terrain_batch_count": int(terrain_renderer.call("get_batched_draw_count")) if is_instance_valid(terrain_renderer) else 0,
            "detail_batch_count": int(detail_renderer.call("get_batched_draw_count")) if is_instance_valid(detail_renderer) else 0,
            "draw_calls": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
            "render_objects": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)),
            "primitives": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)),
            "video_memory_bytes": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)),
            "cpu_process_ms": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0,
        }
        zoom_reports.append(snapshot)
        print("VISUAL_QA " + JSON.stringify(snapshot))

    var version_text := "Project Ember"
    var version_file := FileAccess.open("res://VERSION.txt", FileAccess.READ)
    if version_file != null:
        version_text = version_file.get_line().strip_edges()
        version_file.close()
    var manifest := {
        "build": version_text,
        "godot_version": Engine.get_version_info().get("string", "unknown"),
        "renderer": "GL Compatibility",
        "capture_backend": "Xvfb + Mesa software OpenGL",
        "campaign_seed": CampaignState.world_seed,
        "world_generation_version": CampaignState.world_generation_version,
        "zoom_reports": zoom_reports,
        "failures": _failures,
    }
    var report_file := FileAccess.open(output_dir.path_join("visual-report.json"), FileAccess.WRITE)
    if report_file == null:
        _failures += 1
        push_error("Cannot write visual-report.json")
    else:
        report_file.store_string(JSON.stringify(manifest, "\t"))
        report_file.close()

    if is_instance_valid(_map):
        _map.queue_free()
        await process_frame
    print("Visual QA captures: %d / %d" % [zoom_reports.size(), ZOOM_LEVELS.size()])
    if _failures > 0 or zoom_reports.size() != ZOOM_LEVELS.size():
        quit(1)
    else:
        print("All visual QA captures passed.")
        quit(0)


func _count_sampled_colors(image: Image) -> int:
    var unique: Dictionary = {}
    var step_x := maxi(1, int(image.get_width() / 64))
    var step_y := maxi(1, int(image.get_height() / 36))
    for y in range(0, image.get_height(), step_y):
        for x in range(0, image.get_width(), step_x):
            var color := image.get_pixel(x, y)
            var key := "%d:%d:%d:%d" % [
                roundi(color.r * 255.0),
                roundi(color.g * 255.0),
                roundi(color.b * 255.0),
                roundi(color.a * 255.0),
            ]
            unique[key] = true
    return unique.size()
