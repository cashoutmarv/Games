extends CanvasLayer

# Henry-Stickmin-style 3-option clash overlay used by ClashDirector.
# Player picks BREAK / FAKE / COMMIT. The boss pick is set by the
# director ahead of time. Resolution beat plays in-place; the caller
# awaits `resolved(winner: String, player_pick: String)`.

signal resolved(winner: String, player_pick: String)

@onready var _title: Label = $Window/V/Title
@onready var _row: HBoxContainer = $Window/V/Row
@onready var _status: Label = $Window/V/Status
@onready var _break_btn: Button = $Window/V/Row/Break
@onready var _fake_btn: Button = $Window/V/Row/Fake
@onready var _commit_btn: Button = $Window/V/Row/Commit

var _boss_pick: String = ""
var _player_pick: String = ""

func _ready() -> void:
	_break_btn.pressed.connect(_on_pick.bind("BREAK"))
	_fake_btn.pressed.connect(_on_pick.bind("FAKE"))
	_commit_btn.pressed.connect(_on_pick.bind("COMMIT"))
	_title.text = "CLASH."
	_status.text = "Both freeze. Pick."

func set_boss_pick(pick: String) -> void:
	_boss_pick = pick

func get_player_pick() -> String:
	return _player_pick

func _on_pick(option: String) -> void:
	_player_pick = option
	_break_btn.disabled = true
	_fake_btn.disabled = true
	_commit_btn.disabled = true
	_status.text = "YOU: %s     BOSS: %s" % [_player_pick, _boss_pick]
	await get_tree().create_timer(1.0).timeout
	var winner: String = ClashDirector.resolve_picks(_player_pick, _boss_pick)
	_status.text = _outcome_text(winner)
	await get_tree().create_timer(1.0).timeout
	resolved.emit(winner, _player_pick)

func _outcome_text(winner: String) -> String:
	match winner:
		"player": return "ADVANTAGE: YOU."
		"boss": return "ADVANTAGE: BOSS."
		_: return "STALEMATE."
