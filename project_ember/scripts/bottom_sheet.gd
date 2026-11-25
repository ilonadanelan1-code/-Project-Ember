extends PanelContainer
class_name BottomSheet

signal closed

var _is_open: bool = false
var _drag_start_y: float = 0.0
var _content: Control


func _dp(value: float) -> float:
	var metrics := get_node_or_null("/root/UiMetrics")
	if is_instance_valid(metrics) and metrics.has_method("dp"):
		return float(metrics.call("dp", value))
	return value


func _ready() -> void:
	anchor_left = 0.02
	anchor_right = 0.98
	anchor_top = 0.28
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = -_dp(12.0)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_content)


func set_sheet_content(control: Control) -> void:
	for child in _content.get_children():
		child.queue_free()
	if is_instance_valid(control):
		_content.add_child(control)


func open() -> void:
	visible = true
	_is_open = true
	var tween := create_tween()
	tween.tween_property(self, "offset_top", -_dp(8.0), 0.18)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_drag_start_y = event.position.y
		elif event.position.y - _drag_start_y > _dp(72.0):
			close()
