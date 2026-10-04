class_name TacticalCardAgent
extends RefCounted


func propose(snapshot: WorldSnapshot, battle: BattleDefinition) -> Array[TacticalAbilityCommand]:
	var commands: Array[TacticalAbilityCommand] = []
	if snapshot == null or snapshot.is_true_state:
		return commands
	var considered: Dictionary = {}
	for decision in TacticalActionProjector.new().project(snapshot, battle):
		var card := snapshot.get_unit_card(decision.unit_card_id)
		if considered.has(card.definition_id) or decision.reason != CommandValidationResult.Reason.NONE:
			continue
		if card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED or card.assigned_agent_id == 0 or card.assigned_task_id == 0:
			continue
		var task := snapshot.get_task(card.assigned_task_id)
		if task == null or task.agent_id != card.assigned_agent_id or task.lifecycle not in [TaskState.Lifecycle.PREPARING, TaskState.Lifecycle.EXECUTING]:
			continue
		if battle.automatic_reinforcement:
			var faction := snapshot.get_faction(snapshot.observer_faction_id)
			var reserve := faction.recruitment_reserve if battle.growth_mode and faction != null else battle.reinforcement_supply_reserve
			if faction == null or faction.supply < decision.supply_cost + reserve:
				continue
			if card.tactical_kind in [TacticalAbilityDefinition.Kind.OBSERVE, TacticalAbilityDefinition.Kind.BREAKTHROUGH]:
				var contact_nearby := false
				for hostile in snapshot.units:
					if hostile.enabled and hostile.faction_id != card.faction_id and hostile.is_visible_to_local_player and hostile.position.distance_to(card.center_position) <= 720.0:
						contact_nearby = true
				if not contact_nearby:
					var at_base := false
					for building in snapshot.buildings:
						if building.enabled and building.faction_id == card.faction_id and building.definition_id == &"command_center" and building.position.distance_to(card.center_position) <= battle.reinforcement_supply_radius:
							at_base = true
					if card.tactical_kind == TacticalAbilityDefinition.Kind.BREAKTHROUGH or at_base:
						continue
		var moving := false
		for id in card.active_member_entity_ids:
			var unit := snapshot.get_unit(id)
			moving = moving or unit != null and unit.is_moving
		if moving:
			continue
		var command := TacticalActionProjector.command_for(decision, 0, snapshot.observer_faction_id, snapshot.tick, GameCommand.IssuerKind.AGENT)
		command.agent_id = card.assigned_agent_id
		command.task_id = card.assigned_task_id
		commands.append(command)
		considered[card.definition_id] = true
	return commands
