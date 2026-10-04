class_name MapWildRegionDefinition
extends Resource

@export var region_id: StringName
@export var mirror_id: StringName
@export var display_name_key: StringName
@export var center: Vector2
@export var width_cells: int = 20
@export var depth_cells: int = 20
@export var connected_lane_ids: Array[StringName] = []
@export var tactical_tags: Array[StringName] = []
