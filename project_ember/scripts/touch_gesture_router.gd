extends Node
class_name TouchGestureRouter

signal tap(position: Vector2)
signal double_tap(position: Vector2)
signal long_press(position: Vector2)
signal drag_started(position: Vector2)
signal drag(position: Vector2, delta: Vector2)
signal drag_ended(delta: Vector2)
signal pinch(scale_factor: float, center: Vector2)
signal two_finger_pan(delta: Vector2)

enum GestureState { IDLE, PRESS, TAP, LONG_PRESS, DRAG, PINCH }

const TAP_MAX_MSEC := 250
const LONG_PRESS_MSEC := 400
const DOUBLE_TAP_MSEC := 300
const DOUBLE_TAP_DISTANCE_DP := 24.0
const DRAG_THRESHOLD_DP := 10.0

@export var process_mouse_in_editor: bool = true
@export var consume_mouse_events: bool = false

var gesture_state: GestureState = GestureState.IDLE
var ui_root: Control
var _active_touches: Dictionary = {}
var _primary_index: int = -999
var _press_started_msec: int = 0
var _pinch_distance: float = 0.0
var _pinch_center: Vector2 = Vector2.ZERO
var _last_drag_delta: Vector2 = Vector2.ZERO
var _suppressed_until_all_released: bool = false
var _last_raw_touch_msec: int = -10000
var _last_raw_touch_over_ui: bool = false
var _pending_tap: bool = false
var _pending_tap_position: Vector2 = Vector2.ZERO
var _pending_tap_msec: int = -10000


func _dp(value: float) -> float:
	var metrics := get_node_or_null("/root/UiMetrics")
	if is_instance_valid(metrics) and metrics.has_method("dp"):
		return float(metrics.call("dp", value))
	return value


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		handle_touch_event(event)
	elif OS.has_feature("mobile") and consume_mouse_events and event is InputEventMouse:
		# Godot can synthesize mouse events from a raw touch. Suppress that
		# second world event only when the original touch began outside the UI.
		if Time.get_ticks_msec() - _last_raw_touch_msec <= DOUBLE_TAP_MSEC and not _last_raw_touch_over_ui:
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if OS.has_feature("mobile") or not process_mouse_in_editor:
		return
	if Time.get_ticks_msec() - _last_raw_touch_msec <= DOUBLE_TAP_MSEC:
		if consume_mouse_events and event is InputEventMouse:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_pointer(-1, event.position, _is_ui_position(event.position))
		else:
			_finish_pointer(-1, event.position)
	elif event is InputEventMouseMotion and _active_touches.has(-1):
		_move_pointer(-1, event.position)
	if consume_mouse_events and event is InputEventMouse:
		get_viewport().set_input_as_handled()


func set_ui_root(control: Control) -> void:
	ui_root = control


func handle_touch_event(event: InputEvent) -> void:
	_last_raw_touch_msec = Time.get_ticks_msec()
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_last_raw_touch_over_ui = _is_ui_position(touch.position)
			_start_pointer(touch.index, touch.position, _last_raw_touch_over_ui)
		else:
			_finish_pointer(touch.index, touch.position)
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		_move_pointer(drag_event.index, drag_event.position)


func is_pointer_over_ui(position: Vector2) -> bool:
	return _is_ui_position(position)


func _start_pointer(index: int, position: Vector2, over_ui: bool) -> void:
	if _active_touches.has(index):
		return
	_active_touches[index] = {
		"start": position,
		"position": position,
		"ui": over_ui,
		"started_msec": Time.get_ticks_msec(),
	}
	if _active_touches.size() >= 2:
		_pending_tap = false
		gesture_state = GestureState.PINCH
		_primary_index = -999
		_suppressed_until_all_released = true
		var positions := _get_world_positions()
		if positions.size() >= 2:
			_pinch_distance = positions[0].distance_to(positions[1])
			_pinch_center = (positions[0] + positions[1]) * 0.5
		else:
			_pinch_distance = 0.0
			_pinch_center = Vector2.ZERO
		return
	if over_ui or _suppressed_until_all_released:
		return
	_primary_index = index
	_press_started_msec = Time.get_ticks_msec()
	_last_drag_delta = Vector2.ZERO
	gesture_state = GestureState.PRESS


func _move_pointer(index: int, position: Vector2) -> void:
	if not _active_touches.has(index):
		return
	var entry: Dictionary = _active_touches[index]
	var previous: Vector2 = entry.get("position", position)
	entry["position"] = position
	_active_touches[index] = entry
	if gesture_state == GestureState.PINCH:
		_update_pinch()
		return
	if bool(entry.get("ui", false)) or _suppressed_until_all_released or index != _primary_index:
		return
	var start: Vector2 = entry.get("start", position)
	if (gesture_state == GestureState.PRESS or gesture_state == GestureState.LONG_PRESS) and position.distance_to(start) >= _dp(DRAG_THRESHOLD_DP):
		gesture_state = GestureState.DRAG
		drag_started.emit(start)
	var frame_delta := position - previous
	if gesture_state == GestureState.DRAG:
		_last_drag_delta = frame_delta
		drag.emit(position, frame_delta)


