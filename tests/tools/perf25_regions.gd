extends SceneTree

func _initialize() -> void:
	var original := preload("res://tests/tools/perf25_reference_regions.gd").new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var current := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var failures: Array[String] = []
	RuntimeMeasurement.reset()
	RuntimeMeasurement.enabled = true
	for phase in range(160):
		for world: SimulationWorld in [original,current]:
			world.current_tick = 160 + phase
			world.events.clear()
			var regions := world.strategic_regions.values()
			var index := 0
			for unit: UnitState in world.units.values():
				var region := regions[(index / 4 + phase / 20) % regions.size()] as StrategicRegionState
				# Include exact radius, inside/outside, hero/cardless, dead and returning.
				unit.position = region.position + Vector2([0.0,region.radius,region.radius-0.01,region.radius+0.01][index%4],0)
				unit.enabled = (index + phase / 10) % 13 != 0
				unit.legion_returning = (index + phase / 10) % 17 == 0
				var card := world.unit_cards.get(unit.unit_card_id) as UnitCardState
				if card != null: card.organization = 0.0 if (index + phase / 10) % 3 == 0 else 50.0
				index += 1
			var started := RuntimeMeasurement.begin()
			world._advance_strategic_regions()
			RuntimeMeasurement.end(&"original_usec" if world == original else &"current_usec",started)
		for id in original.strategic_regions:
			var a := original.strategic_regions[id] as StrategicRegionState
			var b := current.strategic_regions[id] as StrategicRegionState
			for property in ["controller_faction_id","contested","capture_faction_id","capture_progress_ticks","previous_controller_faction_id","controller_changed_tick","last_settlement_tick"]:
				if a.get(property) != b.get(property): failures.append("phase %d region %s property %s" % [phase,id,property])
		for faction in [1,2]:
			if original.factions[faction].supply != current.factions[faction].supply: failures.append("income mismatch")
		var a_events: Array[String] = []
		var b_events: Array[String] = []
		for event in original.events: a_events.append("%d:%d:%d:%s" % [event.tick,event.kind,event.entity_id,event.detail])
		for event in current.events: b_events.append("%d:%d:%d:%s" % [event.tick,event.kind,event.entity_id,event.detail])
		if a_events != b_events: failures.append("ordered event mismatch phase %d" % phase)
	var report := {"evidence":"SIMULATED","phases":160,"failures":failures,"measurements":RuntimeMeasurement.summary()}
	FileAccess.open("res://artifacts/perf25-regions01.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PERF25_REGIONS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
