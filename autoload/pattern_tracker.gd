extends Node

# Tracks the player's behavioral patterns across runs. Used by the F2 boss
# clash AI to bias counter-picks, and queryable by future systems
# (Yomi-flavored reads, F3 prediction).
#
# In-memory only for v4; persisted to save in a later phase if/when it
# carries narrative weight.

const _MAX_HISTORY: int = 32

var _clash_picks: Array[String] = []
var _parry_count: int = 0
var _dodge_count: int = 0

func record_clash_pick(pick: String) -> void:
	_clash_picks.append(pick)
	if _clash_picks.size() > _MAX_HISTORY:
		_clash_picks.pop_front()

func most_recent_clash_pick() -> String:
	if _clash_picks.is_empty():
		return ""
	return _clash_picks[-1]

func most_frequent_clash_pick() -> String:
	if _clash_picks.is_empty():
		return ""
	var counts: Dictionary = {}
	for p in _clash_picks:
		counts[p] = int(counts.get(p, 0)) + 1
	var best_pick: String = ""
	var best_count: int = -1
	for k in counts.keys():
		if int(counts[k]) > best_count:
			best_count = int(counts[k])
			best_pick = String(k)
	return best_pick

func clash_pick_count() -> int:
	return _clash_picks.size()

func record_parry() -> void:
	_parry_count += 1

func record_dodge() -> void:
	_dodge_count += 1

func parry_count() -> int:
	return _parry_count

func dodge_count() -> int:
	return _dodge_count

func reset() -> void:
	_clash_picks.clear()
	_parry_count = 0
	_dodge_count = 0
