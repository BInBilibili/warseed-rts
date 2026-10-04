class_name MapLaneDefinition
extends Resource

@export var lane_id: StringName
@export var mirror_id: StringName
@export var display_name_key: StringName
@export var width_cells: int = 12
@export var route_points: PackedVector2Array = PackedVector2Array()
@export var supply_point_ids: Array[StringName] = []
@export var wild_region_ids: Array[StringName] = []
@export var tactical_tags: Array[StringName] = []
