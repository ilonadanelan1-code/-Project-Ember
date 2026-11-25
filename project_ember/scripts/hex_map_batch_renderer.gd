extends Node2D
class_name HexMapBatchRenderer

## One MultiMesh draws the explored world. Terrain textures are sampled in
## shared axial world coordinates, avoiding the tiled-stamp look.

const WORLD_RADIUS := 89
const HEX_SIZE := 30.0
const BASE_QUAD_SIZE := Vector2(63.6948, 70.4895)
const TERRAIN_FAMILY_COUNT := 6
const LOD_FAMILY := 6
const SURFACE_PANEL_COUNT := 25
const ATLAS_PANEL_SIZE := 717.0
const ATLAS_GUTTER := 51.0
const ATLAS_CELL_SIZE := 819.0
const ATLAS_WIDTH := 4096.0
const ATLAS_HEIGHT := 4096.0
const WORLD_TEXTURE_PERIOD := 430.0
const BIOME_MASK_RADIUS := WORLD_RADIUS + 1
const BIOME_MASK_SIZE := BIOME_MASK_RADIUS * 2 + 1
const SURFACE_VARIANTS_PER_FAMILY := 4
const LOD_SURFACE_VARIANT := 24
const BIOME_BLEND_WIDTH := 17.0
const SURFACE_ATLAS_PATH := "res://assets/map/world_surface_atlas.png"
const SURFACE_ATLAS_RESOURCE: Texture2D = preload("res://assets/map/world_surface_atlas.png")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")

const TERRAIN_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_mix;

uniform vec2 quad_size = vec2(63.6948, 70.4895);
uniform float texture_period = 430.0;
uniform float biome_blend_width = 17.0;
uniform sampler2D biome_mask : filter_nearest, repeat_disable;
const float ATLAS_PANEL_SIZE = 717.0;
const float ATLAS_GUTTER = 51.0;
const float ATLAS_CELL_SIZE = 819.0;
const float ATLAS_WIDTH = 4096.0;
const float ATLAS_HEIGHT = 4096.0;
const float MASK_SIZE = 181.0;
const float MASK_RADIUS = 90.0;
const float LOD_SURFACE_VARIANT = 24.0;
varying vec4 instance_payload;

void vertex() {
    instance_payload = COLOR;
}

float sample_surface_variant(vec2 axial_cell) {
    vec2 mask_uv = (axial_cell + vec2(MASK_RADIUS + 0.5)) / MASK_SIZE;
    float encoded = texture(biome_mask, mask_uv).r;
    return floor(encoded * 255.0 + 0.5);
}

vec2 surface_atlas_uv(float variant, vec2 surface_uv) {
    float atlas_column = mod(variant, 5.0);
    float atlas_row = floor(variant / 5.0);
    return vec2(
        (atlas_column * ATLAS_CELL_SIZE + ATLAS_GUTTER + surface_uv.x * ATLAS_PANEL_SIZE) / ATLAS_WIDTH,
        (atlas_row * ATLAS_CELL_SIZE + ATLAS_GUTTER + surface_uv.y * ATLAS_PANEL_SIZE) / ATLAS_HEIGHT
    );
}

vec4 sample_surface(float variant, vec2 surface_uv) {
    return texture(TEXTURE, surface_atlas_uv(variant, surface_uv));
}

