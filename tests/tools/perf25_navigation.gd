extends SceneTree

const REFERENCE = preload("res://tests/tools/perf25_reference_pathfinder.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void:
	var map := BattleContentLoader.load_battle(&"final_decision").battle.map_definition
	var grid := LogicGrid.create_for_map(map)
	var timings: Array[Dictionary] = []
	var reference: RefCounted
	var actual: GridPathfinder
	for repeat in range(3):
		var start := Time.get_ticks_usec()
		reference = REFERENCE.new(grid)
		var before := Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		actual = GridPathfinder.new(grid)
		timings.append({"reference_usec": before, "actual_usec": Time.get_ticks_usec() - start})
	check(reference._rotation_is_valid == actual._rotation_is_valid, "rotation validation")
	var solid_mismatch := 0
	for y in range(grid.grid_size.y):
		for x in range(grid.grid_size.x):
			var cell := Vector2i(x,y)
			if reference._astar.is_point_solid(cell) != actual._astar.is_point_solid(cell): solid_mismatch += 1
	check(solid_mismatch == 0, "all AStar cells equal")
	for i in range(map.supply_points.size()):
		for offset in [1,7,13]:
			var a: Vector2 = map.supply_points[i].position
			var b: Vector2 = map.supply_points[(i+offset)%map.supply_points.size()].position
			check(reference.find_path(a,b) == actual.find_path(a,b), "path %d/%d" % [i,offset])
	# Reversed insertion order must not affect path tie-breaking.
	var reverse_grid := LogicGrid.create_for_map(map)
	var reverse_cells := reverse_grid.blocked_cells.keys()
	reverse_cells.reverse()
	reverse_grid.blocked_cells.clear()
	reverse_grid._navigation_grid_size = Vector2i.ZERO
	for cell in reverse_cells: reverse_grid.blocked_cells[cell] = true
	var reversed := GridPathfinder.new(reverse_grid)
	for i in range(map.supply_points.size()):
		var a: Vector2 = map.supply_points[i].position
		var b: Vector2 = map.supply_points[(i+9)%map.supply_points.size()].position
		check(reference.find_path(a,b) == reversed.find_path(a,b), "insertion order %d" % i)
	# Add/remove an actual blocking cell after construction; both caches must invalidate.
	var source: Vector2 = map.supply_points[2].position
	var destination: Vector2 = map.supply_points[5].position
	var changed := grid.world_to_cell(destination)
	grid.set_blocked(changed,true)
	check(reference.find_path(source,destination) == actual.find_path(source,destination), "blocked endpoint update")
	check(actual.find_path(source,destination).is_empty(), "endpoint really blocked")
	check(reference._rotation_is_valid == actual._rotation_is_valid, "asymmetric obstacle validation")
	grid.set_blocked(changed,false)
	check(reference.find_path(source,destination) == actual.find_path(source,destination), "removed obstacle update")
	check(not actual.find_path(source,destination).is_empty(), "path restored after removal")
	check(reference._rotation_is_valid == actual._rotation_is_valid, "restored symmetry")
	# A fresh world copy must retain the template after another grid changes.
	var separate := LogicGrid.create_for_map(map)
	var separate_nav := GridPathfinder.new(separate)
	grid.set_blocked(changed,true)
	actual.find_path(source,destination)
	check(separate._navigation_mask[changed.y*separate.grid_size.x+changed.x] == 0, "world mutation does not alter separate raw mask")
	check(not separate.is_blocked(changed), "world mutation does not alter template dictionary")
	check(not separate_nav.find_path(source,destination).is_empty(), "world mutation does not alter cached row mask")
	var third := LogicGrid.create_for_map(map)
	check(not GridPathfinder.new(third).find_path(source,destination).is_empty(), "future clones retain template mask")
	grid.set_blocked(changed,false)
	# Exercise row split/merge and edge cells on an odd-sized centrally symmetric grid.
	var small := LogicGrid.new()
	small.grid_size = Vector2i(17,13)
	small.centrally_symmetric_navigation = true
	var small_nav := GridPathfinder.new(small)
	for phase in range(6):
		for x in range(small.grid_size.x):
			for y in range(small.grid_size.y):
				small.set_blocked(Vector2i(x,y),(x*7+y*11+phase)%5 < 2)
		small_nav.find_path(Vector2(16,16),Vector2(48,48))
		var equal := true
		var symmetric := true
		for x in range(small.grid_size.x):
			for y in range(small.grid_size.y):
				var cell := Vector2i(x,y)
				equal = equal and small_nav._astar.is_point_solid(cell) == small.is_blocked(cell)
				symmetric = symmetric and small.is_blocked(cell) == small.is_blocked(small.grid_size-Vector2i.ONE-cell)
		check(equal, "row split/merge phase %d" % phase)
		check(small_nav._rotation_is_valid == symmetric, "odd grid symmetry phase %d" % phase)
	var report := {"evidence":"SIMULATED","checks":checks,"failures":failures,"blocked_cells":grid.blocked_cells.size(),"grid_cells":grid.grid_size.x*grid.grid_size.y,"timings":timings}
	FileAccess.open("res://artifacts/perf25-navigation04.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF25_NAVIGATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
