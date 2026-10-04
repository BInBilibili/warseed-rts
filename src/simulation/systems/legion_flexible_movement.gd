class_name LegionFlexibleMovement
extends RefCounted

# Formation is a preference, never an admission gate. Stable identities keep
# their role offsets where terrain permits; constrained members follow the
# traversable route and expand again as space becomes available.
static func prepare(world: SimulationWorld, commander: CommanderState, record: LegionFormationState) -> void:
	var hero := world.units.get(commander.hero_entity_id) as UnitState
	if hero==null or not hero.enabled or commander.legion_regrouping: return
	var source := LegionSpatialExecutor._source(world,commander,record)
	if hero.control_state!=UnitState.ControlState.AGENT_ASSIGNED: return
	if source==null:
		hero.path.clear(); hero.has_move_target=false
		return
	var state := record.spatial
	state.flexible=true
	var profile := commander.definition.profile.profile_id
	if not state.initialized:
		state.initialized=true; state.flexible=true
		state.anchor=hero.position
		state.facing=Vector2.RIGHT if commander.faction_id==1 else Vector2.LEFT
		for identity in range(60):
			var slot := LegionSpatialOrder.new(); slot.identity=identity; slot.admitted=true
			state.slots.append(slot)
	state.transit=LegionTransitState.new()
	var next_action := (commander.formation_mode - 1) as LegionSpatialState.Action
	if state.action!=next_action: state.deployment=null
	state.action=next_action
	var intent := str([source.order_kind,source.order_destination,source.planned_route,world.logic_grid.revision])
	if state.intent!=intent or state.route.is_empty():
		state.intent=intent; state.goal=source.order_destination; state.ready_since=-1
		state.route=PackedVector2Array([state.anchor]); state.route_index=1
		var waypoints := source.planned_route.duplicate()
		if waypoints.is_empty() or waypoints[-1]!=state.goal: waypoints.append(state.goal)
		for point in waypoints:
			var part := world.pathfinder.find_body_path(state.route[-1],point)
			if part.is_empty(): state.route.clear(); break
			state.route.append_array(part.slice(1))
		state.deployment=null
	if commander.posture==CommanderState.Posture.HOLD:
		record.reason=&"COMMAND_HOLD"; state.reason=&"COMMAND_HOLD"
		return
	if not source.is_moving:
		state.route=PackedVector2Array([state.anchor]); state.route_index=1
		hero.path.clear(); hero.has_move_target=false; hero.desired_position=hero.position
		state.goal=state.anchor
	# Never wait for the old row, escort radius or a full batch. The anchor is
	# only a target generator; members still move once at their actual speed.
	if state.advanced_tick!=world.current_tick:
		state.advanced_tick=world.current_tick
		var remaining := record.core_speed*SimulationWorld.TICK_SECONDS
		# Bound the lead by a real member, without requiring a complete row.
		# Enemy collision can stop the body; it must then stop the anchor too.
		while source.is_moving and remaining>0.001 and state.route_index<state.route.size() and state.anchor.distance_to(hero.position)<320.0:
			var target := state.route[state.route_index]
			var next := state.anchor.move_toward(target,remaining)
			if next.distance_to(state.anchor)>0.001 and state.action!=LegionSpatialState.Action.RETREAT:
				state.facing=(next-state.anchor).normalized()
			remaining-=state.anchor.distance_to(next); state.anchor=next
			if state.anchor.distance_to(target)>0.001: break
			state.route_index+=1
	var reached := state.anchor.distance_to(state.goal)<=6.0
	if reached and not commander.deployment_facing.is_zero_approx(): state.facing=commander.deployment_facing.normalized()
	var identities := PackedInt32Array([60])
	for identity in range(commander.growth_unlocked_slots):
		var unit := world.units.get(commander.growth_slot_entities[identity]) as UnitState
		if unit!=null and LegionSpatialExecutor.eligible(unit,world.unit_cards.get(unit.unit_card_id)): identities.append(identity)
	# Cache stationary deployment; do not solve the full 61-slot layout at 10Hz.
	if reached and (state.deployment==null or state.deployment.identities!=identities or state.deployment.facing!=state.facing):
		var occupied := PackedVector2Array()
		for other: UnitState in world.units.values():
			if other.enabled and other.faction_id==commander.faction_id and other.hero_commander_id!=commander.definition.definition_id and not commander.growth_slot_entities.has(other.entity_id): occupied.append(other.position)
		state.deployment=LegionDeploymentPlanner.plan(profile,state.action,identities,state.goal,state.facing,world.logic_grid,occupied)
		if state.deployment.status==LegionDeploymentPlan.Status.BLOCKED:
			state.deployment=LegionDeploymentPlanner.movement_plan(profile,identities,state.anchor,state.goal,state.facing,world.logic_grid,occupied,true,world.pathfinder,state.action)
	var offsets := LegionDeploymentPlanner.offsets(profile,state.action,48.0)
	state.eligible=0; state.ready=0
	for identity in identities:
		var unit := LegionTransitExecutor._entity(world,commander,identity)
		var offset := offsets[identity]
		var card := world.unit_cards.get(unit.unit_card_id) as UnitCardState
		var formation := world.formations.get(card.formation_id) as FormationState if card!=null else null
		# Role tasks can have their own nearby destinations. Do not acknowledge
		# that task merely because its members reached another card's endpoint.
		var slot_anchor := formation.order_destination if reached and formation!=null and formation.is_moving else state.anchor
		var target := slot_anchor+state.facing*offset.x+state.facing.orthogonal()*offset.y
		if reached and slot_anchor==state.anchor and state.deployment!=null and state.deployment.offsets.size()==61:
			offset=state.deployment.offsets[identity]
			target=state.anchor+state.facing*offset.x+state.facing.orthogonal()*offset.y
		if not LegionTransitGeometry.segment_fits(world.logic_grid,target,target):
			# Pull the preferred slot toward a known traversable anchor. Tight
			# slots may overlap, incurring the separate actual-overlap penalty.
			for scale: float in [0.75,0.5,0.25,0.125,0.0]:
				target=slot_anchor+(state.facing*offset.x+state.facing.orthogonal()*offset.y)*scale
				if LegionTransitGeometry.segment_fits(world.logic_grid,target,target): break
		var path := world.pathfinder.find_body_path(unit.position,target)
		if path.is_empty():
			target=slot_anchor; path=world.pathfinder.find_body_path(unit.position,target)
		var arrived := unit.position.distance_to(target)<=6.0
		unit.legion_motion=LegionMotionConstraint.new(); unit.legion_motion.ground_radius=32.0
		if identity==60:
			unit.path=path; unit.path_index=1; unit.move_target=target; unit.desired_position=target
			unit.has_move_target=not arrived and path.size()>1
			record.target=target; record.reason=&"IN_POSITION" if arrived else &"FORMING"
		else:
			if formation!=null and card.player_stopped:
				target=unit.position; path=PackedVector2Array([target,target]); arrived=true
			var slot := state.slots[identity]
			slot.entity_id=unit.entity_id; slot.admitted=true; slot.target=target; slot.offset=offset
			slot.path=path; slot.path_index=1; slot.tolerance=6.0
			slot.reason=&"PATH_UNAVAILABLE" if path.is_empty() else (&"IN_POSITION" if arrived else &"FORMING")
			slot.at_destination=reached and arrived and formation!=null and slot_anchor==formation.order_destination
			unit.legion_slot=slot; unit.desired_position=target
			unit.local_engagement_active=false; unit.local_engagement_returning=false
			state.eligible+=1
			if arrived: state.ready+=1
	state.reason=&"IN_POSITION" if reached and state.ready==state.eligible else &"FORMING"

static func prepare_hero(record: LegionFormationState) -> bool:
	return record.spatial.flexible and record.spatial.initialized
