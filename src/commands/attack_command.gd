class_name AttackCommand
extends GameCommand

var attack_target_entity_id: int
var formation_id: int
# Fire coordination is independent of movement ownership.
var fire_only: bool = false


func _init(
	new_command_id: int,
	new_issuer_id: int,
	new_issuer_kind: IssuerKind,
	new_issued_tick: int,
	new_entity_id: int,
	new_attack_target_entity_id: int,
	new_formation_id: int = 0
) -> void:
	super(new_command_id, new_issuer_id, new_issuer_kind, new_issued_tick, new_entity_id)
	attack_target_entity_id = new_attack_target_entity_id
	formation_id = new_formation_id


func get_supersession_key() -> String:
	if fire_only:
		return "FIRE%d" % formation_id
	if formation_id != 0:
		return "F%d" % formation_id
	return super()


func duplicate_value() -> AttackCommand:
	var copy := AttackCommand.new(command_id, issuer_id, issuer_kind, issued_tick, target_entity_id, attack_target_entity_id, formation_id)
	copy.fire_only = fire_only
	copy.agent_id = agent_id
	copy.task_id = task_id
	return copy
