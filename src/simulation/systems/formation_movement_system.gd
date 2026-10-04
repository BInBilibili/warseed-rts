class_name FormationMovementSystem
extends RefCounted

const ARRIVAL_TOLERANCE := 6.0
const ANCHOR_MOVE_SPEED := 180.0
const ANCHOR_LAG_LIMIT := 120.0
const COLUMN_SPACING := 42.0
const PREFERRED_SEPARATION := 34.0
const HARD_SEPARATION := 24.0
const STUCK_TICK_LIMIT := 10
const CLEAR_CORRIDOR_TICKS := 5
const NARROW_CORRIDOR_WIDTH := 3
const MAX_RECOVERY_ATTEMPTS := 3
const LAGGED_ANCHOR_SPEED_SCALE := 0.25
const HISTORY_MARGIN := 36.0

var logic_grid: LogicGrid
var pathfinder: GridPathfinder
var sustained_recovery := false


func _init(new_logic_grid: LogicGrid, new_pathfinder: GridPathfinder, use_sustained_recovery: bool = false) -> void:
	sustained_recovery = use_sustained_recovery
	logic_grid = new_logic_grid
	pathfinder = new_pathfinder


func advance(formations: Dictionary, units: Dictionary, events: Array[SimulationEvent], current_tick: int) -> void:
	var formation_ids := formations.keys()
	formation_ids.sort()
	for formation_id in formation_ids:
		var formation := formations[formation_id] as FormationState
		if formation.is_moving:
			_advance_formation(formation, units, events, current_tick)


