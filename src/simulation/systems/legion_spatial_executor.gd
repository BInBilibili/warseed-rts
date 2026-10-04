class_name LegionSpatialExecutor
extends RefCounted

class Layout extends RefCounted:
	var valid := true
	var offsets: Array[Vector2] = []

static var _layouts: Dictionary[StringName,Layout] = {}

static func protection_offset(profile: StringName) -> float:
	if profile in [&"spear",&"guardian"]: return 160.0
	return 192.0 if profile==&"gunner" else 128.0

static func layout(profile: StringName, action: LegionSpatialState.Action) -> Layout:
	var key := StringName(String(profile)+":"+str(action))
	if _layouts.has(key): return _layouts[key]
	var result := Layout.new()
	var template := LegionTemplate.find(profile)
	if template==null: result.valid=false; return result
	var indices := [0,0,0,0]
	var hero_slot := Vector2(-protection_offset(profile),0)
	# Reserve the entire authorized roster once. Later growth/death never
	# reranks survivors or moves their targets to accommodate another role.
	for role in template.slot_roles():
		var preferred := offset(profile,role,indices[role],action); indices[role]+=1
		var found := false
		for ring in range(9):
			if found: break
			for longitudinal in range(-ring,ring+1):
				if found: break
				for lateral in range(-ring,ring+1):
					if maxi(absi(longitudinal),absi(lateral))!=ring: continue
					if role==3 and longitudinal>0: continue
					var candidate := preferred+Vector2(longitudinal,lateral)*48.0
					# The commander is the 61st physical body. Reserve both its
					# cell and the intended core distance instead of filling its
					# protection pocket with later-unlocked soldiers.
					var exclusion := protection_offset(profile) if role in [1,2] else 48.0
					if candidate.distance_squared_to(hero_slot)<exclusion*exclusion-0.01: continue
					var free := true
					for occupied in result.offsets:
						if candidate.distance_squared_to(occupied)<48.0*48.0-0.01: free=false; break
					if free:
						result.offsets.append(candidate); found=true; break
		if not found: result.valid=false; return result
	_layouts[key]=result
	return result

# Stable spatial ownership is separate from cards and recruitment identities.
# The legacy card mover advances command anchors but cannot also move members
# owned here. Internal slot arrival is not task/command completion.
static func eligible(unit: UnitState, card: UnitCardState) -> bool:
	return unit != null and unit.enabled and not unit.rejoin_pending and not unit.legion_returning and unit.control_state == UnitState.ControlState.AGENT_ASSIGNED and card != null and card.uses_legion_slots()

static func relief_required(record: LegionFormationState, hero: UnitState, escort: UnitState, world: SimulationWorld) -> bool:
	if escort == null or not escort.enabled: return false
	var path := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,hero.position,escort.position)
	return path.is_empty() or LegionProtectionPlanner.path_length(path) > 240.0

static func _source(world: SimulationWorld, commander: CommanderState, record: LegionFormationState) -> FormationState:
	if commander.formation_mode != CommanderState.FormationMode.FREE:
		var resting: FormationState
		for card_id in commander.subordinate_unit_card_ids:
			var card := world.unit_cards.get(card_id) as UnitCardState
			if card == null or card.player_stopped or not card.uses_legion_slots() or card.member_entity_ids.is_empty(): continue
			var formation := world.formations.get(card.formation_id) as FormationState
			if formation == null: continue
			if formation.is_moving: return formation
			if resting == null: resting = formation
		return resting
	var escort := world.units.get(record.state.escort_id) as UnitState
	if escort != null:
		var card := world.unit_cards.get(escort.unit_card_id) as UnitCardState
		if eligible(escort,card): return world.formations.get(card.formation_id) as FormationState
	for id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards.get(id) as UnitCardState
		if card != null and card.uses_legion_slots() and not card.member_entity_ids.is_empty():
			return world.formations.get(card.formation_id) as FormationState
	return null

