extends Node2D
class_name WorldDetailBatchRenderer

## One atlas-backed MultiMesh for large foreground landscape details.
## Instances are deterministic per world seed and streamed only for explored cells.

const WORLD_RADIUS := 89
const ATLAS_COLUMNS := 6
const ATLAS_ROWS := 4
const SPRITE_COUNT := 24
const DETAIL_ATLAS_PATH := "res://assets/map/world_detail_atlas.png"
const DETAIL_ATLAS: Texture2D = preload("res://assets/map/world_detail_atlas.png")

const DETAIL_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_mix;
varying vec4 detail_payload;

void vertex() {
    detail_payload = COLOR;
}

void fragment() {
    float sprite_index = clamp(floor(detail_payload.r * 23.0 + 0.5), 0.0, 23.0);
    vec2 atlas_cell = vec2(mod(sprite_index, 6.0), floor(sprite_index / 6.0));
    vec2 atlas_uv = (atlas_cell + UV) / vec2(6.0, 4.0);
    vec4 sprite_color = texture(TEXTURE, atlas_uv);
    float visibility = clamp(detail_payload.a, 0.25, 1.0);
    COLOR = vec4(sprite_color.rgb * visibility, sprite_color.a * visibility);
}
"""

var _multimesh: MultiMesh
var _instance: MultiMeshInstance2D
var _material: ShaderMaterial
var _last_count: int = 0
var _last_source_count: int = 0


func _ready() -> void:
    z_index = -1
    _multimesh = MultiMesh.new()
    _multimesh.transform_format = MultiMesh.TRANSFORM_2D
    _multimesh.use_colors = true
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    _multimesh.mesh = quad
    _multimesh.instance_count = 0

    _instance = MultiMeshInstance2D.new()
    _instance.name = "BatchedWorldDetails"
    _instance.multimesh = _multimesh
    _instance.texture = DETAIL_ATLAS
    _instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    _material = ShaderMaterial.new()
    var shader := Shader.new()
    shader.code = DETAIL_SHADER_CODE
    _material.shader = shader
    _instance.material = _material
    add_child(_instance)


static func choose_sprite(cell: Vector2i, terrain_kind: String, world_seed: int) -> int:
    var mixed := (cell.x * 374761393) ^ (cell.y * 668265263) ^ (world_seed * 1442695041)
    var roll := posmod(mixed, 1000)
    match terrain_kind:
        "plain":
            return posmod(roll, 4) if roll < 36 else -1
        "forest":
            return 4 + posmod(roll, 4) if roll < 92 else -1
        "hills":
            return 8 + posmod(roll, 4) if roll < 105 else -1
        "water":
            return 12 + posmod(roll, 4) if roll < 36 else -1
        "farmland":
            return 16 + posmod(roll, 4) if roll < 88 else -1
        "marsh":
            return 20 + posmod(roll, 4) if roll < 88 else -1
        _:
            return -1


static func sprite_size(sprite_index: int) -> Vector2:
    if sprite_index <= 3:
        return Vector2(60.0, 48.0)
    if sprite_index <= 7:
        return Vector2(84.0, 68.0)
    if sprite_index <= 11:
        return Vector2(96.0, 68.0)
    if sprite_index <= 15:
        return Vector2(62.0, 50.0)
    if sprite_index <= 19:
        return Vector2(86.0, 58.0)
    return Vector2(80.0, 58.0)

func set_visible_cells(
        cells: Array[Vector2i],
        centers: PackedVector2Array,
        terrain_kinds: PackedStringArray,
        colors: PackedColorArray,
        zoom: float,
        world_seed: int
) -> void:
    _last_source_count = mini(cells.size(), mini(centers.size(), mini(terrain_kinds.size(), colors.size())))
    if zoom < 0.40 or _last_source_count == 0:
        _set_instance_count(0)
        return

    var transforms: Array[Transform2D] = []
    var payloads := PackedColorArray()
    for index in range(_last_source_count):
        var cell := cells[index]
        var sprite_index := choose_sprite(cell, terrain_kinds[index], world_seed)
        if sprite_index < 0:
            continue
        var mixed := (cell.x * 374761393) ^ (cell.y * 668265263) ^ (world_seed * 1442695041)
        var offset_x := float(posmod(mixed, 17) - 8)
        var offset_y := float(posmod(floori(float(mixed) / 17.0), 15) - 7)
        var quarter_turn := posmod(floori(float(mixed) / 437.0), 4)
        var angle := float(quarter_turn) * PI * 0.5
        var dims := sprite_size(sprite_index) * zoom
        var cosine := cos(angle)
        var sine := sin(angle)
        var x_axis := Vector2(cosine, sine) * dims.x
        var y_axis := Vector2(-sine, cosine) * dims.y
        var tint := colors[index]
        var brightness := clampf(minf(tint.r, minf(tint.g, tint.b)), 0.34, 1.0)
        transforms.append(Transform2D(x_axis, y_axis, centers[index] + Vector2(offset_x, offset_y) * zoom))
        payloads.append(Color(float(sprite_index) / 23.0, 0.0, 0.0, brightness))

    _set_instance_count(transforms.size())
    for index in range(transforms.size()):
        _multimesh.set_instance_transform_2d(index, transforms[index])
        _multimesh.set_instance_color(index, payloads[index])


func _set_instance_count(count: int) -> void:
    if _multimesh.instance_count != count:
        _multimesh.instance_count = count
        _multimesh.visible_instance_count = count
    _last_count = count


func get_detail_instance_count() -> int:
    return _last_count


func get_source_cell_count() -> int:
    return _last_source_count


func get_batched_draw_count() -> int:
    return 1 if _last_count > 0 else 0


func get_texture() -> Texture2D:
    return DETAIL_ATLAS
