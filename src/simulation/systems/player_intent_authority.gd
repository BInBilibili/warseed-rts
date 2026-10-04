class_name PlayerIntentAuthority
extends RefCounted

const Mode := CommanderState.IntentMode
const Receipt := CommanderState.IntentReceipt


static func enabled(world: SimulationWorld) -> bool:
	return world.battle_definition != null and world.battle_definition.growth_mode


static func card_for(world: SimulationWorld, command: GameCommand) -> UnitCardState:
	if command is UnitCardControlCommand or command is TacticalAbilityCommand or command is SupportOrderCommand or command is DeployUnitCardCommand or command is RecruitUnitCardCommand:
		return world.unit_cards.get(command.unit_card_id) as UnitCardState
	if command is CommanderCardTaskCommand:
		var ids := world.commander_task_graph_system.authority_cards(command)
		return world.unit_cards.get(ids[0]) as UnitCardState if not ids.is_empty() else null
	if command is TaskControlCommand:
		var task := world.tasks.get(command.controlled_task_id) as TaskState
		return world.unit_cards.get(task.unit_card_id) as UnitCardState if task != null else null
	if command is FormationMoveCommand or command is AttackCommand or command is StopCommand or command is StrategicOrderCommand:
		if command.formation_id != 0:
			return world._unit_card_for_formation(command.formation_id)
	var unit := world.units.get(command.target_entity_id) as UnitState
	return world.unit_cards.get(unit.unit_card_id) as UnitCardState if unit != null else null


static func commander_for(world: SimulationWorld, command: GameCommand) -> CommanderState:
	if command is CommanderOrderCommand or command is GrowthCommanderCommand:
		return world.commanders.get(command.commander_id) as CommanderState
	var card := card_for(world, command)
	return world.commanders.get(card.commander_definition_id) as CommanderState if card != null else null


static func validate(world: SimulationWorld, command: GameCommand) -> CommandValidationResult:
	if not enabled(world): return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED)
	if command.scoped_card_ids.size() != command.scoped_card_versions.size() or command.scoped_card_ids.size() != command.scoped_commander_versions.size():
		return reject(CommandValidationResult.Reason.INVALID_DEFINITION)
	if command is CommanderCardTaskCommand:
		for id in world.commander_task_graph_system.authority_cards(command):
			var scoped := world.unit_cards.get(id) as UnitCardState
			var owner := world.commanders.get(scoped.commander_definition_id) as CommanderState if scoped != null else null
			if owner != null and owner.faction_id == command.issuer_id and owner.legion_regrouping:
				return reject(CommandValidationResult.Reason.ENTITY_DISABLED)
	for index in range(command.scoped_card_ids.size() if command.issuer_kind == GameCommand.IssuerKind.AGENT or command is StaffPlanApprovalCommand else 0):
		var scoped := world.unit_cards.get(command.scoped_card_ids[index]) as UnitCardState
		var owner := world.commanders.get(scoped.commander_definition_id) as CommanderState if scoped != null else null
		if scoped == null or owner == null or scoped.authority_version != command.scoped_card_versions[index] or owner.authority_version != command.scoped_commander_versions[index]:
			return reject(CommandValidationResult.Reason.AUTHORITY_STALE)
		if command.issuer_kind == GameCommand.IssuerKind.AGENT and owner.intent_mode != Mode.AUTONOMOUS:
			return reject(CommandValidationResult.Reason.AGENT_OVERRIDE_BLOCKED)
	var commander := commander_for(world, command)
	if command is UnitCardControlCommand and command.automatic_return:
		return reject(CommandValidationResult.Reason.AGENT_OVERRIDE_BLOCKED)
	if command is StaffPlanApprovalCommand and command.request != null:
		for id in staff_scope(world, command):
			var card := world.unit_cards.get(id) as UnitCardState
			var owner := world.commanders.get(card.commander_definition_id) as CommanderState if card != null else null
			if owner != null and (owner.intent_mode != Mode.AUTONOMOUS or card.persistent_manual):
				return reject(CommandValidationResult.Reason.TASK_CONFLICT)
	if command.issuer_kind == GameCommand.IssuerKind.AGENT and commander != null:
		for pending in world.command_queue.snapshot():
			if pending.issuer_kind != GameCommand.IssuerKind.PLAYER: continue
			if pending is CommanderOrderCommand and pending.commander_id == commander.definition.definition_id:
				return reject(CommandValidationResult.Reason.AGENT_OVERRIDE_BLOCKED)
			var pending_card := card_for(world, pending)
			if pending_card != null and pending_card == card_for(world, command) and (world._is_direct_player_order(pending) or pending is UnitCardControlCommand):
				return reject(CommandValidationResult.Reason.AGENT_OVERRIDE_BLOCKED)
		if command.expected_commander_version >= 0 and command.expected_commander_version != commander.authority_version:
			return reject(CommandValidationResult.Reason.AUTHORITY_STALE)
		var card := card_for(world, command)
		if card != null and command.expected_card_version >= 0 and command.expected_card_version != card.authority_version:
			return reject(CommandValidationResult.Reason.AUTHORITY_STALE)
		if commander.intent_mode != Mode.AUTONOMOUS:
			if command is CommanderOrderCommand or command is CommanderCardTaskCommand or command is StrategicOrderCommand or command is TaskControlCommand:
				return reject(CommandValidationResult.Reason.AGENT_OVERRIDE_BLOCKED)
			if command is GrowthCommanderCommand and (commander.intent_mode != Mode.OBJECTIVE or command.action not in [GrowthCommanderCommand.Action.RECOVER, GrowthCommanderCommand.Action.RESUME]):
				return reject(CommandValidationResult.Reason.AGENT_OVERRIDE_BLOCKED)
	return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED)


