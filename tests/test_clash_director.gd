extends SceneTree

# Smoke test for ClashDirector's pure logic.
# RPS triangle: BREAK beats FAKE, FAKE beats COMMIT, COMMIT beats BREAK.

func _initialize() -> void:
	var failures: Array[String] = []

	# Resolve picks: triangle.
	_expect(ClashDirector.resolve_picks("BREAK", "FAKE") == "player",
		"BREAK beats FAKE", failures)
	_expect(ClashDirector.resolve_picks("FAKE", "COMMIT") == "player",
		"FAKE beats COMMIT", failures)
	_expect(ClashDirector.resolve_picks("COMMIT", "BREAK") == "player",
		"COMMIT beats BREAK", failures)

	# Reverse: boss wins the other half.
	_expect(ClashDirector.resolve_picks("FAKE", "BREAK") == "boss",
		"FAKE loses to BREAK", failures)
	_expect(ClashDirector.resolve_picks("COMMIT", "FAKE") == "boss",
		"COMMIT loses to FAKE", failures)
	_expect(ClashDirector.resolve_picks("BREAK", "COMMIT") == "boss",
		"BREAK loses to COMMIT", failures)

	# Ties.
	for opt in ["BREAK", "FAKE", "COMMIT"]:
		_expect(ClashDirector.resolve_picks(opt, opt) == "tie",
			"%s vs %s is a tie" % [opt, opt], failures)

	# Constants exposed.
	_expect(Array(ClashDirector.OPTIONS) == ["BREAK", "FAKE", "COMMIT"],
		"OPTIONS constant exposed in expected order", failures)
	_expect(ClashDirector.BEATS["BREAK"] == "FAKE",
		"BEATS table: BREAK→FAKE", failures)
	_expect(ClashDirector.BEATS["FAKE"] == "COMMIT",
		"BEATS table: FAKE→COMMIT", failures)
	_expect(ClashDirector.BEATS["COMMIT"] == "BREAK",
		"BEATS table: COMMIT→BREAK", failures)

	# is_clash_active starts false.
	_expect(not ClashDirector.is_clash_active(),
		"is_clash_active() is false initially", failures)

	if failures.is_empty():
		print("[test_clash_director] All assertions passed.")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)

func _expect(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append("FAIL: " + message)
