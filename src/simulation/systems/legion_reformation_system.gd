class_name LegionReformationSystem
extends RefCounted

static var policy: LegionReformationPolicy = preload("res://data/legions/rapid_reformation.tres")

static func ignores_pair(unit: UnitState, other: UnitState) -> bool:
	return unit.enabled and other.enabled and unit.faction_id==other.faction_id and ((unit.reformation!=null and unit.reformation.phase==LegionReformationState.Phase.REFORMING) or (other.reformation!=null and other.reformation.phase==LegionReformationState.Phase.REFORMING))

static func overlapped(unit: UnitState, units: Dictionary) -> bool:
	for other: UnitState in units.values():
		if other.enabled and other.entity_id!=unit.entity_id and unit.position.distance_squared_to(other.position)<policy.body_separation*policy.body_separation-0.01: return true
	return false

static func damage_factor(unit: UnitState) -> float:
	return unit.reformation.damage_factor(policy) if unit.reformation!=null else 1.0

# Planning reads public terrain and friendly occupancy only. Hidden enemies are
# still physical blockers in LegionMotionConstraint, never planning inputs.
static func request(world: SimulationWorld, members: Array[UnitState], targets: PackedVector2Array, intent: String, tolerance: float = 6.0) -> bool:
	if members.is_empty() or targets.size()!=members.size() or not policy.validation_errors().is_empty(): return false
	var routes: Array[PackedVector2Array] = []
	var ids := PackedInt32Array()
	for unit in members: ids.append(unit.entity_id)
	for index in range(members.size()):
		var unit := members[index]
		if not unit.enabled or unit.legion_returning or unit.rejoin_pending: return false
		if unit.reformation==null: unit.reformation=LegionReformationState.new()
		if not unit.reformation.can_start(world.current_tick,policy): return false
		if not LegionTransitGeometry.segment_fits(world.logic_grid,targets[index],targets[index],policy.ground_radius): return false
		for previous in range(index):
			var spacing := policy.artillery_separation if unit.tactical_role==UnitState.TacticalRole.FIREPOWER or members[previous].tactical_role==UnitState.TacticalRole.FIREPOWER else policy.body_separation+2.0*tolerance
			if targets[index].distance_to(targets[previous])<spacing-0.01: return false
		for other: UnitState in world.units.values():
			if not other.enabled or other.faction_id!=unit.faction_id or ids.has(other.entity_id): continue
			# A measured current body has no arrival-error interval. Reserve the
			# moving member's tolerance once; two target reservations need both.
			if targets[index].distance_to(other.position)<policy.body_separation+tolerance: return false
			if other.reformation!=null and other.reformation.phase==LegionReformationState.Phase.REFORMING:
				if targets[index].distance_to(other.reformation.target)<policy.body_separation+2.0*tolerance: return false
				if targets[index].distance_to(other.reformation.origin)<policy.body_separation+2.0*tolerance: return false
		var route := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,unit.position,targets[index])
		if route.size()<2: return false
		for segment in range(1,route.size()):
			if not LegionTransitGeometry.segment_fits(world.logic_grid,route[segment-1],route[segment],policy.ground_radius): return false
		var ticks_available := mini(policy.maximum_ticks-policy.landing_ticks,policy.maximum_ticks-unit.reformation.active_ticks.size()-policy.landing_ticks)
		if LegionProtectionPlanner.path_length(route)>unit.move_speed*SimulationWorld.TICK_SECONDS*ticks_available: return false
		routes.append(route)
	for index in range(members.size()):
		members[index].reformation.begin(world.current_tick,targets[index],routes[index],intent,tolerance,policy)
	return true

