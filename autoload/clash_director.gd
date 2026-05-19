extends Node

# Orchestrates the F2-style clash mini-game.
#
# Trigger conditions (any of):
#  - Player parries an F2 (or later) boss projectile.
#  - Boss reaches a cinematic phase-transition threshold.
#  - Player force-triggers via the clash_trigger perk (post-F2 inheritance).
#
# Flow: caller awaits `trigger_clash(boss, parent)` and gets back a winner
# string ("player" | "boss" | "tie"). The director handles the overlay
# scene, boss-side pick computation (via PatternTracker), and resolution.

const ClashScene := preload("res://scenes/ui/clash.tscn")

# Option triangle: BREAK beats FAKE, FAKE beats COMMIT, COMMIT beats BREAK.
const OPTIONS: Array = ["BREAK", "FAKE", "COMMIT"]
const BEATS: Dictionary = {  # winner → loser
	"BREAK": "FAKE",
	"FAKE": "COMMIT",
	"COMMIT": "BREAK",
}

signal clash_started(boss_pick: String)
signal clash_resolved(winner: String, player_pick: String, boss_pick: String)

var _active: bool = false

func is_clash_active() -> bool:
	return _active

# Spawn a clash overlay parented to `parent`, await the player's pick,
# compute the boss pick, resolve, and return the winner string.
func trigger_clash(_boss_node: Node, parent: Node) -> String:
	if _active:
		return "tie"
	_active = true
	var boss_pick: String = _compute_boss_pick()
	var overlay: CanvasLayer = ClashScene.instantiate()
	parent.add_child(overlay)
	overlay.set_boss_pick(boss_pick)
	clash_started.emit(boss_pick)
	var resolved: Array = await overlay.resolved
	var winner: String = resolved[0] if resolved.size() > 0 else "tie"
	var player_pick: String = resolved[1] if resolved.size() > 1 else ""
	if player_pick != "":
		PatternTracker.record_clash_pick(player_pick)
	overlay.queue_free()
	clash_resolved.emit(winner, player_pick, boss_pick)
	_active = false
	return winner

# Pure resolution of two picks. Public so tests can hit it directly.
func resolve_picks(player_pick: String, boss_pick: String) -> String:
	if player_pick == boss_pick:
		return "tie"
	if BEATS.get(player_pick, "") == boss_pick:
		return "player"
	return "boss"

# Boss bias logic: counter the player's most-recent clash pick. Falls
# through to a random pick on the first clash of the run.
func _compute_boss_pick() -> String:
	var counter: Dictionary = {"BREAK": "COMMIT", "FAKE": "BREAK", "COMMIT": "FAKE"}
	var recent: String = PatternTracker.most_recent_clash_pick()
	if recent != "" and counter.has(recent):
		return String(counter[recent])
	return OPTIONS[randi() % OPTIONS.size()]
