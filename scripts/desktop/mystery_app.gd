extends CanvasLayer

# ???.exe — a small overlay window that opens a "corrupted README" hinting
# at the true-true gate. Only visible on the desktop after ending 1 has
# landed and disappears again once ending 2 has been seen (the player
# no longer needs the hint).

@onready var _body: Label = $Window/V/Body
@onready var _close: Button = $Window/V/Footer/Close

const _README_LINES: Array = [
	"y0u beat th3 game.",
	"",
	"didn't you notice — the CURSOR was BLINKING at the end.",
	"",
	"  next time you finish, don't pick close.",
	"  read the screen. look at it. you'll know.",
	"",
	"(this file appeared on its own.)",
]

func _ready() -> void:
	_close.pressed.connect(_on_close)
	_body.text = "\n".join(_README_LINES)

func _on_close() -> void:
	queue_free()
