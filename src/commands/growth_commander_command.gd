class_name GrowthCommanderCommand
extends GameCommand

enum Action { ADVANCE, RECOVER, RESUME, DEFEND_SUPPLY }
var commander_id: StringName
var action: Action
var target_region_id: StringName
var target_position: Vector2

func _init(id: int, faction: int, tick: int, commander: StringName, kind: Action, region: StringName, at: Vector2) -> void:
	super(id, faction, IssuerKind.AGENT, tick, 0)
	commander_id = commander
	action = kind
	target_region_id = region
	target_position = at

func duplicate_value() -> GrowthCommanderCommand:
	var result := GrowthCommanderCommand.new(command_id, issuer_id, issued_tick, commander_id, action, target_region_id, target_position)
	result.agent_id = agent_id
	return result
