extends "res://tests/tools/legion36_economy_contract.gd"

func test_selected_waiting_slot() -> void:
	var world := prepare()
	isolate(world, [&"spear"])
	var commander := leader(world)
	var faction := world.factions[1] as FactionState
	faction.supply = 15
	RecruitmentArbitrationSystem.refresh(world, 1)
	check(faction.recruitment_arbitration.selected_slots.get(commander.definition.definition_id, -1) == 12, "expensive next slot selected before waiting")
	(world.units[commander.growth_slot_entities[0]] as UnitState).enabled = false
	world._refresh_battle_population()
	RecruitmentArbitrationSystem.refresh(world, 1)
	check(LegionGrowthSystem.next_for_world(world, commander) == 12, "safe selected slot survives a different card casualty")
	check(faction.recruitment_arbitration.reserved_slot == 12, "reservation never silently changes purchased role")
	faction.supply += 2
	RecruitmentArbitrationSystem.propose_commands(world, 1)
	apply_queue(world)
	check(commander.growth_unlocked_slots == 13 and faction.supply == 12, "selected armor births and pays five before selecting replacement")
	check(LegionGrowthSystem.next_for_world(world, commander) == 0, "after success missing earlier role regains recovery priority")
	world = prepare()
	isolate(world, [&"spear"])
	commander = leader(world)
	faction = world.factions[1]
	faction.supply = 15
	RecruitmentArbitrationSystem.refresh(world, 1)
	next_card(world, commander).last_damage_tick = world.current_tick
	RecruitmentArbitrationSystem.refresh(world, 1)
	check(not faction.recruitment_arbitration.selected_slots.has(commander.definition.definition_id), "qualification loss releases selected identity")

func test_refusal_does_not_hold_funds() -> void:
	var world := prepare()
	isolate(world, [&"spear", &"guardian"])
	var faction := world.factions[1] as FactionState
	faction.supply = 15
	var card := next_card(world, leader(world))
	RecruitmentArbitrationSystem.refresh(world, 1)
	RecruitmentArbitrationSystem.rejected(world, order(world, card))
	RecruitmentArbitrationSystem.propose_commands(world, 1)
	check(faction.recruitment_arbitration.reserved_commander_id != card.commander_definition_id, "refused owner cannot re-reserve during cooldown")
	var queue := world.command_queue.snapshot()
	check(queue.size() == 1 and world.unit_cards[queue[0].unit_card_id].commander_definition_id == leader(world, &"guardian").definition.definition_id, "other legion can use money during failed-birth cooldown")
	check(faction.recruitment_arbitration.reasons[card.commander_definition_id] == &"GROWTH_WAIT_SPACE", "cooldown retains refusal explanation")

func test_real_tick_batch() -> void:
	var world := prepare()
	isolate(world, [&"spear", &"guardian"])
	var faction := world.factions[1] as FactionState
	faction.supply = 19
	RecruitmentArbitrationSystem.propose_commands(world, 1)
	check(world.command_queue.size() == 2, "exact seven supply admits two distinct purchases")
	world.advance_tick()
	check(faction.population == 62, "real advance_tick preserves both accepted births")
	check(faction.recruitment_spend == 7, "real batch spends exactly admitted costs")

func test_pending_policy_changes() -> void:
	for mode in ["quota", "reserve", "takeover"]:
		var world := prepare()
		isolate(world, [&"spear"])
		var faction := world.factions[1] as FactionState
		faction.supply = 17
		var commander := leader(world)
		var card := next_card(world, commander)
		RecruitmentArbitrationSystem.propose_commands(world, 1)
		check(RecruitmentArbitrationSystem.pending_for(world, 1).size() == 1, "policy fixture has accepted automatic purchase " + mode)
		var command: GameCommand
		if mode == "takeover":
			command = UnitCardControlCommand.new(world.allocate_command_id(), 1, world.current_tick, card.definition.definition_id, UnitCardControlCommand.Action.TAKEOVER)
		else:
			var ids: Array[StringName] = []
			var rates: Array[int] = []
			for profile in LegionTemplate.PROFILE_IDS:
				ids.append(leader(world, profile).definition.definition_id)
				rates.append(1 if mode == "reserve" and profile == &"spear" else 0)
			command = RecruitmentPlanCommand.new(world.allocate_command_id(), 1, world.current_tick, ids, rates, 18 if mode == "reserve" else 12)
		check(world.submit_command(command).is_accepted(), "actual player policy accepted " + mode)
		check(RecruitmentArbitrationSystem.pending_for(world, 1).is_empty(), "player intent cancels queued automatic spend " + mode)
		check(faction.recruitment_arbitration.reserved_commander_id.is_empty(), "pending intent releases reservation " + mode)
		RecruitmentArbitrationSystem.propose_commands(world, 1)
		check(RecruitmentArbitrationSystem.pending_for(world, 1).is_empty(), "automation cannot requeue before accepted intent applies " + mode)
		world.advance_tick()
		check(faction.population == 60 and faction.recruitment_spend == 0, "real tick respects new player intent before any birth " + mode)

func test_queued_window_reason() -> void:
	var world := prepare()
	RecruitmentArbitrationSystem.propose_commands(world, 1)
	apply_queue(world)
	RecruitmentArbitrationSystem.refresh(world, 1)
	for commander: CommanderState in world.commanders.values():
		if commander.faction_id == 1:
			check(world.factions[1].recruitment_arbitration.reasons[commander.definition.definition_id] == &"GROWTH_WAIT_WINDOW", "exhausted faction window is not shown as ready")

