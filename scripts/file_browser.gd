extends Control

const PhaseMachine := preload("res://scripts/systems/phase_machine.gd")
const RowScene := preload("res://scenes/ui/file_browser_row.tscn")
const MainMenuScene := preload("res://scenes/main_menu.tscn")

@onready var _list: VBoxContainer = $V/Scroll/List
@onready var _breadcrumb: Label = $V/Breadcrumb
@onready var _back_button: Button = $V/BackButton
@onready var _confirm_dialog: ConfirmationDialog = $ConfirmDialog
@onready var _info_dialog: AcceptDialog = $InfoDialog
@onready var _toast: Label = $Toast

const FAKE_TREE := [
	{"id": "loop_state", "name": "loop_state.json", "size": "1 KB", "info": "Run state. Tamper at your own risk."},
	{"id": "boss_dat", "name": "boss.dat", "size": "1 KB", "info": "A long ASCII signature: \"I am the warden of the loop.\""},
	{"id": "frame_0001", "name": "cache/frame_0001.tmp", "size": "4 KB", "info": "Stale frame cache. Ignored on next boot."},
	{"id": "frame_0002", "name": "cache/frame_0002.tmp", "size": "4 KB", "info": "Stale frame cache."},
	{"id": "session_log", "name": "logs/session.log", "size": "12 KB", "info": "Garbled session telemetry. Most of it is just runs and screams."},
]

var _pending_delete_id: String = ""

func _ready() -> void:
	_back_button.pressed.connect(_on_back)
	_confirm_dialog.confirmed.connect(_on_confirm_delete)
	_breadcrumb.text = "user://"
	_toast.modulate.a = 0.0
	_populate()

func _populate() -> void:
	for child in _list.get_children():
		child.queue_free()
	for entry in FAKE_TREE:
		var row: PanelContainer = RowScene.instantiate()
		_list.add_child(row)
		var can_delete: bool = false
		if entry.id == "boss_dat":
			can_delete = SaveSystem.state.easter_eggs_found.size() >= PhaseMachine.EGGS_REQUIRED \
				and not SaveSystem.state.boss_deleted
		row.configure(entry.id, entry.name, entry.size, can_delete)
		row.opened.connect(_on_row_opened)
		row.delete_requested.connect(_on_row_delete)

func _on_row_opened(file_id: String) -> void:
	var info := _info_for(file_id)
	_info_dialog.dialog_text = info
	_info_dialog.popup_centered()

func _info_for(file_id: String) -> String:
	for entry in FAKE_TREE:
		if entry.id == file_id:
			return entry.info
	return ""

func _on_row_delete(file_id: String) -> void:
	if file_id != "boss_dat":
		_show_toast("Permission denied. The file is in use.")
		return
	if SaveSystem.state.easter_eggs_found.size() < PhaseMachine.EGGS_REQUIRED:
		_show_toast("Permission denied. The file is in use.")
		return
	_pending_delete_id = file_id
	_confirm_dialog.dialog_text = "Delete %s?\nThis cannot be undone." % file_id
	_confirm_dialog.popup_centered()

func _on_confirm_delete() -> void:
	if _pending_delete_id != "boss_dat":
		return
	AudioBus.play_sfx("file_delete")
	var ok := SaveSystem.delete_boss_file()
	if ok:
		_show_toast("boss.dat deleted.")
		_populate()
		await get_tree().create_timer(1.2).timeout
		get_tree().change_scene_to_packed(MainMenuScene)
	else:
		_show_toast("Deletion failed.")

func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.5)

func _on_back() -> void:
	get_tree().change_scene_to_packed(MainMenuScene)
