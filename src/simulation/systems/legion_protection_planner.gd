class_name LegionProtectionPlanner
extends RefCounted

class State extends RefCounted:
	var escort_id := 0
	var facing := Vector2.RIGHT
	var pending_facing := Vector2.RIGHT
	var pending_since := -1
	var retreat_version := -1
	var retreat_direction := Vector2.ZERO
	func duplicate_value() -> State:
		var copy := State.new()
		copy.escort_id = escort_id
		copy.facing = facing
		copy.pending_facing = pending_facing
		copy.pending_since = pending_since
		copy.retreat_version = retreat_version
		copy.retreat_direction = retreat_direction
		return copy

class Decision extends RefCounted:
	var state: State
	var reason: StringName = &"NO_CORE"
	var target := Vector2.ZERO
	var path := PackedVector2Array()
	var core_path_distance := INF
	var exposure := 0
	var safe := false
	var rejoining := false

static func core_eligible(unit: UnitSnapshot, faction: int) -> bool:
	return unit.faction_id == faction and unit.enabled and not unit.rejoin_pending and not unit.legion_returning and unit.control_state == UnitState.ControlState.AGENT_ASSIGNED and unit.tactical_role in [UnitState.TacticalRole.ASSAULT, UnitState.TacticalRole.ARMOR]

static func path_length(path: PackedVector2Array) -> float:
	var result := 0.0
	for index in range(1, path.size()): result += path[index-1].distance_to(path[index])
	return result

static func exposure_at(position: Vector2, visible: Array[UnitSnapshot], faction: int) -> int:
	var exposure := 0
	for enemy in visible:
		if enemy.enabled and enemy.is_visible_to_local_player and enemy.faction_id != faction and enemy.can_attack and position.distance_squared_to(enemy.position) <= pow(enemy.attack_range + 32.0, 2): exposure += 1
	return exposure

static func route_adds_exposure(path: PackedVector2Array, visible: Array[UnitSnapshot], faction: int) -> bool:
	if path.is_empty(): return true
	for enemy in visible:
		if not enemy.enabled or not enemy.is_visible_to_local_player or enemy.faction_id == faction or not enemy.can_attack: continue
		var radius_squared := pow(enemy.attack_range+32.0,2)
		# Existing exposure may be escaped. Never enter another known weapon's
		# coverage on the way to an apparently safe endpoint.
		if path[0].distance_squared_to(enemy.position) <= radius_squared: continue
		for index in range(1,path.size()):
			var closest := Geometry2D.get_closest_point_to_segment(enemy.position,path[index-1],path[index])
			if closest.distance_squared_to(enemy.position) <= radius_squared: return true
	return false

static func route(grid: LogicGrid, finder: GridPathfinder, origin: Vector2, target: Vector2) -> PackedVector2Array:
	if grid.centrally_symmetric_navigation:
		return finder.find_body_path(origin,target)
	if not grid.is_world_position_walkable(target): return PackedVector2Array()
	if grid.is_segment_walkable(origin, target): return PackedVector2Array([origin, target])
	var path := finder.find_path(origin, target)
	if path.size() < 2: return PackedVector2Array()
	for index in range(1, path.size()):
		if not grid.is_segment_walkable(path[index-1], path[index]): return PackedVector2Array()
	return path

