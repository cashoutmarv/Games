extends Control

signal steer_changed(direction: Vector2)

@export var radius: float = 120.0

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob_pos: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Always-visible debug hint while the artist is asleep.
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _touch_index == -2:
		_update_knob((event as InputEventMouseMotion).position)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and _touch_index == -1:
		_touch_index = event.index
		_origin = event.position
		_knob_pos = event.position
		_emit(Vector2.ZERO)
	elif not event.pressed and event.index == _touch_index:
		_release()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _touch_index:
		_update_knob(event.position)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed and _touch_index == -1:
		_touch_index = -2  # sentinel for "mouse drag"
		_origin = event.position
		_knob_pos = event.position
		_emit(Vector2.ZERO)
	elif not event.pressed and _touch_index == -2:
		_release()

func _update_knob(pos: Vector2) -> void:
	var offset := pos - _origin
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_knob_pos = _origin + offset
	_emit(offset / radius)

func _release() -> void:
	_touch_index = -1
	_emit(Vector2.ZERO)
	queue_redraw()

func _emit(dir: Vector2) -> void:
	_direction = dir
	steer_changed.emit(dir)
	queue_redraw()

func _draw() -> void:
	if _touch_index == -1:
		return
	draw_circle(_origin, radius, Color(1, 1, 1, 0.1))
	draw_arc(_origin, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 2.0)
	draw_circle(_knob_pos, radius * 0.35, Color(1, 1, 1, 0.5))
