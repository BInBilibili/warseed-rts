extends "res://tests/tools/legion49_narrow_aligned.gd"

func _initialize() -> void:
	var count := 12
	var profile: StringName = &"gunner"
	var mirror := false
	var attack := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="): count=int(arg.trim_prefix("--count="))
		if arg.begins_with("--profile="): profile=StringName(arg.trim_prefix("--profile="))
		if arg=="--mirror": mirror=true
		if arg=="--attack": attack=true
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var world := road_fixture(profile,count,mirror,true)
	if attack:
		for formation: FormationState in world.formations.values(): formation.order_kind=FormationState.OrderKind.ATTACK_MOVE
	var commander := world.commanders.values()[0] as CommanderState
	var trace: Array = []
	var first_column := -1
	var min_gap := INF
	var gap_failures: Array = []
	var max_escort_path := 0.0
	var path_hash := HashingContext.new(); path_hash.start(HashingContext.HASH_SHA256)
	for tick in range(1200):
		var before := {}
		for unit: UnitState in world.units.values(): before[unit.entity_id]=unit.position
		step(world)
		var record := world.legion_formation_system.records[commander.definition.definition_id]
		var transit := record.spatial.transit
		var staging := PackedVector2Array()
		for batch in transit.batches:
			check(batch.identities.size()<=12,"every batch includes at most twelve physical identities")
			if batch.gather_phase!=0 or transit.phase==LegionTransitState.Phase.BLOCKED: continue
			for ordinal in range(batch.identities.size()):
				var target := LegionTransitExecutor._target(transit,batch,ordinal)
				for occupied in staging: check(target.distance_to(occupied)>=47.99,"longitudinal staging never assigns the same occupied slot twice")
				staging.append(target)
		var payload: Array = [world.current_tick,transit.phase,transit.reason,record.spatial.ready,record.spatial.eligible]
		for unit: UnitState in world.units.values(): payload.append([unit.entity_id,str(unit.position),str(unit.desired_position)])
		for batch in transit.batches: payload.append([batch.identities,batch.progress,batch.ready,batch.available])
		path_hash.update(JSON.stringify(payload).to_utf8_buffer())
		if transit.phase!=LegionTransitState.Phase.WIDE:
			if first_column<0 and transit.phase in [LegionTransitState.Phase.COLUMN,LegionTransitState.Phase.EXIT_WAIT]: first_column=world.current_tick
			for unit: UnitState in world.units.values():
				check(LegionTransitGeometry.segment_fits(world.logic_grid,before[unit.entity_id],unit.position),"actual column motion retains swept 64 terrain envelope")
			if transit.escort_identity>=0 and transit.batches[transit.hero_batch].admitted:
				var hero := world.units[commander.hero_entity_id] as UnitState
				var escort := LegionTransitExecutor._entity(world,commander,transit.escort_identity)
				var route := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,hero.position,escort.position)
				var gap := LegionProtectionPlanner.path_length(route)
				max_escort_path=maxf(max_escort_path,gap)
				check(not route.is_empty() and gap<=240.01,"actual column commander retains a reachable same-batch core")
			for index in range(1,transit.batches.size()):
				if not transit.batches[index].admitted or not transit.batches[index-1].admitted: continue
				var previous_tail := INF; var head := -INF
				for identity in transit.batches[index-1].identities:
					var u := LegionTransitExecutor._entity(world,commander,identity)
					previous_tail=minf(previous_tail,LegionTransitGeometry.progress_at(transit.path,u.position))
				for identity in transit.batches[index].identities:
					var u := LegionTransitExecutor._entity(world,commander,identity)
					head=maxf(head,LegionTransitGeometry.progress_at(transit.path,u.position))
				min_gap=minf(min_gap,previous_tail-head-64.0)
				if previous_tail-head-64.0<95.99 and gap_failures.size()<20:
					var positions: Array = []
					for b in range(index-1,index+1):
						for identity in transit.batches[b].identities:
							var u := LegionTransitExecutor._entity(world,commander,identity)
							positions.append({"batch":b,"identity":identity,"position":str(u.position),"progress":LegionTransitGeometry.progress_at(transit.path,u.position),"target":str(u.desired_position)})
					gap_failures.append({"tick":world.current_tick,"gap":previous_tail-head-64.0,"members":positions})
				check(previous_tail-head-64.0>=95.99,"actual column batches retain 96 clear gap")
		if world.current_tick%50==0:
			var batches: Array = []
			for batch in transit.batches: batches.append({"progress":batch.progress,"ready":batch.ready,"available":batch.available,"admitted":batch.admitted,"gather_phase":batch.gather_phase})
			trace.append({"tick":world.current_tick,"phase":transit.phase,"columns":transit.columns,"reason":transit.reason,"ready":record.spatial.ready,"eligible":record.spatial.eligible,"batches":batches,"hero":str(world.units[commander.hero_entity_id].position)})
			print("LEGION51_TRANSIT_PROGRESS count=",count," tick=",world.current_tick," phase=",transit.phase," ready=",record.spatial.ready," reason=",transit.reason," errors=",failures.size())
	var state := world.legion_formation_system.records[commander.definition.definition_id].spatial
	check(first_column>=0,"normal wide start physically gathers into column")
	check(not state.transit.batches.is_empty() and state.transit.batches[0].progress>4000.0,"real lead batch passes first narrow bend")
	check(state.ready==count,"all required soldiers physically settle after queue movement")
	var members: Array = []
	for identity in range(count):
		var unit := world.units[commander.growth_slot_entities[identity]] as UnitState
		members.append({"identity":identity,"position":str(unit.position),"target":str(unit.legion_slot.target),"reason":unit.legion_slot.reason})
	var data := {"evidence":"SIMULATED_CANDIDATE","profile":profile,"mirror":mirror,"attack":attack,"count":count,"checks":checks,"failures":failures,"first_column":first_column,"min_gap":min_gap if min_gap<INF else -1,"max_escort_path":max_escort_path,"path_hash":path_hash.finish().hex_encode(),"gap_failures":gap_failures,"trace":trace,"members":members,"full_B":"REWORK","exit_expansion":"NOT_IMPLEMENTED"}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION51_TRANSIT checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
