extends SceneTree

func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	for commander: CommanderState in world.commanders.values():
		world.submit_command(CommanderOrderCommand.new(world.allocate_command_id(), commander.faction_id, 0, commander.definition.definition_id, CommanderOrderCommand.OrderKind.SET_POSTURE, Vector2.ZERO, &"", CommanderState.Posture.HOLD))
	var failures: Array[String] = []
	# An explicit income fixture isolates population/cost limits from territory AI.
	# All 416 added soldiers still go through the actual automatic command pipeline.
	for tick in range(5000):
		if tick % 200 == 0:
			for faction: FactionState in world.factions.values(): faction.supply = faction.supply_capacity
		world.advance_tick()
		for faction: FactionState in world.factions.values():
			if faction.population > 256 or faction.supply < 0: failures.append("population or currency violation")
		if world.factions[1].population == 256 and world.factions[2].population == 256: break
	if world.factions[1].population != 256 or world.factions[2].population != 256: failures.append("both armies must reach 256")
	for card: UnitCardState in world.unit_cards.values():
		var strength := UnitCardSnapshot.new(card, world.units).current_strength
		if strength != 16: failures.append("full card " + String(card.definition.definition_id))
		var command := RecruitUnitCardCommand.new(world.allocate_command_id(), card.faction_id, GameCommand.IssuerKind.PLAYER, world.current_tick, card.definition.definition_id, 1)
		if world.submit_command(command).is_accepted(): failures.append("over-cap recruitment accepted")
	print("GROWTH_CAPACITY blue=%d red=%d entities=%d tick=%d failures=%s" % [world.factions[1].population, world.factions[2].population, world.units.size(), world.current_tick, failures])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
