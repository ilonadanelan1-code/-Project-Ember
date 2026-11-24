extends Node2D
class_name HexMapBatchRenderer

## One batched MultiMesh draws every visible strategic hex.
## No per-cell CanvasItem draw calls or scene nodes are created.

const TEXTURE_WIDTH := 64
const TEXTURE_HEIGHT := 72

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
	_multimesh.mesh = _quad
	_multimesh.instance_count = 0

	_instance = MultiMeshInstance2D.new()
	_instance.name = "BatchedHexes"
	_instance.multimesh = _multimesh
	_instance.texture = _make_hex_texture()
	_instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_instance)


func _draw() -> void:
	# The empty world is the unexplored fog layer. Discovered tiles are drawn
	# above this solid backdrop, so no hidden terrain data is exposed.
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#111710"), true)


func set_map_tiles(
		cells: Array[Vector2i],
		centers: PackedVector2Array,
		colors: PackedColorArray,
		tile_size: Vector2,
		zoom: float
) -> void:
	var source_count := mini(cells.size(), mini(centers.size(), colors.size()))
	_last_source_cell_count = source_count
	var chunk_size := 1
	if zoom <= 0.22:
		chunk_size = 6
	if chunk_size == 1:
		var direct_centers := PackedVector2Array()
		var direct_colors := PackedColorArray()
		direct_centers.resize(source_count)
		direct_colors.resize(source_count)
		for index in range(source_count):
			direct_centers[index] = centers[index]
			direct_colors[index] = colors[index]
		_last_lod_chunk_size = 1
		set_tiles(direct_centers, direct_colors, tile_size, zoom)
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
	for bucket_value in buckets.values():
		var bucket: Dictionary = bucket_value
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

	_last_lod_chunk_size = chunk_size
	set_tiles(lod_centers, lod_colors, tile_size * float(chunk_size), zoom)


func set_tiles(centers: PackedVector2Array, colors: PackedColorArray, tile_size: Vector2, zoom: float) -> void:
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


func _make_hex_texture() -> ImageTexture:
	var image := Image.create(TEXTURE_WIDTH, TEXTURE_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
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

	for y in range(TEXTURE_HEIGHT):
		for x in range(TEXTURE_WIDTH):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			var in_hex := Geometry2D.is_point_in_polygon(point, polygon)
			var in_shadow := Geometry2D.is_point_in_polygon(point, shadow_polygon)
			if not in_hex:
				if in_shadow:
					image.set_pixel(x, y, Color(0.28, 0.31, 0.28, 0.42))
				continue
			var edge_distance := 999.0
			for edge_index in range(polygon.size()):
				var a := polygon[edge_index]
				var b := polygon[(edge_index + 1) % polygon.size()]
				edge_distance = minf(edge_distance, Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point))
			if edge_distance < 2.0:
				image.set_pixel(x, y, Color(0.54, 0.58, 0.52, 1.0))
			elif point.y < 13.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 0.96, 1.0))
			else:
				image.set_pixel(x, y, Color.WHITE)

	_hex_texture = ImageTexture.create_from_image(image)
	return _hex_texture
