extends RefCounted
class_name StrategicMapDetails
## Deterministic cartographic helpers for the strategic map.
## No campaign state is written; roads and natural landmarks are derived at draw time.


static func axial_distance(start_cell: Vector2i, end_cell: Vector2i) -> int:
	var delta := end_cell - start_cell
	return maxi(absi(delta.x), maxi(absi(delta.y), absi(delta.x + delta.y)))


static func axial_line(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var distance := axial_distance(start_cell, end_cell)
	if distance <= 0:
		result.append(start_cell)
		return result

	var start_q := float(start_cell.x)
	var start_r := float(start_cell.y)
	var start_s := -start_q - start_r
	var end_q := float(end_cell.x)
	var end_r := float(end_cell.y)
	var end_s := -end_q - end_r

	for step in range(distance + 1):
		var weight := float(step) / float(distance)
		var q := lerpf(start_q, end_q, weight)
		var r := lerpf(start_r, end_r, weight)
		var s := lerpf(start_s, end_s, weight)
		var rounded_q := roundi(q)
		var rounded_r := roundi(r)
		var rounded_s := roundi(s)
		var q_error := absf(float(rounded_q) - q)
		var r_error := absf(float(rounded_r) - r)
		var s_error := absf(float(rounded_s) - s)
		if q_error >= r_error and q_error >= s_error:
			rounded_q = -rounded_r - rounded_s
		elif r_error >= s_error:
			rounded_r = -rounded_q - rounded_s
		else:
			rounded_s = -rounded_q - rounded_r
		var cell := Vector2i(rounded_q, rounded_r)
		if result.is_empty() or result[result.size() - 1] != cell:
			result.append(cell)
	return result


static func landmark_roll(cell: Vector2i, world_seed: int) -> int:
	var mixed := (cell.x * 374761393) ^ (cell.y * 668265263) ^ (world_seed * 1442695041)
	return posmod(mixed, 2147483647)


static func landmark_kind(cell: Vector2i, terrain_kind: String, world_seed: int) -> String:
	var roll := landmark_roll(cell, world_seed)
	match terrain_kind:
		"hills":
			return "peak" if roll % 31 == 0 else ""
		"forest":
			return "elder_tree" if roll % 37 == 0 else ""
		"water":
			return "islet" if roll % 47 == 0 else ""
		"plain":
			return "standing_stone" if roll % 53 == 0 else ""
		_:
			return ""



static func should_show_city_labels(zoom: float) -> bool:
	return zoom >= 0.72
