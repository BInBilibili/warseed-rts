class_name RecruitmentArbitrationSystem
extends RefCounted

static func pending_for(world: SimulationWorld, faction_id: int) -> Array[RecruitUnitCardCommand]:
	var pending: Array[RecruitUnitCardCommand] = []
	for command in world.command_queue.snapshot():
		if command is RecruitUnitCardCommand and command.issuer_id == faction_id:
			pending.append(command)
	return pending

static func pending_intent_reason(world: SimulationWorld, faction_id: int, card_id: StringName = &"") -> StringName:
	for command in world.command_queue.snapshot():
		if command.issuer_id != faction_id: continue
		if command is RecruitmentPlanCommand or command is SupplyPriorityCommand:
			return &"GROWTH_WAIT_RECHECK"
		if command is UnitCardControlCommand and command.unit_card_id == card_id and command.action in [UnitCardControlCommand.Action.TAKEOVER, UnitCardControlCommand.Action.STAY_MANUAL]:
			return &"GROWTH_WAIT_CONTROL"
	return &""

static func policy_view(world: SimulationWorld, faction_id: int) -> WorldSnapshot:
	var view := world.create_logistics_snapshot(faction_id, true)
	for card in view.unit_cards:
		if card.faction_id == faction_id and pending_intent_reason(world, faction_id, card.definition_id) == &"GROWTH_WAIT_CONTROL":
			card.is_player_overridden = true
	return view

static func cancel_for_player_intent(world: SimulationWorld, command: GameCommand) -> void:
	if world.battle_definition == null or not world.battle_definition.growth_mode or command.issuer_kind != GameCommand.IssuerKind.PLAYER:
		return
	var all_recruits := command is RecruitmentPlanCommand or command is SupplyPriorityCommand
	var takeover: bool = command is UnitCardControlCommand and command.action in [UnitCardControlCommand.Action.TAKEOVER, UnitCardControlCommand.Action.STAY_MANUAL]
	if not all_recruits and not takeover: return
	world.command_queue.remove_if(func(queued: GameCommand) -> bool:
		if queued is not RecruitUnitCardCommand or queued.issuer_kind != GameCommand.IssuerKind.AGENT or queued.issuer_id != command.issuer_id:
			return false
		if not all_recruits and queued.unit_card_id != command.unit_card_id: return false
		world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.COMMAND_REJECTED, queued.target_entity_id, "automatic recruitment superseded by player policy"))
		return true)

static func refresh_all(world: SimulationWorld) -> void:
	if world.battle_definition == null or not world.battle_definition.growth_mode:
		return
	var ids := world.factions.keys()
	ids.sort()
	for id in ids: refresh(world, id)

