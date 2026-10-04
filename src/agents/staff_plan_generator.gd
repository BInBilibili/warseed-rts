class_name StaffPlanGenerator
extends RefCounted

const DEFAULT_CATALOG: StaffPlanCatalog = preload("res://data/ai/staff_plans.tres")
const ROUTE_THREAT_RADIUS := 400.0

var last_rejection_reason: StringName
var _navigator: GridPathfinder
static var _navigation_cache: Dictionary[String, GridPathfinder] = {}


func generate(snapshot: WorldSnapshot, observer: int, request: StaffPlanRequest, catalog: StaffPlanCatalog = DEFAULT_CATALOG) -> StaffPlanSet:
	var started := RuntimeMeasurement.begin()
	var result := _generate_measured(snapshot,observer,request,catalog)
	RuntimeMeasurement.end(&"command.plan_generation_usec",started)
	if RuntimeMeasurement.enabled: RuntimeMeasurement.count("plan.result:"+String(last_rejection_reason if result==null else &"accepted"))
	return result


func _generate_measured(snapshot: WorldSnapshot, observer: int, request: StaffPlanRequest, catalog: StaffPlanCatalog) -> StaffPlanSet:
	last_rejection_reason = &""
	var assessor := StaffSituationAssessor.new()
	var board := assessor.assess(snapshot, observer)
	if board == null:
		return _reject(assessor.last_rejection_reason)
	if snapshot.outcome != null and snapshot.outcome.is_terminal():
		return _reject(&"BATTLE_ENDED")
	if request == null or not request.validate().is_valid():
		return _reject(&"INVALID_REQUEST")
	if catalog == null or not catalog.validate().is_valid():
		return _reject(&"INVALID_PROFILES")
	var objective := snapshot.get_strategic_region(request.objective_region_id)
	if objective == null or not objective.capturable:
		return _reject(&"UNKNOWN_OBJECTIVE")
	if request.coordination != StaffPlanRequest.Coordination.INDEPENDENT and snapshot.navigation_map_id.is_empty():
		return _reject(&"INVALID_REQUEST")
	if request.coordination == StaffPlanRequest.Coordination.MUTUAL_SUPPORT and objective.controller_faction_id != observer:
		return _reject(&"SUPPORT_REQUIRES_FRIENDLY")
	if objective.controller_faction_id == observer and request.coordination != StaffPlanRequest.Coordination.MUTUAL_SUPPORT:
		return _reject(&"OBJECTIVE_ALREADY_HELD")
	for id in request.allowed_card_ids:
		if board.get_card(id) == null:
			return _reject(&"INVALID_REQUEST")
	if request.coordination != StaffPlanRequest.Coordination.INDEPENDENT:
		var groups: Array[StringName] = []
		for card in board.cards:
			if request.allowed_card_ids.has(card.card_id):
				if not card.can_allocate: return _reject(&"COOP_REQUIRES_READY_GROUPS")
				if not groups.has(card.commander_id): groups.append(card.commander_id)
		if groups.size() < 2: return _reject(&"COOP_REQUIRES_TWO_GROUPS")
		for card in board.cards:
			if groups.has(card.commander_id) and snapshot.get_unit_card(card.card_id).authorized_strength > 0 and not request.allowed_card_ids.has(card.card_id): return _reject(&"COOP_REQUIRES_READY_GROUPS")
	for id in request.via_region_ids:
		if snapshot.get_strategic_region(id) == null:
			return _reject(&"INVALID_REQUEST")
	_navigator = null
	if not snapshot.navigation_map_id.is_empty():
		var maps := load("res://data/maps/map_catalog.tres") as MapContentCatalog
		var map := maps.get_map(snapshot.navigation_map_id)
		if map == null:
			return _reject(&"INVALID_REQUEST")
		_navigator = navigation_for_snapshot(snapshot)

	var result := StaffPlanSet.new()
	result.source_tick = snapshot.tick
	result.observer_faction_id = observer
	result.source_fingerprint = board.fingerprint()
	result.request = request.duplicate_value()
	var signatures: Array[String] = []
	for profile in catalog.profiles:
		var plan := _generate_profile(snapshot, board, request, objective, profile)
		if plan == null:
			continue
		var signature := _assignment_signature(plan)
		if signatures.has(signature):
			continue
		signatures.append(signature)
		result.plans.append(plan)
	if result.plans.size() < 2:
		return _reject(&"INSUFFICIENT_ALTERNATIVES")
	result.plans.sort_custom(func(a: StaffCourseOfAction, b: StaffCourseOfAction) -> bool:
		return a.utility_score > b.utility_score if a.utility_score != b.utility_score else String(a.plan_id) < String(b.plan_id))
	return result


