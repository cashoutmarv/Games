extends PanelContainer

@onready var _label: Label = $Margin/Label

var _queue: Array[String] = []
var _showing: bool = false

func _ready() -> void:
	visible = false

func show_line(text: String, duration: float = 3.0) -> void:
	_queue.append(text)
	if not _showing:
		_pump(duration)

func _pump(duration: float) -> void:
	if _queue.is_empty():
		visible = false
		_showing = false
		return
	_showing = true
	visible = true
	_label.text = _queue.pop_front()
	await get_tree().create_timer(duration).timeout
	_pump(duration)
