extends Node

# Entry-point router. v3 swaps the main menu for the desktop hub.
# (The v1 role-swap epilogue branch is gone — that narrative was discarded
# in the v2 pivot.)

const DesktopHubScene := preload("res://scenes/desktop_hub.tscn")

func _ready() -> void:
	_change_scene(DesktopHubScene)

func _change_scene(packed: PackedScene) -> void:
	var s := packed.instantiate()
	add_child(s)
