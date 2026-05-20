extends Control

# Ending 1: the player has defeated the final boss for the first time.
# Walks the player through a short authored cutscene, then drops them
# at an end-of-game Stickmin choice screen that hides the true-true
# gate among ordinary fail-loop options.
#
# - Pre-gate (no ending 1 yet, or ending 1 but the 12-hour delay has
#   not elapsed): every option either fail-loops or routes to the
#   desktop hub as normal.
# - Gate-ready (ending 1 seen + delay elapsed): the "LOOK AT THE
#   MONITOR" option flips to advance and routes to the true-true
#   stand-up cutscene.

const DesktopHubScene := preload("res://scenes/desktop_hub.tscn")
const EndingTrueTrueScene := preload("res://scenes/endings/ending_true_true.tscn")

const LINES: Array = [
	"Black screen. Title bar steady. No more taunts.",
	"The dungeon closes itself. Files fold inward. Memory frees.",
	"A desktop. Yours. Clean wallpaper. The Boss is missing from the icons.",
	"The README.txt is rewritten — politely this time.",
	"Whatever else this was, it was a window. You can step away from it now.",
]

@onready var _label: Label = $V/CenterContainer/Body
@onready var _next_button: Button = $V/CenterContainer/NextButton
@onready var _exit_button: Button = $V/CenterContainer/ExitButton

var _index: int = 0

func _ready() -> void:
	DisplayServer.window_set_title("Boss Battle Belay")
	_next_button.pressed.connect(_advance)
	_exit_button.pressed.connect(_open_end_choice)
	_exit_button.visible = false
	_render()

func _render() -> void:
	_label.text = LINES[_index]
	if _index >= LINES.size() - 1:
		_next_button.visible = false
		_exit_button.visible = true

func _advance() -> void:
	_index = min(_index + 1, LINES.size() - 1)
	_render()

func _open_end_choice() -> void:
	_exit_button.disabled = true
	var outcome: String = await ChoiceDirector.show_screen("end_choice", self)
	# Route based on which option the player picked. Only the true-true
	# outcome jumps to ending 2; everything else returns to the desktop.
	if outcome == "end_monitor_true_true":
		get_tree().change_scene_to_packed(EndingTrueTrueScene)
	else:
		get_tree().change_scene_to_packed(DesktopHubScene)
