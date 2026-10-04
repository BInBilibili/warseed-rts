class_name LegionDeploymentPlanner
extends RefCounted

static var _cache: Dictionary[String,PackedVector2Array] = {}

static func offsets(profile: StringName, action: LegionSpatialState.Action, spacing: float, compact_depth: bool = false) -> PackedVector2Array:
	var key := str([profile,action,spacing,compact_depth])
	if _cache.has(key): return _cache[key].duplicate()
	var source := LegionSpatialExecutor.layout(profile,action)
	if not source.valid: return PackedVector2Array()
	var result := PackedVector2Array(source.offsets)
	var hero := Vector2(-LegionSpatialExecutor.protection_offset(profile),0)
	result.append(hero)
	if spacing==48.0: return result
	var roles := LegionTemplate.find(profile).slot_roles()
	var centers: Array[Vector2] = [Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
	var counts := [0,0,0,0]
	var fronts := [-INF,-INF,-INF,-INF]
	for index in range(60):
		centers[roles[index]]+=source.offsets[index]; counts[roles[index]]+=1
		fronts[roles[index]]=maxf(fronts[roles[index]],source.offsets[index].x)
	for role in range(4):
		if counts[role]>0: centers[role]/=float(counts[role])
	# Keep role centers and the protected commander pocket. Only role-local
	# offsets contract; artillery keeps its original spatial offsets.
	var placed: Array[int] = [60]
	for index in range(60):
		if roles[index]==3: placed.append(index)
	for index in range(60):
		var role: int = roles[index]
		if role==3: continue
		# Longitudinal role relationships survive compression. Reducing width
		# must not pull a rear rank into the protected commander's pocket.
		var preferred := Vector2(source.offsets[index].x,centers[role].y+(source.offsets[index].y-centers[role].y)*(spacing/48.0))
		# A terrain-constrained role can shorten its own rear ranks. Its front,
		# lateral center, artillery and commander pocket are not scaled.
		if compact_depth:
			preferred.x=fronts[role]+(source.offsets[index].x-fronts[role])*(spacing/48.0)
		var found := false
		for ring in range(13):
			if found: break
			var depth_limit := ring if compact_depth else mini(6,ring)
			for x in range(-depth_limit,depth_limit+1):
				if found: break
				for y in range(-ring,ring+1):
					if maxi(absi(x),absi(y))!=ring: continue
					if compact_depth and x*x+y*y>144: continue
					var candidate := preferred+Vector2(x,y)*8.0
					var clear := true
					for previous in placed:
						var required := spacing
						if previous<60 and roles[previous]==3: required=48.0
						if previous==60 and role in [1,2]: required=LegionSpatialExecutor.protection_offset(profile)
						if candidate.distance_to(result[previous])<required-0.01: clear=false; break
					if clear:
						result[index]=candidate; placed.append(index); found=true; break
		if not found:
			# This optional shape may conflict with a protected pocket. Retain
			# the existing valid role layout; terrain validation can still reject it.
			if compact_depth: return offsets(profile,action,spacing)
			return PackedVector2Array()
	_cache[key]=result.duplicate()
	return result

static func _points(offsets_value: PackedVector2Array, identities: PackedInt32Array, anchor: Vector2, facing: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for identity in identities:
		var offset := offsets_value[identity]
		result.append(anchor+facing*offset.x+facing.orthogonal()*offset.y)
	return result

static func fits(points: PackedVector2Array, grid: LogicGrid, occupied: PackedVector2Array) -> bool:
	for point in points:
		if not LegionTransitGeometry.segment_fits(grid,point,point): return false
		for other in occupied:
			if point.distance_squared_to(other)<48.0*48.0-0.01: return false
	return true

# Repair only obstructed slots in formation-local coordinates. The accepted
# objective and every unobstructed stable identity keep their original place.
static func _adapt_slots(profile: StringName, candidate: PackedVector2Array, identities: PackedInt32Array, anchor: Vector2, facing: Vector2, spacing: float, grid: LogicGrid, occupied: PackedVector2Array) -> PackedVector2Array:
	var result := candidate.duplicate()
	var roles := LegionTemplate.find(profile).slot_roles()
	var pending: Array[int] = []
	var placed: Array[int] = []
	for identity in identities:
		var point := anchor+facing*result[identity].x+facing.orthogonal()*result[identity].y
		if fits(PackedVector2Array([point]),grid,occupied): placed.append(identity)
		else: pending.append(identity)
	if pending.is_empty(): return result
	pending.sort()
	# Enumerate nearest Euclidean displacement first, with deterministic local
	# coordinate ties so a 180-degree map rotation produces a rotated result.
	var displacements: Array[Vector2] = []
	for x in range(-12,13):
		for y in range(-12,13):
			if x*x+y*y<=144: displacements.append(Vector2(x,y)*8.0)
	displacements.sort_custom(func(a: Vector2,b: Vector2) -> bool:
		if not is_equal_approx(a.length_squared(),b.length_squared()): return a.length_squared()<b.length_squared()
		return a.x<b.x if a.x!=b.x else a.y<b.y)
	for identity in pending:
		var found := false
		for delta in displacements:
			var offset := candidate[identity]+delta
			var point := anchor+facing*offset.x+facing.orthogonal()*offset.y
			if not fits(PackedVector2Array([point]),grid,occupied): continue
			var clear := true
			for other in placed:
				var required := spacing
				if (identity<60 and roles[identity]==3) or (other<60 and roles[other]==3): required=48.0
				if (identity==60 and roles[other] in [1,2]) or (other==60 and roles[identity] in [1,2]): required=LegionSpatialExecutor.protection_offset(profile)
				if offset.distance_to(result[other])<required-0.01: clear=false; break
			if not clear: continue
			result[identity]=offset; placed.append(identity); found=true; break
		if not found: return PackedVector2Array()
	return result

# Takes public terrain and already-filtered friendly reservations, never a
# world object or a hidden-enemy dictionary. Shared by authority and preview.
static func plan(profile: StringName, action: LegionSpatialState.Action, identities: PackedInt32Array, anchor: Vector2, facing: Vector2, grid: LogicGrid, occupied: PackedVector2Array = PackedVector2Array(), maximum_spacing: float = 48.0, allow_compression: bool = true) -> LegionDeploymentPlan:
	var result := LegionDeploymentPlan.new()
	result.allow_compression=allow_compression
	result.anchor=anchor; result.facing=facing.normalized() if not facing.is_zero_approx() else Vector2.RIGHT
	result.identities=identities.duplicate()
	var standard := offsets(profile,action,48.0)
	if standard.size()!=61 or identities.is_empty(): return result
	for identity in identities:
		if identity<0 or identity>60: return result
	result.standard_points=_points(standard,identities,anchor,result.facing)
	for spacing in LegionReformationSystem.policy.spacings:
		if spacing>maximum_spacing: continue
		if not allow_compression and spacing!=48.0: continue
		for compact_depth in [false,true]:
			if compact_depth and spacing==48.0: continue
			var candidate := offsets(profile,action,spacing,compact_depth)
			if candidate.size()!=61: continue
			candidate=_adapt_slots(profile,candidate,identities,anchor,result.facing,spacing,grid,occupied)
			if candidate.size()!=61: continue
			var points := _points(candidate,identities,anchor,result.facing)
			if not fits(points,grid,occupied): continue
			result.points=points; result.offsets=candidate; result.spacing=spacing
			result.status=LegionDeploymentPlan.Status.STANDARD if spacing==48.0 else LegionDeploymentPlan.Status.COMPRESSED
			result.reason=&"DEPLOYMENT_STANDARD" if spacing==48.0 else &"DEPLOYMENT_COMPRESSED"
			return result
	return result

static func movement_plan(profile: StringName, identities: PackedInt32Array, start: Vector2, goal: Vector2, facing: Vector2, grid: LogicGrid, occupied: PackedVector2Array = PackedVector2Array(), allow_compression: bool = true, finder: GridPathfinder = null, action: LegionSpatialState.Action = LegionSpatialState.Action.MOVE) -> LegionDeploymentPlan:
	if finder==null: finder=GridPathfinder.new(grid)
	var path := LegionProtectionPlanner.route(grid,finder,start,goal)
	var direction := facing
	if direction.is_zero_approx(): direction=(path[-1]-path[-2]).normalized() if path.size()>1 else Vector2.RIGHT
	var result := plan(profile,action,identities,goal,direction,grid,occupied,48.0,allow_compression)
	if path.size()<2 or not LegionReformationSystem._route_clear_grid(grid,path):
		result.status=LegionDeploymentPlan.Status.BLOCKED; result.reason=&"PATH_UNAVAILABLE"; result.points.clear(); return result
	if result.status!=LegionDeploymentPlan.Status.BLOCKED: return result
	# "Transit only" requires real, distinct column slots and a traversable
	# approach. A walkable anchor alone is not a passage certificate.
	for columns in [3,2,1]:
		var candidate := PackedVector2Array(); candidate.resize(61)
		for ordinal in range(identities.size()):
			candidate[identities[ordinal]]=Vector2(-floori(ordinal/float(columns))*48.0,(ordinal%columns-(columns-1)*0.5)*48.0)
		var points := _points(candidate,identities,goal,result.facing)
		if not fits(points,grid,occupied): continue
		var accessible := true
		for point in points:
			if not LegionReformationSystem._route_clear_grid(grid,LegionProtectionPlanner.route(grid,finder,goal,point)): accessible=false; break
		if not accessible: continue
		result.status=LegionDeploymentPlan.Status.TRANSIT_ONLY; result.reason=&"DEPLOYMENT_TRANSIT_ONLY"
		result.points=points; result.offsets=candidate; result.spacing=48.0; return result
	# Lack of full formation space is an advisory. A traversable goal remains
	# valid even when forced compression puts bodies almost on top of each other.
	var compact := standard_fallback(profile,identities,goal,result.facing,grid,action)
	result.offsets=compact; result.points=_points(compact,identities,goal,result.facing)
	result.status=LegionDeploymentPlan.Status.TRANSIT_ONLY; result.reason=&"DEPLOYMENT_TRANSIT_ONLY"; result.spacing=8.0
	return result

static func standard_fallback(profile: StringName, identities: PackedInt32Array, anchor: Vector2, facing: Vector2, grid: LogicGrid, action: LegionSpatialState.Action = LegionSpatialState.Action.MOVE) -> PackedVector2Array:
	var compact := offsets(profile,action,48.0)
	for identity in identities:
		var original := compact[identity]
		for scale: float in [0.5,0.25,0.125,0.0625,0.0]:
			compact[identity]=original*scale
			var point := anchor+facing*compact[identity].x+facing.orthogonal()*compact[identity].y
			if LegionTransitGeometry.segment_fits(grid,point,point): break
	return compact
