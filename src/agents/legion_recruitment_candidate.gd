class_name LegionRecruitmentCandidate
extends RefCounted

var commander_id: StringName
var card: UnitCardSnapshot
var slot: int = -1
var count_in_window: int = 0
var quota: int = 0
var reason: StringName = &"GROWTH_WAIT_FULL"

func is_eligible() -> bool:
	return card != null and reason == &"GROWTH_WAIT_READY"
