class_name MapDefinition
extends Resource

@export var definition_id: StringName = &"test_arena"
@export var cell_size: float = 32.0
@export var grid_size: Vector2i = Vector2i(192, 128)
@export var world_origin: Vector2 = Vector2.ZERO
@export var player_spawn_cell: Vector2i = Vector2i(15, 10)
@export var enemy_spawn_cell: Vector2i = Vector2i(86, 54)
@export var camera_start_cell: Vector2i = Vector2i(14, 10)
@export var require_central_symmetry: bool = false
@export var main_lane_width_cells: int = 12
@export var side_lane_width_cells: int = 7
@export var lanes: Array[MapLaneDefinition] = []
@export var supply_points: Array[MapSupplyPointDefinition] = []
@export var wild_regions: Array[MapWildRegionDefinition] = []
@export var connectors: Array[MapConnectorDefinition] = []


func get_world_rect() -> Rect2:
	return Rect2(world_origin, Vector2(grid_size) * cell_size)


func cell_to_world(cell: Vector2i) -> Vector2:
	return world_origin + Vector2(cell) * cell_size + Vector2.ONE * cell_size * 0.5


func mirror_point(point: Vector2) -> Vector2:
	return get_world_rect().get_center() * 2.0 - point


func validate() -> Array[String]:
	var issues: Array[String] = []
	if definition_id.is_empty() or cell_size != 32.0 or grid_size.x <= 0 or grid_size.y <= 0:
		issues.append("invalid map ID or grid (navigation uses 32-unit cells)")
	var bounds := get_world_rect()
	if not world_origin.is_finite():
		issues.append("nonfinite map origin")
	for cell in [player_spawn_cell, enemy_spawn_cell, camera_start_cell]:
		if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
			issues.append("spawn or camera cell outside map")
	if require_central_symmetry and player_spawn_cell + enemy_spawn_cell != grid_size - Vector2i.ONE:
		issues.append("spawn cells are not centrally symmetric")
	var lane_ids := _index(lanes, &"lane_id", issues)
	var point_ids := _index(supply_points, &"point_id", issues)
	var wild_ids := _index(wild_regions, &"region_id", issues)
	var connector_ids := _index(connectors, &"connector_id", issues)
	for lane in lanes:
		if lane == null:
			continue
		_check_route(lane.route_points, lane.width_cells, issues)
		_check_references(lane.supply_point_ids, point_ids, issues)
		_check_references(lane.wild_region_ids, wild_ids, issues)
		if require_central_symmetry:
			var other := lane_ids.get(lane.mirror_id) as MapLaneDefinition
			if other == null or other.mirror_id != lane.lane_id or other.width_cells != lane.width_cells or not _rotated_routes_match(lane.route_points, other.route_points):
				issues.append("lane symmetry mismatch: %s" % lane.lane_id)
	for point in supply_points:
		if point == null:
			continue
		if not point.position.is_finite() or not bounds.has_point(point.position) or point.radius <= 0 or point.supply_per_settlement < 0 or point.capture_ticks <= 0 or point.owner_faction_id not in [0, 1, 2]:
			issues.append("invalid supply point: %s" % point.point_id)
		if not point.lane_id.is_empty() and not lane_ids.has(point.lane_id):
			issues.append("supply point references unknown lane")
		if point.tier < MapSupplyPointDefinition.Tier.GENERIC or point.tier > MapSupplyPointDefinition.Tier.JUNGLE_LARGE:
			issues.append("invalid supply tier")
		if point.tier != MapSupplyPointDefinition.Tier.GENERIC:
			if point.is_base != (point.tier == MapSupplyPointDefinition.Tier.COMMAND) or point.is_wild != (point.tier in [MapSupplyPointDefinition.Tier.JUNGLE_SMALL, MapSupplyPointDefinition.Tier.JUNGLE_LARGE]):
				issues.append("supply tier/category mismatch")
		if require_central_symmetry:
			var other := point_ids.get(point.mirror_id) as MapSupplyPointDefinition
			var owner := 3 - point.owner_faction_id if point.owner_faction_id != 0 else 0
			if other == null or other.mirror_id != point.point_id or mirror_point(point.position).distance_to(other.position) > 0.01:
				issues.append("supply geometry mismatch: %s" % point.point_id)
			elif other.tier != point.tier or other.supply_per_settlement != point.supply_per_settlement or other.capture_ticks != point.capture_ticks or other.radius != point.radius or other.is_base != point.is_base or other.is_wild != point.is_wild or other.owner_faction_id != owner:
				issues.append("supply economy/ownership mismatch: %s" % point.point_id)
	for region in wild_regions:
		if region == null:
			continue
		if not region.center.is_finite() or not bounds.has_point(region.center) or region.width_cells <= 0 or region.depth_cells <= 0 or region.connected_lane_ids.size() < 2:
			issues.append("invalid wild region")
		_check_references(region.connected_lane_ids, lane_ids, issues)
		if require_central_symmetry:
			var other := wild_ids.get(region.mirror_id) as MapWildRegionDefinition
			if other == null or other.mirror_id != region.region_id or mirror_point(region.center).distance_to(other.center) > 0.01 or other.width_cells != region.width_cells or other.depth_cells != region.depth_cells:
				issues.append("wild region symmetry mismatch")
	for connector in connectors:
		if connector == null:
			continue
		_check_references(connector.supply_point_ids, point_ids, issues)
		_check_route(connector.route_points, connector.width_cells, issues)
		if connector.from_lane_id == connector.to_lane_id or not lane_ids.has(connector.from_lane_id) or not lane_ids.has(connector.to_lane_id):
			issues.append("invalid cross-lane connection")
		if require_central_symmetry:
			var other := connector_ids.get(connector.mirror_id) as MapConnectorDefinition
			if other == null or other.mirror_id != connector.connector_id or other.width_cells != connector.width_cells or not _rotated_routes_match(connector.route_points, other.route_points):
				issues.append("connector symmetry mismatch")
	return issues


func _index(resources: Array, field: StringName, issues: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for resource in resources:
		if resource == null:
			issues.append("null map resource")
			continue
		var id := StringName(resource.get(field))
		if id.is_empty() or result.has(id):
			issues.append("empty or duplicate map element ID: %s" % id)
		result[id] = resource
	return result


func _check_references(ids: Array[StringName], known: Dictionary, issues: Array[String]) -> void:
	var seen: Array[StringName] = []
	for id in ids:
		if not known.has(id) or seen.has(id):
			issues.append("unknown or repeated map reference: %s" % id)
		seen.append(id)


func _check_route(points: PackedVector2Array, width: int, issues: Array[String]) -> void:
	if points.size() < 2 or width <= 0:
		issues.append("invalid route width or points")
	for point in points:
		if not point.is_finite() or not get_world_rect().has_point(point):
			issues.append("route point outside map")


func _rotated_routes_match(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	var forwards := true
	var backwards := true
	for i in range(a.size()):
		forwards = forwards and mirror_point(a[i]).distance_to(b[i]) < 0.01
		backwards = backwards and mirror_point(a[i]).distance_to(b[b.size() - 1 - i]) < 0.01
	return forwards or backwards
