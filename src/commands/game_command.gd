class_name GameCommand
extends RefCounted

enum IssuerKind {
	PLAYER,
	AGENT,
}

var command_id: int
var issuer_id: int
var issuer_kind: IssuerKind
var issued_tick: int
var target_entity_id: int
var agent_id: int = 0
var task_id: int = 0
# Stamped on the queued value by the unified pipeline, never supplied by AI.
var authority_commander_id: StringName
var authority_card_id: StringName
var expected_commander_version: int = -1
var expected_card_version: int = -1
var preserve_queue_order: bool = false
var application_rejection: CommandValidationResult.Reason = CommandValidationResult.Reason.NONE
var scoped_card_ids: Array[StringName] = []
var scoped_card_versions := PackedInt32Array()
var scoped_commander_versions := PackedInt32Array()


func get_priority() -> int:
	return 300 if issuer_kind == IssuerKind.PLAYER else 100


func get_supersession_key() -> String:
	return "U%d" % target_entity_id


func _init(
	new_command_id: int,
	new_issuer_id: int,
	new_issuer_kind: IssuerKind,
	new_issued_tick: int,
	new_target_entity_id: int
) -> void:
	command_id = new_command_id
	issuer_id = new_issuer_id
	issuer_kind = new_issuer_kind
	issued_tick = new_issued_tick
	target_entity_id = new_target_entity_id
