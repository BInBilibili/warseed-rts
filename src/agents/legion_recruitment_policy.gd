class_name LegionRecruitmentPolicy
extends RefCounted

# Pure policy: all inputs are value snapshots from the same legal faction view.
static func candidates(view: WorldSnapshot, battle: BattleDefinition, pending: Array[RecruitUnitCardCommand] = [], ignore_window: bool = false) -> Array[LegionRecruitmentCandidate]:
	var result: Array[LegionRecruitmentCandidate] = []
	var faction := view.get_faction(view.observer_faction_id)
	if faction == null or view.is_true_state or view.knowledge == null or view.knowledge.faction_id != view.observer_faction_id:
		return result
	for commander in view.commanders:
		if commander.faction_id != view.observer_faction_id:
			continue
		var item := LegionRecruitmentCandidate.new()
		item.commander_id = commander.definition_id
		item.quota = faction.recruitment_rates.get(item.commander_id, 2 if item.commander_id == faction.priority_commander_id else 1)
		if faction.recruitment_window == view.tick / 10:
			item.count_in_window = faction.recruited_by_commander.get(item.commander_id, 0)
		for command in pending:
			var card := view.get_unit_card(command.unit_card_id)
			if command.issuer_id == view.observer_faction_id and card != null and card.commander_definition_id == item.commander_id:
				item.count_in_window += command.member_count
		result.append(item)
		if item.quota <= 0:
			item.reason = &"GROWTH_WAIT_PAUSED"
			continue
		if commander.legion_regrouping:
			item.reason = &"GROWTH_WAIT_HERO"
			continue
		item.slot = LegionGrowthSystem.next_for_snapshot(view, commander, pending)
		var template := LegionTemplate.find(commander.profile_id)
		if item.slot < 0 or template == null:
			continue
		var role := LegionGrowthSystem.ROLE_KEYS[template.slot_roles()[item.slot]]
		for id in commander.subordinate_unit_card_ids:
			var card := view.get_unit_card(id)
			if card != null and card.role_key == role:
				item.card = card
				break
		if item.card == null:
			continue
		var card := item.card
		if card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED or card.assigned_agent_id == 0 or card.is_player_overridden:
			item.reason = &"GROWTH_WAIT_CONTROL"
		elif card.deployment_state != UnitCardState.DeploymentState.DEPLOYED:
			item.reason = &"GROWTH_WAIT_CONTROL"
		elif card.current_strength == 0 and view.tick - card.last_damage_tick < 200:
			item.reason = &"GROWTH_WAIT_REBUILD"
		elif view.tick - card.last_damage_tick < 20:
			item.reason = &"GROWTH_WAIT_UNSAFE"
		else:
			var position := AutomaticLogisticsAgent.recruitment_position(view, card, battle)
			if not AutomaticLogisticsAgent.is_in_supply(view, position, battle):
				item.reason = &"GROWTH_WAIT_OUT_OF_SUPPLY"
			elif not AutomaticLogisticsAgent.is_safe(view, position, battle):
				item.reason = &"GROWTH_WAIT_UNSAFE"
			elif not ignore_window and item.count_in_window >= item.quota:
				item.reason = &"GROWTH_WAIT_WINDOW"
			elif faction.recruitment_arbitration.refusal_until.get(item.commander_id, -1) > view.tick:
				item.reason = faction.recruitment_arbitration.refusal_reasons.get(item.commander_id, &"GROWTH_WAIT_RECHECK")
			else:
				item.reason = &"GROWTH_WAIT_READY"
	result.sort_custom(func(a: LegionRecruitmentCandidate, b: LegionRecruitmentCandidate) -> bool: return String(a.commander_id) < String(b.commander_id))
	return result


static func propose(view: WorldSnapshot, battle: BattleDefinition, pending: Array[RecruitUnitCardCommand]) -> RecruitUnitCardCommand:
	var faction := view.get_faction(view.observer_faction_id)
	if faction == null:
		return null
	var total := 0
	if faction.recruitment_window == view.tick / 10:
		for amount in faction.recruited_by_commander.values(): total += amount
	var spent := 0
	var pending_population := 0
	for command in pending:
		if command.issuer_id != view.observer_faction_id: continue
		var card := view.get_unit_card(command.unit_card_id)
		if card == null: continue
		total += command.member_count
		pending_population += command.member_count
		spent += card.recruitment_cost * command.member_count
	if total >= 5 or faction.population + pending_population >= faction.population_capacity:
		return null
	var state := faction.recruitment_arbitration
	var eligible: Array[LegionRecruitmentCandidate] = []
	for item in candidates(view, battle, pending):
		if item.is_eligible(): eligible.append(item)
	var cursor := state.last_served_commander_id
	eligible.sort_custom(func(a: LegionRecruitmentCandidate, b: LegionRecruitmentCandidate) -> bool:
		if a.count_in_window != b.count_in_window: return a.count_in_window < b.count_in_window
		if (a.commander_id == state.reserved_commander_id) != (b.commander_id == state.reserved_commander_id): return a.commander_id == state.reserved_commander_id
		var a_after := String(a.commander_id) > String(cursor)
		var b_after := String(b.commander_id) > String(cursor)
		if a_after != b_after: return a_after
		return String(a.commander_id) < String(b.commander_id))
	var free := faction.supply - spent - faction.recruitment_reserve
	for item in eligible:
		var held := held_for_other(view, item.commander_id, pending)
		if free - held < item.card.recruitment_cost:
			continue
		var command := RecruitUnitCardCommand.new(0, view.observer_faction_id, GameCommand.IssuerKind.AGENT, view.tick, item.card.definition_id, 1)
		command.legion_slot = item.slot
		command.agent_id = item.card.assigned_agent_id
		command.task_id = item.card.assigned_task_id
		return command
	return null


static func held_for_other(view: WorldSnapshot, commander_id: StringName, pending: Array[RecruitUnitCardCommand]) -> int:
	var state := view.get_faction(view.observer_faction_id).recruitment_arbitration
	if state.reserved_commander_id.is_empty() or state.reserved_commander_id == commander_id:
		return 0
	for command in pending:
		var card := view.get_unit_card(command.unit_card_id)
		if command.issuer_id == view.observer_faction_id and card != null and card.commander_definition_id == state.reserved_commander_id and command.legion_slot == state.reserved_slot:
			# The queue already accounts for this cost; do not reserve it twice.
			return 0
	return state.reserved_amount
