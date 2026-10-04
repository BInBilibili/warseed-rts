extends "res://tests/tools/combined21_rules.gd"

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--contested"):
		_run_operation(Mode.JOINT_ATTACK,true)
	else:
		for mode in [Mode.JOINT_ATTACK, Mode.MUTUAL_SUPPORT]: _run_operation(mode)
	for failure in failures: push_error(failure)
	print("COMBINED21_OPERATION failures=",failures)
	quit(0 if failures.is_empty() else 1)

func _run_operation(mode: int, contested: bool = false) -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.command_queue.drain()
	world.agents.clear()
	for faction: FactionState in world.factions.values(): faction.supply = 0
	for commander: CommanderState in world.commanders.values(): commander.last_growth_order_tick = 100000
	var objective := world.strategic_regions[&"blue_mid_high"] as StrategicRegionState
	var travel := world.pathfinder.find_path(world.battle_definition.player_headquarters_position+Vector2(0,-256),objective.position)
	var origin := CommanderTaskGraphBuilder.new()._point_along_route(travel,0.7)
	if mode == Mode.MUTUAL_SUPPORT: objective.controller_faction_id = 1
	var request := StaffPlanRequest.new()
	request.objective_region_id = objective.region_id
	request.coordination = mode as StaffPlanRequest.Coordination
	for card: UnitCardState in world.unit_cards.values():
		var selected := card.commander_definition_id in [&"bai_jiuyang", &"di_tian"]
		if selected:
			request.allowed_card_ids.append(card.definition.definition_id)
			var formation := world.formations[card.formation_id] as FormationState
			formation.anchor_position = origin
			formation.is_moving = false
			for id in card.member_entity_ids:
				world.units[id].position = formation.anchor_position
				world.units[id].has_move_target = false
		else:
			for id in card.member_entity_ids: world.units[id].enabled = false
	var encountered: UnitState
	if contested:
		var opponent := enemy(world,origin+(objective.position-origin).normalized()*180)
		encountered = opponent
		opponent.health = 250
		opponent.max_health = 250
		opponent.can_attack = true
	world._update_faction_knowledge()
	var generator := StaffPlanGenerator.new()
	var plans := generator.generate(world.create_faction_snapshot(1),1,request)
	print("OP_GENERATE mode=",mode," reason=",generator.last_rejection_reason," origin=",origin)
	check(plans != null,"operation generates")
	if plans == null: return
	var plan := plans.plans.filter(func(p: StaffCourseOfAction) -> bool: return p.kind == StaffPlanProfile.Kind.DIRECT)[0] as StaffCourseOfAction
	var approval := StaffPlanApprovalCommand.new(world.allocate_command_id(),1,world.current_tick,request,plan.profile_id,plan.fingerprint())
	check(world.submit_command(approval).is_accepted(),"operation approved")
	var first := -1
	var started: Dictionary = {}
	var graph: CommanderTaskGraphSnapshot
	for tick in range(900):
		world.advance_tick()
		var graphs := world.commander_task_graph_system.create_snapshots(1)
		if graphs.is_empty(): continue
		graph = graphs[0]
		var deployed := 0
		for node in graph.nodes:
			if node.phase == Phase.DEPLOY and node.lifecycle == Life.COMPLETED: deployed += 1
		for node in graph.nodes:
			if node.phase == Phase.ENGAGE and node.started_tick >= 0:
				started[node.card_id] = node.started_tick
				if first < 0: first = world.current_tick
				if mode == Mode.JOINT_ATTACK: check(deployed == 8,"no early assault")
		if mode == Mode.JOINT_ATTACK and started.size() == 8: break
		if mode == Mode.MUTUAL_SUPPORT and graph.nodes.all(func(n: CommanderTaskNodeSnapshot) -> bool: return n.phase == Phase.RETREAT or n.lifecycle in [Life.COMPLETED,Life.SKIPPED]): break
	if contested:
		check(encountered != null and encountered.health < 250,"contested fixture actually exchanges fire")
		print("OP_CONTACT health=",encountered.health," enabled=",encountered.enabled)
	check(started.size() == 8,"every participating card actually engages")
	if mode == Mode.JOINT_ATTACK and started.size() == 8:
		check(started.values().max()-started.values().min() <= 1,"joint attack starts together")
		var first_card := world.unit_cards[request.allowed_card_ids[0]] as UnitCardState
		var target := enemy(world,(world.formations[first_card.formation_id] as FormationState).anchor_position+Vector2(140,0))
		world.command_queue.drain()
		world.current_tick = ceili(float(world.current_tick)/5.0)*5
		GrowthCombatSystem.propose_focus(world)
		var focus_agents: Array[int] = []
		for command in world.command_queue.snapshot():
			if command is AttackCommand and command.fire_only and command.attack_target_entity_id == target.entity_id and not focus_agents.has(command.agent_id): focus_agents.append(command.agent_id)
		check(focus_agents.size() == 2,"two actual commanders submit shared focus through validation")
		world.command_queue.drain()
		target.position = Vector2(30000,2000)
		world._update_faction_knowledge()
		GrowthCombatSystem.propose_focus(world)
		for command in world.command_queue.snapshot():
			if command is AttackCommand: check(command.attack_target_entity_id != target.entity_id,"coalition rejects hidden target")
		world.command_queue.drain()
		var retreat := CommanderCardTaskCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,graph.graph_id,&"",CommanderCardTaskCommand.Action.RETREAT)
		check(world.submit_command(retreat).is_accepted(),"joint retreat accepted")
		world.advance_tick()
		for id in request.allowed_card_ids: check(world.commander_task_graph_system.is_retreating_card(id),"retreat identity reaches local combat")
	if graph != null:
		for node in graph.nodes:
			if node.phase != Phase.RETREAT: print("OP_NODE mode=",mode," ",node.node_id," life=",node.lifecycle," started=",node.started_tick," target=",node.target_position)
	print("COMBINED21_OPERATION mode=",mode," started=",started," tick=",world.current_tick)
