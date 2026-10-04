class_name LegionManualDeployment
extends RefCounted

static func accept(world: SimulationWorld, formation: FormationState, command: FormationMoveCommand) -> void:
	formation.legion_deployment=null; formation.deployment_entity_ids.clear()
	formation.deployment_ready_since=-1
	if world.battle_definition==null or not world.battle_definition.growth_mode or command.has_deployment_line: return
	if uses_automatic_slots(world.units,world.unit_cards,formation,command): return
	var plan := evaluate(world.units,world.formations,world.unit_cards,world.commanders,formation,command,world.logic_grid,world.pathfinder)
	if plan==null: return
	formation.legion_deployment=plan
	var commander := world.commanders[plan.commander_id] as CommanderState
	for identity in plan.identities: formation.deployment_entity_ids.append(commander.growth_slot_entities[identity])

static func evaluate(units: Dictionary, formations: Dictionary, cards: Dictionary, commanders: Dictionary, formation: FormationState, command: FormationMoveCommand, grid: LogicGrid, finder: GridPathfinder) -> LegionDeploymentPlan:
	var leader := units.get(formation.leader_entity_id) as UnitState
	if leader==null: return null
	var card := cards.get(leader.unit_card_id) as UnitCardState
	if card==null: return null
	var commander := commanders.get(card.commander_definition_id) as CommanderState
	if commander==null or commander.formation_mode==CommanderState.FormationMode.FREE: return null
	var identities := PackedInt32Array()
	for identity in range(commander.growth_slot_entities.size()):
		var entity_id: int = commander.growth_slot_entities[identity]
		var unit := units.get(entity_id) as UnitState
		if unit!=null and unit.enabled and formation.member_entity_ids.has(entity_id):
			identities.append(identity)
	var occupied := PackedVector2Array()
	for other: UnitState in units.values():
		if other.enabled and other.faction_id==card.faction_id and not formation.member_entity_ids.has(other.entity_id): occupied.append(other.position)
	for other: FormationState in formations.values():
		if other.formation_id==formation.formation_id or other.legion_deployment==null: continue
		var other_leader := units.get(other.leader_entity_id) as UnitState
		if other_leader!=null and other_leader.faction_id==card.faction_id: occupied.append_array(other.legion_deployment.points)
	var direction := command.deployment_facing
	if not direction.is_finite(): direction=Vector2.ZERO
	var plan := LegionDeploymentPlanner.movement_plan(commander.definition.profile.profile_id,identities,formation.anchor_position,command.target_position,direction,grid,occupied,command.allow_compression,finder,(commander.formation_mode-1) as LegionSpatialState.Action)
	plan.formation_id=formation.formation_id; plan.commander_id=card.commander_definition_id
	return plan

static func uses_automatic_slots(units: Dictionary, cards: Dictionary, formation: FormationState, command: FormationMoveCommand) -> bool:
	var leader := units.get(formation.leader_entity_id) as UnitState
	var card := cards.get(leader.unit_card_id) as UnitCardState if leader!=null else null
	return command.issuer_kind==GameCommand.IssuerKind.AGENT and card!=null and card.uses_legion_slots()

static func evaluate_commander(world: SimulationWorld, commander: CommanderState, goal: Vector2, facing: Vector2) -> LegionDeploymentPlan:
	var identities := PackedInt32Array(); var own_ids := PackedInt32Array(); var center := Vector2.ZERO
	for identity in range(61):
		var id: int = commander.hero_entity_id if identity==60 else commander.growth_slot_entities[identity]
		var unit := world.units.get(id) as UnitState
		if unit==null or not unit.enabled or unit.rejoin_pending or unit.legion_returning: continue
		identities.append(identity); own_ids.append(id); center+=unit.position
	if identities.is_empty(): return LegionDeploymentPlan.new()
	center/=float(identities.size())
	var hero := world.units.get(commander.hero_entity_id) as UnitState
	if hero!=null and hero.enabled: center=hero.position
	var record := world.legion_formation_system.records.get(commander.definition.definition_id) as LegionFormationState
	if record!=null and record.spatial.initialized: center=record.spatial.anchor
	var occupied := PackedVector2Array()
	for unit: UnitState in world.units.values():
		if unit.enabled and unit.faction_id==commander.faction_id and not own_ids.has(unit.entity_id): occupied.append(unit.position)
	for formation: FormationState in world.formations.values():
		if own_ids.has(formation.leader_entity_id) or formation.legion_deployment==null: continue
		var leader := world.units.get(formation.leader_entity_id) as UnitState
		if leader!=null and leader.faction_id==commander.faction_id: occupied.append_array(formation.legion_deployment.points)
	return LegionDeploymentPlanner.movement_plan(commander.definition.profile.profile_id,identities,center,goal,facing,world.logic_grid,occupied,true,world.pathfinder,maxi(0,commander.formation_mode-1) as LegionSpatialState.Action)

static func prepare(world: SimulationWorld) -> void:
	for formation: FormationState in world.formations.values():
		var plan := formation.legion_deployment
		if plan==null or not formation.is_moving or formation.path_index<formation.path.size(): continue
		var leader := world.units.get(formation.leader_entity_id) as UnitState
		if leader!=null and leader.flexible_legion_movement: continue
		if world.current_tick%10==0:
			var active := false
			for id in formation.deployment_entity_ids:
				var unit := world.units.get(id) as UnitState
				if unit!=null and unit.reformation!=null and unit.reformation.phase==LegionReformationState.Phase.REFORMING: active=true; break
			if not active:
				var command := FormationMoveCommand.new(0,0,GameCommand.IssuerKind.PLAYER,world.current_tick,formation.leader_entity_id,formation.formation_id,plan.anchor)
				command.deployment_facing=plan.facing; command.allow_compression=plan.allow_compression
				var refreshed := evaluate(world.units,world.formations,world.unit_cards,world.commanders,formation,command,world.logic_grid,world.pathfinder)
				if refreshed!=null and (refreshed.points!=plan.points or refreshed.identities!=plan.identities or refreshed.status!=plan.status):
					formation.legion_deployment=refreshed; plan=refreshed; formation.deployment_ready_since=-1
					formation.deployment_entity_ids.clear()
					var commander := world.commanders[plan.commander_id] as CommanderState
					for identity in plan.identities: formation.deployment_entity_ids.append(commander.growth_slot_entities[identity])
		if plan.status==LegionDeploymentPlan.Status.BLOCKED: continue
		var members: Array[UnitState] = []; var targets := PackedVector2Array()
		var tolerance := LegionReformationSystem.policy.tolerance(plan.spacing)
		for index in range(formation.deployment_entity_ids.size()):
			var unit := world.units.get(formation.deployment_entity_ids[index]) as UnitState
			if unit==null or not unit.enabled or unit.legion_slot!=null: continue
			unit.desired_position=plan.points[index]
			if unit.position.distance_to(plan.points[index])<=tolerance: continue
			members.append(unit); targets.append(plan.points[index])
		if LegionReformationSystem.request(world,members,targets,"manual:"+str([formation.formation_id,formation.order_destination]),tolerance):
			for unit in members: unit.reformation.charge(world.current_tick,LegionReformationSystem.policy)
