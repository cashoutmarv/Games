extends SceneTree

# Smoke test for EndingDirector. Snapshots + restores SaveSystem state.

func _initialize() -> void:
	var failures: Array[String] = []

	var snapshot: Dictionary = SaveSystem.state.duplicate(true)
	SaveSystem.state.endings_seen = []
	SaveSystem.state.ending_one_completed_at_iso = ""

	# Initial state — no endings, no gate.
	_expect(not EndingDirector.has_seen_ending(EndingDirector.TRUE_ENDING_ID),
		"true ending not seen initially", failures)
	_expect(not EndingDirector.has_seen_ending(EndingDirector.TRUE_TRUE_ENDING_ID),
		"true_true ending not seen initially", failures)
	_expect(not EndingDirector.is_true_true_gate_ready(),
		"gate not ready before ending 1", failures)

	# Completing the true ending marks state + emits signal.
	var captured := [""]
	EndingDirector.ending_completed.connect(func(id: String): captured[0] = id, CONNECT_ONE_SHOT)
	EndingDirector.mark_true_ending_complete()
	_expect(captured[0] == EndingDirector.TRUE_ENDING_ID,
		"ending_completed signal fires on first true ending", failures)
	_expect(EndingDirector.has_seen_ending(EndingDirector.TRUE_ENDING_ID),
		"true ending marked seen", failures)
	_expect(String(SaveSystem.state.ending_one_completed_at_iso) != "",
		"ending_one_completed_at_iso recorded", failures)

	# Idempotency — calling again doesn't re-emit.
	var captured2 := ["unset"]
	EndingDirector.ending_completed.connect(func(id: String): captured2[0] = id, CONNECT_ONE_SHOT)
	EndingDirector.mark_true_ending_complete()
	_expect(captured2[0] == "unset",
		"ending_completed does NOT fire on repeat", failures)

	# Gate not ready immediately after ending 1.
	_expect(not EndingDirector.is_true_true_gate_ready(),
		"gate not ready immediately after ending 1 (delay not elapsed)", failures)

	# Spoof a completion timestamp 13 hours in the past — gate ready.
	var past_ts: int = Time.get_unix_time_from_system() - (13 * 3600)
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(past_ts)
	var iso: String = Time.get_datetime_string_from_datetime_dict(dt, true)
	SaveSystem.state.ending_one_completed_at_iso = iso
	_expect(EndingDirector.is_true_true_gate_ready(),
		"gate ready after 13-hour-old completion timestamp", failures)

	# Once true-true is also seen, the gate stops returning ready.
	SaveSystem.mark_ending_seen(EndingDirector.TRUE_TRUE_ENDING_ID)
	_expect(not EndingDirector.is_true_true_gate_ready(),
		"gate closes once true-true ending is seen", failures)

	# Restore.
	SaveSystem.state = snapshot
	SaveSystem.save()

	if failures.is_empty():
		print("[test_ending_director] All assertions passed.")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)

func _expect(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append("FAIL: " + message)
