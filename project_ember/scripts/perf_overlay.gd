extends CanvasLayer
class_name PerfOverlay

const UiThemeScript = preload("res://scripts/ui_theme.gd")
const Palette = preload("res://scripts/art_palette.gd")
const PerformanceReportScript = preload("res://scripts/performance_report.gd")

const SAMPLE_INTERVAL_SECONDS := 0.25
const REPORT_WINDOW_MS := 10000

var _label: Label
var _copy_button: Button
var _feedback_label: Label
var _elapsed: float = 0.0
var _sample_times: Array[int] = []
var _fps_samples: Array[float] = []
var _cpu_samples: Array[float] = []
var _feedback_until_ms: int = 0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

	var safe_area := SafeAreaContainer.new()
	add_child(safe_area)
	var root := safe_area.get_content_root()

	var panel := PanelContainer.new()
	panel.name = "PerformancePanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = UiMetrics.dp(4.0)
	panel.offset_top = UiMetrics.dp(4.0)
	panel.offset_right = UiMetrics.dp(390.0)
	panel.offset_bottom = UiMetrics.dp(188.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.theme = UiThemeScript.create_theme(GameSettings.ui_scale)
	root.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", int(UiMetrics.dp(4.0)))
	panel.add_child(layout)

	_label = Label.new()
	_label.name = "PerformanceMetrics"
	_label.add_theme_font_size_override("font_size", int(UiMetrics.dp(12.0)))
	_label.add_theme_color_override("font_color", Palette.UI_TEXT)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", int(UiMetrics.dp(8.0)))
	layout.add_child(actions)

	_copy_button = Button.new()
	_copy_button.name = "CopyPerformanceReport"
	_copy_button.text = "СКОПИРОВАТЬ ОТЧЁТ"
	_copy_button.custom_minimum_size = Vector2(UiMetrics.dp(190.0), UiMetrics.dp(36.0))
	_copy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy_button.add_theme_font_size_override("font_size", int(UiMetrics.dp(12.0)))
	_copy_button.pressed.connect(_copy_report)
	actions.add_child(_copy_button)

	_feedback_label = Label.new()
	_feedback_label.name = "CopyFeedback"
	_feedback_label.add_theme_font_size_override("font_size", int(UiMetrics.dp(10.0)))
	_feedback_label.add_theme_color_override("font_color", Color("#8BCF9A"))
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_feedback_label)

	visible = GameSettings.show_fps_overlay
	_record_sample()
	_update_text()


func _process(delta: float) -> void:
	visible = GameSettings.show_fps_overlay
	if not visible:
		return

	_elapsed += delta
	if _elapsed >= SAMPLE_INTERVAL_SECONDS:
		_elapsed = 0.0
		_record_sample()
		_update_text()

	if _feedback_until_ms > 0 and Time.get_ticks_msec() >= _feedback_until_ms:
		_feedback_label.text = ""
		_feedback_until_ms = 0


func _record_sample() -> void:
	var now := Time.get_ticks_msec()
	_sample_times.append(now)
	_fps_samples.append(float(Engine.get_frames_per_second()))
	_cpu_samples.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)

	while not _sample_times.is_empty() and now - _sample_times[0] > REPORT_WINDOW_MS:
		_sample_times.pop_front()
		_fps_samples.pop_front()
		_cpu_samples.pop_front()


func _update_text() -> void:
	if not is_instance_valid(_label):
		return

	var snapshot := _build_snapshot()
	_label.text = "FPS: %d · среднее за 10 с: %.1f · минимум: %.1f\nCPU: %.1f ms · Draw calls: %d\nОбъекты: %d · Примитивы: %d · Узлы: %d\nRAM: %s · GPU: %s\n%s" % [
		int(snapshot["fps_current"]),
		float(snapshot["fps_average"]),
		float(snapshot["fps_min"]),
		float(snapshot["cpu_current_ms"]),
		int(snapshot["draw_calls"]),
		int(snapshot["render_objects"]),
		int(snapshot["primitives"]),
		int(snapshot["node_count"]),
		PerformanceReportScript.format_bytes(int(snapshot["ram_static_bytes"])),
		PerformanceReportScript.format_bytes(int(snapshot["video_memory_bytes"])),
		str(snapshot["map_summary"]),
	]


func _copy_report() -> void:
	_record_sample()
	var report := PerformanceReportScript.build_report(_build_snapshot())
	DisplayServer.clipboard_set(report)
	_feedback_label.text = "Скопировано — вставь сюда"
	_feedback_until_ms = Time.get_ticks_msec() + 3500


func _build_snapshot() -> Dictionary:
	var fps_current := float(Engine.get_frames_per_second())
	var cpu_current_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var fps_average := _average(_fps_samples, fps_current)
	var fps_min := _minimum(_fps_samples, fps_current)
	var fps_max := _maximum(_fps_samples, fps_current)
	var cpu_average := _average(_cpu_samples, cpu_current_ms)
	var cpu_max := _maximum(_cpu_samples, cpu_current_ms)

	var map_available := false
	var viewport_cells := 0
	var tile_instances := 0
	var lod_chunk_size := 1
	var map_zoom := 0.0
	var map_summary := "Карта: нет активного рендерера"
	for map_renderer in get_tree().get_nodes_in_group("map_batch_renderer"):
		if not is_instance_valid(map_renderer):
			continue
		if not map_renderer.has_method("get_tile_instance_count"):
			continue
		map_available = true
		viewport_cells = int(map_renderer.call("get_source_cell_count"))
		tile_instances = int(map_renderer.call("get_tile_instance_count"))
		lod_chunk_size = int(map_renderer.call("get_lod_chunk_size"))
		if map_renderer.has_method("get_last_zoom"):
			map_zoom = float(map_renderer.call("get_last_zoom"))
		map_summary = "Карта: разведано %d · в окне %d · экземпляров %d · LOD %dx · zoom %.3f" % [
			int(CampaignState.get_explored_cell_count()),
			viewport_cells,
			tile_instances,
			lod_chunk_size,
			map_zoom,
		]
		break

	var engine_version: Dictionary = Engine.get_version_info()
	var version_line := "Project Ember"
	var version_file := FileAccess.open("res://VERSION.txt", FileAccess.READ)
	if version_file != null:
		version_line = version_file.get_line().strip_edges()
		version_file.close()

	return {
		"build": version_line,
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"godot_version": str(engine_version.get("string", "unknown")),
		"platform": OS.get_name(),
		"os_version": OS.get_version(),
		"viewport": get_viewport_rect().size.round(),
		"fps_current": fps_current,
		"fps_average": fps_average,
		"fps_min": fps_min,
		"fps_max": fps_max,
		"sample_count": _fps_samples.size(),
		"cpu_current_ms": cpu_current_ms,
		"cpu_average_ms": cpu_average,
		"cpu_max_ms": cpu_max,
		"draw_calls": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
		"render_objects": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)),
		"primitives": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"ram_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"video_memory_bytes": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)),
		"map_available": map_available,
		"map_summary": map_summary,
		"viewport_cells": viewport_cells,
		"tile_instances": tile_instances,
		"lod_chunk_size": lod_chunk_size,
		"map_zoom": map_zoom,
	}


func _average(values: Array[float], fallback: float) -> float:
	if values.is_empty():
		return fallback
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _minimum(values: Array[float], fallback: float) -> float:
	if values.is_empty():
		return fallback
	var result := values[0]
	for value in values:
		result = minf(result, value)
	return result


func _maximum(values: Array[float], fallback: float) -> float:
	if values.is_empty():
		return fallback
	var result := values[0]
	for value in values:
		result = maxf(result, value)
	return result
