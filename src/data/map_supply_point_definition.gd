class_name MapSupplyPointDefinition
extends Resource

enum Tier { GENERIC, COMMAND, HIGH_GROUND, INNER, OUTER, JUNGLE_SMALL, JUNGLE_LARGE }

@export var point_id: StringName
@export var display_name_key: StringName
@export var position: Vector2
@export var mirror_id: StringName
@export var owner_faction_id: int = 0
@export var supply_per_settlement: int = 1
@export var radius: float = 256.0
@export var capture_ticks: int = 120
@export var lane_id: StringName
@export var is_base: bool = false
@export var is_wild: bool = false
@export var tier: Tier = Tier.GENERIC
@export var tactical_tags: Array[StringName] = []
