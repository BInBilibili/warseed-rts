extends SceneTree
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var battle := world.battle_definition
	check(world.commanders.size() == 10 and world.units.size() == 120, "five legions / 60 starting per side")
	check(battle.population_capacity == 300, "300 cap")
	check(battle.support_for_kind(SupportOrderCommand.SupportKind.MISSILE_BARRAGE).activation_delay_ticks == 30, "barrage 3s")
	var frozen := world.grey_ridge_army_plan.duplicate_plan()
	var invalid := frozen.duplicate_plan()
	invalid.legions[0].profile_id = invalid.legions[1].profile_id
	check(not world.get_grey_ridge_army_plan_errors(invalid).is_empty(), "duplicate profile rejected")
	invalid = frozen.duplicate_plan()
	invalid.legions[0].role_strengths[0] += 1
	check(not world.get_grey_ridge_army_plan_errors(invalid).is_empty(), "61 rejected")
	check(frozen.legions[0].role_strengths[0] == 12, "loadout value copy")
	for card: UnitCardState in world.unit_cards.values():
		var commander := world.commanders[card.commander_definition_id] as CommanderState
		var profile := commander.definition.profile
		for id in card.member_entity_ids:
			var unit := world.units[id] as UnitState
			var base := card.definition.combat_override if card.definition.combat_override != null else SimulationWorld.UNIT_CATALOG.get_unit(unit.definition_id).combat
			check(is_equal_approx(unit.max_health, base.max_health * profile.health_multiplier), "HP buff " + str(id))
			unit.health -= 7
			var health := unit.health
			world._bind_unit_card_members(card)
			check(is_equal_approx(unit.health, health), "no stacking/healing " + str(id))
			if unit.definition_id == &"scout_vehicle": check(is_equal_approx(unit.base_move_speed, 200 * profile.speed_multiplier), "scout speed")
	var view := world.create_snapshot()
	var markers := MinimapMarkerProjector.new().project(view, [])
	check(markers.size() == 5, "minimap 5 legal legion markers")
	for marker in markers: check(marker.kind == &"legion", "no per-unit markers")
	var card := world.unit_cards[&"final_group_1_falcon_recon_group"] as UnitCardState
	var takeover := UnitCardControlCommand.new(world.allocate_command_id(), 1, world.current_tick, card.definition.definition_id, UnitCardControlCommand.Action.TAKEOVER)
	check(world.submit_command(takeover).is_accepted(), "takeover accepted")
	world.advance_tick()
	check(card.temporary_micro and not card.persistent_manual, "takeover is timed")
	for i in range(95): world.advance_tick()
	check(card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED, "quiet timeout not early")
	for i in range(15): world.advance_tick()
	check(card.control_state in [UnitCardState.ControlState.AGENT_ASSIGNED, UnitCardState.ControlState.RETURNING], "quiet auto handoff")
	var custom := frozen.duplicate_plan()
	custom.legions[0].role_strengths = PackedInt32Array([0, 60, 0, 0])
	custom.legions[0].profile_id = frozen.legions[4].profile_id
	custom.legions[4].profile_id = frozen.legions[0].profile_id
	var alternate := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION, {}, &"", custom)
	check(alternate.units.size() == 120, "zero roles still 12 starting legion")
	check(alternate.unit_cards[&"final_group_1_falcon_recon_group"].definition.authorized_strength == 0, "zero recon role applied")
	check(alternate.unit_cards[&"final_group_1_ironwall_assault_group"].definition.authorized_strength == 60, "60 assault allowed")
	check(alternate.commanders[&"red_bai_jiuyang"].definition.profile.profile_id == frozen.legions[0].profile_id, "enemy does not copy user loadout")
	# Exact fog union compared with an independent cell-centre oracle.
	var knowledge := FactionKnowledge.new(1, Vector2i(53, 47))
	var circles := [Vector3i(0, 0, 5), Vector3i(10, 10, 8), Vector3i(15, 14, 10), Vector3i(52, 46, 7)]
	knowledge.begin_update()
	for c in circles: knowledge.reveal(Vector2i(c.x, c.y), c.z)
	for y in range(47):
		for x in range(53):
			var expected := false
			for c in circles: expected = expected or Vector2i(x - c.x, y - c.y).length_squared() <= c.z * c.z
			check(knowledge.is_visible(Vector2i(x, y)) == expected, "fog exact union")
	for commander: CommanderState in alternate.commanders.values(): commander.posture = CommanderState.Posture.HOLD
	for i in range(2500):
		if i % 100 == 0:
			for faction: FactionState in alternate.factions.values(): faction.supply = 300
		alternate.advance_tick()
		for faction: FactionState in alternate.factions.values():
			var count := 0
			for recruited in faction.recruited_by_commander.values(): count += recruited
			check(count <= 5 and faction.population <= 300, "recruit cap")
		if alternate.factions[1].population == 300 and alternate.factions[2].population == 300: break
	check(alternate.factions[1].population == 300 and alternate.factions[2].population == 300, "both armies reach 300")
	var record := ArmyRosterStore.build_battle_record(alternate.create_snapshot(), {}, &"final_decision")
	check(ArmyRosterMigration.normalize(record, false).is_success(), "zero role composition remains v4 compatible")
	var frozen_fog := (alternate.faction_knowledge[1] as FactionKnowledge).cells.duplicate()
	var profile_times: Array = []
	for clear in [true, false]:
		var started := Time.get_ticks_usec()
		for repeat in range(30):
			if clear: alternate._vision_sources.clear()
			alternate._update_faction_knowledge()
		profile_times.append((Time.get_ticks_usec() - started) / 1000.0)
	check(frozen_fog == (alternate.faction_knowledge[1] as FactionKnowledge).cells, "cached fog exact")
	print("LEGION22_VISION600 ", profile_times)
	print("LEGION22_RULES ", JSON.stringify({"failures":failures,"capacity_tick":alternate.current_tick,"blue":alternate.factions[1].population,"red":alternate.factions[2].population}))
	quit(0 if failures.is_empty() else 1)
