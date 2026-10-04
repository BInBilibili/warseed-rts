class_name FactionState
extends RefCounted

var faction_id: int
var controller_id: int
var ore: int
var defeated: bool = false
var victorious: bool = false
var supply: int = 0
var supply_capacity: int = 0
var population: int = 0
var population_capacity: int = 0
var air_recon_cooldown_until_tick: int = 0
var fortify_cooldown_until_tick: int = 0
var reinforcement_cooldown_until_tick: int = 0
var recruitment_ready_tick: int = 0
var recruitment_reserve: int = 12
var recruitment_rates: Dictionary[StringName, int] = {}
var recruitment_window: int = -1
var recruited_by_commander: Dictionary[StringName, int] = {}
var recruitment_arbitration := RecruitmentArbitrationState.new()
var recruitment_spend: int = 0
var support_spend: int = 0
var spend_window: int = -1
var previous_recruitment_spend: int = 0
var previous_support_spend: int = 0
var priority_commander_id: StringName
var support_cooldown_until_by_kind: Dictionary = {}
var opened_engineering_route_ids: Array[StringName] = []


func _init(new_faction_id: int, new_controller_id: int, initial_ore: int) -> void:
	faction_id = new_faction_id
	controller_id = new_controller_id
	ore = initial_ore