func _finish_pointer(index: int, position: Vector2) -> void:
	if not _active_touches.has(index):
		return
	var entry: Dictionary = _active_touches[index]
	entry["position"] = position
	_active_touches[index] = entry
	var was_ui := bool(entry.get("ui", false))
	var was_pinching := gesture_state == GestureState.PINCH
	var was_primary := index == _primary_index
	if not was_ui and not _suppressed_until_all_released and not was_pinching and was_primary:
		var start: Vector2 = entry.get("start", position)
		var elapsed := Time.get_ticks_msec() - int(entry.get("started_msec", _press_started_msec))
		var moved := position.distance_to(start)
		if gesture_state == GestureState.PRESS and elapsed <= TAP_MAX_MSEC and moved < _dp(DRAG_THRESHOLD_DP):
			_emit_tap(position)
		elif gesture_state == GestureState.DRAG:
			drag_ended.emit(_last_drag_delta)
	_active_touches.erase(index)
	if was_pinching:
		if _active_touches.is_empty():
			gesture_state = GestureState.IDLE
			_suppressed_until_all_released = false
			_primary_index = -999
		else:
			_suppressed_until_all_released = true
		return
	if index == _primary_index:
		_primary_index = -999
	if _active_touches.is_empty():
		gesture_state = GestureState.IDLE
		_suppressed_until_all_released = false


func _emit_tap(position: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if _pending_tap and now - _pending_tap_msec <= DOUBLE_TAP_MSEC and position.distance_to(_pending_tap_position) <= _dp(DOUBLE_TAP_DISTANCE_DP):
		_pending_tap = false
		gesture_state = GestureState.TAP
		double_tap.emit(position)
		return
	if _pending_tap:
		tap.emit(_pending_tap_position)
	_pending_tap = true
	_pending_tap_position = position
	_pending_tap_msec = now
	gesture_state = GestureState.TAP


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _pending_tap and now - _pending_tap_msec > DOUBLE_TAP_MSEC:
		_pending_tap = false
		tap.emit(_pending_tap_position)
	if _primary_index == -999 or not _active_touches.has(_primary_index) or gesture_state != GestureState.PRESS:
		return
	var entry: Dictionary = _active_touches[_primary_index]
	if bool(entry.get("ui", false)):
		return
	var elapsed := Time.get_ticks_msec() - int(entry.get("started_msec", _press_started_msec))
	var position: Vector2 = entry.get("position", Vector2.ZERO)
	var start: Vector2 = entry.get("start", position)
	if elapsed >= LONG_PRESS_MSEC and position.distance_to(start) < _dp(DRAG_THRESHOLD_DP):
		gesture_state = GestureState.LONG_PRESS
		long_press.emit(position)


func _update_pinch() -> void:
	var positions := _get_world_positions()
	if positions.size() < 2:
		return
	var next_distance := positions[0].distance_to(positions[1])
	var next_center := (positions[0] + positions[1]) * 0.5
	if _pinch_distance > 0.001 and next_distance > 0.001:
		pinch.emit(next_distance / _pinch_distance, next_center)
	if _pinch_center != Vector2.ZERO:
		two_finger_pan.emit(next_center - _pinch_center)
	_pinch_distance = next_distance
	_pinch_center = next_center


func _get_world_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for value in _active_touches.values():
		var entry: Dictionary = value
		if not bool(entry.get("ui", false)):
			positions.append(entry.get("position", Vector2.ZERO))
	return positions


func _is_ui_position(position: Vector2) -> bool:
	return is_instance_valid(ui_root) and _control_tree_hits(ui_root, position)


func _control_tree_hits(node: Node, position: Vector2) -> bool:
	if node is Control:
		var control := node as Control
		if control.is_visible_in_tree() and control.mouse_filter != Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(position) and control.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true
	for child in node.get_children():
		if _control_tree_hits(child, position):
			return true
	return false


func get_active_touch_count() -> int:
	return _active_touches.size()


func reset_gesture_state() -> void:
	_active_touches.clear()
	_primary_index = -999
	gesture_state = GestureState.IDLE
	_suppressed_until_all_released = false
	_pending_tap = false
	_last_raw_touch_over_ui = false
	_pinch_distance = 0.0
	_pinch_center = Vector2.ZERO