static func accepted(world: SimulationWorld, command: GameCommand) -> void:
	if not enabled(world): return
	command.scoped_card_ids.clear()
	command.scoped_card_versions.clear()
	command.scoped_commander_versions.clear()
	var commander := commander_for(world, command)
	var card := card_for(world, command)
	if command is CommanderCardTaskCommand:
		command.scoped_card_ids = world.commander_task_graph_system.authority_cards(command)
	elif command is StaffPlanApprovalCommand and command.request != null:
		command.scoped_card_ids = staff_scope(world, command)
	for id in command.scoped_card_ids:
		var scoped := world.unit_cards.get(id) as UnitCardState
		var owner := world.commanders.get(scoped.commander_definition_id) as CommanderState if scoped != null else null
		command.scoped_card_versions.append(scoped.authority_version if scoped != null else -1)
		command.scoped_commander_versions.append(owner.authority_version if owner != null else -1)
	command.preserve_queue_order = commander != null
	if commander != null:
		command.authority_commander_id = commander.definition.definition_id
		command.expected_commander_version = commander.authority_version
	if card != null:
		command.authority_card_id = card.definition.definition_id
		command.expected_card_version = card.authority_version


static func prepare_batch(world: SimulationWorld, commands: Array[GameCommand]) -> void:
	if not enabled(world): return
	# Validate player claims against the tick's hard constraints before revoking
	# old AI. An accepted attack that has lost visibility cannot steal control.
	for command in commands:
		if not is_player_claim(world, command): continue
		var result := world.validate_command(command)
		if not result.is_accepted(): command.application_rejection = result.reason
	for command in commands:
		if command.application_rejection != CommandValidationResult.Reason.NONE or command.issuer_kind != GameCommand.IssuerKind.PLAYER: continue
		var commander := commander_for(world, command)
		var card := card_for(world, command)
		if command is CommanderOrderCommand and commander != null:
			commander.authority_version += 1
			for id in commander.subordinate_unit_card_ids: (world.unit_cards[id] as UnitCardState).authority_version += 1
		elif card != null and (world._is_direct_player_order(command) or command is UnitCardControlCommand):
			card.authority_version += 1
		elif is_graph_retreat(command):
			for owner in graph_commanders(world, command):
				owner.authority_version += 1
				for id in owner.subordinate_unit_card_ids: (world.unit_cards[id] as UnitCardState).authority_version += 1


