class_name LegionTransitState
extends RefCounted

enum Phase { WIDE, GATHER, COLUMN, EXIT_WAIT, EXPAND, BLOCKED }
class BatchState extends RefCounted:
	var identities := PackedInt32Array()
	var progress := 0.0
	var depth := 0.0
	var ready := 0
	var available := 0
	var gather_phase := 0
	var gather_laterals := PackedFloat64Array()
	var gather_distances := PackedFloat64Array()
	var column_targets := PackedVector2Array()
	var targets_progress := INF
	var admitted := false
	# 0: in the road; 1: moving into a reserved side pocket; 2: physically clear.
	var exit_stage := 0
	var exit_targets := PackedVector2Array()
	func duplicate_value() -> BatchState:
		var copy := BatchState.new()
		copy.identities=identities.duplicate(); copy.progress=progress; copy.depth=depth
		copy.ready=ready; copy.available=available
		copy.gather_phase=gather_phase; copy.gather_laterals=gather_laterals.duplicate(); copy.admitted=admitted
		copy.gather_distances=gather_distances.duplicate()
		copy.column_targets=column_targets.duplicate(); copy.targets_progress=targets_progress
		copy.exit_stage=exit_stage; copy.exit_targets=exit_targets.duplicate()
		return copy

var phase: Phase = Phase.WIDE
var path: LegionTransitGeometry.PathData
var columns := 3
var batches: Array[BatchState] = []
var intent := ""
var source_route := PackedVector2Array()
var goal := Vector2.ZERO
var started_tick := -1
var advanced_tick := -1
var blocked_since := -1
var reason: StringName = &"WIDE"
var hero_batch := -1
var hero_ordinal := -1
var escort_identity := -1
var hero_target := Vector2.ZERO
var gather_navigation: Array[LegionGatherNavigation.State] = []
var rejoin := LegionTransitRejoin.State.new()
var expand_since := -1
var exit_mouth := -1.0
var exit_head := -1.0
var exit_forward := Vector2.ZERO
var exit_clear_since := -1
var exit_planned := false
var exit_plan_reason: StringName = &"TRANSIT_EXIT_CAPACITY"

func duplicate_value() -> LegionTransitState:
	var copy := LegionTransitState.new()
	copy.phase=phase; copy.path=path.duplicate_value() if path!=null else null
	copy.columns=columns; copy.intent=intent; copy.goal=goal
	copy.source_route=source_route.duplicate()
	copy.started_tick=started_tick; copy.advanced_tick=advanced_tick; copy.blocked_since=blocked_since
	copy.reason=reason; copy.hero_batch=hero_batch; copy.hero_ordinal=hero_ordinal
	copy.escort_identity=escort_identity; copy.hero_target=hero_target
	copy.rejoin=rejoin.duplicate_value()
	copy.expand_since=expand_since
	copy.exit_mouth=exit_mouth; copy.exit_head=exit_head; copy.exit_forward=exit_forward
	copy.exit_clear_since=exit_clear_since; copy.exit_planned=exit_planned; copy.exit_plan_reason=exit_plan_reason
	for batch in batches: copy.batches.append(batch.duplicate_value())
	for navigation in gather_navigation: copy.gather_navigation.append(navigation.duplicate_value())
	return copy
