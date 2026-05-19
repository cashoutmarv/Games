extends Node2D

# Orchestrates the F1 boss fight + its role-swap-on-death flow.
#
# Lifecycle:
#   1. Hero-side fight (existing $Boss attacks, $Player engages).
#   2. Hero dies → BossSwap.request_swap → swap announcement.
#   3. Boss-side play: $Boss hidden, a player-controlled boss spawns,
#      waves of hero-AI run in. Win condition: clear all waves. Loss
#      condition: more boss-side deaths than the boss config allows.
#   4. Return announcement → hero respawns with the inherited ability
#      + bonus damage; boss resets to full HP.

const PhaseMachine := preload("res://scripts/systems/phase_machine.gd")
const SwapAnnouncementScene := preload("res://scenes/ui/swap_announcement.tscn")
const PlayerScene := preload("res://scenes/actors/player.tscn")
const HeroAIScene := preload("res://scenes/actors/hero_ai.tscn")

signal boss_defeated
signal player_died
signal player_respawned(player: Node)

@export var boss_id: String = "boss_floor_1"

@onready var _boss: Node = $Boss
@onready var _dialogue_box: PanelContainer = $UI/DialogueBox

var _swap_overlay: CanvasLayer = null
var _boss_side_player: Node = null
var _hero_ais: Array[Node] = []
var _boss_side_wave: int = 0
var _orig_boss_position: Vector2 = Vector2.ZERO
var _hero_spawn_position: Vector2 = Vector2(540, 1500)
var _boss_config: Dictionary = {}

func _ready() -> void:
	_load_boss_config()
	_orig_boss_position = _boss.global_position
	if _boss.has_signal("defeated"):
		_boss.connect("defeated", _on_boss_defeated)
	if _boss.has_signal("wants_to_talk"):
		_boss.connect("wants_to_talk", _on_boss_talk)
	# The active hero player is owned by run.gd and reparented in. Wire it
	# on the next frame after the reparent has settled.
	call_deferred("_wire_active_hero_player")
	BossSwap.reset_for_new_run()
	BossSwap.swap_requested.connect(_on_swap_requested)
	BossSwap.boss_side_won.connect(_on_boss_side_won)
	# Greet the player with the boss's intro line.
	var intro: String = _config_dialog("intro")
	if intro != "":
		_dialogue_box.show_line(intro, 3.5)

