extends CanvasLayer

# Placeholder for the role-swap announcement. v2a uses this for both the
# "your turn — take the boss seat" beat AND the "return to hero — you
# inherited X" beat. The art-spec for the full first-death cinematic is GDD
# open question #9; this overlay is the wiring target it will replace.

signal acknowledged

@onready var _title: Label = $Center/VBox/Title
@onready var _body: Label = $Center/VBox/Body
@onready var _button: Button = $Center/VBox/Continue

const _SWAP_FIRST_TITLE := "YOUR TURN."
const _SWAP_FIRST_BODY := "You beat them. Now take the seat and hold the line — the next hero is on the way. Each death here sharpens you."
const _SWAP_REPEAT_TITLE := "AGAIN."
const _SWAP_REPEAT_BODY := "You beat them. Take the seat. Defend the doorway long enough to walk through it."
const _ONWARD_TITLE := "ONWARD."
const _ONWARD_BODY_FMT := "You held. You carry forward: %s.\nDamage bonus this run: +%d."

func _ready() -> void:
	_button.pressed.connect(_on_continue)

# Configure the overlay for the "hero just died → swap to boss-side" beat.
func show_for_swap(is_first_ever: bool) -> void:
	if is_first_ever:
		_title.text = _SWAP_FIRST_TITLE
		_body.text = _SWAP_FIRST_BODY
	else:
		_title.text = _SWAP_REPEAT_TITLE
		_body.text = _SWAP_REPEAT_BODY
	_button.text = "Continue"
	_button.grab_focus()

# Configure the overlay for the "boss-side cleared → advance to next floor" beat.
func show_for_onward(ability_label: String, bonus_damage: int) -> void:
	_title.text = _ONWARD_TITLE
	_body.text = _ONWARD_BODY_FMT % [ability_label, bonus_damage]
	_button.text = "Continue"
	_button.grab_focus()

func _on_continue() -> void:
	acknowledged.emit()