static func is_graph_retreat(command: GameCommand) -> bool:
	return command is CommanderCardTaskCommand and command.issuer_kind == GameCommand.IssuerKind.PLAYER and command.action == CommanderCardTaskCommand.Action.RETREAT


static func is_player_claim(world: SimulationWorld, command: GameCommand) -> bool:
	return command.issuer_kind == GameCommand.IssuerKind.PLAYER and (command is CommanderOrderCommand or command is UnitCardControlCommand or world._is_direct_player_order(command) or is_graph_retreat(command))


static func graph_commanders(world: SimulationWorld, command: GameCommand) -> Array[CommanderState]:
	var result: Array[CommanderState] = []
	for id in command.scoped_card_ids:
		var card := world.unit_cards.get(id) as UnitCardState
		var owner := world.commanders.get(card.commander_definition_id) as CommanderState if card != null else null
		if owner != null and not result.has(owner): result.append(owner)
	result.sort_custom(func(a: CommanderState, b: CommanderState) -> bool: return String(a.definition.definition_id) < String(b.definition.definition_id))
	return result


static func apply_graph_retreat(world: SimulationWorld, command: GameCommand) -> bool:
	if not enabled(world) or not is_graph_retreat(command): return false
	for owner in graph_commanders(world, command):
		var retreat := CommanderOrderCommand.new(command.command_id, command.issuer_id, command.issued_tick,
			owner.definition.definition_id, CommanderOrderCommand.OrderKind.SET_POSTURE, Vector2.ZERO, &"", CommanderState.Posture.DISENGAGE)
		var result := world.validate_command(retreat)
		if result.is_accepted(): apply_commander(world, retreat)
		else: world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.COMMAND_REJECTED, 0, "commander=%s;command=%d;%s" % [owner.definition.definition_id, command.command_id, result.describe()]))
	return true


