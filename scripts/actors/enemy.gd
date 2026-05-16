extends CharacterBody2D

signal died

@export var max_hp: int = 30
@export var move_speed: float = 80.0
@export var contact_damage: int = 5
@export var damage_cadence: float = 0.5

var hp: int = max_hp
var _damage_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp

func _physics_process(delta: float) -> void:
	var player := _get_player()
	if player != null:
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		_damage_timer -= delta
		if _damage_timer <= 0.0 and global_position.distance_to(player.global_position) < 24.0:
			if player.has_method("take_damage"):
				player.take_damage(contact_damage)
			_damage_timer = damage_cadence

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	if hp <= 0:
		died.emit()
		queue_free()
