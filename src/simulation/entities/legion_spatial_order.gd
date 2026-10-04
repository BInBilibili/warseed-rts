class_name LegionSpatialOrder
extends RefCounted

var identity := -1
var entity_id := 0
var offset := Vector2.ZERO
var target := Vector2.ZERO
var path := PackedVector2Array()
var path_index := 0
var reason: StringName = &"FORMING"
var at_destination := false
var admitted := false
var staging_since := -1
var tolerance := 6.0

func duplicate_value() -> LegionSpatialOrder:
	var copy := LegionSpatialOrder.new()
	copy.identity = identity; copy.entity_id = entity_id; copy.offset = offset
	copy.target = target; copy.path = path.duplicate(); copy.path_index = path_index
	copy.reason = reason; copy.at_destination = at_destination
	copy.admitted = admitted; copy.staging_since = staging_since
	copy.tolerance=tolerance
	return copy
