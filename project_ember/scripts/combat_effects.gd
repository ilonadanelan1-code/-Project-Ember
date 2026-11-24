extends Node3D
class_name CombatEffects

const Palette = preload("res://scripts/art_palette.gd")
const VisualCacheScript = preload("res://scripts/visual_cache.gd")

const SAMPLE_RATE := 22050
const EFFECT_COUNTS := [8, 14, 18]
const AUDIO_COUNTS := [4, 6, 8]

var _effects: Array[Dictionary] = []
var _audio_players: Array[AudioStreamPlayer3D] = []
var _sound_streams: Dictionary = {}
var _sound_cooldowns: Dictionary = {}
var _next_effect_index: int = 0
var _next_audio_index: int = 0


func _ready() -> void:
	add_to_group("battle_effects")
	var quality := 1
	var settings_node := get_node_or_null("/root/GameSettings")
	if is_instance_valid(settings_node):
		quality = clampi(int(settings_node.get("graphics_quality")), 0, 2)
	_create_effect_pool(EFFECT_COUNTS[quality])
	_create_audio_pool(AUDIO_COUNTS[quality])
	_build_sound_library()


func _create_effect_pool(pool_size: int) -> void:
	for index in range(pool_size):
		var instance := MeshInstance3D.new()
		instance.name = "EffectSlot_%02d" % index
		instance.visible = false
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_effects.append({
			"node": instance,
			"active": false,
			"elapsed": 0.0,
			"duration": 0.2,
			"start_scale": 0.2,
			"end_scale": 1.0,
			"rise": 0.0,
			"spin": 0.0,
		})


func _create_audio_pool(pool_size: int) -> void:
	var output_bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	for index in range(pool_size):
		var player := AudioStreamPlayer3D.new()
		player.name = "SFX_%02d" % index
		player.bus = output_bus
		player.unit_size = 8.0
		player.max_distance = 28.0
		player.volume_db = -8.0
		player.max_polyphony = 1
		add_child(player)
		_audio_players.append(player)


func _build_sound_library() -> void:
	for sound_id in ["melee", "spear", "cavalry", "bow", "arrow_impact", "death", "rally"]:
		_sound_streams[sound_id] = _build_sound_stream(sound_id)


func get_sound_stream(sound_id: String) -> AudioStreamWAV:
	return _sound_streams.get(sound_id) as AudioStreamWAV


func get_effect_pool_size() -> int:
	return _effects.size()


func get_audio_pool_size() -> int:
	return _audio_players.size()


func get_generated_sound_count() -> int:
	return _sound_streams.size()


func get_active_effect_count() -> int:
	var active_count := 0
	for slot in _effects:
		if bool(slot.get("active", false)):
			active_count += 1
	return active_count


func spawn_effect(effect_id: String, world_position: Vector3, team: int = 0, direction: Vector3 = Vector3.ZERO) -> void:
	if _effects.is_empty():
		return
	if effect_id not in ["muzzle", "impact", "hit", "charge", "rally", "death", "dust", "trail"]:
		return

	var slot_index := _next_effect_index
	_next_effect_index = (_next_effect_index + 1) % _effects.size()
	var slot: Dictionary = _effects[slot_index]
	var instance := slot["node"] as MeshInstance3D
	instance.mesh = _get_burst_mesh() if effect_id not in ["dust", "death"] else _get_dust_mesh()
	instance.material_override = _get_effect_material(effect_id, team)

	var duration := 0.22
	var start_scale := 0.18
	var end_scale := 0.9
	var rise := 0.0
	var spin := 0.0
	match effect_id:
		"muzzle":
			duration = 0.10
			start_scale = 0.12
			end_scale = 0.58
		"impact", "hit":
			duration = 0.20
			start_scale = 0.14
			end_scale = 0.78
			rise = 0.18
			spin = 3.0
		"charge":
			duration = 0.28
			start_scale = 0.32
			end_scale = 1.25
			rise = 0.25
			spin = 1.5
		"rally":
			duration = 0.46
			start_scale = 0.22
			end_scale = 1.35
			rise = 1.15
			spin = 2.4
		"death":
			duration = 0.42
			start_scale = 0.28
			end_scale = 1.4
			rise = 0.6
		"dust":
			duration = 0.32
			start_scale = 0.2
			end_scale = 1.15
			rise = 0.22
		"trail":
			duration = 0.13
			start_scale = 0.07
			end_scale = 0.30
			spin = 0.4

	instance.global_position = world_position
	instance.scale = Vector3.ONE * start_scale
	instance.transparency = 0.0
	instance.rotation = Vector3.ZERO
	if direction.length_squared() > 0.001:
		instance.look_at(world_position + direction.normalized(), Vector3.UP)
	instance.visible = true

	slot["active"] = true
	slot["elapsed"] = 0.0
	slot["duration"] = duration
	slot["start_scale"] = start_scale
	slot["end_scale"] = end_scale
	slot["rise"] = rise
	slot["spin"] = spin
	_effects[slot_index] = slot


func play_sound(sound_id: String, world_position: Vector3) -> void:
	if not _sound_streams.has(sound_id) or _audio_players.is_empty():
		return
	if float(_sound_cooldowns.get(sound_id, 0.0)) > 0.0:
		return

	var selected_player: AudioStreamPlayer3D
	for player in _audio_players:
		if not player.playing:
			selected_player = player
			break
	if not is_instance_valid(selected_player):
		selected_player = _audio_players[_next_audio_index]
		_next_audio_index = (_next_audio_index + 1) % _audio_players.size()
		selected_player.stop()

	selected_player.stream = _sound_streams[sound_id] as AudioStreamWAV
	selected_player.global_position = world_position
	selected_player.volume_db = -9.0 if sound_id != "rally" else -7.0
	selected_player.play()
	_sound_cooldowns[sound_id] = 0.055 if sound_id != "rally" else 0.22


