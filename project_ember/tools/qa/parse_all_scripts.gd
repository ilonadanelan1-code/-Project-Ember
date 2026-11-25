extends Node

const SCAN_ROOTS: Array[String] = [
	"res://scripts",
	"res://tests",
	"res://tools/qa",
]

var _checked: int = 0
var _failed: Array[String] = []


func _ready() -> void:
	var script_paths: Array[String] = []
	for folder in SCAN_ROOTS:
		_collect_scripts(folder, script_paths)
	script_paths.sort()

	for path in script_paths:
		var loaded: Resource = ResourceLoader.load(path, "GDScript")
		if loaded is GDScript:
			_checked += 1
			print("PASS parser ", path)
		else:
			_failed.append(path)
			push_error("GDScript parser failed: " + path)

	print("GDScript parser: %d checked / %d failed" % [_checked, _failed.size()])
	get_tree().quit(1 if not _failed.is_empty() else 0)


func _collect_scripts(folder: String, output: Array[String]) -> void:
	var directory := DirAccess.open(folder)
	if directory == null:
		_failed.append(folder)
		push_error("Could not scan GDScript folder: " + folder)
		return

	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if directory.current_is_dir():
			if not entry.begins_with("."):
				_collect_scripts(folder.path_join(entry), output)
		elif entry.ends_with(".gd"):
			output.append(folder.path_join(entry))
		entry = directory.get_next()
	directory.list_dir_end()
