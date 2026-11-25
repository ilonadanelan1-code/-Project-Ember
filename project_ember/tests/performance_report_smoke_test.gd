extends SceneTree

const PerformanceReportScript = preload("res://scripts/performance_report.gd")


func _initialize() -> void:
	var report := PerformanceReportScript.build_report({
		"build": "Project Ember test build",
		"timestamp": "2026-11-24 12:00:00",
		"godot_version": "4.3.stable",
		"platform": "Android",
		"os_version": "Android test",
		"viewport": Vector2i(2400, 1080),
		"fps_current": 58.0,
		"fps_average": 55.5,
		"fps_min": 42.0,
		"fps_max": 60.0,
		"sample_count": 40,
		"cpu_current_ms": 8.0,
		"cpu_average_ms": 9.2,
		"cpu_max_ms": 14.0,
		"draw_calls": 12,
		"render_objects": 100,
		"primitives": 5000,
		"node_count": 250,
		"ram_static_bytes": 104857600,
		"video_memory_bytes": 52428800,
		"map_available": true,
		"map_summary": "Map: explored 900 | viewport 120 | instances 24 | LOD 6x | zoom 0.15",
	})

	var required_fragments := [
		"PROJECT EMBER — PERFORMANCE REPORT",
		"FPS current / avg / min / max (10s): 58.0 / 55.5 / 42.0 / 60.0",
		"CPU process ms current / avg / max: 8.00 / 9.20 / 14.00",
		"draw calls 12",
		"RAM static: 100.0 MB",
		"video memory: 50.0 MB",
		"LOD 6x",
	]

	for fragment in required_fragments:
		if not report.contains(fragment):
			push_error("Performance report is missing: %s" % fragment)
			quit(1)
			return

	if report.contains("@gmail.com") or report.contains("token="):
		push_error("Performance report must not contain account secrets or personal email.")
		quit(1)
		return

	print("All performance report smoke tests passed.")
	quit()
