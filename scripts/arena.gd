extends Node2D

# Generic arena room reused for all three floors. Floor cosmetic palette
# is swapped via configure_for_floor(); the door choice screen ID is also
# floor-scoped so the F2/F3 boss doors get their own Stickmin beats.

signal exit_to_boss

@onready var _exit_button: Button = $UI/ExitButton
@onready var _fridge_button: Button = $UI/FridgeButton
@onready var _hint_label: Label = $UI/HintLabel
@onready var _background: ColorRect = $Background
@onready var _floor_tint: ColorRect = $FloorTint

var _floor: int = 1
var _door_screen_id: String = "door_floor_1"
var _scatter_screen_id: String = "fridge_f1"

# Per-floor palette: [bg, floor_tint, hint_text, scatter_button_label]
const _FLOOR_THEMES: Dictionary = {
	1: {
		"bg": Color(0.18, 0.14, 0.12, 1),
		"floor": Color(0.28, 0.22, 0.18, 1),
		"hint": "Apartment hallway.",
		"scatter_label": "[fridge]",
		"door_screen": "door_floor_1",
		"scatter_screen": "fridge_f1",
	},
	2: {
		"bg": Color(0.12, 0.13, 0.18, 1),
		"floor": Color(0.20, 0.22, 0.30, 1),
		"hint": "Office tower — between meetings.",
		"scatter_label": "[printer]",
		"door_screen": "door_floor_2",
		"scatter_screen": "printer_f2",
	},
	3: {
		"bg": Color(0.10, 0.16, 0.14, 1),
		"floor": Color(0.16, 0.24, 0.20, 1),
		"hint": "City block — the algorithm is watching.",
		"scatter_label": "[phone]",
		"door_screen": "door_floor_3",
		"scatter_screen": "phone_f3",
	},
}

func _ready() -> void:
	_exit_button.pressed.connect(_on_exit)
	if _fridge_button != null:
		_fridge_button.pressed.connect(_on_scatter)
	# Default palette if configure_for_floor never gets called (e.g. test scene).
	if _floor == 1:
		_apply_floor_theme(1)

func configure_for_floor(floor: int) -> void:
	_floor = floor
	_apply_floor_theme(floor)

func _apply_floor_theme(floor: int) -> void:
	var theme: Dictionary = _FLOOR_THEMES.get(floor, _FLOOR_THEMES[1])
	if _background != null:
		_background.color = theme["bg"]
	if _floor_tint != null:
		_floor_tint.color = theme["floor"]
	if _hint_label != null:
		_hint_label.text = theme["hint"]
	if _fridge_button != null:
		_fridge_button.text = String(theme["scatter_label"])
	_door_screen_id = String(theme["door_screen"])
	_scatter_screen_id = String(theme["scatter_screen"])

func _on_exit() -> void:
	# Show the per-floor door Stickmin screen; only advance when the
	# player picks the advancing option.
	var outcome: String = await ChoiceDirector.show_screen(_door_screen_id, self)
	if outcome.ends_with("_advance"):
		exit_to_boss.emit()

func _on_scatter() -> void:
	# Floor-specific scattered comedic beat — flavor only, no progression effect.
	await ChoiceDirector.show_screen(_scatter_screen_id, self)