static func update_directions(state: State, hero: UnitSnapshot, visible: Array[UnitSnapshot], tick: int, travel_direction: Vector2, retreat_version: int, retreat_direction: Vector2) -> void:
	if retreat_version >= 0 and retreat_version != state.retreat_version:
		state.retreat_version = retreat_version
		state.retreat_direction = retreat_direction.normalized()
	var wanted := travel_direction.normalized() if not travel_direction.is_zero_approx() else state.facing
	var closest := INF
	var selected := 0
	var immediate := false
	var sorted := visible.duplicate()
	sorted.sort_custom(func(a: UnitSnapshot, b: UnitSnapshot) -> bool: return a.entity_id < b.entity_id)
	for enemy in sorted:
		if not enemy.enabled or not enemy.is_visible_to_local_player or enemy.faction_id == hero.faction_id or not enemy.can_attack: continue
		var distance := hero.position.distance_squared_to(enemy.position)
		var direct: bool = enemy.attack_target_entity_id == hero.entity_id and distance <= pow(enemy.attack_range + 32.0, 2)
		if selected == 0 or direct and not immediate or direct == immediate and distance < closest:
			closest = distance
			selected = enemy.entity_id
			wanted = (enemy.position - hero.position).normalized()
			immediate = direct
	if wanted.is_zero_approx(): wanted = state.facing
	if absf(state.facing.angle_to(wanted)) <= deg_to_rad(5):
		state.pending_since = -1
		return
	if immediate and selected != 0:
		state.facing = wanted
		state.pending_since = -1
		return
	if state.pending_since < 0 or absf(state.pending_facing.angle_to(wanted)) > deg_to_rad(15):
		state.pending_facing = wanted
		state.pending_since = tick
	elif tick - state.pending_since >= 20:
		state.facing = wanted
		state.pending_since = -1

static func plan(previous: State, hero: UnitSnapshot, own: Array[UnitSnapshot], visible: Array[UnitSnapshot], profile: StringName, grid: LogicGrid, finder: GridPathfinder, tick: int, travel_direction: Vector2, retreat_version: int = -1, retreat_direction: Vector2 = Vector2.ZERO) -> Decision:
	var result := Decision.new()
	result.state = previous.duplicate_value()
	result.target = hero.position
	if profile not in LegionTemplate.PROFILE_IDS:
		result.reason = &"INVALID_PROFILE"
		return result
	update_directions(result.state, hero, visible, tick, travel_direction, retreat_version, retreat_direction)
	var core: Array[UnitSnapshot] = []
	for unit in own:
		if core_eligible(unit, hero.faction_id): core.append(unit)
	if core.is_empty():
		result.state.escort_id = 0
		return result
	core.sort_custom(func(a: UnitSnapshot, b: UnitSnapshot) -> bool:
		var first := hero.position.distance_squared_to(a.position)
		var second := hero.position.distance_squared_to(b.position)
		return first < second or first == second and a.entity_id < b.entity_id)
	var escort := core[0]
	var local: UnitSnapshot = null
	for unit in core:
		if unit.position.distance_squared_to(hero.position) > 240.0*240.0: continue
		var access := route(grid,finder,hero.position,unit.position)
		if access.is_empty() or path_length(access) > 240.0: continue
		if local == null: local = unit
		if unit.entity_id == previous.escort_id: local = unit; break
	if local != null: escort = local
	result.rejoining = local == null
	result.state.escort_id = escort.entity_id
	var offset := 128.0
	if profile in [&"spear", &"guardian"]: offset = 160.0
	elif profile == &"gunner": offset = 192.0
	var best_score := INF
	var found := false
	var available := false
	for degrees in [0,30,-30,60,-60,90,-90,180]:
		var candidate: Vector2 = escort.position - result.state.facing.rotated(deg_to_rad(degrees)) * offset
		var occupied := false
		for unit in own:
			if unit.enabled and unit.faction_id == hero.faction_id and unit.entity_id != hero.entity_id and unit.position.distance_squared_to(candidate) < 24.0 * 24.0: occupied = true; break
		if occupied: continue
		var core_path := route(grid, finder, candidate, escort.position)
		if core_path.is_empty(): continue
		var core_distance := path_length(core_path)
		if core_distance > 240.0: continue
		var hero_path := route(grid, finder, hero.position, candidate)
		if hero_path.is_empty(): continue
		available = true
		var exposure := exposure_at(candidate,visible,hero.faction_id)
		if exposure > 0 or route_adds_exposure(hero_path,visible,hero.faction_id):
			result.exposure = maxi(result.exposure, exposure)
			continue
		var score := absf(degrees) * 10000.0 + path_length(hero_path)
		if score >= best_score: continue
		best_score = score
		found = true
		result.target = candidate
		result.path = hero_path
		result.core_path_distance = core_distance
	result.safe = found
	result.reason = (&"REJOIN_CORE" if result.rejoining else &"PROTECTED_TARGET") if found else (&"EXPOSED" if available else &"PATH_UNAVAILABLE")
	if found: result.exposure = 0
	return result