func _advance_formation(
	formation: FormationState,
	units: Dictionary,
	events: Array[SimulationEvent],
	current_tick: int
) -> void:
	var leader := units.get(formation.leader_entity_id) as UnitState
	if leader != null and leader.free_legion_movement and not formation.has_deployment_line:
		_advance_free(formation, units, events, current_tick)
		return
	if formation.legion_deployment!=null and formation.legion_deployment.status==LegionDeploymentPlan.Status.BLOCKED and formation.path_index>=formation.path.size(): return
	_update_mode(formation)
	var tangent := _get_tangent(formation)
	var recon_spread := _is_recon_formation(formation, units)
	var desired_positions := _create_desired_positions(formation, tangent, recon_spread)
	var all_close := true
	for entity_id in formation.member_entity_ids:
		var unit := units[entity_id] as UnitState
		if not unit.enabled or unit.legion_slot != null:
			continue
		unit.desired_position = desired_positions[entity_id]
		if unit.following_formation and unit.position.distance_to(unit.desired_position) > ANCHOR_LAG_LIMIT:
			all_close = false
	var speed_scale := 1.0 if all_close else LAGGED_ANCHOR_SPEED_SCALE
	_advance_anchor(formation, speed_scale)
	# Arrival is measured against the final deployed slots, never yesterday's column.
	if formation.strict_deployment_slots and formation.path_index >= formation.path.size():
		formation.mode = FormationState.MovementMode.WIDE
	tangent = _get_tangent(formation)
	desired_positions = _create_desired_positions(formation, tangent, recon_spread)

	var start_positions: Dictionary = {}
	for entity_id in formation.member_entity_ids:
		start_positions[entity_id] = (units[entity_id] as UnitState).position
	var committed_positions: Dictionary = {}
	for entity_id in formation.member_entity_ids:
		var unit := units[entity_id] as UnitState
		if not unit.enabled or not unit.following_formation or unit.legion_slot != null:
			continue
		unit.desired_position = desired_positions[entity_id]
		var before := unit.position
		var prior_recovery := unit.recovery_path.duplicate() if unit.legion_motion != null else PackedVector2Array()
		var prior_recovery_index := unit.recovery_path_index
		var was_recovering := unit.is_recovering
		var prior_attempts := unit.recovery_attempts
		var proposed := _propose_position(unit, formation, start_positions, units)
		if not unit.flexible_legion_movement: proposed = _enforce_hard_separation(entity_id, proposed, committed_positions, units)
		if not logic_grid.is_segment_walkable(before, proposed):
			proposed = _seek_position(before, unit.desired_position, unit.move_speed * SimulationWorld.TICK_SECONDS)
			if not logic_grid.is_segment_walkable(before, proposed):
				proposed = before
		var coupled_wait := false
		if unit.legion_motion != null:
			# Separation steering must not create extra travel for coupled units.
			proposed = before.move_toward(proposed,unit.move_speed*SimulationWorld.TICK_SECONDS)
			var limited := unit.legion_motion.constrain(before,proposed,entity_id,units,logic_grid,pathfinder)
			coupled_wait = limited != proposed
			proposed = limited
			if coupled_wait:
				unit.recovery_path = prior_recovery; unit.recovery_path_index = prior_recovery_index
				unit.is_recovering = was_recovering; unit.recovery_attempts = prior_attempts
		unit.position = proposed
		committed_positions[entity_id] = proposed
		if not coupled_wait:
			_update_stuck_state(unit, formation, before, events, current_tick)
		else:
			unit.ticks_without_progress = 0
			unit.progress_window_tick = current_tick; unit.progress_window_position = unit.position

	var members_arrived := formation.path_index >= formation.path.size()
	if formation.legion_deployment!=null and formation.legion_deployment.status==LegionDeploymentPlan.Status.BLOCKED: members_arrived=false
	var arrival_tolerance := LegionReformationSystem.policy.tolerance(formation.legion_deployment.spacing) if formation.legion_deployment!=null else ARRIVAL_TOLERANCE
	if members_arrived:
		formation.mode = FormationState.MovementMode.WIDE
		for entity_id in formation.member_entity_ids:
			var unit := units[entity_id] as UnitState
			if unit.enabled and unit.legion_slot != null:
				if not unit.legion_slot.at_destination or unit.legion_slot.reason==&"PATH_UNAVAILABLE" or unit.position.distance_to(unit.legion_slot.target)>ARRIVAL_TOLERANCE:
					members_arrived=false
					break
				continue
			if unit.enabled and unit.following_formation and (unit.position.distance_to(unit.desired_position)>arrival_tolerance or (not unit.flexible_legion_movement and LegionReformationSystem.damage_factor(unit)!=1.0)):
				members_arrived = false
				break
			if unit.enabled and unit.following_formation and unit.legion_motion != null and unit.legion_motion.constrain(unit.position,unit.desired_position,entity_id,units,logic_grid,pathfinder) != unit.desired_position:
				members_arrived = false
				break
			if unit.enabled and unit.following_formation and unit.legion_motion != null and (start_positions[entity_id] as Vector2).distance_to(unit.desired_position) > unit.move_speed*SimulationWorld.TICK_SECONDS+0.001:
				members_arrived = false
				break
	if formation.legion_deployment!=null:
		if members_arrived:
			if formation.deployment_ready_since<0: formation.deployment_ready_since=current_tick
			members_arrived=current_tick-formation.deployment_ready_since>=20
		else: formation.deployment_ready_since=-1
	if members_arrived:
		formation.is_moving = false
		formation.path = PackedVector2Array()
		formation.planned_route = PackedVector2Array()
		for entity_id in formation.member_entity_ids:
			var unit := units[entity_id] as UnitState
			if unit.enabled and unit.legion_slot != null:
				# This is completion of the original card destination. Keep the
				# actual position; even a final snap must not spend another budget.
				unit.has_move_target=false
				events.append(SimulationEvent.new(current_tick, SimulationEvent.Kind.UNIT_ARRIVED, entity_id))
				continue
			if unit.enabled and unit.following_formation:
				if formation.legion_deployment==null: unit.position = unit.desired_position
				unit.has_move_target = false
				events.append(SimulationEvent.new(current_tick, SimulationEvent.Kind.UNIT_ARRIVED, entity_id))


