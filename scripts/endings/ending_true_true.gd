extends Control

# Ending 2 — the true-true ending. Auto-progresses through a short
# stand-up cutscene, fades the screen to black, marks ending 2 as seen
# so a future relaunch can acknowledge it, then literally quits the app.

const _BEATS: Array = [
	{"text": "You stop typing. The cursor in the title bar stops blinking.", "delay": 2.5},
	{"text": "The chair scrapes back. You stand.", "delay": 2.0},
	{"text": "The monitor is still on. You walk out of frame anyway.", "delay": 2.4},
	{"text": "From off-screen: the monitor clicks off.", "delay": 2.0},
	{"text": "", "delay": 1.5},  # full black fade before quit
]

@onready var _label: Label = $V/Body
@onready var _backdrop: ColorRect = $Backdrop
@onready var _fade: ColorRect = $Fade

var _index: int = 0
var _step_t: float = 0.0
var _step_dur: float = 1.0
var _done: bool = false

func _ready() -> void:
	# Mark ending 2 immediately so a future relaunch sees it — the player
	# can't dismiss this cutscene any other way (the app is about to quit).
	SaveSystem.mark_ending_seen(EndingDirector.TRUE_TRUE_ENDING_ID)
	# Clean up cosmetic state.
	DisplayServer.window_set_title("Boss Battle Belay")
	_fade.modulate.a = 0.0
	_advance_step()

func _process(delta: float) -> void:
	if _done:
		return
	_step_t += delta
	# Fade up over the duration of the last beat.
	if _index >= _BEATS.size() - 1:
		_fade.modulate.a = clamp(_step_t / _step_dur, 0.0, 1.0)
	if _step_t >= _step_dur:
		_step_t = 0.0
		_advance_step()

func _advance_step() -> void:
	if _index >= _BEATS.size():
		_quit_for_real()
		return
	var beat: Dictionary = _BEATS[_index]
	_label.text = String(beat.get("text", ""))
	_step_dur = float(beat.get("delay", 2.0))
	_index += 1

func _quit_for_real() -> void:
	if _done:
		return
	_done = true
	# This is the whole point of the game: the Godot app exits for real.
	get_tree().quit()
