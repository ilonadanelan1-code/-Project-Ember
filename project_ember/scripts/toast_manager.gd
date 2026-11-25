extends Control
class_name ToastManager

const Palette = preload("res://scripts/art_palette.gd")
const MAX_TOASTS := 2
const DEFAULT_DURATION := 2.6

var _toasts: Array[Dictionary] = []


func _dp(value: float) -> float:
	var metrics := get_node_or_null("/root/UiMetrics")
	if is_instance_valid(metrics) and metrics.has_method("dp"):
		return float(metrics.call("dp", value))
	return value


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_toast(message: String, duration: float = DEFAULT_DURATION, icon_text: String = "•") -> void:
	if message.strip_edges().is_empty():
		return
	while _toasts.size() >= MAX_TOASTS:
		var oldest: Dictionary = _toasts.pop_front()
		var old_panel := oldest.get("panel") as Control
		if is_instance_valid(old_panel):
			old_panel.queue_free()

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.UI_BRONZE_DARK.r, Palette.UI_BRONZE_DARK.g, Palette.UI_BRONZE_DARK.b, 0.92)
	style.border_color = Palette.UI_GOLD
	style.set_border_width_all(int(_dp(1.5)))
	style.set_corner_radius_all(int(_dp(8.0)))
	style.content_margin_left = _dp(12.0)
	style.content_margin_right = _dp(12.0)
	style.content_margin_top = _dp(8.0)
	style.content_margin_bottom = _dp(8.0)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(_dp(8.0)))
	panel.add_child(row)
	var icon := Label.new()
	icon.text = icon_text
	icon.add_theme_font_size_override("font_size", int(_dp(18.0)))
	icon.add_theme_color_override("font_color", Palette.UI_GOLD)
	row.add_child(icon)
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", int(_dp(14.0)))
	label.add_theme_color_override("font_color", Palette.UI_TEXT)
	label.custom_minimum_size.x = _dp(180.0)
	row.add_child(label)
	add_child(panel)
	_toasts.append({"panel": panel, "remaining": maxf(0.5, duration)})
	_relayout()
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.12)


func _process(delta: float) -> void:
	for index in range(_toasts.size() - 1, -1, -1):
		var entry: Dictionary = _toasts[index]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			var panel := entry.get("panel") as Control
			if is_instance_valid(panel):
				panel.queue_free()
			_toasts.remove_at(index)
		else:
			_toasts[index] = entry
	_relayout()


func _relayout() -> void:
	for index in range(_toasts.size()):
		var panel := _toasts[index].get("panel") as Control
		if not is_instance_valid(panel):
			continue
		panel.anchor_left = 0.5
		panel.anchor_right = 0.5
		panel.anchor_top = 0.0
		panel.anchor_bottom = 0.0
		panel.offset_left = -_dp(160.0)
		panel.offset_right = _dp(160.0)
		var top := _dp(12.0 + float(index) * 64.0)
		panel.offset_top = top
		panel.offset_bottom = top + _dp(56.0)


func get_toast_count() -> int:
	return _toasts.size()