func _advance_anchor(formation: FormationState, speed_scale: float = 1.0) -> void:
	if formation.path_index >= formation.path.size():
		return
	var travel_remaining := clampf(formation.anchor_speed_limit,0.0,ANCHOR_MOVE_SPEED) * SimulationWorld.TICK_SECONDS * speed_scale
	var retained_distance := COLUMN_SPACING * (formation.member_entity_ids.size() - 1) + HISTORY_MARGIN
	while travel_remaining > 0.0 and formation.path_index < formation.path.size():
		var waypoint := formation.path[formation.path_index]
		var offset := waypoint - formation.anchor_position
		if offset.length() <= travel_remaining:
			formation.anchor_position = waypoint
			formation.append_anchor_history(formation.anchor_position, retained_distance)
			travel_remaining -= offset.length()
			formation.path_index += 1
		else:
			formation.anchor_position += offset.normalized() * travel_remaining
			formation.append_anchor_history(formation.anchor_position, retained_distance)
			travel_remaining = 0.0


func _update_mode(formation: FormationState) -> void:
	var narrow_ahead := formation.forced_column_ticks > 0
	if formation.forced_column_ticks > 0:
		formation.forced_column_ticks -= 1
	var previous_cell := logic_grid.world_to_cell(formation.anchor_position)
	for index in range(formation.path_index, mini(formation.path_index + 4, formation.path.size())):
		var cell := logic_grid.world_to_cell(formation.path[index])
		var delta := cell - previous_cell
		var direction := Vector2i(signi(delta.x), signi(delta.y))
		if direction == Vector2i.ZERO:
			direction = Vector2i.RIGHT
		if logic_grid.get_corridor_width(cell, direction) < NARROW_CORRIDOR_WIDTH:
			narrow_ahead = true
			break
		previous_cell = cell
	if narrow_ahead:
		formation.mode = FormationState.MovementMode.COLUMN
		formation.clear_corridor_ticks = 0
	elif formation.mode == FormationState.MovementMode.COLUMN:
		formation.clear_corridor_ticks += 1
		if formation.clear_corridor_ticks >= CLEAR_CORRIDOR_TICKS:
			formation.mode = FormationState.MovementMode.WIDE


func _get_tangent(formation: FormationState) -> Vector2:
	if formation.path_index < formation.path.size():
		var offset := formation.path[formation.path_index] - formation.anchor_position
		if not offset.is_zero_approx():
			return offset.normalized()
	if formation.path.size() >= 2:
		return (formation.path[-1] - formation.path[-2]).normalized()
	return Vector2.RIGHT


func _create_desired_positions(formation: FormationState, tangent: Vector2, recon_spread: bool = false) -> Dictionary:
	var desired: Dictionary = {}
	var lateral := Vector2(-tangent.y, tangent.x)
	var deploying_on_line := formation.has_deployment_line and formation.path_index >= formation.path.size()
	for entity_id in formation.member_entity_ids:
		var slot_id := formation.get_slot_id(entity_id)
		var deployment_index := formation.deployment_entity_ids.find(entity_id)
		if formation.legion_deployment!=null and formation.path_index>=formation.path.size() and deployment_index>=0 and formation.legion_deployment.points.size()>deployment_index:
			desired[entity_id]=formation.legion_deployment.points[deployment_index]
		elif deploying_on_line:
			desired[entity_id] = formation.get_deployment_position(slot_id)
		elif formation.mode == FormationState.MovementMode.COLUMN:
			var history_position := formation.sample_anchor_history(COLUMN_SPACING * slot_id)
			desired[entity_id] = _get_walkable_history_position(formation, history_position, slot_id)
		else:
			var offset := formation.get_recon_offset(slot_id) if recon_spread else formation.get_wide_offset(slot_id)
			desired[entity_id] = formation.anchor_position + tangent * offset.x + lateral * offset.y
	if formation.strict_deployment_slots:
		# A wide slot can fall into a river/bank at bends even when the anchor
		# route is valid. Recovering forever toward that blocked slot cannot work.
		for id in desired:
			var preferred: Vector2 = desired[id]
			if logic_grid.is_world_position_walkable(preferred): continue
			var cell := logic_grid.world_to_cell(preferred)
			var found := false
			for ring in range(1, 9):
				if found: break
				for y in range(-ring, ring + 1):
					if found: break
					for x in range(-ring, ring + 1):
						if maxi(absi(x), absi(y)) != ring: continue
						var candidate := logic_grid.cell_to_world(cell + Vector2i(x, y))
						if not logic_grid.is_world_position_walkable(candidate): continue
						var free := true
						for other in desired:
							if other != id and candidate.distance_squared_to(desired[other]) < PREFERRED_SEPARATION * PREFERRED_SEPARATION:
								free = false
								break
						if free:
							desired[id] = candidate
							found = true
							break
	return desired