func _reject(reason: StringName) -> StaffPlanSet:
	last_rejection_reason = reason
	return null


func _generate_profile(snapshot: WorldSnapshot, board: StaffSituationSnapshot, request: StaffPlanRequest, objective: StrategicRegionSnapshot, profile: StaffPlanProfile) -> StaffCourseOfAction:
	var available: Array[StaffCardAssessment] = []
	var eligible_reserve: Array[StaffCardAssessment] = []
	for card in board.cards:
		if not request.allowed_card_ids.is_empty() and not request.allowed_card_ids.has(card.card_id):
			continue
		if card.can_allocate:
			available.append(card)
		elif card.is_reserve and not snapshot.get_unit_card(card.card_id).is_player_overridden \
			and (not card.organization_enabled or card.organization > 0.0) and card.control_state in [UnitCardState.ControlState.UNASSIGNED, UnitCardState.ControlState.AGENT_ASSIGNED]:
			eligible_reserve.append(card)
	if available.is_empty():
		return null
	available.sort_custom(func(a: StaffCardAssessment, b: StaffCardAssessment) -> bool:
		if profile.kind == StaffPlanProfile.Kind.RECON_FIRST:
			var a_scout := _is_scout(snapshot, a.card_id)
			var b_scout := _is_scout(snapshot, b.card_id)
			if a_scout != b_scout:
				return a_scout
		return String(a.card_id) < String(b.card_id))
	if profile.kind == StaffPlanProfile.Kind.RECON_FIRST and not _is_scout(snapshot, available[0].card_id):
		return null
	var axis: StrategicRegionSnapshot
	if profile.kind == StaffPlanProfile.Kind.FLANK:
		var weighted_origin := Vector2.ZERO
		var total_strength := 0
		for card in available:
			weighted_origin += card.position * card.current_strength
			total_strength += card.current_strength
		axis = _flank_axis(snapshot, objective, weighted_origin / maxi(1, total_strength))
		if axis == null:
			return null
	var plan := StaffCourseOfAction.new()
	plan.coordination = request.coordination
	plan.formation = request.formation
	plan.profile_id = profile.profile_id
	plan.kind = profile.kind
	plan.name_key = profile.name_key
	plan.source_tick = snapshot.tick
	plan.objective_region_id = objective.region_id
	plan.plan_id = StringName("coa:%s:%s:%d" % [objective.region_id, profile.profile_id, snapshot.tick])
	plan.preparation_ticks = profile.preparation_ticks
	var commit_count := maxi(1, ceili(available.size() * profile.force_percent / 100.0))
	var group_ids: Array[StringName] = []
	if _navigator != null:
		for card in available:
			if not group_ids.has(card.commander_id):
				group_ids.append(card.commander_id)
		group_ids.sort()
	var group_count := maxi(1, ceili(group_ids.size() * profile.force_percent / 100.0))
	if request.coordination != StaffPlanRequest.Coordination.INDEPENDENT: group_count = group_ids.size()
	for index in range(available.size()):
		var card := available[index]
		var commit := index < commit_count if _navigator == null else group_ids.find(card.commander_id) < group_count
		if commit:
			var scout := index == 0 and profile.kind == StaffPlanProfile.Kind.RECON_FIRST if _navigator == null else _is_scout(snapshot, card.card_id)
			_add_assignment(plan, card, card.position, objective, axis, scout)
		else:
			plan.reserve_card_ids.append(card.card_id)
			plan.reserve_strength += card.current_strength
	var budget := mini(board.supply, request.max_supply_cost)
	var population_left := maxi(0, board.population_capacity - board.population)
	for card in eligible_reserve:
		if profile.permits_reserve_deployment and plan.supply_cost + card.supply_cost <= budget and card.available_strength <= population_left:
			_add_assignment(plan, card, _reserve_origin(snapshot, board.observer_faction_id), objective, axis, false)
			population_left -= card.available_strength
		else:
			plan.reserve_card_ids.append(card.card_id)
			plan.reserve_strength += card.available_strength
	plan.assignments.sort_custom(func(a: StaffPlanAssignment, b: StaffPlanAssignment) -> bool: return String(a.card_id) < String(b.card_id))
	if axis != null and _navigator == null:
		# Stage along our own rear before crossing to the selected flank.
		var rear := _reserve_origin(snapshot, board.observer_faction_id)
		plan.route_distance = 0.0
		for assignment in plan.assignments:
			var origin := assignment.route_points[0]
			assignment.route_points = PackedVector2Array([origin, Vector2(origin.x, rear.y), Vector2(axis.position.x, rear.y), axis.position, objective.position])
			for route_index in range(1, assignment.route_points.size()):
				plan.route_distance += assignment.route_points[route_index - 1].distance_to(assignment.route_points[route_index])
	if _navigator != null:
		plan.route_is_navigation_path = true
		plan.route_distance = 0.0
		for assignment in plan.assignments:
			var stops := PackedVector2Array([assignment.route_points[0]])
			for id in request.via_region_ids:
				stops.append(snapshot.get_strategic_region(id).position)
			if axis != null and not request.via_region_ids.has(axis.region_id):
				stops.append(axis.position)
			stops.append(objective.position)
			assignment.route_points = PackedVector2Array([stops[0]])
			for index in range(1, stops.size()):
				if request.coordination != StaffPlanRequest.Coordination.INDEPENDENT and index == stops.size()-1: assignment.required_route_end_index = assignment.route_points.size()-1
				var segment := _navigator.find_path(stops[index - 1], stops[index])
				if segment.is_empty():
					return null
				for point_index in range(1, segment.size()):
					assignment.route_points.append(segment[point_index])
			for index in range(1, assignment.route_points.size()):
				plan.route_distance += assignment.route_points[index - 1].distance_to(assignment.route_points[index])
	plan.reserve_card_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	_score(plan, board, objective, profile, request)
	return plan


