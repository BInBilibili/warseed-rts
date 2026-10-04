class_name GrowthCommanderSystem
extends RefCounted

var agent := GrowthCommanderAgent.new()

func validate(world: SimulationWorld, command: GrowthCommanderCommand) -> CommandValidationResult:
	if world.battle_definition == null or not world.battle_definition.growth_mode:
		return CommandValidationResult.new(CommandValidationResult.Status.REJECTED, CommandValidationResult.Reason.INVALID_TARGET)
	var commander := world.commanders.get(command.commander_id) as CommanderState
	if commander == null or commander.faction_id != command.issuer_id or command.issuer_kind != GameCommand.IssuerKind.AGENT or command.agent_id != commander.agent_id or not world._agent_authorization_allows(command):
		return CommandValidationResult.new(CommandValidationResult.Status.REJECTED, CommandValidationResult.Reason.AGENT_NOT_AUTHORIZED)
	if world.commander_task_graph_system.owns_commander(commander):
		return CommandValidationResult.new(CommandValidationResult.Status.REJECTED, CommandValidationResult.Reason.TASK_CONFLICT)
	for pending in world.command_queue.snapshot():
		if (pending is GrowthCommanderCommand or pending is CommanderOrderCommand) and pending.commander_id == command.commander_id:
			return CommandValidationResult.new(CommandValidationResult.Status.REJECTED, CommandValidationResult.Reason.TASK_CONFLICT)
	for candidate in agent.propose(world.create_commander_task_snapshot(command.issuer_id, false), world.battle_definition, command.commander_id):
		if candidate.commander_id == command.commander_id and candidate.action == command.action and candidate.target_region_id == command.target_region_id and candidate.target_position == command.target_position:
			return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED)
	return CommandValidationResult.new(CommandValidationResult.Status.REJECTED, CommandValidationResult.Reason.TASK_CONFLICT)

func apply(world: SimulationWorld, command: GrowthCommanderCommand) -> void:
	var checked := validate(world, command)
	if not checked.is_accepted():
		world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.COMMAND_REJECTED, command.issuer_id, checked.describe()))
		return
	var commander := world.commanders[command.commander_id] as CommanderState
	var route := PackedVector2Array()
	if command.action in [GrowthCommanderCommand.Action.ADVANCE,GrowthCommanderCommand.Action.DEFEND_SUPPLY]:
		# Validation above proves the previous execution is complete and the
		# existing agent is authorized to choose this objective. Recovery/resume
		# retain the original source because they temporarily interrupt it.
		commander.legion_execution_authority = CommanderState.LegionExecutionAuthority.AGENT_OBJECTIVE
	if command.action == GrowthCommanderCommand.Action.RECOVER:
		if not commander.growth_recovering:
			commander.recovery_started_tick = world.current_tick
			commander.recovery_strength = 0
			for card_id in commander.subordinate_unit_card_ids:
				commander.recovery_strength += UnitCardSnapshot.new(world.unit_cards[card_id], world.units).current_strength
			commander.growth_resume_position = commander.target_position
			commander.growth_resume_region_id = commander.target_region_id
			commander.growth_resume_route = commander.planned_route.duplicate()
		commander.growth_recovering = true
	elif command.action == GrowthCommanderCommand.Action.RESUME:
		commander.growth_recovering = false
		route = commander.growth_resume_route.duplicate()
	world._assign_commander_objective(commander, command.target_position, command.target_region_id, route)
	commander.last_growth_order_tick = world.current_tick
	world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.TASK_STATE_CHANGED, command.issuer_id, "growth_commander=%s;action=%s;region=%s" % [command.commander_id, GrowthCommanderCommand.Action.keys()[command.action], command.target_region_id]))

func propose_commands(world: SimulationWorld) -> void:
	if world.battle_definition == null or not world.battle_definition.growth_mode or world.current_tick % 20 != 0:
		return
	for faction in [1, 2]:
		for command in agent.propose(world.create_commander_task_snapshot(faction, false), world.battle_definition):
			var commander := world.commanders[command.commander_id] as CommanderState
			if world.commander_task_graph_system.owns_commander(commander):
				continue
			command.command_id = world.allocate_command_id()
			world.submit_command(command)
