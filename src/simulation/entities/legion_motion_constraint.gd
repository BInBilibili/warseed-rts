class_name LegionMotionConstraint
extends RefCounted

var partner_id := 0
var radius := 240.0
var ground_radius := 0.0
var transit_path: LegionTransitGeometry.PathData
var previous_batch := PackedInt32Array()
var next_batch := PackedInt32Array()
var exit_lane_origin := Vector2(INF,INF)
var exit_lane_normal := Vector2.ZERO
var exit_lane_side := 0.0
var exit_lane_clearance := 0.0

func _init(id: int = 0) -> void:
	partner_id = id

# Both members read the partner's latest position, regardless of move order.
# A blocked step may take a bounded local sidestep, never extra movement.
func constrain(from: Vector2, proposed: Vector2, entity_id: int, units: Dictionary, grid: LogicGrid = null, finder: GridPathfinder = null) -> Vector2:
	var partner := units.get(partner_id) as UnitState
	var moving := units.get(entity_id) as UnitState
	if moving!=null and moving.flexible_legion_movement: partner=null
	if partner == null or not partner.enabled:
		if _clear(from,proposed,entity_id,units,grid): return proposed
		for degrees in [30,-30,60,-60,90,-90]:
			var side := from+(proposed-from).rotated(deg_to_rad(degrees))
			if _clear(from,side,entity_id,units,grid): return side
		return _separate(from,proposed,entity_id,units,grid,finder,null,0.0,0.0)
	var center := partner.position
	var limit := maxf(radius,from.distance_to(center))
	var path_limit := radius
	if grid != null and finder != null:
		var current := LegionProtectionPlanner.route(grid,finder,from,center)
		if not current.is_empty(): path_limit = maxf(radius,LegionProtectionPlanner.path_length(current))
	var result := _clip(from,proposed,center,limit,grid,finder,path_limit)
	if _clear(from,result,entity_id,units,grid): return result
	var delta := proposed-from
	for degrees in [30,-30,60,-60,90,-90]:
		var side := _clip(from,from+delta.rotated(deg_to_rad(degrees)),center,limit,grid,finder,path_limit)
		if side.distance_squared_to(from) > 0.01 and _clear(from,side,entity_id,units,grid): return side
	return _separate(from,proposed,entity_id,units,grid,finder,partner,limit,path_limit)

# Cancellation can leave a member between two already-solid friendly bodies.
# Escape along their actual normals/tangents, including away from the goal.
# Every candidate still passes the same swept overlap, terrain and escort
# constraints, and spends at most the caller's remaining movement budget.
func _separate(from: Vector2, proposed: Vector2, entity_id: int, units: Dictionary, grid: LogicGrid, finder: GridPathfinder, partner: UnitState, limit: float, path_limit: float) -> Vector2:
	var unit := units.get(entity_id) as UnitState
	if unit==null or unit.reformation==null or unit.reformation.phase!=LegionReformationState.Phase.SEPARATING: return from
	var directions: Array[Vector2] = []
	var sum := Vector2.ZERO
	var ids := units.keys(); ids.sort()
	for id: int in ids:
		var other := units[id] as UnitState
		if not other.enabled or id==entity_id or other.faction_id!=unit.faction_id: continue
		var offset := from-other.position
		if offset.length()>=24.0: continue
		var normal := offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT
		sum+=normal
		directions.append_array([normal,normal.orthogonal(),-normal.orthogonal()])
	if not sum.is_zero_approx(): directions.push_front(sum.normalized())
	for direction in directions:
		for scale: float in [1.0,0.5,0.25]:
			var point := from+direction*from.distance_to(proposed)*scale
			if partner!=null: point=_clip(from,point,partner.position,limit,grid,finder,path_limit)
			if point.distance_squared_to(from)>0.000001 and _clear(from,point,entity_id,units,grid): return point
	return from

func _clip(from: Vector2, proposed: Vector2, center: Vector2, limit: float, grid: LogicGrid, finder: GridPathfinder, path_limit: float) -> Vector2:
	var result := proposed
	if proposed.distance_squared_to(center) > limit*limit:
		var delta := proposed-from
		var a := delta.length_squared()
		if a <= 0.000001: return from
		var b := 2.0*(from-center).dot(delta)
		var c := (from-center).length_squared()-limit*limit
		var t := clampf((-b+sqrt(maxf(0.0,b*b-4.0*a*c)))/(2.0*a),0.0,1.0)
		result = from+delta*t
	if grid != null and finder != null and not _path_within(result,center,grid,finder,path_limit):
		var lo := 0.0; var hi := 1.0
		for retry in range(12):
			var mid := (lo+hi)*0.5
			if _path_within(from.lerp(result,mid),center,grid,finder,path_limit): lo=mid
			else: hi=mid
		result=from.lerp(result,lo)
	return result

func _path_within(point: Vector2, center: Vector2, grid: LogicGrid, finder: GridPathfinder, limit: float) -> bool:
	var path := LegionProtectionPlanner.route(grid,finder,point,center)
	# A tolerance here compounds: the next move inherits the previous gap as
	# its limit. Check the actual rounded position without extending that limit.
	return not path.is_empty() and LegionProtectionPlanner.path_length(path) <= limit

func _clear(from: Vector2, result: Vector2, entity_id: int, units: Dictionary, grid: LogicGrid) -> bool:
	if exit_lane_origin.is_finite() and exit_lane_side!=0.0:
		var old_lateral := (from-exit_lane_origin).dot(exit_lane_normal)*exit_lane_side
		var new_lateral := (result-exit_lane_origin).dot(exit_lane_normal)*exit_lane_side
		# A released body cannot drift back into the still-live through lane.
		if new_lateral<minf(old_lateral,exit_lane_clearance)-0.001: return false
	if grid != null and not grid.is_segment_walkable(from,result): return false
	if grid!=null and ground_radius>0.0 and not LegionTransitGeometry.segment_fits(grid,from,result,ground_radius): return false
	if transit_path!=null and not previous_batch.is_empty():
		var limit := INF
		for id in previous_batch:
			var previous := units.get(id) as UnitState
			if previous!=null and previous.enabled:
				limit=minf(limit,LegionTransitGeometry.progress_at(transit_path,previous.position)-160.0)
		var old_progress := LegionTransitGeometry.progress_at(transit_path,from)
		if LegionTransitGeometry.progress_at(transit_path,result)>maxf(limit,old_progress)+0.001: return false
	if transit_path!=null and not next_batch.is_empty():
		var limit := -INF
		for id in next_batch:
			var follower := units.get(id) as UnitState
			if follower!=null and follower.enabled:
				limit=maxf(limit,LegionTransitGeometry.progress_at(transit_path,follower.position)+160.0)
		var old_progress := LegionTransitGeometry.progress_at(transit_path,from)
		if LegionTransitGeometry.progress_at(transit_path,result)<minf(limit,old_progress)-0.001: return false
	# Authority checks physical occupancy without feeding hidden identities to
	# the planner. Existing overlaps may separate, never worsen.
	for other: UnitState in units.values():
		if other.entity_id == entity_id or not other.enabled: continue
		var moving := units.get(entity_id) as UnitState
		if moving!=null and moving.flexible_legion_movement and moving.faction_id==other.faction_id: continue
		if moving!=null and LegionReformationSystem.ignores_pair(moving,other): continue
		var initial := from.distance_squared_to(other.position)
		var required := minf(24.0*24.0,initial)
		if Geometry2D.get_closest_point_to_segment(other.position,from,result).distance_squared_to(other.position) < required-0.01:
			return false
	return true
