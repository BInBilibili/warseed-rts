class_name TestFinalDecisionMap
extends RefCounted


func run() -> Array[String]:
	var failures: Array[String] = []
	var map := load("res://data/maps/final_decision.tres") as MapDefinition
	if map == null:
		return ["final decision map failed to load"]
	_expect(map.validate().is_empty(), "layout validation: %s" % [map.validate()], failures)
	_expect(map.get_world_rect().size == Vector2(32768, 24576), "super-large map bounds", failures)
	_expect(map.lanes.size() == 3 and map.connectors.size() == 9 and map.supply_points.size() == 26, "three lanes, six cross-lane paths, two jungle river links, a river crossing, twenty-six supply nodes", failures)
	var tier_counts: Dictionary = {}
	for point in map.supply_points:
		tier_counts[point.tier] = int(tier_counts.get(point.tier, 0)) + 1
	_expect(tier_counts == {MapSupplyPointDefinition.Tier.COMMAND: 2, MapSupplyPointDefinition.Tier.HIGH_GROUND: 6, MapSupplyPointDefinition.Tier.INNER: 6, MapSupplyPointDefinition.Tier.OUTER: 6, MapSupplyPointDefinition.Tier.JUNGLE_SMALL: 4, MapSupplyPointDefinition.Tier.JUNGLE_LARGE: 2}, "exact tier counts", failures)
	for lane in map.lanes:
		var expected: Array[StringName] = [&"blue_base"]
		for tier in ["high", "inner", "outer"]: expected.append(StringName("blue_%s_%s" % [lane.lane_id, tier]))
		for tier in ["outer", "inner", "high"]: expected.append(StringName("red_%s_%s" % [lane.lane_id, tier]))
		expected.append(&"red_base")
		_expect(lane.supply_point_ids == expected, "lane ordered from blue HQ through three tiers to red HQ: %s" % lane.lane_id, failures)
	var catalog := load("res://data/maps/map_catalog.tres") as MapContentCatalog
	_expect(catalog != null and catalog.validate().is_empty() and catalog.get_map(&"final_decision") == map, "catalog resolves validated typed map", failures)
	var grid := LogicGrid.create_for_map(map)
	var navigator := GridPathfinder.new(grid)
	var origin := map.cell_to_world(map.player_spawn_cell)
	var mismatches := 0
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var cell := Vector2i(x, y)
			if grid.is_blocked(cell) != grid.is_blocked(grid.grid_size - Vector2i.ONE - cell):
				mismatches += 1
	_expect(mismatches == 0, "every navigation cell rotates exactly (mismatches=%d)" % mismatches, failures)
	for point in map.supply_points:
		var path := navigator.find_path(origin, point.position)
		_expect(not path.is_empty(), "supply node is reachable: %s" % point.point_id, failures)
		for i in range(1, path.size()):
			_expect(grid.is_segment_walkable(path[i - 1], path[i]), "smoothed path remains walkable: %s" % point.point_id, failures)
		var mirror_path := navigator.find_path(map.mirror_point(origin), map.mirror_point(point.position))
		_expect(absf(_length(path) - _length(mirror_path)) < 64.0, "both sides have equivalent route distance: %s" % point.point_id, failures)
	_expect(not grid.is_world_position_walkable(Vector2(4000, 9000)), "terrain limits cross-country shortcuts", failures)
	_expect(grid.get_corridor_width(grid.world_to_cell(Vector2(12000, 2048)), Vector2i.RIGHT) == 32, "main highway is 32 cells wide", failures)
	_expect(grid.get_corridor_width(grid.world_to_cell(Vector2(19456, 4096)), Vector2i.DOWN) in [11, 12], "diagonal jungle connector remains narrow", failures)
	# Rejection evidence must be independent of the source fixture's own claims.
	var broken := map.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as MapDefinition
	broken.supply_points[0].supply_per_settlement += 1
	_expect(not broken.validate().is_empty(), "unequal mirrored economy rejected", failures)
	broken = map.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as MapDefinition
	broken.lanes[0].route_points[1] += Vector2(32, 0)
	_expect(not broken.validate().is_empty(), "asymmetric road rejected", failures)
	broken = map.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as MapDefinition
	broken.connectors[0].to_lane_id = &"missing"
	_expect(not broken.validate().is_empty(), "unknown connector endpoint rejected", failures)
	broken = map.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as MapDefinition
	broken.supply_points[1].point_id = broken.supply_points[0].point_id
	_expect(not broken.validate().is_empty(), "duplicate supply ID rejected", failures)
	_expect(map.validate().is_empty(), "rejection tests do not mutate cached resources", failures)
	return failures


func _length(path: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