func _process(delta: float) -> void:
	for slot_index in range(_effects.size()):
		var slot: Dictionary = _effects[slot_index]
		if not bool(slot.get("active", false)):
			continue
		var instance := slot["node"] as MeshInstance3D
		if not is_instance_valid(instance):
			slot["active"] = false
			_effects[slot_index] = slot
			continue
		var elapsed := float(slot["elapsed"]) + delta
		var duration := maxf(float(slot["duration"]), 0.01)
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		var eased := progress * progress * (3.0 - 2.0 * progress)
		var scale_value := lerpf(float(slot["start_scale"]), float(slot["end_scale"]), eased)
		instance.scale = Vector3.ONE * scale_value
		instance.global_position.y += float(slot["rise"]) * delta
		instance.rotation.y += float(slot["spin"]) * delta
		instance.transparency = clampf(progress * 1.12, 0.0, 0.92)
		slot["elapsed"] = elapsed
		if progress >= 1.0:
			instance.visible = false
			instance.transparency = 0.0
			slot["active"] = false
		_effects[slot_index] = slot

	for sound_id in _sound_cooldowns.keys():
		var remaining := maxf(0.0, float(_sound_cooldowns[sound_id]) - delta)
		if remaining <= 0.0:
			_sound_cooldowns.erase(sound_id)
		else:
			_sound_cooldowns[sound_id] = remaining


func _get_burst_mesh() -> Mesh:
	return VisualCacheScript.get_mesh("combat:fx:burst:v1", func() -> Mesh:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in range(8):
			var angle := TAU * float(index) / 8.0
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			var side := Vector3(-direction.z, 0.0, direction.x) * 0.055
			var base := direction * 0.12
			var tip := direction * (0.32 if index % 2 == 0 else 0.25) + Vector3(0.0, 0.035, 0.0)
			surface.add_vertex(base - side)
			surface.add_vertex(base + side)
			surface.add_vertex(tip)
		surface.generate_normals()
		return surface.commit()
	)


func _get_dust_mesh() -> Mesh:
	return VisualCacheScript.get_mesh("combat:fx:dust:v1", func() -> Mesh:
		var mesh := SphereMesh.new()
		mesh.radius = 0.36
		mesh.height = 0.58
		mesh.radial_segments = 6
		mesh.rings = 3
		return mesh
	)


func _get_effect_material(effect_id: String, team: int) -> Material:
	var color := Palette.FX_SPARK
	var glow := Palette.FX_SPARK_GLOW
	match effect_id:
		"muzzle", "trail":
			color = Palette.FX_MUZZLE
			glow = Palette.FX_MUZZLE_GLOW
		"rally":
			color = Palette.FX_RALLY
			glow = Palette.FX_RALLY_GLOW
		"death":
			color = Palette.FX_DEATH
			glow = Palette.FX_DEATH_GLOW
		"dust", "charge":
			color = Palette.FX_DUST
			glow = Palette.FX_DUST_GLOW
		_:
			if team == 1:
				color = Palette.FX_ENEMY_SPARK
				glow = Palette.FX_ENEMY_SPARK_GLOW
	var material_kind := "impact"
	if effect_id in ["muzzle", "trail"]:
		material_kind = "muzzle"
	elif effect_id in ["rally", "death", "dust", "charge"]:
		material_kind = effect_id
	var key := "combat:fx:material:%s:%d" % [material_kind, team]
	return VisualCacheScript.get_material(key, func() -> Material:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color.r, color.g, color.b, 0.88)
		material.emission_enabled = true
		material.emission = glow
		material.emission_energy_multiplier = 1.25
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		return material
	)


func _build_sound_stream(sound_id: String) -> AudioStreamWAV:
	var duration := 0.16
	var frequency_start := 180.0
	var frequency_end := 85.0
	var noise_amount := 0.16
	match sound_id:
		"melee":
			duration = 0.13
			frequency_start = 190.0
			frequency_end = 72.0
			noise_amount = 0.30
		"spear":
			duration = 0.15
			frequency_start = 260.0
			frequency_end = 105.0
			noise_amount = 0.20
		"cavalry":
			duration = 0.21
			frequency_start = 120.0
			frequency_end = 48.0
			noise_amount = 0.34
		"bow":
			duration = 0.11
			frequency_start = 720.0
			frequency_end = 260.0
			noise_amount = 0.25
		"arrow_impact":
			duration = 0.12
			frequency_start = 330.0
			frequency_end = 90.0
			noise_amount = 0.28
		"death":
			duration = 0.25
			frequency_start = 105.0
			frequency_end = 38.0
			noise_amount = 0.12
		"rally":
			duration = 0.28
			frequency_start = 240.0
			frequency_end = 410.0
			noise_amount = 0.08

	var sample_count := int(SAMPLE_RATE * duration)
	var sample_data := PackedByteArray()
	sample_data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time := float(sample_index) / float(SAMPLE_RATE)
		var progress := time / duration
		var phase := TAU * (frequency_start * time + (frequency_end - frequency_start) * time * progress * 0.5)
		var envelope := pow(1.0 - progress, 1.8)
		var tone := sin(phase) * (0.34 if sound_id != "rally" else 0.24)
		var transient := sin(float(sample_index) * 17.137) * noise_amount * maxf(0.0, 1.0 - progress * 12.0)
		var overtone := sin(phase * 2.03) * (0.08 if sound_id == "bow" else 0.035)
		var sample_value := clampf((tone + transient + overtone) * envelope, -1.0, 1.0)
		sample_data.encode_s16(sample_index * 2, roundi(sample_value * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = sample_data
	return stream
