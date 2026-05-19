extends CharacterBody2D

const ProjectileScene := preload("res://scenes/actors/projectile.tscn")

signal hp_changed(hp: int, max_hp: int)
signal defeated
signal wants_to_talk(line: String)
signal pattern_started(pattern_id: String)

@export var max_hp: int = 480
@export var move_speed: float = 110.0
@export var contact_damage: int = 12
@export var projectile_damage: int = 8
@export var dash_damage: int = 18
@export var slam_damage: int = 22
@export var telegraph_seconds: float = 0.7
@export var boss_id: String = "boss_floor_1"

# Patterns recharge with a base cooldown that shortens by phase.
@export var pattern_cooldown_phase_1: float = 2.4
@export var pattern_cooldown_phase_2: float = 1.6
@export var pattern_cooldown_phase_3: float = 1.0

enum Phase { ONE, TWO, THREE }
enum Pattern { IDLE, DASH, FAN, SLAM }

var hp: int = max_hp
var _phase: int = Phase.ONE
var _pattern: int = Pattern.IDLE
var _pattern_timer: float = 0.0
var _telegraph_timer: float = 0.0
var _dash_target: Vector2 = Vector2.ZERO
var _slam_radius_max: float = 200.0
var _slam_t: float = 0.0
var _defeated: bool = false
var _pattern_queue_index: int = 0

@onready var _sprite: ColorRect = $Sprite

func _ready() -> void:
	add_to_group("boss")
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	_pattern_timer = pattern_cooldown_phase_1

func _physics_process(delta: float) -> void:
	if _defeated:
		return
	var player := _get_player()
	# Idle drift: amble toward the player so the arena stays engaged.
	if _pattern == Pattern.IDLE and player != null:
		var to_player: Vector2 = player.global_position - global_position
		if to_player.length() > 220.0:
			velocity = to_player.normalized() * move_speed * 0.5
		else:
			velocity = Vector2.ZERO
		move_and_slide()

	_pattern_timer = max(0.0, _pattern_timer - delta)
	if _pattern == Pattern.IDLE and _pattern_timer <= 0.0:
		_start_next_pattern()
	elif _telegraph_timer > 0.0:
		_telegraph_timer = max(0.0, _telegraph_timer - delta)
		if _telegraph_timer <= 0.0:
			_resolve_pattern()

	if _pattern == Pattern.SLAM and _telegraph_timer <= 0.0:
		_advance_slam(delta)

	_update_visuals(delta)

	if Input.is_action_just_pressed("debug_kill_boss"):
		take_damage(hp)

func _get_player() -> Node2D:
	# When boss-side play is active, the "boss" is actually the player-controlled
	# entity (also in the boss group). Skip it; target hero-AI / hero players.
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p == self:
			continue
		return p as Node2D
	return null

func _start_next_pattern() -> void:
	# Phase 1 only uses DASH + FAN. Phase 2 adds SLAM. Phase 3 cycles all three faster.
	var options: Array
	match _phase:
		Phase.ONE:
			options = [Pattern.DASH, Pattern.FAN]
		Phase.TWO:
			options = [Pattern.DASH, Pattern.FAN, Pattern.SLAM]
		Phase.THREE:
			options = [Pattern.DASH, Pattern.FAN, Pattern.SLAM, Pattern.DASH]
		_:
			options = [Pattern.FAN]
	_pattern = options[_pattern_queue_index % options.size()]
	_pattern_queue_index += 1
	_telegraph_timer = telegraph_seconds
	var pid := _pattern_name(_pattern)
	pattern_started.emit(pid)

func _resolve_pattern() -> void:
	var player := _get_player()
	match _pattern:
		Pattern.DASH:
			if player != null:
				_dash_target = player.global_position
				_do_dash()
		Pattern.FAN:
			_do_projectile_fan()
		Pattern.SLAM:
			_slam_t = 0.0
			# SLAM resolves over multiple frames via _advance_slam.
			return
	_pattern = Pattern.IDLE
	_pattern_timer = _current_pattern_cooldown()

