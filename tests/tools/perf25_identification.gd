extends SceneTree

func _initialize() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var reference = preload("res://tests/tools/perf25_reference_identification.gd").new()
	var actual := TacticalAbilitySystem.new()
	var old_knowledge := FactionKnowledge.new(1,world.logic_grid.grid_size)
	var new_knowledge := FactionKnowledge.new(1,world.logic_grid.grid_size)
	var failures: Array[String] = []
	var old_times: Array[int] = []
	var new_times: Array[int] = []
	var scout: UnitCardState
	for card: UnitCardState in world.unit_cards.values():
		if card.faction_id == 1 and card.definition.tactical_ability.kind == TacticalAbilityDefinition.Kind.OBSERVE:
			scout = card
			break
	scout.tactical_command = TacticalAbilityCommand.new(1,1,GameCommand.IssuerKind.PLAYER,0,scout.definition.definition_id)
	scout.tactical_complete_tick = 0
	scout.tactical_until_tick = 100
	var center := UnitCardSnapshot.new(scout,world.units).center_position
	for i in range(600):
		var unit := UnitState.new(100000+i,center+Vector2(i%25*15,i/25*15),0,2)
		old_knowledge.hostile_contacts[unit.entity_id] = KnowledgeContact.from_unit(unit,0)
		new_knowledge.hostile_contacts[unit.entity_id] = KnowledgeContact.from_unit(unit,0)
	for tick in range(65):
		world.current_tick = tick
		old_knowledge.visible_hostile_unit_ids.clear()
		new_knowledge.visible_hostile_unit_ids.clear()
		for i in range(600):
			if tick >= 25 and i%3 == 0: continue
			old_knowledge.visible_hostile_unit_ids.append(100000+i)
			new_knowledge.visible_hostile_unit_ids.append(100000+i)
		if tick == 40: scout.tactical_until_tick = 40
		var event_start := world.events.size()
		var start := Time.get_ticks_usec()
		reference.update_identification(world,old_knowledge)
		var old_elapsed := Time.get_ticks_usec()-start
		var expected_events: Array[String] = []
		for index in range(event_start,world.events.size()): expected_events.append(world.events[index].detail)
		world.events.resize(event_start)
		start = Time.get_ticks_usec()
		actual.update_identification(world,new_knowledge)
		var new_elapsed := Time.get_ticks_usec()-start
		var actual_events: Array[String] = []
		for index in range(event_start,world.events.size()): actual_events.append(world.events[index].detail)
		if expected_events != actual_events or old_knowledge.identification_until_by_entity != new_knowledge.identification_until_by_entity or reference.observation_started != actual.observation_started or reference.passive_observation_started != actual.passive_observation_started:
			failures.append("identification or event order changed at %d" % tick)
		if tick >= 10:
			old_times.append(old_elapsed)
			new_times.append(new_elapsed)
	var report := {"evidence":"SIMULATED","ticks":65,"failures":failures,"reference_usec":stats(old_times),"actual_usec":stats(new_times)}
	FileAccess.open("res://artifacts/perf25-identification01.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF25_IDENTIFICATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func stats(values: Array[int]) -> Dictionary:
	values.sort()
	return {"p50":values[int((values.size()-1)*0.5)],"p95":values[int((values.size()-1)*0.95)],"max":values[-1]}
