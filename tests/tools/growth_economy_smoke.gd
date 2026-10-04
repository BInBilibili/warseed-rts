extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	check(world.units.size() == 96, "48 versus 48 opening")
	check(world.battle_definition.growth_mode and world.battle_definition.validate(SimulationWorld.UNIT_CATALOG).is_valid(), "growth data validates")
	var cards: Array[UnitCardState] = []
	for card: UnitCardState in world.unit_cards.values():
		if card.faction_id == 1:
			cards.append(card)
			var red := world.unit_cards[StringName("red_%s" % card.definition.definition_id)] as UnitCardState
			check(card.member_entity_ids.size() == red.member_entity_ids.size(), "paired opening card strength")
			for index in range(card.member_entity_ids.size()):
				var blue_unit := world.units[card.member_entity_ids[index]] as UnitState
				var red_unit := world.units[red.member_entity_ids[index]] as UnitState
				check(world.battle_definition.map_definition.mirror_point(blue_unit.position).distance_to(red_unit.position) < 0.01, "mirrored opening position")
	var blue_faction := world.factions[1] as FactionState
	var initial_snapshot := world.create_snapshot()
	var card := cards[0]
	var priority := SupplyPriorityCommand.new(world.allocate_command_id(), 1, 0, card.commander_definition_id)
	check(world.submit_command(priority).is_accepted(), "priority accepted")
	priority.commander_id = &"invalid_after_enqueue"
	world.advance_tick()
	check(blue_faction.priority_commander_id == card.commander_definition_id, "priority queued as value")
	check(initial_snapshot.get_faction(1).priority_commander_id == &"di_tian", "old snapshot unchanged")
	check(world.create_faction_snapshot(2).get_faction(1).priority_commander_id.is_empty(), "enemy cannot read priority")
	check(not world.submit_command(SupplyPriorityCommand.new(world.allocate_command_id(), 1, world.current_tick, &"red_bai_jiuyang")).is_accepted(), "cannot prioritize hostile group")
	world.command_queue.drain()
	blue_faction.recruitment_ready_tick = 0
	blue_faction.supply = 100
	var count_before := card.member_entity_ids.size()
	var recruit := RecruitUnitCardCommand.new(world.allocate_command_id(), 1, GameCommand.IssuerKind.PLAYER, world.current_tick, card.definition.definition_id, 2)
	check(world.submit_command(recruit).is_accepted(), "recruit accepted at safe HQ")
	check(not world.submit_command(recruit.duplicate_value()).is_accepted(), "same faction double recruitment rejected")
	recruit.member_count = 100
	world.advance_tick()
	check(card.member_entity_ids.size() == count_before + 2, "exact immutable recruitment count applied")
	check(blue_faction.supply == 100 - 2 * card.definition.recruitment_cost, "per-member cost charged")
	check(not world.submit_command(RecruitUnitCardCommand.new(world.allocate_command_id(), 1, 0, world.current_tick, card.definition.definition_id, 2)).is_accepted(), "recruitment cooldown enforced")
	for candidate in cards:
		blue_faction.recruitment_ready_tick = 0
		blue_faction.supply = candidate.definition.recruitment_cost - 1
		check(not world.submit_command(RecruitUnitCardCommand.new(world.allocate_command_id(), 1, 0, world.current_tick, candidate.definition.definition_id, 1)).is_accepted(), "per-role insufficient supply rejected")
	blue_faction.supply = 100
	check(not world.submit_command(RecruitUnitCardCommand.new(world.allocate_command_id(), 1, 0, world.current_tick, card.definition.definition_id, -1)).is_accepted(), "negative count rejected")
	check(not world.submit_command(RecruitUnitCardCommand.new(world.allocate_command_id(), 1, 0, world.current_tick, card.definition.definition_id, 3)).is_accepted(), "oversized batch rejected")
	# Exercise real autonomous growth; initial queued orders and movement stay active.
	var opening_population := blue_faction.population
	for tick in range(600):
		world.advance_tick()
	check(blue_faction.population > opening_population, "friendly automatic growth occurs")
	check((world.factions[2] as FactionState).population > 48, "hostile automatic growth occurs")
	check(blue_faction.supply >= 0 and blue_faction.population <= 256, "growth respects currency and population")
	var history := ArmyRosterStore.build_battle_record(world.create_snapshot(), {}, &"final_decision")
	var restarted := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION, history)
	check(restarted.units.size() == 96, "record does not change new match opening")
	for failure in failures:
		push_error(failure)
	print("GROWTH_ECONOMY opening=48 blue=%d red=%d ticks=%d failures=%d" % [blue_faction.population, (world.factions[2] as FactionState).population, world.current_tick, failures.size()])
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
