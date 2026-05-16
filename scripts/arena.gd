extends Node2D

signal exit_to_boss

@onready var _exit_button: Button = $UI/ExitButton

func _ready() -> void:
	_exit_button.pressed.connect(_on_exit)

func _on_exit() -> void:
	exit_to_boss.emit()