func _do_dash() -> void:
	# Single fast leap toward _dash_target. Damage applied via overlap check.
	var dir: Vector2 = (_dash_target - global_position).normalized()
	var leap: Vector2 = dir * 360.0
	var before: Vector2 = global_position
	global_position += leap
	# Apply contact damage if we ended up on the player.
	var player := _get_player()
	if player != null and global_position.distance_to(player.global_position) < 60.0:
		if player.has_method("take_damage"):
			player.take_damage(dash_damage)

func _do_projectile_fan() -> void:
	var player := _get_player()
	if player == null:
		return
	var to_player: Vector2 = (player.global_position - global_position).normalized()
	var fan_count: int = 5 if _phase == Phase.ONE else 7
	var spread_deg: float = 40.0
	for i in fan_count:
		var t: float = -0.5 + (float(i) / float(fan_count - 1)) if fan_count > 1 else 0.0
		var angle: float = deg_to_rad(spread_deg) * t
		var dir: Vector2 = to_player.rotated(angle)
		var p: Node2D = ProjectileScene.instantiate()
		p.global_position = global_position + dir * 48.0
		p.set("direction", dir)
		p.set("owner_group", "boss")
		p.set("damage", projectile_damage)
		p.set("speed", 420.0)
		get_parent().add_child(p)

func _advance_slam(delta: float) -> void:
	_slam_t += delta
	var radius: float = lerp(20.0, _slam_radius_max, clamp(_slam_t / 0.4, 0.0, 1.0))
	# Apply slam damage once at the apex.
	if _slam_t >= 0.4 and _pattern == Pattern.SLAM:
		var player := _get_player()
		if player != null and global_position.distance_to(player.global_position) < radius:
			if player.has_method("take_damage"):
				player.take_damage(slam_damage)
		_pattern = Pattern.IDLE
		_pattern_timer = _current_pattern_cooldown()

func _current_pattern_cooldown() -> float:
	match _phase:
		Phase.ONE: return pattern_cooldown_phase_1
		Phase.TWO: return pattern_cooldown_phase_2
		Phase.THREE: return pattern_cooldown_phase_3
	return pattern_cooldown_phase_1

func _update_visuals(_delta: float) -> void:
	if _sprite == null:
		return
	if _telegraph_timer > 0.0:
		# Pulse during the telegraph so the player can react.
		var t: float = 1.0 - (_telegraph_timer / telegraph_seconds)
		_sprite.color = Color(0.9, 0.2, 0.6, 1).lerp(Color(1.0, 0.9, 0.3, 1), t)
	else:
		_sprite.color = Color(0.9, 0.2, 0.6, 1)

func _pattern_name(p: int) -> String:
	match p:
		Pattern.DASH: return "dash"
		Pattern.FAN: return "fan"
		Pattern.SLAM: return "slam"
	return "idle"

func take_damage(amount: int) -> void:
	if _defeated:
		return
	hp = max(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	_check_phase_transition()
	if hp <= 0:
		_on_defeat()

func _check_phase_transition() -> void:
	var ratio: float = float(hp) / float(max_hp)
	if _phase == Phase.ONE and ratio <= 0.66:
		_enter_phase(Phase.TWO)
	elif _phase == Phase.TWO and ratio <= 0.33:
		_enter_phase(Phase.THREE)

func _enter_phase(phase: int) -> void:
	_phase = phase
	# Quick recovery — telegraph a one-second breath before the next pattern.
	_pattern_timer = 1.0
	_pattern = Pattern.IDLE
	_telegraph_timer = 0.0
	wants_to_talk.emit(_phase_taunt(phase))

func _phase_taunt(phase: int) -> String:
	match phase:
		Phase.TWO: return "A {weapon}? Try harder."
		Phase.THREE: return "Almost. The {weapon} isn't going to do it."
	return ""

func _on_defeat() -> void:
	_defeated = true
	# Unlock the hidden-depth reveal layer + record the kill.
	RevealDirector.unlock("hidden_depth")
	var bd: Array = SaveSystem.state.get("bosses_defeated", [])
	if not bd.has(boss_id):
		bd.append(boss_id)
		SaveSystem.state.bosses_defeated = bd
		SaveSystem.save()
	wants_to_talk.emit("Every hit had a window. Every dodge could cancel. You did it with a {weapon} — but you didn't know any of it.")
	defeated.emit()