func _is_scout(snapshot: WorldSnapshot, card_id: StringName) -> bool:
	var card := snapshot.get_unit_card(card_id)
	return card != null and card.tactical_kind == TacticalAbilityDefinition.Kind.OBSERVE and card.has_active_unit_type(&"scout_vehicle")


func _flank_axis(snapshot: WorldSnapshot, objective: StrategicRegionSnapshot, origin: Vector2) -> StrategicRegionSnapshot:
	var best: StrategicRegionSnapshot
	var best_detour := INF
	for region in snapshot.strategic_regions:
		if region.region_id == objective.region_id or not region.capturable or region.position.distance_to(objective.position) < 128.0:
			continue
		var detour := origin.distance_to(region.position) + region.position.distance_to(objective.position)
		if best == null or detour < best_detour or (is_equal_approx(detour, best_detour) and String(region.region_id) < String(best.region_id)):
			best = region
			best_detour = detour
	return best


func _reserve_origin(snapshot: WorldSnapshot, observer: int) -> Vector2:
	var selected: BuildingSnapshot
	for building in snapshot.buildings:
		if building.faction_id == observer and building.enabled and (selected == null or building.entity_id < selected.entity_id):
			selected = building
	return selected.position if selected != null else Vector2.ZERO


func _add_assignment(plan: StaffCourseOfAction, card: StaffCardAssessment, origin: Vector2, objective: StrategicRegionSnapshot, axis: StrategicRegionSnapshot, scout: bool) -> void:
	var assignment := StaffPlanAssignment.new()
	assignment.card_id = card.card_id
	assignment.commander_id = card.commander_id
	assignment.objective_region_id = objective.region_id
	assignment.axis_region_id = axis.region_id if axis != null else objective.region_id
	assignment.role = StaffPlanAssignment.Role.RECONNAISSANCE if scout else (StaffPlanAssignment.Role.FLANK if axis != null else StaffPlanAssignment.Role.ADVANCE)
	assignment.requires_deployment = card.is_reserve
	assignment.supply_cost = card.supply_cost if card.is_reserve else 0
	assignment.strength = card.available_strength if card.is_reserve else card.current_strength
	assignment.preparation_ticks = 0 if scout else plan.preparation_ticks
	assignment.route_points.append(origin)
	if axis != null:
		assignment.route_points.append(axis.position)
	assignment.route_points.append(objective.position)
	plan.assignments.append(assignment)
	plan.committed_strength += assignment.strength
	plan.supply_cost += assignment.supply_cost
	for index in range(1, assignment.route_points.size()):
		plan.route_distance += assignment.route_points[index - 1].distance_to(assignment.route_points[index])