func _is_recon_formation(formation: FormationState, units: Dictionary) -> bool:
	return formation.uses_recon_spread(units)


func _get_walkable_history_position(
	formation: FormationState,
	preferred_position: Vector2,
	slot_id: int
) -> Vector2:
	if logic_grid.is_world_position_walkable(preferred_position):
		return preferred_position
	var fallback_distance := COLUMN_SPACING * slot_id
	var step_count := ceili(fallback_distance / 12.0)
	for step in range(step_count + 1):
		var candidate := formation.sample_anchor_history(maxf(0.0, fallback_distance - step * 12.0))
		if logic_grid.is_world_position_walkable(candidate):
			return candidate
	return formation.anchor_position


func _propose_position(unit: UnitState, formation: FormationState, positions: Dictionary, units: Dictionary = {}) -> Vector2:
	if unit.flexible_legion_movement:
		var desired := unit.desired_position
		if not LegionTransitGeometry.segment_fits(logic_grid,desired,desired): desired=formation.anchor_position
		var route := pathfinder.find_body_path(unit.position,desired)
		if route.size()<2: return unit.position
		unit.desired_position=desired
		return unit.position.move_toward(route[1],unit.move_speed*SimulationWorld.TICK_SECONDS)
	if unit.reformation!=null and unit.reformation.phase==LegionReformationState.Phase.REFORMING:
		var route := unit.reformation.route
		return _seek_position(unit.position,route[1] if route.size()>1 else unit.reformation.target,unit.move_speed*SimulationWorld.TICK_SECONDS)
	if unit.is_recovering and unit.recovery_path_index < unit.recovery_path.size():
		var recovery_target := unit.recovery_path[unit.recovery_path_index]
		var recovery_position := _seek_position(unit.position, recovery_target, unit.move_speed * SimulationWorld.TICK_SECONDS)
		if recovery_position.distance_to(recovery_target) <= ARRIVAL_TOLERANCE:
			unit.recovery_path_index += 1
			if unit.recovery_path_index >= unit.recovery_path.size():
				unit.is_recovering = false
				unit.recovery_path = PackedVector2Array()
				unit.recovery_path_index = 0
				unit.recovery_attempts = 0
		return recovery_position

	var seek := unit.desired_position - unit.position
	var steering := seek.normalized() if not seek.is_zero_approx() else Vector2.ZERO
	for other_id in formation.member_entity_ids:
		if other_id == unit.entity_id:
			continue
		if units.has(other_id) and LegionReformationSystem.ignores_pair(unit,units[other_id]): continue
		var offset := unit.position - (positions[other_id] as Vector2)
		var distance := offset.length()
		if distance < PREFERRED_SEPARATION:
			if distance <= 0.001:
				offset = Vector2.RIGHT.rotated(float((unit.entity_id * 17 + other_id * 31) % 8) * PI / 4.0)
				distance = 1.0
			steering += offset.normalized() * (PREFERRED_SEPARATION - distance) / PREFERRED_SEPARATION * 0.45
	if steering.is_zero_approx():
		return unit.position
	var max_travel := unit.move_speed * SimulationWorld.TICK_SECONDS
	return unit.position + steering.normalized() * minf(max_travel, unit.position.distance_to(unit.desired_position))


