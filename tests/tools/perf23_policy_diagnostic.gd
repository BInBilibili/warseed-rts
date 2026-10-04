extends SceneTree
func _initialize() -> void:
	var policy=preload("res://tests/tools/perf23_blue_policy.gd").new("concentration")
	var world:=SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION,{},&"",policy.army_plan())
	var failures:Array[String]=[]
	var commander:=world.commanders[&"di_tian"] as CommanderState
	var target:=world.strategic_regions[&"blue_mid_high"] as StrategicRegionState
	var command:=CommanderOrderCommand.new(world.allocate_command_id(),1,0,&"di_tian",CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE,target.position,target.region_id)
	if not world.validate_command(command).is_accepted(): failures.append("zero role vetoed legion order")
	var active_card:UnitCardState
	for id in commander.subordinate_unit_card_ids:
		var card:=world.unit_cards[id] as UnitCardState
		if card.definition.authorized_strength>0: active_card=card;break
	var saved_formation:=active_card.formation_id
	active_card.formation_id=-98765
	if world.validate_command(command).is_accepted(): failures.append("missing real formation was accepted")
	active_card.formation_id=saved_formation
	for tick in range(201):
		policy.advance(world)
		world.advance_tick()
	print("POLICY_DIAGNOSTIC ",JSON.stringify(policy.actions))
	print("POLICY_BOUNDARIES failures=",failures)
	quit(0 if failures.is_empty() else 1)
