class_name LogicGrid
extends RefCounted

const MAP_DEFINITION: MapDefinition = preload("res://data/maps/test_arena.tres")
const CELL_SIZE := 32.0
const GRID_SIZE := Vector2i(192, 128)
const WORLD_ORIGIN := Vector2.ZERO

static var _map_cache: Dictionary = {}
static var _map_cache_mutex := Mutex.new()

var centrally_symmetric_navigation: bool = false
var blocked_cells: Dictionary = {}
var revision: int = 0
var grid_size: Vector2i = GRID_SIZE
var world_origin: Vector2 = WORLD_ORIGIN
var _navigation_grid_size := Vector2i.ZERO
var _navigation_mask := PackedByteArray()
var _navigation_rows: Array[PackedInt32Array] = []
var _navigation_dirty_rows: Dictionary = {}
var _presentation_only := false


static func create_test_map() -> LogicGrid:
	var grid := LogicGrid.new()
	# Legacy near-base wall keeps the compact navigation regression playable.
	for y in range(12):
		if y != 5 and y != 10:
			grid.set_blocked(Vector2i(11, y), true)
	grid._block_rect(Rect2i(18, 4, 2, 2))
	# Central divider with a two-cell choke.
	for y in range(12, 52):
		if y < 31 or y > 32:
			grid.set_blocked(Vector2i(47, y), true)
	# Northern and southern obstacle islands create route choices.
	grid._block_rect(Rect2i(30, 12, 8, 6))
	grid._block_rect(Rect2i(58, 46, 10, 6))
	grid._block_rect(Rect2i(67, 24, 4, 8))
	# Four-cell choke gates.
	for y in range(5, 25):
		if y < 14 or y > 17:
			grid.set_blocked(Vector2i(60, y), true)
	# Preserve a second compact 2x2 corner obstacle in the expanded arena.
	grid._block_rect(Rect2i(72, 30, 2, 2))
	# Large-theater terrain keeps the new three quarters tactically meaningful.
	for y in range(24, 104):
		if y < 62 or y > 65:
			grid.set_blocked(Vector2i(95, y), true)
	grid._block_rect(Rect2i(60, 24, 16, 12))
	grid._block_rect(Rect2i(116, 92, 20, 12))
	grid._block_rect(Rect2i(134, 48, 8, 16))
	for y in range(10, 50):
		if y < 28 or y > 35:
			grid.set_blocked(Vector2i(120, y), true)
	grid._block_rect(Rect2i(144, 60, 4, 4))
	return grid


static func create_for_battle(definition: BattleDefinition) -> LogicGrid:
	if definition == null:
		return create_test_map()
	if definition.map_definition != null:
		return create_for_map(definition.map_definition)
	var grid := LogicGrid.new() if not definition.navigation_blocked_rects.is_empty() else create_test_map()
	grid.world_origin = definition.battlefield_bounds.position
	grid.grid_size = Vector2i(
		ceili(definition.battlefield_bounds.size.x / CELL_SIZE),
		ceili(definition.battlefield_bounds.size.y / CELL_SIZE)
	)
	for rect in definition.navigation_blocked_rects:
		grid._block_rect(rect)
	# The marked engineering obstacle and authoritative navigation cover the same cells.
	for route in definition.engineering_routes:
		for rect in route.cleared_rects:
			grid._block_rect(rect)
	return grid


