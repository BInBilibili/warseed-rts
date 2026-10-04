class_name LegionArtilleryGuard
extends RefCounted

class Assignment extends RefCounted:
	var entity_id := 0
	var gun_id := 0
	var origin := Vector2.ZERO
	var destination := Vector2(INF,INF)
	var last_adjustment := -1000

class Group extends RefCounted:
	var intent := ""
	var members: Dictionary[int,Assignment] = {}

var groups: Dictionary[StringName,Group] = {}

func clear(commander_id: StringName) -> void:
	groups.erase(commander_id)

func prepare(world: SimulationWorld, commander: CommanderState, record: LegionFormationState, view: WorldSnapshot, grid: LogicGrid, finder: GridPathfinder, policy: LegionArtilleryPolicy, state: LegionArtilleryState, site_ids: PackedInt32Array, target: Vector2, intent: String, authorized_entities: PackedInt32Array) -> void:
	state.guards_actionable=0; state.guards_positioned=0; state.guard_reason=&"NO_DEPLOYED_ARTILLERY"
	var id := commander.definition.definition_id
	if not target.is_finite(): clear(id); return
	var guns: Array[UnitSnapshot] = []
	for entity_id in commander.growth_slot_entities:
		var gun := view.get_unit(entity_id)
		if gun!=null and site_ids.has(entity_id) and not gun.is_moving and gun.position.distance_to(target)<=gun.attack_range:
			guns.append(gun)
	if guns.is_empty(): clear(id); return
	var key := intent+":"+str(state.target_entity_id)
	if not groups.has(id) or groups[id].intent!=key:
		var fresh := Group.new(); fresh.intent=key; groups[id]=fresh
	var group := groups[id]
	var active := PackedInt32Array()
	for member in record.batch_plan.members:
		if member.role not in [1,2] or member.identity>=commander.growth_unlocked_slots: continue
		if not authorized_entities.has(member.entity_id):
			group.members.erase(member.identity); continue
		var unit := world.units.get(member.entity_id) as UnitState
		var card := world.unit_cards.get(unit.unit_card_id) as UnitCardState if unit!=null else null
		var task := world.tasks.get(unit.assigned_task_id) as TaskState if unit!=null else null
		if not LegionSpatialExecutor.eligible(unit,card) or card.player_stopped or card.continuing_player_order or task!=null and task.phase in [TaskState.Phase.RETREATING,TaskState.Phase.EVADING]:
			group.members.erase(member.identity); continue
		active.append(member.identity); state.guards_actionable+=1
		if not group.members.has(member.identity) or group.members[member.identity].entity_id!=unit.entity_id:
			var fresh := Assignment.new(); fresh.entity_id=unit.entity_id; fresh.origin=unit.position
			group.members[member.identity]=fresh
		var assignment := group.members[member.identity]
		var gun: UnitSnapshot
		for candidate in guns:
			if candidate.entity_id==assignment.gun_id: gun=candidate; break
		if gun==null:
			var nearest := INF
			for candidate in guns:
				var path := finder.find_body_path(unit.position,candidate.position)
				var distance := LegionProtectionPlanner.path_length(path) if not path.is_empty() else INF
				if distance<nearest: nearest=distance; gun=candidate
			if gun==null: continue
			assignment.gun_id=gun.entity_id; assignment.destination=Vector2(INF,INF)
		var forward := (target-gun.position).normalized()
		if forward.is_zero_approx(): continue
		if _in_band(unit.position,gun.position,forward,policy) and _clear_site(grid,view,unit.position,unit.entity_id):
			state.guards_positioned+=1
			assignment.destination=unit.position
		elif assignment.destination.is_finite() and not _in_band(assignment.destination,gun.position,forward,policy):
			assignment.destination=Vector2(INF,INF)
		if not assignment.destination.is_finite() and world.current_tick-assignment.last_adjustment>=policy.relocation_interval_ticks:
			assignment.last_adjustment=world.current_tick
			# Keep successful placements stable, but do not strand unplaced guards
			# on the first gun that happened to finish deploying.
			var choices: Array[UnitSnapshot] = [gun]
			for candidate in guns:
				if candidate.entity_id!=gun.entity_id: choices.append(candidate)
			for candidate in choices:
				var direction := (target-candidate.position).normalized()
				var side := direction.orthogonal()
				var offsets: Array[Vector2] = []
				for depth in [policy.guard_preferred_distance,policy.guard_minimum_distance,policy.guard_maximum_distance]:
					for lateral in [0,-32,32,-64,64,-96,96,-128,128]:
						var offset := Vector2(depth,lateral)
						if offset.length()<=policy.guard_maximum_distance: offsets.append(offset)
					# Include the actual band edge, not just the interior grid:
					# a partly occupied band can have its only free space there.
					var edge := sqrt(maxf(0.0,policy.guard_maximum_distance*policy.guard_maximum_distance-depth*depth))
					offsets.append(Vector2(depth,-edge))
					offsets.append(Vector2(depth,edge))
				for index in range(offsets.size()):
					var offset := offsets[(index+member.identity)%offsets.size()]
					var at := candidate.position+direction*offset.x+side*offset.y
					if at.distance_to(assignment.origin)>GrowthCombatSystem.LEASH: continue
					if not _clear_site(grid,view,at,unit.entity_id): continue
					if _reserved(group,at,unit.entity_id): continue
					var route := finder.find_body_path(unit.position,at)
					if route.is_empty() or LegionProtectionPlanner.path_length(route)>GrowthCombatSystem.LEASH: continue
					assignment.gun_id=candidate.entity_id
					assignment.destination=at; break
				if assignment.destination.is_finite(): break
		if not assignment.destination.is_finite(): continue
		# Local guard preference never blocks the normal order when unavailable.
		var path := finder.find_body_path(unit.position,assignment.destination)
		if path.is_empty(): assignment.destination=Vector2(INF,INF); continue
		var slot := unit.legion_slot
		if slot==null:
			slot=LegionSpatialOrder.new(); slot.identity=member.identity
			slot.entity_id=unit.entity_id; slot.admitted=true
			unit.legion_slot=slot
		slot.target=assignment.destination; slot.path=path; slot.path_index=1
		slot.reason=&"ARTILLERY_GUARD"; slot.at_destination=false
		unit.desired_position=assignment.destination
	for identity in group.members.keys():
		if not active.has(identity): group.members.erase(identity)
	state.guard_reason=&"GUARDS_IN_POSITION" if state.guards_actionable>0 and state.guards_positioned==state.guards_actionable else &"GUARD_GAPS"

static func _in_band(at: Vector2, gun: Vector2, forward: Vector2, policy: LegionArtilleryPolicy) -> bool:
	var offset := at-gun
	return offset.dot(forward)>=policy.guard_minimum_distance-0.01 and offset.length()<=policy.guard_maximum_distance+0.01

static func _reserved(group: Group, at: Vector2, entity_id: int) -> bool:
	for assignment: Assignment in group.members.values():
		if assignment.entity_id!=entity_id and assignment.destination.is_finite() and assignment.destination.distance_to(at)<48.0: return true
	return false

static func _clear_site(grid: LogicGrid, view: WorldSnapshot, at: Vector2, entity_id: int) -> bool:
	if not LegionTransitGeometry.segment_fits(grid,at,at): return false
	for unit in view.units:
		if not unit.enabled or unit.entity_id==entity_id: continue
		if unit.faction_id!=view.observer_faction_id and not unit.is_visible_to_local_player: continue
		if unit.position.distance_to(at)<48.0: return false
	return true