func _load_boss_config() -> void:
	if not FileAccess.file_exists("res://data/bosses.json"):
		return
	var f := FileAccess.open("res://data/bosses.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has(boss_id):
		_boss_config = parsed[boss_id]

func _config_dialog(key: String) -> String:
	var d: Dictionary = _boss_config.get("dialogue", {})
	return d.get(key, "")

func _wire_active_hero_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p == _boss_side_player:
			continue
		if "swap_boss_id" in p:
			p.set("swap_boss_id", boss_id)
		if p.has_signal("died") and not p.is_connected("died", _on_player_died):
			p.connect("died", _on_player_died)
		if p.has_signal("death_intercepted_by_swap") and not p.is_connected("death_intercepted_by_swap", _on_death_intercepted):
			p.connect("death_intercepted_by_swap", _on_death_intercepted)
		if p.has_signal("rewound") and not p.is_connected("rewound", _on_player_rewound):
			p.connect("rewound", _on_player_rewound)
		return

func _on_boss_talk(line: String) -> void:
	_dialogue_box.show_line(line, 3.5)

func _on_boss_defeated() -> void:
	if BossSwap.current_state != BossSwap.SwapState.HERO:
		# Boss-side play has its own win/loss path; ignore stray boss signals.
		return
	boss_defeated.emit()

func _on_player_died() -> void:
	if BossSwap.current_state == BossSwap.SwapState.HERO:
		# Hero-side death NOT routed through BossSwap (no swap_boss_id set
		# or BossSwap was busy). End the run.
		player_died.emit()

func _on_death_intercepted(_boss_id: String) -> void:
	# Hero-side death routed through BossSwap. Announcement will appear
	# shortly via _on_swap_requested.
	pass

func _on_player_rewound(is_first_ever: bool) -> void:
	# Cinematic placeholder: full overlay on first ever, brief tint flash after.
	var msg: String = "TIME — REWIND." if is_first_ever else "again."
	_dialogue_box.show_line(msg, 2.0 if is_first_ever else 0.8)

# ---- Swap flow -----------------------------------------------------------

func _on_swap_requested(_boss_id: String, is_first_ever: bool) -> void:
	_show_swap_announcement(is_first_ever)

func _show_swap_announcement(is_first_ever: bool) -> void:
	_swap_overlay = SwapAnnouncementScene.instantiate()
	add_child(_swap_overlay)
	_swap_overlay.show_for_swap(is_first_ever)
	_swap_overlay.acknowledged.connect(_on_swap_overlay_acknowledged, CONNECT_ONE_SHOT)

func _on_swap_overlay_acknowledged() -> void:
	_dismiss_overlay()
	BossSwap.acknowledge_swap_announcement()
	_begin_boss_side_play()

func _begin_boss_side_play() -> void:
	# Hide and disable the original hero-side boss.
	_set_hero_boss_active(false)
	# Speak the boss-side intro.
	var line: String = _config_dialog("boss_side_intro")
	if line != "":
		_dialogue_box.show_line(line, 3.5)
	_boss_side_wave = 0
	_spawn_boss_side_player()
	_spawn_current_wave()

func _set_hero_boss_active(active: bool) -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	_boss.visible = active
	_boss.set_physics_process(active)
	_boss.set_process(active)
	if active:
		if not _boss.is_in_group("boss"):
			_boss.add_to_group("boss")
	else:
		# Disabled — drop out of the boss group so projectiles don't hit it.
		if _boss.is_in_group("boss"):
			_boss.remove_from_group("boss")

func _spawn_boss_side_player() -> void:
	_boss_side_player = PlayerScene.instantiate()
	_boss_side_player.set("is_boss_side", true)
	_boss_side_player.set("swap_boss_id", "")  # don't re-route death through swap
	add_child(_boss_side_player)
	_boss_side_player.global_position = _orig_boss_position
	if _boss_side_player.has_signal("died"):
		_boss_side_player.connect("died", _on_boss_side_player_died)
	# Re-wire the joystick to this new player.
	_emit_player_respawned(_boss_side_player)

func _spawn_current_wave() -> void:
	var waves: Array = _boss_config.get("boss_side", {}).get("hero_ai_wave", [])
	if waves.is_empty() or _boss_side_wave >= waves.size():
		# No more waves to fight — boss-side win.
		BossSwap.notify_boss_side_won()
		return
	var wave: Dictionary = waves[_boss_side_wave]
	var count: int = int(wave.get("count", 1))
	for i in count:
		_spawn_hero_ai(wave, i, count)

func _spawn_hero_ai(wave: Dictionary, index: int, total: int) -> void:
	var ai: Node = HeroAIScene.instantiate()
	ai.set("max_hp", int(wave.get("hp", 60)))
	ai.set("move_speed", float(wave.get("speed", 130.0)))
	ai.set("damage", int(wave.get("damage", 8)))
	add_child(ai)
	# Spread spawn positions across the lower half of the arena.
	var x_step: float = 1080.0 / float(total + 1)
	ai.global_position = Vector2(x_step * float(index + 1), 1600.0)
	if ai.has_signal("died"):
		ai.connect("died", _on_hero_ai_died.bind(ai))
	_hero_ais.append(ai)

func _on_hero_ai_died(ai: Node) -> void:
	_hero_ais.erase(ai)
	# Clear any null/dead references.
	_hero_ais = _hero_ais.filter(func(n): return is_instance_valid(n))
	if _hero_ais.is_empty():
		_boss_side_wave += 1
		var waves: Array = _boss_config.get("boss_side", {}).get("hero_ai_wave", [])
		if _boss_side_wave >= waves.size():
			BossSwap.notify_boss_side_won()
		else:
			_spawn_current_wave()

func _on_boss_side_player_died() -> void:
	BossSwap.notify_boss_side_death()
	_boss_side_player = null
	var max_deaths: int = int(_boss_config.get("boss_side", {}).get("max_deaths_before_run_ends", 3))
	if BossSwap.boss_side_deaths_this_fight >= max_deaths:
		# Out of lives — end the run as a loss.
		_clear_boss_side()
		player_died.emit()
		return
	# Otherwise respawn the boss-side player and reset the current wave.
	_clear_hero_ais()
	_boss_side_wave = max(0, _boss_side_wave)
	_spawn_boss_side_player()
	_spawn_current_wave()

func _on_boss_side_won(_boss_id: String, ability_id: String, bonus_damage: int) -> void:
	# Wrap up boss-side combat and show the return announcement.
	_clear_boss_side()
	var line: String = _config_dialog("boss_side_win")
	if line != "":
		_dialogue_box.show_line(line, 3.0)
	var label: String = _ability_label(ability_id)
	_swap_overlay = SwapAnnouncementScene.instantiate()
	add_child(_swap_overlay)
	_swap_overlay.show_for_return(label, bonus_damage)
	_swap_overlay.acknowledged.connect(_on_return_overlay_acknowledged.bind(bonus_damage), CONNECT_ONE_SHOT)

func _on_return_overlay_acknowledged(bonus_damage: int) -> void:
	_dismiss_overlay()
	BossSwap.acknowledge_return()
	_apply_run_bonus(bonus_damage)
	_reset_hero_boss()
	_respawn_hero_player(bonus_damage)

func _apply_run_bonus(amount: int) -> void:
	# Bonus damage carries to hero-side for the remainder of the run.
	if amount <= 0:
		return
	if "damage_bonus" in RunState:
		RunState.damage_bonus = int(RunState.damage_bonus) + amount

func _reset_hero_boss() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	_set_hero_boss_active(true)
	_boss.global_position = _orig_boss_position
	# Reset HP and phase by re-running setup. The script sets these in _ready.
	if "max_hp" in _boss:
		_boss.set("hp", int(_boss.get("max_hp")))
	if "_defeated" in _boss:
		_boss.set("_defeated", false)
	if _boss.has_signal("hp_changed"):
		_boss.emit_signal("hp_changed", int(_boss.get("max_hp")), int(_boss.get("max_hp")))

func _respawn_hero_player(bonus_damage: int) -> void:
	var p: Node = PlayerScene.instantiate()
	p.set("swap_boss_id", boss_id)
	p.set("bonus_damage", bonus_damage)
	add_child(p)
	p.global_position = _hero_spawn_position
	if p.has_signal("died"):
		p.connect("died", _on_player_died)
	if p.has_signal("death_intercepted_by_swap"):
		p.connect("death_intercepted_by_swap", _on_death_intercepted)
	if p.has_signal("rewound"):
		p.connect("rewound", _on_player_rewound)
	_emit_player_respawned(p)

func _emit_player_respawned(p: Node) -> void:
	player_respawned.emit(p)

func _clear_hero_ais() -> void:
	for ai in _hero_ais:
		if is_instance_valid(ai):
			ai.queue_free()
	_hero_ais.clear()

func _clear_boss_side() -> void:
	_clear_hero_ais()
	if _boss_side_player != null and is_instance_valid(_boss_side_player):
		_boss_side_player.queue_free()
	_boss_side_player = null
	_boss_side_wave = 0

func _dismiss_overlay() -> void:
	if _swap_overlay != null and is_instance_valid(_swap_overlay):
		_swap_overlay.queue_free()
		_swap_overlay = null

func _ability_label(ability_id: String) -> String:
	if ability_id == "":
		return "(nothing)"
	var cfg: Dictionary = BossSwap.get_ability_config(ability_id)
	return cfg.get("label", ability_id)
