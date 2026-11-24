extends Node
class_name UiMetricsService

signal metrics_changed

const DEFAULT_DPI := 160.0
const MIN_DPI := 120.0
const MAX_DPI := 640.0

var real_px_per_dp: float = 1.0
var ref_px_per_real: float = 1.0
var ref_px_per_dp: float = 1.0
var _last_signature: String = ""


func _ready() -> void:
	var window := get_window()
	if is_instance_valid(window):
		if not window.size_changed.is_connected(refresh_metrics):
			window.size_changed.connect(refresh_metrics)
	var viewport := get_viewport()
	if is_instance_valid(viewport) and not viewport.size_changed.is_connected(refresh_metrics):
		viewport.size_changed.connect(refresh_metrics)
	if has_node("/root/GameSettings"):
		var settings := get_node("/root/GameSettings")
		if settings.has_signal("settings_changed") and not settings.settings_changed.is_connected(refresh_metrics):
			settings.settings_changed.connect(refresh_metrics)
	refresh_metrics()


func refresh_metrics() -> void:
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		dpi = DEFAULT_DPI
	var viewport_size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		window_size = Vector2(DisplayServer.screen_get_size())
	var scale := 1.0
	if has_node("/root/GameSettings"):
		scale = clampf(float(get_node("/root/GameSettings").get("ui_scale")), 0.8, 1.6)
	var ratio := viewport_size.x / window_size.x if viewport_size.x > 0.0 and window_size.x > 0.0 else 1.0
	_set_metrics(dpi, ratio, scale)


func configure_for_test(dpi: float, viewport_width: float, window_width: float, ui_scale: float = 1.0) -> void:
	var ratio := viewport_width / window_width if viewport_width > 0.0 and window_width > 0.0 else 1.0
	_set_metrics(dpi, ratio, ui_scale)


func _set_metrics(dpi: float, real_to_viewport_ratio: float, ui_scale: float) -> void:
	var safe_dpi := DEFAULT_DPI if dpi <= 0.0 else clampf(dpi, MIN_DPI, MAX_DPI)
	real_px_per_dp = safe_dpi / 160.0
	ref_px_per_real = maxf(real_to_viewport_ratio, 0.01)
	ref_px_per_dp = real_px_per_dp * ref_px_per_real * clampf(ui_scale, 0.8, 1.6)
	var signature := "%.5f:%.5f:%.5f" % [real_px_per_dp, ref_px_per_real, ref_px_per_dp]
	if signature == _last_signature:
		return
	_last_signature = signature
	metrics_changed.emit()


func dp(value: float) -> float:
	return value * ref_px_per_dp


func dp_vector(value: Vector2) -> Vector2:
	return value * ref_px_per_dp


func px_to_dp(value: float) -> float:
	return value / maxf(ref_px_per_dp, 0.001)


func get_viewport_to_window_scale() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return Vector2.ONE
	return Vector2(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
