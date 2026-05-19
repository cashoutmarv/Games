extends Node

# Henry-Stickmin-style choice screen director.
#
# Owns:
#  - The catalogue of screens and their option outcomes (from data/choices.json)
#  - The set of outcome IDs the player has ever seen (persisted via
#    SaveSystem.state.choices_seen)
#  - The factory call that spawns a choice_screen overlay and resolves to
#    a `chosen` signal once the player picks an advancing option.
#
# Choice screens are blocking-UI overlays — the calling site `awaits`
# `show_screen(screen_id)` and gets back the chosen outcome id.

const CHOICES_DATA_PATH := "res://data/choices.json"
const ChoiceScreenScene := preload("res://scenes/ui/choice_screen.tscn")

signal outcome_recorded(outcome_id: String)
signal screen_resolved(screen_id: String, outcome_id: String)

# Loaded once at _ready.
var _screens: Dictionary = {}

func _ready() -> void:
	_load_screens()

func _load_screens() -> void:
	if not FileAccess.file_exists(CHOICES_DATA_PATH):
		push_warning("ChoiceDirector: choices.json missing")
		return
	var f := FileAccess.open(CHOICES_DATA_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ChoiceDirector: choices.json malformed")
		return
	_screens = parsed.get("screens", {})

# ---- Public API ---------------------------------------------------------

# Spawn the screen as a child of `parent_node` and await the player's
# chosen-advance pick. Returns the chosen outcome id.
func show_screen(screen_id: String, parent_node: Node) -> String:
	var cfg: Dictionary = _screens.get(screen_id, {})
	if cfg.is_empty():
		push_warning("ChoiceDirector: screen '%s' not found" % screen_id)
		return ""
	var overlay: CanvasLayer = ChoiceScreenScene.instantiate()
	parent_node.add_child(overlay)
	overlay.configure(screen_id, cfg, self)
	var outcome_id: String = await overlay.advance_chosen
	overlay.queue_free()
	screen_resolved.emit(screen_id, outcome_id)
	return outcome_id

# Called by the choice screen each time the player presses any option
# (advance or fail). Records the outcome ID for the medal grid.
func record_outcome(outcome_id: String) -> void:
	if outcome_id == "":
		return
	SaveSystem.mark_choice_outcome_seen(outcome_id)
	outcome_recorded.emit(outcome_id)

# Queries for Choices.exe -------------------------------------------------

# All outcome IDs across every screen (advance + fail). Stable iteration.
func all_outcome_ids() -> Array:
	var out: Array = []
	for screen_id in _screens.keys():
		var cfg: Dictionary = _screens[screen_id]
		for opt in cfg.get("options", []):
			var oid: String = String(opt.get("outcome_id", ""))
			if oid != "" and not out.has(oid):
				out.append(oid)
	return out

func outcomes_for_screen(screen_id: String) -> Array:
	var cfg: Dictionary = _screens.get(screen_id, {})
	var out: Array = []
	for opt in cfg.get("options", []):
		out.append(opt.get("outcome_id", ""))
	return out

func is_outcome_seen(outcome_id: String) -> bool:
	var seen: Array = SaveSystem.state.get("choices_seen", [])
	return seen.has(outcome_id)

func total_outcomes() -> int:
	return all_outcome_ids().size()

func seen_outcome_count() -> int:
	var seen: Array = SaveSystem.state.get("choices_seen", [])
	var total: Array = all_outcome_ids()
	var count: int = 0
	for oid in total:
		if seen.has(oid):
			count += 1
	return count

# Screen catalogue access for the Choices.exe app.
func screen_ids() -> Array:
	return _screens.keys()

func screen_config(screen_id: String) -> Dictionary:
	return _screens.get(screen_id, {})
