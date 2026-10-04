class_name MapConnectorDefinition
extends Resource

@export var connector_id: StringName
@export var mirror_id: StringName
@export var from_lane_id: StringName
@export var to_lane_id: StringName
@export var width_cells: int = 7
@export var route_points: PackedVector2Array = PackedVector2Array()
@export var supply_point_ids: Array[StringName] = []
@export var tactical_tags: Array[StringName] = []
