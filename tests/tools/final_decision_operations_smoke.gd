extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	print("OPS world ready")
	_expect(world.units.size() == 96, "96 initial combatants, 512 capacity")
	# Controlled casualty fixture, then restore via the actual Agent/command/economy pipeline.
	for id in [1, 1001]:
		var unit := world.units[id] as UnitState
		unit.enabled = false
		unit.health = 0
	world._refresh_battle_population()
	for tick in range(35):
		world.advance_tick()
		if tick % 10 == 0: print("OPS tick=",world.current_tick)
	var reinforced := {1: 0, 2: 0}
	for event in world.events:
		if event.kind == SimulationEvent.Kind.UNIT_CARD_REINFORCED:
			if "source=recruitment" in event.detail:
				reinforced[event.entity_id] += 1
	for faction_id in [1, 2]:
		_expect(reinforced[faction_id] > 0, "automatic reinforcement faction %d" % faction_id)
		_expect(world.factions[faction_id].population <= 256, "population capacity faction %d" % faction_id)
	var commander_ids: Array[StringName] = []
	for commander: CommanderState in world.commanders.values():
		if commander.faction_id == 1:
			commander_ids.append(commander.definition.definition_id)
	commander_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for index in range(2):
		var request := StaffPlanRequest.new()
		request.objective_region_id = &"blue_top_high" if index == 0 else &"blue_mid_high"
		request.allowed_card_ids.assign(world.commanders[commander_ids[index]].subordinate_unit_card_ids)
		print("OPS generate=",index)
		var generator := StaffPlanGenerator.new()
		var plans := generator.generate(world.create_faction_snapshot(1), 1, request)
		_expect(plans != null, "generate group %d: %s" % [index, generator.last_rejection_reason])
		if plans == null:
			continue
		var plan := plans.plans[0]
		for assignment in plan.assignments:
			for i in range(1, assignment.route_points.size()):
				_expect(world.logic_grid.is_segment_walkable(assignment.route_points[i - 1], assignment.route_points[i]), "planned route stays on road %s -> %s" % [assignment.route_points[i - 1], assignment.route_points[i]])
		var command := StaffPlanApprovalCommand.new(world.allocate_command_id(), 1, world.current_tick, request, plan.profile_id, plan.fingerprint())
		var receipt := world.submit_command(command)
		_expect(receipt.is_accepted(), "approve group plan: " + receipt.describe())
		world.advance_tick()
	var graphs := world.commander_task_graph_system.create_snapshots(1)
	_expect(graphs.size() == 2, "two independent battlegroup operations coexist")
	if graphs.size() != 2:
		print("OPS_EARLY_FAILURE ", failures)
		quit(1)
		return
	for graph in graphs:
		for node in graph.nodes:
			_expect(world.logic_grid.is_world_position_walkable(node.target_position), "task stage target on road")
	for tick in range(15):
		world.advance_tick()
	_expect(world.commander_task_graph_system.is_running(), "operations execute after approval")
	var preserved_id := world.commander_task_graph_system._operations[1]._graph.graph_id
	var replace_request := StaffPlanRequest.new()
	replace_request.objective_region_id = &"jungle_upper_rear"
	replace_request.allowed_card_ids.assign(world.commanders[commander_ids[0]].subordinate_unit_card_ids)
	var replacement := StaffPlanGenerator.new().generate(world.create_faction_snapshot(1), 1, replace_request)
	_expect(replacement != null, "replacement plan exists")
	if replacement != null:
		var plan := replacement.plans[0]
		var approval := StaffPlanApprovalCommand.new(world.allocate_command_id(), 1, world.current_tick, replace_request, plan.profile_id, plan.fingerprint())
		_expect(world.submit_command(approval).is_accepted(), "replace one group operation")
		world.advance_tick()
		var preserved := false
		for operation in world.commander_task_graph_system._operations:
			preserved = preserved or operation._graph.graph_id == preserved_id and operation.is_running()
		_expect(preserved, "replacement leaves other group running")
	# Finish one actual exploitation stage, then verify authority retains a garrison task.
	var worker := world.commander_task_graph_system._operations[-1]
	var graph := worker._graph
	var exploit: CommanderTaskNodeSnapshot
	for node in graph.nodes:
		if node.phase == CommanderTaskStageDefinition.Phase.EXPLOIT:
			exploit = node
			break
	var card := world.unit_cards[exploit.card_id] as UnitCardState
	var commander := world.commanders[exploit.commander_id] as CommanderState
	var formation := world.formations[card.formation_id] as FormationState
	formation.anchor_position = exploit.target_position
	formation.is_moving = false
	for id in card.member_entity_ids:
		world.units[id].position = exploit.target_position
		world.units[id].has_move_target = false
		world.units[id].following_formation = false
	var task := world._assign_unit_card_task(commander, card, exploit.target_position, PackedVector2Array(), TaskState.Kind.DEFEND_AREA)
	exploit.task_id = task.task_id
	exploit.lifecycle = CommanderTaskNodeSnapshot.Lifecycle.ACTIVE
	exploit.started_tick = world.current_tick
	exploit.progress_ticks = exploit.dwell_ticks - 1
	for node in graph.nodes:
		if node.card_id == card.definition.definition_id and node != exploit and node.phase != CommanderTaskStageDefinition.Phase.RETREAT:
			node.lifecycle = CommanderTaskNodeSnapshot.Lifecycle.COMPLETED
	world.strategic_regions[graph.approved_plan.objective_region_id].controller_faction_id = 1
	world.strategic_regions[graph.approved_plan.objective_region_id].contested = false
	var finish := CommanderCardTaskCommand.new(world.allocate_command_id(), 1, GameCommand.IssuerKind.AGENT, world.current_tick, graph.graph_id, exploit.node_id, CommanderCardTaskCommand.Action.COMPLETE)
	finish.agent_id = commander.agent_id
	finish.task_id = task.task_id
	_expect(world.submit_command(finish).is_accepted(), "complete controlled exploit fixture through command pipeline")
	world.advance_tick()
	_expect(card.control_state == UnitCardState.ControlState.AGENT_ASSIGNED and card.assigned_task_id != 0 and card.assigned_task_id != task.task_id, "completed operation hands card to persistent garrison")
	var markers := MinimapMarkerProjector.new().project(world.create_faction_snapshot(1), [])
	_expect(markers.size() < 40, "minimap aggregates 256 friendly units")
	var headquarters := 0
	for marker in markers:
		if marker.kind == &"headquarters":
			headquarters += 1
	_expect(headquarters > 0, "minimap headquarters marker")
	_expect(ArmyRosterStore.campaign_record_path_for_session("test", &"final_decision") != ArmyRosterStore.campaign_record_path_for_session("test", &"grey_ridge"), "final roster isolated")
	var reserve_request := StaffPlanRequest.new()
	reserve_request.objective_region_id = &"blue_mid_outer"
	var reserve_set := StaffPlanGenerator.new().generate(world.create_faction_snapshot(1), 1, reserve_request)
	var reserve_plan: StaffCourseOfAction
	if reserve_set != null:
		for option in reserve_set.plans:
			if option.profile_id == &"reconnaissance_first": reserve_plan = option
	_expect(reserve_plan != null and reserve_plan.reserve_card_ids.size() == 8, "recon plan holds two complete combined-arms groups")
	if reserve_plan != null:
		var approval := StaffPlanApprovalCommand.new(world.allocate_command_id(), 1, world.current_tick, reserve_request, reserve_plan.profile_id, reserve_plan.fingerprint())
		_expect(world.submit_command(approval).is_accepted(), "approve combined-arms reserve plan")
		world.advance_tick()
		var reserve_graph := world.commander_task_graph_system._graph
		_expect(reserve_graph.adaptation_policy.max_reserve_commits == 8, "every reserved detachment can reinforce")
		for node in reserve_graph.nodes:
			if node.phase == CommanderTaskStageDefinition.Phase.RECON and node.is_required:
				node.lifecycle = CommanderTaskNodeSnapshot.Lifecycle.COMPLETED
		for tick in range(250): world.advance_tick()
		_expect(reserve_graph.reserve_card_ids.is_empty(), "autonomous reserve release commits complete groups")
	for failure in failures:
		push_error(failure)
	print("FINAL_DECISION_OPERATIONS tick=%d graphs=%d auto_reinforced=%s markers=%d failures=%s" % [world.current_tick, graphs.size(), reinforced, markers.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failures.append(detail)
		push_error(detail)