static func apply_commander(world: SimulationWorld, command: CommanderOrderCommand) -> bool:
	if not enabled(world) or command.issuer_kind != GameCommand.IssuerKind.PLAYER: return false
	var commander := world.commanders[command.commander_id] as CommanderState
	var had_player_goal := commander.intent_mode != Mode.AUTONOMOUS
	world.commander_task_graph_system.cancel_commander(world, command.commander_id)
	world._cancel_commander_intent(commander)
	for id in commander.subordinate_unit_card_ids:
		world._release_card_for_commander(world.unit_cards[id], "PLAYER_INTENT_REPLACED")
		(world.unit_cards[id] as UnitCardState).commander_hold_position = Vector2(INF, INF)
	commander.player_command_id = command.command_id
	commander.growth_recovering = false
	commander.growth_resume_route.clear()
	commander.growth_resume_region_id = &""
	commander.last_growth_order_tick = world.current_tick
	var mode := resolve_mode(commander, command)
	commander.intent_mode = mode as CommanderState.IntentMode
	commander.autonomous_growth = mode == Mode.AUTONOMOUS
	commander.posture = command.posture if command.order_kind in [CommanderOrderCommand.OrderKind.SET_POSTURE, CommanderOrderCommand.OrderKind.ASSIGN_INTENT] or command.apply_requested_posture else CommanderState.Posture.BALANCED
	if mode == Mode.FORCE_ATTACK: commander.posture = CommanderState.Posture.AGGRESSIVE
	if mode == Mode.HOLD: commander.posture = CommanderState.Posture.HOLD
	if mode == Mode.RETREAT: commander.posture = CommanderState.Posture.DISENGAGE
	var target := command.target_position
	var region := command.target_region_id
	var route := command.route_points.duplicate()
	if command.order_kind == CommanderOrderCommand.OrderKind.SET_POSTURE:
		target = world._commander_disengage_position(commander) if mode == Mode.RETREAT else commander.player_target_position if had_player_goal else commander.target_position
		region = &"" if mode == Mode.RETREAT else commander.player_target_region_id if had_player_goal else commander.target_region_id
		route = PackedVector2Array() if mode == Mode.RETREAT else commander.player_route.duplicate() if had_player_goal else commander.planned_route.duplicate()
	commander.deployment_goal = target if command.use_legion_deployment else Vector2(INF, INF)
	commander.deployment_facing = command.deployment_facing if command.use_legion_deployment else Vector2.ZERO
	commander.player_target_position = target
	commander.player_target_region_id = region
	commander.player_route = route.duplicate()
	commander.legion_execution_authority = CommanderState.LegionExecutionAuthority.PLAYER_INTENT if mode == Mode.FORCE_ATTACK or command.order_kind == CommanderOrderCommand.OrderKind.ASSIGN_INTENT else CommanderState.LegionExecutionAuthority.PLAYER_MOVEMENT
	if mode in [Mode.HOLD, Mode.AUTONOMOUS]:
		for id in commander.subordinate_unit_card_ids:
			var card := world.unit_cards[id] as UnitCardState
			var formation := world.formations.get(card.formation_id) as FormationState
			if formation != null:
				card.commander_hold_position = formation.anchor_position
				commander.target_position = formation.anchor_position
				commander.player_target_position = formation.anchor_position
		commander.player_target_region_id = &""
		commander.player_route.clear()
		commander.target_region_id = &""
		commander.planned_route.clear()
		commander.deployment_goal = Vector2(INF, INF)
		world._reissue_commander_tasks_at_current_positions(commander)
		commander.intent_receipt = Receipt.CANCELLED if mode == Mode.HOLD and command.order_kind == CommanderOrderCommand.OrderKind.CANCEL_INTENT else Receipt.RETURNED if mode == Mode.AUTONOMOUS else Receipt.EXECUTING
		commander.legion_execution_authority = CommanderState.LegionExecutionAuthority.AUTONOMOUS if mode == Mode.AUTONOMOUS else CommanderState.LegionExecutionAuthority.STOPPED
		if mode == Mode.AUTONOMOUS: commander.posture = CommanderState.Posture.BALANCED
	else:
		if command.order_kind == CommanderOrderCommand.OrderKind.ASSIGN_INTENT:
			commander.set_high_level_intent(command.intent_id, region, command.main_axis_region_id, command.reserve_policy, world.current_tick)
		world._assign_commander_objective(commander, target, region, route)
		commander.intent_receipt = Receipt.EXECUTING
	world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.UNIT_CONTROL_CHANGED, 0,
		"commander=%s;command=%d;mode=%s;version=%d;receipt=%s" % [command.commander_id, command.command_id, Mode.keys()[mode], commander.authority_version, Receipt.keys()[commander.intent_receipt]]))
	return true


static func forbids_disengagement(world: SimulationWorld, task: TaskState) -> bool:
	if not enabled(world): return false
	var card := world.unit_cards.get(task.unit_card_id) as UnitCardState
	var owner := world.commanders.get(card.commander_definition_id) as CommanderState if card != null else null
	return owner != null and owner.intent_mode in [Mode.FORCE_ATTACK, Mode.HOLD, Mode.RETREAT]


static func retains_target(world: SimulationWorld, task: TaskState) -> bool:
	if not enabled(world): return false
	var card := world.unit_cards.get(task.unit_card_id) as UnitCardState
	var owner := world.commanders.get(card.commander_definition_id) as CommanderState if card != null else null
	return owner != null and owner.intent_mode != Mode.AUTONOMOUS


