extends Control

# Desktop hub — the game's entry point from this PR onward.
# Replaces scenes/main_menu.tscn as the routing surface. Three placeholder
# icons: Run.exe (→ weapon_input), Choices.exe (→ medal grid), Settings.exe
# (no-op stub).
#
# A hidden debug overlay ports the v1 dev panel buttons so testing
# unaffected.

const WeaponInputScene := preload("res://scenes/ui/weapon_input.tscn")
const ChoicesAppScene := preload("res://scenes/desktop/choices_app.tscn")

@onready var _run_button: Button = $V/Icons/RunIcon/Button
@onready var _choices_button: Button = $V/Icons/ChoicesIcon/Button
@onready var _settings_button: Button = $V/Icons/SettingsIcon/Button
@onready var _last_weapon_label: Label = $V/Footer/LastWeapon
@onready var _runs_label: Label = $V/Footer/Runs
@onready var _debug_toggle: Button = $V/Footer/DebugToggle
@onready var _debug_panel: Control = $DebugPanel
@onready var _wallpaper: ColorRect = $Wallpaper
@onready var _title_bar: Label = $TitleBar

const _WALLPAPER_CORRUPTED: Color = Color(0.08, 0.1, 0.18, 1)
const _WALLPAPER_RESTORED: Color = Color(0.12, 0.18, 0.22, 1)

func _ready() -> void:
	_run_button.pressed.connect(_on_run)
	_choices_button.pressed.connect(_on_choices)
	_settings_button.pressed.connect(_on_settings)
	_debug_toggle.pressed.connect(_on_debug_toggle)
	$DebugPanel/V/BumpRuns.pressed.connect(_on_bump_runs)
	$DebugPanel/V/ResetSave.pressed.connect(_on_reset_save)
	$DebugPanel/V/UnlockReveal.pressed.connect(_on_unlock_reveal)
	SaveSystem.state_changed.connect(_refresh)
	_debug_panel.visible = false
	# Restore OS window title in case a previous run left the F4 title-bar
	# cheat string in place.
	DisplayServer.window_set_title("Boss Battle Belay")
	_refresh()

func _refresh() -> void:
	var last: String = SaveSystem.state.get("last_weapon_text", "")
	if last == "":
		_last_weapon_label.text = "no runs yet."
	else:
		_last_weapon_label.text = "last run: %s" % last
	_runs_label.text = "runs: %d   choices: %d/%d" % [
		int(SaveSystem.state.get("total_runs", 0)),
		ChoiceDirector.seen_outcome_count(),
		ChoiceDirector.total_outcomes(),
	]
	# Wallpaper + title-bar reflect ending-1 state. Before ending 1:
	# corrupted palette + glitchy title. After: restored palette + clean
	# title.
	if EndingDirector.has_seen_ending(EndingDirector.TRUE_ENDING_ID):
		_wallpaper.color = _WALLPAPER_RESTORED
		_title_bar.text = "DESKTOP — clean."
	else:
		_wallpaper.color = _WALLPAPER_CORRUPTED
		_title_bar.text = "DESKTOP — Boss Battle Belay"

func _on_run() -> void:
	RunState.clear_weapon()
	get_tree().change_scene_to_packed(WeaponInputScene)

func _on_choices() -> void:
	# Open Choices.exe as an overlay rather than a scene change so the
	# desktop stays in the background.
	var app: CanvasLayer = ChoicesAppScene.instantiate()
	add_child(app)

func _on_settings() -> void:
	# v3 stub. Future passes wire real settings.
	pass

func _on_debug_toggle() -> void:
	_debug_panel.visible = not _debug_panel.visible

# ---- Debug panel handlers ----

func _on_bump_runs() -> void:
	RunState.debug_set_runs(SaveSystem.state.total_runs + 1)
	_refresh()

func _on_reset_save() -> void:
	SaveSystem.reset_all()
	_refresh()

func _on_unlock_reveal() -> void:
	RevealDirector.unlock("hidden_depth")
	_refresh()
