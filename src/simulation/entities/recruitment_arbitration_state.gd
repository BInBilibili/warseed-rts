class_name RecruitmentArbitrationState
extends RefCounted

var reserved_commander_id: StringName
var reserved_slot: int = -1
var reserved_cost: int = 0
var reserved_amount: int = 0
var last_served_commander_id: StringName
var selected_slots: Dictionary[StringName, int] = {}
var waiting_since: Dictionary[StringName, int] = {}
var reasons: Dictionary[StringName, StringName] = {}
var refusal_until: Dictionary[StringName, int] = {}
var refusal_reasons: Dictionary[StringName, StringName] = {}

func clear_reservation() -> void:
	reserved_commander_id = &""
	reserved_slot = -1
	reserved_cost = 0
	reserved_amount = 0

func duplicate_value() -> RecruitmentArbitrationState:
	var copy := RecruitmentArbitrationState.new()
	copy.reserved_commander_id = reserved_commander_id
	copy.reserved_slot = reserved_slot
	copy.reserved_cost = reserved_cost
	copy.reserved_amount = reserved_amount
	copy.last_served_commander_id = last_served_commander_id
	copy.selected_slots.assign(selected_slots)
	copy.waiting_since.assign(waiting_since)
	copy.reasons.assign(reasons)
	copy.refusal_until.assign(refusal_until)
	copy.refusal_reasons.assign(refusal_reasons)
	return copy
