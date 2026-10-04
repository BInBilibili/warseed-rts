class_name AreaSupportCommand
extends GameCommand

var support_kind: SupportOrderCommand.SupportKind
var position: Vector2

func _init(id: int, faction: int, kind: IssuerKind, tick: int, support: SupportOrderCommand.SupportKind, target: Vector2) -> void:
	super(id, faction, kind, tick, 0)
	support_kind = support
	position = target

func duplicate_value() -> AreaSupportCommand:
	var result := AreaSupportCommand.new(command_id, issuer_id, issuer_kind, issued_tick, support_kind, position)
	result.agent_id = agent_id
	result.task_id = task_id
	return result

func get_supersession_key() -> String:
	return "AREA_SUPPORT_%d_%d" % [issuer_id, support_kind]
