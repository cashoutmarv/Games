extends SceneTree

# Smoke test for the PatternTracker autoload.

func _initialize() -> void:
	var failures: Array[String] = []

	PatternTracker.reset()
	_expect(PatternTracker.clash_pick_count() == 0,
		"reset zeroes the clash history", failures)
	_expect(PatternTracker.most_recent_clash_pick() == "",
		"most_recent_clash_pick on empty history returns ''", failures)
	_expect(PatternTracker.parry_count() == 0 and PatternTracker.dodge_count() == 0,
		"parry and dodge counters reset", failures)

	PatternTracker.record_clash_pick("BREAK")
	_expect(PatternTracker.most_recent_clash_pick() == "BREAK",
		"most_recent_clash_pick returns last recorded pick", failures)
	PatternTracker.record_clash_pick("FAKE")
	_expect(PatternTracker.most_recent_clash_pick() == "FAKE",
		"most_recent_clash_pick updates as new picks land", failures)

	# Frequency: 2x BREAK, 1x FAKE.
	PatternTracker.record_clash_pick("BREAK")
	_expect(PatternTracker.most_frequent_clash_pick() == "BREAK",
		"most_frequent_clash_pick picks the modal value", failures)
	_expect(PatternTracker.clash_pick_count() == 3,
		"clash_pick_count tracks total recorded", failures)

	# Counters increment.
	PatternTracker.record_parry()
	PatternTracker.record_parry()
	PatternTracker.record_dodge()
	_expect(PatternTracker.parry_count() == 2,
		"parry counter increments", failures)
	_expect(PatternTracker.dodge_count() == 1,
		"dodge counter increments", failures)

	# Reset clears everything.
	PatternTracker.reset()
	_expect(PatternTracker.clash_pick_count() == 0 \
			and PatternTracker.parry_count() == 0 \
			and PatternTracker.dodge_count() == 0,
		"reset clears all counters", failures)

	if failures.is_empty():
		print("[test_pattern_tracker] All assertions passed.")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)

func _expect(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append("FAIL: " + message)
