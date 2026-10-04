class_name LegionReformationState
extends RefCounted

enum Phase { SOLID, REFORMING, SEPARATING }
var phase: Phase = Phase.SOLID
var forced_overlap := false
var started_tick := -1
var deadline_tick := -1
var separating_since_tick := -1
var cooldown_until := -1
var last_budget_tick := -1
var active_ticks := PackedInt32Array()
var target := Vector2.ZERO
var requested_target := Vector2.ZERO
var returning_to_origin := false
var origin := Vector2.ZERO
var route := PackedVector2Array()
var tolerance := 6.0
var intent := ""
var reason: StringName = &"REFORMATION_SOLID"
var observed_position := Vector2(INF,INF)
var stalled_ticks := 0
var observed_tick := -1

func prune(tick: int, policy: LegionReformationPolicy) -> void:
	while not active_ticks.is_empty() and active_ticks[0]<=tick-policy.budget_window_ticks:
		active_ticks.remove_at(0)

func can_start(tick: int, policy: LegionReformationPolicy) -> bool:
	prune(tick,policy)
	return phase==Phase.SOLID and tick>=cooldown_until and active_ticks.size()<policy.maximum_ticks

func begin(tick: int, destination: Vector2, path: PackedVector2Array, version: String, arrival: float, policy: LegionReformationPolicy) -> bool:
	if not can_start(tick,policy) or path.size()<2: return false
	phase=Phase.REFORMING; started_tick=tick; separating_since_tick=-1
	deadline_tick=tick+mini(policy.maximum_ticks,policy.maximum_ticks-active_ticks.size())
	target=destination; requested_target=destination; returning_to_origin=false
	origin=path[0]; route=path.duplicate(); tolerance=arrival; intent=version
	reason=&"REFORMATION_ACTIVE"
	return true

func charge(tick: int, policy: LegionReformationPolicy) -> bool:
	prune(tick,policy)
	if phase!=Phase.REFORMING: return false
	if tick>=deadline_tick or active_ticks.size()>=policy.maximum_ticks:
		return false
	if last_budget_tick!=tick:
		active_ticks.append(tick); last_budget_tick=tick
	return true

func end(tick: int, overlapped: bool, policy: LegionReformationPolicy, cause: StringName) -> void:
	separating_since_tick=(separating_since_tick if phase==Phase.SEPARATING and separating_since_tick>=0 else tick) if overlapped else -1
	phase=Phase.SEPARATING if overlapped else Phase.SOLID
	cooldown_until=maxi(cooldown_until,tick+policy.cooldown_ticks)
	reason=&"REFORMATION_SEPARATING" if overlapped else cause
	route=PackedVector2Array()

func damage_factor(policy: LegionReformationPolicy) -> float:
	return policy.damage_multiplier if phase!=Phase.SOLID or forced_overlap else 1.0

func duplicate_value() -> LegionReformationState:
	var copy := LegionReformationState.new()
	copy.forced_overlap=forced_overlap
	copy.phase=phase; copy.started_tick=started_tick; copy.deadline_tick=deadline_tick; copy.separating_since_tick=separating_since_tick
	copy.cooldown_until=cooldown_until; copy.last_budget_tick=last_budget_tick
	copy.active_ticks=active_ticks.duplicate(); copy.target=target; copy.origin=origin
	copy.requested_target=requested_target; copy.returning_to_origin=returning_to_origin
	copy.route=route.duplicate(); copy.tolerance=tolerance; copy.intent=intent; copy.reason=reason
	copy.observed_position=observed_position; copy.stalled_ticks=stalled_ticks; copy.observed_tick=observed_tick
	return copy
