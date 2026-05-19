extends Node2D

# v3 arena: apartment hallway placeholder. The "To Boss" button now fronts
# a Stickmin door choice screen. A "fridge" interactable triggers a
# scattered comedic choice screen for medal-board padding.

signal exit_to_boss

@onready var _exit_button: Button = $UI/ExitButton
@onready var _fridge_button: Button = $UI/FridgeButton

func _ready() -> void:
	_exit_button.pressed.connect(_on_exit)
	if _fridge_button != null:
		_fridge_button.pressed.connect(_on_fridge)

func _on_exit() -> void:
	# Show the boss-door Stickmin screen; only advance to the boss room
	# when the player picks the advancing option.
	var outcome: String = await ChoiceDirector.show_screen("door_floor_1", self)
	if outcome.ends_with("_advance"):
		exit_to_boss.emit()

func _on_fridge() -> void:
	# Pure flavor — outcome recorded for Choices.exe, no progression effect.
	await ChoiceDirector.show_screen("fridge_f1", self)
