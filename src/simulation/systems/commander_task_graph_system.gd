class_name CommanderTaskGraphSystem
extends RefCounted

const Phase := CommanderTaskStageDefinition.Phase
const Life := CommanderTaskNodeSnapshot.Lifecycle
const Action := CommanderCardTaskCommand.Action

var _coordinator := true
var _operations: Array[CommanderTaskGraphSystem] = []
var _graph: CommanderTaskGraphSnapshot
var _agent := CommanderTaskGraphAgent.new()
var _installation_sequence: int = 0
var _proposal_snapshot: WorldSnapshot
var _adaptation := CommanderAdaptationSystem.new()


func install(world: SimulationWorld, plan: StaffCourseOfAction, supply_limit: int = 0) -> void:
	if _coordinator:
		var worker := CommanderTaskGraphSystem.new()
		worker._coordinator = false
		worker._installation_sequence = _installation_sequence
		worker.install(world, plan, supply_limit)
		if worker._graph == null:
			return
		_installation_sequence = worker._installation_sequence
		var commanders: Array[StringName] = []
		for assignment in plan.assignments:
			if not commanders.has(assignment.commander_id):
				commanders.append(assignment.commander_id)
		for card_id in plan.reserve_card_ids:
			var card := world.unit_cards.get(card_id) as UnitCardState
			if card != null and not commanders.has(card.commander_definition_id):
				commanders.append(card.commander_definition_id)
		for operation in _operations:
			for id in commanders:
				operation.cancel_commander(world, id)
		_operations = _operations.filter(func(operation: CommanderTaskGraphSystem) -> bool: return operation.is_running() or not operation._graph.reserve_card_ids.is_empty())
		_operations.append(worker)
		_graph = worker._graph
		return
	var legal_view := world.create_faction_snapshot(SimulationWorld.LOCAL_PLAYER_ID)
	var legal_navigator: GridPathfinder
	if plan.coordination != StaffPlanRequest.Coordination.INDEPENDENT:
		legal_navigator = StaffPlanGenerator.navigation_for_snapshot(legal_view)
	var graph := CommanderTaskGraphBuilder.new().build(legal_view, plan, CommanderTaskGraphBuilder.DEFAULT_DEFINITION, legal_navigator)
	if graph == null:
		return
	_installation_sequence += 1
	graph.graph_id = StringName("%s:%d" % [graph.graph_id, _installation_sequence])
	if _graph != null:
		for node in _graph.nodes:
			_finish_task(world, node, false)
	_graph = graph
	if world.battle_definition.map_definition != null:
		_graph.adaptation_policy.max_reserve_commits = plan.reserve_card_ids.size()
	_graph.adaptation_budget_remaining = maxi(0, supply_limit - plan.supply_cost)
	_graph.reinforcement_supply_cost = world.get_support_cost(SupportOrderCommand.SupportKind.FIELD_REINFORCEMENT)
	_graph.next_adaptation_tick = world.current_tick + _graph.adaptation_policy.interval_ticks
	var held_ids := _graph.reserve_card_ids.duplicate()
	for assignment in _graph.approved_plan.assignments:
		held_ids.append(assignment.card_id)
	for card_id in held_ids:
		var owned_card := world.unit_cards.get(card_id) as UnitCardState
		var owner := world.commanders.get(owned_card.commander_definition_id) as CommanderState if owned_card!=null else null
		if owner!=null and world.battle_definition.growth_mode:
			# A successfully installed plan replaces the execution source. Its
			# termination does not silently reactivate retained old intent text.
			owner.legion_execution_authority=CommanderState.LegionExecutionAuthority.STAFF_PLAN
		if plan.coordination != StaffPlanRequest.Coordination.INDEPENDENT:
			var held_card := world.unit_cards.get(card_id) as UnitCardState
			if held_card != null:
				var held_commander := world.commanders.get(held_card.commander_definition_id) as CommanderState
				if held_commander != null: held_commander.autonomous_growth = false
		var task := world._task_for_unit_card(card_id)
		if task != null:
			var hold := CommanderTaskNodeSnapshot.new()
			hold.card_id = card_id
			hold.commander_id = (world.unit_cards[card_id] as UnitCardState).commander_definition_id
			hold.task_id = task.task_id
			_finish_task(world, hold, false)
	world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.COMMANDER_GRAPH_CHANGED, 0,
		"graph=%s;state=installed;plan=%s" % [_graph.graph_id, plan.plan_id]))


