extends CanvasLayer

# Choices.exe — the medal grid for every outcome the player has ever
# seen across choice screens. Pure collection toy.

@onready var _grid: GridContainer = $Window/V/ScrollContainer/Grid
@onready var _counter: Label = $Window/V/Counter
@onready var _close_button: Button = $Window/V/Header/CloseButton

func _ready() -> void:
	_close_button.pressed.connect(_on_close)
	_render()

func _render() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var total: int = 0
	var seen: int = 0
	for screen_id in ChoiceDirector.screen_ids():
		for outcome_id in ChoiceDirector.outcomes_for_screen(screen_id):
			total += 1
			var tile := _make_tile(outcome_id)
			_grid.add_child(tile)
			if ChoiceDirector.is_outcome_seen(outcome_id):
				seen += 1
	_counter.text = "%d / %d outcomes discovered" % [seen, total]

func _make_tile(outcome_id: String) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(140, 70)
	var l := Label.new()
	l.anchor_right = 1.0
	l.anchor_bottom = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ChoiceDirector.is_outcome_seen(outcome_id):
		l.text = _pretty_label(outcome_id)
		p.modulate = Color(1, 1, 1, 1)
	else:
		l.text = "???"
		p.modulate = Color(0.25, 0.25, 0.3, 1)
	p.add_child(l)
	return p

func _pretty_label(outcome_id: String) -> String:
	# outcome_id is snake_case; the medal label just upper-cases the suffix.
	# (Outcomes are authored in choices.json so we don't have nice strings
	# for every one — this keeps the grid readable without extra config.)
	return outcome_id.replace("_", " ").to_upper()

func _on_close() -> void:
	queue_free()
