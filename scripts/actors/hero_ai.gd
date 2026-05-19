extends CharacterBody2D

# Mirrored stick-figure hero used during boss-side play. The player has just
# taken the boss seat; these AIs are the "incoming heroes" that wave-attack
# the boss. They are not players (no `player` group) — they target the boss.

const ProjectileScene := preload("res://scenes/actors/projectile.tscn")

signal died

@export var max_hp: int = 60
@export var move_speed: float = 130.0
@export var damage: int = 8
@export var fire_cadence: float = 0.6
@export var fire_range: float = 420.0

var hp: int = max_hp
var _fire_timer: float = 0.0

func _ready() -> void:
	add_to_group("hero_ai")
	add_to_group("enemy")  # boss-fired projectiles damage enemies too
	hp = max_hp
	_fire_timer = randf_range(0.0, fire_cadence)

func _physics_process(delta: float) -> void:
	var target := _find_boss()
	if target == null:
		return
	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()
	# Keep a stand-off distance — heroes don't suicide into the boss.
	var stand_off: float = 220.0
	if dist > stand_off + 30.0:
		velocity = to_target.normalized() * move_speed
	elif dist < stand_off - 30.0:
		velocity = -to_target.normalized() * move_speed * 0.6
	else:
		# Strafe perpendicular.
		velocity = to_target.normalized().rotated(PI / 2.0) * move_speed * 0.8
	move_and_slide()

	_fire_timer -= delta
	if _fire_timer <= 0.0 and dist < fire_range:
		_fire_at(target)
		_fire_timer = fire_cadence

func _find_boss() -> Node2D:
	var bosses := get_tree().get_nodes_in_group("boss")
	for b in bosses:
		return b as Node2D
	return null

func _fire_at(target: Node2D) -> void:
	var dir: Vector2 = (target.global_position - global_position).normalized()
	var p: Node2D = ProjectileScene.instantiate()
	p.global_position = global_position + dir * 28.0
	p.set("direction", dir)
	p.set("owner_group", "player")  # damages bosses
	p.set("damage", damage)
	p.set("speed", 480.0)
	get_parent().add_child(p)

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	if hp <= 0:
		died.emit()
		queue_free()
