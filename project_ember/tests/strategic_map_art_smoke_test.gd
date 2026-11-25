extends SceneTree

const MapDetailsScript = preload("res://scripts/strategic_map_details.gd")
const WorldScript = preload("res://scripts/world_generator.gd")

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
	var start := Vector2i(-9, 3)
	var finish := Vector2i(4, -8)
	var route := MapDetailsScript.axial_line(start, finish)
	var expected_distance := MapDetailsScript.axial_distance(start, finish)
	_check(route.size() == expected_distance + 1, "axial road route contains one cell per hex step")
	_check(not route.is_empty() and route[0] == start and route[route.size() - 1] == finish, "axial road route preserves both city endpoints")
	var route_is_contiguous := true
	for index in range(1, route.size()):
		if WorldScript.hex_distance(route[index - 1], route[index]) != 1:
			route_is_contiguous = false
	_check(route_is_contiguous, "road route advances only through adjacent hexes")
	_check(MapDetailsScript.axial_line(start, start) == [start], "road route safely handles a city connected to itself")

	var seed_value := 842173
	var sample_cell := Vector2i(-17, 23)
	_check(
		MapDetailsScript.landmark_roll(sample_cell, seed_value) == MapDetailsScript.landmark_roll(sample_cell, seed_value),
		"natural landmark placement is stable for a fixed world seed"
	)
	_check(
		MapDetailsScript.landmark_roll(sample_cell, seed_value) != MapDetailsScript.landmark_roll(sample_cell, seed_value + 1),
		"natural landmark placement responds to a different world seed"
	)

	var expected_features := {
		"hills": "peak",
		"forest": "elder_tree",
		"water": "islet",
		"plain": "standing_stone",
	}
	for terrain_kind in expected_features:
		var found_feature := false
		for q in range(-35, 36):
			for r in range(-35, 36):
				if MapDetailsScript.landmark_kind(Vector2i(q, r), terrain_kind, seed_value) == str(expected_features[terrain_kind]):
					found_feature = true
					break
			if found_feature:
				break
		_check(found_feature, "%s terrain has a deterministic natural landmark variant" % terrain_kind)
	_check(MapDetailsScript.landmark_kind(sample_cell, "void", seed_value).is_empty(), "unknown terrain never receives a natural landmark")
	_check(MapDetailsScript.should_show_city_labels(0.72), "city labels activate at readable strategic zoom")
	_check(not MapDetailsScript.should_show_city_labels(0.71), "city labels stay hidden when the map is too distant")

	if _failures > 0:
		printerr("Strategic map art tests failed: %d" % _failures)
		quit(1)
	else:
		print("All strategic map art smoke tests passed.")
		quit(0)
