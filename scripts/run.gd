extends Node

const ArenaScene := preload("res://scenes/arena.tscn")
const BossRoomScene := preload("res://scenes/boss_room.tscn")
const MainMenuScene := preload("res://scenes/main_menu.tscn")

const RUN_DURATION_SECONDS := 600.0  # 10 minutes

@onready var _stage: Node = $Stage
@onready var _hud: CanvasLayer = $HUD
@onready var _timer_label: Label = $HUD/TimerLabel

var _arena: Node = null
var _boss_room: Node = null
var _time_left: float = RUN_DURATION_SECONDS

func _ready() -> void:
	RunState.start_run()
	_load_arena()

func _load_arena() -> void:
	if _arena != null:
		_arena.queue_free()
	_arena = ArenaScene.instantiate()
	_stage.add_child(_arena)
	if _arena.has_signal("exit_to_boss"):
		_arena.connect("exit_to_boss", _enter_boss_room)
	_wire_player()

func _enter_boss_room() -> void:
	if _arena != null:
		_arena.queue_free()
		_arena = null
	_boss_room = BossRoomScene.instantiate()
	_stage.add_child(_boss_room)
	RunState.mark_reached_boss_room()
	if _boss_room.has_signal("boss_defeated"):
		_boss_room.connect("boss_defeated", _on_boss_defeated)
	if _boss_room.has_signal("player_died"):
		_boss_room.connect("player_died", _on_player_died)
	_wire_player()

func _wire_player() -> void:
	# Hook the HUD's joystick to whatever player exists in the current stage.
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node = players[0]
	if _hud.has_node("Joystick"):
		var js: Node = _hud.get_node("Joystick")
		if not js.is_connected("steer_changed", Callable(player, "set_steer")):
			js.connect("steer_changed", Callable(player, "set_steer"))
	if player.has_signal("died") and not player.is_connected("died", _on_player_died):
		player.connect("died", _on_player_died)

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
	RunState.end_run(won)
	get_tree().change_scene_to_packed(MainMenuScene)
