extends Area2D

@export var speed: float = 600.0
@export var damage: int = 10
@export var lifetime: float = 1.5
@export var reflect_speed_multiplier: float = 1.3
@export var reflect_damage_multiplier: float = 1.5

var direction: Vector2 = Vector2.RIGHT
var owner_group: String = "player"  # "player" or "boss" — controls who it can hit
var _reflected: bool = false

var _age: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	global_position += direction * speed * delta
	_age += delta
	if _age > lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Node) -> void:
	_try_hit(area)

func _try_hit(node: Node) -> void:
	if node == null:
		return
	# Player-fired hits enemies/bosses (incl. hero-AI which is also tagged
	# enemy during boss-side play); boss-fired hits anyone playable.
	var hit_groups: Array
	if owner_group == "player":
		hit_groups = ["enemy", "boss"]
	else:
		hit_groups = ["player", "hero_ai"]
	for g in hit_groups:
		if node.is_in_group(g):
			# Parry-reflection: if this is a boss projectile hitting a parrying
			# player, swap owners and bounce it back instead of damaging.
			if owner_group == "boss" and g == "player" and node.has_method("is_parrying") and node.is_parrying():
				_reflect()
				return
			if node.has_method("take_damage"):
				node.take_damage(damage)
			queue_free()
			return

func _reflect() -> void:
	if _reflected:
		return
	_reflected = true
	owner_group = "player" if owner_group == "boss" else "boss"
	direction = -direction
	speed *= reflect_speed_multiplier
	damage = int(damage * reflect_damage_multiplier)
	# Briefly extend lifetime so the reflected shot has time to travel back.
	lifetime = max(lifetime, _age + 1.5)
