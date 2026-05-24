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
# Per-run bonus damage added on top of weapon-base damage. Pulled from
# RunState.damage_bonus on spawn so respawning boss-side players inherit
# the accumulating +1-per-death bonus.
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
const _SNAPSHOT_BUFFER: int = 40  # 10s back at 0.25s spacing (F1 perk window)
var _snapshot_timer: float = 0.0
# F3 body-reflex dodge cooldown. Auto-dodges incoming damage when ready.
var _reflex_cooldown: float = 0.0
const _REFLEX_COOLDOWN_SECONDS: float = 3.0
const _REFLEX_IFRAMES: float = 0.4
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
	# Inherit any run-level bonuses (per-run +1-dmg compounding).
	if "damage_bonus" in RunState:
		bonus_damage = max(bonus_damage, int(RunState.damage_bonus))
	# Apply weapon archetype dispatch (v3). RunState.weapon_data holds the
	# resolved weapon dictionary entry; defaults are kept if unset.
	_apply_weapon_dispatch()
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	if is_replay:
		_replay_frames = ReplayRecorder.load_playback()

func _apply_weapon_dispatch() -> void:
	if not "weapon_data" in RunState:
		return
	var data: Dictionary = RunState.weapon_data
	if data.is_empty():
		return
	var stats: Dictionary = data.get("stats", {})
	# Each stat is optional; only override the export default if present.
	if stats.has("fire_cooldown"):
		fire_cooldown = float(stats["fire_cooldown"])
	if stats.has("move_speed"):
		move_speed = float(stats["move_speed"])
	if stats.has("dodge_speed"):
		dodge_speed = float(stats["dodge_speed"])
	# `damage` / `speed` / `range` / `knockback` live on the projectile and
	# are applied in _spawn_projectile by reading RunState.weapon_data again.

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

	# Movement: dodge velocity overrides steer during the dodge. Clash
	# overlay halts movement so the "both freeze" beat reads cleanly.
	if ClashDirector.is_clash_active():
		velocity = Vector2.ZERO
	elif _is_dodging:
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
	_reflex_cooldown = max(0.0, _reflex_cooldown - delta)
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
	# Freeze input while a clash overlay is up — both fighters freeze.
	if ClashDirector.is_clash_active():
		return
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
		PatternTracker.record_parry()
		return

	# Force-clash — F2 perk. Initiates a clash with the currently active
	# hero-side boss on demand.
	if Input.is_action_just_pressed("force_clash") \
			and BossSwap.has_ability("clash_trigger") \
			and not ClashDirector.is_clash_active():
		_initiate_force_clash()
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
	PatternTracker.record_dodge()
	AudioBus.play_sfx("player_dodge")

# F2 perk: force a clash with whatever boss is in the scene.
func _initiate_force_clash() -> void:
	var bosses: Array = get_tree().get_nodes_in_group("boss")
	for b in bosses:
		if not is_instance_valid(b) or b == self:
			continue
		call_deferred("_resolve_clash_with", b)
		return

func _resolve_clash_with(boss_node: Node) -> void:
	var winner: String = await ClashDirector.trigger_clash(boss_node, get_parent())
	if winner == "player":
		if boss_node != null and boss_node.has_method("take_damage"):
			boss_node.take_damage(60)
	elif winner == "boss":
		take_damage(30)

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
	# Dispatch by the resolved weapon's attack_pattern (v3). RunState may
	# be empty (e.g. test scenes); falls through to single_shot in that case.
	var pattern: String = "single_shot"
	if "weapon_data" in RunState:
		var data: Dictionary = RunState.weapon_data
		pattern = String(data.get("attack_pattern", "single_shot"))
	match pattern:
		"cone": _fire_cone(damage_multiplier)
		"aoe_radial": _fire_aoe(damage_multiplier)
		"buff_self": _fire_buff_self()
		"melee_arc", "thrust": _fire_melee(damage_multiplier, pattern)
		_: _fire_single(damage_multiplier)

func _fire_single(damage_multiplier: float) -> void:
	_spawn_one_projectile(aim_direction, damage_multiplier, {})

func _fire_cone(damage_multiplier: float) -> void:
	# Three projectiles in a 28-degree cone.
	for offset in [-deg_to_rad(14.0), 0.0, deg_to_rad(14.0)]:
		_spawn_one_projectile(aim_direction.rotated(offset), damage_multiplier * 0.6, {})