static func _action(commander: CommanderState, source: FormationState) -> LegionSpatialState.Action:
	if commander.posture == CommanderState.Posture.DISENGAGE or commander.growth_recovering: return LegionSpatialState.Action.RETREAT
	if commander.deployment_goal==source.order_destination and not commander.deployment_facing.is_zero_approx(): return LegionSpatialState.Action.MOVE
	if not source.is_moving: return LegionSpatialState.Action.DEFEND
	if source.order_kind in [FormationState.OrderKind.ATTACK_MOVE,FormationState.OrderKind.ATTACK_TARGET]: return LegionSpatialState.Action.ATTACK
	return LegionSpatialState.Action.MOVE

# Alternating fixed columns do not recenter surviving members after casualties
# or move existing slots when growth unlocks another identity.
static func offset(profile: StringName, role: int, ordinal: int, action: LegionSpatialState.Action) -> Vector2:
	var column := ordinal % 6
	var side := (1.0 if column % 2 == 0 else -1.0) * (floori(column/2.0)*48.0+24.0)
	var row := floori(ordinal/6.0)*48.0
	if action == LegionSpatialState.Action.MOVE:
		var lane: float = [-168.0,-48.0,72.0,168.0][role]
		return Vector2(-floori(ordinal/2.0)*48.0 + (48.0 if role == 2 else (-144.0 if role == 3 else 0.0)),lane+(ordinal%2)*48.0)
	if role == 0:
		if profile == &"sentinel" and ordinal < 4: return Vector2(192.0,(ordinal-1.5)*48.0)
		return Vector2(-144.0-row,(1.0 if ordinal%2==0 else -1.0)*(192.0+floori(column/2.0)*48.0))
	var x: float = [0.0,0.0,96.0,-144.0][role]-row
	if profile == &"spear" and role == 2: x=144.0-absf(side)*0.4-row
	if profile == &"guardian": x=[0.0,0.0,96.0,-160.0][role]-row
	if profile == &"gunner": x=[0.0,48.0,96.0,-96.0][role]-row
	if profile == &"sentinel": x=[0.0,0.0,96.0,-144.0][role]-row
	if profile == &"ranger": x=[0.0,48.0,144.0,-144.0][role]-row
	if action == LegionSpatialState.Action.DEFEND: x-=absf(side)*0.2
	return Vector2(x,side)

