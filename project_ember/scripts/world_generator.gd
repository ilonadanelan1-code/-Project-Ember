extends RefCounted
class_name EmberWorldGenerator

const WORLD_RADIUS := 89
const WORLD_HEX_COUNT := 24031
const DEFAULT_SEED := 842173
const KINGDOM_COUNT := 9

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


static func terrain_at(cell: Vector2i, seed_value: int = DEFAULT_SEED) -> String:
	if not is_inside_world(cell):
		return "void"
	# Keep the starting corridor and all capital approaches accessible.
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
