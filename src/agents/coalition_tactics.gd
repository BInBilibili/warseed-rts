class_name CoalitionTactics
extends RefCounted

const Phase := CommanderTaskStageDefinition.Phase
const Mode := StaffPlanRequest.Coordination

static func configure_node(snapshot: WorldSnapshot, plan: StaffCourseOfAction, assignment: StaffPlanAssignment, node: CommanderTaskNodeSnapshot, navigator: GridPathfinder) -> bool:
	if plan.coordination == Mode.INDEPENDENT: return true
	if node.phase == Phase.RETREAT or node.phase == Phase.MUSTER: return true
	var objective := snapshot.get_strategic_region(plan.objective_region_id)
	var groups: Array[StringName] = []
	for item in plan.assignments:
		if not groups.has(item.commander_id): groups.append(item.commander_id)
	groups.sort()
	var group_index := groups.find(assignment.commander_id)
	var operation_origin := Vector2.ZERO
	for item in plan.assignments: operation_origin += item.route_points[0]
	operation_origin /= plan.assignments.size()
	var front := (objective.position - operation_origin).normalized()
	var lateral := Vector2(-front.y, front.x)
	var offset := (float(group_index) - float(groups.size()-1)/2.0) * 160.0
	var depth := 0.0
	match plan.formation:
		StaffPlanRequest.Formation.WEDGE: depth = absf(offset) * 0.8
		StaffPlanRequest.Formation.DEPTH:
			depth = group_index * 160.0
			offset = -64.0 if group_index % 2 == 0 else 64.0
	var card := snapshot.get_unit_card(assignment.card_id)
	var role_depth := 0.0
	if card.tactical_kind == TacticalAbilityDefinition.Kind.SUPPRESS: role_depth = 220.0
	elif card.tactical_kind == TacticalAbilityDefinition.Kind.OBSERVE: role_depth = -80.0
	elif card.tactical_kind != TacticalAbilityDefinition.Kind.BREAKTHROUGH: role_depth = 72.0
	var staging := 640.0 if node.phase in [Phase.RECON, Phase.DEPLOY] else 0.0
	var desired := objective.position - front * (staging + depth + role_depth) + lateral * offset
	# Intersect the continuous route, never its closest vertex: a long final
	# segment must not send the scouts through the objective before staging.
	var prefix := projected_prefix(assignment.route_points, desired, assignment.required_route_end_index)
	var path := navigator.find_path(prefix[-1], desired)
	if path.is_empty(): path = PackedVector2Array([prefix[-1]])
	node.target_position = path[-1]
	node.route_points = prefix.slice(1)
	for point in path.slice(1): node.route_points.append(point)
	# Recon scouts already occupy their deployment slot. Later stages navigate
	# from their actual position; other cards preserve every planned waypoint.
	if node.phase in [Phase.ENGAGE, Phase.EXPLOIT] or node.phase == Phase.DEPLOY and assignment.role == StaffPlanAssignment.Role.RECONNAISSANCE and plan.coordination == Mode.JOINT_ATTACK:
		node.route_points = PackedVector2Array([node.target_position])
	node.arrival_radius = 144.0
	if plan.coordination == Mode.MUTUAL_SUPPORT:
		if node.phase == Phase.RECON: node.is_required = false
		if node.phase == Phase.ENGAGE: node.dwell_ticks = 100
	return true

static func shared_cards(graph: CommanderTaskGraphSnapshot, commander_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if graph == null or graph.retreat_requested or graph.approved_plan.coordination == Mode.INDEPENDENT: return result
	var participates := false
	for node in graph.nodes:
		if node.commander_id == commander_id and node.phase == Phase.ENGAGE and node.lifecycle == CommanderTaskNodeSnapshot.Lifecycle.ACTIVE: participates = true
	if not participates: return result
	for node in graph.nodes:
		if node.phase == Phase.ENGAGE and node.lifecycle == CommanderTaskNodeSnapshot.Lifecycle.ACTIVE and not result.has(node.card_id): result.append(node.card_id)
	return result

static func projected_prefix(route: PackedVector2Array, desired: Vector2, required_index: int = 0) -> PackedVector2Array:
	var index := clampi(required_index, 0, route.size()-1)
	var projection := route[index]
	var nearest := INF
	for i in range(required_index + 1, route.size()):
		var candidate := Geometry2D.get_closest_point_to_segment(desired, route[i-1], route[i])
		var distance := candidate.distance_squared_to(desired)
		if distance < nearest:
			nearest = distance
			index = i - 1
			projection = candidate
	var prefix := route.slice(0, index + 1)
	if not prefix[-1].is_equal_approx(projection): prefix.append(projection)
	return prefix
