extends "res://tests/tools/legion49_narrow_aligned.gd"

func _initialize() -> void:
	var world := road_fixture(&"gunner",12,false,true)
	var commander := world.commanders.values()[0] as CommanderState
	for tick in range(200): step(world)
	var transit := world.legion_formation_system.records[commander.definition.definition_id].spatial.transit
	var minimum := 8
	var first_reduction := -1.0
	for distance in range(0,ceili(transit.path.total),32):
		var point := LegionTransitGeometry.point_at(transit.path,distance)
		var tangent := LegionTransitGeometry.point_at(transit.path,distance+1)-point
		var columns := LegionTransitGeometry.columns_at(world.logic_grid,point,tangent)
		minimum=mini(minimum,columns)
		if columns<transit.columns and first_reduction<0.0: first_reduction=distance
	check(minimum>=1,"actual diagnostic route has at least one envelope-safe column")
	check(transit.columns<=minimum,"fixed admitted column width fits narrowest remaining section")
	var data := {"evidence":"SIMULATED_CANDIDATE_COMPONENT_PROBE","checks":checks,"failures":failures,"columns":transit.columns,"minimum_route_columns":minimum,"first_reduction_distance":first_reduction,"route_length":transit.path.total,"scope":"look-ahead width only; no exit or tactical acceptance"}
	FileAccess.open("res://artifacts/legion50/transit-width01.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION50_WIDTH checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
