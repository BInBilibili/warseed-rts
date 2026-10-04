extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	for faction in [1,2]:
		var view := world.create_commander_task_snapshot(faction,false)
		var prefix := "blue" if faction == 1 else "red"
		var base := view.get_strategic_region(StringName(prefix+"_base"))
		var high := view.get_strategic_region(StringName(prefix+"_mid_high"))
		var hostile := UnitSnapshot.new(UnitState.new(999999,base.position+Vector2(128,0),0,3-faction))
		hostile.is_visible_to_local_player = true
		view.units.assign([hostile])
		var agent := GrowthCommanderAgent.new()
		check(agent._reserve_target(view,high.position).region_id == base.region_id, "reserve protects visible HQ incursion faction %d" % faction)
		var high_hostile := UnitSnapshot.new(UnitState.new(999998,high.position+Vector2(128,0),0,3-faction))
		high_hostile.is_visible_to_local_player = true
		view.units.append(high_hostile)
		check(agent._reserve_target(view,high.position).region_id == base.region_id, "HQ priority over simultaneous close highland threat faction %d" % faction)
		view.units.assign([hostile])
		hostile.is_visible_to_local_player = false
		check(agent._reserve_target(view,high.position).region_id == high.region_id, "hidden HQ threat cannot trigger reserve faction %d" % faction)
		hostile.is_visible_to_local_player = true
		hostile.legion_returning = true
		check(agent._reserve_target(view,high.position).region_id == high.region_id, "returning enemies do not trigger reserve faction %d" % faction)
		_mobile_order_priority(world,faction)
	for faction in [1,2]:
		_attack_headquarters(faction)
		_direct_headquarters_order(faction)
	var report := {"checks":checks,"failures":failures,"evidence":"SIMULATED"}
	print("PERF25_OBJECTIVES ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _direct_headquarters_order(faction: int) -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var id: StringName = &"mobile_legion" if faction == 1 else &"red_mobile_legion"
	var base_id: StringName = &"blue_base" if faction == 1 else &"red_base"
	var base := world.strategic_regions[base_id] as StrategicRegionState
	var command := CommanderOrderCommand.new(world.allocate_command_id(),faction,world.current_tick,id,CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE,base.position,base_id)
	command.hand_back_control = true
	command.apply_requested_posture = true
	check(world.submit_command(command).is_accepted(),"click own HQ center accepts reachable surrounding deployment faction %d" % faction)
	world.advance_tick()
	check(world.commanders[id].target_region_id == base_id,"HQ defense order applied faction %d" % faction)
	var blocked := CommanderOrderCommand.new(world.allocate_command_id(),faction,world.current_tick,id,CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE,Vector2(-100,-100))
	check(not world.submit_command(blocked).is_accepted(),"out of bounds remains rejected faction %d" % faction)
	blocked = CommanderOrderCommand.new(world.allocate_command_id(),faction,world.current_tick,id,CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE,Vector2(64,64))
	check(world.submit_command(blocked).reason == CommandValidationResult.Reason.PATH_UNAVAILABLE,"no nearby reachable deployment remains rejected faction %d" % faction)
	blocked = CommanderOrderCommand.new(world.allocate_command_id(),faction,world.current_tick,id,CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE,base.position,base_id,CommanderState.Posture.BALANCED,PackedVector2Array([Vector2(64,64)]))
	check(world.submit_command(blocked).reason == CommandValidationResult.Reason.PATH_UNAVAILABLE,"unreachable explicit waypoint remains rejected faction %d" % faction)

func _mobile_order_priority(world: SimulationWorld,faction: int) -> void:
	var view := world.create_commander_task_snapshot(faction,false)
	view.tick = 500
	var id: StringName = &"mobile_legion" if faction == 1 else &"red_mobile_legion"
	var commander := view.get_commander(id)
	var prefix := "blue" if faction == 1 else "red"
	var base := view.get_strategic_region(StringName(prefix+"_base"))
	var objective := view.get_strategic_region(&"jungle_upper_major")
	commander.last_growth_order_tick = 0
	commander.autonomous_growth = false
	commander.target_region_id = objective.region_id
	commander.target_position = objective.position
	var hostile := UnitSnapshot.new(UnitState.new(999999,base.position,0,3-faction))
	hostile.is_visible_to_local_player = true
	view.units.assign([hostile])
	var agent := GrowthCommanderAgent.new()
	check(agent.propose(view,world.battle_definition,id).is_empty(),"explicit mobile objective survives HQ defense evaluation faction %d" % faction)
	commander.autonomous_growth = true
	for posture in [CommanderState.Posture.HOLD,CommanderState.Posture.DISENGAGE]:
		commander.posture = posture
		check(agent.propose(view,world.battle_definition,id).is_empty(),"reserve respects posture %d faction %d" % [posture,faction])

func _attack_headquarters(faction: int) -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var commander_id: StringName = &"di_tian" if faction == 1 else &"red_di_tian"
	var commander := world.commanders[commander_id] as CommanderState
	var base_id: StringName = &"red_base" if faction == 1 else &"blue_base"
	var headquarters := world.buildings[SimulationWorld.ENEMY_COMMAND_CENTER_ID if faction == 1 else SimulationWorld.PLAYER_COMMAND_CENTER_ID] as BuildingState
	var approach := Vector2(-1,1).normalized() if faction == 1 else Vector2(1,-1).normalized()
	var assembly := headquarters.position + approach * 650.0
	for unit: UnitState in world.units.values():
		unit.enabled = false
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		var formation := world.formations[card.formation_id] as FormationState
		formation.anchor_position = assembly
		formation.target_position = assembly
		formation.is_moving = false
		for i in range(card.member_entity_ids.size()):
			var unit := world.units[card.member_entity_ids[i]] as UnitState
			unit.enabled = true
			unit.position = assembly+Vector2(i*8,0)
			unit.has_move_target = false
	var hero := world.units[commander.hero_entity_id] as UnitState
	hero.enabled = true
	hero.position = assembly
	world.command_queue.drain()
	world._update_faction_knowledge()
	var command := CommanderOrderCommand.new(world.allocate_command_id(),faction,world.current_tick,commander_id,CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE,headquarters.position+approach*360.0,base_id)
	command.hand_back_control = true
	command.apply_requested_posture = true
	check(world.submit_command(command).is_accepted(), "HQ approach command accepted faction %d" % faction)
	var before := headquarters.health
	for tick in range(90): world.advance_tick()
	check(headquarters.health < before, "autonomous legion closes range and damages objective HQ faction %d" % faction)
	var card := world.unit_cards[commander.subordinate_unit_card_ids[0]] as UnitCardState
	var task := world.tasks[card.assigned_task_id] as TaskState
	var formation := world.formations[card.formation_id] as FormationState
	for posture in [CommanderState.Posture.HOLD,CommanderState.Posture.DISENGAGE]:
		commander.posture = posture
		check(not world.strategic_task_system._advance_growth_structure_objective(task,formation,world),"structure approach respects posture %d faction %d" % [posture,faction])
	commander.posture = CommanderState.Posture.BALANCED
	commander.growth_recovering = true
	check(not world.strategic_task_system._advance_growth_structure_objective(task,formation,world),"recovering legion does not attack structure faction %d" % faction)
	commander.growth_recovering = false
	commander.legion_regrouping = true
	check(not world.strategic_task_system._advance_growth_structure_objective(task,formation,world),"returning legion does not attack structure faction %d" % faction)
	commander.legion_regrouping = false
	world.faction_knowledge[faction].visible_hostile_building_ids.clear()
	check(not world.strategic_task_system._advance_growth_structure_objective(task,formation,world),"hidden structure does not trigger approach faction %d" % faction)
	print("PERF25_HQ faction=%d hp=%.1f->%.1f" % [faction,before,headquarters.health])
