extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.enemy_operation_system._state = null
	world.enemy_reaction_committed_until_tick = 100000
	# Isolate the scout/firepower interaction from strategic recovery of this
	# deliberately reduced five-member group (the normal recovery threshold is 8).
	for commander: CommanderState in world.commanders.values():
		commander.last_growth_order_tick = 100000
	var chosen: Array[StringName] = []
	for card in world.unit_cards.values():
		if "group_1_" in String(card.definition.definition_id) and card.definition.tactical_ability != null and card.definition.tactical_ability.kind in [TacticalAbilityDefinition.Kind.OBSERVE, TacticalAbilityDefinition.Kind.SUPPRESS]:
			chosen.append(card.definition.definition_id)
		else:
			for id in card.member_entity_ids:
				world.units[id].enabled = false
				world.units[id].health = 0
	var center := world.battle_definition.map_definition.get_world_rect().get_center()
	for card_id in chosen:
		var card := world.unit_cards[card_id] as UnitCardState
		var scout := card.definition.tactical_ability.kind == TacticalAbilityDefinition.Kind.OBSERVE
		var point := center + Vector2(-150 if card.faction_id == 1 else 150, -64 if scout else 64)
		var formation := world.formations[card.formation_id] as FormationState
		world._apply_stop(StopCommand.new(world.allocate_command_id(), card.faction_id, GameCommand.IssuerKind.AGENT, 0, formation.leader_entity_id, formation.formation_id))
		formation.anchor_position = point
		formation.target_position = point
		for i in range(card.member_entity_ids.size()):
			var unit := world.units[card.member_entity_ids[i]] as UnitState
			unit.position = point + Vector2((i % 4) * 12 - 18, (i / 4) * 12 - 18)
			unit.has_move_target = false
			unit.following_formation = false
			unit.health = 10000 # Test fixture keeps observation targets alive through preparation.
			unit.max_health = 10000
		var task := world.tasks[card.assigned_task_id] as TaskState
		task.kind = TaskState.Kind.ENEMY_OPERATION
		task.target_position = point
	world._refresh_battle_population()
	world._update_faction_knowledge()
	var identified := {1: 0, 2: 0}
	var suppressed := {1: 0, 2: 0}
	for faction in [1, 2]:
		var legal := world.create_faction_snapshot(faction)
		print("TACTIC_INITIAL faction=",faction," commands=",TacticalCardAgent.new().propose(legal, world.battle_definition).size()," units=",legal.units.size())
		for card in legal.unit_cards:
			if chosen.has(card.definition_id):
				print("TACTIC_CARD ",card.definition_id," strength=",card.current_strength," control=",card.control_state," agent=",card.assigned_agent_id," task=",card.assigned_task_id," moving=",legal.get_unit(card.active_member_entity_ids[0]).is_moving)
	for tick in range(200): world.advance_tick()
	for event in world.events:
		if event.kind == SimulationEvent.Kind.TACTICAL_IDENTIFIED:
			var faction := 1 if "faction=1;" in event.detail else 2
			identified[faction] += 1
		if event.kind == SimulationEvent.Kind.SUPPRESSION_APPLIED:
			var target := world.units.get(event.entity_id) as UnitState
			if target != null: suppressed[target.faction_id] += 1
	for faction in [1, 2]:
		if identified[faction] == 0: failures.append("faction %d never identified through actual observation" % faction)
		if suppressed[faction] == 0: failures.append("faction %d never delivered suppression fire" % faction)
	for failure in failures: push_error(failure)
	for event in world.events:
		if event.kind in [SimulationEvent.Kind.TACTICAL_ACTION_STARTED, SimulationEvent.Kind.TACTICAL_ACTION_INTERRUPTED, SimulationEvent.Kind.TACTICAL_ACTION_COMPLETED]:
			print("TACTIC tick=%d faction=%d %s %s" % [event.tick, event.entity_id, SimulationEvent.Kind.keys()[event.kind], event.detail])
	print("FINAL_TACTICS identified=%s suppressed=%s failures=%s" % [identified, suppressed, failures])
	quit(0 if failures.is_empty() else 1)
