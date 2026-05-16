extends Node2D

const PhaseMachine := preload("res://scripts/systems/phase_machine.gd")

signal boss_defeated
signal player_died

@onready var _boss: Node = $Boss
@onready var _dialogue_box: PanelContainer = $UI/DialogueBox

func _ready() -> void:
	if _boss.has_signal("defeated"):
		_boss.connect("defeated", _on_boss_defeated)
	if _boss.has_signal("wants_to_talk"):
		_boss.connect("wants_to_talk", _on_boss_talk)
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0].has_signal("died"):
		players[0].connect("died", _on_player_died)
	# Greet the player based on phase.
	var phase_name := PhaseMachine.phase_name(RunState.current_phase)
	var greeting := DialogueDirector.get_random_line(phase_name)
	if greeting != "":
		_dialogue_box.show_line(greeting, 3.0)

func _on_boss_talk(line: String) -> void:
	_dialogue_box.show_line(line, 3.5)

func _on_boss_defeated() -> void:
	boss_defeated.emit()

func _on_player_died() -> void:
	player_died.emit()
