extends RefCounted
class_name EmberWorldGenerator

const WORLD_RADIUS := 89
const WORLD_HEX_COUNT := 24031
const DEFAULT_SEED := 842173
const KINGDOM_COUNT := 9
const WORLD_GENERATION_VERSION := 3

static func kingdom_capital_cells() -> Array[Vector2i]:
	return [
		Vector2i(3, 0),
		Vector2i(54, -12),
		Vector2i(30, 42),
		Vector2i(-22, 57),
		Vector2i(-57, 8),
		Vector2i(-42, -30),
		Vector2i(15, -59),
		Vector2i(71, 17),
		Vector2i(-66, -21),
	]


static func is_inside_world(cell: Vector2i) -> bool:
	return hex_distance(Vector2i.ZERO, cell) <= WORLD_RADIUS


static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	return int((absi(a.x - b.x) + absi(a.y - b.y) + absi((a.x + a.y) - (b.x + b.y))) / 2)


static func terrain_at(
		cell: Vector2i,
		seed_value: int = DEFAULT_SEED,
		generation_version: int = WORLD_GENERATION_VERSION
) -> String:
	if not is_inside_world(cell):
		return "void"
	if generation_version < 2:
		return _legacy_terrain_at(cell, seed_value)
	if generation_version < 3:
		return _coherent_terrain_at(cell, seed_value)
	return _coherent_terrain_v3_at(cell, seed_value)


static func _legacy_terrain_at(cell: Vector2i, seed_value: int) -> String:
	# Version 1 is kept byte-for-byte in behaviour for campaigns created before
	# coherent biome generation was introduced.
	if absi(cell.y) <= 1 and absi(cell.x) <= 7:
		return "plain"
	for capital in kingdom_capital_cells():
		if hex_distance(cell, capital) <= 2:
			return "plain"
	var mixed: int = cell.x * 73856093 + cell.y * 19349663 + cell.x * cell.y * 83492791 + seed_value
	var value: int = posmod(mixed, 100)
	if value < 7:
		return "water"
	if value < 24:
		return "forest"
	if value < 38:
		return "hills"
	return "plain"


static func _coherent_terrain_at(cell: Vector2i, seed_value: int) -> String:
	# The opening route and all nine capital approaches stay traversable.
	if absi(cell.y) <= 1 and absi(cell.x) <= 7:
		return "plain"
	for capital in kingdom_capital_cells():
		if hex_distance(cell, capital) <= 2:
			return "plain"

	# A fixed starter basin gives the opening scouting area a visible shoreline
	# without blocking the capital corridor or the first army's movement route.
	if hex_distance(cell, Vector2i(-10, 4)) <= 2:
		return "water"

	# Low-frequency elevation builds continents and broad mountain ranges.
	# Medium/fine layers break up their edges without turning the map into noise.
	var elevation := (
		_noise_value(cell, seed_value, 24.0) * 0.70
		+ _noise_value(cell, seed_value + 13, 10.0) * 0.22
		+ _noise_value(cell, seed_value + 29, 4.0) * 0.08
	)
	var moisture := (
		_noise_value(cell, seed_value + 101, 20.0) * 0.70
		+ _noise_value(cell, seed_value + 207, 8.0) * 0.30
	)
	var field_signal := _noise_value(cell, seed_value + 503, 40.0)

	if elevation < 0.285:
		return "water"
	if elevation < 0.38 and moisture > 0.46:
		return "marsh"
	if elevation > 0.73:
		return "hills"
	if moisture > 0.60:
		return "forest"
	if elevation > 0.40 and elevation < 0.64 and moisture > 0.36 and moisture < 0.61 and field_signal > 0.52:
		return "farmland"
	return "plain"