func _fire_aoe(damage_multiplier: float) -> void:
	# A single slow heavy projectile. (Real AoE explosion in a later phase.)
	_spawn_one_projectile(aim_direction, damage_multiplier * 1.4, {"speed_mult": 0.6, "size": 1.5})

func _fire_buff_self() -> void:
	# Utility — no projectile; brief invuln + speed boost.
	_iframes_timer = max(_iframes_timer, 0.5)
	# Lean on the dodge boost for the visible "I did something" feedback.
	_dodge_velocity = aim_direction * dodge_speed * 0.7
	_is_dodging = true
	_dodge_timer = 0.18

func _fire_melee(damage_multiplier: float, pattern: String) -> void:
	# Short-lived close-range projectile that swings forward as a melee hit.
	var range_mult: float = 0.35 if pattern == "melee_arc" else 0.5
	_spawn_one_projectile(aim_direction, damage_multiplier * 1.4, {"speed_mult": 0.85, "range_mult": range_mult})

func _spawn_one_projectile(dir: Vector2, damage_multiplier: float, overrides: Dictionary) -> void:
	var p: Node2D = ProjectileScene.instantiate()
	# Offset from the firer's body so the projectile cannot self-collide
	# (boss-side player is in both "player" and "boss" groups).
	p.global_position = global_position + dir * 36.0
	p.set("direction", dir)
	p.set("owner_group", "boss" if is_boss_side else "player")
	# Base damage = weapon damage stat + bonus_damage, scaled by multiplier.
	var base_dmg: int = int(p.get("damage"))
	if "weapon_data" in RunState:
		var stats: Dictionary = RunState.weapon_data.get("stats", {})
		if stats.has("damage"):
			base_dmg = int(stats["damage"])
		if stats.has("speed"):
			p.set("speed", float(stats["speed"]))
		if stats.has("range") and float(p.get("speed")) > 0:
			p.set("lifetime", float(stats["range"]) / float(p.get("speed")))
		# Tags surface on the projectile for downstream effects.
		var tags: Array = RunState.weapon_data.get("tags", [])
		if "tags" in p:
			p.set("tags", tags)
	p.set("damage", int((base_dmg + bonus_damage) * damage_multiplier))
	if overrides.has("speed_mult"):
		p.set("speed", float(p.get("speed")) * float(overrides["speed_mult"]))
	if overrides.has("range_mult") and float(p.get("speed")) > 0:
		p.set("lifetime", float(p.get("lifetime")) * float(overrides["range_mult"]))
	# Charged shots get a small extra speed bump for feel.
	if damage_multiplier > 1.0:
		p.set("speed", float(p.get("speed")) * lerp(1.0, 1.4, (damage_multiplier - 1.0) / max(0.01, charge_max_multiplier - 1.0)))
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

func take_damage(amount: int, pierces_iframes: bool = false) -> void:
	# Cheat projectiles (F4) bypass dodge/parry invuln. Everything else
	# honors the normal i-frame window.
	if not pierces_iframes and (_is_dodging or _iframes_timer > 0.0):
		return
	if not pierces_iframes and _parry_timer > 0.0:
		# Successful parry — incoming damage is rejected and the parry window
		# closes. Projectile reflection happens in projectile.gd's collision
		# logic (it queries player.is_parrying()).
		_parry_timer = 0.0
		AudioBus.play_sfx("player_parry")
		# F2 perk: an active parry triggers a clash with the hero-side boss.
		if BossSwap.has_ability("clash_trigger") and not is_boss_side \
				and not ClashDirector.is_clash_active():
			_clash_after_parry()
		return
	# F3 perk: body-reflex auto-dodge if cooldown is ready. F4 piercing
	# damage bypasses this too.
	if not pierces_iframes and BossSwap.has_ability("prediction_reflex") \
			and _reflex_cooldown <= 0.0 and not is_boss_side:
		_reflex_cooldown = _REFLEX_COOLDOWN_SECONDS
		_iframes_timer = _REFLEX_IFRAMES
		AudioBus.play_sfx("player_dodge")
		return
	hp = max(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	_hit_flash_timer = 0.08
	if hp > 0:
		return
	# Death — try rewind (perk), then fall through. Hero death no longer
	# routes through BossSwap; that fires on hero-side WIN now (boss_room
	# triggers BossSwap.request_swap from boss-defeated).
	if _try_rewind():
		return
	died.emit()
	queue_free()

func _clash_after_parry() -> void:
	var bosses: Array = get_tree().get_nodes_in_group("boss")
	for b in bosses:
		if not is_instance_valid(b) or b == self:
			continue
		call_deferred("_resolve_clash_with", b)
		return

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
