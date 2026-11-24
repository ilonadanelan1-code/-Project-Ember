extends Node
class_name HapticsService

const MIN_INTERVAL_MSEC := 80
var _last_vibration_msec: int = -MIN_INTERVAL_MSEC


func tap(duration_msec: int = 10) -> bool:
	return _vibrate(duration_msec)


func confirm(duration_msec: int = 30) -> bool:
	return _vibrate(duration_msec)


func warn(duration_msec: int = 60) -> bool:
	return _vibrate(duration_msec)


func _vibrate(duration_msec: int) -> bool:
	if not has_node("/root/GameSettings") or not bool(get_node("/root/GameSettings").get("vibration_enabled")):
		return false
	if not OS.has_feature("mobile"):
		return false
	var now := Time.get_ticks_msec()
	if now - _last_vibration_msec < MIN_INTERVAL_MSEC:
		return false
	_last_vibration_msec = now
	Input.vibrate_handheld(clampi(duration_msec, 1, 100))
	return true


func can_vibrate_at(now_msec: int) -> bool:
	return now_msec - _last_vibration_msec >= MIN_INTERVAL_MSEC
