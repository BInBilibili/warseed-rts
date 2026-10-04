class_name RecruitmentSystem
extends RefCounted

static func validate(world: SimulationWorld, command: GameCommand) -> CommandValidationResult:
	var battle := world.battle_definition
	var faction := world.factions.get(command.issuer_id) as FactionState
	if battle == null or not battle.growth_mode or faction == null:
		return _reject(CommandValidationResult.Reason.INVALID_TARGET)
	if command is RecruitmentPlanCommand:
		if command.issuer_kind != GameCommand.IssuerKind.PLAYER: return _reject(CommandValidationResult.Reason.NOT_CONTROLLER)
		if command.reserve < 0 or command.reserve > faction.supply_capacity or command.commander_ids.size() != command.rates.size(): return _reject(CommandValidationResult.Reason.INVALID_TARGET)
		var seen: Array[StringName] = []
		var total := 0
		var expected := 0
		for leader: CommanderState in world.commanders.values():
			if leader.faction_id == command.issuer_id: expected += 1
		if command.commander_ids.size() != expected: return _reject(CommandValidationResult.Reason.INVALID_TARGET)
		for index in range(command.commander_ids.size()):
			var id: StringName = command.commander_ids[index]
			var leader := world.commanders.get(id) as CommanderState
			if leader == null or leader.faction_id != command.issuer_id or seen.has(id): return _reject(CommandValidationResult.Reason.NOT_CONTROLLER)
			if command.rates[index] < 0 or command.rates[index] > 2: return _reject(CommandValidationResult.Reason.INVALID_TARGET)
			seen.append(id)
			total += command.rates[index]
		return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED) if total <= 5 else _reject(CommandValidationResult.Reason.INVALID_TARGET)
	if command is SupplyPriorityCommand:
		if command.issuer_kind != GameCommand.IssuerKind.PLAYER:
			return _reject(CommandValidationResult.Reason.NOT_CONTROLLER)
		if command.commander_id.is_empty():
			return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED)
		for card: UnitCardState in world.unit_cards.values():
			if card.faction_id == command.issuer_id and card.commander_definition_id == command.commander_id:
				return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED)
		return _reject(CommandValidationResult.Reason.NOT_CONTROLLER)
	var order := command as RecruitUnitCardCommand
	if order.issuer_kind == GameCommand.IssuerKind.AGENT and not world._agent_authorization_allows(order):
		return _reject(CommandValidationResult.Reason.AGENT_NOT_AUTHORIZED)
	var card := world.unit_cards.get(order.unit_card_id) as UnitCardState
	if card == null or card.faction_id != order.issuer_id:
		return _reject(CommandValidationResult.Reason.NOT_CONTROLLER)
	if order.issuer_kind == GameCommand.IssuerKind.AGENT and RecruitmentArbitrationSystem.pending_intent_reason(world, order.issuer_id, order.unit_card_id) != &"":
		return _reject(CommandValidationResult.Reason.TASK_CONFLICT)
	var commander := world.commanders.get(card.commander_definition_id) as CommanderState
	if commander == null: return _reject(CommandValidationResult.Reason.INVALID_TARGET)
	var pending_recruits: Array[RecruitUnitCardCommand] = []
	for queued in world.command_queue.snapshot():
		if queued is RecruitUnitCardCommand and queued.issuer_id == order.issuer_id: pending_recruits.append(queued)
	var slot := LegionGrowthSystem.next_for_world(world, commander, pending_recruits)
	var template := LegionTemplate.find(commander.definition.profile.profile_id)
	if order.member_count != 1 or slot < 0 or (order.legion_slot >= 0 and order.legion_slot != slot):
		return _reject(CommandValidationResult.Reason.INVALID_TARGET)
	if LegionGrowthSystem.ROLE_KEYS[template.slot_roles()[slot]] != card.definition.role_key:
		return _reject(CommandValidationResult.Reason.INVALID_TARGET)
	if order.member_count <= 0 or order.member_count > battle.recruitment_batch_size:
		return _reject(CommandValidationResult.Reason.INVALID_TARGET)
	var view := UnitCardSnapshot.new(card, world.units)
	if card.deployment_state != UnitCardState.DeploymentState.DEPLOYED or (view.current_strength > 0 and not world.formations.has(card.formation_id)):
		return _reject(CommandValidationResult.Reason.INVALID_DEPLOYMENT_STATE)
	if order.issuer_kind == GameCommand.IssuerKind.AGENT and (card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED or order.agent_id == 0 or order.agent_id != card.assigned_agent_id or order.task_id != card.assigned_task_id):
		return _reject(CommandValidationResult.Reason.AGENT_OVERRIDE_BLOCKED)
	if view.current_strength + order.member_count > view.authorized_strength:
		return _reject(CommandValidationResult.Reason.UNIT_CARD_FULL_STRENGTH)
	if view.current_strength == 0 and world.current_tick - card.last_damage_tick < 200:
		return _reject(CommandValidationResult.Reason.SUPPORT_COOLDOWN)
	var group_counts: Dictionary[StringName, int] = {}
	if faction.recruitment_window == world.current_tick / 10: group_counts.assign(faction.recruited_by_commander)
	var total := 0
	for value in group_counts.values(): total += value
	var group_total: int = group_counts.get(card.commander_definition_id, 0)
	var card_pending := 0
	var knowledge := world.create_logistics_snapshot(order.issuer_id, false)
	var position := AutomaticLogisticsAgent.recruitment_position(knowledge, view, battle)
	if not AutomaticLogisticsAgent.is_in_supply(knowledge, position, battle):
		return _reject(CommandValidationResult.Reason.OUT_OF_RANGE)
	if not AutomaticLogisticsAgent.is_safe(knowledge, position, battle) or world.current_tick - card.last_damage_tick < 20:
		return _reject(CommandValidationResult.Reason.TACTICAL_UNSAFE)
	var pending_supply := 0
	var pending_population := 0
	for pending in world.command_queue.snapshot():
		if pending.issuer_id != order.issuer_id:
			continue
		if pending is RecruitUnitCardCommand:
			var queued_card := world.unit_cards.get(pending.unit_card_id) as UnitCardState
			if queued_card != null:
				pending_supply += queued_card.definition.recruitment_cost * pending.member_count
				pending_population += pending.member_count
				total += pending.member_count
				if queued_card.commander_definition_id == card.commander_definition_id: group_total += pending.member_count
				if pending.unit_card_id == order.unit_card_id: card_pending += pending.member_count
		if pending is SupportOrderCommand or pending is AreaSupportCommand:
			pending_supply += world.get_support_cost(pending.support_kind)
		elif pending is DeployUnitCardCommand:
			var deployed := world.unit_cards.get(pending.unit_card_id) as UnitCardState
			if deployed != null:
				pending_supply += deployed.effective_supply_cost()
				pending_population += deployed.available_strength
		elif pending is TacticalAbilityCommand:
			var tactical := world.unit_cards.get(pending.unit_card_id) as UnitCardState
			if tactical != null and tactical.definition.tactical_ability != null:
				pending_supply += tactical.definition.tactical_ability.supply_cost
	var quota: int = faction.recruitment_rates.get(card.commander_definition_id, 2 if card.commander_definition_id == faction.priority_commander_id else 1)
	if total + order.member_count > 5 or group_total + order.member_count > quota:
		return _reject(CommandValidationResult.Reason.SUPPORT_COOLDOWN)
	if view.current_strength + card_pending + order.member_count > view.authorized_strength:
		return _reject(CommandValidationResult.Reason.UNIT_CARD_FULL_STRENGTH)
	if faction.supply - pending_supply - faction.recruitment_reserve < card.definition.recruitment_cost * order.member_count:
		return _reject(CommandValidationResult.Reason.INSUFFICIENT_SUPPLY)
	var reserve_view := world.create_logistics_snapshot(order.issuer_id, true)
	if faction.supply - pending_supply - faction.recruitment_reserve - LegionRecruitmentPolicy.held_for_other(reserve_view, card.commander_definition_id, pending_recruits) < card.definition.recruitment_cost:
		return _reject(CommandValidationResult.Reason.INSUFFICIENT_SUPPLY)
	if faction.population + pending_population + order.member_count > faction.population_capacity:
		return _reject(CommandValidationResult.Reason.POPULATION_FULL)
	return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED)

static func _reject(reason: CommandValidationResult.Reason) -> CommandValidationResult:
	return CommandValidationResult.new(CommandValidationResult.Status.REJECTED, reason)

static func record_spend(faction: FactionState, tick: int, recruitment: int, support: int) -> void:
	if faction.spend_window != tick / 10:
		faction.previous_recruitment_spend = faction.recruitment_spend if faction.spend_window == tick / 10 - 1 else 0
		faction.previous_support_spend = faction.support_spend if faction.spend_window == tick / 10 - 1 else 0
		faction.recruitment_spend = 0
		faction.support_spend = 0
		faction.spend_window = tick / 10
	faction.recruitment_spend += recruitment
	faction.support_spend += support