static func prepare(world: SimulationWorld, commander: CommanderState, record: LegionFormationState, visible: Array[UnitSnapshot]) -> void:
	var hero := world.units.get(commander.hero_entity_id) as UnitState
	if hero == null or not hero.enabled or commander.legion_regrouping or hero.control_state != UnitState.ControlState.AGENT_ASSIGNED:
		record.spatial = LegionSpatialState.new()
		return
	if commander.posture == CommanderState.Posture.HOLD: return
	var source := _source(world,commander,record)
	if source == null or record.batch_plan == null: return
	var state := record.spatial
	var wanted := _action(commander,source)
	var escort := world.units.get(record.state.escort_id) as UnitState
	var relief := wanted != LegionSpatialState.Action.RETREAT and relief_required(record,hero,escort,world)
	if not state.initialized:
		state.initialized=true; state.anchor=hero.position+record.state.facing*protection_offset(commander.definition.profile.profile_id)
		state.facing=record.state.facing; state.action=wanted; state.changed_tick=world.current_tick
		state.hero_offset=hero.position-state.anchor
		for identity in range(60):
			var slot := LegionSpatialOrder.new(); slot.identity=identity
			slot.admitted=identity<commander.growth_unlocked_slots
			state.slots.append(slot)
	var changed := wanted != state.action
	if changed and (wanted == LegionSpatialState.Action.RETREAT or world.current_tick-state.changed_tick >= 20):
		state.action=wanted; state.changed_tick=world.current_tick
		# A withdrawal starts from actual positions, not a 180 degree slot swap.
		if wanted == LegionSpatialState.Action.RETREAT:
			state.hero_offset=hero.position-state.anchor
			for slot in state.slots:
				var member := world.units.get(slot.entity_id) as UnitState
				if member != null and member.enabled:
					var delta := member.position-state.anchor
					slot.offset=Vector2(delta.dot(state.facing),delta.dot(state.facing.orthogonal()))
	if LegionTransitExecutor.prepare(world,commander,record,source,visible): return
	state.relief=relief
	if relief:
		# Hold the local remnant while its selected real core comes back. This is
		# explicitly unprotected, not a scout-to-armor qualification shortcut.
		state.anchor=hero.position; state.reason=&"REJOIN_CORE"
	else:
		_update_anchor(world,record,source)
	if state.anchor.distance_to(commander.deployment_goal)<=6.0 and not commander.deployment_facing.is_zero_approx(): state.facing=commander.deployment_facing.normalized()
	state.ready=0; state.eligible=0
	var arrived := 0
	var geometry := layout(commander.definition.profile.profile_id,state.action)
	if not geometry.valid: state.reason=&"PATH_UNAVAILABLE"; return
	if state.action!=LegionSpatialState.Action.RETREAT and not relief:
		var identities := PackedInt32Array([60])
		var member_ids := PackedInt32Array([commander.hero_entity_id])
		for member in record.batch_plan.members:
			var candidate := world.units.get(member.entity_id) as UnitState
			if candidate!=null and candidate.enabled and candidate.hero_commander_id.is_empty():
				identities.append(member.identity); member_ids.append(member.entity_id)
		var occupied := PackedVector2Array()
		for other: UnitState in world.units.values():
			if other.enabled and other.faction_id==commander.faction_id and not member_ids.has(other.entity_id): occupied.append(other.position)
		var deployment := LegionDeploymentPlanner.plan(commander.definition.profile.profile_id,state.action,identities,state.anchor,state.facing,world.logic_grid,occupied)
		if deployment.status in [LegionDeploymentPlan.Status.STANDARD,LegionDeploymentPlan.Status.COMPRESSED]:
			if state.deployment!=null and deployment.spacing>state.deployment.spacing:
				if state.expansion_clear_since<0: state.expansion_clear_since=world.current_tick
				if world.current_tick-state.expansion_clear_since<20:
					deployment=LegionDeploymentPlanner.plan(commander.definition.profile.profile_id,state.action,identities,state.anchor,state.facing,world.logic_grid,occupied,state.deployment.spacing)
			else: state.expansion_clear_since=-1
			state.deployment=deployment
		else:
			state.deployment=deployment; state.ready_since=-1
	for identity in range(60):
		var member := record.batch_plan.members[identity]
		var slot := state.slots[identity]
		var unit := world.units.get(member.entity_id) as UnitState
		var card := world.unit_cards.get(unit.unit_card_id) as UnitCardState if unit != null else null
		if not eligible(unit,card): slot.entity_id=0; continue
		slot.entity_id=unit.entity_id
		if state.action != LegionSpatialState.Action.RETREAT:
			slot.offset=state.deployment.offsets[identity] if state.deployment!=null and state.deployment.offsets.size()==61 else geometry.offsets[identity]
		slot.tolerance=LegionReformationSystem.policy.tolerance(state.deployment.spacing) if state.deployment!=null else 6.0
		var target := state.anchor+state.facing*slot.offset.x+state.facing.orthogonal()*slot.offset.y
		if not slot.admitted:
			var rear := -192.0
			for value in geometry.offsets: rear=minf(rear,value.x-96.0)
			var staging := state.anchor+state.facing*(rear-floori(identity/6.0)*48.0)+state.facing.orthogonal()*((identity%6-2.5)*48.0)
			var clear := not LegionProtectionPlanner.route_adds_exposure(LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,unit.position,target),visible,unit.faction_id)
			if unit.position.distance_to(staging)<=6.0 and clear and not relief:
				if slot.staging_since<0: slot.staging_since=world.current_tick
				if world.current_tick-slot.staging_since>=20: slot.admitted=true
			else: slot.staging_since=-1
			if not slot.admitted: target=staging
		if slot.admitted: state.eligible+=1
		if relief:
			if unit.entity_id == record.state.escort_id:
				target=hero.position+state.facing*128.0
			else:
				# Existing local members retain their actual safe positions; distant
				# unrelated scouts are not pulled across the map to this meeting.
				target=unit.position
		_set_target(world,unit,slot,target,visible,relief)
		var card_formation := world.formations.get(card.formation_id) as FormationState
		slot.at_destination = slot.admitted and not relief and state.route_index >= state.route.size() and state.anchor.distance_to(state.goal)<=6.0 and card_formation!=null and card_formation.order_destination.distance_to(state.goal)<=0.01
		slot.at_destination = slot.at_destination and state.ready_since>=0 and world.current_tick-state.ready_since>=20
		unit.legion_slot=slot
		unit.local_engagement_active=false; unit.local_engagement_returning=false
		unit.desired_position=slot.target
		if slot.admitted and unit.position.distance_to(slot.target)<=120.0 and slot.reason!=&"PATH_UNAVAILABLE": state.ready+=1
		if slot.admitted and slot.reason==&"IN_POSITION": arrived+=1
	if not relief:
		state.reason=&"IN_POSITION" if arrived==state.eligible else &"FORMING"
	# Only physical readiness gates normal advance; unavailable/manual recruits
	# do not enter its denominator. Original tasks and targets remain intact.
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards.get(card_id) as UnitCardState
		if card == null or not card.uses_legion_slots(): continue
		var formation := world.formations.get(card.formation_id) as FormationState
		if formation != null and (relief or state.ready < ceili(state.eligible*0.8) and state.action!=LegionSpatialState.Action.RETREAT): formation.anchor_speed_limit=0.0