void fragment() {
    float q = floor(instance_payload.r * 178.0 + 0.5) - 89.0;
    float r = floor(instance_payload.g * 178.0 + 0.5) - 89.0;
    float terrain_family = clamp(floor(instance_payload.b * 6.0 + 0.5), 0.0, 6.0);
    float brightness = clamp(instance_payload.a, 0.20, 1.0);

    float scale = max(quad_size.x / 63.6948, 1.0);
    vec2 local_px = (UV - vec2(0.5)) * quad_size;
    vec2 local_hex = local_px / scale;
    float ax = abs(local_px.x);
    float ay = abs(local_px.y);
    float edge_distance = min(
        25.980762 * scale - ax,
        min(30.0 * scale - ay, (51.961524 * scale - (ax + 1.7320508 * ay)) * 0.5)
    );
    float coverage = smoothstep(-0.65, 0.65, edge_distance);
    vec2 world_center = vec2(51.961524 * (q + 0.5 * r), 45.0 * r);
    vec2 world_position = world_center + local_px;
    float current_variant = terrain_family > 5.5 ? LOD_SURFACE_VARIANT : sample_surface_variant(vec2(q, r));
    float active_period = terrain_family > 5.5 ? texture_period * 2.0 : texture_period;
    vec2 surface_uv = fract(world_position / active_period);

    vec4 surface = sample_surface(current_variant, surface_uv);

    // Blend neighboring biome panels in a narrow, symmetric band along shared
    // hex edges. Both sides converge to the same 50/50 mixture at the border.
    if (terrain_family < 5.5) {
        float projection0 = local_hex.x;
        float projection1 = local_hex.x * 0.5 - local_hex.y * 0.8660254;
        float projection2 = -local_hex.x * 0.5 - local_hex.y * 0.8660254;
        float projection3 = -local_hex.x;
        float projection4 = -local_hex.x * 0.5 + local_hex.y * 0.8660254;
        float projection5 = local_hex.x * 0.5 + local_hex.y * 0.8660254;
        float max_projection = projection0;
        float second_projection = -1000.0;
        vec2 neighbor_offset = vec2(1.0, 0.0);
        vec2 second_neighbor_offset = vec2(1.0, -1.0);
        if (projection1 > max_projection) {
            second_projection = max_projection;
            second_neighbor_offset = neighbor_offset;
            max_projection = projection1;
            neighbor_offset = vec2(1.0, -1.0);
        } else if (projection1 > second_projection) {
            second_projection = projection1;
            second_neighbor_offset = vec2(1.0, -1.0);
        }
        if (projection2 > max_projection) {
            second_projection = max_projection;
            second_neighbor_offset = neighbor_offset;
            max_projection = projection2;
            neighbor_offset = vec2(0.0, -1.0);
        } else if (projection2 > second_projection) {
            second_projection = projection2;
            second_neighbor_offset = vec2(0.0, -1.0);
        }
        if (projection3 > max_projection) {
            second_projection = max_projection;
            second_neighbor_offset = neighbor_offset;
            max_projection = projection3;
            neighbor_offset = vec2(-1.0, 0.0);
        } else if (projection3 > second_projection) {
            second_projection = projection3;
            second_neighbor_offset = vec2(-1.0, 0.0);
        }
        if (projection4 > max_projection) {
            second_projection = max_projection;
            second_neighbor_offset = neighbor_offset;
            max_projection = projection4;
            neighbor_offset = vec2(-1.0, 1.0);
        } else if (projection4 > second_projection) {
            second_projection = projection4;
            second_neighbor_offset = vec2(-1.0, 1.0);
        }
        if (projection5 > max_projection) {
            second_projection = max_projection;
            second_neighbor_offset = neighbor_offset;
            max_projection = projection5;
            neighbor_offset = vec2(0.0, 1.0);
        } else if (projection5 > second_projection) {
            second_projection = projection5;
            second_neighbor_offset = vec2(0.0, 1.0);
        }
        float local_edge_distance = 25.980762 - max_projection;
        if (local_edge_distance < biome_blend_width) {
            float neighbor_variant = sample_surface_variant(vec2(q, r) + neighbor_offset);
            if (abs(neighbor_variant - current_variant) > 0.1 && neighbor_variant < 24.0) {
                float blend_weight = 0.5 * (1.0 - smoothstep(0.5, biome_blend_width, local_edge_distance));
                vec4 neighbor_surface = sample_surface(neighbor_variant, surface_uv);
                surface = mix(surface, neighbor_surface, blend_weight);
            }
        }
        float second_edge_distance = 25.980762 - second_projection;
        if (second_edge_distance < biome_blend_width * 0.82) {
            float second_variant = sample_surface_variant(vec2(q, r) + second_neighbor_offset);
            if (abs(second_variant - current_variant) > 0.1 && second_variant < 24.0) {
                float second_weight = 0.26 * (1.0 - smoothstep(0.5, biome_blend_width * 0.82, second_edge_distance));
                vec4 second_surface = sample_surface(second_variant, surface_uv);
                surface = mix(surface, second_surface, second_weight);
            }
        }
    }

    COLOR = vec4(surface.rgb * brightness, surface.a * coverage);
}
"""

var _instance: MultiMeshInstance2D
var _multimesh: MultiMesh
var _surface_texture: Texture2D
var _biome_mask_texture: ImageTexture
var _biome_mask_signature: String = ""
var _terrain_material: ShaderMaterial
var _quad: QuadMesh
var _last_instance_count: int = 0
var _last_zoom: float = -1.0
var _last_lod_chunk_size: int = 1
var _last_source_cell_count: int = 0
var _last_texture_families: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
    z_index = -1
    add_to_group("map_batch_renderer")
    _quad = QuadMesh.new()
    _quad.size = Vector2.ONE

    _multimesh = MultiMesh.new()
    _multimesh.transform_format = MultiMesh.TRANSFORM_2D
    _multimesh.use_colors = true
    _multimesh.mesh = _quad
    _multimesh.instance_count = 0

    _instance = MultiMeshInstance2D.new()
    _instance.name = "BatchedHexes"
    _instance.multimesh = _multimesh
    _surface_texture = _load_surface_texture()
    if _surface_texture == null:
        push_error("Continuous world surface atlas could not be loaded; terrain renderer remains disabled.")
        return
    _instance.texture = _surface_texture
    _instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    _terrain_material = ShaderMaterial.new()
    var terrain_shader := Shader.new()
    terrain_shader.code = TERRAIN_SHADER_CODE
    _terrain_material.shader = terrain_shader
    _terrain_material.set_shader_parameter("quad_size", BASE_QUAD_SIZE)
    _terrain_material.set_shader_parameter("texture_period", WORLD_TEXTURE_PERIOD)
    _terrain_material.set_shader_parameter("biome_blend_width", BIOME_BLEND_WIDTH)
    refresh_biome_mask()
    _instance.material = _terrain_material
    add_child(_instance)


func refresh_biome_mask() -> void:
    if not is_instance_valid(_terrain_material):
        return
    var signature := "%d:%d" % [CampaignState.world_seed, CampaignState.world_generation_version]
    if signature == _biome_mask_signature and is_instance_valid(_biome_mask_texture):
        return
    var mask_image := Image.create(BIOME_MASK_SIZE, BIOME_MASK_SIZE, false, Image.FORMAT_RGBA8)
    # A one-cell water ring lets the shader blend the world's outer coast safely.
    mask_image.fill(Color8(12, 0, 0, 255))
    for q in range(-BIOME_MASK_RADIUS, BIOME_MASK_RADIUS + 1):
        for r in range(-BIOME_MASK_RADIUS, BIOME_MASK_RADIUS + 1):
            var cell := Vector2i(q, r)
            if not WorldGeneratorScript.is_inside_world(cell):
                continue
            var terrain_kind := CampaignState.get_world_terrain(cell)
            var variant := surface_variant_for_cell(cell, terrain_kind, CampaignState.world_seed)
            mask_image.set_pixel(q + BIOME_MASK_RADIUS, r + BIOME_MASK_RADIUS, Color8(variant, 0, 0, 255))
    _biome_mask_texture = ImageTexture.create_from_image(mask_image)
    _terrain_material.set_shader_parameter("biome_mask", _biome_mask_texture)
    _biome_mask_signature = signature


func get_biome_mask_texture() -> Texture2D:
    return _biome_mask_texture


func get_texture_period() -> float:
    return WORLD_TEXTURE_PERIOD


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#111710"), true)


static func make_instance_data(cell: Vector2i, terrain_kind: String, use_lod: bool = false) -> Color:
    return make_instance_data_from_axial(Vector2(float(cell.x), float(cell.y)), terrain_kind, use_lod)


static func make_instance_data_from_axial(axial: Vector2, terrain_kind: String, use_lod: bool = false) -> Color:
    var family := LOD_FAMILY if use_lod else terrain_variant_for_kind(terrain_kind)
    var q_encoded := clampf((axial.x + float(WORLD_RADIUS)) / float(WORLD_RADIUS * 2), 0.0, 1.0)
    var r_encoded := clampf((axial.y + float(WORLD_RADIUS)) / float(WORLD_RADIUS * 2), 0.0, 1.0)
    var family_encoded := float(family) / float(LOD_FAMILY)
    return Color(q_encoded, r_encoded, family_encoded, 1.0)


static func surface_variant_for_cell(cell: Vector2i, terrain_kind: String, world_seed: int) -> int:
    var family := terrain_variant_for_kind(terrain_kind)
    var region_q := floori(float(cell.x) / 4.0)
    var region_r := floori(float(cell.y) / 4.0)
    var mixed := (region_q * 374761393) ^ (region_r * 668265263) ^ (world_seed * 1442695041) ^ (family * 1597334677)
    return family * SURFACE_VARIANTS_PER_FAMILY + posmod(mixed, SURFACE_VARIANTS_PER_FAMILY)


static func make_landmark_instance_data(cell: Vector2i, landmark_kind: String) -> Color:
    match landmark_kind:
        "peak":
            return make_instance_data(cell, "hills")
        "elder_tree":
            return make_instance_data(cell, "forest")
        "islet":
            return make_instance_data(cell, "water")
        "standing_stone":
            return make_instance_data(cell, "plain")
        _:
            return make_instance_data(cell, "plain")


static func terrain_variant_for_kind(terrain_kind: String) -> int:
    match terrain_kind:
        "forest":
            return 1
        "hills":
            return 2
        "water":
            return 3
        "farmland":
            return 4
        "marsh":
            return 5
        _:
            return 0


static func world_texture_uv(cell: Vector2i, local_pixel: Vector2) -> Vector2:
    var center := Vector2(51.961524 * (float(cell.x) + 0.5 * float(cell.y)), 45.0 * float(cell.y))
    var world_position := center + local_pixel
    return Vector2(
        fposmod(world_position.x, WORLD_TEXTURE_PERIOD) / WORLD_TEXTURE_PERIOD,
        fposmod(world_position.y, WORLD_TEXTURE_PERIOD) / WORLD_TEXTURE_PERIOD
    )


func set_map_tiles(
        cells: Array[Vector2i],
        centers: PackedVector2Array,
        colors: PackedColorArray,
        tile_size: Vector2,
        zoom: float,
        terrain_data: PackedColorArray = PackedColorArray()
) -> void:
    refresh_biome_mask()
    var source_count := mini(cells.size(), mini(centers.size(), colors.size()))
    _last_source_cell_count = source_count
    var has_terrain_data := terrain_data.size() >= source_count
    var chunk_size := 1
    if zoom <= 0.22:
        chunk_size = 6
    if chunk_size == 1:
        var direct_centers := PackedVector2Array()
        var direct_colors := PackedColorArray()
        var direct_styles := PackedColorArray()
        direct_centers.resize(source_count)
        direct_colors.resize(source_count)
        direct_styles.resize(source_count)
        for index in range(source_count):
            direct_centers[index] = centers[index]
            direct_colors[index] = colors[index]
            direct_styles[index] = terrain_data[index] if has_terrain_data else make_instance_data(cells[index], "plain")
        _last_lod_chunk_size = 1
        set_tiles(direct_centers, direct_colors, tile_size, zoom, direct_styles)
        return

    var buckets: Dictionary = {}
    for index in range(source_count):
        var cell := cells[index]
        var bucket_key := Vector2i(
            floori(float(cell.x) / float(chunk_size)),
            floori(float(cell.y) / float(chunk_size))
        )
        if not buckets.has(bucket_key):
            buckets[bucket_key] = {
                "position": Vector2.ZERO,
                "color": Color(0.0, 0.0, 0.0, 0.0),
                "axial": Vector2.ZERO,
                "count": 0,
            }
        var bucket: Dictionary = buckets[bucket_key]
        var bucket_position: Vector2 = bucket["position"]
        var bucket_color: Color = bucket["color"]
        var bucket_axial: Vector2 = bucket["axial"]
        bucket["position"] = bucket_position + centers[index]
        bucket["color"] = bucket_color + colors[index]
        bucket["axial"] = bucket_axial + Vector2(float(cell.x), float(cell.y))
        bucket["count"] = int(bucket["count"]) + 1
        buckets[bucket_key] = bucket

    var lod_centers := PackedVector2Array()
    var lod_colors := PackedColorArray()
    var lod_styles := PackedColorArray()
    for bucket_key_value in buckets.keys():
        var bucket: Dictionary = buckets[bucket_key_value]
        var count := int(bucket["count"])
        if count <= 0:
            continue
        var average_color: Color = bucket["color"] / float(count)
        var average_position: Vector2 = bucket["position"] / float(count)
        var average_axial: Vector2 = bucket["axial"] / float(count)
        lod_centers.append(average_position)
        lod_colors.append(average_color)
        lod_styles.append(make_instance_data_from_axial(average_axial, "plain", true))

    _last_lod_chunk_size = chunk_size
    set_tiles(lod_centers, lod_colors, tile_size * float(chunk_size), zoom, lod_styles)


func set_tiles(
        centers: PackedVector2Array,
        colors: PackedColorArray,
        tile_size: Vector2,
        zoom: float,
        terrain_data: PackedColorArray = PackedColorArray()
) -> void:
    if not is_instance_valid(_multimesh) or not is_instance_valid(_instance):
        return
    var count := mini(centers.size(), colors.size())
    if _multimesh.instance_count != count:
        _multimesh.instance_count = count
        _multimesh.visible_instance_count = count
    _last_instance_count = count
    _last_texture_families.resize(count)
    if is_instance_valid(_terrain_material):
        _terrain_material.set_shader_parameter("quad_size", tile_size)
    var scaled_size := tile_size * zoom
    for index in range(count):
        var center := centers[index]
        var instance_transform := Transform2D(
            Vector2(scaled_size.x, 0.0),
            Vector2(0.0, scaled_size.y),
            center
        )
        _multimesh.set_instance_transform_2d(index, instance_transform)
        var payload := terrain_data[index] if index < terrain_data.size() else make_instance_data(Vector2i.ZERO, "plain")
        var map_color := colors[index]
        var fog_brightness := clampf(minf(map_color.r, minf(map_color.g, map_color.b)), 0.20, 1.0)
        var family := clampi(roundi(payload.b * float(LOD_FAMILY)), 0, LOD_FAMILY)
        _multimesh.set_instance_color(index, Color(payload.r, payload.g, payload.b, fog_brightness))
        _last_texture_families[index] = family
    _last_zoom = zoom


func get_tile_instance_count() -> int:
    return _last_instance_count


func get_batched_draw_count() -> int:
    return 1 if _last_instance_count > 0 else 0


func get_lod_chunk_size() -> int:
    return _last_lod_chunk_size


func get_last_zoom() -> float:
    return _last_zoom


func get_source_cell_count() -> int:
    return _last_source_cell_count


func get_texture() -> Texture2D:
    return _surface_texture


func get_terrain_family_count() -> int:
    return TERRAIN_FAMILY_COUNT


func get_surface_panel_count() -> int:
    return SURFACE_PANEL_COUNT


func get_surface_variant_count() -> int:
    return TERRAIN_FAMILY_COUNT * SURFACE_VARIANTS_PER_FAMILY


func get_surface_panel_size() -> Vector2i:
    return Vector2i(int(ATLAS_PANEL_SIZE), int(ATLAS_PANEL_SIZE))


func get_instance_texture_family(index: int) -> int:
    if index < 0 or index >= _last_texture_families.size():
        return -1
    return _last_texture_families[index]


func _load_surface_texture() -> Texture2D:
    var expected_width := int(ATLAS_WIDTH)
    var expected_height := int(ATLAS_HEIGHT)
    var actual_size := SURFACE_ATLAS_RESOURCE.get_size()
    if int(actual_size.x) != expected_width or int(actual_size.y) != expected_height:
        push_error(
            "World surface atlas size mismatch (%s): expected %d×%d, received %s"
            % [SURFACE_ATLAS_PATH, expected_width, expected_height, actual_size]
        )
        return null
    return SURFACE_ATLAS_RESOURCE
