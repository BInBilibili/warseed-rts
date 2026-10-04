class_name AreaSupportEffect
extends RefCounted

var effect_id: int
var faction_id: int
var support_kind: SupportOrderCommand.SupportKind
var position: Vector2
var radius: float
var started_tick: int
var active_tick: int
var expires_tick: int
var next_pulse_tick: int
var executed: bool = false

func duplicate_value() -> AreaSupportEffect:
	var result := AreaSupportEffect.new()
	result.effect_id = effect_id
	result.faction_id = faction_id
	result.support_kind = support_kind
	result.position = position
	result.radius = radius
	result.started_tick = started_tick
	result.active_tick = active_tick
	result.expires_tick = expires_tick
	result.next_pulse_tick = next_pulse_tick
	result.executed = executed
	return result
