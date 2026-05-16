extends Node

const DIALOGUE_PATH := "res://data/dialogue.json"

var _lines: Dictionary = {}

func _ready() -> void:
	_load_dialogue()

func _load_dialogue() -> void:
	if not FileAccess.file_exists(DIALOGUE_PATH):
		push_warning("Dialogue file missing at %s" % DIALOGUE_PATH)
		return
	var f := FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_lines = parsed

func get_lines_for_phase(phase_name: String) -> Array:
	if _lines.has(phase_name):
		return _lines[phase_name]
	return []

func get_random_line(phase_name: String) -> String:
	var pool: Array = get_lines_for_phase(phase_name)
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]
