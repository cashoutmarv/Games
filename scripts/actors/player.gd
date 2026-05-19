extends CharacterBody2D

# v2 twin-stick combatant. Move with WASD / left stick, aim with mouse,
# fire (Z), parry (X), dodge-roll (Space).
#
# Parry / charge / dodge-cancel are inputs that the engine always accepts,
# but `RevealDirector` gates them: they only DO anything after the F1 boss
# reveal. The GDD pretext is "you could have done this the whole time" —
# the moves were there, the player just didn't know.

const ProjectileScene := preload("res://scenes/actors/projectile.tscn")

signal hp_changed(hp: int, max_hp: int)
signal died
# Emitted when a boss-fight death is routed through BossSwap instead of
# ending the run. The boss room owns what happens next.
signal death_intercepted_by_swap(boss_id: String)
# Emitted when the time-rewind ability triggers on a would-be death.
# The boss room shows the cinematic (first ever) or a brief flourish.
signal rewound(is_first_ever: bool)

@export var max_hp: int = 100
@export var move_speed: float = 240.0
@export var dodge_speed: float = 520.0
@export var dodge_duration: float = 0.25
@export var dodge_cooldown: float = 0.7
@export var parry_window: float = 0.22
@export var parry_cooldown: float = 1.0
@export var fire_cooldown: float = 0.28
@export var charge_full_seconds: float = 1.0
@export var charge_max_multiplier: float = 3.0
@export var iframes_on_dodge: float = 0.25
@export var fire_range: float = 700.0  # unused now; kept for replay compat
@export var is_replay: bool = false
@export var is_boss_side: bool = false
# Set by the boss room before the fight starts so player.gd can ask BossSwap
# to handle death routing. Empty string means "no boss context" — death falls
# through to the original `died` + queue_free path.
@export var swap_boss_id: String = ""
# Per-fight bonus damage added on top of weapon-base damage (boss-side win
# rewards). Boss room sets this when respawning the hero after a swap win.
@export var bonus_damage: int = 0

var hp: int = max_hp
var steer_input: Vector2 = Vector2.ZERO
var aim_direction: Vector2 = Vector2.RIGHT
var _fire_timer: float = 0.0
var _charge_timer: float = 0.0
var _is_charging: bool = false
var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _is_dodging: bool = false
var _dodge_velocity: Vector2 = Vector2.ZERO
var _iframes_timer: float = 0.0
var _parry_timer: float = 0.0
var _parry_cooldown_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _rewind_used_this_fight: bool = false
var _rewind_snapshots: Array = []
const _SNAPSHOT_INTERVAL: float = 0.25
const _SNAPSHOT_BUFFER: int = 10  # 2.5s back at 0.25s spacing
var _snapshot_timer: float = 0.0
var _replay_frames: Array = []
var _replay_index: int = 0
var _replay_fired_this_tick: bool = false

@onready var _sprite: ColorRect = $Sprite

func _ready() -> void:
	add_to_group("player")
	if is_boss_side:
		# Boss-side: bigger sprite, different tint, larger HP pool.
		add_to_group("boss")
		max_hp = 600
		_sprite.color = Color(0.9, 0.2, 0.6, 1)
		scale = Vector2(2.0, 2.0)
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	if is_replay:
		_replay_frames = ReplayRecorder.load_playback()

func set_steer(v: Vector2) -> void:
	steer_input = v.limit_length(1.0)

func _physics_process(delta: float) -> void:
	if hp <= 0:
		return
	if is_replay:
		_advance_replay()
	else:
		_read_keyboard_fallback()
		_update_aim()

	_tick_timers(delta)

	# Movement: dodge velocity overrides steer during the dodge.
	if _is_dodging:
		velocity = _dodge_velocity
	else:
		velocity = steer_input * move_speed
	move_and_slide()

	if not is_replay:
		_handle_combat_input(delta)

	_tick_rewind_snapshot(delta)
	_update_visuals(delta)

	if not is_replay and ReplayRecorder.is_recording():
		ReplayRecorder.record(steer_input, _replay_fired_this_tick)
		_replay_fired_this_tick = false

