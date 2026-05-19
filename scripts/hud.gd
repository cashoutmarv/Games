extends CanvasLayer

@onready var _hp_bar: ProgressBar = $HPBar
@onready var _joystick: Control = $Joystick
@onready var _timer_label: Label = $TimerLabel

var _bound_player: Node = null

func _ready() -> void:
	# Wire HP bar to whichever player exists.
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		bind_player(players[0])

func bind_player(p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	# Drop any prior connection.
	if _bound_player != null and is_instance_valid(_bound_player) and _bound_player.is_connected("hp_changed", _on_hp_changed):
		_bound_player.disconnect("hp_changed", _on_hp_changed)
	_bound_player = p
	if p.has_signal("hp_changed"):
		p.connect("hp_changed", _on_hp_changed)
		_on_hp_changed(int(p.get("hp")), int(p.get("max_hp")))

func _on_hp_changed(hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
