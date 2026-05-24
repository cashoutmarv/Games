extends Node

# Entry-of-run weapon prompt. Pipeline:
#   1. Show the Stickmin weapon_prompt screen via ChoiceDirector.
#   2. If the player picks an advancing option (CUSTOM →), reveal the
#      text field, capture their typed weapon, resolve via WeaponDict,
#      and store on RunState.
#   3. change_scene_to_packed(RunScene).
# Fail-loop options on the Stickmin screen are handled internally by
# choice_screen.gd; they never advance past the prompt.

const RunScene := preload("res://scenes/run.tscn")

@onready var _text_field: LineEdit = $UI/CenterContainer/V/InputRow/TextField
@onready var _submit_button: Button = $UI/CenterContainer/V/InputRow/SubmitButton
@onready var _resolved_label: Label = $UI/CenterContainer/V/ResolvedLabel
@onready var _input_row: HBoxContainer = $UI/CenterContainer/V/InputRow
@onready var _hint_label: Label = $UI/CenterContainer/V/HintLabel

func _ready() -> void:
	# Hide the text input behind the Stickmin screen until the player picks CUSTOM →.
	_input_row.visible = false
	_resolved_label.text = ""
	_submit_button.pressed.connect(_on_submit)
	_text_field.text_submitted.connect(_on_text_submitted)
	call_deferred("_show_stickmin_prompt")

func _show_stickmin_prompt() -> void:
	var outcome: String = await ChoiceDirector.show_screen("weapon_prompt", self)
	# CUSTOM → was picked. Reveal the text input.
	_input_row.visible = true
	_hint_label.text = "Type a weapon. Try: rusty crowbar · sharp pen · big shotgun · flaming book"
	_text_field.grab_focus()

func _on_text_submitted(_text: String) -> void:
	_on_submit()

func _on_submit() -> void:
	var text: String = _text_field.text.strip_edges()
	if text == "":
		text = "fist"  # WeaponDict's empty-input fallback also handles this.
	var resolved: Dictionary = WeaponDict.resolve(text)
	# Display a one-frame "resolved as" preview before scene change.
	_resolved_label.text = "%s → %s" % [text, String(resolved.get("archetype", "?"))]
	RunState.set_weapon(text, resolved)
	# Give the player a beat to see the preview.
	await get_tree().create_timer(0.4).timeout
	get_tree().change_scene_to_packed(RunScene)
