class_name SupplyPriorityCommand
extends GameCommand

var commander_id: StringName

func _init(id: int, faction: int, tick: int, priority_id: StringName = &"") -> void:
	super(id, faction, IssuerKind.PLAYER, tick, 0)
	commander_id = priority_id

func duplicate_value() -> SupplyPriorityCommand:
	return SupplyPriorityCommand.new(command_id, issuer_id, issued_tick, commander_id)

func get_supersession_key() -> String:
	return "SUPPLY_PRIORITY_%d" % issuer_id
