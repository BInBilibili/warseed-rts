class_name LegionSpatialState
extends RefCounted

enum Action { MOVE, ATTACK, DEFEND, RETREAT }
var initialized := false
var flexible := false
var action: Action = Action.MOVE
var changed_tick := -1
var advanced_tick := -1
var anchor := Vector2.ZERO
var facing := Vector2.RIGHT
var goal := Vector2.ZERO
var hero_offset := Vector2.ZERO
var route := PackedVector2Array()
var route_index := 0
var intent := ""
var ready := 0
var eligible := 0
var reason: StringName = &"FORMING"
var relief := false
var slots: Array[LegionSpatialOrder] = []
var transit := LegionTransitState.new()
var deployment: LegionDeploymentPlan
var expansion_clear_since := -1
var ready_since := -1

func duplicate_value() -> LegionSpatialState:
	var copy := LegionSpatialState.new()
	copy.flexible=flexible
	copy.initialized = initialized; copy.action = action; copy.changed_tick = changed_tick
	copy.advanced_tick = advanced_tick
	copy.anchor = anchor; copy.facing = facing; copy.goal = goal
	copy.hero_offset = hero_offset
	copy.route = route.duplicate(); copy.route_index = route_index; copy.intent = intent
	copy.ready = ready; copy.eligible = eligible; copy.reason = reason; copy.relief = relief
	for slot in slots: copy.slots.append(slot.duplicate_value())
	copy.transit=transit.duplicate_value()
	copy.deployment=deployment.duplicate_value() if deployment!=null else null
	copy.expansion_clear_since=expansion_clear_since
	copy.ready_since=ready_since
	return copy