func _read_keyboard_fallback() -> void:
	# Always read the keyboard movement axis — joystick and keys are additive.
	# The virtual joystick still calls set_steer() and wins when active.
	if steer_input.length_squared() > 0.01:
		return
	var v := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"),
	)
	steer_input = v.limit_length(1.0)

func _update_aim() -> void:
	var mouse: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse - global_position
	if to_mouse.length_squared() > 1.0:
		aim_direction = to_mouse.normalized()

func _advance_replay() -> void:
	if _replay_index >= _replay_frames.size():
		steer_input = Vector2.ZERO
		_replay_fired_this_tick = false
		return
	var frame: Dictionary = _replay_frames[_replay_index]
	steer_input = frame.steer
	_replay_fired_this_tick = frame.fired
	_replay_index += 1

func _tick_timers(delta: float) -> void:
	_fire_timer = max(0.0, _fire_timer - delta)
	_dodge_cooldown_timer = max(0.0, _dodge_cooldown_timer - delta)
	_parry_cooldown_timer = max(0.0, _parry_cooldown_timer - delta)
	if _is_dodging:
		_dodge_timer -= delta
		if _dodge_timer <= 0.0:
			_is_dodging = false
	if _iframes_timer > 0.0:
		_iframes_timer = max(0.0, _iframes_timer - delta)
	if _parry_timer > 0.0:
		_parry_timer = max(0.0, _parry_timer - delta)
	if _hit_flash_timer > 0.0:
		_hit_flash_timer = max(0.0, _hit_flash_timer - delta)

func _handle_combat_input(_delta: float) -> void:
	# Dodge — always available, always cancels current action.
	if Input.is_action_just_pressed("dodge_roll") and _dodge_cooldown_timer <= 0.0:
		_start_dodge()
		# Dodge-cancel: aborts fire cooldown and charge.
		if RevealDirector.dodge_cancel_enabled():
			_fire_timer = 0.0
			_cancel_charge()
		return

	# Parry — only when revealed.
	if Input.is_action_just_pressed("parry") and RevealDirector.parry_enabled() \
			and _parry_cooldown_timer <= 0.0:
		_parry_timer = parry_window
		_parry_cooldown_timer = parry_cooldown
		return

	# Charge attack — only when revealed. Hold fire to charge.
	if RevealDirector.charge_enabled():
		if Input.is_action_pressed("fire"):
			if not _is_charging and _fire_timer <= 0.0:
				_is_charging = true
				_charge_timer = 0.0
			if _is_charging:
				_charge_timer = min(charge_full_seconds, _charge_timer + _delta)
		if _is_charging and Input.is_action_just_released("fire"):
			_release_charged_shot()
			return

	# Vanilla fire on tap.
	if Input.is_action_just_pressed("fire") and _fire_timer <= 0.0 and not _is_charging:
		_fire_basic()

func _start_dodge() -> void:
	_is_dodging = true
	_dodge_timer = dodge_duration
	_iframes_timer = iframes_on_dodge
	_dodge_cooldown_timer = dodge_cooldown
	# Dodge in the steer direction; fall back to aim direction if standing still.
	var dir: Vector2 = steer_input
	if dir.length_squared() < 0.01:
		dir = aim_direction
	_dodge_velocity = dir.normalized() * dodge_speed
	AudioBus.play_sfx("player_dodge")

func _fire_basic() -> void:
	_spawn_projectile(1.0)
	_fire_timer = fire_cooldown
	_replay_fired_this_tick = true
	AudioBus.play_sfx("player_shoot")

func _release_charged_shot() -> void:
	var charge_ratio: float = clamp(_charge_timer / charge_full_seconds, 0.0, 1.0)
	var multiplier: float = lerp(1.0, charge_max_multiplier, charge_ratio)
	_spawn_projectile(multiplier)
	_fire_timer = fire_cooldown * (1.0 + charge_ratio)
	_is_charging = false
	_charge_timer = 0.0
	_replay_fired_this_tick = true
	AudioBus.play_sfx("player_shoot")