func test_order_and_wait_age() -> void:
	var traces: Array[String] = []
	for reversed_order in [false, true]:
		var world := prepare()
		if reversed_order:
			var original := world.commanders.duplicate()
			var keys := original.keys()
			keys.reverse()
			world.commanders.clear()
			for key in keys: world.commanders[key] = original[key]
		var faction := world.factions[1] as FactionState
		faction.supply = 12
		RecruitmentArbitrationSystem.refresh(world, 1)
		var ids := faction.recruitment_arbitration.waiting_since.keys()
		ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		check(faction.recruitment_arbitration.reserved_commander_id == ids[0], "equal wait ages use stable commander ID")
		var older := leader(world, &"spear").definition.definition_id
		faction.recruitment_arbitration.clear_reservation()
		faction.recruitment_arbitration.waiting_since[older] = world.current_tick - 10
		RecruitmentArbitrationSystem.refresh(world, 1)
		check(faction.recruitment_arbitration.reserved_commander_id == older, "older waiter precedes lexicographic ID")
		faction.supply = 17
		RecruitmentArbitrationSystem.propose_commands(world, 1)
		var queue := world.command_queue.snapshot()
		check(queue.size() == 1 and world.unit_cards[queue[0].unit_card_id].commander_definition_id == older, "oldest unaffordable soldier actually gets next income")
		world.advance_tick()
		traces.append(str([faction.supply, faction.population, faction.recruitment_arbitration.last_served_commander_id, leader(world, &"spear").growth_unlocked_slots]))
	check(traces[0] == traces[1], "dictionary insertion order does not change purchase outcome")

func test_support_batch() -> void:
	for support_first in [false, true]:
		var world := prepare()
		isolate(world, [&"guardian"])
		var faction := world.factions[1] as FactionState
		var support := AreaSupportCommand.new(world.allocate_command_id(), 1, GameCommand.IssuerKind.PLAYER, world.current_tick, SupportOrderCommand.SupportKind.AIR_RECON, world.battle_definition.player_headquarters_position)
		faction.supply = 12 + 2 + world.get_support_cost(support.support_kind)
		if support_first: check(world.submit_command(support).is_accepted(), "support accepted before automatic growth")
		RecruitmentArbitrationSystem.propose_commands(world, 1)
		if not support_first: check(world.submit_command(support).is_accepted(), "support respects already queued growth commitment")
		check(RecruitmentArbitrationSystem.pending_for(world, 1).size() == 1, "mixed queue contains exactly one growth purchase")
		world.advance_tick()
		check(faction.population == 61 and faction.recruitment_spend == 2 and faction.support_spend == 20, "actual mixed batch fulfills both purchases once")
		check(world.area_support_system.effects.size() == 1, "support creates real effect")

func test_private_value_snapshot() -> void:
	var world := prepare()
	isolate(world, [&"spear"])
	world.factions[1].supply = 15
	RecruitmentArbitrationSystem.refresh(world, 1)
	var frozen := world.create_logistics_snapshot(1, true)
	var state := frozen.get_faction(1).recruitment_arbitration
	var id := leader(world).definition.definition_id
	var before := var_to_str([state.selected_slots, state.waiting_since, state.reasons, state.reserved_commander_id, state.reserved_slot, state.reserved_amount])
	world.factions[1].recruitment_arbitration.selected_slots.clear()
	world.factions[1].recruitment_arbitration.waiting_since.clear()
	world.factions[1].recruitment_arbitration.reasons.clear()
	world.factions[1].recruitment_arbitration.clear_reservation()
	check(before == var_to_str([state.selected_slots, state.waiting_since, state.reasons, state.reserved_commander_id, state.reserved_slot, state.reserved_amount]), "all arbitration dictionaries and reservation fields are value copies")
	var proposal_before := LegionRecruitmentPolicy.propose(frozen, world.battle_definition, [])
	for unit: UnitState in world.units.values():
		if unit.faction_id == 2:
			unit.health = 1
			unit.position = Vector2(16000, 12000)
	world.factions[2].supply = 999
	var proposal_after := LegionRecruitmentPolicy.propose(frozen, world.battle_definition, [])
	check(proposal_before == null and proposal_after == null and state.reserved_commander_id == id, "unseen authority pollution cannot change a policy using fixed legal knowledge")

func test_reserved_owner_two_queued() -> void:
	var world := prepare()
	isolate(world, [&"spear"])
	var faction := world.factions[1] as FactionState
	var id := leader(world).definition.definition_id
	faction.recruitment_rates[id] = 2
	faction.supply = 15
	RecruitmentArbitrationSystem.refresh(world, 1)
	check(faction.recruitment_arbitration.reserved_slot == 12, "two-round owner starts saving first slot")
	faction.supply = 50
	RecruitmentArbitrationSystem.propose_commands(world, 1)
	check(RecruitmentArbitrationSystem.pending_for(world, 1).size() == 2, "reserved owner can enqueue second-round soldier")
	check(faction.recruitment_arbitration.reserved_amount == 0, "two queued slots never count original reservation twice")

func _initialize() -> void:
	test_selected_waiting_slot()
	test_refusal_does_not_hold_funds()
	test_real_tick_batch()
	test_pending_policy_changes()
	test_queued_window_reason()
	test_order_and_wait_age()
	test_support_batch()
	test_private_value_snapshot()
	test_reserved_owner_two_queued()
	var output := "res://artifacts/legion36/boundary.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"evidence": "SIMULATED", "checks": checks, "failures": failures, "scope": "selected identity, refusal, accepted intents and real advance_tick queue"}))
	print("LEGION36_BOUNDARY checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