func create_snapshots(observer: int) -> Array[CommanderTaskGraphSnapshot]:
	if _coordinator:
		var snapshots: Array[CommanderTaskGraphSnapshot] = []
		for operation in _operations:
			snapshots.append_array(operation.create_snapshots(observer))
		return snapshots
	var result: Array[CommanderTaskGraphSnapshot] = []
	if _graph != null and observer in [0, _graph.faction_id]:
		result.append(_graph.duplicate_value())
	return result


func owns_card(card_id: StringName) -> bool:
	if _coordinator:
		return _operations.any(func(operation: CommanderTaskGraphSystem) -> bool: return operation.owns_card(card_id))
	if _graph == null:
		return false
	if _graph.reserve_card_ids.has(card_id):
		return true
	for node in _graph.nodes:
		if node.phase == Phase.RETREAT and not _graph.retreat_requested:
			continue
		if node.card_id == card_id and node.lifecycle not in [Life.CANCELLED, Life.FAILED, Life.COMPLETED, Life.SKIPPED]:
			return true
	return false


func is_running() -> bool:
	if _coordinator:
		return _operations.any(func(operation: CommanderTaskGraphSystem) -> bool: return operation.is_running())
	if _graph == null:
		return false
	for node in _graph.nodes:
		if node.phase == Phase.RETREAT and not _graph.retreat_requested:
			continue
		if node.lifecycle not in [Life.COMPLETED, Life.SKIPPED, Life.FAILED, Life.CANCELLED]:
			return true
	return false


func allows_coordination(card_id: StringName) -> bool:
	if _coordinator:
		return _operations.all(func(operation: CommanderTaskGraphSystem) -> bool: return operation.allows_coordination(card_id))
	if not owns_card(card_id):
		return true
	for node in _graph.nodes:
		if node.card_id == card_id and node.lifecycle == Life.ACTIVE and node.phase in [Phase.ENGAGE, Phase.EXPLOIT]:
			return true
	return false


func allows_legion_local_task(world: SimulationWorld, card_id: StringName) -> bool:
	if _coordinator:
		return _operations.any(func(operation: CommanderTaskGraphSystem) -> bool: return operation.allows_legion_local_task(world,card_id))
	if _graph==null or _graph.retreat_requested or _graph.reserve_card_ids.has(card_id): return false
	var card := world.unit_cards.get(card_id) as UnitCardState
	if card==null or not card.uses_legion_slots() or card.player_stopped: return false
	var task := world.tasks.get(card.assigned_task_id) as TaskState
	if task==null or task.unit_card_id!=card_id or task.faction_id!=_graph.faction_id or task.lifecycle!=TaskState.Lifecycle.EXECUTING or world.current_tick<task.activation_tick: return false
	if task.phase in [TaskState.Phase.RETREATING,TaskState.Phase.EVADING,TaskState.Phase.DONE]: return false
	for node in _graph.nodes:
		if node.card_id==card_id and node.commander_id==card.commander_definition_id and node.lifecycle==Life.ACTIVE and node.phase in [Phase.ENGAGE,Phase.EXPLOIT] and node.task_id==task.task_id:
			return true
	return false


func owns_commander(commander: CommanderState) -> bool:
	if commander == null:
		return false
	for card_id in commander.subordinate_unit_card_ids:
		if owns_card(card_id):
			return true
	return false


func cooperation_cards(commander_id: StringName) -> Array[StringName]:
	if _coordinator:
		for operation in _operations:
			var ids := operation.cooperation_cards(commander_id)
			if not ids.is_empty(): return ids
		return []
	return CoalitionTactics.shared_cards(_graph, commander_id)


func cancel_commander(world: SimulationWorld, commander_id: StringName) -> void:
	if _coordinator:
		for operation in _operations:
			operation.cancel_commander(world, commander_id)
		return
	if _graph == null:
		return
	for node in _graph.nodes:
		if node.commander_id == commander_id:
			_finish_task(world, node, false)
			_set_state(world, node, Life.CANCELLED, &"COMMANDER_GRAPH_PLAYER_ORDER")
	var commander := world.commanders.get(commander_id) as CommanderState
	if commander != null:
		for card_id in commander.subordinate_unit_card_ids:
			_graph.reserve_card_ids.erase(card_id)


