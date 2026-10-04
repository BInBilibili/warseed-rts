extends GridPathfinder

var _visibility_cache: Dictionary = {}
var _visibility_revision := -1
var _blockers: Array[AABB] = []
var _solid_rows: Array[PackedInt32Array] = []

# Experimental exact rejection accelerator: a segment intersecting the strict
# interior of an already proven solid cell cannot pass the existing grid test.
# Border/corner cases always fall back to the original DDA traversal.
func _simplify_path(path: PackedVector2Array) -> PackedVector2Array:
	if path.size() <= 2: return path
	if _visibility_revision != logic_grid.revision:
		_visibility_revision = logic_grid.revision
		_visibility_cache.clear()
		_blockers.clear()
		_solid_rows = logic_grid.blocked_row_spans()
	if _visibility_cache.size() > 65536: _visibility_cache.clear()
	var simplified := PackedVector2Array([path[0]])
	var anchor_index := 0
	while anchor_index < path.size()-1:
		var blockers := _blockers
		var next_index := path.size()-1
		while next_index > anchor_index+1:
			var a := path[anchor_index]
			var b := path[next_index]
			var key := Vector4(a.x,a.y,b.x,b.y)
			if _visibility_cache.has(key):
				if _visibility_cache[key]: break
				next_index -= 1
				continue
			var rejected := false
			for box in blockers:
				if box.intersects_segment(Vector3(a.x,a.y,0),Vector3(b.x,b.y,0)) != null:
					rejected = true
					break
			if not rejected:
				if logic_grid.is_segment_walkable(a,b):
					_visibility_cache[key] = true
					break
				_remember_solid_cell(a,b,blockers)
			_visibility_cache[key] = false
			next_index -= 1
		simplified.append(path[next_index])
		anchor_index = next_index
	return simplified

func _remember_solid_cell(a: Vector2,b: Vector2,blockers: Array[AABB]) -> void:
	var steps := maxi(1,ceili(a.distance_to(b)/LogicGrid.CELL_SIZE))
	for i in range(1,steps):
		var cell := logic_grid.world_to_cell(a.lerp(b,float(i)/steps))
		if not logic_grid.is_in_bounds(cell) or not logic_grid.is_blocked(cell): continue
		var left := cell.x
		var right := cell.x+1
		var spans := _solid_rows[cell.y]
		for index in range(0,spans.size(),2):
			if spans[index] <= cell.x and spans[index]+spans[index+1] > cell.x:
				left = spans[index]
				right = spans[index]+spans[index+1]
				break
		var top := cell.y
		var bottom := cell.y+1
		while top > 0 and _row_contains(top-1,left,right): top -= 1
		while bottom < _solid_rows.size() and _row_contains(bottom,left,right): bottom += 1
		var low := logic_grid.world_origin+Vector2(left,top)*LogicGrid.CELL_SIZE
		# Far below a map pixel, but large enough to exclude float32 boundaries.
		var inset := 0.03125
		var box := AABB(Vector3(low.x+inset,low.y+inset,-1),Vector3((right-left)*LogicGrid.CELL_SIZE-2*inset,(bottom-top)*LogicGrid.CELL_SIZE-2*inset,2))
		if not blockers.has(box): blockers.append(box)
		return

func _row_contains(row: int,left: int,right: int) -> bool:
	var spans := _solid_rows[row]
	for i in range(0,spans.size(),2):
		if spans[i] <= left and spans[i]+spans[i+1] >= right: return true
	return false
