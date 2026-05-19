extends Node

# Owns ending-state bookkeeping and gate evaluation.
#
# v5 ships ending 1 (the "true" ending) — triggered when the final boss
# is defeated for the first time. The true-true gate logic and quit-the-
# app cutscene land in v6.

const TRUE_ENDING_ID := "true"
const TRUE_TRUE_ENDING_ID := "true_true"
const TRUE_TRUE_DELAY_HOURS: float = 12.0

signal ending_completed(ending_id: String)

func has_seen_ending(ending_id: String) -> bool:
	var seen: Array = SaveSystem.state.get("endings_seen", [])
	return seen.has(ending_id)

func mark_true_ending_complete() -> void:
	var was_seen: bool = has_seen_ending(TRUE_ENDING_ID)
	SaveSystem.mark_ending_seen(TRUE_ENDING_ID)
	if not was_seen:
		ending_completed.emit(TRUE_ENDING_ID)

# True-true gate: ending 1 seen AND a real-time delay has elapsed since
# the recorded completion timestamp. v6 will hook this; v5 just defines
# the predicate so other systems can query it without a separate impl.
func is_true_true_gate_ready() -> bool:
	if not has_seen_ending(TRUE_ENDING_ID):
		return false
	if has_seen_ending(TRUE_TRUE_ENDING_ID):
		return false
	var iso: String = String(SaveSystem.state.get("ending_one_completed_at_iso", ""))
	if iso == "":
		return false
	var dt_then: Dictionary = Time.get_datetime_dict_from_datetime_string(iso, true)
	if dt_then.is_empty():
		return false
	var ts_then: int = Time.get_unix_time_from_datetime_dict(dt_then)
	var ts_now: int = Time.get_unix_time_from_system()
	var elapsed_hours: float = float(ts_now - ts_then) / 3600.0
	return elapsed_hours >= TRUE_TRUE_DELAY_HOURS
