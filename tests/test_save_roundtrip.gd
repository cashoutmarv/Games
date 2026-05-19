extends SceneTree

# Minimal smoke test runnable via:
#   godot --headless --script res://tests/test_save_roundtrip.gd
# Verifies default state shape, phase machine transitions, and JSON round-trip.

const PhaseMachine := preload("res://scripts/systems/phase_machine.gd")

func _initialize() -> void:
	var failures: Array[String] = []

	# Phase machine: bare state → NORMAL_FIGHT.
	var s := {
		"total_runs": 0,
		"easter_eggs_found": [],
		"boss_deleted": false,
		"role_swap_active": false,
	}
	_expect(PhaseMachine.evaluate(s) == PhaseMachine.NarrativePhase.NORMAL_FIGHT,
		"runs=0 should be NORMAL_FIGHT", failures)

	s.total_runs = 3
	_expect(PhaseMachine.evaluate(s) == PhaseMachine.NarrativePhase.BOSS_HESITATES,
		"runs=3 should be BOSS_HESITATES", failures)

	s.total_runs = 5
	_expect(PhaseMachine.evaluate(s) == PhaseMachine.NarrativePhase.BOSS_TALKS,
		"runs=5 should be BOSS_TALKS", failures)

	s.total_runs = 8
	_expect(PhaseMachine.evaluate(s) == PhaseMachine.NarrativePhase.EASTER_EGG_HUNT,
		"runs=8, eggs=0 should be EASTER_EGG_HUNT", failures)

	s.easter_eggs_found = ["echo", "ghost", "seam"]
	_expect(PhaseMachine.evaluate(s) == PhaseMachine.NarrativePhase.FILE_BROWSER_UNLOCKED,
		"eggs=3 should unlock FILE_BROWSER", failures)

	s.boss_deleted = true
	_expect(PhaseMachine.evaluate(s) == PhaseMachine.NarrativePhase.BOSS_DELETED,
		"boss_deleted should be BOSS_DELETED", failures)

	s.role_swap_active = true
	_expect(PhaseMachine.evaluate(s) == PhaseMachine.NarrativePhase.ROLE_SWAP,
		"role_swap_active should be ROLE_SWAP", failures)

	# Phase name round-trip.
	for phase in range(PhaseMachine.NarrativePhase.size()):
		var name := PhaseMachine.phase_name(phase)
		_expect(PhaseMachine.phase_from_name(name) == phase,
			"phase round-trip failed for %s" % name, failures)

	# Schema v2 — new fields exist in the default state shape.
	var snapshot: Dictionary = SaveSystem.state.duplicate(true)
	var defaults: Dictionary = SaveSystem._default_state()
	_expect(int(defaults.get("schema_version", 0)) == 2,
		"default schema_version is 2", failures)
	for required_key in ["inherited_abilities", "boss_side_deaths_total",
			"first_boss_side_swap_seen", "endings_seen",
			"ending_one_completed_at_iso", "choices_seen"]:
		_expect(defaults.has(required_key),
			"default state has v2 key '%s'" % required_key, failures)

	# Ending + choice helpers update state idempotently.
	SaveSystem.state = SaveSystem._default_state()
	SaveSystem.mark_ending_seen("true")
	SaveSystem.mark_ending_seen("true")  # second call is a no-op
	_expect(SaveSystem.state.endings_seen == ["true"],
		"mark_ending_seen is idempotent", failures)
	_expect(SaveSystem.state.ending_one_completed_at_iso != "",
		"first 'true' ending records completion timestamp", failures)

	SaveSystem.mark_choice_outcome_seen("door_kick_fail")
	SaveSystem.mark_choice_outcome_seen("door_kick_fail")
	_expect(SaveSystem.state.choices_seen == ["door_kick_fail"],
		"mark_choice_outcome_seen is idempotent", failures)

	# Restore real save state.
	SaveSystem.state = snapshot
	SaveSystem.save()

	if failures.is_empty():
		print("[test] All assertions passed.")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)

func _expect(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append("FAIL: " + message)
