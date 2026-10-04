extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var battle := world.battle_definition
	# Tasks are private to their faction, including enemy operation control contexts.
	for observer in [1, 2]:
		var legal := world.create_faction_snapshot(observer)
		for task in legal.tasks:
			_expect(task.faction_id in [0, observer], "opponent task must stay private")
		for card in legal.unit_cards:
			_expect(legal.get_task(card.assigned_task_id) != null, "each faction card has a real task")
	var red := world.create_faction_snapshot(2)
	var red_scout: UnitCardSnapshot
	for card in red.unit_cards:
		if card.tactical_kind == TacticalAbilityDefinition.Kind.OBSERVE:
			red_scout = card
			break
	var observe := TacticalAbilityCommand.new(world.allocate_command_id(), 2, GameCommand.IssuerKind.AGENT, 0, red_scout.definition_id, red_scout.center_position)
	observe.agent_id = red_scout.assigned_agent_id
	observe.task_id = red_scout.assigned_task_id
	_expect(world.validate_command(observe).is_accepted(), "red reconnaissance has valid skill authorization")
	# Legal snapshots decide resupply; mutate only a fixture snapshot for boundary predicates.
	for id in [1]:
		world.units[id].enabled = false
		world.units[id].health = 0
	world._refresh_battle_population()
	world.current_tick = 30
	world._update_faction_knowledge()
	var legal := world.create_faction_snapshot(1)
	var agent := AutomaticLogisticsAgent.new()
	var proposed := agent.propose(legal, battle)
	_expect(proposed != null, "damaged friendly card at base replenishes automatically")
	if proposed != null:
		var card := legal.get_unit_card(proposed.unit_card_id)
		legal.unit_cards.assign([card])
		var faction := legal.get_faction(1)
		var supply := faction.supply
		faction.supply = battle.reinforcement_supply_reserve
		_expect(agent.propose(legal, battle) == null, "preserve supply reserve")
		faction.supply = supply
		faction.recruitment_ready_tick = legal.tick + 1
		_expect(agent.propose(legal, battle) == null, "respect cooldown")
		faction.recruitment_ready_tick = 0
		card.is_player_overridden = true
		_expect(agent.propose(legal, battle) == null, "never replenish player takeover")
		card.is_player_overridden = false
		legal.get_strategic_region(&"blue_base").contested = true
		_expect(agent.propose(legal, battle) == null, "contested supply cannot replenish")
		legal.get_strategic_region(&"blue_base").contested = false
		var before := _marker_signature(MinimapMarkerProjector.new().project(world.create_faction_snapshot(1), []))
		world.units[1001].position += Vector2(-300, 0)
		world.units[1001].health = 1
		var after := world.create_faction_snapshot(1)
		_expect(_marker_signature(MinimapMarkerProjector.new().project(after, [])) == before, "hidden enemy pollution cannot change minimap")
		_expect(agent.propose(after, battle).unit_card_id == proposed.unit_card_id, "hidden enemy pollution cannot change logistics")
		proposed.command_id = world.allocate_command_id()
		var before_strength := world.create_faction_snapshot(1).get_unit_card(proposed.unit_card_id).current_strength
		_expect(world.submit_command(proposed).is_accepted(), "queue automatic replenishment")
		var takeover := UnitCardControlCommand.new(world.allocate_command_id(), 1, world.current_tick, proposed.unit_card_id, UnitCardControlCommand.Action.TAKEOVER)
		_expect(world.submit_command(takeover).is_accepted(), "queue takeover before replenishment applies")
		world.advance_tick()
		_expect(world.create_faction_snapshot(1).get_unit_card(proposed.unit_card_id).current_strength == before_strength, "same-tick player takeover blocks queued automatic replenish")
	# Rules use the regular objective system; the old scenario's resource remains untouched.
	for fixture in ["timeout", "mutual", "blue", "red"]:
		world.buildings[2001].enabled = fixture in ["timeout", "blue"]
		world.buildings[2101].enabled = fixture in ["timeout", "red"]
		world.objective_system.configure(battle.objective_set)
		var outcome := world.objective_system.advance(world, [], battle.time_limit_ticks if fixture == "timeout" else 31)
		var expected := BattleOutcome.Result.DRAW if fixture in ["timeout", "mutual"] else (BattleOutcome.Result.VICTORY if fixture == "blue" else BattleOutcome.Result.DEFEAT)
		_expect(outcome.result == expected, "symmetric outcome " + fixture)
		if fixture == "timeout":
			world.battle_outcome = outcome
			var record := ArmyRosterStore.build_battle_record(world.create_faction_snapshot(1), {}, &"final_decision")
			var path := ArmyRosterStore.campaign_record_path_for_session("final-boundary-validation", &"final_decision")
			_expect(ArmyRosterStore.save_record(record, path), "atomic final roster save")
			var loaded := ArmyRosterStore.load_record(path)
			_expect(loaded.get("last_result") == "draw" and loaded.get("cards", {}).size() == 16, "draw and all final cards round trip")
	var legacy := load("res://data/objectives/standard_card_battle_objectives.tres") as BattleObjectiveSetDefinition
	_expect(legacy.conclusion_groups[2].outcome_result == BattleOutcome.Result.DEFEAT, "legacy objective resource unchanged")
	for failure in failures: push_error(failure)
	print("FINAL_BOUNDARIES failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _marker_signature(markers: Array[MinimapMarkerProjector.Marker]) -> String:
	var rows: PackedStringArray = []
	for marker in markers:
		rows.append("%s:%s:%s:%s" % [marker.kind, marker.position, marker.faction_id, marker.remembered])
	return "|".join(rows)

func _expect(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)
