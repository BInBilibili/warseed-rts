class_name LegionTransitRejoin
extends RefCounted

class State extends RefCounted:
	var entities := PackedInt32Array()
	var approached := PackedByteArray()
	var goals := PackedVector2Array()
	func _init() -> void:
		entities.resize(60); approached.resize(60); goals.resize(60)
	func duplicate_value() -> State:
		var copy := State.new()
		copy.entities=entities.duplicate(); copy.approached=approached.duplicate(); copy.goals=goals.duplicate()
		return copy

static func prepare(world: SimulationWorld, commander: CommanderState, record: LegionFormationState, visible: Array[UnitSnapshot], state: State) -> void:
	if commander.posture in [CommanderState.Posture.HOLD,CommanderState.Posture.DISENGAGE] or commander.legion_regrouping or commander.growth_recovering: return
	var hero := world.units.get(commander.hero_entity_id) as UnitState
	if not LegionTransitExecutor._available(world,hero): return
	var transit := record.spatial.transit
	if transit.phase not in [LegionTransitState.Phase.COLUMN,LegionTransitState.Phase.EXIT_WAIT] or transit.batches.is_empty(): return
	var pending: Array[int] = []
	for identity in record.batch_plan.pending_identities:
		if identity<60 and LegionTransitExecutor._available(world,LegionTransitExecutor._entity(world,commander,identity)): pending.append(identity)
	if pending.is_empty(): return
	# Waiting identities retain a physical hold order until capacity is reserved.
	# They must not fall back to the legacy card mover while another group joins.
	pending.sort()
	for identity in pending:
		var unit := LegionTransitExecutor._entity(world,commander,identity)
		var slot := record.spatial.slots[identity]
		slot.entity_id=unit.entity_id; slot.admitted=false; slot.at_destination=false
		slot.target=unit.position; slot.path=PackedVector2Array(); slot.path_index=0
		slot.reason=&"TRANSIT_REJOIN_WAIT"
		unit.legion_slot=slot; unit.desired_position=unit.position
		unit.local_engagement_active=false; unit.local_engagement_returning=false
	var last := transit.batches[-1]
	var new_batch := last.identities.size()>=12
	var proposed := LegionTransitState.BatchState.new() if new_batch else last.duplicate_value()
	if new_batch:
		var actual_tail := INF
		for identity in last.identities:
			var unit := LegionTransitExecutor._entity(world,commander,identity)
			if LegionTransitExecutor._available(world,unit): actual_tail=minf(actual_tail,LegionTransitGeometry.progress_at(transit.path,unit.position))
		if not is_finite(actual_tail): return
		proposed.progress=actual_tail-172.0; proposed.gather_phase=2
	var old_count := proposed.identities.size()
	var selected: Array[int] = []
	var needed_cores := 2
	for identity in proposed.identities:
		var unit := LegionTransitExecutor._entity(world,commander,identity)
		if LegionTransitExecutor._available(world,unit) and unit.tactical_role in [UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR]: needed_cores-=1
	for identity in pending:
		if needed_cores<=0 or selected.size()>=12-old_count: break
		if record.batch_plan.members[identity].role in [1,2]:
			selected.append(identity); needed_cores-=1
	# Once this group has its two escorts, prioritize waiting artillery. Taking
	# all queued cores first strands later gun-only batches at the same tail.
	for artillery_first in [true,false]:
		for identity in pending:
			if selected.size()>=12-old_count: break
			if selected.has(identity): continue
			if artillery_first and record.batch_plan.members[identity].role!=3: continue
			selected.append(identity)
	for identity in selected: proposed.identities.append(identity)
	var targets := LegionTransitExecutor._column_targets(world,transit,proposed,proposed.progress)
	if targets.size()!=proposed.identities.size(): return
	var can_admit := true
	var escorts := 0; var artillery := 0
	for identity in proposed.identities:
		var unit := LegionTransitExecutor._entity(world,commander,identity)
		if not LegionTransitExecutor._available(world,unit): continue
		if unit.tactical_role in [UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR]: escorts+=1
		if unit.tactical_role==UnitState.TacticalRole.FIREPOWER: artillery+=1
	if artillery>0 and escorts<2: can_admit=false
	var prior := PackedInt32Array()
	var previous_index := transit.batches.size()-1 if new_batch else transit.batches.size()-2
	if previous_index>=0:
		for identity in transit.batches[previous_index].identities:
			var unit := LegionTransitExecutor._entity(world,commander,identity)
			if LegionTransitExecutor._available(world,unit): prior.append(unit.entity_id)
	for index in range(selected.size()):
		var identity: int = selected[index]
		var unit := LegionTransitExecutor._entity(world,commander,identity)
		var slot := record.spatial.slots[identity]
		var target := targets[old_count+index]
		if state.entities[identity]!=unit.entity_id:
			state.entities[identity]=unit.entity_id; state.approached[identity]=0; slot.staging_since=-1
			transit.gather_navigation[identity]=LegionGatherNavigation.State.new()
		if state.goals[identity].distance_to(target)>6.0: slot.staging_since=-1
		state.goals[identity]=target
		var tangent := (LegionTransitGeometry.point_at(transit.path,proposed.progress+1)-LegionTransitGeometry.point_at(transit.path,proposed.progress)).normalized()
		var approach := target-tangent*96.0
		# The rear is an approach region, not a single obligatory occupied point.
		# A friendly waiting body must not permanently lock that intermediate
		# waypoint when a unit has already physically reached the safe rear side.
		var delta := unit.position-target
		var from_rear := delta.dot(tangent)<=-64.0 and absf(delta.dot(tangent.orthogonal()))<=128.0 and delta.length()<=192.0
		if state.approached[identity]==0 and (unit.position.distance_to(approach)<=6.0 or from_rear): state.approached[identity]=1
		var goal := target if state.approached[identity]!=0 else approach
		slot.entity_id=unit.entity_id; slot.admitted=false; slot.at_destination=false
		LegionSpatialExecutor._set_target(world,unit,slot,goal,visible,true)
		var detour := LegionGatherNavigation.route(world,unit,goal,transit.gather_navigation[identity])
		if detour.size()>1 and not LegionProtectionPlanner.route_adds_exposure(detour,visible,unit.faction_id): slot.path=detour; slot.path_index=1
		unit.legion_slot=slot; unit.desired_position=slot.target
		unit.local_engagement_active=false; unit.local_engagement_returning=false
		unit.legion_motion=LegionMotionConstraint.new()
		unit.legion_motion.ground_radius=32.0; unit.legion_motion.transit_path=transit.path
		unit.legion_motion.previous_batch=prior.duplicate()
		var safe := slot.reason!=&"PATH_UNAVAILABLE" and not LegionProtectionPlanner.route_adds_exposure(PackedVector2Array([unit.position,target]),visible,unit.faction_id)
		if state.approached[identity]!=0 and unit.position.distance_to(target)<=6.0 and safe:
			if slot.staging_since<0: slot.staging_since=world.current_tick
			if world.current_tick-slot.staging_since<20: can_admit=false
		else:
			slot.staging_since=-1; can_admit=false
	if not can_admit: return
	# Commit only after the real units have reached their reserved rear slots.
	proposed.column_targets=targets; proposed.targets_progress=proposed.progress
	proposed.depth=(ceili(proposed.identities.size()/float(transit.columns))-1)*48.0+64.0
	proposed.gather_phase=2; proposed.admitted=true
	if new_batch:
		transit.batches.append(proposed)
		var plan_batch := LegionBatchPlanner.Batch.new()
		plan_batch.identities=proposed.identities.duplicate(); plan_batch.depth=proposed.depth
		record.batch_plan.batches.append(plan_batch)
	else:
		last.identities=proposed.identities; last.column_targets=targets; last.targets_progress=last.progress; last.depth=proposed.depth
		record.batch_plan.batches[-1].identities=proposed.identities.duplicate()
		record.batch_plan.batches[-1].depth=proposed.depth
	for identity in selected:
		record.spatial.slots[identity].admitted=true
		record.batch_plan.pending_identities.remove_at(record.batch_plan.pending_identities.find(identity))
		var member := record.batch_plan.members[identity]
		member.batch=record.batch_plan.batches.size()-1
		member.ordinal=proposed.identities.find(identity)
		member.offset=Vector2(-record.batch_plan.batches[-1].depth_start-floori(member.ordinal/3.0)*48.0,(member.ordinal%3-1)*48.0)
	LegionBatchPlanner._evaluate(record.batch_plan)
