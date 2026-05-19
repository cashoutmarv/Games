extends SceneTree

# Smoke test for RevealDirector — the autoload that tracks which of the
# four reveal layers (hidden_depth, clash, prediction, fourth_wall) are
# unlocked. Persists through SaveSystem; the test snapshots & restores.

func _initialize() -> void:
	var failures: Array[String] = []

	var snapshot: Dictionary = SaveSystem.state.duplicate(true)
	SaveSystem.state.reveals_unlocked = []
	SaveSystem.save()

	# --- Initial state ----------------------------------------------------
	_expect(not RevealDirector.is_unlocked("hidden_depth"),
		"hidden_depth not unlocked initially", failures)
	_expect(not RevealDirector.parry_enabled(),
		"parry disabled before hidden_depth reveal", failures)
	_expect(not RevealDirector.charge_enabled(),
		"charge disabled before hidden_depth reveal", failures)
	_expect(not RevealDirector.dodge_cancel_enabled(),
		"dodge-cancel disabled before hidden_depth reveal", failures)

	# --- Unlock + signal --------------------------------------------------
	var observed := [""]
	RevealDirector.reveal_unlocked.connect(func(layer_id: String):
		observed[0] = layer_id
	, CONNECT_ONE_SHOT)
	RevealDirector.unlock("hidden_depth")
	_expect(observed[0] == "hidden_depth",
		"reveal_unlocked signal fires with correct id", failures)
	_expect(RevealDirector.is_unlocked("hidden_depth"),
		"hidden_depth marked unlocked", failures)
	_expect(RevealDirector.parry_enabled(),
		"parry enabled after hidden_depth reveal", failures)
	_expect(RevealDirector.charge_enabled(),
		"charge enabled after hidden_depth reveal", failures)
	_expect(RevealDirector.dodge_cancel_enabled(),
		"dodge-cancel enabled after hidden_depth reveal", failures)

	# --- Idempotent ------------------------------------------------------
	RevealDirector.unlock("hidden_depth")
	_expect(RevealDirector.get_unlocked().size() == 1,
		"unlock is idempotent — no duplicate entries", failures)

	# --- Unknown layer is a no-op ----------------------------------------
	RevealDirector.unlock("not_a_layer")
	_expect(RevealDirector.get_unlocked().size() == 1,
		"unknown layer id is rejected", failures)

	# --- All four layers ------------------------------------------------
	for layer in ["clash", "prediction", "fourth_wall"]:
		RevealDirector.unlock(layer)
		_expect(RevealDirector.is_unlocked(layer),
			"layer %s unlocks" % layer, failures)
	_expect(RevealDirector.get_unlocked().size() == 4,
		"all four layers unlocked", failures)

	# --- Persistence: state survives a snapshot round-trip --------------
	var saved: Dictionary = SaveSystem.state.duplicate(true)
	SaveSystem.state.reveals_unlocked = []
	_expect(not RevealDirector.is_unlocked("hidden_depth"),
		"clearing reveals_unlocked drops query result", failures)
	SaveSystem.state = saved
	_expect(RevealDirector.is_unlocked("hidden_depth"),
		"restoring state restores reveal flags", failures)

	# Restore real save state.
	SaveSystem.state = snapshot
	SaveSystem.save()

	if failures.is_empty():
		print("[test_reveal_director] All assertions passed.")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)

func _expect(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append("FAIL: " + message)
