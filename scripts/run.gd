extends Node

const ArenaScene := preload("res://scenes/arena.tscn")
const BossRoomScene := preload("res://scenes/boss_room.tscn")
const DesktopHubScene := preload("res://scenes/desktop_hub.tscn")
const EndingTrueScene := preload("res://scenes/endings/ending_true.tscn")
const PlayerScene := preload("res://scenes/actors/player.tscn")

const RUN_DURATION_SECONDS := 600.0  # 10 minutes
const ARENA_PLAYER_SPAWN := Vector2(540, 1500)
const BOSS_ROOM_PLAYER_SPAWN := Vector2(540, 1500)
const FINAL_FLOOR: int = 4

@onready var _stage: Node = $Stage
@onready var _hud: CanvasLayer = $HUD
@onready var _timer_label: Label = $HUD/TimerLabel

var _arena: Node = null
var _boss_room: Node = null
var _player: Node = null
var _time_left: float = RUN_DURATION_SECONDS

func _ready() -> void:
	# Restore the OS title bar if the player is closing the window — F4's
	# cheat title-bar writes shouldn't bleed across into the next session.
	get_tree().root.close_requested.connect(_on_window_close_requested)
	# Guard: a weapon must be chosen before the arena loads. If the player
	# entered run.tscn directly without going through weapon_input (e.g.
	# from a deep link), bounce them to the prompt.
	if RunState.weapon_data.is_empty():
		var weapon_scene: PackedScene = load("res://scenes/ui/weapon_input.tscn")
		call_deferred("_bounce_to_scene", weapon_scene)
		return
	RunState.start_run()
	# Load arena first so the player (added after) renders on top of its
	# background.
	_load_arena()
	_spawn_player(ARENA_PLAYER_SPAWN)

func _on_window_close_requested() -> void:
	DisplayServer.window_set_title("Boss Battle Belay")

func _bounce_to_scene(packed: PackedScene) -> void:
	get_tree().change_scene_to_packed(packed)

func _spawn_player(at: Vector2) -> void:
	_player = PlayerScene.instantiate()
	_stage.add_child(_player)
	_player.global_position = at
	if _player.has_signal("died") and not _player.is_connected("died", _on_player_died):
		_player.connect("died", _on_player_died)
	_wire_joystick_to(_player)

func _load_arena() -> void:
	if _arena != null:
		_arena.queue_free()
	_arena = ArenaScene.instantiate()
	_stage.add_child(_arena)
	if _arena.has_method("configure_for_floor"):
		_arena.configure_for_floor(RunState.current_floor)
	if _arena.has_signal("exit_to_boss"):
		_arena.connect("exit_to_boss", _enter_boss_room)

func _enter_boss_room() -> void:
	if _arena != null:
		_arena.queue_free()
		_arena = null
	_boss_room = BossRoomScene.instantiate()
	# Set boss_id from current floor BEFORE adding to tree so _ready picks
	# the right config. The final floor uses "boss_final" rather than
	# "boss_floor_4" to match the GDD's framing.
	var boss_id: String
	if RunState.current_floor >= FINAL_FLOOR:
		boss_id = "boss_final"
	else:
		boss_id = "boss_floor_%d" % RunState.current_floor
	_boss_room.set("boss_id", boss_id)
	_stage.add_child(_boss_room)
	# Move the existing player into the new room and reposition.
	if _player != null and is_instance_valid(_player):
		_player.get_parent().remove_child(_player)
		_boss_room.add_child(_player)
		_player.global_position = BOSS_ROOM_PLAYER_SPAWN
		# Reset HP for the new fight.
		if "max_hp" in _player:
			_player.set("hp", int(_player.get("max_hp")))
			if _player.has_signal("hp_changed"):
				_player.emit_signal("hp_changed", int(_player.get("hp")), int(_player.get("max_hp")))
	RunState.mark_reached_boss_room()
	if _boss_room.has_signal("boss_defeated"):
		_boss_room.connect("boss_defeated", _on_boss_defeated)
	if _boss_room.has_signal("player_died"):
		_boss_room.connect("player_died", _on_player_died)
	if _boss_room.has_signal("player_respawned"):
		_boss_room.connect("player_respawned", _on_player_respawned)

func _wire_joystick_to(player: Node) -> void:
	if not is_instance_valid(player):
		return
	if _hud.has_node("Joystick"):
		var js: Node = _hud.get_node("Joystick")
		var cb := Callable(player, "set_steer")
		if not js.is_connected("steer_changed", cb):
			js.connect("steer_changed", cb)
	if _hud.has_method("bind_player"):
		_hud.bind_player(player)

func _on_player_respawned(player: Node) -> void:
	_player = player
	# Boss-side player deaths are handled inside the boss room (they feed
	# the boss-side death counter and don't end the run by themselves), so
	# don't wire run's run-ending `died` handler in that case.
	if not bool(player.get("is_boss_side")):
		if player.has_signal("died") and not player.is_connected("died", _on_player_died):
			player.connect("died", _on_player_died)
	_wire_joystick_to(player)

func _process(delta: float) -> void:
	if not RunState.run_in_progress:
		return
	_time_left = max(0.0, _time_left - delta)
	_timer_label.text = _format_time(_time_left)
	if _time_left <= 0.0:
		_finish(false)

func _format_time(seconds: float) -> String:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	return "%02d:%02d" % [m, s]

func _on_boss_defeated() -> void:
	# Floor cleared. F1–F3 do boss-side then advance; F4 (final) skips
	# boss-side and runs the ending instead.
	if RunState.current_floor >= FINAL_FLOOR:
		EndingDirector.mark_true_ending_complete()
		RunState.end_run(true)
		# Reset cosmetic title bar before leaving the run.
		DisplayServer.window_set_title("Boss Battle Belay")
		get_tree().change_scene_to_packed(EndingTrueScene)
		return
	RunState.current_floor += 1
	_advance_to_next_floor()

func _advance_to_next_floor() -> void:
	# Tear down the just-cleared boss room (the boss-side player was already
	# queue_freed before the ONWARD announcement). Spawn a fresh hero for
	# the new floor's arena.
	if _boss_room != null and is_instance_valid(_boss_room):
		_boss_room.queue_free()
		_boss_room = null
	# Discard any stale player reference.
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	_player = null
	_load_arena()
	_spawn_player(ARENA_PLAYER_SPAWN)

func _on_player_died() -> void:
	_finish(false)

func _finish(won: bool) -> void:
	if not RunState.run_in_progress:
		return
	RunState.end_run(won)
	get_tree().change_scene_to_packed(DesktopHubScene)
