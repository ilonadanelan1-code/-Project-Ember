extends SceneTree

const Library = preload("res://scripts/combat_sprite_library.gd")
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
	if not Library.has_assets():
		_check(Library.get_frames(0, 0) == null, "source-only repository safely selects the legacy fallback renderer")
		_check(Library.get_frames(1, 1) == null, "source-only fallback is safe for both teams and ranged units")
	else:
		var expected := {
			0: {"idle": 8, "run": 6, "attack_a": 4, "attack_b": 4, "guard": 6},
			1: {"idle": 6, "run": 4, "shoot": 8},
			2: {"idle": 12, "run": 6, "attack": 3, "defend": 6},
			4: {"idle": 8, "run": 6, "attack_a": 4, "attack_b": 4, "guard": 6},
		}
		for team in range(2):
			for role in expected.keys():
				var frames: SpriteFrames = Library.get_frames(team, int(role))
				_check(frames != null, "team %d role %d receives SpriteFrames" % [team, role])
				if frames == null:
					continue
				for animation_name in expected[role].keys():
					var animation := StringName(animation_name)
					_check(frames.has_animation(animation), "team %d role %d has %s animation" % [team, role, animation_name])
					if frames.has_animation(animation):
						_check(frames.get_frame_count(animation) == int(expected[role][animation_name]), "%s frame count is correct" % animation_name)
						_check(frames.get_frame_texture(animation, 0) != null, "%s has a valid first atlas frame" % animation_name)
				_check(frames == Library.get_frames(team, int(role)), "SpriteFrames are cached per team and role")
		_check(Library.get_attack_animation(0, false) == &"attack_a", "melee attack selects first swing")
		_check(Library.get_attack_animation(0, true) == &"attack_b", "melee attack alternates swing")
		_check(Library.get_attack_animation(1) == &"shoot", "ranged attack selects shooting animation")
		_check(Library.get_attack_animation(2) == &"attack", "spear attack selects thrust animation")
		_check(Library.get_animation_duration(Library.get_frames(0, 0), &"attack_a") > 0.0, "attack timing is derived from animation frames")

	if Library.has_cavalry_assets():
		for team in range(2):
			var horse_frames: SpriteFrames = Library.get_frames(team, 3)
			_check(horse_frames != null, "team %d cavalry receives mounted pixel sprites" % team)
			if horse_frames == null:
				continue
			var atlas_path := "res://assets/combat/cavalry/blue_animations.png" if team == 0 else "res://assets/combat/cavalry/red_animations.png"
			var atlas_texture := load(atlas_path) as Texture2D
			_check(atlas_texture != null and atlas_texture.get_width() == 1408 and atlas_texture.get_height() == 328, "team %d cavalry atlas uses the normalized 88x82 layout" % team)
			for animation_data in [["idle", 11], ["run", 8], ["attack", 12], ["charge", 16]]:
				var animation := StringName(animation_data[0])
				_check(horse_frames.has_animation(animation), "cavalry has %s animation" % animation)
				if horse_frames.has_animation(animation):
					_check(horse_frames.get_frame_count(animation) == int(animation_data[1]), "cavalry %s frame count is correct" % animation)
					_check(horse_frames.get_frame_texture(animation, 0) != null, "cavalry %s frame texture is valid" % animation)
			_check(horse_frames == Library.get_frames(team, 3), "cavalry frames are cached per team")
		_check(Library.get_attack_animation(3, false, false) == &"attack", "cavalry uses the rearing animation for a normal attack")
		_check(Library.get_attack_animation(3, false, true) == &"charge", "cavalry uses the jump animation for a charge")
		_check(Library.get_contact_time(3) > 0.0, "cavalry strike timing is explicitly configured")
	else:
		_check(Library.get_frames(0, 3) == null, "missing cavalry art safely selects the original renderer")

	_check(Library.get_contact_time(0) > 0.0 and Library.get_contact_time(1) > 0.0, "melee contact and arrow release have explicit timings")
	var recovery_frames := SpriteFrames.new()
	recovery_frames.add_animation("guard")
	recovery_frames.add_animation("defend")
	_check(Library.get_recovery_animation(0, recovery_frames) == &"guard", "swordsmen recover in a guard stance")
	_check(Library.get_recovery_animation(2, recovery_frames) == &"defend", "spearmen recover in a defensive stance")
	_check(Library.get_recovery_animation(3, recovery_frames) == &"idle", "cavalry returns to mounted idle after an attack")

	if _failures > 0:
		printerr("Combat sprite library tests failed: %d" % _failures)
		quit(1)
	else:
		print("All combat sprite library smoke tests passed.")
		quit(0)
