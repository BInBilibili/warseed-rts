extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var map := load("res://data/maps/final_decision.tres") as MapDefinition
	var battle := load("res://data/battles/final_decision.tres") as BattleDefinition
	var grid := LogicGrid.create_for_map(map)
	var navigator := GridPathfinder.new(grid)
	var upper := PackedVector2Array([Vector2(4864,16384),Vector2(8192,9216),Vector2(12288,8192),Vector2(18432,6144)])
	var river: MapConnectorDefinition
	for link in map.connectors:
		if link.connector_id == &"river": river = link
	var links_tested := 0
	for link in map.connectors:
		if not String(link.connector_id).ends_with("_river_link"): continue
		links_tested += 1
		var north := link.connector_id == &"upper_river_link"
		var expected := upper.duplicate()
		if not north:
			for index in range(expected.size()): expected[index] = map.mirror_point(expected[index])
		if link.route_points != expected or link.width_cells != 10: failures.append("wrong jungle chain or width")
		if not river.route_points.has(expected[2]): failures.append("road must meet river exactly")
		for index in range(1,expected.size()):
			var a := expected[index-1]
			var b := expected[index]
			if not grid.is_segment_walkable(a,b): failures.append("broken direct jungle road")
			var path := navigator.find_path(a,b)
			var length := 0.0
			for step in range(1,path.size()):
				length += path[step-1].distance_to(path[step])
				if not grid.is_segment_walkable(path[step-1],path[step]): failures.append("path crosses obstacle")
			if path.is_empty() or length > a.distance_to(b)*1.05+64: failures.append("jungle path detours via main lane")
			var side := (b-a).normalized().orthogonal()*120
			for sample in range(1,20):
				var center := a.lerp(b,float(sample)/20)
				if not grid.is_world_position_walkable(center+side) or not grid.is_world_position_walkable(center-side): failures.append("road narrower than usable convoy width")
		for index in range(1,link.supply_point_ids.size()):
			var a := battle.region_dictionary().get(link.supply_point_ids[index-1]) as BattleRegionDefinition
			var b := battle.region_dictionary().get(link.supply_point_ids[index]) as BattleRegionDefinition
			if a == null or b == null or not a.adjacent_region_ids.has(b.region_id) or not b.adjacent_region_ids.has(a.region_id): failures.append("strategic adjacency not bidirectional")
	if links_tested != 2: failures.append("missing mirrored jungle road")
	# The two jungle chains share the existing river through its center crossing.
	var river_path := navigator.find_path(upper[2],map.mirror_point(upper[2]))
	if river_path.is_empty(): failures.append("north/south river connection unavailable")
	for index in range(1,river_path.size()):
		if not grid.is_segment_walkable(river_path[index-1],river_path[index]): failures.append("river transit leaves navigation")
	for failure in failures: push_error(failure)
	print("JUNGLE_LINKS chains=2 nodes=26 direct_roads=true river_transit=true failures=",failures)
	quit(0 if failures.is_empty() else 1)
