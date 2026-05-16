extends RefCounted
class_name AutoTargeter

static func find_nearest(from: Node2D, group: String, max_range: float = 400.0) -> Node2D:
	if from == null:
		return null
	var nodes := from.get_tree().get_nodes_in_group(group)
	var best: Node2D = null
	var best_dist_sq := max_range * max_range
	for n in nodes:
		if not (n is Node2D):
			continue
		var d2 := from.global_position.distance_squared_to((n as Node2D).global_position)
		if d2 < best_dist_sq:
			best_dist_sq = d2
			best = n
	return best
