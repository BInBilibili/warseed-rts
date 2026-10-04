extends "res://tests/tools/legion49_narrow_aligned.gd"

func _initialize() -> void:
	var count := 12
	var profile: StringName = &"gunner"
	var mirror := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="): count=int(arg.trim_prefix("--count="))
		if arg.begins_with("--profile="): profile=StringName(arg.trim_prefix("--profile="))
		if arg=="--mirror": mirror=true
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var world := road_fixture(profile,count,mirror,true)
	var commander := world.commanders.values()[0] as CommanderState
	var min_gap := INF
	var max_escort_path := 0.0
	for tick in range(2400):
		var before := {}
		for unit: UnitState in world.units.values(): before[unit.entity_id]=unit.position
		step(world)
		var record := world.legion_formation_system.records[commander.definition.definition_id]
		var transit := record.spatial.transit
		if transit.phase!=LegionTransitState.Phase.WIDE:
			for unit: UnitState in world.units.values():
				check(LegionTransitGeometry.segment_fits(world.logic_grid,before[unit.entity_id],unit.position),"actual exit motion retains swept 64 terrain envelope")
			if transit.escort_identity>=0 and transit.batches[transit.hero_batch].admitted:
				var hero := world.units[commander.hero_entity_id] as UnitState
				var escort := LegionTransitExecutor._entity(world,commander,transit.escort_identity)
				var route := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,hero.position,escort.position)
				var distance := LegionProtectionPlanner.path_length(route)
				max_escort_path=maxf(max_escort_path,distance)
				check(not route.is_empty() and distance<=240.01,"commander retains a reachable same-batch escort during exit")
			for index in range(1,transit.batches.size()):
				if not transit.batches[index].admitted or not transit.batches[index-1].admitted: continue
				var previous_tail := INF
				var following_head := -INF
				for identity in transit.batches[index-1].identities:
					var unit := LegionTransitExecutor._entity(world,commander,identity)
					previous_tail=minf(previous_tail,LegionTransitGeometry.progress_at(transit.path,unit.position))
				for identity in transit.batches[index].identities:
					var unit := LegionTransitExecutor._entity(world,commander,identity)
					following_head=maxf(following_head,LegionTransitGeometry.progress_at(transit.path,unit.position))
				min_gap=minf(min_gap,previous_tail-following_head-64.0)
				check(previous_tail-following_head-64.0>=95.99,"exit motion retains 96 clear inter-batch gap")
		if world.current_tick%100==0:
			var batches: Array = []
			for batch in transit.batches:
				batches.append({"progress":batch.progress,"ready":batch.ready,"available":batch.available,"admitted":batch.admitted})
			print("LEGION54_EXIT_PROGRESS profile=",profile," count=",count," mirror=",mirror," tick=",world.current_tick," phase=",transit.phase," reason=",transit.reason," batches=",JSON.stringify(batches))
		if transit.reason==&"TRANSIT_EXIT_COMPLETE": break
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	var transit := record.spatial.transit
	check(transit.phase==LegionTransitState.Phase.EXPAND,"all batches leave EXIT_WAIT and enter physical expansion")
	check(transit.reason==&"TRANSIT_EXIT_COMPLETE","exit completion receipt is emitted")
	check(transit.expand_since>=0 and world.current_tick-transit.expand_since>=20,"expanded formation remains stable for 20 ticks")
	check(record.spatial.ready==count,"all required soldiers settle in expanded formation")
	var batch_rows: Array = []
	for batch in transit.batches:
		batch_rows.append({"identities":batch.identities,"progress":batch.progress,"ready":batch.ready,"available":batch.available,"admitted":batch.admitted})
		check(batch.identities.size()<=12,"each physical batch remains within twelve identities")
		check(batch.available==batch.identities.size() and batch.ready==batch.available,"every batch member is physically ready at exit completion")
	var data := {"evidence":"SIMULATED_CANDIDATE","profile":profile,"count":count,"mirror":mirror,"checks":checks,"failures":failures,"final_tick":world.current_tick,"phase":transit.phase,"reason":transit.reason,"expand_since":transit.expand_since,"min_gap":min_gap if min_gap<INF else -1,"max_escort_path":max_escort_path,"batches":batch_rows,"route_length":transit.path.total,"full_B":"REWORK"}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION54_EXIT checks=",checks," failures=",failures.size()," phase=",transit.phase," reason=",transit.reason)
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