func _cancel_charge() -> void:
	_is_charging = false
	_charge_timer = 0.0

func _spawn_projectile(damage_multiplier: float) -> void:
	var p: Node2D = ProjectileScene.instantiate()
	# Offset from the firer's body so the projectile cannot self-collide
	# (boss-side player is in both "player" and "boss" groups).
	p.global_position = global_position + aim_direction * 36.0
	p.set("direction", aim_direction)
	p.set("owner_group", "boss" if is_boss_side else "player")
	# Base damage is the projectile scene's default; multiplier scales it.
	var base_dmg: int = int(p.get("damage"))
	p.set("damage", base_dmg + bonus_damage)
	if damage_multiplier != 1.0:
		p.set("damage", int(p.get("damage") * damage_multiplier))
		# Visually beefier — bigger speed for charged shots.
		p.set("speed", float(p.get("speed")) * lerp(1.0, 1.4, damage_multiplier / charge_max_multiplier))
	get_parent().add_child(p)

func _tick_rewind_snapshot(delta: float) -> void:
	if not BossSwap.has_ability("rewind_on_death"):
		return
	_snapshot_timer += delta
	if _snapshot_timer < _SNAPSHOT_INTERVAL:
		return
	_snapshot_timer = 0.0
	_rewind_snapshots.append({"pos": global_position, "hp": hp})
	if _rewind_snapshots.size() > _SNAPSHOT_BUFFER:
		_rewind_snapshots.pop_front()

func _update_visuals(_delta: float) -> void:
	if _sprite == null:
		return
	if _hit_flash_timer > 0.0:
		_sprite.color = Color(1.0, 1.0, 1.0, 1.0)
	elif _is_dodging or _iframes_timer > 0.0:
		_sprite.color = Color(0.7, 1.0, 1.0, 0.6)
	elif _parry_timer > 0.0:
		_sprite.color = Color(1.0, 0.95, 0.4, 1.0)
	elif is_boss_side:
		_sprite.color = Color(0.9, 0.2, 0.6, 1)
	else:
		_sprite.color = Color(0.4, 0.8, 1.0, 1)

func take_damage(amount: int) -> void:
	if _is_dodging or _iframes_timer > 0.0:
		return
	if _parry_timer > 0.0:
		# Successful parry — incoming damage is rejected and the parry window
		# closes. Projectile reflection happens in projectile.gd's collision
		# logic (it queries player.is_parrying()).
		_parry_timer = 0.0
		AudioBus.play_sfx("player_parry")
		return
	hp = max(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	_hit_flash_timer = 0.08
	if hp > 0:
		return
	# Death — try rewind first, then swap, then fall through.
	if _try_rewind():
		return
	if swap_boss_id != "" and BossSwap.current_state == BossSwap.SwapState.HERO:
		death_intercepted_by_swap.emit(swap_boss_id)
		BossSwap.request_swap(swap_boss_id)
		queue_free()
		return
	died.emit()
	queue_free()

# True if the rewind ability fired and the player was saved from death.
func _try_rewind() -> bool:
	if not BossSwap.has_ability("rewind_on_death"):
		return false
	if _rewind_used_this_fight:
		return false
	if _rewind_snapshots.is_empty():
		return false
	var snapshot: Dictionary = _rewind_snapshots[0]  # ~2s ago is the oldest
	global_position = snapshot.pos
	hp = max(1, int(max_hp * 0.5))
	hp_changed.emit(hp, max_hp)
	_rewind_used_this_fight = true
	_rewind_snapshots.clear()
	_iframes_timer = 0.6
	var is_first_ever := not SaveSystem.state.get("first_rewind_seen", false)
	if is_first_ever:
		SaveSystem.state.first_rewind_seen = true
		SaveSystem.save()
	rewound.emit(is_first_ever)
	AudioBus.play_sfx("player_rewind")
	return true

# Queried by projectile.gd to decide whether to reflect.
func is_parrying() -> bool:
	return _parry_timer > 0.0
