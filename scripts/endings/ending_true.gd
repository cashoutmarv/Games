extends Control

# Ending 1: the player has defeated the final boss for the first time.
# Plays a short authored cutscene of dialog lines, then routes to the
# desktop hub which now persists as the new "main menu" state. v6 wires
# the true-true gate; for v5 this scene just plays once and exits.

const DesktopHubScene := preload("res://scenes/desktop_hub.tscn")

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
	# Restore the OS title bar in case the F4 cheats left it in a weird state.
	DisplayServer.window_set_title("Boss Battle Belay")
	_next_button.pressed.connect(_advance)
	_exit_button.pressed.connect(_to_desktop)
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

func _to_desktop() -> void:
	get_tree().change_scene_to_packed(DesktopHubScene)