func _seek_position(from_position: Vector2, target_position: Vector2, max_travel: float) -> Vector2:
	var offset := target_position - from_position
	if offset.length() <= max_travel:
		return target_position
	return from_position + offset.normalized() * max_travel


func _enforce_hard_separation(entity_id: int, proposed: Vector2, committed: Dictionary, units: Dictionary = {}) -> Vector2:
	for other_id in committed.keys():
		if units.has(entity_id) and units.has(other_id) and LegionReformationSystem.ignores_pair(units[entity_id],units[other_id]): continue
		var other_position := committed[other_id] as Vector2
		if proposed.distance_to(other_position) < HARD_SEPARATION:
			var offset := proposed - other_position
			if offset.is_zero_approx():
				offset = Vector2.RIGHT if entity_id > int(other_id) else Vector2.LEFT
			return other_position + offset.normalized() * HARD_SEPARATION
	return proposed


func _update_stuck_state(
	unit: UnitState,
	formation: FormationState,
	before: Vector2,
	events: Array[SimulationEvent],
	current_tick: int
) -> void:
	if unit.position.distance_to(unit.desired_position) <= ARRIVAL_TOLERANCE:
		unit.ticks_without_progress = 0
		unit.progress_window_tick = current_tick
		unit.progress_window_position = unit.position
		return
	var oscillating := false
	if sustained_recovery:
		if unit.progress_window_tick < 0:
			unit.progress_window_tick = current_tick
			unit.progress_window_position = before
		elif current_tick - unit.progress_window_tick >= 20:
			oscillating = unit.position.distance_to(unit.progress_window_position) < 32.0
			unit.progress_window_tick = current_tick
			unit.progress_window_position = unit.position
			if oscillating: unit.ticks_without_progress = STUCK_TICK_LIMIT
	if not oscillating and unit.position.distance_to(before) >= 0.5:
		unit.ticks_without_progress = 0
		if not unit.is_recovering:
			unit.recovery_attempts = 0
		return
	unit.ticks_without_progress += 1
	if unit.ticks_without_progress < STUCK_TICK_LIMIT:
		return
	unit.ticks_without_progress = 0
	unit.recovery_attempts += 1
	events.append(SimulationEvent.new(current_tick, SimulationEvent.Kind.UNIT_STUCK, unit.entity_id))
	if unit.recovery_attempts <= MAX_RECOVERY_ATTEMPTS or sustained_recovery and oscillating:
		var fallback_positions := PackedVector2Array()
		for index in range(formation.anchor_history.size() - 1, -1, -1):
			fallback_positions.append(formation.anchor_history[index])
		var recovery_path := pathfinder.find_path_to_first_reachable(
			unit.position,
			unit.desired_position,
			fallback_positions
		)
		if not recovery_path.is_empty():
			unit.recovery_path = recovery_path
			unit.recovery_path_index = 1
			unit.is_recovering = unit.recovery_path.size() > 1
	formation.forced_column_ticks = CLEAR_CORRIDOR_TICKS * 2

