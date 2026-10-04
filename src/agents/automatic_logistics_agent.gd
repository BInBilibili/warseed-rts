class_name AutomaticLogisticsAgent
extends RefCounted

# Decisions consume only friendly cards, public supply control and observed threats.
func propose(snapshot: WorldSnapshot, battle: BattleDefinition, pending: Array[RecruitUnitCardCommand] = []) -> GameCommand:
	if snapshot == null or snapshot.is_true_state or snapshot.knowledge == null or snapshot.knowledge.faction_id != snapshot.observer_faction_id or battle == null or not battle.automatic_reinforcement:
		return null
	if battle.growth_mode:
		return _propose_growth(snapshot, battle, pending)
	var faction := snapshot.get_faction(snapshot.observer_faction_id)
	var support := battle.support_for_kind(SupportOrderCommand.SupportKind.FIELD_REINFORCEMENT)
	if faction == null or support == null or faction.population >= faction.population_capacity or faction.supply < support.supply_cost + battle.reinforcement_supply_reserve:
		return null
	if maxi(faction.reinforcement_cooldown_until_tick, int(faction.support_cooldown_until_by_kind.get(support.support_kind, 0))) > snapshot.tick:
		return null
	var cards: Array[UnitCardSnapshot] = []
	for card in snapshot.unit_cards:
		if card.faction_id != snapshot.observer_faction_id or card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED or card.assigned_agent_id == 0 or card.is_player_overridden:
			continue
		if card.deployment_state != UnitCardState.DeploymentState.DEPLOYED or card.current_strength <= 0 or card.current_strength >= card.authorized_strength:
			continue
		if not is_in_supply(snapshot, card.center_position, battle) or not is_safe(snapshot, card.center_position, battle):
			continue
		cards.append(card)
	cards.sort_custom(func(a: UnitCardSnapshot, b: UnitCardSnapshot) -> bool:
		var a_ratio := float(a.current_strength) / a.authorized_strength
		var b_ratio := float(b.current_strength) / b.authorized_strength
		return a_ratio < b_ratio if not is_equal_approx(a_ratio, b_ratio) else String(a.definition_id) < String(b.definition_id))
	if cards.is_empty():
		return null
	var card := cards[0]
	var command := SupportOrderCommand.new(0, snapshot.observer_faction_id, GameCommand.IssuerKind.AGENT, snapshot.tick, support.support_kind, &"", &"", card.definition_id)
	command.agent_id = card.assigned_agent_id
	command.task_id = card.assigned_task_id
	return command


static func is_in_supply(snapshot: WorldSnapshot, position: Vector2, battle: BattleDefinition) -> bool:
	for region in snapshot.strategic_regions:
		if region.controller_faction_id == snapshot.observer_faction_id and not region.contested and position.distance_to(region.position) <= battle.reinforcement_supply_radius:
			return true
	return false


static func is_safe(snapshot: WorldSnapshot, position: Vector2, battle: BattleDefinition) -> bool:
	for unit in snapshot.units:
		if unit.faction_id != snapshot.observer_faction_id and unit.enabled and unit.is_visible_to_local_player and position.distance_to(unit.position) < battle.reinforcement_safe_radius:
			return false
	return true


func _propose_growth(snapshot: WorldSnapshot, battle: BattleDefinition, pending: Array[RecruitUnitCardCommand]) -> RecruitUnitCardCommand:
	return LegionRecruitmentPolicy.propose(snapshot, battle, pending)


static func recruitment_weight(snapshot: WorldSnapshot, card: UnitCardSnapshot) -> float:
	var commander := snapshot.get_commander(card.commander_definition_id)
	if commander == null:
		return 1.0
	if commander.personality_key == &"PERSONALITY_CAUTIOUS" and card.role_key == &"UNIT_CARD_ROLE_RECON":
		return 2.0
	if commander.personality_key == &"PERSONALITY_METHODICAL" and card.role_key == &"UNIT_CARD_ROLE_FIREPOWER":
		return 2.0
	if commander.personality_key in [&"PERSONALITY_RESOLUTE", &"PERSONALITY_OPPORTUNISTIC"] and card.role_key == &"UNIT_CARD_ROLE_ARMOR":
		return 2.0
	return 1.0


static func recruitment_position(snapshot: WorldSnapshot, card: UnitCardSnapshot, battle: BattleDefinition) -> Vector2:
	if card.current_strength > 0:
		return card.center_position
	var base := battle.player_headquarters_position if snapshot.observer_faction_id == 1 else battle.enemy_headquarters_position
	return base + Vector2(256.0, 256.0) * (1.0 if snapshot.observer_faction_id == 1 else -1.0)
