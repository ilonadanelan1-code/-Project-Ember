extends Node2D
class_name HexMapBatchRenderer

## One batched MultiMesh draws every visible strategic hex.
## Terrain-specific atlas motifs and per-instance orientation keep the map
## varied without creating per-cell nodes or additional draw calls.

const TEXTURE_WIDTH := 64
const TEXTURE_HEIGHT := 72
const TERRAIN_VARIANT_COUNT := 5
const VARIANT_GRASS := 0
const VARIANT_FOREST := 1
const VARIANT_HILLS := 2
const VARIANT_WATER := 3
const VARIANT_LOD := 4

const TERRAIN_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_mix;

void fragment() {
	float variant = clamp(floor(INSTANCE_CUSTOM.r + 0.5), 0.0, 4.0);
	float turn_index = floor(clamp(INSTANCE_CUSTOM.g, 0.0, 0.999) * 6.0);
	float angle = turn_index * (PI / 3.0);
	float c = cos(angle);
	float s = sin(angle);
	vec2 centered_uv = UV - vec2(0.5);
	vec2 rotated_uv = mat2(c, -s, s, c) * centered_uv + vec2(0.5);
	rotated_uv = clamp(rotated_uv, vec2(0.018), vec2(0.982));
	vec2 atlas_uv = vec2((variant + rotated_uv.x) / 5.0, rotated_uv.y);
	vec4 tile = texture(TEXTURE, atlas_uv);
	COLOR = vec4(tile.rgb * COLOR.rgb, tile.a * COLOR.a);
}
"""

var _instance: MultiMeshInstance2D
var _multimesh: MultiMesh
var _hex_texture: ImageTexture
var _quad: QuadMesh
var _last_instance_count: int = 0
var _last_zoom: float = -1.0
var _last_lod_chunk_size: int = 1
var _last_source_cell_count: int = 0


func _ready() -> void:
	z_index = -1
	add_to_group("map_batch_renderer")
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = _quad
	_multimesh.instance_count = 0

	_instance = MultiMeshInstance2D.new()
	_instance.name = "BatchedHexes"
	_instance.multimesh = _multimesh
	_instance.texture = _make_hex_texture()
	_instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var terrain_material := ShaderMaterial.new()
	var terrain_shader := Shader.new()
	terrain_shader.code = TERRAIN_SHADER_CODE
	terrain_material.shader = terrain_shader
	_instance.material = terrain_material
	add_child(_instance)


func _draw() -> void:
	# The empty world is the unexplored fog layer. Discovered tiles are drawn
	# above this solid backdrop, so no hidden terrain data is exposed.
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#111710"), true)


static func make_instance_data(cell: Vector2i, terrain_kind: String, use_lod: bool = false) -> Color:
	var variant := VARIANT_LOD if use_lod else terrain_variant_for_kind(terrain_kind)
	var orientation_hash := cell.x * 374761393 + cell.y * 668265263 + cell.x * cell.y * 1442695041
	var orientation := float(posmod(orientation_hash, 6)) / 6.0
	return Color(float(variant), orientation, 0.0, 1.0)


static func terrain_variant_for_kind(terrain_kind: String) -> int:
	match terrain_kind:
		"forest":
			return VARIANT_FOREST
		"hills":
			return VARIANT_HILLS
		"water":
			return VARIANT_WATER
		_:
			return VARIANT_GRASS


func set_map_tiles(
		cells: Array[Vector2i],
		centers: PackedVector2Array,
		colors: PackedColorArray,
		tile_size: Vector2,
		zoom: float,
		custom_data: PackedColorArray = PackedColorArray()
) -> void:
	var source_count := mini(cells.size(), mini(centers.size(), colors.size()))
	_last_source_cell_count = source_count
	var has_custom_data := custom_data.size() >= source_count
	var chunk_size := 1
	if zoom <= 0.22:
		chunk_size = 6
	if chunk_size == 1:
		var direct_centers := PackedVector2Array()
		var direct_colors := PackedColorArray()
		var direct_custom_data := PackedColorArray()
		direct_centers.resize(source_count)
		direct_colors.resize(source_count)
		direct_custom_data.resize(source_count)
		for index in range(source_count):
			direct_centers[index] = centers[index]
			direct_colors[index] = colors[index]
			direct_custom_data[index] = custom_data[index] if has_custom_data else make_instance_data(cells[index], "grass")
		_last_lod_chunk_size = 1
		set_tiles(direct_centers, direct_colors, tile_size, zoom, direct_custom_data)
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
				"count": 0,
			}
		var bucket: Dictionary = buckets[bucket_key]
		var bucket_position: Vector2 = bucket["position"]
		var bucket_color: Color = bucket["color"]
		bucket["position"] = bucket_position + centers[index]
		bucket["color"] = bucket_color + colors[index]
		bucket["count"] = int(bucket["count"]) + 1
		buckets[bucket_key] = bucket

	var lod_centers := PackedVector2Array()
	var lod_colors := PackedColorArray()
	var lod_custom_data := PackedColorArray()
	for bucket_key_value in buckets.keys():
		var bucket: Dictionary = buckets[bucket_key_value]
		var count := int(bucket["count"])
		if count <= 0:
			continue
		var average_color: Color = bucket["color"]
		average_color /= float(count)
		# A soft alpha at the boundary keeps partially explored chunks visually
		# subordinate to fully explored terrain without revealing hidden details.
		var coverage := clampf(float(count) / float(chunk_size * chunk_size), 0.0, 1.0)
		average_color.a *= 0.28 + coverage * 0.72
		var average_position: Vector2 = bucket["position"]
		lod_centers.append(average_position / float(count))
		lod_colors.append(average_color)
		var chunk_cell: Vector2i = bucket_key_value
		lod_custom_data.append(make_instance_data(chunk_cell, "grass", true))

	_last_lod_chunk_size = chunk_size
	set_tiles(lod_centers, lod_colors, tile_size * float(chunk_size), zoom, lod_custom_data)


func set_tiles(
		centers: PackedVector2Array,
		colors: PackedColorArray,
		tile_size: Vector2,
		zoom: float,
		custom_data: PackedColorArray = PackedColorArray()
) -> void:
	if not is_instance_valid(_multimesh) or not is_instance_valid(_instance):
		return
	var count := mini(centers.size(), colors.size())
	if _multimesh.instance_count != count:
		_multimesh.instance_count = count
		_multimesh.visible_instance_count = count
	_last_instance_count = count
	var scaled_size := tile_size * zoom
	for index in range(count):
		var center := centers[index]
		var transform := Transform2D(
			Vector2(scaled_size.x, 0.0),
			Vector2(0.0, scaled_size.y),
			center
		)
		_multimesh.set_instance_transform_2d(index, transform)
		_multimesh.set_instance_color(index, colors[index])
		var instance_data := custom_data[index] if index < custom_data.size() else Color(float(VARIANT_LOD), 0.0, 0.0, 1.0)
		_multimesh.set_instance_custom_data(index, instance_data)
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
	return _hex_texture


func get_instance_custom_data(index: int) -> Color:
	if not is_instance_valid(_multimesh) or index < 0 or index >= _last_instance_count:
		return Color.TRANSPARENT
	return _multimesh.get_instance_custom_data(index)


func is_using_instance_custom_data() -> bool:
	return is_instance_valid(_multimesh) and _multimesh.use_custom_data


func get_terrain_variant_count() -> int:
	return TERRAIN_VARIANT_COUNT


func _make_hex_texture() -> ImageTexture:
	var atlas := Image.create(TEXTURE_WIDTH * TERRAIN_VARIANT_COUNT, TEXTURE_HEIGHT, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.0, 0.0, 0.0, 0.0))
	for variant in range(TERRAIN_VARIANT_COUNT):
		_draw_hex_base(atlas, variant * TEXTURE_WIDTH)
		match variant:
			VARIANT_GRASS:
				_draw_grass_motif(atlas, variant * TEXTURE_WIDTH)
			VARIANT_FOREST:
				_draw_forest_motif(atlas, variant * TEXTURE_WIDTH)
			VARIANT_HILLS:
				_draw_hills_motif(atlas, variant * TEXTURE_WIDTH)
			VARIANT_WATER:
				_draw_water_motif(atlas, variant * TEXTURE_WIDTH)
			VARIANT_LOD:
				_draw_lod_motif(atlas, variant * TEXTURE_WIDTH)
	_hex_texture = ImageTexture.create_from_image(atlas)
	return _hex_texture


func _draw_hex_base(image: Image, offset_x: int) -> void:
	var polygon := PackedVector2Array([
		Vector2(32.0, 2.0),
		Vector2(59.0, 17.0),
		Vector2(59.0, 55.0),
		Vector2(32.0, 70.0),
		Vector2(5.0, 55.0),
		Vector2(5.0, 17.0),
	])
	var shadow_polygon := PackedVector2Array()
	for point in polygon:
		shadow_polygon.append(point + Vector2(0.0, 2.0))

	for local_y in range(TEXTURE_HEIGHT):
		for local_x in range(TEXTURE_WIDTH):
			var point := Vector2(float(local_x) + 0.5, float(local_y) + 0.5)
			var in_hex := Geometry2D.is_point_in_polygon(point, polygon)
			var in_shadow := Geometry2D.is_point_in_polygon(point, shadow_polygon)
			var x := offset_x + local_x
			if not in_hex:
				if in_shadow:
					image.set_pixel(x, local_y, Color(0.28, 0.31, 0.28, 0.42))
				continue
			var edge_distance := 999.0
			for edge_index in range(polygon.size()):
				var a := polygon[edge_index]
				var b := polygon[(edge_index + 1) % polygon.size()]
				edge_distance = minf(edge_distance, Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point))
			var vertical_light := 0.96 + (1.0 - float(local_y) / float(TEXTURE_HEIGHT)) * 0.10
			var side_facet := 0.025 if local_x < 32 else -0.025
			var shade := clampf(vertical_light + side_facet, 0.82, 1.08)
			if edge_distance < 1.8:
				shade = 1.10
			elif edge_distance < 4.2:
				shade *= 0.80
			image.set_pixel(x, local_y, Color(shade, shade, shade, 1.0))


func _draw_grass_motif(image: Image, offset_x: int) -> void:
	for origin in [Vector2(17, 43), Vector2(42, 31), Vector2(31, 21)]:
		_draw_shade_line(image, offset_x, origin, origin + Vector2(-4, -8), 1, 0.76)
		_draw_shade_line(image, offset_x, origin, origin + Vector2(0, -10), 1, 0.72)
		_draw_shade_line(image, offset_x, origin, origin + Vector2(4, -7), 1, 0.82)
		_draw_shade_line(image, offset_x, origin + Vector2(0, -2), origin + Vector2(5, -6), 1, 1.08)


func _draw_forest_motif(image: Image, offset_x: int) -> void:
	_draw_shade_line(image, offset_x, Vector2(18, 43), Vector2(18, 28), 2, 0.62)
	_draw_shade_line(image, offset_x, Vector2(42, 48), Vector2(42, 32), 2, 0.62)
	_draw_shade_line(image, offset_x, Vector2(31, 30), Vector2(31, 18), 2, 0.66)
	_draw_shade_disk(image, offset_x, Vector2(18, 27), 7, 0.72)
	_draw_shade_disk(image, offset_x, Vector2(42, 31), 8, 0.70)
	_draw_shade_disk(image, offset_x, Vector2(31, 18), 6, 0.68)
	_draw_shade_disk(image, offset_x, Vector2(15, 25), 2, 1.12)
	_draw_shade_disk(image, offset_x, Vector2(39, 28), 2, 1.12)
	_draw_shade_disk(image, offset_x, Vector2(29, 16), 2, 1.10)


func _draw_hills_motif(image: Image, offset_x: int) -> void:
	_draw_shade_line(image, offset_x, Vector2(9, 47), Vector2(22, 34), 2, 0.70)
	_draw_shade_line(image, offset_x, Vector2(22, 34), Vector2(33, 38), 2, 1.10)
	_draw_shade_line(image, offset_x, Vector2(33, 38), Vector2(54, 24), 2, 0.74)
	_draw_shade_line(image, offset_x, Vector2(10, 52), Vector2(23, 40), 1, 1.10)
	_draw_shade_line(image, offset_x, Vector2(23, 40), Vector2(35, 44), 1, 0.82)
	_draw_shade_line(image, offset_x, Vector2(35, 44), Vector2(53, 32), 1, 1.08)
	_draw_shade_line(image, offset_x, Vector2(15, 57), Vector2(25, 49), 1, 0.84)


func _draw_water_motif(image: Image, offset_x: int) -> void:
	for wave_index in range(3):
		var base_y := 25.0 + float(wave_index) * 11.0
		var previous := Vector2(12.0, base_y)
		for point_index in range(1, 7):
			var x := 12.0 + float(point_index) * 6.0
			var y := base_y + sin(float(point_index) * 1.2 + float(wave_index)) * 2.2
			var next_point := Vector2(x, y)
			_draw_shade_line(image, offset_x, previous, next_point, 1, 1.10 if wave_index != 1 else 0.78)
			previous = next_point
	_draw_shade_line(image, offset_x, Vector2(21, 18), Vector2(31, 17), 1, 1.08)
	_draw_shade_line(image, offset_x, Vector2(35, 55), Vector2(44, 54), 1, 1.08)


func _draw_lod_motif(image: Image, offset_x: int) -> void:
	# At continent scale use restrained topographic contours rather than
	# magnifying individual trees, grass blades or waves.
	_draw_shade_line(image, offset_x, Vector2(14, 25), Vector2(24, 19), 1, 0.90)
	_draw_shade_line(image, offset_x, Vector2(24, 19), Vector2(41, 23), 1, 0.90)
	_draw_shade_line(image, offset_x, Vector2(41, 23), Vector2(50, 34), 1, 0.90)
	_draw_shade_line(image, offset_x, Vector2(12, 39), Vector2(24, 34), 1, 1.08)
	_draw_shade_line(image, offset_x, Vector2(24, 34), Vector2(39, 38), 1, 1.08)
	_draw_shade_line(image, offset_x, Vector2(39, 38), Vector2(51, 47), 1, 1.08)


func _draw_shade_line(image: Image, offset_x: int, start: Vector2, finish: Vector2, width: int, shade: float) -> void:
	var distance := start.distance_to(finish)
	var steps := maxi(1, ceili(distance * 2.0))
	for step in range(steps + 1):
		var point := start.lerp(finish, float(step) / float(steps))
		for dy in range(-width, width + 1):
			for dx in range(-width, width + 1):
				if dx * dx + dy * dy > width * width + 1:
					continue
				_shade_pixel(image, offset_x + roundi(point.x) + dx, roundi(point.y) + dy, shade)


func _draw_shade_disk(image: Image, offset_x: int, center: Vector2, radius: int, shade: float) -> void:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius:
				_shade_pixel(image, offset_x + roundi(center.x) + x, roundi(center.y) + y, shade)


func _shade_pixel(image: Image, x: int, y: int, shade: float) -> void:
	if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height():
		return
	var current := image.get_pixel(x, y)
	if current.a < 0.95:
		return
	var value := clampf(current.r * shade, 0.42, 1.16)
	image.set_pixel(x, y, Color(value, value, value, current.a))
