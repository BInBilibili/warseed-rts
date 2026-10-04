extends "res://tests/tools/legion49_narrow_aligned.gd"

# A phase label and ready-at-current-queue-slot are not physical exit evidence.
func exit_geometry(world: SimulationWorld, path: LegionTransitGeometry.PathData) -> Dictionary:
	var last_nonwide := 0.0
	var changes: Array = []
	var last_capacity := -1
	for distance in range(0,ceili(path.total)+1,32):
		var point := LegionTransitGeometry.point_at(path,distance)
		var capacity := LegionTransitGeometry.columns_at(world.logic_grid,point,LegionTransitGeometry.point_at(path,distance+1)-point)
		if capacity<8: last_nonwide=distance
		if capacity!=last_capacity: changes.append({"distance":distance,"columns":capacity}); last_capacity=capacity
	var mouth := last_nonwide+32.0
	var first_extension_blocked := -1.0
	for distance in range(0,1281,8):
		if not LegionTransitGeometry.window_fits(world.logic_grid,path,path.total,path.total+distance,3):
			first_extension_blocked=distance; break
	return {"sample_step":32,"mouth_sample":mouth,"wide_run_before_goal":path.total-mouth,"capacity_changes":changes,"first_three_column_extension_blocked":first_extension_blocked,"wide_640_window_terrain_fits":LegionTransitGeometry.window_fits(world.logic_grid,path,mouth,mouth+640.0,8)}

func physical_state(world: SimulationWorld, commander: CommanderState, record: LegionFormationState, mouth: float) -> Dictionary:
	var transit := record.spatial.transit
	var tail := INF
	var wide_ready := 0
	var arrived := 0
	var max_wide_error := 0.0
	var members: Array = []
	var layout := LegionSpatialExecutor.layout(commander.definition.profile.profile_id,record.spatial.action)
	for identity in range(commander.growth_unlocked_slots):
		var unit := LegionTransitExecutor._entity(world,commander,identity)
		var target := record.spatial.anchor+record.spatial.facing*layout.offsets[identity].x+record.spatial.facing.orthogonal()*layout.offsets[identity].y
		var error := unit.position.distance_to(target)
		max_wide_error=maxf(max_wide_error,error)
		if error<=6.0: wide_ready+=1
		if unit.legion_slot!=null and unit.legion_slot.at_destination: arrived+=1
		tail=minf(tail,LegionTransitGeometry.progress_at(transit.path,unit.position)-32.0)
		members.append([identity,unit.entity_id,str(unit.position),str(unit.desired_position),str(target),unit.enabled])
	var hero := world.units[commander.hero_entity_id] as UnitState
	tail=minf(tail,LegionTransitGeometry.progress_at(transit.path,hero.position)-32.0)
	members.append([60,hero.entity_id,str(hero.position),str(hero.desired_position),hero.enabled])
	return {"tail_progress":tail,"tail_clear":tail>=mouth,"wide_ready":wide_ready,"wide_error_max":max_wide_error,"at_destination":arrived,"anchor_goal_distance":record.spatial.anchor.distance_to(record.spatial.goal),"members":members}

