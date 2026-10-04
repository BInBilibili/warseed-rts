class_name CommanderTaskGraphBuilder
extends RefCounted

const DEFAULT_DEFINITION: CommanderTaskGraphDefinition = preload("res://data/ai/commander_task_graph.tres")

var last_rejection_reason: StringName


func build(snapshot: WorldSnapshot, plan: StaffCourseOfAction, definition: CommanderTaskGraphDefinition = DEFAULT_DEFINITION, legal_navigator: GridPathfinder = null) -> CommanderTaskGraphSnapshot:
	last_rejection_reason = &""
	if snapshot == null or snapshot.is_true_state or snapshot.knowledge == null or snapshot.knowledge.faction_id != snapshot.observer_faction_id:
		return _reject(&"FACTION_KNOWLEDGE_REQUIRED")
	if plan == null or definition == null or not definition.validate().is_valid():
		return _reject(&"INVALID_GRAPH_DEFINITION")
	if snapshot.outcome != null and snapshot.outcome.is_terminal():
		return _reject(&"BATTLE_ENDED")
	var is_approved := false
	for decision in snapshot.staff_plan_decisions:
		if decision.faction_id == snapshot.observer_faction_id and decision.approved_plan != null \
				and decision.approved_plan.fingerprint() == plan.fingerprint():
			is_approved = true
	if not is_approved:
		return _reject(&"APPROVED_PLAN_REQUIRED")
	var objective := snapshot.get_strategic_region(plan.objective_region_id)
	if objective == null or plan.assignments.is_empty():
		return _reject(&"INVALID_GRAPH_OBJECTIVE")
	var headquarters: BuildingSnapshot
	for building in snapshot.buildings:
		if building.faction_id == snapshot.observer_faction_id and building.enabled and building.definition_id == &"command_center" \
				and (headquarters == null or building.entity_id < headquarters.entity_id):
			headquarters = building
	if headquarters == null:
		return _reject(&"RETREAT_DESTINATION_REQUIRED")
	var assigned_ids: Array[StringName] = []
	for assignment in plan.assignments:
		var card := snapshot.get_unit_card(assignment.card_id)
		if card == null or card.faction_id != snapshot.observer_faction_id or card.commander_definition_id != assignment.commander_id \
				or assignment.route_points.is_empty() or assigned_ids.has(assignment.card_id) or plan.reserve_card_ids.has(assignment.card_id):
			return _reject(&"INVALID_GRAPH_ASSIGNMENT")
		for point in assignment.route_points:
			if not point.is_finite():
				return _reject(&"INVALID_GRAPH_ROUTE")
		assigned_ids.append(assignment.card_id)
	var graph := CommanderTaskGraphSnapshot.new()
	var cooperation_navigator: GridPathfinder = legal_navigator
	if plan.coordination != StaffPlanRequest.Coordination.INDEPENDENT and cooperation_navigator == null:
		var maps := load("res://data/maps/map_catalog.tres") as MapContentCatalog
		var map := maps.get_map(snapshot.navigation_map_id)
		if map == null: return _reject(&"INVALID_GRAPH_ROUTE")
		var grid := LogicGrid.create_for_map(map)
		for building in snapshot.buildings:
			if building.enabled:
				for cell in building.footprint_cells: grid.set_blocked(cell, true)
		cooperation_navigator = GridPathfinder.new(grid)
	graph.graph_id = StringName("operation:%s" % plan.fingerprint())
	graph.faction_id = snapshot.observer_faction_id
	graph.approved_plan = plan.duplicate_value()
	graph.created_tick = snapshot.tick
	graph.reserve_card_ids.assign(plan.reserve_card_ids)
	graph.reserve_card_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for assignment in plan.assignments:
		for stage in definition.stages:
			var node := CommanderTaskNodeSnapshot.new()
			node.node_id = _node_id(assignment.card_id, stage.stage_id)
			node.card_id = assignment.card_id
			node.baseline_strength = assignment.strength
			node.commander_id = assignment.commander_id
			node.phase = stage.phase
			node.timeout_ticks = stage.timeout_ticks
			node.dwell_ticks = stage.dwell_ticks
			node.arrival_radius = stage.arrival_radius
			node.earliest_tick = snapshot.tick + (assignment.preparation_ticks if stage.phase == CommanderTaskStageDefinition.Phase.MUSTER else 0)
			node.changed_tick = snapshot.tick
			for prerequisite in stage.prerequisite_ids:
				node.prerequisite_ids.append(_node_id(assignment.card_id, prerequisite))
			var origin := assignment.route_points[0]
			node.target_position = objective.position
			match stage.phase:
				CommanderTaskStageDefinition.Phase.MUSTER:
					node.target_position = origin if not snapshot.navigation_map_id.is_empty() else _muster_position(plan, assignment.commander_id)
					node.requires_deployment = assignment.requires_deployment
					node.supply_cost = assignment.supply_cost
				CommanderTaskStageDefinition.Phase.RECON:
					node.is_required = assignment.role == StaffPlanAssignment.Role.RECONNAISSANCE
					node.target_position = _point_along_route(assignment.route_points, 0.90) if not snapshot.navigation_map_id.is_empty() else origin.lerp(objective.position, 0.75)
				CommanderTaskStageDefinition.Phase.DEPLOY:
					node.target_position = assignment.route_points[-2] if assignment.route_points.size() > 2 else origin.lerp(objective.position, 0.85)
					if assignment.route_points.size() > 2:
						for route_index in range(1, assignment.route_points.size() - 2):
							node.route_points.append(assignment.route_points[route_index])
					# Main forces cannot deploy before every assigned advance scout reports.
					for scout in plan.assignments:
						if (snapshot.navigation_map_id.is_empty() or scout.commander_id == assignment.commander_id) and scout.card_id != assignment.card_id and scout.role == StaffPlanAssignment.Role.RECONNAISSANCE:
							node.prerequisite_ids.append(_node_id(scout.card_id, definition.get_phase(CommanderTaskStageDefinition.Phase.RECON).stage_id))
				CommanderTaskStageDefinition.Phase.RETREAT:
					node.target_position = headquarters.position + Vector2(0.0, -160.0)
			if not snapshot.navigation_map_id.is_empty():
				if stage.phase in [CommanderTaskStageDefinition.Phase.RECON, CommanderTaskStageDefinition.Phase.DEPLOY]:
					var progress := 0.90 if stage.phase == CommanderTaskStageDefinition.Phase.RECON else 0.96
					node.target_position = _point_along_route(assignment.route_points, progress)
					node.route_points = _prefix_route(assignment.route_points, progress)
				# Budget travel at 60 world units/second, with room for combat and regrouping.
				var length := 0.0
				for i in range(1, assignment.route_points.size()):
					length += assignment.route_points[i - 1].distance_to(assignment.route_points[i])
				node.timeout_ticks = maxi(node.timeout_ticks, ceili(length / 60.0 * 10.0) + stage.timeout_ticks)
			if not CoalitionTactics.configure_node(snapshot, plan, assignment, node, cooperation_navigator): return _reject(&"INVALID_GRAPH_ROUTE")
			if node.route_points.is_empty() or node.route_points[-1] != node.target_position:
				node.route_points.append(node.target_position)
			node.prerequisite_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
			graph.nodes.append(node)
	if plan.coordination == StaffPlanRequest.Coordination.JOINT_ATTACK:
		var shared_budget := 0
		for assignment in plan.assignments:
			var budget := assignment.preparation_ticks
			for node in graph.nodes:
				if node.card_id == assignment.card_id and node.phase in [CommanderTaskStageDefinition.Phase.MUSTER, CommanderTaskStageDefinition.Phase.RECON, CommanderTaskStageDefinition.Phase.DEPLOY]: budget += node.timeout_ticks
			shared_budget = maxi(shared_budget, budget)
		for node in graph.nodes:
			if node.phase != CommanderTaskStageDefinition.Phase.ENGAGE: continue
			node.timeout_ticks = maxi(node.timeout_ticks, shared_budget)
			for other in graph.nodes:
				if other.phase == CommanderTaskStageDefinition.Phase.DEPLOY and not node.prerequisite_ids.has(other.node_id): node.prerequisite_ids.append(other.node_id)
			node.prerequisite_ids.sort()
	graph.nodes.sort_custom(func(a: CommanderTaskNodeSnapshot, b: CommanderTaskNodeSnapshot) -> bool: return String(a.node_id) < String(b.node_id))
	return graph