static func create_for_map(map_definition: MapDefinition) -> LogicGrid:
	if map_definition == null:
		return create_test_map()
	var signature: Array = [map_definition.world_origin, map_definition.grid_size, map_definition.require_central_symmetry]
	for lane in map_definition.lanes:
		if lane != null: signature.append([lane.route_points, lane.width_cells])
	for connector in map_definition.connectors:
		if connector != null: signature.append([connector.route_points, connector.width_cells])
	for region in map_definition.wild_regions:
		if region != null: signature.append([region.center, region.width_cells, region.depth_cells])
	for point in map_definition.supply_points:
		if point != null: signature.append([point.position, point.radius, point.is_base])
	var key := var_to_str(signature)
	_map_cache_mutex.lock()
	if _map_cache.has(key):
		var cached: LogicGrid = _map_cache[key]
		var copy := LogicGrid.new()
		copy.blocked_cells = cached.blocked_cells.duplicate()
		copy.revision = cached.revision
		copy.grid_size = cached.grid_size
		copy.world_origin = cached.world_origin
		copy.centrally_symmetric_navigation = cached.centrally_symmetric_navigation
		copy._copy_navigation_cache(cached)
		_map_cache_mutex.unlock()
		return copy
	_map_cache_mutex.unlock()
	var grid := LogicGrid.new()
	grid.centrally_symmetric_navigation = map_definition.require_central_symmetry
	grid.world_origin = map_definition.world_origin
	grid.grid_size = map_definition.grid_size
	# Sample cell centers against world geometry so 180-degree rotation is exact.
	grid._block_rect(Rect2i(Vector2i.ZERO, grid.grid_size))
	for lane in map_definition.lanes:
		if lane != null:
			grid._carve_polyline(lane.route_points, lane.width_cells)
	for connector in map_definition.connectors:
		if connector != null:
			grid._carve_polyline(connector.route_points, connector.width_cells)
	for region in map_definition.wild_regions:
		if region != null:
			var half_size := Vector2(region.width_cells, region.depth_cells) * 0.5 * CELL_SIZE
			grid._carve_rect(Rect2(region.center - half_size, half_size * 2.0))
	for point in map_definition.supply_points:
		if point != null:
			var radius := 768.0 if point.is_base else point.radius
			grid._carve_disc(point.position, radius)
	grid._prepare_navigation_cache()
	_map_cache_mutex.lock()
	if _map_cache.size() >= 4: _map_cache.clear()
	var template := LogicGrid.new()
	template.blocked_cells = grid.blocked_cells.duplicate()
	template.revision = grid.revision
	template.grid_size = grid.grid_size
	template.world_origin = grid.world_origin
	template.centrally_symmetric_navigation = grid.centrally_symmetric_navigation
	template._copy_navigation_cache(grid)
	_map_cache[key] = template
	_map_cache_mutex.unlock()
	return grid


func _carve_polyline(points: PackedVector2Array, width_cells: int) -> void:
	var radius := width_cells * CELL_SIZE * 0.5
	for index in range(1, points.size()):
		var a := points[index - 1]
		var b := points[index]
		var start := world_to_cell(a.min(b) - Vector2.ONE * radius).max(Vector2i.ZERO)
		var end := world_to_cell(a.max(b) + Vector2.ONE * radius).min(grid_size - Vector2i.ONE)
		for x in range(start.x, end.x + 1):
			for y in range(start.y, end.y + 1):
				var cell := Vector2i(x, y)
				var center := cell_to_world(cell)
				var closest := Geometry2D.get_closest_point_to_segment(center, a, b)
				if center.distance_squared_to(closest) <= radius * radius:
					set_blocked(cell, false)


func _carve_disc(position: Vector2, radius: float) -> void:
	var start := world_to_cell(position - Vector2.ONE * radius).max(Vector2i.ZERO)
	var end := world_to_cell(position + Vector2.ONE * radius).min(grid_size - Vector2i.ONE)
	for x in range(start.x, end.x + 1):
		for y in range(start.y, end.y + 1):
			var cell := Vector2i(x, y)
			if cell_to_world(cell).distance_squared_to(position) <= radius * radius:
				set_blocked(cell, false)


func _carve_rect(rect: Rect2) -> void:
	var start := world_to_cell(rect.position).max(Vector2i.ZERO)
	var end := world_to_cell(rect.end).min(grid_size - Vector2i.ONE)
	for x in range(start.x, end.x + 1):
		for y in range(start.y, end.y + 1):
			var cell := Vector2i(x, y)
			if rect.has_point(cell_to_world(cell)):
				set_blocked(cell, false)


