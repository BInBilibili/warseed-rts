class_name FactionSnapshot
extends RefCounted

var faction_id: int
var controller_id: int
var ore: int
var defeated: bool
var victorious: bool
var supply: int
var supply_capacity: int
var population: int
var population_capacity: int
var air_recon_cooldown_until_tick: int
var fortify_cooldown_until_tick: int
var reinforcement_cooldown_until_tick: int
var recruitment_ready_tick: int
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
var support_cooldown_until_by_kind: Dictionary
var opened_engineering_route_ids: Array[StringName] = []


func _init(faction: FactionState, include_private_economy: bool = true) -> void:
	faction_id = faction.faction_id
	controller_id = faction.controller_id
	ore = faction.ore if include_private_economy else 0
	defeated = faction.defeated
	victorious = faction.victorious
	supply = faction.supply if include_private_economy else 0
	supply_capacity = faction.supply_capacity if include_private_economy else 0
	population = faction.population if include_private_economy else 0
	population_capacity = faction.population_capacity if include_private_economy else 0
	air_recon_cooldown_until_tick = faction.air_recon_cooldown_until_tick if include_private_economy else 0
	fortify_cooldown_until_tick = faction.fortify_cooldown_until_tick if include_private_economy else 0
	reinforcement_cooldown_until_tick = faction.reinforcement_cooldown_until_tick if include_private_economy else 0
	recruitment_ready_tick = faction.recruitment_ready_tick if include_private_economy else 0
	recruitment_reserve = faction.recruitment_reserve if include_private_economy else 0
	recruitment_window = faction.recruitment_window if include_private_economy else 0
	recruitment_spend = faction.recruitment_spend if include_private_economy else 0
	support_spend = faction.support_spend if include_private_economy else 0
	spend_window = faction.spend_window if include_private_economy else 0
	previous_recruitment_spend = faction.previous_recruitment_spend if include_private_economy else 0
	previous_support_spend = faction.previous_support_spend if include_private_economy else 0
	if include_private_economy: recruitment_rates.assign(faction.recruitment_rates)
	if include_private_economy: recruited_by_commander.assign(faction.recruited_by_commander)
	if include_private_economy: recruitment_arbitration = faction.recruitment_arbitration.duplicate_value()
	priority_commander_id = faction.priority_commander_id if include_private_economy else &""
	support_cooldown_until_by_kind = faction.support_cooldown_until_by_kind.duplicate() if include_private_economy else {}
	if include_private_economy:
		opened_engineering_route_ids.assign(faction.opened_engineering_route_ids)
