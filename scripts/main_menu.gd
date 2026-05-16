extends Control

const PhaseMachine := preload("res://scripts/systems/phase_machine.gd")
const RunScene := preload("res://scenes/run.tscn")
const FileBrowserScene := preload("res://scenes/file_browser.tscn")
const EpilogueScene := preload("res://scenes/epilogue.tscn")

@onready var _start_button: Button = $V/StartButton
@onready var _continue_button: Button = $V/ContinueButton
@onready var _files_button: Button = $V/FilesButton
@onready var _debug_panel: Control = $DebugPanel
@onready var _phase_label: Label = $V/PhaseLabel
@onready var _runs_label: Label = $V/RunsLabel

func _ready() -> void:
	_start_button.pressed.connect(_on_start)
	_continue_button.pressed.connect(_on_continue)
	_files_button.pressed.connect(_on_files)
	$DebugPanel/V/BumpRuns.pressed.connect(_on_bump_runs)
	$DebugPanel/V/AddEggs.pressed.connect(_on_add_eggs)
	$DebugPanel/V/ResetSave.pressed.connect(_on_reset)
	$DebugPanel/V/ToggleDeleted.pressed.connect(_on_toggle_deleted)
	$DebugPanel/V/OpenFiles.pressed.connect(_on_files)
	SaveSystem.state_changed.connect(_refresh)
	RunState.phase_changed.connect(_on_phase_changed)
	_refresh()

func _refresh() -> void:
	RunState.recompute_phase()
	var phase := RunState.current_phase
	_phase_label.text = "Phase: %s" % PhaseMachine.phase_name(phase)
	_runs_label.text = "Runs: %d   Eggs: %d" % [
		SaveSystem.state.total_runs,
		SaveSystem.state.easter_eggs_found.size(),
	]
	_files_button.visible = phase >= PhaseMachine.NarrativePhase.FILE_BROWSER_UNLOCKED
	_continue_button.visible = SaveSystem.state.boss_deleted

func _on_phase_changed(_phase: int) -> void:
	_refresh()

func _on_start() -> void:
	get_tree().change_scene_to_packed(RunScene)

func _on_continue() -> void:
	SaveSystem.set_role_swap(true)
	get_tree().change_scene_to_packed(EpilogueScene)

func _on_files() -> void:
	get_tree().change_scene_to_packed(FileBrowserScene)

# ---- Debug panel handlers ----

func _on_bump_runs() -> void:
	RunState.debug_set_runs(SaveSystem.state.total_runs + 1)
	_refresh()

func _on_add_eggs() -> void:
	RunState.debug_add_eggs(3)
	_refresh()

func _on_reset() -> void:
	SaveSystem.reset_all()
	_refresh()

func _on_toggle_deleted() -> void:
	RunState.debug_set_boss_deleted(not SaveSystem.state.boss_deleted)
	_refresh()
