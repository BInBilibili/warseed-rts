extends "res://tests/tools/legion49_narrow_aligned.gd"

func apply_valid(world: SimulationWorld, command: GameCommand) -> void:
	check(world.submit_command(command).is_accepted(),"transit boundary command accepted by shared validation")
	for queued in world.command_queue.drain(): world._apply_command(queued)

func _initialize() -> void:
	var world := road_fixture(&"gunner",12,false,true)
	var commander := world.commanders.values()[0] as CommanderState
	for tick in range(200): step(world)
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	check(record.spatial.transit.phase==LegionTransitState.Phase.COLUMN,"control fixture really reaches physical column")
	var snapshot := record.duplicate_value()
	var old_progress := snapshot.spatial.transit.batches[0].progress
	var old_points := snapshot.spatial.transit.path.points.duplicate()
	var old_members := snapshot.spatial.transit.batches[0].identities.duplicate()
	for tick in range(30): step(world)
	check(snapshot.spatial.transit.batches[0].progress==old_progress,"old transit snapshot retains progress after actual movement")
	check(snapshot.spatial.transit.path.points==old_points,"old transit snapshot retains route geometry")
	check(snapshot.spatial.transit.batches[0].identities==old_members,"old transit snapshot retains batch identities")
	var artillery: UnitCardState
	for id in commander.subordinate_unit_card_ids:
		if world.unit_cards[id].definition.role_key==LegionTemplate.ROLE_KEYS[3]: artillery=world.unit_cards[id]
	apply_valid(world,UnitCardControlCommand.new(world.allocate_command_id(),1,world.current_tick,artillery.definition.definition_id,UnitCardControlCommand.Action.TAKEOVER))
	apply_valid(world,StopCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,artillery.member_entity_ids[0],artillery.formation_id))
	var stopped := {}
	for id in artillery.member_entity_ids: stopped[id]=world.units[id].position
	for tick in range(30): step(world)
	for id in artillery.member_entity_ids:
		check(world.units[id].position==stopped[id],"transit preserves actual player-stopped card positions")
		check(world.units[id].legion_slot==null,"transit releases all manually controlled card slots")
	var previous_goal := record.spatial.transit.goal
	apply_valid(world,CommanderOrderCommand.new(world.allocate_command_id(),1,world.current_tick,commander.definition.definition_id,CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE,Vector2(2048,18000)))
	for tick in range(40):
		world.strategic_task_system.advance(world)
		for queued in world.command_queue.drain(): world._apply_command(queued)
		step(world)
	var source := LegionSpatialExecutor._source(world,commander,record)
	check(source.order_destination!=previous_goal,"new strategic command reaches actual source formation")
	check(record.spatial.goal==source.order_destination,"transit replaces obsolete goal after a valid new order")
	var before := {}
	for unit: UnitState in world.units.values(): before[unit.entity_id]=unit.position
	for tick in range(10): step(world)
	var stale_moves := 0
	for unit: UnitState in world.units.values():
		if unit.position.distance_to(before[unit.entity_id])>0.01 and record.spatial.transit.phase==LegionTransitState.Phase.BLOCKED: stale_moves+=1
	check(stale_moves==0,"order-changed blocked state cannot keep moving to obsolete transit targets")
	var data := {"evidence":"SIMULATED_CANDIDATE","checks":checks,"failures":failures,"old_goal":str(previous_goal),"source_goal":str(source.order_destination),"transit_goal":str(record.spatial.transit.goal),"phase":record.spatial.transit.phase,"reason":record.spatial.transit.reason,"stale_moves":stale_moves,"full_B":"REWORK"}
	FileAccess.open("res://artifacts/legion51/transit-controls08.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION51_CONTROLS checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
