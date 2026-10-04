extends SceneTree

var failures: Array[String]=[]
var checks := 0
var output := ""
var ticks := 1200
var manual := false

func check(value: bool, reason: String) -> void:
	checks+=1
	if not value and not failures.has(reason): failures.append(reason); print("FAIL ",reason)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--ticks="): ticks=int(arg.trim_prefix("--ticks="))
		if arg=="--manual": manual=true
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var starts := {}; var distances := {}; var initial_members := {}; var goals := {}; var accepted := 0
	var goal_distances := {}; var member_goals := {}; var member_distances := {}
	for id: StringName in world.commanders:
		var c: CommanderState=world.commanders[id]
		starts[id]=world.units[c.hero_entity_id].position; distances[id]=0.0
		for entity in c.growth_slot_entities:
			if entity>0: initial_members[entity]=world.units[entity].position
		if manual:
			var goal: Vector2=world.strategic_regions[&"blue_mid_high" if c.faction_id==1 else &"red_mid_high"].position
			var command := CommanderOrderCommand.new(world.allocate_command_id(),c.faction_id,0,id,CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE,goal)
			command.use_legion_deployment=true; command.hand_back_control=true
			command.apply_requested_posture=true; command.deployment_facing=(goal-starts[id]).normalized()
			var result := world.submit_command(command)
			check(result.is_accepted(),"manual opening accepted "+str(id)+" "+str(result.reason))
			if result.is_accepted(): accepted+=1
			goals[id]=goal
			goal_distances[id]=INF
			for entity in c.growth_slot_entities:
				if entity>0: member_goals[entity]=goal; member_distances[entity]=INF
	var samples: Array=[]; var max_overlap := 0; var cursor := 0; var fired := 0
	for step in range(ticks):
		var previous := {}
		for unit: UnitState in world.units.values():
			if unit.enabled: previous[unit.entity_id]=[unit.position,unit.move_speed,unit.legion_returning]
		world.advance_tick()
		var overlapping := 0
		for unit: UnitState in world.units.values():
			if not unit.enabled or not unit.flexible_legion_movement: continue
			if member_goals.has(unit.entity_id): member_distances[unit.entity_id]=minf(member_distances[unit.entity_id],unit.position.distance_to(member_goals[unit.entity_id]))
			if previous.has(unit.entity_id) and not unit.legion_returning and not previous[unit.entity_id][2]:
				var origin: Vector2=previous[unit.entity_id][0]
				check(origin.distance_to(unit.position)<=maxf(previous[unit.entity_id][1],unit.move_speed)*0.1+0.1,"real speed E"+str(unit.entity_id))
				check(world.logic_grid.is_segment_walkable(origin,unit.position),"no terrain crossing E"+str(unit.entity_id))
			if unit.reformation!=null and unit.reformation.forced_overlap:
				overlapping+=1
				check(is_equal_approx(LegionReformationSystem.damage_factor(unit),1.5),"overlap damage exactly once")
		max_overlap=maxi(max_overlap,overlapping)
		while cursor<world.events.size():
			if world.events[cursor].kind==SimulationEvent.Kind.PROJECTILE_FIRED: fired+=1
			cursor+=1
		for id: StringName in world.commanders:
			var c: CommanderState=world.commanders[id]
			var hero: UnitState=world.units[c.hero_entity_id]
			distances[id]=maxf(distances[id],hero.position.distance_to(starts[id]))
			if goals.has(id): goal_distances[id]=minf(goal_distances[id],hero.position.distance_to(goals[id]))
		if world.current_tick%200==0:
			var row := {"tick":world.current_tick,"distances":distances.duplicate(),"fired":fired,"overlaps":overlapping}
			samples.append(row); print(JSON.stringify(row))
	for id in starts: check(distances[id]>600.0,"commander left spawn "+str(id))
	var unmoved: Array=[]
	for id in initial_members:
		var unit: UnitState=world.units[id]
		if unit.enabled and not unit.legion_returning and unit.position.distance_to(initial_members[id])<400.0: unmoved.append(id)
	check(unmoved.is_empty(),"initial soldiers left spawn "+str(unmoved))
	if manual:
		for id in goal_distances: check(goal_distances[id]<350.0,"hero reached requested area "+str(id)+" distance="+str(goal_distances[id]))
		for id in member_distances: check(member_distances[id]<600.0,"soldier reached requested area E"+str(id)+" distance="+str(member_distances[id]))
	var fingerprint := HashingContext.new(); fingerprint.start(HashingContext.HASH_SHA256)
	for unit: UnitState in world.units.values(): fingerprint.update(str([unit.entity_id,unit.position,unit.health,unit.enabled]).to_utf8_buffer())
	var result := {"evidence":"SIMULATED_MAIN","failures":failures,"checks":checks,"manual":manual,"accepted":accepted,"ticks":world.current_tick,"samples":samples,"maximum_overlap_count":max_overlap,"fingerprint":fingerprint.finish().hex_encode(),"fired":fired,"goal_distances":goal_distances,"member_distances":member_distances}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result))
	print("MOVEMENT_CONTRACT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