func supersede_card_order(world: SimulationWorld, card_id: StringName) -> void:
	if _coordinator:
		for operation in _operations: operation.supersede_card_order(world,card_id)
		return
	if _graph==null: return
	_graph.reserve_card_ids.erase(card_id)
	for node in _graph.nodes:
		if node.card_id!=card_id or node.lifecycle in [Life.COMPLETED,Life.CANCELLED,Life.FAILED,Life.SKIPPED]: continue
		var task := world.tasks.get(node.task_id) as TaskState
		if task!=null and task.lifecycle not in [TaskState.Lifecycle.COMPLETED,TaskState.Lifecycle.CANCELLED,TaskState.Lifecycle.FAILED]:
			task.set_lifecycle(TaskState.Lifecycle.CANCELLED,world.current_tick)
			task.set_phase(TaskState.Phase.DONE,world.current_tick,"Replaced by accepted player order")
		_set_state(world,node,Life.CANCELLED,&"COMMANDER_GRAPH_PLAYER_ORDER")


func authority_cards(command: CommanderCardTaskCommand) -> Array[StringName]:
	if _coordinator:
		for operation in _operations:
			if operation._graph.graph_id == command.graph_id: return operation.authority_cards(command)
		return []
	if _graph == null or _graph.graph_id != command.graph_id: return []
	var node := _graph.get_node(command.node_id)
	if node != null: return [node.card_id]
	var ids: Array[StringName] = _graph.reserve_card_ids.duplicate()
	for assignment in _graph.approved_plan.assignments:
		if not ids.has(assignment.card_id): ids.append(assignment.card_id)
	ids.sort()
	return ids


func propose_commands(world: SimulationWorld) -> void:
	if _coordinator:
		for operation in _operations:
			operation.propose_commands(world)
		return
	if _graph == null or not is_running():
		return
	if _graph.approved_plan.coordination == StaffPlanRequest.Coordination.JOINT_ATTACK:
		var manual := false
		for assignment in _graph.approved_plan.assignments:
			var participant := world.unit_cards.get(assignment.card_id) as UnitCardState
			if participant != null and participant.control_state in [UnitCardState.ControlState.PLAYER_CONTROLLED, UnitCardState.ControlState.PLAYER_OVERRIDDEN, UnitCardState.ControlState.RETURNING]: manual = true
		if manual and _graph.coordination_paused_since_tick < 0: _graph.coordination_paused_since_tick = world.current_tick
		elif not manual and _graph.coordination_paused_since_tick >= 0:
			_graph.coordination_paused_ticks += world.current_tick - _graph.coordination_paused_since_tick
			_graph.coordination_paused_since_tick = -1
	var snapshot := world.create_commander_task_snapshot(_graph.faction_id)
	# Submission only enqueues commands; all proposals observe the same world state.
	_proposal_snapshot = snapshot
	for adjustment in _adaptation.agent.propose(snapshot, _graph.duplicate_value()):
		adjustment.command_id = world.allocate_command_id()
		if world.submit_command(adjustment).is_accepted():
			_proposal_snapshot = null
			return
	for command in _agent.propose(snapshot, _graph.duplicate_value()):
		command.command_id = world.allocate_command_id()
		var result := world.submit_command(command)
		if not result.is_accepted() and command.action == Action.START and result.reason not in [CommandValidationResult.Reason.TASK_CONFLICT, CommandValidationResult.Reason.AGENT_NOT_AUTHORIZED]:
			command.command_id = world.allocate_command_id()
			command.action = Action.BLOCK
			world.submit_command(command)
	_proposal_snapshot = null


