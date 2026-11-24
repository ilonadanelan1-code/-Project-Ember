extends SceneTree

const RouterScript = preload("res://scripts/touch_gesture_router.gd")
const UiMetricsScript = preload("res://scripts/ui_metrics.gd")
const GameSettingsScript = preload("res://scripts/game_settings.gd")

var _failures := 0
var _tap_count := 0
var _double_tap_count := 0
var _long_press_count := 0
var _drag_started_count := 0
var _drag_ended_count := 0
var _pinch_count := 0
var _two_finger_pan_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _touch(router: Node, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	router.handle_touch_event(event)


func _drag(router: Node, index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	router.handle_touch_event(event)


func _run() -> void:
	if root.get_node_or_null("GameSettings") == null:
		var settings := GameSettingsScript.new()
		settings.name = "GameSettings"
		root.add_child(settings)
	if root.get_node_or_null("UiMetrics") == null:
		var metrics := UiMetricsScript.new()
		metrics.name = "UiMetrics"
		root.add_child(metrics)
	var router := RouterScript.new()
	root.add_child(router)
	router.tap.connect(func(_p: Vector2) -> void: _tap_count += 1)
	router.double_tap.connect(func(_p: Vector2) -> void: _double_tap_count += 1)
	router.long_press.connect(func(_p: Vector2) -> void: _long_press_count += 1)
	router.drag_started.connect(func(_p: Vector2) -> void: _drag_started_count += 1)
	router.drag_ended.connect(func(_d: Vector2) -> void: _drag_ended_count += 1)
	router.pinch.connect(func(_f: float, _p: Vector2) -> void: _pinch_count += 1)
	router.two_finger_pan.connect(func(_d: Vector2) -> void: _two_finger_pan_count += 1)

	_touch(router, 0, Vector2(200.0, 180.0), true)
	_touch(router, 0, Vector2(202.0, 181.0), false)
	await create_timer(0.34).timeout
	_check(_tap_count == 1, "a short touch emits one tap after the double-tap window")

	await create_timer(0.06).timeout
	_touch(router, 0, Vector2(205.0, 182.0), true)
	_touch(router, 0, Vector2(205.0, 182.0), false)
	_touch(router, 0, Vector2(206.0, 182.0), true)
	_touch(router, 0, Vector2(206.0, 182.0), false)
	_check(_double_tap_count == 1, "two close taps emit double_tap")
	await create_timer(0.34).timeout

	_touch(router, 0, Vector2(220.0, 180.0), true)
	await create_timer(0.46).timeout
	_check(_long_press_count == 1, "a stationary hold reaches the 400 ms threshold")
	_touch(router, 0, Vector2(220.0, 180.0), false)

	_touch(router, 0, Vector2(250.0, 180.0), true)
	_drag(router, 0, Vector2(280.0, 185.0))
	_touch(router, 0, Vector2(300.0, 190.0), false)
	_check(_drag_started_count == 1 and _drag_ended_count == 1, "movement beyond 10 dp emits drag start and end")

	var taps_before_multi := _tap_count
	_touch(router, 0, Vector2(310.0, 180.0), true)
	_touch(router, 1, Vector2(410.0, 180.0), true)
	_drag(router, 1, Vector2(460.0, 190.0))
	_touch(router, 0, Vector2(310.0, 180.0), false)
	_touch(router, 1, Vector2(460.0, 190.0), false)
	_check(_pinch_count > 0, "two changing touch points emit pinch")
	_check(_two_finger_pan_count > 0, "two-finger movement emits two_finger_pan")
	_check(_tap_count == taps_before_multi, "a multitouch gesture cancels the pending single tap")

	var ui_root := Control.new()
	ui_root.size = Vector2(500.0, 350.0)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ui_root)
	var button := Button.new()
	button.position = Vector2(20.0, 20.0)
	button.size = Vector2(120.0, 60.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(button)
	router.set_ui_root(ui_root)
	await process_frame
	var taps_before_ui := _tap_count
	_touch(router, 0, Vector2(40.0, 40.0), true)
	_touch(router, 0, Vector2(40.0, 40.0), false)
	_check(_tap_count == taps_before_ui, "a touch starting on a Button is not routed into the world")
	_check(router.is_pointer_over_ui(Vector2(40.0, 40.0)), "UI hit testing uses control rectangles instead of hover events")

	var taps_before_dedup := _tap_count
	_touch(router, 0, Vector2(200.0, 250.0), true)
	_touch(router, 0, Vector2(200.0, 250.0), false)
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	mouse_down.position = Vector2(200.0, 250.0)
	router.call("_unhandled_input", mouse_down)
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	mouse_up.position = Vector2(200.0, 250.0)
	router.call("_unhandled_input", mouse_up)
	await create_timer(0.34).timeout
	_check(_tap_count == taps_before_dedup + 1, "emulated mouse events inside the raw-touch window do not duplicate a gesture")

	router.queue_free()
	ui_root.queue_free()
	await process_frame
	if _failures > 0:
		printerr("Touch gesture router tests failed: %d" % _failures)
		quit(1)
	else:
		print("All touch gesture router smoke tests passed.")
		quit(0)
