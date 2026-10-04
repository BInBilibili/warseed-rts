extends "res://tests/tools/legion49_narrow_aligned.gd"

func _initialize() -> void:
	var world := road_fixture(&"gunner",60,false,true)
	var goal := Vector2(6656,19456)
	var incoming := (goal-Vector2(4864,16384)).normalized()
	var rows: Array = []
	for turn in range(16):
		var axis := incoming.rotated(turn*PI/8.0)
		var path := LegionTransitGeometry.build(world.logic_grid,world.pathfinder,goal-axis*320.0,PackedVector2Array([goal+axis*320.0]))
		if not path.valid or path.total>640.01 or not LegionTransitGeometry.window_fits(world.logic_grid,path,0,640,8): continue
		for profile: StringName in LegionTemplate.PROFILE_IDS:
			var slots := PackedVector2Array()
			var layout := LegionSpatialExecutor.layout(profile,LegionSpatialState.Action.MOVE)
			for identity in range(61):
				var offset := layout.offsets[identity] if identity<60 else Vector2(-LegionSpatialExecutor.protection_offset(profile),0)
				var selected := Vector2(INF,INF)
				for ring in range(9):
					if selected.is_finite(): break
					for x in range(-ring,ring+1):
						if selected.is_finite(): break
						for y in range(-ring,ring+1):
							if maxi(absi(x),absi(y))!=ring: continue
							var point := goal+axis*(offset.x+x*48.0)+axis.orthogonal()*(offset.y+y*48.0)
							if point.distance_to(goal)>512.0 or absf((point-goal).dot(incoming.orthogonal()))<80.0: continue
							if not LegionTransitGeometry.segment_fits(world.logic_grid,point,point): continue
							var free := true
							for occupied in slots:
								if point.distance_squared_to(occupied)<48.0*48.0-0.01: free=false; break
							if free: selected=point; break
				if not selected.is_finite(): break
				slots.append(selected)
			rows.append({"angle_index":turn,"axis":str(axis),"profile":profile,"capacity":slots.size(),"slots":str(slots)})
	var fits := 0
	for row in rows:
		if row.capacity==61: fits+=1
	check(fits>0,"actual junction has at least one 61-body geometric layout preserving a 96 central passage")
	var data := {"evidence":"SIMULATED_COMPONENT_ONLY","checks":checks,"failures":failures,"feasible_layouts":fits,"rows":rows,"physical_exit_execution":false,"limitations":"No dynamic occupancy, traffic reservations, escort selection or expansion motion certified"}
	FileAccess.open("res://artifacts/legion51/exit-geometry01.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION51_EXIT_GEOMETRY checks=",checks," failures=",failures.size()," feasible=",fits)
	quit(0 if failures.is_empty() else 1)
