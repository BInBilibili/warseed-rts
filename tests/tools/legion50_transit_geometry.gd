extends SceneTree

const Geometry = preload("res://src/simulation/systems/legion_transit_geometry.gd")
var checks := 0
var failures: Array[String] = []
var rows: Array = []

func check(value: bool, message: String) -> void:
	checks+=1
	if not value and not failures.has(message): failures.append(message)

func _initialize() -> void:
	var grid := LogicGrid.new()
	grid.grid_size=Vector2i(30,30)
	grid.set_blocked(Vector2i(10,10),true)
	check(grid.is_segment_walkable(Vector2(280,304),Vector2(400,304)),"control centerline misses obstacle")
	check(not Geometry.segment_fits(grid,Vector2(280,304),Vector2(400,304)),"body sweep catches obstacle beyond centerline")
	check(Geometry.segment_fits(grid,Vector2(280,280),Vector2(400,280)),"clear full body path remains allowed")
	check(not Geometry.segment_fits(grid,Vector2(20,200),Vector2(20,250)),"full body cannot extend outside world")
	# A short diagonal corner graze cannot hide between 32-distance samples.
	check(not Geometry.segment_fits(grid,Vector2(284,294),Vector2(300,278)),"continuous envelope catches diagonal corner graze")
	var map := load("res://data/maps/final_decision.tres") as MapDefinition
	grid=LogicGrid.create_for_map(map)
	var finder := GridPathfinder.new(grid)
	for mirror in [false,true]:
		var points := PackedVector2Array([Vector2(2048,20000),Vector2(2048,18432),Vector2(4864,16384),Vector2(6656,19456)])
		if mirror:
			for i in range(points.size()): points[i]=map.mirror_point(points[i])
		var route := Geometry.build(grid,finder,points[0],points.slice(1))
		check(route.valid,"actual two-bend road has a navigable center route")
		var direction := (points[1]-points[0]).normalized()
		check(Geometry.columns_at(grid,points[0],direction)==8,"actual main road permits eight columns")
		var middle := points[1].lerp(points[2],0.5)
		var narrow_columns := Geometry.columns_at(grid,middle,(points[2]-points[1]).normalized())
		check(narrow_columns==3,"actual 320 road chooses three columns")
		check(not Geometry.window_fits(grid,route,0,route.total,8),"eight-column body route rejected through narrowing")
		var three := Geometry.window_fits(grid,route,0,route.total,3)
		check(three,"three-column full swept envelopes fit actual bends")
		var copy := route.duplicate_value()
		route.points[0]+=Vector2(1,0)
		check(copy.points[0]==points[0],"route snapshot points do not alias")
		rows.append({"mirror":mirror,"length":copy.total,"columns":narrow_columns,"three_column_envelope":three})
	var data := {"evidence":"SIMULATED_COMPONENT_ONLY","checks":checks,"failures":failures,"rows":rows,"physical_unit_execution":false}
	FileAccess.open("res://artifacts/legion50/geometry02.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION50_GEOMETRY checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
