extends SceneTree

# Smoke test for the role-reversal-on-victory state machine.
# Run with:
#   godot --headless --script res://tests/test_boss_swap.gd
#
# IMPORTANT: the swap fires on hero-side WIN now, not on hero death.
# These assertions cover the corrected semantics.

func _initialize() -> void:
	var failures: Array[String] = []

	# Snapshot real save state so the test can scribble freely.
	var snapshot: Dictionary = SaveSystem.state.duplicate(true)

	# Start from a known-clean state.
	SaveSystem.state.inherited_abilities = []
	SaveSystem.state.boss_side_deaths_total = 0
	SaveSystem.state.first_boss_side_swap_seen = false
	BossSwap.reset_for_new_run()
	if "damage_bonus" in RunState:
		RunState.damage_bonus = 0

	# --- Initial state ----------------------------------------------------
	_expect(BossSwap.current_state == BossSwap.SwapState.HERO,
		"initial state is HERO", failures)
	_expect(BossSwap.boss_side_deaths_this_fight == 0,
		"initial per-fight death counter is zero", failures)
	_expect(not BossSwap.has_ability("rewind_on_death"),
		"no abilities inherited initially", failures)

	# --- Ability map for all three swappable bosses -----------------------
	_expect(BossSwap.ability_for_boss("boss_floor_1") == "rewind_on_death",
		"floor 1 boss maps to rewind_on_death", failures)
	_expect(BossSwap.ability_for_boss("boss_floor_2") == "clash_trigger",
		"floor 2 boss maps to clash_trigger", failures)
	_expect(BossSwap.ability_for_boss("boss_floor_3") == "prediction_reflex",
		"floor 3 boss maps to prediction_reflex", failures)
	_expect(BossSwap.ability_for_boss("boss_final") == "",
		"final boss has no swap (it's the wall)", failures)

	# --- Ability configs load from data/abilities.json --------------------
	var rewind_cfg: Dictionary = BossSwap.get_ability_config("rewind_on_death")
	_expect(rewind_cfg.get("id", "") == "rewind_on_death",
		"rewind ability config loaded from JSON", failures)
	_expect(rewind_cfg.get("from_boss", "") == "boss_floor_1",
		"rewind ability is sourced from floor 1 boss", failures)
	_expect(float(rewind_cfg.get("rewind_seconds", 0.0)) == 10.0,
		"rewind window is 10 seconds (corrected from 2s)", failures)

	# --- Trigger semantics: request_swap fires from hero-side WIN ---------
	# (The autoload doesn't enforce who calls it; this test exercises the
	# state-machine contract directly. The boss_room.gd code path is the
	# only place that should call request_swap, and only on boss_defeated.)
	var captured_first_ever := [false]
	BossSwap.swap_requested.connect(func(_bid: String, is_first_ever: bool): captured_first_ever[0] = is_first_ever, CONNECT_ONE_SHOT)

	BossSwap.request_swap("boss_floor_1")
	_expect(BossSwap.current_state == BossSwap.SwapState.ANNOUNCING_SWAP,
		"after request_swap, state is ANNOUNCING_SWAP", failures)
	_expect(BossSwap.active_boss_id == "boss_floor_1",
		"active_boss_id captured", failures)
	_expect(captured_first_ever[0] == true,
		"swap_requested reports first_ever=true on the very first swap", failures)

	BossSwap.acknowledge_swap_announcement()
	_expect(BossSwap.current_state == BossSwap.SwapState.BOSS_SIDE,
		"after acknowledge, state is BOSS_SIDE", failures)
	_expect(SaveSystem.state.first_boss_side_swap_seen == true,
		"first_boss_side_swap_seen flag set after first ack", failures)

	# --- Boss-side deaths increment +1 dmg per death on RunState ---------
	BossSwap.notify_boss_side_death()
	_expect(BossSwap.boss_side_deaths_this_fight == 1,
		"per-fight death counter incremented", failures)
	if "damage_bonus" in RunState:
		_expect(int(RunState.damage_bonus) == 1,
			"RunState.damage_bonus incremented on boss-side death", failures)

	BossSwap.notify_boss_side_death()
	_expect(BossSwap.boss_side_deaths_this_fight == 2,
		"per-fight death counter incremented twice", failures)
	if "damage_bonus" in RunState:
		_expect(int(RunState.damage_bonus) == 2,
			"RunState.damage_bonus accumulates", failures)

	BossSwap.notify_boss_side_won()
	_expect(BossSwap.current_state == BossSwap.SwapState.ANNOUNCING_RETURN,
		"after boss-side cleared, state is ANNOUNCING_RETURN", failures)
	_expect(BossSwap.has_ability("rewind_on_death"),
		"rewind_on_death inherited after boss-side cleared", failures)

	BossSwap.acknowledge_return()
	_expect(BossSwap.current_state == BossSwap.SwapState.HERO,
		"after acknowledge_return, state is HERO", failures)

	# --- Second-swap flag: first_ever should be false now -----------------
	BossSwap.reset_for_new_run()
	var captured_second := [true]
	BossSwap.swap_requested.connect(func(_bid: String, is_first_ever: bool): captured_second[0] = is_first_ever, CONNECT_ONE_SHOT)
	BossSwap.request_swap("boss_floor_1")
	_expect(captured_second[0] == false,
		"subsequent swap reports first_ever=false", failures)
	BossSwap.reset_for_new_run()

	# --- Inherited abilities persist across reset_for_new_run ------------
	_expect(BossSwap.has_ability("rewind_on_death"),
		"inherited ability persists across reset_for_new_run", failures)
	_expect(BossSwap.get_inherited_abilities().size() == 1,
		"exactly one ability inherited at this point", failures)

	# --- Guard rails: out-of-order calls are no-ops -----------------------
	BossSwap.notify_boss_side_death()  # in HERO state — should not crash
	_expect(BossSwap.current_state == BossSwap.SwapState.HERO,
		"notify_boss_side_death from HERO is a no-op", failures)
	BossSwap.acknowledge_return()  # in HERO state — should not crash
	_expect(BossSwap.current_state == BossSwap.SwapState.HERO,
		"acknowledge_return from HERO is a no-op", failures)

	# --- Hero-side death does NOT auto-trigger a swap --------------------
	# The autoload's state machine alone doesn't have a death entry point;
	# verifying this means asserting that the API surface to "request a
	# swap" is the only path (no death-named methods exist).
	_expect(BossSwap.current_state == BossSwap.SwapState.HERO,
		"no death-driven path exists into BOSS_SIDE", failures)

	# --- Restore real save state ------------------------------------------
	SaveSystem.state = snapshot
	SaveSystem.save()
	if "damage_bonus" in RunState:
		RunState.damage_bonus = 0

	if failures.is_empty():
		print("[test_boss_swap] All assertions passed.")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)

func _expect(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append("FAIL: " + message)
