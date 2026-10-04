extends SimulationWorld

func _advance_strategic_regions() -> void:
	if not is_card_battle():
		return
	var region_ids := strategic_regions.keys()
	region_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for region_id in region_ids:
		var region := strategic_regions[region_id] as StrategicRegionState
		if not region.capturable:
			continue
		var occupying_factions: Dictionary = {}
		for unit_variant in units.values():
			var unit := unit_variant as UnitState
			var card := unit_cards.get(unit.unit_card_id) as UnitCardState
			if card != null and card.uses_tactical_organization() and card.organization <= 0.0 and region.controller_faction_id != unit.faction_id:
				continue
			if unit.enabled and not unit.legion_returning and unit.tactical_role != UnitState.TacticalRole.SCOUT and unit.definition_id != &"supply_truck" and unit.position.distance_to(region.position) <= region.radius:
				occupying_factions[unit.faction_id] = int(occupying_factions.get(unit.faction_id, 0)) + 1
		var previous_controller := region.controller_faction_id
		var previous_contested := region.contested
		var previous_capture_faction := region.capture_faction_id
		region.contested = occupying_factions.size() > 1
		if occupying_factions.size() == 1:
			var occupying_faction_id := int(occupying_factions.keys()[0])
			if occupying_faction_id == region.controller_faction_id:
				region.capture_faction_id = occupying_faction_id
				region.capture_progress_ticks = region.capture_required_ticks
			else:
				if region.capture_faction_id != occupying_faction_id:
					region.capture_faction_id = occupying_faction_id
					region.capture_progress_ticks = 0
				region.capture_progress_ticks = mini(region.capture_required_ticks, region.capture_progress_ticks + 1)
				if previous_capture_faction != occupying_faction_id:
					events.append(SimulationEvent.new(
						current_tick, SimulationEvent.Kind.REGION_CAPTURE_STARTED, occupying_faction_id,
						"region=%s;faction=%d;progress=%d;required=%d" % [region.region_id, occupying_faction_id, region.capture_progress_ticks, region.capture_required_ticks]
					))
				if region.capture_progress_ticks >= region.capture_required_ticks:
					region.controller_faction_id = occupying_faction_id
		elif occupying_factions.is_empty():
			if region.controller_faction_id != 0:
				if region.capture_faction_id != 0 and region.capture_faction_id != region.controller_faction_id and region.capture_progress_ticks > 0:
					events.append(SimulationEvent.new(
						current_tick, SimulationEvent.Kind.REGION_CAPTURE_INTERRUPTED, region.capture_faction_id,
						"region=%s;faction=%d" % [region.region_id, region.capture_faction_id]
					))
				region.capture_faction_id = region.controller_faction_id
				region.capture_progress_ticks = region.capture_required_ticks
			elif region.capture_progress_ticks > 0:
				region.capture_progress_ticks = maxi(0, region.capture_progress_ticks - REGION_CAPTURE_DECAY_PER_TICK)
				if region.capture_progress_ticks == 0:
					var interrupted_faction := region.capture_faction_id
					region.capture_faction_id = 0
					events.append(SimulationEvent.new(
						current_tick, SimulationEvent.Kind.REGION_CAPTURE_INTERRUPTED, interrupted_faction,
						"region=%s;faction=%d" % [region.region_id, interrupted_faction]
					))
		if region.controller_faction_id != previous_controller or region.contested != previous_contested:
			if region.controller_faction_id != previous_controller:
				region.previous_controller_faction_id = previous_controller
				region.controller_changed_tick = current_tick
			events.append(SimulationEvent.new(
				current_tick,
				SimulationEvent.Kind.REGION_CONTROL_CHANGED,
				0,
				"region=%s;controller=%d;contested=%s;capture_faction=%d;progress=%d;required=%d" % [
					region.region_id, region.controller_faction_id, region.contested,
					region.capture_faction_id, region.capture_progress_ticks, region.capture_required_ticks,
				]
			))
		var settlement_interval := battle_definition.region_settlement_interval_ticks if battle_definition != null else GREY_RIDGE_REGION_INTERVAL_TICKS
		if current_tick == 0 or current_tick % settlement_interval != 0:
			continue
		if region.controller_faction_id == 0 or region.contested:
			continue
		var faction := factions.get(region.controller_faction_id) as FactionState
		if faction == null:
			continue
		var previous_supply := faction.supply
		faction.supply = mini(faction.supply_capacity, faction.supply + region.supply_per_settlement)
		var credited_supply := faction.supply - previous_supply
		region.last_settlement_tick = current_tick
		events.append(SimulationEvent.new(
			current_tick,
			SimulationEvent.Kind.REGION_SETTLED,
			region.controller_faction_id,
			"region=%s;credited=%d;supply=%d" % [region.region_id, credited_supply, faction.supply]
		))
		if credited_supply > 0:
			events.append(SimulationEvent.new(
				current_tick,
				SimulationEvent.Kind.SUPPLY_CHANGED,
				region.controller_faction_id,
				"supply=%d;delta=%d;source=%s" % [faction.supply, credited_supply, region.region_id]
			))
