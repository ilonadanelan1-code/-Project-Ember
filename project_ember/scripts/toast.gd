extends RefCounted
class_name Toast

static func push(manager: ToastManager, message: String, icon_text: String = "•", duration: float = 2.6) -> void:
	if is_instance_valid(manager):
		manager.show_toast(message, duration, icon_text)
