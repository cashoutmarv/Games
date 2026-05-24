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
@export var reveal_on_defeat: String = "hidden_depth"
# F2+ trigger a clash mini-game on each phase transition. Damages the
# loser when resolved.
@export var triggers_clash_on_phase_transition: bool = false
@export var clash_win_damage: int = 60
@export var clash_loss_damage: int = 35
# F4 4th-wall cheats — bundle of flags only the final boss enables.
@export var cheat_skip_telegraph: bool = false  # untelegraphed attacks
@export var cheat_pierces_iframes: bool = false  # boss projectiles bypass player invuln
@export var cheat_godmode_chance: float = 0.0  # chance to reject incoming damage [0..1]
@export var cheat_teleport_chance: float = 0.0  # chance to teleport behind player per pattern [0..1]
@export var cheat_writes_title_bar: bool = false  # writes HP + taunts to OS title bar
@export var cheat_writes_save_file: bool = false  # appends taunt lines to the save during fight

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
	# Freeze hero-side AI while a clash overlay is up.
	if ClashDirector.is_clash_active():
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
	_telegraph_timer = 0.0 if cheat_skip_telegraph else telegraph_seconds
	# Cheat: occasional pre-pattern teleport behind the player (no-clip flavor).
	if cheat_teleport_chance > 0.0 and randf() < cheat_teleport_chance:
		_teleport_near_player()
	var pid := _pattern_name(_pattern)
	pattern_started.emit(pid)

func _teleport_near_player() -> void:
	var player := _get_player()
	if player == null:
		return
	# Drop in ~120px behind the player along their facing.
	var offset: Vector2 = Vector2(0, 1).rotated(randf() * TAU) * 140.0
	global_position = player.global_position + offset

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
		if cheat_pierces_iframes and "pierces_iframes" in p:
			p.set("pierces_iframes", true)
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
	# Cheat: god-mode windows reject incoming damage occasionally.
	if cheat_godmode_chance > 0.0 and randf() < cheat_godmode_chance:
		wants_to_talk.emit("Nope.")
		return
	hp = max(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	_update_cheat_title_bar()
	_check_phase_transition()
	if hp <= 0:
		_on_defeat()

func _update_cheat_title_bar() -> void:
	if not cheat_writes_title_bar:
		return
	var pct: int = int(round(100.0 * float(hp) / float(max_hp)))
	DisplayServer.window_set_title("Boss Battle Belay — boss HP: %d%%" % pct)

func _maybe_write_taunt_to_save(taunt: String) -> void:
	if not cheat_writes_save_file:
		return
	# Append a taunt line to a side file the player can find. Keeping it
	# off the canonical loop_state.json keeps the schema clean.
	var path := "user://boss_taunts.log"
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return
	f.seek_end()
	f.store_line("[%s] %s" % [Time.get_datetime_string_from_system(true), taunt])
	f.close()

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
	var taunt: String = _phase_taunt(phase)
	wants_to_talk.emit(taunt)
	_maybe_write_taunt_to_save(taunt)
	if triggers_clash_on_phase_transition and phase >= Phase.TWO:
		call_deferred("_initiate_phase_clash")

# Cinematic phase-transition clash. Both fighters freeze; player picks one
# of BREAK / FAKE / COMMIT; ClashDirector resolves; damage applied.
func _initiate_phase_clash() -> void:
	# Pause normal physics: pattern timer + telegraph timer pause via a flag.
	_pattern = Pattern.IDLE
	_pattern_timer = max(_pattern_timer, 1.5)
	var parent: Node = get_parent()
	if parent == null:
		return
	var winner: String = await ClashDirector.trigger_clash(self, parent)
	if winner == "player":
		take_damage(clash_win_damage)
	elif winner == "boss":
		var p := _get_player()
		if p != null and p.has_method("take_damage"):
			p.take_damage(clash_loss_damage)
	# Tie: no damage; both narratively bounce.

func _phase_taunt(phase: int) -> String:
	match phase:
		Phase.TWO: return "A {weapon}? Try harder."
		Phase.THREE: return "Almost. The {weapon} isn't going to do it."
	return ""

func _on_defeat() -> void:
	_defeated = true
	# Unlock the floor-specific reveal layer + record the kill.
	if reveal_on_defeat != "":
		RevealDirector.unlock(reveal_on_defeat)
	var bd: Array = SaveSystem.state.get("bosses_defeated", [])
	if not bd.has(boss_id):
		bd.append(boss_id)
		SaveSystem.state.bosses_defeated = bd
		SaveSystem.save()
	defeated.emit()
