extends "res://tests/tools/legion49_narrow_aligned.gd"

func _initialize() -> void:
	var destination := "res://artifacts/legion52/manual-move-boundary01.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): destination=arg.trim_prefix("--output=")
	var world := road_fixture(&"gunner",12,false,true)
	var commander := world.commanders.values()[0] as CommanderState
	for tick in range(230): step(world)
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	var source := LegionSpatialExecutor._source(world,commander,record)
	var card := world.unit_cards[world.units[source.leader_entity_id].unit_card_id] as UnitCardState
	var order := FormationMoveCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,source.leader_entity_id,source.formation_id,source.order_destination,PackedVector2Array([Vector2(2048,18432),Vector2(4864,16384),source.order_destination]))
	var receipt := world.submit_command(order)
	check(receipt.is_accepted(),"direct player card movement is a legal command")
	for command in world.command_queue.drain(): world._apply_command(command)
	var max_excess := 0.0; var min_pair := INF
	for tick in range(100):
		var before := {}; var speed := {}
		for unit: UnitState in world.units.values(): before[unit.entity_id]=unit.position; speed[unit.entity_id]=unit.move_speed
		step(world)
		for unit: UnitState in world.units.values(): max_excess=maxf(max_excess,unit.position.distance_to(before[unit.entity_id])-speed[unit.entity_id]*SimulationWorld.TICK_SECONDS)
		for id in card.member_entity_ids: check(world.units[id].legion_slot==null,"manual card is excluded from automatic transit")
		var units := world.units.values()
		for a in range(units.size()):
			for b in range(a+1,units.size()): min_pair=minf(min_pair,units[a].position.distance_to(units[b].position))
	var data := {"evidence":"SIMULATED_CANDIDATE","checks":checks,"failures":failures,"max_tick_speed_excess":max_excess,"min_entity_distance":min_pair,"manual_card":card.definition.definition_id,"full_B":"REWORK"}
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION51_MANUAL_MOVE checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
