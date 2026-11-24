extends Control
class_name SafeAreaContainer

@export_range(0.0, 64.0, 1.0) var horizontal_padding_dp: float = 24.0
@export_range(0.0, 64.0, 1.0) var top_padding_dp: float = 12.0
@export_range(0.0, 64.0, 1.0) var bottom_padding_dp: float = 16.0

var content_root: Control
var _window: Window


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root = Control.new()
	content_root.name = "SafeContent"
	content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_root)
	_window = get_window()
	if is_instance_valid(_window) and not _window.size_changed.is_connected(refresh_safe_area):
		_window.size_changed.connect(refresh_safe_area)
	var viewport := get_viewport()
	if is_instance_valid(viewport) and not viewport.size_changed.is_connected(refresh_safe_area):
		viewport.size_changed.connect(refresh_safe_area)
	if has_node("/root/UiMetrics"):
		var metrics := get_node("/root/UiMetrics")
		if not metrics.metrics_changed.is_connected(refresh_safe_area):
			metrics.metrics_changed.connect(refresh_safe_area)
	refresh_safe_area()


func get_content_root() -> Control:
	return content_root


func refresh_safe_area() -> void:
	if not is_instance_valid(content_root):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		window_size = Vector2(DisplayServer.screen_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		window_size = viewport_size

	var window_position := DisplayServer.window_get_position()
	var safe_rect := DisplayServer.get_display_safe_area()
	var insets := Vector4.ZERO
	if safe_rect.size.x > 0 and safe_rect.size.y > 0:
		var window_left := window_position.x
		var window_top := window_position.y
		var window_right := window_left + int(window_size.x)
		var window_bottom := window_top + int(window_size.y)
		var safe_left := maxi(window_left, safe_rect.position.x)
		var safe_top := maxi(window_top, safe_rect.position.y)
		var safe_right := mini(window_right, safe_rect.position.x + safe_rect.size.x)
		var safe_bottom := mini(window_bottom, safe_rect.position.y + safe_rect.size.y)
		if safe_right > safe_left and safe_bottom > safe_top:
			insets = Vector4(
				float(safe_left - window_left),
				float(safe_top - window_top),
				float(window_right - safe_right),
				float(window_bottom - safe_bottom)
			)

	var scale_x := viewport_size.x / window_size.x
	var scale_y := viewport_size.y / window_size.y
	var base_horizontal := UiMetrics.dp(horizontal_padding_dp)
	var base_top := UiMetrics.dp(top_padding_dp)
	var base_bottom := UiMetrics.dp(bottom_padding_dp)
	content_root.offset_left = insets.x * scale_x + base_horizontal
	content_root.offset_top = insets.y * scale_y + base_top
	content_root.offset_right = -(insets.z * scale_x + base_horizontal)
	content_root.offset_bottom = -(insets.w * scale_y + base_bottom)
