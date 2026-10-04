class_name RecruitmentPlanCommand
extends GameCommand

var commander_ids: Array[StringName] = []
var rates: Array[int] = []
var reserve: int

func _init(id: int, faction: int, tick: int, ids: Array[StringName], quotas: Array[int], minimum_supply: int) -> void:
	super(id, faction, IssuerKind.PLAYER, tick, 0)
	commander_ids.assign(ids)
	rates.assign(quotas)
	reserve = minimum_supply

func duplicate_value() -> RecruitmentPlanCommand:
	return RecruitmentPlanCommand.new(command_id, issuer_id, issued_tick, commander_ids, rates, reserve)

func get_supersession_key() -> String:
	return "RECRUITMENT_PLAN_%d" % issuer_id
