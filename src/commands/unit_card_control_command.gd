class_name UnitCardControlCommand
extends GameCommand

enum Action {
	TAKEOVER,
	RETURN_TO_COMMANDER,
	STAY_MANUAL,
}

var automatic_return: bool = false
var unit_card_id: StringName
var action: Action


func _init(
	new_command_id: int,
	new_issuer_id: int,
	new_issued_tick: int,
	new_unit_card_id: StringName,
	new_action: Action
) -> void:
	super(new_command_id, new_issuer_id, IssuerKind.PLAYER, new_issued_tick, 0)
	unit_card_id = new_unit_card_id
	action = new_action


func get_supersession_key() -> String:
	return "UNIT_CARD_CONTROL_%s" % unit_card_id


func duplicate_value() -> UnitCardControlCommand:
	var result := UnitCardControlCommand.new(command_id, issuer_id, issued_tick, unit_card_id, action)
	result.issuer_kind = issuer_kind
	result.agent_id = agent_id
	result.automatic_return = automatic_return
	return result
