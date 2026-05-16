extends CanvasLayer

@onready var _hp_bar: ProgressBar = $HPBar
@onready var _joystick: Control = $Joystick
@onready var _timer_label: Label = $TimerLabel

func _ready() -> void:
	# Wire HP bar to whichever player exists.
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p := players[0]
		if p.has_signal("hp_changed"):
			p.connect("hp_changed", _on_hp_changed)
			_on_hp_changed(p.get("hp"), p.get("max_hp"))

func _on_hp_changed(hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
