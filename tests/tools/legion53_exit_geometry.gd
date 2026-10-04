extends "res://tests/tools/legion49_narrow_aligned.gd"

func _initialize() -> void:
	var world := road_fixture(&"gunner",60,false,true)
	var commander := world.commanders.values()[0] as CommanderState
	for tick in range(250): step(world)
	var record := world.legion_formation_system.records[commander.definition.definition_id] as LegionFormationState
	var path := record.spatial.transit.path
	var capacities: Array = []
	var previous := -1
	for distance in range(0,ceili(path.total)+1,32):
		var point := LegionTransitGeometry.point_at(path,distance)
		var tangent := LegionTransitGeometry.point_at(path,distance+1)-point
		var capacity := LegionTransitGeometry.columns_at(world.logic_grid,point,tangent)
		if capacity!=previous:
			capacities.append({"distance":distance,"position":str(point),"columns":capacity})
			previous=capacity
	print(JSON.stringify({"length":path.total,"points":str(path.points),"capacities":capacities}))
	quit()
