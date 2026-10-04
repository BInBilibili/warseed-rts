class_name RecruitUnitCardCommand
extends GameCommand

var unit_card_id: StringName
var member_count: int
var legion_slot: int = -1

func _init(id: int, faction: int, kind: IssuerKind, tick: int, card_id: StringName, count: int) -> void:
	super(id, faction, kind, tick, 0)
	unit_card_id = card_id
	member_count = count

func duplicate_value() -> RecruitUnitCardCommand:
	var result := RecruitUnitCardCommand.new(command_id, issuer_id, issuer_kind, issued_tick, unit_card_id, member_count)
	result.agent_id = agent_id
	result.task_id = task_id
	result.legion_slot = legion_slot
	return result

func get_supersession_key() -> String:
	return "RECRUIT_%d" % issuer_id