func validate(world: SimulationWorld, command: CommanderCardTaskCommand) -> CommandValidationResult:
	if _coordinator:
		for operation in _operations:
			if operation._graph.graph_id == command.graph_id:
				return operation.validate(world, command)
		return _reject(CommandValidationResult.Reason.INVALID_TASK)
	if _graph == null or command.graph_id != _graph.graph_id:
		return _reject(CommandValidationResult.Reason.INVALID_TASK)
	if command.issuer_id != _graph.faction_id or command.issuer_id != SimulationWorld.LOCAL_PLAYER_ID:
		return _reject(CommandValidationResult.Reason.NOT_CONTROLLER)
	if command.action >= Action.AUTO_RETREAT:
		return _adaptation.validate(world, _graph, command)
	if command.action == Action.RETREAT:
		if _graph.retreat_requested:
			return _reject(CommandValidationResult.Reason.TASK_CONFLICT)
		return _reject(CommandValidationResult.Reason.AGENT_NOT_AUTHORIZED) if command.issuer_kind != GameCommand.IssuerKind.PLAYER else CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED)
	var node := _graph.get_node(command.node_id)
	if node == null:
		return _reject(CommandValidationResult.Reason.INVALID_TASK)
	var commander := world.commanders.get(node.commander_id) as CommanderState
	if commander == null or command.issuer_kind == GameCommand.IssuerKind.AGENT and command.agent_id != commander.agent_id:
		return _reject(CommandValidationResult.Reason.AGENT_NOT_AUTHORIZED)
	if not world._agent_authorization_allows(command):
		return _reject(CommandValidationResult.Reason.AGENT_NOT_AUTHORIZED)
	var snapshot := _proposal_snapshot if _proposal_snapshot != null else world.create_commander_task_snapshot(command.issuer_id)
	var expected := _agent.expected_action(snapshot, _graph, node)
	if command.action == Action.BLOCK and expected == Action.START and not _validate_start(world, node).is_accepted():
		return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED)
	if expected != command.action:
		return _reject(CommandValidationResult.Reason.TASK_CONFLICT)
	if command.action == Action.START:
		return _validate_start(world, node)
	return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED)


func _validate_start(world: SimulationWorld, node: CommanderTaskNodeSnapshot) -> CommandValidationResult:
	var card := world.unit_cards.get(node.card_id) as UnitCardState
	if card == null:
		return _reject(CommandValidationResult.Reason.INVALID_TARGET)
	if node.requires_deployment and card.deployment_state == UnitCardState.DeploymentState.RESERVE:
		return world.validate_command(_deployment(world, node))
	var formation := world.formations.get(card.formation_id) as FormationState
	if formation == null or card.deployment_state != UnitCardState.DeploymentState.DEPLOYED:
		return _reject(CommandValidationResult.Reason.INVALID_DEPLOYMENT_STATE)
	if not world.find_formation_deployment_position(formation, node.target_position, node.arrival_radius, node.route_points).is_finite():
		return _reject(CommandValidationResult.Reason.PATH_UNAVAILABLE)
	return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED)


