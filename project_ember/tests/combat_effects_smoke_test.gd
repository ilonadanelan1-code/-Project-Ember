extends SceneTree

const CombatEffectsScript = preload("res://scripts/combat_effects.gd")

class FakeGameSettings:
	extends Node
	var graphics_quality: int = 1

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	var settings := root.get_node_or_null("GameSettings")
	var owns_fake_settings := false
	if not is_instance_valid(settings):
		settings = FakeGameSettings.new()
		settings.name = "GameSettings"
		root.add_child(settings)
		owns_fake_settings = true
	var original_quality := int(settings.get("graphics_quality"))
	var parent := Node3D.new()
	parent.name = "CombatEffectsTestRoot"
	root.add_child(parent)

	var expected_effects := [8, 14, 18]
	var expected_audio := [4, 6, 8]
	for quality in range(3):
		settings.set("graphics_quality", quality)
		var manager := CombatEffectsScript.new()
		parent.add_child(manager)
		_check(manager.get_effect_pool_size() == expected_effects[quality], "quality %d creates the expected bounded effect pool" % quality)
		_check(manager.get_audio_pool_size() == expected_audio[quality], "quality %d creates the expected bounded audio pool" % quality)
		_check(manager.get_generated_sound_count() == 7, "quality %d generates all seven short combat sounds" % quality)
		_check(manager.get_child_count() == expected_effects[quality] + expected_audio[quality], "quality %d creates no extra effect or audio nodes" % quality)
		for sound_id in ["melee", "spear", "cavalry", "bow", "arrow_impact", "death", "rally"]:
			var stream := manager.get_sound_stream(sound_id)
			_check(stream != null and stream.data.size() > 0, "generated sound '%s' contains PCM samples" % sound_id)
		for effect_index in range(40):
			manager.spawn_effect("impact" if effect_index % 2 == 0 else "trail", Vector3(float(effect_index) * 0.1, 0.5, 0.0), effect_index % 2)
		_check(manager.get_active_effect_count() <= manager.get_effect_pool_size(), "effect bursts never exceed the fixed pool")
		_check(manager.get_active_effect_count() == manager.get_effect_pool_size(), "burst overflow reuses the existing effect slots")
		_check(manager.get_child_count() == expected_effects[quality] + expected_audio[quality], "repeated bursts allocate no additional child nodes")
		manager.play_sound("melee", Vector3.ZERO)
		manager.play_sound("rally", Vector3.ZERO)
		manager.queue_free()
		await process_frame

	settings.set("graphics_quality", original_quality)
	if owns_fake_settings:
		settings.queue_free()
	parent.queue_free()
	await process_frame

	if _failures > 0:
		printerr("Combat effects smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All combat effects smoke tests passed.")
		quit(0)
