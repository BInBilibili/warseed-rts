class_name LegionFormationCommand
extends GameCommand

var commander_id: StringName
var mode: CommanderState.FormationMode

func _init(id: int, faction: int, tick: int, commander: StringName, selected: CommanderState.FormationMode) -> void:
	super(id, faction, IssuerKind.PLAYER, tick, 0)
	commander_id = commander
	mode = selected

func duplicate_value() -> LegionFormationCommand:
	var copy := LegionFormationCommand.new(command_id, issuer_id, issued_tick, commander_id, mode)
	copy.issuer_kind = issuer_kind
	copy.agent_id = agent_id
	return copy

func get_supersession_key() -> String:
	return "LEGION_FORMATION_%s" % commander_id
