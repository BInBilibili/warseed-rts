class_name LegionFormationState
extends RefCounted

var active := false
var state := LegionProtectionPlanner.State.new()
var batch_plan: LegionBatchPlanner.Plan
var spatial := LegionSpatialState.new()
var reason: StringName = &"PENDING"
var target := Vector2.ZERO
var core_path_distance := INF
var core_speed := 0.0
var initialized := false
var last_retreat_target := Vector2.ZERO
var retreat_version := 0
var was_retreating := false

func duplicate_value() -> LegionFormationState:
	var copy := LegionFormationState.new()
	copy.active = active
	copy.state = state.duplicate_value()
	copy.batch_plan = batch_plan.duplicate_value() if batch_plan != null else null
	copy.spatial = spatial.duplicate_value()
	copy.reason = reason
	copy.target = target
	copy.core_path_distance = core_path_distance
	copy.core_speed = core_speed
	copy.initialized = initialized
	copy.last_retreat_target = last_retreat_target
	copy.retreat_version = retreat_version
	copy.was_retreating = was_retreating
	return copy

func reason_key() -> StringName:
	return StringName("LEGION_FORMATION_"+String(reason))
