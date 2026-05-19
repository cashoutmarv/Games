extends Node

const ArenaScene := preload("res://scenes/arena.tscn")
const BossRoomScene := preload("res://scenes/boss_room.tscn")
const MainMenuScene := preload("res://scenes/main_menu.tscn")
const PlayerScene := preload("res://scenes/actors/player.tscn")

const RUN_DURATION_SECONDS := 600.0  # 10 minutes
const ARENA_PLAYER_SPAWN := Vector2(540, 1500)
const BOSS_ROOM_PLAYER_SPAWN := Vector2(540, 1500)

@onready var _stage: Node = $Stage
@onready var _hud: CanvasLayer = $HUD
@onready var _timer_label: Label = $HUD/TimerLabel

var _arena: Node = null
var _boss_room: Node = null
var _player: Node = null
var _time_left: float = RUN_DURATION_SECONDS

func _ready() -> void:
	RunState.start_run()
	_spawn_player(ARENA_PLAYER_SPAWN)
	_load_arena()

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
	if _arena.has_signal("exit_to_boss"):
		_arena.connect("exit_to_boss", _enter_boss_room)

func _enter_boss_room() -> void:
	if _arena != null:
		_arena.queue_free()
		_arena = null
	_boss_room = BossRoomScene.instantiate()
	_stage.add_child(_boss_room)
	# Move the existing player into the new room and reposition.
	if _player != null and is_instance_valid(_player):
		_player.get_parent().remove_child(_player)
		_boss_room.add_child(_player)
		_player.global_position = BOSS_ROOM_PLAYER_SPAWN
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
	_finish(true)

func _on_player_died() -> void:
	_finish(false)

func _finish(won: bool) -> void:
	if not RunState.run_in_progress:
		return
	RunState.end_run(won)
	get_tree().change_scene_to_packed(MainMenuScene)
