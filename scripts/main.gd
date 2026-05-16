extends Node

const PhaseMachine := preload("res://scripts/systems/phase_machine.gd")
const MainMenuScene := preload("res://scenes/main_menu.tscn")
const EpilogueScene := preload("res://scenes/epilogue.tscn")

func _ready() -> void:
	# Route based on whether the player is mid-role-swap.
	if SaveSystem.state.role_swap_active:
		_change_scene(EpilogueScene)
	else:
		_change_scene(MainMenuScene)

func _change_scene(packed: PackedScene) -> void:
	var s := packed.instantiate()
	add_child(s)
