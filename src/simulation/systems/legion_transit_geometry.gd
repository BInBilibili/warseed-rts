class_name LegionTransitGeometry
extends RefCounted

const RADIUS := 32.0
const SPACING := 48.0
const SAMPLE_STEP := 32.0
const CORNER_BLEND := 128.0

class PathData extends RefCounted:
	var points := PackedVector2Array()
	var lengths := PackedFloat64Array()
	var total := 0.0
	var valid := false
	var reason: StringName = &"PATH_UNAVAILABLE"
	func duplicate_value() -> PathData:
		var copy := PathData.new()
		copy.points=points.duplicate(); copy.lengths=lengths.duplicate()
		copy.total=total; copy.valid=valid; copy.reason=reason
		return copy

static func build(grid: LogicGrid, finder: GridPathfinder, start: Vector2, waypoints: PackedVector2Array) -> PathData:
	var result := PathData.new()
	result.points.append(start); result.lengths.append(0.0)
	for target in waypoints:
		var route := LegionProtectionPlanner.route(grid,finder,result.points[-1],target)
		if route.is_empty(): return result
		for point in route:
			var distance := result.points[-1].distance_to(point)
			if distance<=0.001: continue
			if result.points.size()>1:
				var before := (result.points[-1]-result.points[-2]).normalized()
				if before.dot((point-result.points[-1]).normalized()) < -0.95:
					result.reason=&"PATH_REVERSAL_REQUIRES_REPLAN"; return result
			result.total+=distance; result.points.append(point); result.lengths.append(result.total)
	result.valid=result.points.size()>1
	if result.valid: result.reason=&"READY"
	return result

static func _corner(path: PathData, index: int, lateral: float) -> Vector2:
	var before := (path.points[index]-path.points[index-1]).normalized().orthogonal()
	var after := (path.points[index+1]-path.points[index]).normalized().orthogonal()
	var normal := (before+after).normalized()
	return path.points[index]+normal*lateral/maxf(0.25,normal.dot(before))

static func point_at(path: PathData, distance: float, lateral: float = 0.0) -> Vector2:
	if not path.valid: return Vector2(INF,INF)
	var index := 1
	while index<path.points.size()-1 and distance>path.lengths[index]: index+=1
	var tangent := (path.points[index]-path.points[index-1]).normalized()
	var offset := tangent.orthogonal()*lateral
	var local := distance-path.lengths[index-1]
	var remaining := path.lengths[index]-distance
	# Negative/overrun distances describe rear or front slots, never permission
	# to stand there; callers still validate their full physical envelope.
	if distance<0.0 or distance>path.total: return path.points[index-1]+tangent*local+offset
	var blend := minf(CORNER_BLEND,(path.lengths[index]-path.lengths[index-1])*0.5)
	if index>1 and local<blend:
		return _corner(path,index-1,lateral).lerp(path.points[index-1]+tangent*blend+offset,local/blend)
	if index<path.points.size()-1 and remaining<blend:
		return (path.points[index]-tangent*blend+offset).lerp(_corner(path,index,lateral),1.0-remaining/blend)
	return path.points[index-1]+tangent*local+offset

static func _intersects_rect(origin: Vector2, target: Vector2, rectangle: Rect2) -> bool:
	var lower := 0.0; var upper := 1.0
	var delta := target-origin
	for axis in range(2):
		if absf(delta[axis])<0.000001:
			if origin[axis]<rectangle.position[axis] or origin[axis]>rectangle.end[axis]: return false
		else:
			var a := (rectangle.position[axis]-origin[axis])/delta[axis]
			var b := (rectangle.end[axis]-origin[axis])/delta[axis]
			lower=maxf(lower,minf(a,b)); upper=minf(upper,maxf(a,b))
			if lower>upper: return false
	return true

static func progress_at(path: PathData, position: Vector2) -> float:
	if not path.valid: return 0.0
	var best := INF; var progress := 0.0
	for index in range(1,path.points.size()):
		var a := path.points[index-1]; var b := path.points[index]
		var delta := b-a
		var fraction := (position-a).dot(delta)/delta.length_squared()
		# Rear staging may extend the first segment, but never an inner corner.
		fraction=clampf(fraction,-100.0 if index==1 else 0.0,100.0 if index==path.points.size()-1 else 1.0)
		var projected := a+delta*fraction
		var distance := position.distance_squared_to(projected)
		if distance<best:
			best=distance; progress=path.lengths[index-1]+delta.length()*fraction
	return progress

static func segment_fits(grid: LogicGrid, origin: Vector2, target: Vector2, radius: float = RADIUS) -> bool:
	if not origin.is_finite() or not target.is_finite() or radius<0.0: return false
	# Continuous swept square, not center/corner-only samples. Minkowski-expand
	# each intersected blocked cell and clip the center segment against it.
	var lo := grid.world_to_cell(origin.min(target)-Vector2.ONE*radius)
	var hi := grid.world_to_cell(origin.max(target)+Vector2.ONE*radius)
	if not grid.is_in_bounds(lo) or not grid.is_in_bounds(hi): return false
	var rows := grid.blocked_row_spans()
	for y in range(lo.y,hi.y+1):
		for index in range(0,rows[y].size(),2):
			var first := rows[y][index]; var count := rows[y][index+1]
			if first>hi.x: break
			if first+count-1<lo.x: continue
			var padding := Vector2.ONE*(radius-0.001)
			var corner := grid.world_origin+Vector2(first,y)*LogicGrid.CELL_SIZE
			var box := Rect2(corner-padding,Vector2(count,1)*LogicGrid.CELL_SIZE+padding*2.0)
			if _intersects_rect(origin,target,box): return false
	return true

static func columns_at(grid: LogicGrid, center: Vector2, tangent: Vector2) -> int:
	if tangent.is_zero_approx() or not segment_fits(grid,center,center): return 0
	var normal := tangent.normalized().orthogonal()
	var width := 0.0
	for sign_value in [-1.0,1.0]:
		var clearance := 0.0
		for distance in range(8,1033,8):
			if not grid.is_world_position_walkable(center+normal*distance*sign_value): break
			clearance=distance
		width+=clearance
	var cap := 8 if width>=1008.0 else (4 if width>=496.0 else 3)
	for columns in [8,4,3,2,1]:
		if columns>cap: continue
		var fits := true
		for column in range(columns):
			var point: Vector2 = center+normal*(column-(columns-1)*0.5)*SPACING
			if not segment_fits(grid,point,point): fits=false; break
		if fits: return columns
	return 0

static func window_fits(grid: LogicGrid, path: PathData, start: float, finish: float, columns: int) -> bool:
	if not path.valid or columns<1 or columns>8 or finish<start: return false
	var samples: Array[float] = [start,finish]
	var distance := start+SAMPLE_STEP
	while distance<finish:
		samples.append(distance); distance+=SAMPLE_STEP
	# Include all corners and the ends of their piecewise-linear miter blends.
	for index in range(1,path.points.size()):
		var blend := minf(CORNER_BLEND,(path.lengths[index]-path.lengths[index-1])*0.5)
		for point in [path.lengths[index-1]+blend,path.lengths[index]-blend,path.lengths[index]]:
			if point>start and point<finish: samples.append(point)
	samples.sort()
	for column in range(columns):
		var lateral := (column-(columns-1)*0.5)*SPACING
		var previous := point_at(path,start,lateral)
		for sample in samples:
			var next := point_at(path,sample,lateral)
			if not segment_fits(grid,previous,next): return false
			previous=next
	return true
