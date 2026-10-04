class_name LegionControlHandoff
extends RefCounted

# Authority-only handoff. A control-owner change is not a new movement order.
static func return_current(world: SimulationWorld, card: UnitCardState) -> void:
	if card.player_stopped: return
	var formation := world.formations.get(card.formation_id) as FormationState
	var commander := world.commanders.get(card.commander_definition_id) as CommanderState
	if formation==null or commander==null: return
	# A graph stage owns its task meaning. The accepted player order replaces
	# only this card's old stages, without stopping the in-flight formation.
	if world.commander_task_graph_system.owns_card(card.definition.definition_id):
		world.commander_task_graph_system.supersede_card_order(world,card.definition.definition_id)
	var task := world.tasks.get(card.return_task_id) as TaskState
	if task==null or task.unit_card_id!=card.definition.definition_id or task.lifecycle in [TaskState.Lifecycle.COMPLETED,TaskState.Lifecycle.FAILED,TaskState.Lifecycle.CANCELLED]:
		task=TaskState.new(world._next_task_id,commander.agent_id,card.member_entity_ids)
		world._next_task_id+=1; world.tasks[task.task_id]=task
	task.faction_id=card.faction_id; task.agent_id=commander.agent_id
	task.unit_card_id=card.definition.definition_id; task.formation_id=card.formation_id
	task.kind=TaskState.Kind.DEFEND_AREA; task.persistent_order=true
	task.target_position=formation.order_destination; task.final_target_position=formation.order_destination
	task.planned_route=formation.planned_route.duplicate(); task.route=formation.path.duplicate()
	task.target_entity_id=formation.order_target_entity_id
	task.has_staged_target=false; task.remaining_staged_route.clear()
	task.requires_observed_contact=false; task.activation_tick=world.current_tick
	task.participant_entity_ids.clear()
	card.continuing_player_order=true; card.temporary_micro=false
	card.control_state=UnitCardState.ControlState.AGENT_ASSIGNED
	card.assigned_agent_id=commander.agent_id; card.assigned_task_id=task.task_id
	card.return_task_id=0; card.return_formation_id=0
	for id in card.member_entity_ids:
		var unit := world.units.get(id) as UnitState
		if unit==null or not unit.enabled: continue
		task.participant_entity_ids.append(id)
		unit.control_state=UnitState.ControlState.AGENT_ASSIGNED
		unit.assigned_agent_id=commander.agent_id; unit.assigned_task_id=task.task_id
		unit.return_task_id=0; unit.rejoin_pending=false
	var task_ids: Array[int] = []
	for id in commander.current_task_ids:
		var existing := world.tasks.get(id) as TaskState
		if existing!=null and existing.unit_card_id!=card.definition.definition_id: task_ids.append(id)
	task_ids.append(task.task_id); commander.set_task_ids(task_ids)
	task.set_lifecycle(TaskState.Lifecycle.EXECUTING,world.current_tick)
	advance_current(world,task)

# Retain the already validated move/attack/deployment and its physical state.
# A fresh commander assignment clears the card flag and resumes normal tasks.
static func advance_current(world: SimulationWorld, task: TaskState) -> bool:
	if world.battle_definition==null or not world.battle_definition.growth_mode: return false
	var card := world.unit_cards.get(task.unit_card_id) as UnitCardState
	if card==null or not card.continuing_player_order or card.assigned_task_id!=task.task_id: return false
	var formation := world.formations.get(card.formation_id) as FormationState
	var commander := world.commanders.get(card.commander_definition_id) as CommanderState
	var available := false
	for id in card.member_entity_ids:
		var unit := world.units.get(id) as UnitState
		if unit!=null and unit.enabled and not unit.legion_returning: available=true; break
	if task.lifecycle in [TaskState.Lifecycle.COMPLETED,TaskState.Lifecycle.CANCELLED,TaskState.Lifecycle.FAILED] or formation==null or not available or card.deployment_state!=UnitCardState.DeploymentState.DEPLOYED or commander==null or commander.legion_regrouping:
		cancel_current(world,card)
		return true
	task.set_phase(TaskState.Phase.ADVANCING if formation.is_moving else TaskState.Phase.HOLDING,world.current_tick,"Continuing accepted player order after control handoff")
	return true

static func cancel_current(world: SimulationWorld, card: UnitCardState) -> void:
	if not card.continuing_player_order: return
	card.continuing_player_order=false
	var task := world.tasks.get(card.assigned_task_id) as TaskState
	if task!=null:
		if task.lifecycle not in [TaskState.Lifecycle.COMPLETED,TaskState.Lifecycle.CANCELLED,TaskState.Lifecycle.FAILED]:
			task.set_lifecycle(TaskState.Lifecycle.CANCELLED,world.current_tick)
		task.set_phase(TaskState.Phase.DONE,world.current_tick,"Accepted player order ended")
		world.release_task_participants(task)
	var commander := world.commanders.get(card.commander_definition_id) as CommanderState
	if commander!=null: commander.current_task_ids.erase(card.assigned_task_id)
	card.assigned_task_id=0; card.assigned_agent_id=0
	if card.control_state==UnitCardState.ControlState.AGENT_ASSIGNED: card.control_state=UnitCardState.ControlState.UNASSIGNED
