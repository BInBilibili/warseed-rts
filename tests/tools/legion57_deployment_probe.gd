extends "res://tests/tools/legion57_exit_execution.gd"

func _initialize() -> void:
	var world := road_fixture(&"gunner",60,false,true)
	world.legion_formation_system.prepare(world)
	var record := world.legion_formation_system.records.values()[0] as LegionFormationState
	for spacing in [48.0,40.0,32.0]:
		var offsets := LegionDeploymentPlanner.offsets(&"gunner",record.spatial.action,spacing)
		var blocked: Array = []
		for identity in range(offsets.size()):
			var target := record.spatial.goal+record.spatial.facing*offsets[identity].x+record.spatial.facing.orthogonal()*offsets[identity].y
			if not LegionTransitGeometry.segment_fits(world.logic_grid,target,target): blocked.append([identity,str(offsets[identity]),str(target)])
		print("SPACING ",spacing," GOAL ",record.spatial.goal," FACING ",record.spatial.facing," BLOCKED ",JSON.stringify(blocked))
	quit()