static func _update_anchor(world: SimulationWorld, record: LegionFormationState, source: FormationState) -> void:
	var state := record.spatial
	if state.advanced_tick == world.current_tick: return
	state.advanced_tick=world.current_tick
	var intent := str([source.order_kind,source.order_destination,source.planned_route])
	if intent != state.intent:
		state.intent=intent; state.goal=source.order_destination
		state.route=source.planned_route.duplicate()
		if state.route.is_empty() or state.route[-1]!=state.goal: state.route.append(state.goal)
		state.route_index=0
	# Card completion clears its planned route without undoing physical arrival.
	# Consume reached nodes before the stationary/DEFEND branch so late cards
	# still receive their original destination's actual-arrival acknowledgement.
	while state.route_index<state.route.size() and state.anchor.distance_to(state.route[state.route_index])<=0.01:
		state.route_index+=1
	if state.action==LegionSpatialState.Action.DEFEND or not source.is_moving: return
	for slot in state.slots:
		var unit := world.units.get(slot.entity_id) as UnitState
		if unit!=null and unit.reformation!=null and unit.reformation.phase==LegionReformationState.Phase.REFORMING and unit.reformation.intent==state.intent: return
	if state.eligible>0 and state.ready<ceili(state.eligible*0.8) and state.action!=LegionSpatialState.Action.RETREAT: return
	if record.reason in [&"NO_CORE",&"EXPOSED",&"PATH_UNAVAILABLE",&"REJOIN_CORE"] and state.action!=LegionSpatialState.Action.RETREAT: return
	if state.route_index>=state.route.size(): return
	var path := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,state.anchor,state.route[state.route_index])
	if path.size()<2: state.reason=&"PATH_UNAVAILABLE"; return
	var next := state.anchor.move_toward(path[1],record.core_speed*SimulationWorld.TICK_SECONDS)
	if not world.logic_grid.is_segment_walkable(state.anchor,next): return
	# Spatial facing follows travel only during ordinary marching. Defending or
	# retreating never rotates every member toward a newly detected enemy.
	if state.action==LegionSpatialState.Action.MOVE and next.distance_squared_to(state.anchor)>0.01:
		state.facing=(next-state.anchor).normalized()
	state.anchor=next
	if state.anchor.distance_to(state.route[state.route_index])<=0.01: state.route_index+=1