static func prepare(world: SimulationWorld) -> void:
	if world.battle_definition==null or not world.battle_definition.growth_mode: return
	LegionManualDeployment.prepare(world)
	# Stable targets during a local maneuver. Replanning never refreshes budget.
	for unit: UnitState in world.units.values():
		if unit.reformation==null and unit.legion_slot!=null: unit.reformation=LegionReformationState.new()
		var state := unit.reformation
		if state==null: continue
		if state.observed_tick!=world.current_tick:
			state.stalled_ticks=state.stalled_ticks+1 if unit.position.distance_to(state.observed_position)<1.0 else 0
			state.observed_position=unit.position; state.observed_tick=world.current_tick
		if not unit.enabled:
			state.end(world.current_tick,false,policy,&"REFORMATION_DEAD"); continue
		if state.phase!=LegionReformationState.Phase.REFORMING: continue
		var desired := unit.legion_slot.target if unit.legion_slot!=null else (unit.desired_position if unit.following_formation else unit.move_target)
		var cancelled := unit.legion_returning or (unit.legion_slot==null and not unit.has_move_target) or desired.distance_to(state.requested_target)>0.01
		if cancelled or not state.charge(world.current_tick,policy):
			state.end(world.current_tick,overlapped(unit,world.units),policy,&"REFORMATION_CANCELLED" if cancelled else &"REFORMATION_TIMEOUT")
			continue
		_revalidate(world,unit)
	var ids := world.legion_formation_system.records.keys(); ids.sort()
	for id: StringName in ids:
		var record := world.legion_formation_system.records[id]
		if not record.active or record.spatial.flexible: continue
		var commander := world.commanders[id] as CommanderState
		var transit := record.spatial.transit
		if transit.phase==LegionTransitState.Phase.WIDE:
			_prepare_wide(world,commander,record)
			continue
		for batch in transit.batches:
			# Never phase a marching column through another traffic batch.
			if batch.admitted and batch.exit_stage==0 and transit.phase!=LegionTransitState.Phase.EXPAND: continue
			var members: Array[UnitState] = []
			var targets := PackedVector2Array()
			var tolerance := policy.tolerance(record.spatial.deployment.spacing) if transit.phase==LegionTransitState.Phase.EXPAND and record.spatial.deployment!=null else 6.0
			for ordinal in range(batch.identities.size()):
				var unit := LegionTransitExecutor._entity(world,commander,batch.identities[ordinal])
				if not LegionTransitExecutor._available(world,unit): continue
				var target := LegionTransitExecutor._target(transit,batch,ordinal)
				if unit.position.distance_to(target)<=tolerance: continue
				members.append(unit); targets.append(target)
			if request(world,members,targets,str([id,transit.started_tick,transit.phase,batch.exit_stage,batch.gather_phase]),tolerance):
				for unit in members: unit.reformation.charge(world.current_tick,policy)
	for unit: UnitState in world.units.values():
		if unit.reformation==null or unit.reformation.phase!=LegionReformationState.Phase.REFORMING: continue
		if unit.legion_slot!=null:
			unit.legion_slot.path=unit.reformation.route.duplicate(); unit.legion_slot.path_index=1

static func _route_clear(world: SimulationWorld, route: PackedVector2Array) -> bool:
	return _route_clear_grid(world.logic_grid,route)

static func _route_clear_grid(grid: LogicGrid, route: PackedVector2Array) -> bool:
	if route.size()<2: return false
	for index in range(1,route.size()):
		if not LegionTransitGeometry.segment_fits(grid,route[index-1],route[index],policy.ground_radius): return false
	return true

static func _landing_clear(world: SimulationWorld, unit: UnitState, point: Vector2) -> bool:
	for other: UnitState in world.units.values():
		if not other.enabled or other.entity_id==unit.entity_id or other.faction_id!=unit.faction_id: continue
		var other_state := other.reformation
		if other_state!=null and other_state.phase==LegionReformationState.Phase.REFORMING:
			if point.distance_to(other_state.target)<policy.body_separation+2.0*unit.reformation.tolerance-0.01: return false
			# Members in one atomic swap may share start/end reservations.
			if other_state.intent==unit.reformation.intent: continue
			if point.distance_to(other_state.origin)<policy.body_separation-0.01: return false
		if point.distance_to(other.position)<policy.body_separation-0.01: return false
	return true

