extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	if world.battle_definition == null or world.units.size() != 96:
		push_error("growth battle must instantiate 48 units per faction with capacity 256")
		quit(1)
		return
	var map := world.battle_definition.map_definition
	for card: UnitCardState in world.unit_cards.values():
		if card.faction_id != 1: continue
		var red_card := world.unit_cards[StringName("red_%s" % card.definition.definition_id)] as UnitCardState
		for i in range(card.member_entity_ids.size()):
			var blue := world.units[card.member_entity_ids[i]] as UnitState
			var red := world.units[red_card.member_entity_ids[i]] as UnitState
			if blue.definition_id != red.definition_id or map.mirror_point(blue.position).distance_to(red.position) > 0.01 or blue.health != red.health:
				failures.append("initial mirrored unit mismatch %s/%d" % [card.definition.definition_id, i])
			if not world.logic_grid.is_world_position_walkable(blue.position) or not world.logic_grid.is_world_position_walkable(red.position):
				failures.append("initial unit blocked %s/%d" % [card.definition.definition_id, i])
	for id in world.commanders:
		if world.commanders[id].faction_id != 1: continue
		var region := world.strategic_regions[&"blue_mid_outer"] as StrategicRegionState
		var command := CommanderOrderCommand.new(world.allocate_command_id(), 1, 0, id,
			CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE, region.position, region.region_id)
		if not world.submit_command(command).is_accepted():
			failures.append("commander order rejected: %s" % id)
	for i in range(310):
		world.advance_tick()
	var red_income := false
	var blue_income := false
	for event in world.events:
		if event.kind == SimulationEvent.Kind.SUPPLY_CHANGED and "source=base_income" in event.detail:
			red_income = red_income or event.entity_id == 2
			blue_income = blue_income or event.entity_id == 1
	if not red_income or not blue_income:
		failures.append("both factions must receive base income")
	for failure in failures:
		push_error(failure)
	print("FINAL_DECISION_BATTLE initial=96 capacity=512 ticks=%d units=%d failures=%d" % [world.current_tick, world.units.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
