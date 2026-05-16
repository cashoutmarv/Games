extends PanelContainer

signal opened(file_id: String)
signal delete_requested(file_id: String)

@onready var _name_label: Label = $H/Name
@onready var _size_label: Label = $H/Size
@onready var _delete_button: Button = $H/Delete

var file_id: String = ""
var file_name: String = ""
var file_size: String = ""
var can_delete: bool = false

func configure(p_id: String, p_name: String, p_size: String, p_can_delete: bool) -> void:
	file_id = p_id
	file_name = p_name
	file_size = p_size
	can_delete = p_can_delete
	if is_node_ready():
		_refresh()

func _ready() -> void:
	_refresh()
	gui_input.connect(_on_gui_input)
	_delete_button.pressed.connect(_on_delete_pressed)

func _refresh() -> void:
	_name_label.text = file_name
	_size_label.text = file_size
	_delete_button.disabled = not can_delete
	_delete_button.text = "Delete" if can_delete else "Locked"

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			opened.emit(file_id)

func _on_delete_pressed() -> void:
	delete_requested.emit(file_id)
