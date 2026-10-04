class_name StrategicRegionSnapshot
extends RefCounted

var region_id: StringName
var supply_tier: MapSupplyPointDefinition.Tier
var display_name_key: StringName
var terrain_key: StringName
var position: Vector2
var radius: float
var supply_per_settlement: int
var capturable: bool
var capture_required_ticks: int
var controller_faction_id: int
var previous_controller_faction_id: int
var controller_changed_tick: int
var contested: bool
var capture_faction_id: int
var capture_progress_ticks: int
var capture_progress: float
var last_settlement_tick: int
var supply_node_active: bool


func _init(state: StrategicRegionState) -> void:
	region_id = state.region_id
	supply_tier = state.supply_tier
	display_name_key = state.display_name_key
	terrain_key = state.terrain_key
	position = state.position
	radius = state.radius
	supply_per_settlement = state.supply_per_settlement
	capturable = state.capturable
	capture_required_ticks = state.capture_required_ticks
	controller_faction_id = state.controller_faction_id
	previous_controller_faction_id = state.previous_controller_faction_id
	controller_changed_tick = state.controller_changed_tick
	contested = state.contested
	capture_faction_id = state.capture_faction_id
	capture_progress_ticks = state.capture_progress_ticks
	capture_progress = state.capture_ratio()
	last_settlement_tick = state.last_settlement_tick
	supply_node_active = state.supply_node_active
