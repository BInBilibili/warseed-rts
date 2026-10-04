class_name LegionDeploymentPlan
extends RefCounted

enum Status { STANDARD, COMPRESSED, TRANSIT_ONLY, BLOCKED }
var status: Status = Status.BLOCKED
var spacing := 48.0
var anchor := Vector2.ZERO
var facing := Vector2.RIGHT
var identities := PackedInt32Array()
var points := PackedVector2Array()
var standard_points := PackedVector2Array()
var offsets := PackedVector2Array()
var reason: StringName = &"DEPLOYMENT_NO_SPACE"
var formation_id := 0
var commander_id: StringName
var allow_compression := true

func duplicate_value() -> LegionDeploymentPlan:
	var copy := LegionDeploymentPlan.new()
	copy.status=status; copy.spacing=spacing; copy.anchor=anchor; copy.facing=facing
	copy.identities=identities.duplicate(); copy.points=points.duplicate()
	copy.standard_points=standard_points.duplicate(); copy.offsets=offsets.duplicate(); copy.reason=reason
	copy.formation_id=formation_id; copy.commander_id=commander_id
	copy.allow_compression=allow_compression
	return copy
