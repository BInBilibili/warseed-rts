class_name LegionGatherNavigation
extends RefCounted

# Local routes use public terrain and own units only. Every accepted step is
# still checked by the authoritative mover against actual physical occupancy.
class State extends RefCounted:
	var previous := Vector2(INF,INF)
	var stalled := 0
	var retry_tick := -1
	var goal := Vector2(INF,INF)
	var route := PackedVector2Array()
	var index := 1
	var observed_tick := -1
	var best_distance := INF
	var progress_tick := -1
	func duplicate_value() -> State:
		var copy := State.new()
		copy.previous=previous; copy.stalled=stalled; copy.retry_tick=retry_tick
		copy.goal=goal; copy.route=route.duplicate(); copy.index=index; copy.observed_tick=observed_tick
		copy.best_distance=best_distance; copy.progress_tick=progress_tick
		return copy

static func _clear(origin: Vector2, target: Vector2, own: PackedVector2Array, grid: LogicGrid) -> bool:
	if not LegionTransitGeometry.segment_fits(grid,origin,target): return false
	for position in own:
		if Geometry2D.get_closest_point_to_segment(position,origin,target).distance_squared_to(position)<24.0*24.0-0.01: return false
	return true

static func _grid_route(grid: LogicGrid, origin: Vector2, goal: Vector2, own: PackedVector2Array) -> PackedVector2Array:
	var target := origin.move_toward(goal,224.0)
	var astar := AStarGrid2D.new()
	astar.region=Rect2i(-18,-18,37,37); astar.cell_size=Vector2.ONE*16.0
	astar.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in range(-18,19):
		for x in range(-18,19):
			var cell := Vector2i(x,y); var point := origin+Vector2(cell)*16.0
			var blocked := not LegionTransitGeometry.segment_fits(grid,point,point,40.0)
			if not blocked:
				for position in own:
					if point.distance_squared_to(position)<32.0*32.0: blocked=true; break
			astar.set_point_solid(cell,blocked)
	astar.set_point_solid(Vector2i.ZERO,false)
	var finish := Vector2i(((target-origin)/16.0).round())
	if astar.is_point_solid(finish): return PackedVector2Array()
	var cells := astar.get_id_path(Vector2i.ZERO,finish)
	if cells.is_empty(): return PackedVector2Array()
	var path := PackedVector2Array([origin])
	for index in range(1,cells.size()): path.append(origin+Vector2(cells[index])*16.0)
	if target.distance_to(goal)<=0.01: path.append(goal)
	for index in range(1,path.size()):
		if not _clear(path[index-1],path[index],own,grid): return PackedVector2Array()
	var result := PackedVector2Array([origin])
	var index := 0
	while index<path.size()-1:
		var next := path.size()-1
		while next>index+1 and not _clear(path[index],path[next],own,grid): next-=1
		result.append(path[next]); index=next
	return result

static func local_route(grid: LogicGrid, origin: Vector2, goal: Vector2, own: PackedVector2Array) -> PackedVector2Array:
	var grid_route := _grid_route(grid,origin,goal,own)
	if not grid_route.is_empty(): return grid_route
	# A lattice can miss the exact passage between two 48-spaced bodies. Add
	# analytical gap midpoints and a circumscribed obstacle polygon, then
	# validate every visibility edge against the real swept clearance.
	var graph := AStar2D.new()
	var target := origin.move_toward(goal,224.0)
	var points := PackedVector2Array([origin])
	if _clear(target,target,own,grid): points.append(target)
	for center in own:
		if center.distance_to(origin)>300.0: continue
		for x in [-24.0,24.0]:
			for y in [-24.0,24.0]:
				var point := center+Vector2(x,y)
				if _clear(point,point,own,grid): points.append(point)
		for corner in range(8):
			var point := center+Vector2.from_angle(corner*PI/4.0)*27.0
			if point.distance_to(origin)<=320.0 and _clear(point,point,own,grid): points.append(point)
	for first in range(own.size()):
		if own[first].distance_to(origin)>300.0: continue
		for second in range(first+1,own.size()):
			var gap := own[first].distance_to(own[second])
			if gap<47.99 or gap>96.0: continue
			var point := (own[first]+own[second])*0.5
			if _clear(point,point,own,grid): points.append(point)
			var normal := (own[second]-own[first]).normalized().orthogonal()
			for sign_value in [-1.0,1.0]:
				var approach: Vector2 = point+normal*24.0*sign_value
				if _clear(approach,approach,own,grid): points.append(approach)
	if points.size()<2: return PackedVector2Array()
	for index in range(points.size()): graph.add_point(index,points[index])
	for first in range(points.size()):
		for second in range(first+1,points.size()):
			if points[first].distance_to(points[second])>160.0: continue
			if _clear(points[first],points[second],own,grid): graph.connect_points(first,second)
	var ranked: Array[int] = []
	for index in range(1,points.size()): ranked.append(index)
	ranked.sort_custom(func(a: int,b: int) -> bool:
		var da := points[a].distance_squared_to(goal); var db := points[b].distance_squared_to(goal)
		return da<db if not is_equal_approx(da,db) else a<b)
	for index in ranked:
		if points[index].distance_to(goal)>=origin.distance_to(goal)-2.0: break
		var path := graph.get_point_path(0,index)
		if path.size()>1: return path
	return PackedVector2Array()

static func route(world: SimulationWorld, unit: UnitState, goal: Vector2, state: State) -> PackedVector2Array:
	if unit.reformation!=null and unit.reformation.phase==LegionReformationState.Phase.REFORMING:
		state.route=PackedVector2Array()
		return PackedVector2Array()
	if unit.position.distance_to(goal)<=6.0:
		state.route=PackedVector2Array(); state.stalled=0; state.previous=unit.position
		return PackedVector2Array()
	if state.observed_tick!=world.current_tick:
		state.stalled=state.stalled+1 if state.previous.distance_to(goal)-unit.position.distance_to(goal)<1.0 else 0
		state.previous=unit.position; state.observed_tick=world.current_tick
	if state.goal.distance_to(goal)>1.0:
		state.route=PackedVector2Array(); state.goal=goal; state.stalled=0
		state.best_distance=unit.position.distance_to(goal); state.progress_tick=world.current_tick
	if unit.position.distance_to(goal)<state.best_distance-1.0:
		state.best_distance=unit.position.distance_to(goal); state.progress_tick=world.current_tick
	while state.index<state.route.size() and unit.position.distance_to(state.route[state.index])<=2.0: state.index+=1
	if state.index>=state.route.size(): state.route=PackedVector2Array()
	var own := PackedVector2Array()
	for other: UnitState in world.units.values():
		if other.enabled and other.faction_id==unit.faction_id and other.entity_id!=unit.entity_id and other.position.distance_to(unit.position)<448.0: own.append(other.position)
	if not state.route.is_empty() and not _clear(unit.position,state.route[state.index],own,world.logic_grid): state.route=PackedVector2Array()
	if state.route.is_empty() and (state.stalled>=5 or world.current_tick-state.progress_tick>=20) and world.current_tick>=state.retry_tick:
		state.retry_tick=world.current_tick+10
		state.route=local_route(world.logic_grid,unit.position,goal,own); state.index=1
	if state.route.is_empty(): return PackedVector2Array()
	# Consume one cached waypoint per physical tick. Returning the entire suffix
	# lets the mover pass a corner without the persistent cursor observing it.
	return PackedVector2Array([unit.position,state.route[state.index]])