func _initialize() -> void:
	var count := 12
	var profile: StringName = &"gunner"
	var mirror := false
	var attack := false
	var ticks := 1200
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="): count=int(arg.trim_prefix("--count="))
		if arg.begins_with("--profile="): profile=StringName(arg.trim_prefix("--profile="))
		if arg.begins_with("--ticks="): ticks=int(arg.trim_prefix("--ticks="))
		if arg=="--mirror": mirror=true
		if arg=="--attack": attack=true
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var world := road_fixture(profile,count,mirror,true)
	if attack:
		for formation: FormationState in world.formations.values(): formation.order_kind=FormationState.OrderKind.ATTACK_MOVE
	var commander := world.commanders.values()[0] as CommanderState
	var geometry := {}
	var trace: Array = []
	var stable := 0
	var stable_max := 0
	var first_column := -1
	var first_expand := -1
	var first_clear := -1
	var first_receipt := -1
	var min_gap := INF
	var max_escort_path := 0.0
	var membership: Array = []
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	for tick in range(ticks):
		var before := {}
		for unit: UnitState in world.units.values(): before[unit.entity_id]=unit.position
		step(world)
		var record := world.legion_formation_system.records[commander.definition.definition_id] as LegionFormationState
		var transit := record.spatial.transit
		check(world.units.size()==count+1,"required soldier and commander identities are never removed")
		var payload: Array = [world.current_tick,transit.phase,transit.reason]
		if transit.path!=null:
			if geometry.is_empty(): geometry=exit_geometry(world,transit.path)
			var physical := physical_state(world,commander,record,geometry.mouth_sample)
			payload.append(physical)
			if transit.phase==LegionTransitState.Phase.COLUMN and first_column<0: first_column=world.current_tick
			if transit.phase==LegionTransitState.Phase.EXPAND and first_expand<0: first_expand=world.current_tick
			if physical.tail_clear and first_clear<0: first_clear=world.current_tick
			stable=stable+1 if physical.tail_clear and physical.wide_ready==count else 0
			stable_max=maxi(stable_max,stable)
			if transit.reason==&"TRANSIT_EXIT_COMPLETE":
				if first_receipt<0: first_receipt=world.current_tick
				check(physical.tail_clear and stable>=20,"success receipt requires actual tail clearance and consecutive wide readiness")
			var ids: Array = []
			var batches: Array = []
			var partition: Array = []
			for batch in transit.batches:
				check(batch.identities.size()<=12,"batch physical capacity includes commander")
				partition.append(Array(batch.identities)); ids.append_array(Array(batch.identities))
				batches.append([batch.progress,batch.ready,batch.available,Array(batch.identities)])
			ids.sort()
			var expected: Array = range(count); expected.append(60)
			check(ids==expected,"all required identities occur in exactly one batch")
			if membership.is_empty(): membership=partition.duplicate(true)
			check(membership==partition,"stable batch identities are not reordered to manufacture completion")
			payload.append(batches)
			for unit: UnitState in world.units.values(): check(LegionTransitGeometry.segment_fits(world.logic_grid,before[unit.entity_id],unit.position),"actual motion retains swept 64 terrain envelope")
			if transit.escort_identity>=0 and transit.batches[transit.hero_batch].admitted:
				var hero := world.units[commander.hero_entity_id] as UnitState
				var escort := LegionTransitExecutor._entity(world,commander,transit.escort_identity)
				var route := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,hero.position,escort.position)
				var gap := LegionProtectionPlanner.path_length(route)
				max_escort_path=maxf(max_escort_path,gap)
				check(not route.is_empty() and gap<=240.01,"admitted commander retains reachable same-batch escort")
			for index in range(1,transit.batches.size()):
				if not transit.batches[index].admitted or not transit.batches[index-1].admitted: continue
				var tail := INF; var head := -INF
				for identity in transit.batches[index-1].identities: tail=minf(tail,LegionTransitGeometry.progress_at(transit.path,LegionTransitExecutor._entity(world,commander,identity).position))
				for identity in transit.batches[index].identities: head=maxf(head,LegionTransitGeometry.progress_at(transit.path,LegionTransitExecutor._entity(world,commander,identity).position))
				min_gap=minf(min_gap,tail-head-64.0)
				check(tail-head-64.0>=95.99,"actual transit batches retain 96 clear gap")
			if world.current_tick%100==0: trace.append({"tick":world.current_tick,"phase":transit.phase,"reason":transit.reason,"tail_progress":physical.tail_progress,"wide_ready":physical.wide_ready,"stable":stable,"queue_ready":record.spatial.ready,"batches":batches})
		else:
			for unit: UnitState in world.units.values(): payload.append([unit.entity_id,str(unit.position),str(unit.desired_position)])
		hash.update(JSON.stringify(payload).to_utf8_buffer())
		if world.current_tick%400==0: print("LEGION54_PROGRESS profile=",profile," count=",count," tick=",world.current_tick," phase=",transit.phase," failures=",failures.size())
	var record := world.legion_formation_system.records[commander.definition.definition_id] as LegionFormationState
	var transit := record.spatial.transit
	var final := physical_state(world,commander,record,geometry.mouth_sample)
	var movement_failures := failures.duplicate()
	check(first_column>=0 and record.spatial.ready==count,"all soldiers complete gathering and current queue-slot arrival")
	check(final.tail_clear,"every physical member clears the sampled narrow mouth")
	check(first_expand>=0,"physical exit enters expansion")
	check(final.wide_ready==count and stable>=20,"actual role formation remains ready for twenty consecutive ticks")
	check(first_receipt>=0,"physical exit completion receipt exists")
	check(final.at_destination==count and final.anchor_goal_distance<=6.0,"all soldiers arrive at the original accepted destination")
	var diagnostics: Array = []
	for index in range(transit.batches.size()):
		var batch := transit.batches[index]
		var required := transit.path.total+192.0+float(transit.batches.size()-1-index)*160.0
		var limit := required
		if index>0:
			for identity in transit.batches[index-1].identities: limit=minf(limit,LegionTransitGeometry.progress_at(transit.path,LegionTransitExecutor._entity(world,commander,identity).position)-160.0)
		var rear := batch.progress-(ceili(batch.identities.size()/float(transit.columns))-1)*48.0
		diagnostics.append({"index":index,"progress":batch.progress,"required":required,"limit":limit,"shortfall":required-batch.progress,"window_next_8_fits":LegionTransitGeometry.window_fits(world.logic_grid,transit.path,rear-192.0,batch.progress+8.0,transit.columns),"targets_next_8":LegionTransitExecutor._column_targets(world,transit,batch,batch.progress+8.0).size(),"identities":Array(batch.identities)})
	var result := {"evidence":"SIMULATED_CANDIDATE","profile":profile,"count":count,"mirror":mirror,"attack":attack,"ticks":ticks,"checks":checks,"failures":failures,"movement_failures":movement_failures,"phase":transit.phase,"reason":transit.reason,"first_column":first_column,"first_expand":first_expand,"first_clear":first_clear,"first_receipt":first_receipt,"stable_max":stable_max,"min_gap":min_gap,"max_escort_path":max_escort_path,"path_hash":hash.finish().hex_encode(),"geometry":geometry,"physical":final,"diagnostics":diagnostics,"trace":trace,"full_B":"REWORK"}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file==null: push_error("Cannot write independent exit evidence"); quit(2); return
	file.store_string(JSON.stringify(result)); file.close()
	print("LEGION54_PHYSICAL_EXIT checks=",checks," failures=",failures.size()," phase=",transit.phase," reason=",transit.reason)
	quit(0 if failures.is_empty() else 1)