func _score(plan: StaffCourseOfAction, board: StaffSituationSnapshot, objective: StrategicRegionSnapshot, profile: StaffPlanProfile, request: StaffPlanRequest) -> void:
	var contact_score := 0
	var report_score := 0
	for fact in board.facts:
		if fact.category == StaffSituationFact.Category.THREAT and fact.confidence_percent > 0 and _near_routes(plan, fact.position):
			plan.evidence_fact_ids.append(fact.fact_id)
			var value := ceili(fact.estimated_max * fact.confidence_percent / 100.0)
			if fact.kind == StaffSituationFact.Kind.INTEL_ESTIMATE:
				report_score = maxi(report_score, value)
			else:
				contact_score += value
		elif fact.kind == StaffSituationFact.Kind.UNKNOWN_REGION and (fact.region_id == objective.region_id or _uses_axis(plan, fact.region_id)):
			plan.uncertainty_score += 15
			plan.evidence_fact_ids.append(fact.fact_id)
		elif fact.category == StaffSituationFact.Category.GAP and not fact.card_id.is_empty() and _uses_card(plan, fact.card_id):
			plan.readiness_penalty += 5
			plan.evidence_fact_ids.append(fact.fact_id)
	plan.known_threat_score = maxi(contact_score, report_score)
	plan.risk_score = plan.known_threat_score * 4 + plan.uncertainty_score + plan.readiness_penalty
	plan.objective_value = 40 + objective.supply_per_settlement * 10
	plan.utility_score = plan.objective_value + plan.committed_strength * 2 - plan.supply_cost * 4 \
		- ceili(plan.route_distance / 512.0) - ceili(plan.preparation_ticks / 10.0) \
		- ceili(plan.risk_score * profile.risk_weight * request.risk_aversion / 2.0)
	plan.evidence_fact_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	plan.reason_keys.assign([&"STAFF_STRATEGIC_ROUTE_ONLY", &"STAFF_UTILITY_HEURISTIC"])
	if plan.uncertainty_score > 0:
		plan.reason_keys.append(&"STAFF_RECON_REQUIRED")
	if plan.reserve_strength > 0:
		plan.reason_keys.append(&"STAFF_FORCE_HELD_IN_RESERVE")
	if plan.supply_cost > 0:
		plan.reason_keys.append(&"STAFF_DEPLOYMENT_COMMITMENT")
	if profile.kind == StaffPlanProfile.Kind.RECON_FIRST:
		plan.reason_keys.append(&"STAFF_RECON_BEFORE_COMMITMENT")


func _near_routes(plan: StaffCourseOfAction, position: Vector2) -> bool:
	for assignment in plan.assignments:
		for index in range(1, assignment.route_points.size()):
			var closest := Geometry2D.get_closest_point_to_segment(position, assignment.route_points[index - 1], assignment.route_points[index])
			if position.distance_to(closest) <= ROUTE_THREAT_RADIUS:
				return true
	return false


func _uses_axis(plan: StaffCourseOfAction, region_id: StringName) -> bool:
	for assignment in plan.assignments:
		if assignment.axis_region_id == region_id:
			return true
	return false


func _uses_card(plan: StaffCourseOfAction, card_id: StringName) -> bool:
	for assignment in plan.assignments:
		if assignment.card_id == card_id:
			return true
	return false


func _assignment_signature(plan: StaffCourseOfAction) -> String:
	var values: Array[Dictionary] = []
	for assignment in plan.assignments:
		values.append(assignment.to_dictionary())
	return JSON.stringify(values)


static func navigation_for_snapshot(snapshot: WorldSnapshot) -> GridPathfinder:
	# Callers supply an already validated faction snapshot. The key contains
	# only public map identity and that observer's known building footprints.
	if snapshot == null or snapshot.is_true_state or snapshot.knowledge == null or snapshot.knowledge.faction_id != snapshot.observer_faction_id:
		return null
	var maps := load("res://data/maps/map_catalog.tres") as MapContentCatalog
	var map := maps.get_map(snapshot.navigation_map_id)
	if map == null: return null
	var occupied: Array[Vector2i] = []
	for building in snapshot.buildings:
		if building.enabled:
			occupied.append_array(building.footprint_cells)
	occupied.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x if a.x != b.x else a.y < b.y)
	var key := "%s:%s" % [snapshot.navigation_map_id, occupied]
	if not _navigation_cache.has(key):
		if _navigation_cache.size() >= 4:
			_navigation_cache.clear()
		var grid := LogicGrid.create_for_map(map)
		for cell in occupied:
			grid.set_blocked(cell, true)
		_navigation_cache[key] = GridPathfinder.new(grid)
	return _navigation_cache[key]
