extends Node

const PhaseMachine := preload("res://scripts/systems/phase_machine.gd")

signal phase_changed(phase: int)
signal run_started
signal run_ended(won: bool)

var current_phase: int = PhaseMachine.NarrativePhase.NORMAL_FIGHT
var run_in_progress: bool = false
var reached_boss_room_this_run: bool = false
# Per-run bonus damage applied on top of weapon/projectile base damage.
# Earned by dying boss-side then winning back; resets to 0 at run start.
var damage_bonus: int = 0
# Player-typed weapon for this run + the resolved dictionary entry.
# Set by weapon_input.gd via set_weapon() before the arena loads.
var weapon_text: String = ""
var weapon_data: Dictionary = {}
# 1-indexed floor counter. Advances on boss_room.boss_defeated; run ends
# when it exceeds 3 (the final boss in v5 will short-circuit).
var current_floor: int = 1

func _ready() -> void:
	recompute_phase()

func recompute_phase() -> void:
	var new_phase: int = PhaseMachine.evaluate(SaveSystem.state)
	if new_phase != current_phase:
		current_phase = new_phase
		SaveSystem.state.dialogue_phase = PhaseMachine.phase_name(new_phase)
		SaveSystem.save()
		phase_changed.emit(new_phase)
	else:
		current_phase = new_phase

func start_run() -> void:
	run_in_progress = true
	reached_boss_room_this_run = false
	damage_bonus = 0
	current_floor = 1
	PatternTracker.reset()
	recompute_phase()
	ReplayRecorder.start()
	run_started.emit()

# Record the weapon the player chose at run start. Called from weapon_input.gd.
func set_weapon(text: String, resolved: Dictionary) -> void:
	weapon_text = text
	weapon_data = resolved
	# Persist a hint for the desktop hub to display "last run's weapon".
	SaveSystem.state.last_weapon_text = text
	SaveSystem.state.last_weapon_archetype = String(resolved.get("archetype", ""))
	SaveSystem.save()

func clear_weapon() -> void:
	weapon_text = ""
	weapon_data = {}

func mark_reached_boss_room() -> void:
	reached_boss_room_this_run = true

func end_run(won: bool) -> void:
	if not run_in_progress:
		return
	run_in_progress = false
	SaveSystem.bump_run_count(won)
	# Only promote the recorded buffer to the canonical replay if this run
	# reached the boss room AND we don't already have a first-run recording.
	if reached_boss_room_this_run and not SaveSystem.state.first_run_recorded:
		if ReplayRecorder.flush_to_disk():
			SaveSystem.set_first_run_recorded()
	else:
		ReplayRecorder.discard()
	recompute_phase()
	run_ended.emit(won)

# ---- Debug helpers (used by main menu dev panel) ----

func debug_set_runs(n: int) -> void:
	SaveSystem.state.total_runs = max(0, n)
	SaveSystem.save()
	recompute_phase()

func debug_set_phase(phase: int) -> void:
	current_phase = phase
	SaveSystem.state.dialogue_phase = PhaseMachine.phase_name(phase)
	SaveSystem.save()
	phase_changed.emit(phase)

func debug_set_boss_deleted(deleted: bool) -> void:
	SaveSystem.state.boss_deleted = deleted
	SaveSystem.save()
	recompute_phase()

func debug_add_eggs(n: int) -> void:
	var all_ids: Array = ["echo", "ghost", "seam", "vessel", "warden"]
	for i in range(min(n, all_ids.size())):
		SaveSystem.mark_egg_found(all_ids[i])
	recompute_phase()
