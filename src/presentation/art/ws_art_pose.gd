class_name WsArtPose
extends RefCounted
## A value-only presentation DTO, populated ONLY from the authorized snapshot.
var entity_id: int = 0
var definition_id: StringName = &"scout_vehicle"
var position: Vector2 = Vector2.ZERO
var heading: float = 0.0
var blue: bool = true
var enabled: bool = true
var contact_only: bool = false
var intel_freshness: float = 1.0

var deployment_progress := 0.0
