extends RefCounted
class_name PerformanceReport


static func build_report(snapshot: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("PROJECT EMBER — PERFORMANCE REPORT")
	lines.append("Build: %s" % str(snapshot.get("build", "unknown")))
	lines.append("Captured: %s" % str(snapshot.get("timestamp", "unknown")))
	lines.append("Engine: Godot %s" % str(snapshot.get("godot_version", "unknown")))
	lines.append("Platform: %s | OS: %s" % [
		str(snapshot.get("platform", "unknown")),
		str(snapshot.get("os_version", "unknown")),
	])

	var viewport: Vector2i = snapshot.get("viewport", Vector2i.ZERO)
	lines.append("Viewport: %d x %d" % [viewport.x, viewport.y])
	lines.append("FPS current / avg / min / max (10s): %.1f / %.1f / %.1f / %.1f" % [
		float(snapshot.get("fps_current", 0.0)),
		float(snapshot.get("fps_average", 0.0)),
		float(snapshot.get("fps_min", 0.0)),
		float(snapshot.get("fps_max", 0.0)),
	])
	lines.append("Samples in 10s window: %d" % int(snapshot.get("sample_count", 0)))
	lines.append("CPU process ms current / avg / max: %.2f / %.2f / %.2f" % [
		float(snapshot.get("cpu_current_ms", 0.0)),
		float(snapshot.get("cpu_average_ms", 0.0)),
		float(snapshot.get("cpu_max_ms", 0.0)),
	])
	lines.append("Rendering: draw calls %d | objects %d | primitives %d" % [
		int(snapshot.get("draw_calls", 0)),
		int(snapshot.get("render_objects", 0)),
		int(snapshot.get("primitives", 0)),
	])
	lines.append("Scene nodes: %d" % int(snapshot.get("node_count", 0)))
	lines.append("RAM static: %s | video memory: %s" % [
		format_bytes(int(snapshot.get("ram_static_bytes", 0))),
		format_bytes(int(snapshot.get("video_memory_bytes", 0))),
	])

	if bool(snapshot.get("map_available", false)):
		lines.append(str(snapshot.get("map_summary", "Map: available")))
	else:
		lines.append("Map: no active strategic map renderer")

	lines.append("Note: capture was taken in-game; FPS/CPU are sampled over the last 10 seconds.")
	return "\n".join(lines) + "\n"


static func format_bytes(byte_count: int) -> String:
	if byte_count <= 0:
		return "n/a"
	return "%.1f MB" % (float(byte_count) / 1048576.0)
