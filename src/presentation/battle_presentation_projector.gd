class_name BattlePresentationProjector
extends RefCounted

# Each thread owns its projector and mutable geometry/knowledge caches.
var _situation := BattlefieldSituationProjector.new()
var _command := CommandSituationProjector.new()

func project(snapshot: WorldSnapshot, battle: BattleDefinition) -> BattlePresentationView:
	var result := BattlePresentationView.new()
	result.source = snapshot
	result.definition = battle
	var costs := {}
	if battle != null:
		for support in battle.support_abilities: costs[String(support.support_id)] = support.supply_cost
	result.situation = _situation.project(snapshot, SimulationWorld.LOCAL_PLAYER_ID,
		battle.battlefield_bounds if battle != null else SimulationWorld.BATTLEFIELD_BOUNDS,
		battle.base_supply_interval_ticks if battle != null else BattlefieldSituationProjector.DEFAULT_BASE_SUPPLY_INTERVAL_TICKS,
		battle.region_settlement_interval_ticks if battle != null else BattlefieldSituationProjector.DEFAULT_REGION_SETTLEMENT_INTERVAL_TICKS,
		costs, battle.base_supply_amount if battle != null else 1)
	if result.situation != null:
		result.command_situation = _command.project(snapshot, result.situation, SimulationWorld.LOCAL_PLAYER_ID)
	return result
