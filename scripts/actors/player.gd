extends CharacterBody2D

const AutoTargeter := preload("res://scripts/systems/auto_targeter.gd")
const ProjectileScene := preload("res://scenes/actors/projectile.tscn")

signal hp_changed(hp: int, max_hp: int)
signal died
# Emitted when a death is intercepted by the role-swap flow instead of ending
# the run. The player node stays alive for the swap announcement; the boss
# room owns the actual hand-off into boss-side play.
signal death_intercepted_by_swap(boss_id: String)

@export var max_hp: int = 100
@export var move_speed: float = 200.0
@export var fire_cadence: float = 0.5
@export var fire_range: float = 400.0
@export var is_replay: bool = false
# Set by the boss room before the fight starts so player.gd can ask BossSwap
# to handle death routing. Empty string means "no boss context" — death falls
# through to the original `died` + queue_free path.
@export var swap_boss_id: String = ""

var hp: int = max_hp
var steer_input: Vector2 = Vector2.ZERO
var _fire_timer: float = 0.0
var _replay_frames: Array = []
var _replay_index: int = 0
var _replay_fired_this_tick: bool = false

func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	if is_replay:
		_replay_frames = ReplayRecorder.load_playback()

func set_steer(v: Vector2) -> void:
	steer_input = v.limit_length(1.0)

func _physics_process(delta: float) -> void:
	if is_replay:
		_advance_replay()
	else:
		_read_keyboard_fallback()

	velocity = steer_input * move_speed
	move_and_slide()

	_fire_timer -= delta
	var fired := false
	if _fire_timer <= 0.0:
		fired = _try_fire()
		_fire_timer = fire_cadence

	if not is_replay and ReplayRecorder.is_recording():
		ReplayRecorder.record(steer_input, fired)

func _read_keyboard_fallback() -> void:
	# If virtual joystick is not driving steer_input, fall back to keyboard.
	if steer_input.length_squared() > 0.01:
		return
	var v := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"),
	)
	steer_input = v.limit_length(1.0)

func _advance_replay() -> void:
	if _replay_index >= _replay_frames.size():
		steer_input = Vector2.ZERO
		_replay_fired_this_tick = false
		return
	var frame: Dictionary = _replay_frames[_replay_index]
	steer_input = frame.steer
	_replay_fired_this_tick = frame.fired
	_replay_index += 1

func _try_fire() -> bool:
	var target := AutoTargeter.find_nearest(self, "enemy", fire_range)
	if target == null:
		target = AutoTargeter.find_nearest(self, "boss", fire_range)
	if target == null:
		return false
	var p: Node2D = ProjectileScene.instantiate()
	p.global_position = global_position
	p.set("direction", (target.global_position - global_position).normalized())
	p.set("owner_group", "player")
	get_parent().add_child(p)
	AudioBus.play_sfx("player_shoot")
	return true

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		if swap_boss_id != "" and BossSwap.current_state == BossSwap.SwapState.HERO:
			# Boss-fight death: route through role-swap. The hero node is
			# done; the boss room takes over via BossSwap signals and will
			# spawn whatever it needs for boss-side play.
			death_intercepted_by_swap.emit(swap_boss_id)
			BossSwap.request_swap(swap_boss_id)
			queue_free()
			return
		died.emit()
		queue_free()
