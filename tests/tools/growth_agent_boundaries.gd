extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var commander := world.commanders[&"di_tian"] as CommanderState
	var target := world.strategic_regions[&"red_mid_outer"] as StrategicRegionState
	var route := PackedVector2Array([world.strategic_regions[&"blue_mid_outer"].position])
	var order := CommanderOrderCommand.new(world.allocate_command_id(), 1, 0, &"di_tian", CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE, target.position, target.region_id)
	order.route_points = route
	check(world.submit_command(order).is_accepted(), "explicit objective accepted")
	world.advance_tick()
	world.command_queue.drain()
	var position: Vector2 = world.strategic_regions[&"blue_mid_outer"].position
	place_group(world, commander, position, 20.0, false)
	world.current_tick = 90
	world._update_faction_knowledge()
	var agent := GrowthCommanderAgent.new()
	var recovery := command_for(agent.propose(world.create_commander_task_snapshot(1), world.battle_definition), &"di_tian")
	check(recovery != null and recovery.action == GrowthCommanderCommand.Action.RECOVER, "depleted explicit mission temporarily recovers")
	if recovery != null:
		recovery.command_id = world.allocate_command_id()
		check(world.submit_command(recovery).is_accepted(), "recovery validated through shared pipeline")
		world.advance_tick()
		check(commander.growth_recovering and commander.growth_resume_region_id == target.region_id and commander.growth_resume_route == route, "recovery preserves player objective and route")
		world.command_queue.drain()
		world.current_tick += 81
		place_group(world, commander, commander.target_position, 90.0, false)
		world._update_faction_knowledge()
		check(command_for(agent.propose(world.create_commander_task_snapshot(1), world.battle_definition), &"di_tian") == null, "no premature return without ammunition")
		place_group(world, commander, commander.target_position, 90.0, true)
		var resume := command_for(agent.propose(world.create_commander_task_snapshot(1), world.battle_definition), &"di_tian")
		check(resume != null and resume.action == GrowthCommanderCommand.Action.RESUME, "rearmed group resumes mission")
		if resume != null:
			resume.command_id = world.allocate_command_id()
			check(world.submit_command(resume).is_accepted(), "resume validated")
			world.advance_tick()
			check(not commander.growth_recovering and commander.target_region_id == target.region_id and commander.planned_route == route and not commander.autonomous_growth, "original player mission restored")
	# Equal observations and strength; cautious and resolute commanders react differently.
	var view := world.create_commander_task_snapshot(1)
	view.tick += 100
	view.units.clear()
	var own := view.get_commander(&"di_tian")
	for card in view.unit_cards:
		if card.commander_definition_id == own.definition_id:
			card.center_position = position
			card.current_strength = 3
			card.organization = 100.0
			card.ammunition = card.ammunition_capacity
	for index in range(12):
		var hostile := UnitSnapshot.new(UnitState.new(9000 + index, position + Vector2(index, 0), 100, 2))
		hostile.is_visible_to_local_player = true
		view.units.append(hostile)
	own.personality_key = &"PERSONALITY_CAUTIOUS"
	var cautious := command_for(agent.propose(view, world.battle_definition), own.definition_id)
	own.personality_key = &"PERSONALITY_RESOLUTE"
	var resolute := command_for(agent.propose(view, world.battle_definition), own.definition_id)
	check(cautious != null and cautious.action == GrowthCommanderCommand.Action.RECOVER and resolute == null, "same visible threat changes personality response")
	var before := command_signature(agent.propose(world.create_commander_task_snapshot(1), world.battle_definition))
	world.units[1001].position += Vector2(-100, 0)
	world.units[1001].health = 1
	check(before == command_signature(agent.propose(world.create_commander_task_snapshot(1), world.battle_definition)), "hidden enemy cannot alter growth decision")
	check_support_ai()
	check_equal_engagement()
	for failure in failures: push_error(failure)
	print("GROWTH_AGENT_BOUNDARIES failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check_support_ai() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var agent := GrowthSupportAgent.new()
	var faction := world.factions[2] as FactionState
	faction.supply = 120
	var position := world.battle_definition.battlefield_bounds.get_center()
	for index in range(1, 7): world.units[index].position = position + Vector2(index * 8, 0)
	world._update_faction_knowledge()
	check(agent.propose(world.create_true_state_snapshot(), world.battle_definition, world.battle_definition.enemy_agent_id) == null, "support rejects true state")
	check(agent.propose(world.create_faction_snapshot(2), world.battle_definition, world.battle_definition.enemy_agent_id) == null, "support ignores hidden cluster")
	var recon := AreaSupportCommand.new(world.allocate_command_id(), 2, GameCommand.IssuerKind.AGENT, 0, SupportOrderCommand.SupportKind.AIR_RECON, position)
	recon.agent_id = world.battle_definition.enemy_agent_id
	check(world.submit_command(recon).is_accepted(), "enemy recon uses normal pipeline")
	world.advance_tick()
	world.command_queue.drain()
	faction.supply = 119
	check(agent.propose(world.create_faction_snapshot(2), world.battle_definition, recon.agent_id) == null, "AI reserves recruitment supply")
	faction.supply = 120
	var strike := agent.propose(world.create_faction_snapshot(2), world.battle_definition, recon.agent_id)
	check(strike != null and strike.support_kind == SupportOrderCommand.SupportKind.MISSILE_BARRAGE, "observed cluster yields missile plan")
	if strike != null:
		strike.command_id = world.allocate_command_id()
		check(world.submit_command(strike).is_accepted(), "enemy missile authorized and priced normally")
		world.advance_tick()
		check(faction.supply == 60, "enemy pays missile cost")
	world.command_queue.drain()
	faction.supply = 300
	faction.support_cooldown_until_by_kind.clear()
	world.units[1001].position = position
	world._update_faction_knowledge()
	var safe := agent.propose(world.create_faction_snapshot(2), world.battle_definition, recon.agent_id)
	check(safe == null or safe.support_kind != SupportOrderCommand.SupportKind.MISSILE_BARRAGE, "missile avoids current allies")

func check_equal_engagement() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var blue := world.unit_cards[&"final_group_1_armored_spearhead"] as UnitCardState
	var red := world.unit_cards[&"red_final_group_1_armored_spearhead"] as UnitCardState
	var center := world.battle_definition.battlefield_bounds.get_center()
	for unit: UnitState in world.units.values(): unit.enabled = false
	for card in [blue, red]:
		var unit := world.units[card.member_entity_ids[0]] as UnitState
		unit.enabled = true
		unit.position = center + Vector2(-200 if card.faction_id == 1 else 200, 0)
		unit.attack_range = 100.0
		unit.sight_range = 1000.0
		world.formations[card.formation_id].anchor_position = unit.position
	world._update_faction_knowledge()
	var blue_cards: Array[UnitCardState] = [blue]
	var red_cards: Array[UnitCardState] = [red]
	check(world._select_commander_focus_target(blue_cards, 1) == red.member_entity_ids[0], "blue acquires visible target outside weapon range")
	check(world._select_commander_focus_target(red_cards, 2) == blue.member_entity_ids[0], "red uses identical proactive engagement radius")

func place_group(world: SimulationWorld, commander: CommanderState, position: Vector2, organization: float, rearmed: bool) -> void:
	for id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[id] as UnitCardState
		card.organization = organization
		world.formations[card.formation_id].anchor_position = position
		for entity_id in card.member_entity_ids:
			var unit := world.units[entity_id] as UnitState
			unit.position = position
			unit.ammunition = unit.ammunition_capacity if rearmed else 0

func command_for(commands: Array[GrowthCommanderCommand], id: StringName) -> GrowthCommanderCommand:
	for command in commands:
		if command.commander_id == id: return command
	return null

func command_signature(commands: Array[GrowthCommanderCommand]) -> String:
	var parts: Array[String] = []
	for command in commands: parts.append("%s:%d:%s:%s" % [command.commander_id, command.action, command.target_region_id, command.target_position])
	return "|".join(parts)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
