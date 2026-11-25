extends Node

const RendererScript = preload("res://scripts/hex_map_batch_renderer.gd")

var _failures := 0


func _ready() -> void:
    call_deferred("_run")


func _check(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        _failures += 1
        push_error("TEST FAILED: " + description)


func _run() -> void:
    var renderer := RendererScript.new()
    get_tree().root.add_child(renderer)
    await get_tree().process_frame

    var surface_texture := renderer.get_texture()
    _check(surface_texture is Texture2D, "continuous world surface atlas loads")
    if surface_texture is Texture2D:
        _check(surface_texture.get_width() == 4096 and surface_texture.get_height() == 4096, "24 independent scene panels plus LOD use a guarded 5x5 atlas within a 4096px GPU limit")
    else:
        _check(false, "world surface atlas is null")

    _check(renderer.get_terrain_family_count() == 6, "six continuous terrain families are available")
    _check(renderer.get_surface_panel_count() == 25, "24 independent biome scenes plus continent LOD share one atlas")
    _check(renderer.get_surface_variant_count() == 24, "six biomes expose four independent art variants each")
    _check(renderer.get_surface_panel_size() == Vector2i(717, 717), "surface panels use independent painterly scene crops")
    _check(renderer.get_texture_period() == 430.0, "430-world-unit surface period provides increased source detail at close zoom")
    var mask_texture := renderer.get_biome_mask_texture()
    _check(mask_texture is Texture2D and mask_texture.get_width() == 181 and mask_texture.get_height() == 181, "181x181 surface-variant mask includes the world boundary water ring")
    _check(renderer.get_batched_draw_count() == 0, "empty viewport submits no terrain draw batch")

    var batched_instance := renderer.get_node_or_null("BatchedHexes") as MultiMeshInstance2D
    _check(batched_instance != null, "one terrain MultiMesh instance is created")
    if batched_instance != null:
        var material := batched_instance.material as ShaderMaterial
        _check(material != null and material.shader != null, "continuous surface shader is installed")
        if material != null and material.shader != null:
            var source := material.shader.code
            _check(source.contains("varying vec4 instance_payload;"), "shader captures per-instance world payload")
            _check(source.contains("world_center = vec2(51.961524 * (q + 0.5 * r), 45.0 * r)"), "shader reconstructs pointy-top axial world coordinates")
            _check(source.contains("fract(world_position / active_period)"), "surface UVs continue globally across neighboring hexes")
            _check(source.contains("edge_distance") and source.contains("smoothstep"), "hexes are clipped with a clean antialiased mask")
            _check(source.contains("ATLAS_CELL_SIZE") and source.contains("atlas_column = mod(variant, 5.0)"), "shader resolves five atlas columns")
            _check(source.contains("atlas_row = floor(variant / 5.0)") and source.contains("/ ATLAS_HEIGHT"), "shader resolves five atlas rows independently")
            _check(not source.contains("atlas_index = clamp(floor"), "renderer no longer chooses a separate painted stamp per hex")
            _check(source.contains("uniform sampler2D surface_atlas") and source.contains("textureLod(surface_atlas,"), "shader samples the painted atlas through an explicit texture uniform and mip level")
            _check(source.contains("MAX_ATLAS_MIP_LEVEL = 4.0") and source.contains("dFdx(surface_coordinate)") and source.contains("dFdy(surface_coordinate)"), "atlas mip level is capped at four using continuous UV derivatives to protect panel gutters")
            _check(source.contains("uniform sampler2D biome_mask"), "shader samples a world-wide biome mask for neighboring terrain")
            _check(source.contains("sample_surface_variant") and source.contains("neighbor_surface") and source.contains("second_neighbor_offset"), "shader blends different biome surfaces across shared edges")
            _check(source.contains("biome_blend_width"), "biome transitions use a controlled soft boundary")

    var names := ["plain", "forest", "hills", "water", "farmland", "marsh"]
    var expected_families := [0, 1, 2, 3, 4, 5]
    var centers := PackedVector2Array()
    var colors := PackedColorArray()
    var styles := PackedColorArray()
    var cells: Array[Vector2i] = []
    for family_index in range(names.size()):
        for cell_index in range(100):
            var column := cell_index % 10 + (family_index % 3) * 10
            var row := int(cell_index / 10) + int(family_index / 3) * 10
            var cell := Vector2i(column - 15, row - 10)
            cells.append(cell)
            centers.append(Vector2(51.961524 * (float(cell.x) + 0.5 * float(cell.y)), 45.0 * float(cell.y)))
            colors.append(Color.WHITE)
            styles.append(RendererScript.make_instance_data(cell, names[family_index]))

    renderer.set_tiles(centers, colors, Vector2(63.6948, 70.4895), 0.9, styles)
    _check(renderer.get_tile_instance_count() == 600, "600 explored hexes use 600 MultiMesh instances")
    _check(renderer.get_batched_draw_count() == 1, "all biome surfaces stay in one draw batch")
    var families_match := true
    for family_index in range(names.size()):
        for index in range(family_index * 100, (family_index + 1) * 100):
            if renderer.get_instance_texture_family(index) != expected_families[family_index]:
                families_match = false
    _check(families_match, "all six terrain types select their own continuous surface panel")

    _check(RendererScript.terrain_variant_for_kind("plain") == 0, "plain maps to meadow surface")
    _check(RendererScript.terrain_variant_for_kind("forest") == 1, "forest maps to canopy surface")
    _check(RendererScript.terrain_variant_for_kind("hills") == 2, "highlands map to alpine surface")
    _check(RendererScript.terrain_variant_for_kind("water") == 3, "water maps to lake/ocean surface")
    _check(RendererScript.terrain_variant_for_kind("farmland") == 4, "farmland maps to field surface")
    _check(RendererScript.terrain_variant_for_kind("marsh") == 5, "marsh maps to wetland surface")
    var region_variant_a := RendererScript.surface_variant_for_cell(Vector2i(0, 0), "plain", 842173)
    var region_variant_b := RendererScript.surface_variant_for_cell(Vector2i(2, 3), "plain", 842173)
    _check(region_variant_a == region_variant_b, "same 4x4 axial region keeps one stable meadow scene variant")
    _check(region_variant_a >= 0 and region_variant_a < 4, "meadow selects one of four independent source scenes")
    _check(RendererScript.surface_variant_for_cell(Vector2i(0, 0), "forest", 842173) >= 4, "forest selects its own independent atlas range")
    _check(RendererScript.surface_variant_for_cell(Vector2i(0, 0), "plain", 842173) != RendererScript.surface_variant_for_cell(Vector2i(4, 0), "plain", 842173), "different axial macro-regions can select different meadow scenes")
    for family_name in names:
        var expected_family := RendererScript.terrain_variant_for_kind(family_name)
        var selected_variant := RendererScript.surface_variant_for_cell(Vector2i(-17, 29), family_name, 842173)
        _check(selected_variant >= expected_family * 4 and selected_variant < expected_family * 4 + 4, "%s selects only its four dedicated scene variants" % family_name)

    # Each shared edge midpoint must map to one identical world-space UV from both cells.
    var neighbor_directions: Array[Vector2i] = [
        Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
        Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
    ]
    var edge_samples_match := true
    for direction in neighbor_directions:
        var world_delta := Vector2(
            51.961524 * (float(direction.x) + 0.5 * float(direction.y)),
            45.0 * float(direction.y)
        )
        var first_uv := RendererScript.world_texture_uv(Vector2i(0, 0), world_delta * 0.5)
        var second_uv := RendererScript.world_texture_uv(direction, -world_delta * 0.5)
        if first_uv.distance_to(second_uv) >= 0.00001:
            edge_samples_match = false
    _check(edge_samples_match, "all six neighbor directions share continuous surface UVs for every biome")

    var lod_centers := PackedVector2Array([Vector2(120.0, 100.0)])
    var lod_colors := PackedColorArray([Color.WHITE])
    var lod_styles := PackedColorArray([RendererScript.make_instance_data(Vector2i(6, 6), "plain", true)])
    renderer.set_tiles(lod_centers, lod_colors, Vector2(63.6948 * 6.0, 70.4895 * 6.0), 0.1, lod_styles)
    _check(renderer.get_instance_texture_family(0) == 6, "continent LOD selects the calm topographic surface panel")
    _check(renderer.get_batched_draw_count() == 1, "LOD remains one batch")

    renderer.set_map_tiles(cells, centers, colors, Vector2(63.6948, 70.4895), 0.9, styles)
    _check(renderer.get_lod_chunk_size() == 1 and renderer.get_tile_instance_count() == 600, "close zoom keeps direct hex terrain")
    renderer.set_map_tiles(cells, centers, colors, Vector2(63.6948, 70.4895), 0.1, styles)
    _check(renderer.get_lod_chunk_size() == 6, "continent zoom activates six-hex LOD chunks")
    _check(renderer.get_tile_instance_count() <= 36, "600 discovered tiles collapse into at most 36 LOD instances")
    _check(renderer.get_instance_texture_family(0) == 6, "LOD chunks use the topographic panel")
    _check(renderer.get_batched_draw_count() == 1, "LOD remains one terrain batch")

    if _failures > 0:
        printerr("Continuous world surface renderer tests failed: %d" % _failures)
        get_tree().quit(1)
    else:
        print("All continuous world surface renderer tests passed.")
        get_tree().quit(0)