static func _coherent_terrain_v3_at(cell: Vector2i, seed_value: int) -> String:
	# Keep the same capital corridor and starter lake so movement and city starts
	# remain compatible with the existing campaign layout.
	if absi(cell.y) <= 1 and absi(cell.x) <= 7:
		return "plain"
	for capital in kingdom_capital_cells():
		if hex_distance(cell, capital) <= 2:
			return "plain"
	if hex_distance(cell, Vector2i(-10, 4)) <= 2:
		return "water"

	var elevation := (
		_noise_value(cell, seed_value, 24.0) * 0.70
		+ _noise_value(cell, seed_value + 13, 10.0) * 0.22
		+ _noise_value(cell, seed_value + 29, 4.0) * 0.08
	)
	var moisture := (
		_noise_value(cell, seed_value + 101, 20.0) * 0.70
		+ _noise_value(cell, seed_value + 207, 8.0) * 0.30
	)
	var field_signal := _noise_value(cell, seed_value + 503, 40.0)

	# The opening region is deliberately less mountainous and more varied:
	# meadows, fields, forest belts, a few ridges, and the starter lake.
	# Beyond this radius the full world-scale thresholds remain unchanged.
	var start_distance := hex_distance(cell, Vector2i(-2, 0))
	if start_distance <= 16:
		if elevation < 0.27:
			return "water"
		if elevation < 0.38 and moisture > 0.65:
			return "marsh"
		if elevation > 0.79:
			return "hills"
		if moisture > 0.64:
			return "forest"
		if field_signal > 0.75 and elevation > 0.40 and elevation < 0.80:
			return "farmland"
		return "plain"

	if elevation < 0.285:
		return "water"
	if elevation < 0.38 and moisture > 0.46:
		return "marsh"
	if elevation > 0.73:
		return "hills"
	if moisture > 0.60:
		return "forest"
	if elevation > 0.40 and elevation < 0.64 and moisture > 0.36 and moisture < 0.61 and field_signal > 0.52:
		return "farmland"
	return "plain"


static func _noise_value(cell: Vector2i, seed_value: int, spacing: float) -> float:
	var sample_x := float(cell.x) / spacing
	var sample_y := float(cell.y) / spacing
	var x0 := floori(sample_x)
	var y0 := floori(sample_y)
	var blend_x := _smooth_curve(sample_x - float(x0))
	var blend_y := _smooth_curve(sample_y - float(y0))
	var top_left := _lattice_value(x0, y0, seed_value)
	var top_right := _lattice_value(x0 + 1, y0, seed_value)
	var bottom_left := _lattice_value(x0, y0 + 1, seed_value)
	var bottom_right := _lattice_value(x0 + 1, y0 + 1, seed_value)
	var top := lerpf(top_left, top_right, blend_x)
	var bottom := lerpf(bottom_left, bottom_right, blend_x)
	return lerpf(top, bottom, blend_y)


static func _lattice_value(x: int, y: int, seed_value: int) -> float:
	var mixed := (x * 374761393) ^ (y * 668265263) ^ (seed_value * 1442695041)
	return float(posmod(mixed, 2147483647)) / 2147483647.0


static func _smooth_curve(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


static func cell_to_array(cell: Vector2i) -> Array[int]:
	return [cell.x, cell.y]


static func encode_cell(cell: Vector2i) -> int:
	if not is_inside_world(cell):
		return -1
	var width := WORLD_RADIUS * 2 + 1
	return (cell.x + WORLD_RADIUS) * width + (cell.y + WORLD_RADIUS)


static func decode_cell(encoded: int) -> Vector2i:
	var width := WORLD_RADIUS * 2 + 1
	if encoded < 0 or encoded >= width * width:
		return Vector2i(9999, 9999)
	var q := floori(float(encoded) / float(width)) - WORLD_RADIUS
	var r := posmod(encoded, width) - WORLD_RADIUS
	var cell := Vector2i(q, r)
	return cell if is_inside_world(cell) else Vector2i(9999, 9999)


static func array_to_cell(value: Variant, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback


static func neighbors() -> Array[Vector2i]:
	return [
		Vector2i(1, 0),
		Vector2i(1, -1),
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
	]
