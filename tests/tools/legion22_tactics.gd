extends SceneTree
var failures: Array[String] = []
func check(value: bool, why: String) -> void:
	if not value: failures.append(why)
func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	for commander: CommanderState in world.commanders.values(): commander.posture = CommanderState.Posture.HOLD
	var card := world.unit_cards[&"final_group_1_falcon_recon_group"] as UnitCardState
	var center := (world.formations[card.formation_id] as FormationState).anchor_position
	var enemy: UnitState
	for unit: UnitState in world.units.values():
		if unit.faction_id == 2:
			enemy = unit
			break
	enemy.position = center + Vector2(150,0)
	enemy.health = 100000
	enemy.max_health = 100000
	enemy.can_attack = false
	enemy.following_formation = false
	enemy.has_move_target = false
	enemy.assigned_task_id = 0
	enemy.assigned_agent_id = 0
	enemy.control_state = UnitState.ControlState.PLAYER_CONTROLLED
	world._update_faction_knowledge()
	check(world._handoff_delay(card) == 30, "contact delay3s")
	var command := UnitCardControlCommand.new(world.allocate_command_id(),1,world.current_tick,card.definition.definition_id,UnitCardControlCommand.Action.TAKEOVER)
	check(world.submit_command(command).is_accepted(), "initial control accepted")
	for tick in range(25):
		_contact_step(world, card, enemy)
	check(card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED, "manual before3s")
	command = UnitCardControlCommand.new(world.allocate_command_id(),1,world.current_tick,card.definition.definition_id,UnitCardControlCommand.Action.TAKEOVER)
	check(world.submit_command(command).is_accepted(), "renew control accepted")
	for tick in range(15):
		_contact_step(world, card, enemy)
	check(card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED, "second input resets timeout")
	for tick in range(30):
		_contact_step(world, card, enemy)
	check(card.control_state in [UnitCardState.ControlState.AGENT_ASSIGNED,UnitCardState.ControlState.RETURNING], "contact returns automatically")
	# Independently verify reserve reacts only to a legally observed intruder.
	var mobile := world.commanders[&"mobile_legion"] as CommanderState
	mobile.posture = CommanderState.Posture.BALANCED
	mobile.last_growth_order_tick = -1000
	var high := world.strategic_regions[&"blue_mid_high"] as StrategicRegionState
	enemy.position = high.position + Vector2(128,0)
	var observer := world.units[card.member_entity_ids[0]] as UnitState
	observer.position = high.position
	world._update_faction_knowledge()
	var view := world.create_commander_task_snapshot(1)
	var orders := GrowthCommanderAgent.new().propose(view,world.battle_definition)
	var intercepted := false
	for order in orders:
		if order.commander_id == &"mobile_legion": intercepted = order.target_position == enemy.position
	check(intercepted,"mobile intercepts observed highland threat")
	var saved := observer.position
	observer.position = world.battle_definition.player_headquarters_position
	enemy.position = world.battle_definition.enemy_headquarters_position
	world._update_faction_knowledge()
	orders = GrowthCommanderAgent.new().propose(world.create_commander_task_snapshot(1),world.battle_definition)
	for order in orders:
		if order.commander_id == &"mobile_legion": check(order.target_position != enemy.position,"reserve ignores hidden target")
	var priority := SupplyPriorityCommand.new(world.allocate_command_id(),1,world.current_tick,&"di_tian")
	check(world.submit_command(priority).is_accepted(),"priority accepted")
	world.advance_tick()
	var rates := 0
	for value in world.factions[1].recruitment_rates.values(): rates += value
	check(rates == 5 and world.factions[1].recruitment_rates[&"mobile_legion"] == 0,"priority reallocates five total slots")
	print("LEGION22_TACTICS ",failures)
	quit(0 if failures.is_empty() else 1)

func _contact_step(world: SimulationWorld, card: UnitCardState, enemy: UnitState) -> void:
	enemy.position = (world.formations[card.formation_id] as FormationState).anchor_position + Vector2(150,0)
	enemy.has_move_target = false
	world._update_faction_knowledge()
	world.advance_tick()
