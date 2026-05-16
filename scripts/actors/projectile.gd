extends Area2D

@export var speed: float = 600.0
@export var damage: int = 10
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT
var owner_group: String = "player"  # "player" or "boss" — controls who it can hit

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
	# Player-fired projectiles damage enemies and boss; boss-fired damage player.
	var hit_groups: Array
	if owner_group == "player":
		hit_groups = ["enemy", "boss"]
	else:
		hit_groups = ["player"]
	for g in hit_groups:
		if node.is_in_group(g):
			if node.has_method("take_damage"):
				node.take_damage(damage)
			queue_free()
			return
