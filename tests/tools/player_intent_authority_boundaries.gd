extends "res://tests/tools/player_intent_authority_contract.gd"


func _initialize() -> void:
	test_recovery()
	test_hold_and_blockage()
	test_application_rejection()
	test_plan_scope()
	test_card_completion()
	test_graph_retreat_priority()
	test_task_ownership()
	test_hold_target_validation()
	test_retreat_scope()
	test_rejected_takeover_preserves_recruitment()
	var output := "res://artifacts/control-contract/boundaries.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "evidence": "SIMULATED"}))
	print("AUTHORITY_BOUNDARIES checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)


func test_recovery() -> void:
	var w := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var c := w.commanders[&"di_tian"] as CommanderState
	var cmd := order(w, c, Mode.OBJECTIVE)
	var goal := cmd.target_position
	check(w.submit_command(cmd).is_accepted(), "ordinary player objective accepted")
	w.advance_tick()
	w.command_queue.drain()
	w.current_tick = 100
	for id in c.subordinate_unit_card_ids: (w.unit_cards[id] as UnitCardState).organization = 20.0
	var proposals := GrowthCommanderAgent.new().propose(w.create_commander_task_snapshot(1), w.battle_definition, c.definition.definition_id)
	check(proposals.size() == 1 and proposals[0].action == GrowthCommanderCommand.Action.RECOVER, "ordinary low organization permits recovery")
	if proposals.is_empty(): return
	proposals[0].command_id = w.allocate_command_id()
	check(w.submit_command(proposals[0]).is_accepted(), "recovery passes unified pipeline")
	w.advance_tick()
	w.command_queue.drain()
	check(c.growth_recovering and c.player_target_position == goal and c.growth_resume_position == goal, "recovery retains goal ownership")
	# The existing mandatory 200-tick recovery interval must elapse.
	w.current_tick += 201
	for id in c.subordinate_unit_card_ids:
		var card := w.unit_cards[id] as UnitCardState
		card.organization = 100.0
		var f := w.formations[card.formation_id] as FormationState
		f.anchor_position = c.target_position
		f.is_moving = false
		for entity_id in card.member_entity_ids: (w.units[entity_id] as UnitState).position = c.target_position
	w._update_faction_knowledge()
	proposals = GrowthCommanderAgent.new().propose(w.create_commander_task_snapshot(1), w.battle_definition, c.definition.definition_id)
	check(proposals.size() == 1 and proposals[0].action == GrowthCommanderCommand.Action.RESUME, "recovery resumes after mandatory interval")
	if not proposals.is_empty():
		proposals[0].command_id = w.allocate_command_id()
		check(w.submit_command(proposals[0]).is_accepted(), "resume passes unified pipeline")
		w.advance_tick()
		check(not c.growth_recovering and c.target_position == goal and c.intent_mode == Mode.OBJECTIVE, "same player goal resumes")
	# Capture/destination completion never grants strategic retargeting.
	var view := w.create_commander_task_snapshot(1)
	view.tick += 100
	var own := view.get_commander(c.definition.definition_id)
	own.growth_recovering = false
	for card in view.unit_cards:
		if card.commander_definition_id == own.definition_id: card.organization = 100.0
	check(GrowthCommanderAgent.new().propose(view, w.battle_definition, own.definition_id).is_empty(), "completed ordinary goal cannot retarget")


func test_hold_and_blockage() -> void:
	var w := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	w.advance_tick()
	w.command_queue.drain()
	var c := w.commanders[&"di_tian"] as CommanderState
	c.equipped_doctrine_ids.append(&"elastic_defense")
	var cancel := CommanderOrderCommand.new(w.allocate_command_id(), 1, w.current_tick, c.definition.definition_id, CommanderOrderCommand.OrderKind.CANCEL_INTENT)
	check(w.submit_command(cancel).is_accepted(), "elastic defense cancellation accepted")
	w.advance_tick()
	w.command_queue.drain()
	var card := w.unit_cards[c.subordinate_unit_card_ids[-1]] as UnitCardState
	var original := card.commander_hold_position
	check(w.submit_command(stop(w, card)).is_accepted(), "hold card takeover accepted")
	w.advance_tick()
	check(w.submit_command(control(w, card, UnitCardControlCommand.Action.RETURN_TO_COMMANDER)).is_accepted(), "hold card return accepted")
	w.advance_tick()
	var returned := w.tasks[card.assigned_task_id] as TaskState
	check(returned.final_target_position == original, "hold return cannot inherit elastic strategic offset")
	check(w.submit_command(order(w, c, Mode.FORCE_ATTACK)).is_accepted(), "force from hold accepted")
	w.advance_tick()
	w.command_queue.drain()
	var recon := w.unit_cards[c.subordinate_unit_card_ids[0]] as UnitCardState
	var task := w.tasks[recon.assigned_task_id] as TaskState
	var original_target := task.target_position
	var original_route := task.planned_route.duplicate()
	var f := w.formations[recon.formation_id] as FormationState
	f.is_moving = true
	task.phase = TaskState.Phase.MUSTERING
	task.last_progress_position = (w.units[f.leader_entity_id] as UnitState).position
	task.ticks_without_progress = 30
	w.strategic_task_system._advance_scout_area(task, w)
	check(task.lifecycle == TaskState.Lifecycle.BLOCKED and task.target_position == original_target, "blocked force scout keeps target")
	PlayerIntentAuthority.refresh_receipts(w)
	check(c.intent_receipt == CommanderState.IntentReceipt.BLOCKED, "blockage is visible in receipt")
	w.current_tick += 31
	w.strategic_task_system._try_resume_blocked_movement(task, w)
	check(task.target_position == original_target and task.planned_route == original_route, "bounded retry keeps target and route")


func test_application_rejection() -> void:
	var w := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	w.advance_tick()
	w.command_queue.drain()
	var c := w.commanders[&"di_tian"] as CommanderState
	var card := w.unit_cards[c.subordinate_unit_card_ids[1]] as UnitCardState
	var f := w.formations[card.formation_id] as FormationState
	var enemy: UnitState
	for u: UnitState in w.units.values():
		if u.faction_id == 2 and u.hero_commander_id.is_empty(): enemy = u; break
	var saved := enemy.position
	enemy.position = (w.units[f.leader_entity_id] as UnitState).position + Vector2(60, 0)
	w._update_faction_knowledge()
	var ai := FormationMoveCommand.new(w.allocate_command_id(), 1, GameCommand.IssuerKind.AGENT, w.current_tick, f.leader_entity_id, f.formation_id, f.anchor_position)
	ai.agent_id = c.agent_id
	ai.task_id = card.assigned_task_id
	check(w.submit_command(ai).is_accepted(), "prior AI move accepted")
	var attack := AttackCommand.new(w.allocate_command_id(), 1, GameCommand.IssuerKind.PLAYER, w.current_tick, f.leader_entity_id, enemy.entity_id, f.formation_id)
	var previous := card.authority_version
	check(w.submit_command(attack).is_accepted(), "visible player target admitted")
	check(card.authority_version == previous, "admission does not commit authority")
	enemy.position = saved
	w._update_faction_knowledge()
	w.advance_tick()
	check(card.authority_version == previous and not card.persistent_manual, "application visibility rejection retains old authority")
	check(f.order_destination == ai.target_position and not w.events.any(func(e: SimulationEvent) -> bool: return e.kind == SimulationEvent.Kind.COMMAND_REJECTED and e.detail.begins_with("command=%d;" % ai.command_id)), "application rejection preserves prior valid AI execution")


func test_plan_scope() -> void:
	var w := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	w.advance_tick()
	w.command_queue.drain()
	var request := StaffPlanRequest.new()
	request.objective_region_id = &"blue_mid_outer"
	var c := w.commanders[&"di_tian"] as CommanderState
	request.allowed_card_ids = c.subordinate_unit_card_ids.duplicate()
	request.max_supply_cost = 0
	var plans := StaffPlanGenerator.new().generate(w.create_faction_snapshot(1), 1, request)
	check(plans != null and not plans.plans.is_empty(), "real staff plan available")
	if plans == null or plans.plans.is_empty(): return
	var plan := plans.plans[0]
	check(w.submit_command(StaffPlanApprovalCommand.new(w.allocate_command_id(), 1, w.current_tick, request, plan.profile_id, plan.fingerprint())).is_accepted(), "real staff approval accepted")
	w.advance_tick()
	w.command_queue.drain()
	var graphs := w.commander_task_graph_system.create_snapshots(1)
	check(not graphs.is_empty(), "real graph installed")
	if graphs.is_empty(): return
	var graph := graphs[0]
	var proposals := CommanderTaskGraphAgent.new().propose(w.create_commander_task_snapshot(1), graph)
	check(not proposals.is_empty(), "real graph proposes command")
	if proposals.is_empty(): return
	var stage := proposals[0]
	stage.command_id = w.allocate_command_id()
	check(stage.target_card_id.is_empty(), "normal stage has no trusted target override")
	check(w.submit_command(stage).is_accepted(), "old graph stage accepted")
	var queued := w.command_queue.snapshot()[0]
	check(not queued.scoped_card_ids.is_empty(), "authority resolves graph scope on server")
	check(w.submit_command(order(w, c, Mode.FORCE_ATTACK)).is_accepted(), "new intent supersedes graph")
	w.advance_tick()
	check(not w.commander_task_graph_system.owns_commander(c), "superseded graph ownership cancelled")
	check(w.events.any(func(e: SimulationEvent) -> bool: return e.kind == SimulationEvent.Kind.COMMAND_REJECTED and e.detail.contains("AUTHORITY_STALE")), "stale graph stage rejected before execution")


func test_card_completion() -> void:
	var w := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	w.advance_tick()
	w.command_queue.drain()
	var c := w.commanders[&"di_tian"] as CommanderState
	var card := w.unit_cards[c.subordinate_unit_card_ids[1]] as UnitCardState
	var f := w.formations[card.formation_id] as FormationState
	var cmd := AttackMoveCommand.new(w.allocate_command_id(), 1, GameCommand.IssuerKind.PLAYER, w.current_tick, f.leader_entity_id, f.formation_id, f.anchor_position)
	check(w.submit_command(cmd).is_accepted(), "card attack move accepted")
	check(w.command_queue.snapshot()[0] is AttackMoveCommand, "value copy preserves attack move subtype")
	w.advance_tick()
	w.command_queue.drain()
	check(w.submit_command(stop(w, card)).is_accepted(), "persistent stop accepted")
	w.advance_tick()
	var anchor := f.anchor_position
	var enemy: UnitState
	for unit: UnitState in w.units.values():
		if unit.faction_id == 2 and unit.hero_commander_id.is_empty(): enemy = unit; break
	enemy.position = anchor + Vector2(60, 0)
	w._update_faction_knowledge()
	GrowthCombatSystem.advance(w)
	PlayerIntentAuthority.refresh_receipts(w)
	check(card.persistent_manual and not f.is_moving and f.anchor_position == anchor and not f.local_engagement_active, "visible hostile cannot turn manual stop into pursuit")
	check(card.player_order_receipt == CommanderState.IntentReceipt.CANCELLED, "manual stop has cancelled receipt")
	var retreat := order(w, c, Mode.RETREAT)
	check(w.submit_command(retreat).is_accepted(), "explicit retreat goal accepted through objective validation")
	w.advance_tick()
	check(c.intent_mode == Mode.RETREAT and c.posture == CommanderState.Posture.DISENGAGE and c.player_target_position == retreat.target_position, "explicit retreat retains goal and prevents pursuit")


func test_graph_retreat_priority() -> void:
	for retreat_last in [false, true]:
		var w := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
		w.advance_tick()
		w.command_queue.drain()
		var c := w.commanders[&"di_tian"] as CommanderState
		var request := StaffPlanRequest.new()
		request.objective_region_id = &"blue_mid_outer"
		request.allowed_card_ids = c.subordinate_unit_card_ids.duplicate()
		request.max_supply_cost = 0
		var plans := StaffPlanGenerator.new().generate(w.create_faction_snapshot(1), 1, request)
		check(plans != null and not plans.plans.is_empty(), "retreat priority real plan available")
		if plans == null or plans.plans.is_empty(): continue
		var plan := plans.plans[0]
		check(w.submit_command(StaffPlanApprovalCommand.new(w.allocate_command_id(), 1, w.current_tick, request, plan.profile_id, plan.fingerprint())).is_accepted(), "retreat priority plan accepted")
		w.advance_tick()
		w.command_queue.drain()
		var graph := w.commander_task_graph_system.create_snapshots(1)[0]
		var force: CommanderOrderCommand
		var retreat: CommanderCardTaskCommand
		if retreat_last:
			force = order(w, c, Mode.FORCE_ATTACK)
			retreat = CommanderCardTaskCommand.new(w.allocate_command_id(), 1, GameCommand.IssuerKind.PLAYER, w.current_tick, graph.graph_id, &"", CommanderCardTaskCommand.Action.RETREAT)
		else:
			retreat = CommanderCardTaskCommand.new(w.allocate_command_id(), 1, GameCommand.IssuerKind.PLAYER, w.current_tick, graph.graph_id, &"", CommanderCardTaskCommand.Action.RETREAT)
			force = order(w, c, Mode.FORCE_ATTACK)
		retreat.graph_revision = graph.revision
		# Deliberately enqueue in reverse allocation order: simulation ID wins.
		check(w.submit_command(force).is_accepted(), "force and graph retreat same tick accepted")
		check(w.submit_command(retreat).is_accepted(), "player graph retreat accepted with resolved scope")
		w.advance_tick()
		check(c.intent_mode == (Mode.RETREAT if retreat_last else Mode.FORCE_ATTACK), "last valid player ID wins graph retreat vs force regardless enqueue order")
		check(not w.commander_task_graph_system.owns_commander(c), "graph retreat cannot revive old stage")


func test_task_ownership() -> void:
	var w := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	w.advance_tick()
	w.command_queue.drain()
	for faction in [1, 2]:
		var target: TaskState
		for task: TaskState in w.tasks.values():
			if task.faction_id != faction and task.lifecycle == TaskState.Lifecycle.EXECUTING: target = task; break
		check(target != null, "opposing live task exists")
		if target == null: continue
		for action in [TaskControlCommand.Action.CANCEL, TaskControlCommand.Action.PAUSE]:
			var command := TaskControlCommand.new(w.allocate_command_id(), faction, w.current_tick, target.task_id, action)
			var result := w.submit_command(command)
			check(result.reason == CommandValidationResult.Reason.NOT_CONTROLLER and target.lifecycle == TaskState.Lifecycle.EXECUTING, "task owner check rejects opposing cancel or pause without mutation")


func test_hold_target_validation() -> void:
	var w := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var c := w.commanders[&"di_tian"] as CommanderState
	var cancel := CommanderOrderCommand.new(w.allocate_command_id(), 1, w.current_tick, c.definition.definition_id, CommanderOrderCommand.OrderKind.CANCEL_INTENT)
	check(w.submit_command(cancel).is_accepted(), "hold target validation cancel accepted")
	w.advance_tick()
	w.command_queue.drain()
	var command := order(w, c)
	var cell := w.logic_grid.world_to_cell(command.target_position)
	for y in range(-10, 11):
		for x in range(-10, 11): w.logic_grid.set_blocked(cell + Vector2i(x, y), true)
	var version := c.authority_version
	var previous := c.player_command_id
	var result := w.submit_command(command)
	check(result.reason == CommandValidationResult.Reason.PATH_UNAVAILABLE, "hold to ordinary validates new unreachable goal rather than old hold anchor")
	check(c.intent_mode == Mode.HOLD and c.authority_version == version and c.player_command_id == previous, "rejected unreachable goal retains original hold authority")


func test_retreat_scope() -> void:
	var w := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	w.advance_tick()
	w.command_queue.drain()
	var c := w.commanders[&"di_tian"] as CommanderState
	var card := w.unit_cards[c.subordinate_unit_card_ids[1]] as UnitCardState
	var f := w.formations[card.formation_id] as FormationState
	var ai := FormationMoveCommand.new(w.allocate_command_id(), 1, GameCommand.IssuerKind.AGENT, w.current_tick, f.leader_entity_id, f.formation_id, f.anchor_position)
	ai.agent_id = c.agent_id
	ai.task_id = card.assigned_task_id
	check(w.submit_command(ai).is_accepted(), "pre-retreat valid AI admitted")
	var retreat := CommanderOrderCommand.new(w.allocate_command_id(), 1, w.current_tick, c.definition.definition_id, CommanderOrderCommand.OrderKind.SET_POSTURE, Vector2.ZERO, &"", CommanderState.Posture.DISENGAGE)
	check(w.submit_command(retreat).is_accepted(), "posture retreat admitted")
	check(w.command_queue.snapshot().any(func(cmd: GameCommand) -> bool: return cmd.command_id == ai.command_id), "retreat admission cannot erase queued old AI")
	f.local_engagement_active = true
	f.local_engagement_returning = true
	f.local_engagement_resume_destination = Vector2.ZERO
	w.advance_tick()
	check(not f.local_engagement_active and not f.local_engagement_returning, "new legion retreat clears local pursuit and stale return route")
	check(w.events.any(func(e: SimulationEvent) -> bool: return e.kind == SimulationEvent.Kind.COMMAND_REJECTED and e.detail.begins_with("command=%d;" % ai.command_id) and e.detail.contains("AUTHORITY_STALE")), "pre-retreat AI rejected at application with stale receipt")
	w.command_queue.drain()
	var task := w.tasks[card.assigned_task_id] as TaskState
	f.anchor_position = task.target_position
	f.order_target_entity_id = 0
	f.is_moving = false
	for id in card.member_entity_ids: (w.units[id] as UnitState).position = task.target_position
	var enemy: UnitState
	for unit: UnitState in w.units.values():
		if unit.faction_id == 2 and unit.hero_commander_id.is_empty(): enemy = unit; break
	enemy.position = task.target_position + Vector2(60, 0)
	w._update_faction_knowledge()
	w.strategic_task_system._advance_defend_area(task, w)
	var attacks := w.command_queue.snapshot().filter(func(cmd: GameCommand) -> bool: return cmd is AttackCommand and cmd.formation_id == f.formation_id)
	check(not attacks.is_empty(), "retreat destination sees legal hostile for self defense")
	check(attacks.all(func(cmd: AttackCommand) -> bool: return cmd.fire_only), "retreat self defense cannot become pursuit after arriving")


func test_rejected_takeover_preserves_recruitment() -> void:
	var w := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	w.advance_tick()
	w.command_queue.drain()
	w.current_tick = 20
	var c := w.commanders[&"di_tian"] as CommanderState
	var slot := LegionGrowthSystem.next_for_world(w, c)
	var role := LegionGrowthSystem.ROLE_KEYS[LegionTemplate.find(c.definition.profile.profile_id).slot_roles()[slot]]
	var card: UnitCardState
	for id in c.subordinate_unit_card_ids:
		if (w.unit_cards[id] as UnitCardState).definition.role_key == role: card = w.unit_cards[id]; break
	(w.factions[1] as FactionState).supply = 100
	var recruit := RecruitUnitCardCommand.new(w.allocate_command_id(), 1, GameCommand.IssuerKind.AGENT, w.current_tick, card.definition.definition_id, 1)
	recruit.agent_id = c.agent_id
	recruit.task_id = card.assigned_task_id
	check(w.submit_command(recruit).is_accepted(), "old automatic recruit admitted before takeover")
	var takeover := control(w, card, UnitCardControlCommand.Action.TAKEOVER)
	check(w.submit_command(takeover).is_accepted(), "takeover admitted before application recheck")
	check(w.command_queue.snapshot().any(func(cmd: GameCommand) -> bool: return cmd.command_id == recruit.command_id), "takeover admission preserves pending recruitment")
	# Model ownership changing between admission and application. This invalidates
	# the takeover's all-member ownership constraint while recruitment remains legal.
	(w.units[card.member_entity_ids[0]] as UnitState).controller_id = 2
	check(w.validate_command(takeover).reason == CommandValidationResult.Reason.NOT_CONTROLLER, "takeover becomes invalid before applying")
	var batch := w.command_queue.drain()
	check(RecruitmentSystem.validate(w, recruit).is_accepted(), "old recruitment remains independently legal after draining pending claims")
	for queued in batch: w.command_queue.enqueue(queued)
	var version := card.authority_version
	var strength := card.member_entity_ids.size()
	w.advance_tick()
	check(not card.persistent_manual and card.authority_version == version, "rejected takeover cannot commit authority")
	check(card.member_entity_ids.size() > strength, "rejected takeover cannot enter batch support suppression")
	check(not w.events.any(func(e: SimulationEvent) -> bool: return e.detail == "automatic support superseded by player takeover"), "rejected takeover produces no false support preemption")
