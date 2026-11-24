extends PanelContainer
class_name ConfirmDialog

signal confirmed
signal cancelled

var destructive_hold: bool = false
var hold_duration_seconds: float = 1.0
var _hold_timer: Timer
var _confirm_button: Button
var _title_label: Label
var _message_label: Label
var _confirm_label: String = "ПОДТВЕРДИТЬ"


func _dp(value: float) -> float:
	var metrics := get_node_or_null("/root/UiMetrics")
	if is_instance_valid(metrics) and metrics.has_method("dp"):
		return float(metrics.call("dp", value))
	return value


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -_dp(220.0)
	offset_top = -_dp(110.0)
	offset_right = _dp(220.0)
	offset_bottom = _dp(110.0)
	custom_minimum_size = Vector2(_dp(320.0), _dp(190.0))
	_build_contents()


func configure(title: String, message: String, confirm_text: String = "ПОДТВЕРДИТЬ", cancel_text: String = "ОТМЕНА", require_hold: bool = false) -> void:
	destructive_hold = require_hold
	_pending_title = title
	_pending_message = message
	_cancel_button_text = cancel_text
	_confirm_label = confirm_text
	_refresh_text()


var _pending_title: String = ""
var _pending_message: String = ""
var _cancel_button_text: String = "ОТМЕНА"
var _hold_elapsed: float = 0.0
var _hold_active: bool = false
var _hold_fill: ProgressBar
var _cancel_button: Button


func _build_contents() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(_dp(16.0)))
	margin.add_theme_constant_override("margin_right", int(_dp(16.0)))
	margin.add_theme_constant_override("margin_top", int(_dp(14.0)))
	margin.add_theme_constant_override("margin_bottom", int(_dp(14.0)))
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(_dp(8.0)))
	margin.add_child(column)
	_title_label = Label.new()
	_title_label.name = "DialogTitle"
	_title_label.text = _pending_title
	_title_label.add_theme_font_size_override("font_size", int(_dp(20.0)))
	column.add_child(_title_label)
	_message_label = Label.new()
	_message_label.name = "DialogMessage"
	_message_label.text = _pending_message
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", int(_dp(14.0)))
	column.add_child(_message_label)
	_hold_fill = ProgressBar.new()
	_hold_fill.min_value = 0.0
	_hold_fill.max_value = 1.0
	_hold_fill.value = 0.0
	_hold_fill.custom_minimum_size.y = _dp(8.0)
	_hold_fill.visible = false
	column.add_child(_hold_fill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_dp(8.0)))
	column.add_child(row)
	_cancel_button = Button.new()
	_cancel_button.text = _cancel_button_text
	_cancel_button.custom_minimum_size.y = _dp(48.0)
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.pressed.connect(cancel)
	row.add_child(_cancel_button)
	_confirm_button = Button.new()
	_confirm_button.text = _confirm_label
	_confirm_button.custom_minimum_size.y = _dp(48.0)
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.button_down.connect(_on_confirm_button_down)
	_confirm_button.button_up.connect(_on_confirm_button_up)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	row.add_child(_confirm_button)
	_hold_timer = Timer.new()
	_hold_timer.wait_time = 0.05
	_hold_timer.one_shot = false
	_hold_timer.timeout.connect(_update_hold)
	add_child(_hold_timer)
	_refresh_text()


func _refresh_text() -> void:
	if not is_instance_valid(_title_label):
		return
	_title_label.text = _pending_title
	_message_label.text = _pending_message
	_cancel_button.text = _cancel_button_text
	_confirm_button.text = _confirm_label
	_hold_fill.visible = destructive_hold
	_hold_fill.value = 0.0
	_hold_elapsed = 0.0


func open() -> void:
	_hold_elapsed = 0.0
	_hold_active = false
	_hold_fill.value = 0.0
	visible = true


func cancel() -> void:
	_cancel_hold()
	visible = false
	cancelled.emit()


func _on_confirm_button_down() -> void:
	if not visible:
		return
	if not destructive_hold:
		return
	_hold_elapsed = 0.0
	_hold_active = true
	_hold_timer.start()


func _on_confirm_button_up() -> void:
	_cancel_hold()


func _on_confirm_pressed() -> void:
	if not visible:
		return
	if destructive_hold and _hold_elapsed < hold_duration_seconds:
		return
	_cancel_hold()
	visible = false
	confirmed.emit()


func _update_hold() -> void:
	if not _hold_active:
		return
	_hold_elapsed += _hold_timer.wait_time
	_hold_fill.value = clampf(_hold_elapsed / hold_duration_seconds, 0.0, 1.0)
	if _hold_elapsed >= hold_duration_seconds:
		_cancel_hold()
		visible = false
		confirmed.emit()


func _cancel_hold() -> void:
	_hold_active = false
	if is_instance_valid(_hold_timer):
		_hold_timer.stop()