func _block_rect(rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			set_blocked(Vector2i(x, y), true)


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func set_blocked(cell: Vector2i, blocked: bool) -> void:
	if _presentation_only:
		push_error("Cannot mutate a published presentation grid")
		return
	if not is_in_bounds(cell):
		return
	if blocked_cells.has(cell) == blocked:
		return
	if blocked:
		if not blocked_cells.has(cell):
			blocked_cells[cell] = true
			revision += 1
	elif blocked_cells.has(cell):
		blocked_cells.erase(cell)
		revision += 1
	if _navigation_grid_size == grid_size:
		_navigation_mask[cell.y * grid_size.x + cell.x] = 1 if blocked else 0
		_navigation_dirty_rows[cell.y] = true


func _copy_navigation_cache(source: LogicGrid) -> void:
	_navigation_grid_size = source._navigation_grid_size
	# Packed arrays are reference values in GDScript. The mask is mutated in
	# place; duplicate it. Row runs are replaced wholesale, never edited in place.
	_navigation_mask = source._navigation_mask.duplicate()
	_navigation_rows = source._navigation_rows.duplicate()
	_navigation_dirty_rows = source._navigation_dirty_rows.duplicate()


func _prepare_navigation_cache() -> void:
	if _navigation_grid_size != grid_size:
		_navigation_grid_size = grid_size
		_navigation_mask.resize(grid_size.x * grid_size.y)
		_navigation_mask.fill(0)
		for cell: Vector2i in blocked_cells:
			_navigation_mask[cell.y * grid_size.x + cell.x] = 1
		_navigation_rows.resize(grid_size.y)
		for y in range(grid_size.y): _navigation_dirty_rows[y] = true
	for y: int in _navigation_dirty_rows:
		var runs := PackedInt32Array()
		var start := -1
		var offset := y * grid_size.x
		for x in range(grid_size.x):
			if _navigation_mask[offset + x] != 0:
				if start < 0: start = x
			elif start >= 0:
				runs.append(start)
				runs.append(x - start)
				start = -1
		if start >= 0:
			runs.append(start)
			runs.append(grid_size.x - start)
		_navigation_rows[y] = runs
	_navigation_dirty_rows.clear()


func apply_navigation_solidity(astar: AStarGrid2D) -> void:
	_prepare_navigation_cache()
	astar.fill_solid_region(astar.region, false)
	for y in range(grid_size.y):
		var runs := _navigation_rows[y]
		for index in range(0, runs.size(), 2):
			astar.fill_solid_region(Rect2i(runs[index], y, runs[index + 1], 1), true)


func has_rotationally_symmetric_solidity() -> bool:
	_prepare_navigation_cache()
	var rotated := _navigation_mask.duplicate()
	rotated.reverse()
	return rotated == _navigation_mask


func copy_for_presentation() -> LogicGrid:
	_prepare_navigation_cache()
	var copy := LogicGrid.new()
	copy.grid_size = grid_size
	copy.world_origin = world_origin
	copy.revision = revision
	copy.centrally_symmetric_navigation = centrally_symmetric_navigation
	copy._copy_navigation_cache(self)
	copy._presentation_only = true
	return copy


func blocked_row_spans() -> Array[PackedInt32Array]:
	_prepare_navigation_cache()
	return _navigation_rows.duplicate()


func is_blocked(cell: Vector2i) -> bool:
	if _presentation_only:
		return not is_in_bounds(cell) or _navigation_mask[cell.y * grid_size.x + cell.x] != 0
	return not is_in_bounds(cell) or blocked_cells.has(cell)


func is_world_position_walkable(world_position: Vector2) -> bool:
	return not is_blocked(world_to_cell(world_position))


func is_segment_walkable(from_position: Vector2, to_position: Vector2) -> bool:
	if centrally_symmetric_navigation:
		return _grid_segment_walkable(from_position, to_position)
	var distance := from_position.distance_to(to_position)
	var sample_count := maxi(1, ceili(distance / 8.0))
	for index in range(sample_count + 1):
		if not is_world_position_walkable(from_position.lerp(to_position, float(index) / sample_count)):
			return false
	return true


func _grid_segment_walkable(from_position: Vector2, to_position: Vector2) -> bool:
	# Traverse every crossed cell. Fixed-distance sampling can miss a thin corner
	# on a long route, then reject the same route when a unit takes a short step.
	var cell := world_to_cell(from_position)
	var end_cell := world_to_cell(to_position)
	if is_blocked(cell) or is_blocked(end_cell): return false
	var delta := to_position - from_position
	var step := Vector2i(signf(delta.x), signf(delta.y))
	var interval_x := INF
	var interval_y := INF
	var next_x := INF
	var next_y := INF
	if step.x != 0:
		interval_x = CELL_SIZE / absf(delta.x)
		next_x = (world_origin.x + (cell.x + (1 if step.x > 0 else 0)) * CELL_SIZE - from_position.x) / delta.x
	if step.y != 0:
		interval_y = CELL_SIZE / absf(delta.y)
		next_y = (world_origin.y + (cell.y + (1 if step.y > 0 else 0)) * CELL_SIZE - from_position.y) / delta.y
	while cell != end_cell:
		if cell.x == end_cell.x: next_x = INF
		if cell.y == end_cell.y: next_y = INF
		if absf(next_x - next_y) < 0.000000001:
			# Match AStar's no-corner-cutting rule in both rotation directions.
			if is_blocked(cell + Vector2i(step.x, 0)) or is_blocked(cell + Vector2i(0, step.y)): return false
			cell += step
			next_x += interval_x
			next_y += interval_y
		elif next_x < next_y:
			cell.x += step.x
			next_x += interval_x
		else:
			cell.y += step.y
			next_y += interval_y
		if is_blocked(cell): return false
	return true


func get_corridor_width(cell: Vector2i, direction: Vector2i) -> int:
	if is_blocked(cell):
		return 0
	var perpendicular := Vector2i(-direction.y, direction.x)
	var width := 1
	var cursor := cell + perpendicular
	while not is_blocked(cursor):
		width += 1
		cursor += perpendicular
	cursor = cell - perpendicular
	while not is_blocked(cursor):
		width += 1
		cursor -= perpendicular
	return width


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local := world_position - world_origin
	return Vector2i(floori(local.x / CELL_SIZE), floori(local.y / CELL_SIZE))


func cell_to_world(cell: Vector2i) -> Vector2:
	return world_origin + Vector2(cell) * CELL_SIZE + Vector2.ONE * CELL_SIZE * 0.5


func get_world_rect() -> Rect2:
	return Rect2(world_origin, Vector2(grid_size) * CELL_SIZE)


func get_footprint_cells(world_position: Vector2, footprint_size: Vector2i) -> Array[Vector2i]:
	if centrally_symmetric_navigation:
		var map_center := world_origin + Vector2(grid_size) * (CELL_SIZE * 0.5)
		if world_position.x > map_center.x or world_position.x == map_center.x and world_position.y > map_center.y:
			# Even-width footprints have a half-cell bias. Reflect the canonical
			# footprint as well as its center so opposing HQs block mirrored cells.
			var canonical := get_footprint_cells(map_center * 2.0 - world_position, footprint_size)
			var rotated: Array[Vector2i] = []
			for cell in canonical:
				rotated.append(grid_size - Vector2i.ONE - cell)
			return rotated
	var center := world_to_cell(world_position)
	var first := center - Vector2i((footprint_size.x - 1) / 2, (footprint_size.y - 1) / 2)
	var cells: Array[Vector2i] = []
	for x in range(first.x, first.x + footprint_size.x):
		for y in range(first.y, first.y + footprint_size.y):
			cells.append(Vector2i(x, y))
	return cells


func get_footprint_work_cells(footprint_cells: Array[Vector2i]) -> Array[Vector2i]:
	var footprint_lookup: Dictionary = {}
	var cardinal_offsets: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for cell in footprint_cells:
		footprint_lookup[cell] = true
	var candidates: Array[Vector2i] = []
	for cell in footprint_cells:
		for offset in cardinal_offsets:
			var candidate: Vector2i = cell + offset
			if not footprint_lookup.has(candidate) and not candidates.has(candidate) and not is_blocked(candidate):
				candidates.append(candidate)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return candidates


func get_blocked_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _presentation_only:
		for y in range(_navigation_rows.size()):
			var runs := _navigation_rows[y]
			for index in range(0,runs.size(),2):
				for x in range(runs[index],runs[index]+runs[index+1]): cells.append(Vector2i(x,y))
		return cells
	for cell_variant in blocked_cells.keys():
		cells.append(cell_variant as Vector2i)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells
