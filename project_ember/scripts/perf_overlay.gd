extends CanvasLayer
class_name PerfOverlay
const UiThemeScript = preload("res://scripts/ui_theme.gd")
const Palette = preload("res://scripts/art_palette.gd")

var _label: Label
var _elapsed: float = 0.0
func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 10.0
	panel.offset_top = 10.0
	panel.offset_right = 365.0
	panel.offset_bottom = 126.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme = UiThemeScript.create_theme(0.85)
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	_label.add_theme_color_override("font_color", Palette.UI_TEXT)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_label)
	visible = GameSettings.show_fps_overlay
	_update_text()
func _process(delta: float) -> void:
	visible = GameSettings.show_fps_overlay
	if not visible:
		return
	_elapsed += delta
	if _elapsed < 0.25:
		return
	_elapsed = 0.0
	_update_text()
func _update_text() -> void:
	if not is_instance_valid(_label):
		return
	var fps := Engine.get_frames_per_second()
	var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var primitives := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var video_memory := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	var static_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_label.text = "FPS: %d · Draw calls: %d\nОбъекты: %d · Примитивы: %d\nУзлы: %d · RAM: %s · GPU: %s" % [
		fps, draw_calls, objects, primitives, node_count,
		"—" if static_memory <= 0.0 else "%.1f MB" % (float(static_memory) / 1048576.0),
		"—" if video_memory <= 0 else "%.1f MB" % (float(video_memory) / 1048576.0),
	]