static func _set_target(world: SimulationWorld, unit: UnitState, slot: LegionSpatialOrder, target: Vector2, visible: Array[UnitSnapshot], safe_only: bool) -> void:
	var path := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,unit.position,target)
	if path.is_empty() or safe_only and LegionProtectionPlanner.route_adds_exposure(path,visible,unit.faction_id):
		slot.target=unit.position; slot.path=PackedVector2Array(); slot.path_index=0; slot.reason=&"PATH_UNAVAILABLE"
		return
	slot.target=target; slot.path=path; slot.path_index=1
	slot.reason=&"IN_POSITION" if unit.position.distance_to(target)<=slot.tolerance else &"FORMING"

static func advance(world: SimulationWorld) -> void:
	var ids := world.units.keys(); ids.sort()
	for id: int in ids:
		var unit := world.units[id] as UnitState
		var slot := unit.legion_slot
		if slot == null or not unit.enabled: continue
		var remaining := unit.move_speed*SimulationWorld.TICK_SECONDS
		var collision := unit.legion_motion if unit.legion_motion!=null else LegionMotionConstraint.new()
		collision.ground_radius=32.0
		while remaining>0.001 and slot.path_index<slot.path.size():
			var waypoint := slot.path[slot.path_index]
			var before := unit.position
			var proposed := before.move_toward(waypoint,remaining)
			# A no-partner constraint still enforces swept physical occupancy.
			var accepted := collision.constrain(before,proposed,id,world.units,world.logic_grid,world.pathfinder)
			unit.position=accepted; remaining-=before.distance_to(accepted)
			if not accepted.is_equal_approx(proposed): break
			if accepted.distance_to(waypoint)>0.001: break
			slot.path_index+=1
		unit.desired_position=slot.target
		unit.has_move_target=unit.position.distance_to(slot.target)>slot.tolerance
		if not unit.has_move_target and slot.reason!=&"PATH_UNAVAILABLE": slot.reason=&"IN_POSITION"

static func refresh(world: SimulationWorld) -> void:
	if world.battle_definition==null or not world.battle_definition.growth_mode: return
	for id: StringName in world.legion_formation_system.records:
		var record := world.legion_formation_system.records[id]
		if not record.active: continue
		var commander := world.commanders.get(id) as CommanderState
		if commander==null: continue
		if commander.posture==CommanderState.Posture.HOLD:
			record.spatial.reason=&"COMMAND_HOLD"
			continue
		if commander.legion_regrouping:
			record.spatial=LegionSpatialState.new(); record.reason=&"REGROUPING"
			continue
		if record.spatial.flexible: continue
		var escort := world.units.get(record.state.escort_id) as UnitState
		if record.reason in [&"FORMING",&"IN_POSITION"] and (escort==null or not escort.enabled):
			record.reason=&"REJOIN_CORE"; record.state.escort_id=0; record.core_speed=0.0
		var state := record.spatial
		if state.transit.phase!=LegionTransitState.Phase.WIDE:
			LegionTransitExecutor.refresh(world,commander,record)
			continue
		state.ready=0; state.eligible=0
		var arrived := 0
		for slot in state.slots:
			var unit := world.units.get(slot.entity_id) as UnitState
			var card := world.unit_cards.get(unit.unit_card_id) as UnitCardState if unit!=null else null
			if not eligible(unit,card) or not slot.admitted: continue
			state.eligible+=1
			if slot.reason==&"PATH_UNAVAILABLE": continue
			if unit.position.distance_to(slot.target)<=120.0: state.ready+=1
			if unit.position.distance_to(slot.target)<=slot.tolerance and LegionReformationSystem.damage_factor(unit)==1.0: arrived+=1
		var hero := world.units.get(commander.hero_entity_id) as UnitState
		var ready := state.eligible>0 and arrived==state.eligible and not state.relief and state.anchor.distance_to(state.goal)<=6.0 and hero!=null and LegionReformationSystem.damage_factor(hero)==1.0 and not hero.has_move_target
		if state.deployment!=null and state.deployment.status==LegionDeploymentPlan.Status.BLOCKED: ready=false
		if ready:
			if state.ready_since<0: state.ready_since=world.current_tick
		else: state.ready_since=-1
		if not state.relief: state.reason=&"IN_POSITION" if ready and world.current_tick-state.ready_since>=20 else &"FORMING"
