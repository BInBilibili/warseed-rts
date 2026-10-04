extends SceneTree

func _initialize() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var expected: Dictionary = {}
	for faction in [1,2]:
		var original := world.faction_knowledge[faction] as FactionKnowledge
		var copy := FactionKnowledge.new(faction,world.logic_grid.grid_size)
		copy.cells = original.cells.duplicate()
		copy._visible_indices = original._visible_indices.duplicate()
		expected[faction] = copy
	var failures: Array[String] = []
	var unit := world.units.values()[0] as UnitState
	var saved := world.create_faction_snapshot(1)
	var saved_cells := saved.knowledge.cells.duplicate()
	RuntimeMeasurement.reset()
	RuntimeMeasurement.enabled = true
	for phase in range(18):
		world.current_tick = phase
		match phase:
			1,2: effect(world,phase,SupportOrderCommand.SupportKind.FIELD_HOSPITAL,0,100)
			3: effect(world,1,SupportOrderCommand.SupportKind.AIR_RECON,5,9)
			4: effect(world,2,SupportOrderCommand.SupportKind.AIR_RECON,6,12)
			7: unit.position += Vector2(64,32)
			8: unit.sight_range *= 1.5
			10: unit.enabled = false
			11: world.air_recon_until_by_faction[1] = {&"jungle_upper_major":13}
			12: world.buildings[SimulationWorld.PLAYER_COMMAND_CENTER_ID].enabled = false
			13: world.area_support_system.effects.clear()
			14: unit.enabled = true
			15: world.buildings[SimulationWorld.PLAYER_COMMAND_CENTER_ID].enabled = true
			16: effect(world,1,SupportOrderCommand.SupportKind.MISSILE_BARRAGE,16,100)
		world._update_faction_knowledge()
		for faction in [1,2]:
			var reference := expected[faction] as FactionKnowledge
			reference.begin_update()
			# Previous public implementation: reveal every actual sensor in order.
			for sensor: UnitState in world.units.values():
				if not sensor.enabled or sensor.faction_id != faction: continue
				var radius := sensor.sight_range
				var card := world.unit_cards.get(sensor.unit_card_id) as UnitCardState
				if card != null: radius = maxf(radius,world.tactical_ability_system.observation_range(card,world.current_tick))
				reference.reveal(world.logic_grid.world_to_cell(sensor.position),ceili(radius/LogicGrid.CELL_SIZE))
			for building: BuildingState in world.buildings.values():
				if not building.enabled or building.faction_id != faction: continue
				var definition := world.BUILDING_CATALOG.get_building(building.definition_id)
				reference.reveal(world.logic_grid.world_to_cell(building.position),ceili((definition.sight_range if definition != null else 256.0)/LogicGrid.CELL_SIZE))
			var regions: Dictionary = world.air_recon_until_by_faction.get(faction,{})
			for region_id in regions:
				if regions[region_id] > phase:
					var region := world.strategic_regions[region_id] as StrategicRegionState
					reference.reveal(world.logic_grid.world_to_cell(region.position),ceili(region.radius/LogicGrid.CELL_SIZE))
			world.area_support_system.reveal(world,reference)
			var actual := world.faction_knowledge[faction] as FactionKnowledge
			if actual.cells != reference.cells: failures.append("sensor union/history mismatch %d/%d" % [phase,faction])
			var visible := PackedInt32Array()
			var ids := world.units.keys()
			ids.sort()
			for id in ids:
				var target := world.units[id] as UnitState
				if target.faction_id != faction and reference.is_visible(world.logic_grid.world_to_cell(target.position)): visible.append(id)
			if actual.visible_hostile_unit_ids != visible: failures.append("contact visibility mismatch %d/%d" % [phase,faction])
		if saved.knowledge.cells != saved_cells: failures.append("old faction snapshot mutated")
	var report := {"evidence":"SIMULATED","phases":18,"failures":failures,"cache":RuntimeMeasurement.summary().counters}
	RuntimeMeasurement.enabled = false
	FileAccess.open("res://artifacts/perf25-fog-contract01.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF25_FOG_CONTRACT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func effect(world: SimulationWorld, faction: int, kind: SupportOrderCommand.SupportKind, active: int, expires: int) -> void:
	var area := AreaSupportEffect.new()
	area.faction_id = faction
	area.support_kind = kind
	area.position = Vector2(16384,12288) + Vector2(faction*800,0)
	area.radius = 1600
	area.active_tick = active
	area.expires_tick = expires
	world.area_support_system.effects.append(area)
