extends RefCounted
class_name PhaseMachine

enum NarrativePhase {
	NORMAL_FIGHT,
	BOSS_HESITATES,
	BOSS_TALKS,
	EASTER_EGG_HUNT,
	FILE_BROWSER_UNLOCKED,
	BOSS_DELETED,
	ROLE_SWAP,
}

const EGGS_REQUIRED := 3

static func evaluate(state: Dictionary) -> int:
	if state.get("role_swap_active", false):
		return NarrativePhase.ROLE_SWAP
	if state.get("boss_deleted", false):
		return NarrativePhase.BOSS_DELETED
	var eggs: Array = state.get("easter_eggs_found", [])
	if eggs.size() >= EGGS_REQUIRED:
		return NarrativePhase.FILE_BROWSER_UNLOCKED
	var runs: int = int(state.get("total_runs", 0))
	if runs >= 8:
		return NarrativePhase.EASTER_EGG_HUNT
	if runs >= 5:
		return NarrativePhase.BOSS_TALKS
	if runs >= 3:
		return NarrativePhase.BOSS_HESITATES
	return NarrativePhase.NORMAL_FIGHT

static func phase_name(phase: int) -> String:
	match phase:
		NarrativePhase.NORMAL_FIGHT: return "NORMAL_FIGHT"
		NarrativePhase.BOSS_HESITATES: return "BOSS_HESITATES"
		NarrativePhase.BOSS_TALKS: return "BOSS_TALKS"
		NarrativePhase.EASTER_EGG_HUNT: return "EASTER_EGG_HUNT"
		NarrativePhase.FILE_BROWSER_UNLOCKED: return "FILE_BROWSER_UNLOCKED"
		NarrativePhase.BOSS_DELETED: return "BOSS_DELETED"
		NarrativePhase.ROLE_SWAP: return "ROLE_SWAP"
	return "NORMAL_FIGHT"

static func phase_from_name(name: String) -> int:
	match name:
		"NORMAL_FIGHT": return NarrativePhase.NORMAL_FIGHT
		"BOSS_HESITATES": return NarrativePhase.BOSS_HESITATES
		"BOSS_TALKS": return NarrativePhase.BOSS_TALKS
		"EASTER_EGG_HUNT": return NarrativePhase.EASTER_EGG_HUNT
		"FILE_BROWSER_UNLOCKED": return NarrativePhase.FILE_BROWSER_UNLOCKED
		"BOSS_DELETED": return NarrativePhase.BOSS_DELETED
		"ROLE_SWAP": return NarrativePhase.ROLE_SWAP
	return NarrativePhase.NORMAL_FIGHT
