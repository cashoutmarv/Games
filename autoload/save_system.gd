extends Node

const SAVE_PATH := "user://loop_state.json"
const BOSS_PATH := "user://boss.dat"
const REPLAY_PATH := "user://run1_inputs.dat"
const SCHEMA_VERSION := 2
const BOSS_SIGNATURE := "I am the warden of the loop."

signal state_changed
signal boss_deleted_changed(deleted: bool)

var state: Dictionary = _default_state()

func _ready() -> void:
	load_state()
	ensure_boss_file()

func _default_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"total_runs": 0,
		"successful_runs": 0,
		"dialogue_phase": "NORMAL_FIGHT",
		"easter_eggs_found": [],
		"boss_deleted": false,
		"role_swap_active": false,
		"first_run_recorded": false,
		"recorded_inputs_path": REPLAY_PATH,
		"last_played_iso": Time.get_datetime_string_from_system(true),
		# --- v2 additions (role-swap + endings + choice screens) ---
		"inherited_abilities": [],
		"boss_side_deaths_total": 0,
		"first_boss_side_swap_seen": false,
		"endings_seen": [],
		"ending_one_completed_at_iso": "",
		"choices_seen": [],
		"reveals_unlocked": [],
		"bosses_defeated": [],
		"first_rewind_seen": false,
	}

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		state = _default_state()
		save()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("Could not open save file; using defaults.")
		state = _default_state()
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file malformed; resetting.")
		state = _default_state()
		save()
		return
	state = _merge_with_defaults(parsed)
	_migrate_if_needed()
	_detect_tampering()

func _merge_with_defaults(parsed: Dictionary) -> Dictionary:
	var merged := _default_state()
	for key in parsed.keys():
		if merged.has(key):
			merged[key] = parsed[key]
	return merged

# Walks the loaded state forward to the current SCHEMA_VERSION. Each step
# touches only fields it owns, so a v1-on-disk save lights up the v2 fields
# without losing v1 progress.
func _migrate_if_needed() -> void:
	var loaded_version: int = int(state.get("schema_version", 1))
	if loaded_version >= SCHEMA_VERSION:
		return
	if loaded_version < 2:
		# v1 saves don't have these fields; defaults already filled them in
		# via _merge_with_defaults, but persist the bumped schema version.
		state.schema_version = 2
	save()

func _detect_tampering() -> void:
	# If boss.dat is missing but state says not deleted, treat as user-tampered.
	if not FileAccess.file_exists(BOSS_PATH) and not state.boss_deleted:
		state.boss_deleted = true
		save()
		boss_deleted_changed.emit(true)

func save() -> void:
	state.last_played_iso = Time.get_datetime_string_from_system(true)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not write save file at %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(state, "\t"))
	f.close()
	state_changed.emit()

func ensure_boss_file() -> void:
	if state.boss_deleted:
		return
	if FileAccess.file_exists(BOSS_PATH):
		return
	var f := FileAccess.open(BOSS_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not write boss file at %s" % BOSS_PATH)
		return
	f.store_string("BOSS_v1\n")
	f.store_string(BOSS_SIGNATURE + "\n")
	# ~1KB of deterministic pseudo-random padding so the file looks substantive.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xB055
	var bytes := PackedByteArray()
	bytes.resize(1024)
	for i in bytes.size():
		bytes[i] = rng.randi() & 0xFF
	f.store_buffer(bytes)
	f.close()

func delete_boss_file() -> bool:
	if not FileAccess.file_exists(BOSS_PATH):
		state.boss_deleted = true
		save()
		boss_deleted_changed.emit(true)
		return true
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(BOSS_PATH))
	if err != OK:
		# Fall back to FileAccess removal for sandboxed paths.
		var dir := DirAccess.open("user://")
		if dir == null:
			push_error("Could not open user:// to delete boss file.")
			return false
		err = dir.remove("boss.dat")
		if err != OK:
			push_error("Boss file deletion failed: %s" % err)
			return false
	state.boss_deleted = true
	save()
	boss_deleted_changed.emit(true)
	return true

func mark_egg_found(egg_id: String) -> void:
	if not state.easter_eggs_found.has(egg_id):
		state.easter_eggs_found.append(egg_id)
		save()

func bump_run_count(was_successful: bool) -> void:
	state.total_runs += 1
	if was_successful:
		state.successful_runs += 1
	save()

func set_role_swap(active: bool) -> void:
	state.role_swap_active = active
	save()

func set_first_run_recorded() -> void:
	state.first_run_recorded = true
	save()

func mark_ending_seen(ending_id: String) -> void:
	var seen: Array = state.get("endings_seen", [])
	if not seen.has(ending_id):
		seen.append(ending_id)
		state.endings_seen = seen
		if ending_id == "true" and state.get("ending_one_completed_at_iso", "") == "":
			state.ending_one_completed_at_iso = Time.get_datetime_string_from_system(true)
		save()

func mark_choice_outcome_seen(choice_outcome_id: String) -> void:
	var seen: Array = state.get("choices_seen", [])
	if not seen.has(choice_outcome_id):
		seen.append(choice_outcome_id)
		state.choices_seen = seen
		save()

func reset_all() -> void:
	# Dev cheat — wipe everything and recreate.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(BOSS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BOSS_PATH))
	if FileAccess.file_exists(REPLAY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REPLAY_PATH))
	state = _default_state()
	save()
	ensure_boss_file()
