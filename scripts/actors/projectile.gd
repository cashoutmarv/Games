extends Area2D

@export var speed: float = 600.0
@export var damage: int = 10
@export var lifetime: float = 1.5
@export var reflect_speed_multiplier: float = 1.3
@export var reflect_damage_multiplier: float = 1.5
# F4 cheat flag — projectile ignores the player's dodge/parry i-frames.
@export var pierces_iframes: bool = false

var direction: Vector2 = Vector2.RIGHT
var owner_group: String = "player"  # "player" or "boss" — controls who it can hit
var tags: Array = []  # weapon tags applied on hit: "dot", "chain", ...
var _reflected: bool = false
var _chained_once: bool = false

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
			# Parry-reflection: if this is a (non-piercing) boss projectile
			# hitting a parrying player, swap owners and bounce it back
			# instead of damaging. F4 cheat projectiles ignore the parry.
			if not pierces_iframes and owner_group == "boss" and g == "player" \
					and node.has_method("is_parrying") and node.is_parrying():
				_reflect()
				return
			if node.has_method("take_damage"):
				# Player.take_damage takes an optional pierces_iframes
				# argument; other actors take only the amount. Pass it
				# through only for the player.
				if pierces_iframes and node.is_in_group("player"):
					node.take_damage(damage, true)
				else:
					node.take_damage(damage)
				_apply_dot_if_tagged(node)
			if _chain_if_tagged(node):
				return
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

# "dot" tag: apply ~3 ticks of secondary damage after the initial hit.
func _apply_dot_if_tagged(node: Node) -> void:
	if not tags.has("dot"):
		return
	if not node.has_method("take_damage"):
		return
	var ticks: int = 3
	var dmg_per_tick: int = max(1, int(damage * 0.2))
	var t: SceneTreeTimer
	for i in ticks:
		t = node.get_tree().create_timer(0.4 * float(i + 1))
		t.timeout.connect(func():
			if is_instance_valid(node) and node.has_method("take_damage"):
				node.take_damage(dmg_per_tick)
		)

# "chain" tag: after the first hit, the projectile re-targets the nearest
# other enemy (one chain only) and continues with reduced damage.
func _chain_if_tagged(node: Node) -> bool:
	if not tags.has("chain"):
		return false
	if _chained_once:
		return false
	_chained_once = true
	var seek_groups: Array = ["enemy", "boss"] if owner_group == "player" else ["player", "hero_ai"]
	var nearest: Node2D = null
	var nearest_d: float = INF
	for g in seek_groups:
		for n in get_tree().get_nodes_in_group(g):
			if n == node or not (n is Node2D):
				continue
			var d: float = (n as Node2D).global_position.distance_to(global_position)
			if d < nearest_d:
				nearest_d = d
				nearest = n as Node2D
	if nearest == null:
		return false
	direction = (nearest.global_position - global_position).normalized()
	damage = int(damage * 0.7)
	lifetime = _age + 1.0
	return true