func apply(world: SimulationWorld, command: CommanderCardTaskCommand) -> void:
	if _coordinator:
		for operation in _operations:
			if operation._graph.graph_id == command.graph_id:
				operation.apply(world, command)
				return
		return
	var validation := validate(world, command)
	if not validation.is_accepted():
		world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.COMMANDER_GRAPH_CHANGED, 0,
			"graph=%s;node=%s;state=rejected;reason=%s" % [command.graph_id, command.node_id, validation.describe()]))
		return
	if command.action >= Action.AUTO_RETREAT:
		_adaptation.apply(world, self, _graph, command)
		return
	if command.action == Action.RETREAT:
		_graph.retreat_requested = true
		world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.COMMANDER_GRAPH_CHANGED, 0,
			"graph=%s;state=retreat_requested;reason=COMMANDER_GRAPH_PLAYER_RETREAT;command=%d" % [_graph.graph_id, command.command_id]))
		return
	var node := _graph.get_node(command.node_id)
	match command.action:
		Action.START:
			var card := world.unit_cards[node.card_id] as UnitCardState
			if node.started_tick < 0:
				node.started_tick = world.current_tick
			if node.requires_deployment and card.deployment_state == UnitCardState.DeploymentState.RESERVE:
				var deploy := _deployment(world, node)
				deploy.command_id = world.allocate_command_id()
				var result := world.submit_command(deploy)
				if not result.is_accepted():
					_set_state(world, node, Life.BLOCKED, StringName("REASON_%s" % CommandValidationResult.Reason.keys()[result.reason]))
					return
			else:
				var commander := world.commanders[node.commander_id] as CommanderState
				var route := node.route_points
				if _graph.approved_plan.coordination != StaffPlanRequest.Coordination.INDEPENDENT:
					if node.phase in [Phase.ENGAGE, Phase.EXPLOIT]:
						route = PackedVector2Array()
				var task := world._assign_unit_card_task(commander, card, node.target_position, route, TaskState.Kind.DEFEND_AREA)
				if task == null:
					_set_state(world, node, Life.BLOCKED, &"COMMANDER_GRAPH_NO_TASK")
					return
				task.target_radius = node.arrival_radius
				task.has_staged_target = false
				task.activation_tick = world.current_tick
				task.requires_observed_contact = false
				node.task_id = task.task_id
				if not commander.current_task_ids.has(task.task_id):
					commander.current_task_ids.append(task.task_id)
			_set_state(world, node, Life.ACTIVE, &"COMMANDER_GRAPH_EXECUTING")
		Action.PROGRESS:
			node.progress_ticks += 1
		Action.RESET_PROGRESS:
			node.progress_ticks = 0
		Action.COMPLETE, Action.SKIP:
			_finish_task(world, node, true)
			if command.action == Action.COMPLETE and node.phase == Phase.EXPLOIT and world.battle_definition.map_definition != null:
				var commander := world.commanders.get(node.commander_id) as CommanderState
				var card := world.unit_cards.get(node.card_id) as UnitCardState
				if commander != null and card != null and card.control_state == UnitCardState.ControlState.UNASSIGNED:
					var garrison := world._assign_unit_card_task(commander, card, node.target_position, PackedVector2Array(), TaskState.Kind.DEFEND_AREA)
					if garrison != null:
						garrison.activation_tick = world.current_tick
						garrison.requires_observed_contact = false
						commander.current_task_ids.append(garrison.task_id)
			_set_state(world, node, Life.COMPLETED if command.action == Action.COMPLETE else Life.SKIPPED,
				&"COMMANDER_GRAPH_COMPLETED" if command.action == Action.COMPLETE else &"COMMANDER_GRAPH_NOT_REQUIRED")
		Action.PAUSE:
			node.progress_ticks = 0
			node.paused_tick = world.current_tick
			_set_state(world, node, Life.PAUSED, &"COMMANDER_GRAPH_PLAYER_CONTROL")
		Action.RESUME:
			var resume_reason: StringName = &"COMMANDER_GRAPH_DEPENDENCY_READY" if node.lifecycle == Life.BLOCKED else &"COMMANDER_GRAPH_CONTROL_RETURNED"
			if node.started_tick >= 0 and node.paused_tick >= 0:
				node.paused_duration_ticks += world.current_tick - node.paused_tick
			node.paused_tick = -1
			_set_state(world, node, Life.ACTIVE if node.started_tick >= 0 else Life.WAITING, resume_reason)
		Action.BLOCK, Action.FAIL, Action.CANCEL:
			var snapshot := world.create_commander_task_snapshot(_graph.faction_id)
			var reason := _agent.transition_reason(snapshot, _graph, node, command.action)
			if command.action == Action.BLOCK and _agent.expected_action(snapshot, _graph, node) == Action.START:
				reason = StringName("REASON_%s" % CommandValidationResult.Reason.keys()[_validate_start(world, node).reason])
			_finish_task(world, node, false)
			_set_state(world, node, Life.BLOCKED if command.action == Action.BLOCK else (Life.FAILED if command.action == Action.FAIL else Life.CANCELLED),
				reason)


func _deployment(world: SimulationWorld, node: CommanderTaskNodeSnapshot) -> DeployUnitCardCommand:
	var retreat: CommanderTaskNodeSnapshot
	for candidate in _graph.nodes:
		if candidate.card_id == node.card_id and candidate.phase == Phase.RETREAT:
			retreat = candidate
	var deploy := DeployUnitCardCommand.new(0, _graph.faction_id, GameCommand.IssuerKind.AGENT, world.current_tick,
		node.card_id, retreat.target_position, node.commander_id)
	deploy.agent_id = (world.commanders[node.commander_id] as CommanderState).agent_id
	deploy.source_graph_id = _graph.graph_id
	return deploy


