extends "res://tests/tools/legion49_narrow_executor.gd"

func apply_valid(world: SimulationWorld, command: GameCommand) -> void:
	check(world.submit_command(command).is_accepted(),"boundary command admitted through shared validation")
	for queued in world.command_queue.drain(): world._apply_command(queued)

func boundary_cases() -> void:
	var world := road_fixture(&"gunner",12,false,false)
	var commander := world.commanders.values()[0] as CommanderState
	var artillery: UnitCardState
	for id in commander.subordinate_unit_card_ids:
		if world.unit_cards[id].definition.role_key==LegionTemplate.ROLE_KEYS[3]: artillery=world.unit_cards[id]
	var gun_formation := world.formations[artillery.formation_id] as FormationState
	gun_formation.order_destination=Vector2(2048,14000)
	gun_formation.target_position=gun_formation.order_destination
	gun_formation.path.append(gun_formation.order_destination)
	gun_formation.planned_route.append(gun_formation.order_destination)
	for tick in range(600): step(world)
	check(gun_formation.is_moving,"reaching another card destination cannot complete artillery objective")
	for id in artillery.member_entity_ids:
		check(not world.units[id].legion_slot.at_destination,"different card goal retains nonarrival")
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	var previous_goal := record.spatial.goal
	var old_snapshot := record.duplicate_value()
	apply_valid(world,CommanderOrderCommand.new(world.allocate_command_id(),1,world.current_tick,commander.definition.definition_id,CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE,Vector2(2048,13000)))
	# Commander intent first creates tasks. Let their real activation delay and
	# command generation run; intent admission alone is not a card move order.
	for tick in range(40):
		world.strategic_task_system.advance(world)
		for queued in world.command_queue.drain(): world._apply_command(queued)
		step(world)
	check(record.spatial.goal!=previous_goal,"accepted new objective replaces old spatial goal")
	check(record.spatial.route_index<record.spatial.route.size(),"new objective cannot inherit consumed old route")
	check(old_snapshot.spatial.goal==previous_goal,"prior snapshot keeps its old goal")
	for unit: UnitState in world.units.values():
		if unit.legion_slot!=null: check(not unit.legion_slot.at_destination,"new distant objective not completed early")
	apply_valid(world,UnitCardControlCommand.new(world.allocate_command_id(),1,world.current_tick,artillery.definition.definition_id,UnitCardControlCommand.Action.TAKEOVER))
	apply_valid(world,StopCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,artillery.member_entity_ids[0],artillery.formation_id))
	var stopped := {}
	for id in artillery.member_entity_ids: stopped[id]=world.units[id].position
	for tick in range(30): step(world)
	for id in artillery.member_entity_ids:
		check(world.units[id].position==stopped[id],"arrival coordinator preserves actual player stop")
		check(world.units[id].legion_slot==null,"player card remains outside automatic slots")
	check(not gun_formation.is_moving,"arrival fix does not reactivate player stop")
	rows.append({"boundary_cases":"different goal, new shared command, snapshot, takeover and stop","old_goal":str(previous_goal),"new_goal":str(record.spatial.goal)})

func _initialize() -> void:
	for profile: StringName in [&"spear",&"guardian",&"gunner"]:
		for mirror in [false,true]:
			var row := road_trial(profile,12,mirror,false)
			check(row.completed_tick>0,"reformed actual formation completes all cards: "+String(profile)+str(mirror))
			rows.append(row)
	boundary_cases()
	FileAccess.open("res://artifacts/legion50/arrival-contract02.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED","checks":checks,"failures":failures,"rows":rows}))
	print("LEGION50_ARRIVAL checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
