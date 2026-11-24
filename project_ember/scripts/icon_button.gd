extends Button
class_name IconButton

@export var icon_path: String = ""
@export var fallback_icon: String = "•"
@export var label_text: String = ""
@export_range(48.0, 96.0, 1.0) var touch_size_dp: float = 48.0


func _ready() -> void:
	custom_minimum_size = Vector2(maxf(custom_minimum_size.x, UiMetrics.dp(touch_size_dp)), maxf(custom_minimum_size.y, UiMetrics.dp(touch_size_dp)))
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	if icon_path.begins_with("res://") and ResourceLoader.exists(icon_path):
		var icon_resource := load(icon_path)
		if icon_resource is Texture2D:
			icon = icon_resource
			icon_max_width = int(UiMetrics.dp(26.0))
	if icon == null:
		text = (fallback_icon + "  " + label_text).strip_edges()
	else:
		text = label_text
	add_theme_font_size_override("font_size", int(UiMetrics.dp(14.0)))