static func refresh(world: SimulationWorld, faction_id: int) -> void:
	if world.battle_definition == null or not world.battle_definition.growth_mode:
		return
	var faction := world.factions.get(faction_id) as FactionState
	if faction == null: return
	var state := faction.recruitment_arbitration
	var view := policy_view(world, faction_id)
	var items := LegionRecruitmentPolicy.candidates(view, world.battle_definition, [], true)
	var pending := pending_for(world, faction_id)
	var queued_by_commander: Dictionary[StringName, int] = {}
	var queued_counts: Dictionary[StringName, int] = {}
	var total := 0
	if faction.recruitment_window == world.current_tick / 10:
		for count in faction.recruited_by_commander.values(): total += count
	for command in pending:
		var card := view.get_unit_card(command.unit_card_id)
		if card != null:
			# A second-round order must not hide the first committed identity.
			if not queued_by_commander.has(card.commander_definition_id):
				queued_by_commander[card.commander_definition_id] = command.legion_slot
			queued_counts[card.commander_definition_id] = queued_counts.get(card.commander_definition_id, 0) + command.member_count
			total += command.member_count
	var valid: Array[LegionRecruitmentCandidate] = []
	state.reasons.clear()
	for item in items:
		var id := item.commander_id
		if pending_intent_reason(world, faction_id) != &"": item.reason = &"GROWTH_WAIT_RECHECK"
		state.reasons[id] = item.reason
		if not item.is_eligible():
			# Space/refusal cooldown is temporary. Keep the identity and wait age,
			# but exclude it from reservation and purchasing until retry is legal.
			var refusal_active: bool = state.refusal_until.get(id, -1) > world.current_tick and item.reason == state.refusal_reasons.get(id, &"")
			if not refusal_active:
				state.waiting_since.erase(id)
				state.selected_slots.erase(id)
			continue
		if state.selected_slots.get(id, -1) != item.slot:
			state.selected_slots[id] = item.slot
			state.waiting_since[id] = world.current_tick
		elif not state.waiting_since.has(id):
			state.waiting_since[id] = world.current_tick
		valid.append(item)
		if queued_by_commander.has(id): state.reasons[id] = &"GROWTH_WAIT_QUEUED"
		elif total >= 5 or item.count_in_window + queued_counts.get(id, 0) >= item.quota: state.reasons[id] = &"GROWTH_WAIT_WINDOW"
	var free := world.area_support_system.available_supply(world, faction_id) - faction.recruitment_reserve
	var owner: LegionRecruitmentCandidate
	for item in valid:
		if item.commander_id == state.reserved_commander_id and item.slot == state.reserved_slot and item.count_in_window < item.quota and (total < 5 or queued_by_commander.has(item.commander_id)):
			owner = item
			break
	if owner == null or free < 0 or faction.population >= faction.population_capacity:
		state.clear_reservation()
		owner = null
	if owner == null and free >= 0 and total < 5 and faction.population < faction.population_capacity:
		var waiting: Array[LegionRecruitmentCandidate] = []
		for item in valid:
			if item.count_in_window < item.quota and not queued_by_commander.has(item.commander_id) and free < item.card.recruitment_cost:
				waiting.append(item)
		waiting.sort_custom(func(a: LegionRecruitmentCandidate, b: LegionRecruitmentCandidate) -> bool:
			var a_tick: int = state.waiting_since.get(a.commander_id, world.current_tick)
			var b_tick: int = state.waiting_since.get(b.commander_id, world.current_tick)
			return a_tick < b_tick if a_tick != b_tick else String(a.commander_id) < String(b.commander_id))
		if not waiting.is_empty():
			owner = waiting[0]
			state.reserved_commander_id = owner.commander_id
			state.reserved_slot = owner.slot
	if owner != null:
		state.reserved_cost = owner.card.recruitment_cost
		state.reserved_amount = 0 if queued_by_commander.get(owner.commander_id, -1) == owner.slot else mini(state.reserved_cost, maxi(0, free))
	for item in valid:
		var id := item.commander_id
		if state.reasons[id] != &"GROWTH_WAIT_READY": continue
		if faction.population >= faction.population_capacity:
			state.reasons[id] = &"GROWTH_WAIT_POPULATION"
		elif free < 0:
			state.reasons[id] = &"GROWTH_WAIT_RESERVE"
		elif id == state.reserved_commander_id:
			state.reasons[id] = &"GROWTH_WAIT_SAVING" if free < item.card.recruitment_cost else &"GROWTH_WAIT_READY"
		elif free - state.reserved_amount < item.card.recruitment_cost:
			state.reasons[id] = &"GROWTH_WAIT_OTHER" if state.reserved_amount > 0 else &"GROWTH_WAIT_FUNDS"
		if state.refusal_until.get(id, -1) > world.current_tick:
			state.reasons[id] = state.refusal_reasons.get(id, &"GROWTH_WAIT_RECHECK")

static func complete(world: SimulationWorld, faction_id: int, commander_id: StringName) -> void:
	var state: RecruitmentArbitrationState = world.factions[faction_id].recruitment_arbitration
	state.last_served_commander_id = commander_id
	state.selected_slots.erase(commander_id)
	state.waiting_since.erase(commander_id)
	state.refusal_until.erase(commander_id)
	state.refusal_reasons.erase(commander_id)
	state.reasons[commander_id] = &"GROWTH_WAIT_READY"
	if state.reserved_commander_id == commander_id: state.clear_reservation()

static func rejected(world: SimulationWorld, command: RecruitUnitCardCommand, reason: StringName = &"GROWTH_WAIT_SPACE") -> void:
	var card := world.unit_cards.get(command.unit_card_id) as UnitCardState
	if card == null: return
	var state: RecruitmentArbitrationState = world.factions[command.issuer_id].recruitment_arbitration
	state.reasons[card.commander_definition_id] = reason
	state.refusal_until[card.commander_definition_id] = world.current_tick + 10
	state.refusal_reasons[card.commander_definition_id] = reason
	if state.reserved_commander_id == card.commander_definition_id: state.clear_reservation()

static func propose_commands(world: SimulationWorld, faction_id: int) -> void:
	refresh(world, faction_id)
	if pending_intent_reason(world, faction_id) != &"": return
	for attempt in range(5):
		var view := policy_view(world, faction_id)
		var pending := pending_for(world, faction_id)
		var queued_cost := 0
		for command in pending:
			var card := view.get_unit_card(command.unit_card_id)
			if card != null: queued_cost += card.recruitment_cost * command.member_count
		# Policy subtracts pending recruits itself. Other committed commands must
		# also reduce spendable funds; this changes only our private value snapshot.
		view.get_faction(faction_id).supply = world.area_support_system.available_supply(world, faction_id) + queued_cost
		var command := AutomaticLogisticsAgent.new().propose(view, world.battle_definition, pending)
		if command == null: break
		command.command_id = world.allocate_command_id()
		if not world.submit_command(command).is_accepted(): break
		refresh(world, faction_id)
	refresh(world, faction_id)
