class_name StaffPlanRequest
extends RefCounted

enum Coordination { INDEPENDENT, JOINT_ATTACK, MUTUAL_SUPPORT }
enum Formation { LINE, WEDGE, DEPTH }
var coordination: Coordination = Coordination.INDEPENDENT
var formation: Formation = Formation.LINE

var via_region_ids: Array[StringName] = []
var objective_region_id: StringName
var max_supply_cost: int = 0
var risk_aversion: int = 2
var allowed_card_ids: Array[StringName] = []


func validate() -> DataValidationResult:
	var result := DataValidationResult.new()
	if coordination < Coordination.INDEPENDENT or coordination > Coordination.MUTUAL_SUPPORT or formation < Formation.LINE or formation > Formation.DEPTH:
		result.add(DataValidationResult.Reason.INVALID_VALUE, "invalid cooperation or formation")
	if objective_region_id.is_empty():
		result.add(DataValidationResult.Reason.EMPTY_ID, "staff request requires an objective")
	if max_supply_cost < 0 or risk_aversion < 1 or risk_aversion > 3:
		result.add(DataValidationResult.Reason.INVALID_VALUE, "staff budget or risk preference is invalid")
	if via_region_ids.size() > 3:
		result.add(DataValidationResult.Reason.INVALID_VALUE, "at most three route waypoints")
	var route_ids: Array[StringName] = []
	for id in via_region_ids:
		if id.is_empty() or id == objective_region_id or route_ids.has(id):
			result.add(DataValidationResult.Reason.INVALID_VALUE, "invalid route waypoint")
		route_ids.append(id)
	var ids: Array[StringName] = []
	for id in allowed_card_ids:
		if id.is_empty() or ids.has(id):
			result.add(DataValidationResult.Reason.DUPLICATE_ID, "allowed cards must be nonempty distinct IDs")
		ids.append(id)
	return result


func duplicate_value() -> StaffPlanRequest:
	var result := StaffPlanRequest.new()
	result.coordination = coordination
	result.formation = formation
	result.via_region_ids.assign(via_region_ids)
	result.objective_region_id = objective_region_id
	result.max_supply_cost = max_supply_cost
	result.risk_aversion = risk_aversion
	result.allowed_card_ids.assign(allowed_card_ids)
	return result


func to_dictionary() -> Dictionary:
	var sorted_ids := allowed_card_ids.duplicate()
	sorted_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var result := {"via_region_ids": via_region_ids.duplicate(), "objective_region_id": String(objective_region_id), "max_supply_cost": max_supply_cost,
		"risk_aversion": risk_aversion, "allowed_card_ids": sorted_ids}
	if coordination != Coordination.INDEPENDENT:
		result["coordination"] = int(coordination)
		result["formation"] = int(formation)
	return result
