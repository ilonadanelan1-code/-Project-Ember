extends SceneTree

const CampaignStateScript = preload("res://scripts/campaign_state.gd")
const SAVE_PATH := "user://project_ember_campaign.json"
const BACKUP_PATH := SAVE_PATH + ".bak"
const TEMP_PATH := SAVE_PATH + ".tmp"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _read_bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _run() -> void:
	var had_main := FileAccess.file_exists(SAVE_PATH)
	var had_backup := FileAccess.file_exists(BACKUP_PATH)
	var original_main := _read_bytes(SAVE_PATH)
	var original_backup := _read_bytes(BACKUP_PATH)
	var corrupt_archive_path := SAVE_PATH + ".corrupt"
	var corrupt_suffix := 1
	while FileAccess.file_exists(corrupt_archive_path):
		corrupt_archive_path = "%s.corrupt.%d" % [SAVE_PATH, corrupt_suffix]
		corrupt_suffix += 1

	_remove_file(SAVE_PATH)
	_remove_file(BACKUP_PATH)
	_remove_file(TEMP_PATH)
	var state := CampaignStateScript.new()
	root.add_child(state)
	state.new_campaign()
	state.city_gold = 431
	_check(state.save_campaign(), "first campaign state is written atomically")
	state.city_gold = 975
	_check(state.save_campaign(), "second save rotates previous primary into .bak")
	_check(FileAccess.file_exists(BACKUP_PATH), "the last known-good campaign save exists in .bak")

	var corrupt := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("{ interrupted json write")
		corrupt.close()
	state.city_gold = 0
	_check(state.load_campaign(), "load recovers from malformed primary JSON through .bak")
	_check(state.city_gold == 431, "backup recovery restores the last known-good economy state")
	_check(FileAccess.file_exists(SAVE_PATH) and FileAccess.file_exists(BACKUP_PATH), "recovery restores primary and preserves backup")
	_check(not FileAccess.file_exists(TEMP_PATH), "successful recovery leaves no .tmp file")
	_check(FileAccess.file_exists(corrupt_archive_path), "damaged primary is preserved in the existing .corrupt archive flow")

	var saved_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var saved_data: Variant = JSON.parse_string(saved_file.get_as_text()) if saved_file != null else null
	if saved_file != null:
		saved_file.close()
	_check(saved_data is Dictionary and saved_data.has("turn_number") and saved_data.has("player_units") and saved_data.has("cities"), "existing campaign JSON keys remain present")
	_check(saved_data is Dictionary and not saved_data.has("battle_in_progress"), "campaign save schema gains no battle-state field")

	state.battle_in_progress = true
	state.city_gold = 999
	_check(not state.save_campaign(), "campaign writes remain blocked during an unfinished tactical battle")
	state.battle_in_progress = false
	_check(state.load_campaign() and state.city_gold == 431, "a background save during battle cannot overwrite the strategic checkpoint")

	state.queue_free()
	await process_frame
	_remove_file(SAVE_PATH)
	_remove_file(BACKUP_PATH)
	_remove_file(TEMP_PATH)
	_remove_file(corrupt_archive_path)
	if had_main:
		_check(_write_bytes(SAVE_PATH, original_main), "pre-test main save is restored")
	if had_backup:
		_check(_write_bytes(BACKUP_PATH, original_backup), "pre-test backup save is restored")
	if _failures > 0:
		printerr("Atomic save smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All atomic save smoke tests passed.")
		quit(0)
