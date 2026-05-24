extends SceneTree

# Smoke test for ChoiceDirector. Doesn't instantiate the overlay scene —
# just exercises the data + bookkeeping API.

func _initialize() -> void:
	var failures: Array[String] = []

	var snapshot: Dictionary = SaveSystem.state.duplicate(true)
	SaveSystem.state.choices_seen = []

	# Catalogue loaded from choices.json.
	var ids: Array = ChoiceDirector.screen_ids()
	_expect(ids.has("weapon_prompt"),
		"weapon_prompt screen present in catalogue", failures)
	_expect(ids.has("door_floor_1"),
		"door_floor_1 screen present", failures)
	_expect(ids.has("fridge_f1"),
		"fridge_f1 screen present", failures)

	# Each known screen has an advance outcome.
	for screen in ["weapon_prompt", "door_floor_1", "fridge_f1"]:
		var cfg: Dictionary = ChoiceDirector.screen_config(screen)
		var has_advance: bool = false
		for opt in cfg.get("options", []):
			if bool(opt.get("is_advance", false)):
				has_advance = true
				break
		_expect(has_advance,
			"screen '%s' has at least one advance option" % screen, failures)

	# Outcome bookkeeping is idempotent.
	_expect(not ChoiceDirector.is_outcome_seen("weapon_prompt_sword_fail"),
		"unseen outcome reads false initially", failures)
	ChoiceDirector.record_outcome("weapon_prompt_sword_fail")
	_expect(ChoiceDirector.is_outcome_seen("weapon_prompt_sword_fail"),
		"recorded outcome reads true", failures)
	ChoiceDirector.record_outcome("weapon_prompt_sword_fail")  # 2nd call no-op
	_expect(Array(SaveSystem.state.get("choices_seen", [])).size() == 1,
		"record_outcome is idempotent", failures)

	# Counter math: seen=1, total >= number of distinct outcomes in catalogue.
	var total: int = ChoiceDirector.total_outcomes()
	_expect(total >= 3,
		"total outcomes counted across screens (got %d)" % total, failures)
	_expect(ChoiceDirector.seen_outcome_count() == 1,
		"seen count is 1 after one record", failures)

	# Empty outcome_id is ignored.
	ChoiceDirector.record_outcome("")
	_expect(ChoiceDirector.seen_outcome_count() == 1,
		"empty outcome_id is rejected", failures)

	# Restore.
	SaveSystem.state = snapshot
	SaveSystem.save()

	if failures.is_empty():
		print("[test_choice_director] All assertions passed.")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)

func _expect(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append("FAIL: " + message)
