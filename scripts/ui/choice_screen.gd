extends CanvasLayer

# Generic Stickmin-style multi-option choice screen.
#
# Lifecycle: ChoiceDirector instantiates this scene, calls configure(),
# the player picks options (failures loop, advance closes). When the
# player picks an advance option, `advance_chosen(outcome_id: String)`
# fires and the caller queue_frees this scene.

signal advance_chosen(outcome_id: String)

@onready var _title: Label = $Center/VBox/Title
@onready var _subtitle: Label = $Center/VBox/Subtitle
@onready var _button_row: VBoxContainer = $Center/VBox/Buttons
@onready var _flash_label: Label = $Center/VBox/Flash

var _screen_id: String = ""
var _config: Dictionary = {}
var _director: Node = null
var _flash_clear_t: float = 0.0

func _process(delta: float) -> void:
	if _flash_clear_t > 0.0:
		_flash_clear_t -= delta
		if _flash_clear_t <= 0.0:
			_flash_label.text = ""
			_render_buttons()  # Re-enable the buttons after a fail beat.

# Called once by ChoiceDirector.show_screen().
func configure(screen_id: String, cfg: Dictionary, director: Node) -> void:
	_screen_id = screen_id
	_config = cfg
	_director = director
	_title.text = String(cfg.get("title", ""))
	_subtitle.text = String(cfg.get("subtitle", ""))
	_flash_label.text = ""
	_render_buttons()

func _render_buttons() -> void:
	# Clear previous round of buttons.
	for child in _button_row.get_children():
		child.queue_free()
	for opt in _config.get("options", []):
		var b := Button.new()
		b.text = String(opt.get("label", "?"))
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(_on_option_pressed.bind(opt))
		_button_row.add_child(b)

func _on_option_pressed(opt: Dictionary) -> void:
	var outcome_id: String = String(opt.get("outcome_id", ""))
	if _director != null and _director.has_method("record_outcome"):
		_director.record_outcome(outcome_id)
	if bool(opt.get("is_advance", false)):
		advance_chosen.emit(outcome_id)
		return
	# Fail-loop: show the fail line for ~1.6s, hide buttons, then re-render.
	var fail_line: String = String(opt.get("fail_line", "..."))
	_flash_label.text = fail_line
	_flash_clear_t = 1.6
	for child in _button_row.get_children():
		(child as Button).disabled = true