func validate_deployment(world: SimulationWorld, command: DeployUnitCardCommand) -> CommandValidationResult:
	if _coordinator:
		for operation in _operations:
			if operation._graph.graph_id == command.source_graph_id:
				return operation.validate_deployment(world, command)
		return _reject(CommandValidationResult.Reason.INVALID_TASK)
	if _graph == null or command.source_graph_id != _graph.graph_id or _graph.retreat_requested:
		return _reject(CommandValidationResult.Reason.INVALID_TASK)
	for node in _graph.nodes:
		if node.card_id == command.unit_card_id and node.phase == Phase.MUSTER and node.requires_deployment and node.lifecycle in [Life.WAITING, Life.ACTIVE]:
			var card := world.unit_cards.get(node.card_id) as UnitCardState
			if card == null or card.effective_supply_cost() > node.supply_cost:
				return _reject(CommandValidationResult.Reason.INSUFFICIENT_SUPPLY)
			return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED)
	return _reject(CommandValidationResult.Reason.TASK_CONFLICT)


func reject_deployment(world: SimulationWorld, command: DeployUnitCardCommand, reason: CommandValidationResult.Reason) -> void:
	if _coordinator:
		for operation in _operations:
			if operation._graph.graph_id == command.source_graph_id:
				operation.reject_deployment(world, command, reason)
		return
	if _graph == null or _graph.graph_id != command.source_graph_id:
		return
	for node in _graph.nodes:
		if node.card_id == command.unit_card_id and node.phase == Phase.MUSTER and node.lifecycle == Life.ACTIVE:
			_set_state(world, node, Life.BLOCKED, StringName("REASON_%s" % CommandValidationResult.Reason.keys()[reason]))


func _finish_task(world: SimulationWorld, node: CommanderTaskNodeSnapshot, completed: bool) -> void:
	var task := world.tasks.get(node.task_id) as TaskState
	if task == null or task.lifecycle in [TaskState.Lifecycle.COMPLETED, TaskState.Lifecycle.CANCELLED, TaskState.Lifecycle.FAILED]:
		return
	var card := world.unit_cards.get(node.card_id) as UnitCardState
	if card == null or card.assigned_task_id != node.task_id and card.return_task_id != node.task_id:
		return
	var manually_controlled := card.control_state in [UnitCardState.ControlState.PLAYER_OVERRIDDEN, UnitCardState.ControlState.RETURNING]
	if not manually_controlled:
		world._stop_task_formation(task)
	task.set_lifecycle(TaskState.Lifecycle.COMPLETED if completed else TaskState.Lifecycle.CANCELLED, world.current_tick)
	task.set_phase(TaskState.Phase.DONE, world.current_tick, "Commander graph stage finished")
	if completed:
		task.progress_current = task.progress_target
	world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.TASK_STATE_CHANGED, task.task_id,
		"%s:DONE:COMMANDER_GRAPH" % TaskState.Lifecycle.keys()[task.lifecycle]))
	var commander := world.commanders.get(node.commander_id) as CommanderState
	if commander != null:
		commander.current_task_ids.erase(task.task_id)
	if manually_controlled:
		return
	world.release_task_participants(task)
	card.assigned_task_id = 0
	card.assigned_agent_id = 0
	card.control_state = UnitCardState.ControlState.UNASSIGNED


func _set_state(world: SimulationWorld, node: CommanderTaskNodeSnapshot, lifecycle: CommanderTaskNodeSnapshot.Lifecycle, reason: StringName) -> void:
	if node.lifecycle == lifecycle and node.reason_key == reason:
		return
	node.lifecycle = lifecycle
	node.reason_key = reason
	node.changed_tick = world.current_tick
	world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.COMMANDER_GRAPH_CHANGED, node.task_id,
		"graph=%s;node=%s;phase=%s;state=%s;reason=%s" % [_graph.graph_id, node.node_id, Phase.keys()[node.phase], Life.keys()[lifecycle], reason]))


func _reject(reason: CommandValidationResult.Reason) -> CommandValidationResult:
	return CommandValidationResult.new(CommandValidationResult.Status.REJECTED, reason)

func is_retreating_card(card_id: StringName) -> bool:
	if _coordinator:
		for operation in _operations:
			if operation.is_retreating_card(card_id): return true
		return false
	if _graph == null or not _graph.retreat_requested: return false
	for node in _graph.nodes:
		if node.card_id == card_id and node.phase == Phase.RETREAT and node.lifecycle not in [Life.COMPLETED, Life.SKIPPED, Life.CANCELLED, Life.FAILED]: return true
	return false
