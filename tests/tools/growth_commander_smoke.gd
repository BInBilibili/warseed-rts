extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	check(world.commanders.size() == 8, "four commanders on both sides")
	var agent := GrowthCommanderAgent.new()
	check(agent.propose(world.create_true_state_snapshot(), world.battle_definition).is_empty(), "true state rejected")
	for faction in [1, 2]:
		var view := world.create_commander_task_snapshot(faction)
		check(view.commanders.size() == 4, "own commander visibility")
		check(agent.propose(view, world.battle_definition).size() == 4, "four opening objectives proposed")
		for candidate in agent.propose(view, world.battle_definition):
			candidate.issuer_id = 3 - faction
			check(not world.submit_command(candidate).is_accepted(), "cross-faction commander rejected")
	var auto := agent.propose(world.create_commander_task_snapshot(1), world.battle_definition)[0]
	check(world.submit_command(auto).is_accepted(), "autonomous objective queued")
	var commander_id := auto.commander_id
	auto.target_region_id = &"tampered"
	var hold := CommanderOrderCommand.new(world.allocate_command_id(), 1, 0, commander_id, CommanderOrderCommand.OrderKind.SET_POSTURE, Vector2.ZERO, &"", CommanderState.Posture.HOLD)
	check(world.submit_command(hold).is_accepted(), "same tick player hold accepted")
	world.advance_tick()
	check((world.commanders[commander_id] as CommanderState).posture == CommanderState.Posture.HOLD and (world.commanders[commander_id] as CommanderState).target_region_id.is_empty(), "player command supersedes automatic objective")
	for tick in range(240): world.advance_tick()
	for commander: CommanderState in world.commanders.values():
		if commander.definition.definition_id == commander_id: continue
		check(not commander.target_region_id.is_empty(), "commander executes objective " + String(commander.definition.definition_id))
	# A destroyed card rebuilds at its own headquarters only after its delay,
	# pays the same per-member price, and receives a real commander task.
	world.command_queue.drain()
	var card := world.unit_cards[&"final_group_2_armored_spearhead"] as UnitCardState
	for id in card.member_entity_ids:
		world.units[id].enabled = false
	card.last_damage_tick = world.current_tick
	card.last_active_strength = 0
	card.organization = 0.0
	world._refresh_battle_population()
	var faction := world.factions[1] as FactionState
	faction.supply = 200
	faction.recruitment_ready_tick = 0
	var recruit := RecruitUnitCardCommand.new(world.allocate_command_id(), 1, GameCommand.IssuerKind.PLAYER, world.current_tick, card.definition.definition_id, 2)
	check(not world.submit_command(recruit).is_accepted(), "reconstruction delay enforced")
	card.last_damage_tick -= 201
	world.formations.erase(card.formation_id)
	check(world.submit_command(recruit).is_accepted(), "reconstruction accepted after delay")
	world.advance_tick()
	var revived := UnitCardSnapshot.new(card, world.units)
	check(revived.current_strength == 2 and revived.center_position.distance_to(world.battle_definition.player_headquarters_position) < 700.0, "two real members reconstructed at HQ")
	check(faction.supply == 194, "reconstruction pays armor member cost")
	check(card.assigned_task_id != 0 and world.tasks[card.assigned_task_id].lifecycle == TaskState.Lifecycle.EXECUTING, "reconstructed card assigned active task")
	# Captures/losses and damage are projected from copied public/own state.
	var region := world.strategic_regions[&"blue_mid_high"] as StrategicRegionState
	region.previous_controller_faction_id = 1
	region.controller_faction_id = 2
	region.controller_changed_tick = world.current_tick
	var legal := world.create_faction_snapshot(1)
	var situation := BattlefieldSituationProjector.new().project(legal, 1, world.battle_definition.battlefield_bounds)
	var alerts := CommandSituationProjector.new().project(legal, situation, 1)
	var loss_found := false
	for alert in alerts.exceptions:
		if alert.kind == CommandExceptionSnapshot.Kind.SUPPLY_LOST and alert.region_id == region.region_id: loss_found = true
		check(alert.kind != CommandExceptionSnapshot.Kind.REINFORCEMENT_REQUEST, "routine replacement requests suppressed")
	check(loss_found, "supply loss has actionable alert")
	region.previous_controller_faction_id = 0
	region.controller_faction_id = 1
	region.contested = true
	var threatened_view := world.create_faction_snapshot(1)
	var threatened_situation := BattlefieldSituationProjector.new().project(threatened_view, 1, world.battle_definition.battlefield_bounds)
	var threat_found := false
	for alert in CommandSituationProjector.new().project(threatened_view, threatened_situation, 1).exceptions:
		if alert.kind == CommandExceptionSnapshot.Kind.SUPPLY_THREAT and alert.region_id == region.region_id:
			threat_found = true
			check(alert.action_ids[0] == CommandExceptionSnapshot.Action.FOCUS and not alert.action_ids.has(CommandExceptionSnapshot.Action.REPLAN), "friendly supply warning focuses instead of invalid offensive plan")
	check(threat_found, "contested holding produces immediate warning")
	check(alerts.exceptions.size() <= 6, "decision summary capped")
	region.controller_faction_id = 1
	check(legal.get_strategic_region(region.region_id).controller_faction_id == 2, "old ownership snapshot unchanged")
	for failure in failures: push_error(failure)
	print("GROWTH_COMMANDER commanders=%d ticks=%d failures=%s" % [world.commanders.size(), world.current_tick, failures])
	quit(0 if failures.is_empty() else 1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
