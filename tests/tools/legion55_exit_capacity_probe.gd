extends "res://tests/tools/legion49_narrow_aligned.gd"

func _initialize() -> void:
	var rows: Array = []
	for profile: StringName in [&"spear",&"guardian",&"gunner",&"sentinel",&"ranger"]:
		var world := road_fixture(profile,60,false,true)
		var commander := world.commanders.values()[0] as CommanderState
		for tick in range(300):
			step(world)
			var current := world.legion_formation_system.records[commander.definition.definition_id] as LegionFormationState
			if current.spatial.transit.path!=null: break
		var record := world.legion_formation_system.records[commander.definition.definition_id] as LegionFormationState
		var path := record.spatial.transit.path
		if path==null: push_error("No transit path in probe"); quit(1); return
		var direction := (LegionTransitGeometry.point_at(path,path.total)-LegionTransitGeometry.point_at(path,path.total-1)).normalized()
		var layout := LegionSpatialExecutor.layout(profile,record.spatial.action)
		var variants: Array = []
		for forward: Vector2 in [record.spatial.facing,direction]:
			for count in [12,60]:
				var bad: Array = []; var xs: Array = []; var ys: Array = []
				for identity in range(count):
					var target: Vector2 = record.spatial.goal+forward*layout.offsets[identity].x+forward.orthogonal()*layout.offsets[identity].y
					if not LegionTransitGeometry.segment_fits(world.logic_grid,target,target): bad.append(identity)
					xs.append(layout.offsets[identity].x); ys.append(layout.offsets[identity].y)
				variants.append({"forward":str(forward),"count":count,"bad":bad,"x_range":[xs.min(),xs.max()],"y_range":[ys.min(),ys.max()]})
		rows.append({"profile":profile,"goal":str(record.spatial.goal),"length":path.total,"directions":variants})
	print("LEGION55_CAPACITY ",JSON.stringify(rows)); quit(0)