static func _revalidate(world: SimulationWorld, unit: UnitState) -> void:
	var state := unit.reformation
	var route := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,unit.position,state.target)
	var ticks_left := state.deadline_tick-world.current_tick
	var travel := unit.move_speed*SimulationWorld.TICK_SECONDS
	var clear := _route_clear(world,route) and _landing_clear(world,unit,state.target)
	var reserve := 0 if state.returning_to_origin else policy.landing_ticks
	if clear and LegionProtectionPlanner.path_length(route)<=maxi(0,ticks_left-reserve)*travel+state.tolerance:
		state.route=route; return
	# Withdraw permission early while already separated. If overlapping, use
	# the reserved origin only when it is still reachable within this lease.
	if not overlapped(unit,world.units):
		state.end(world.current_tick,false,policy,&"REFORMATION_LANDING_UNAVAILABLE"); return
	var fallback := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,unit.position,state.origin)
	if _route_clear(world,fallback) and _landing_clear(world,unit,state.origin) and LegionProtectionPlanner.path_length(fallback)<=ticks_left*travel:
		state.target=state.origin; state.returning_to_origin=true; state.route=fallback
		state.reason=&"REFORMATION_RETURNING"
	else:
		state.end(world.current_tick,true,policy,&"REFORMATION_LANDING_UNAVAILABLE")

static func _prepare_wide(world: SimulationWorld, commander: CommanderState, record: LegionFormationState) -> void:
	if record.batch_plan==null or record.spatial.relief or commander.posture==CommanderState.Posture.HOLD: return
	for batch in record.batch_plan.batches:
		var members: Array[UnitState] = []
		var targets := PackedVector2Array()
		var trigger := record.spatial.changed_tick==world.current_tick
		for identity in batch.identities:
			var unit := LegionTransitExecutor._entity(world,commander,identity)
			if not LegionTransitExecutor._available(world,unit): continue
			var slot := unit.legion_slot
			var target := unit.move_target if identity==60 else (slot.target if slot!=null else unit.position)
			if unit.position.distance_to(target)<=6.0: continue
			if slot!=null and not slot.admitted: continue
			members.append(unit); targets.append(target)
			if unit.reformation!=null and unit.reformation.stalled_ticks>=10: trigger=true
		if trigger and request(world,members,targets,record.spatial.intent,LegionReformationSystem.policy.tolerance(record.spatial.deployment.spacing) if record.spatial.deployment!=null else 6.0):
			for unit in members: unit.reformation.charge(world.current_tick,policy)

static func finish_movement(world: SimulationWorld) -> void:
	for unit: UnitState in world.units.values():
		if unit.flexible_legion_movement:
			if unit.reformation==null: unit.reformation=LegionReformationState.new()
			unit.reformation.forced_overlap=unit.enabled and overlapped(unit,world.units)
			# Evaluate after every movement, before projectiles resolve. Every
			# participant pays once, including a stationary unit being overlapped.
			if unit.reformation.forced_overlap:
				if unit.reformation.separating_since_tick<0: unit.reformation.separating_since_tick=world.current_tick
			elif unit.reformation.phase==LegionReformationState.Phase.SOLID:
				unit.reformation.separating_since_tick=-1
		var state := unit.reformation
		if state==null or state.phase==LegionReformationState.Phase.SOLID: continue
		var overlap := overlapped(unit,world.units)
		if state.phase==LegionReformationState.Phase.SEPARATING:
			if not overlap: state.end(world.current_tick,false,policy,&"REFORMATION_SOLID")
		elif unit.position.distance_to(state.target)<=state.tolerance and not overlap:
			state.end(world.current_tick,false,policy,&"REFORMATION_RETURNED" if state.returning_to_origin else &"REFORMATION_COMPLETE")
