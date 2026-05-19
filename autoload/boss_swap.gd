extends Node

# Role-swap-on-death state machine and ability-inheritance store.
#
# Pillar 4 of the GDD: dying in a boss fight does not end the run — the player
# flips to the BOSS seat for the rest of the fight. Winning boss-side returns
# the player as hero with that boss's signature ability inherited, plus +1
# permanent damage per boss-side death accumulated this fight.
#
# This autoload owns the STATE and DATA. The gameplay reaction (boss responds
# to input, hero-AI spawns, scene transitions) is wired by individual boss
# rooms via the signals below.

const ABILITIES_PATH := "res://data/abilities.json"

enum SwapState {
	HERO,                # Player is in hero seat, normal play.
	ANNOUNCING_SWAP,     # Hero just died, swap announcement (cinematic on first ever) is up.
	BOSS_SIDE,           # Player is controlling the boss; hero-AI is the threat.
	ANNOUNCING_RETURN,   # Boss-side won; return-to-hero announcement is up.
}

signal swap_requested(boss_id: String, is_first_ever: bool)
signal swap_announcement_acknowledged
signal boss_side_started(boss_id: String)
signal boss_side_death_occurred(boss_id: String, deaths_this_fight: int)
signal boss_side_won(boss_id: String, ability_id: String, bonus_damage: int)
signal hero_returned(boss_id: String, ability_id: String, bonus_damage: int)

var current_state: int = SwapState.HERO
var active_boss_id: String = ""
var boss_side_deaths_this_fight: int = 0
var first_boss_side_death_seen_cinematic: bool = false

# Loaded once at ready; maps ability_id -> ability config dict.
var _abilities: Dictionary = {}
# Maps boss_id -> ability_id that boss bestows on inheritance.
var _boss_ability_map: Dictionary = {
	"boss_floor_1": "rewind_on_death",
	"boss_floor_2": "clash_trigger",
	"boss_floor_3": "prediction_reflex",
}

func _ready() -> void:
	_load_abilities()

func _load_abilities() -> void:
	if not FileAccess.file_exists(ABILITIES_PATH):
		push_warning("BossSwap: abilities.json not found at %s" % ABILITIES_PATH)
		return
	var f := FileAccess.open(ABILITIES_PATH, FileAccess.READ)
	if f == null:
		push_warning("BossSwap: could not open abilities.json")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("BossSwap: abilities.json malformed")
		return
	_abilities = parsed

# ---- Public API ----------------------------------------------------------

# Called by a boss room when the player's hero seat dies during the fight.
# Routes through the swap flow instead of ending the run.
func request_swap(boss_id: String) -> void:
	if current_state != SwapState.HERO:
		push_warning("BossSwap: request_swap while not in HERO state (%s)" % current_state)
		return
	active_boss_id = boss_id
	current_state = SwapState.ANNOUNCING_SWAP
	boss_side_deaths_this_fight = 0
	var is_first := not SaveSystem.state.get("first_boss_side_swap_seen", false)
	swap_requested.emit(boss_id, is_first)

# Called from the swap announcement UI when the player dismisses it.
func acknowledge_swap_announcement() -> void:
	if current_state != SwapState.ANNOUNCING_SWAP:
		return
	if not SaveSystem.state.get("first_boss_side_swap_seen", false):
		SaveSystem.state.first_boss_side_swap_seen = true
		SaveSystem.save()
	current_state = SwapState.BOSS_SIDE
	swap_announcement_acknowledged.emit()
	boss_side_started.emit(active_boss_id)

# Called by the boss room when the player (now boss-side) dies.
# Each death grants +1 base damage that compounds for the rest of the run,
# and the first death uses the cinematic teaching beat for the perk being
# tested in this boss-side play.
func notify_boss_side_death() -> void:
	if current_state != SwapState.BOSS_SIDE:
		return
	boss_side_deaths_this_fight += 1
	SaveSystem.state.boss_side_deaths_total = int(SaveSystem.state.get("boss_side_deaths_total", 0)) + 1
	SaveSystem.save()
	# Per-run accumulating damage bonus carried into the next floor.
	if "damage_bonus" in RunState:
		RunState.damage_bonus = int(RunState.damage_bonus) + 1
	boss_side_death_occurred.emit(active_boss_id, boss_side_deaths_this_fight)

# Called by the boss room when boss-side play has been cleared (all incoming
# hero-AI waves KO'd). Locks in the perk inheritance and announces the
# transition to the next floor.
func notify_boss_side_won() -> void:
	if current_state != SwapState.BOSS_SIDE:
		return
	var ability_id: String = _boss_ability_map.get(active_boss_id, "")
	var bonus_damage: int = boss_side_deaths_this_fight
	if ability_id != "" and not has_ability(ability_id):
		var inherited: Array = SaveSystem.state.get("inherited_abilities", [])
		inherited.append(ability_id)
		SaveSystem.state.inherited_abilities = inherited
		SaveSystem.save()
	current_state = SwapState.ANNOUNCING_RETURN
	boss_side_won.emit(active_boss_id, ability_id, bonus_damage)

# Called when control returns to the hero seat (after the return announcement).
func acknowledge_return() -> void:
	if current_state != SwapState.ANNOUNCING_RETURN:
		return
	var ability_id: String = _boss_ability_map.get(active_boss_id, "")
	var bonus_damage: int = boss_side_deaths_this_fight
	var bid := active_boss_id
	current_state = SwapState.HERO
	hero_returned.emit(bid, ability_id, bonus_damage)

# Reset state if a run ends without swap resolution (e.g. quit-to-menu).
func reset_for_new_run() -> void:
	current_state = SwapState.HERO
	active_boss_id = ""
	boss_side_deaths_this_fight = 0

# ---- Queries -------------------------------------------------------------

func has_ability(ability_id: String) -> bool:
	var inherited: Array = SaveSystem.state.get("inherited_abilities", [])
	return inherited.has(ability_id)

func get_ability_config(ability_id: String) -> Dictionary:
	return _abilities.get(ability_id, {})

func get_inherited_abilities() -> Array:
	return SaveSystem.state.get("inherited_abilities", []).duplicate()

func get_boss_side_deaths_total() -> int:
	return int(SaveSystem.state.get("boss_side_deaths_total", 0))

# Ability for a given boss id. Used by UI and tests.
func ability_for_boss(boss_id: String) -> String:
	return _boss_ability_map.get(boss_id, "")