# Independent paths preserve explicit route points without rank offsets,
# collective lag limits, or waiting for a commander/escort to form up.
func _advance_free(formation: FormationState, units: Dictionary, events: Array[SimulationEvent], tick: int) -> void:
	_advance_anchor(formation)
	var destination := formation.target_position
	var waypoints := PackedVector2Array() if formation.local_engagement_active or formation.local_engagement_returning else formation.planned_route.duplicate()
	if waypoints.is_empty() or waypoints[-1] != destination: waypoints.append(destination)
	var intent := str([formation.formation_id,formation.order_kind,waypoints])
	var arrived := true
	for id in formation.member_entity_ids:
		var unit := units[id] as UnitState
		if not unit.enabled or not unit.following_formation: continue
		if unit.legion_slot != null:
			unit.recovery_path.clear()
			arrived = false
			continue
		if unit.free_march_intent != intent:
			unit.free_march_intent = intent
			unit.free_march_destination = _free_landing(unit,destination,units)
			unit.free_march_waypoints = waypoints.duplicate()
			unit.free_march_waypoints[-1] = unit.free_march_destination
			unit.free_march_waypoint_index = 0
			unit.recovery_path.clear()
		if unit.free_march_revision != logic_grid.revision:
			unit.free_march_revision = logic_grid.revision
			unit.recovery_path.clear()
		var budget := unit.move_speed * SimulationWorld.TICK_SECONDS
		while budget > 0.001 and unit.free_march_waypoint_index < unit.free_march_waypoints.size():
			var waypoint := unit.free_march_waypoints[unit.free_march_waypoint_index]
			if unit.position.distance_to(waypoint) <= ARRIVAL_TOLERANCE:
				unit.free_march_waypoint_index += 1
				unit.recovery_path.clear()
				continue
			if unit.recovery_path.is_empty():
				unit.recovery_path = pathfinder.find_body_path(unit.position,waypoint)
				unit.recovery_path_index = 1
			if unit.recovery_path_index >= unit.recovery_path.size(): break
			var point := unit.recovery_path[unit.recovery_path_index]
			var before := unit.position
			var proposed := before.move_toward(point,budget)
			var next := proposed
			if unit.legion_motion != null: next = unit.legion_motion.constrain(before,next,id,units,logic_grid,pathfinder)
			unit.position = next
			budget -= before.distance_to(next)
			if next != proposed: break
			if next.distance_to(point) <= 0.001: unit.recovery_path_index += 1
			else: break
		unit.desired_position = unit.free_march_destination
		unit.has_move_target = unit.free_march_waypoint_index < unit.free_march_waypoints.size()
		if unit.has_move_target: arrived = false
	if arrived:
		formation.anchor_position = destination
		formation.is_moving = false
		formation.path.clear(); formation.planned_route.clear()
		for id in formation.member_entity_ids:
			var unit := units[id] as UnitState
			if unit.enabled and unit.following_formation:
				unit.has_move_target = false
				events.append(SimulationEvent.new(tick,SimulationEvent.Kind.UNIT_ARRIVED,id))

# Reserve a nearby clear landing point once per order, independent of role,
# rank, commander position or other members' progress. No marching slots.
func _free_landing(unit: UnitState, goal: Vector2, units: Dictionary) -> Vector2:
	var occupied := PackedVector2Array()
	for other: UnitState in units.values():
		if not other.enabled or other.entity_id == unit.entity_id or other.faction_id != unit.faction_id: continue
		occupied.append(other.free_march_destination if other.free_legion_movement and other.has_move_target and other.free_march_destination.is_finite() else other.position)
	var mirror := -1.0 if unit.faction_id == SimulationWorld.ENEMY_PLAYER_ID else 1.0
	for ring in range(9):
		for x in range(-ring,ring+1):
			for y in range(-ring,ring+1):
				if maxi(absi(x),absi(y)) != ring: continue
				var point := goal + Vector2(x,y)*LegionBatchPlanner.SPACING*mirror
				if not LegionTransitGeometry.segment_fits(logic_grid,point,point): continue
				var clear := true
				for other in occupied:
					if point.distance_to(other) < PREFERRED_SEPARATION + 2.0*ARRIVAL_TOLERANCE: clear = false; break
				if clear and not pathfinder.find_body_path(unit.position,point).is_empty(): return point
	# Tight space remains traversable; actual overlap retains its normal cost.
	return goal
