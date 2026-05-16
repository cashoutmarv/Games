extends Node2D

const PlayerScene := preload("res://scenes/actors/player.tscn")
const MainMenuScene := preload("res://scenes/main_menu.tscn")

@onready var _hero_spawn: Marker2D = $HeroSpawn
@onready var _boss_marker: Marker2D = $BossMarker
@onready var _dialogue_box: PanelContainer = $UI/DialogueBox
@onready var _exit_button: Button = $UI/ExitButton

var _hero: Node2D = null

func _ready() -> void:
	_exit_button.pressed.connect(_on_exit)
	_spawn_hero()
	# The player is now the boss — stuck in place, awaiting the incoming hero.
	var line := DialogueDirector.get_random_line("ROLE_SWAP")
	if line == "":
		line = "You are the warden now. Someone is coming."
	_dialogue_box.show_line(line, 5.0)

func _spawn_hero() -> void:
	_hero = PlayerScene.instantiate()
	_hero.is_replay = true
	_hero.global_position = _hero_spawn.global_position
	add_child(_hero)
	if _hero.has_signal("died"):
		_hero.connect("died", _on_hero_died)
	# Listen for the hero reaching us.
	get_tree().create_timer(0.1).timeout.connect(_check_hero_loop)

func _check_hero_loop() -> void:
	if _hero == null or not is_instance_valid(_hero):
		return
	if _hero.global_position.distance_to(_boss_marker.global_position) < 32.0:
		_on_hero_arrived()
		return
	get_tree().create_timer(0.2).timeout.connect(_check_hero_loop)

func _on_hero_arrived() -> void:
	# The player-as-boss is defeated. The loop completes.
	var line := DialogueDirector.get_random_line("ROLE_SWAP_END")
	if line == "":
		line = "And so the wheel turns."
	_dialogue_box.show_line(line, 4.0)
	await get_tree().create_timer(4.5).timeout
	SaveSystem.set_role_swap(false)
	SaveSystem.reset_all()  # the loop genuinely resets
	get_tree().change_scene_to_packed(MainMenuScene)

func _on_hero_died() -> void:
	# Shouldn't happen in v1 — replay should always reach us — but fail gracefully.
	push_warning("Replay hero died before arrival. Returning to menu.")
	SaveSystem.set_role_swap(false)
	get_tree().change_scene_to_packed(MainMenuScene)

func _on_exit() -> void:
	SaveSystem.set_role_swap(false)
	get_tree().change_scene_to_packed(MainMenuScene)
