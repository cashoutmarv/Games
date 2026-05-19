extends Node

# Owns which reveal layers of the four-layer reveal engine are active for the
# player. Each layer is unlocked permanently the first time the player clears
# the corresponding boss. Other systems read these flags to decide whether to
# surface inputs (parry/charge after hidden_depth), trigger clashes
# (after clash), or show prediction lines (after prediction).
#
# Persisted to SaveSystem.state.reveals_unlocked as an Array[String].

const LAYERS := ["hidden_depth", "clash", "prediction", "fourth_wall"]

signal reveal_unlocked(layer_id: String)

func is_unlocked(layer_id: String) -> bool:
	var u: Array = SaveSystem.state.get("reveals_unlocked", [])
	return u.has(layer_id)

func unlock(layer_id: String) -> void:
	if not LAYERS.has(layer_id):
		push_warning("RevealDirector: unknown layer id '%s'" % layer_id)
		return
	var u: Array = SaveSystem.state.get("reveals_unlocked", [])
	if u.has(layer_id):
		return
	u.append(layer_id)
	SaveSystem.state.reveals_unlocked = u
	SaveSystem.save()
	reveal_unlocked.emit(layer_id)

func get_unlocked() -> Array:
	return SaveSystem.state.get("reveals_unlocked", []).duplicate()

# Hidden-depth-gated inputs (parry / charge / dodge-cancel). These are
# called by player.gd to decide whether to accept the corresponding actions.
func parry_enabled() -> bool:
	return is_unlocked("hidden_depth")

func charge_enabled() -> bool:
	return is_unlocked("hidden_depth")

func dodge_cancel_enabled() -> bool:
	return is_unlocked("hidden_depth")
