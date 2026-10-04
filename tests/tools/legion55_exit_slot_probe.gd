extends "res://tests/tools/legion49_narrow_aligned.gd"

func _initialize() -> void:
	var world := road_fixture(&"gunner",60,false,true)
	var commander := world.commanders.values()[0] as CommanderState
	for tick in range(300):
		step(world)
		var record := world.legion_formation_system.records[commander.definition.definition_id] as LegionFormationState
		if record.spatial.transit.path!=null: break
	var record := world.legion_formation_system.records[commander.definition.definition_id] as LegionFormationState
	var transit := record.spatial.transit
	var origin := LegionTransitGeometry.point_at(transit.path,transit.exit_mouth)
	var depth := 0.0
	for batch in transit.batches: depth=maxf(depth,(ceili(batch.identities.size()/float(transit.columns))-1)*48.0)
	var reserved := PackedVector2Array()
	var rows: Array = []
	for index in range(transit.batches.size()):
		var batch := transit.batches[index]
		var side := -1.0 if index%2==0 else 1.0
		for ordinal in range(batch.identities.size()):
			var longitudinal := transit.exit_head-transit.exit_mouth+floori(index/2.0)*(depth+48.0)-floori(ordinal/3.0)*48.0
			var lateral := side*((transit.columns-1)*24.0+160.0+64.0)+(ordinal%3-1)*48.0
			var point := origin+transit.exit_forward*longitudinal+transit.exit_forward.orthogonal()*lateral
			var terrain := LegionTransitGeometry.segment_fits(world.logic_grid,point,point)
			var nearest := INF
			for other in reserved: nearest=minf(nearest,point.distance_to(other))
			rows.append([index,ordinal,str(point),terrain,nearest,LegionTransitGeometry.progress_at(transit.path,point),str(origin),str(transit.exit_forward)])
			if terrain and nearest>=48.0: reserved.append(point)
	print("LEGION55_SLOTS ",JSON.stringify({"planned":transit.exit_planned,"reason":transit.exit_plan_reason,"mouth":transit.exit_mouth,"head":transit.exit_head,"rows":rows}))
	quit(0)