func _node_id(card_id: StringName, stage_id: StringName) -> StringName:
	return StringName("%s/%s" % [card_id, stage_id])


func _muster_position(plan: StaffCourseOfAction, commander_id: StringName) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	# Use stable card order so resource ordering cannot change float summation.
	var assignments := plan.assignments.duplicate()
	assignments.sort_custom(func(a: StaffPlanAssignment, b: StaffPlanAssignment) -> bool: return String(a.card_id) < String(b.card_id))
	for assignment in assignments:
		if assignment.commander_id == commander_id:
			sum += assignment.route_points[0]
			count += 1
	return sum / maxi(1, count)


func _reject(reason: StringName) -> CommanderTaskGraphSnapshot:
	last_rejection_reason = reason
	return null


func _point_along_route(route: PackedVector2Array, fraction: float) -> Vector2:
	return _prefix_route(route, fraction)[-1]


func _prefix_route(route: PackedVector2Array, fraction: float) -> PackedVector2Array:
	var length := 0.0
	for i in range(1, route.size()):
		length += route[i - 1].distance_to(route[i])
	var remaining := length * fraction
	var result := PackedVector2Array()
	for i in range(1, route.size()):
		var segment := route[i - 1].distance_to(route[i])
		if remaining <= segment:
			result.append(route[i - 1].lerp(route[i], remaining / maxf(0.001, segment)))
			return result
		result.append(route[i])
		remaining -= segment
	if result.is_empty():
		result.append(route[-1])
	return result