static func refresh_receipts(world: SimulationWorld) -> void:
	if not enabled(world): return
	for card: UnitCardState in world.unit_cards.values():
		if not card.persistent_manual: continue
		var formation := world.formations.get(card.formation_id) as FormationState
		if formation == null: continue
		if card.player_stopped:
			card.player_order_receipt = Receipt.CANCELLED
		elif card.manual_target_entity_id != 0:
			var knowledge := world.faction_knowledge.get(card.faction_id) as FactionKnowledge
			var contact := knowledge.hostile_contacts.get(card.manual_target_entity_id) as KnowledgeContact if knowledge != null else null
			card.player_order_receipt = Receipt.ACHIEVED if contact != null and not contact.enabled else Receipt.BLOCKED if not world.is_entity_visible_to_faction(card.manual_target_entity_id, card.faction_id) else Receipt.EXECUTING
		else:
			var moving := formation.is_moving
			var stalled := false
			for entity_id in card.member_entity_ids:
				var unit := world.units.get(entity_id) as UnitState
				if unit == null or not unit.enabled: continue
				moving = moving or unit.has_move_target
				stalled = stalled or unit.has_move_target and unit.ticks_without_progress >= 30
			card.player_order_receipt = Receipt.BLOCKED if stalled else Receipt.EXECUTING if moving else Receipt.ACHIEVED
	for commander: CommanderState in world.commanders.values():
		if commander.intent_mode in [Mode.AUTONOMOUS, Mode.HOLD] or commander.legion_regrouping: continue
		var arrived := true
		var blocked := false
		for id in commander.subordinate_unit_card_ids:
			var card := world.unit_cards[id] as UnitCardState
			if card.member_entity_ids.is_empty(): continue
			if card.persistent_manual: arrived = false
			var task := world.tasks.get(card.assigned_task_id) as TaskState
			if task == null: arrived = false; continue
			blocked = blocked or task.lifecycle == TaskState.Lifecycle.BLOCKED
			arrived = arrived and task.phase in [TaskState.Phase.HOLDING, TaskState.Phase.SCOUTING] and not task.has_staged_target
			for entity_id in card.member_entity_ids:
				var unit := world.units.get(entity_id) as UnitState
				if unit != null and unit.enabled: arrived = arrived and not unit.has_move_target
		var region := world.strategic_regions.get(commander.player_target_region_id) as StrategicRegionState
		if region != null: arrived = arrived and region.controller_faction_id == commander.faction_id and not region.contested
		commander.intent_receipt = Receipt.BLOCKED if blocked else Receipt.ACHIEVED if arrived and not commander.growth_recovering else Receipt.EXECUTING


static func reject(reason: CommandValidationResult.Reason) -> CommandValidationResult:
	return CommandValidationResult.new(CommandValidationResult.Status.REJECTED, reason)


static func staff_scope(world: SimulationWorld, command: StaffPlanApprovalCommand) -> Array[StringName]:
	if not command.request.allowed_card_ids.is_empty(): return command.request.allowed_card_ids.duplicate()
	var result: Array[StringName] = []
	for card: UnitCardState in world.unit_cards.values():
		if card.faction_id == command.issuer_id and card.deployment_state == UnitCardState.DeploymentState.DEPLOYED:
			result.append(card.definition.definition_id)
	result.sort()
	return result


static func resolve_mode(commander: CommanderState, command: CommanderOrderCommand) -> int:
	if command.order_kind == CommanderOrderCommand.OrderKind.RETURN_AI: return Mode.AUTONOMOUS
	if command.order_kind == CommanderOrderCommand.OrderKind.CANCEL_INTENT: return Mode.HOLD
	if command.order_kind == CommanderOrderCommand.OrderKind.SET_POSTURE:
		return Mode.RETREAT if command.posture == CommanderState.Posture.DISENGAGE else Mode.HOLD if command.posture == CommanderState.Posture.HOLD else Mode.OBJECTIVE
	if command.requested_intent_mode >= 0: return command.requested_intent_mode
	return Mode.FORCE_ATTACK if commander.intent_mode == Mode.FORCE_ATTACK else Mode.OBJECTIVE
