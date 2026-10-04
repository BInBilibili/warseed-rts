extends SceneTree

var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if not value: failures.append(label)

func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var faction := world.factions[1] as FactionState
	var ids: Array[StringName] = [&"bai_jiuyang", &"di_tian", &"lin_mo", &"lu_zheng"]
	var old := world.create_faction_snapshot(1)
	var plan := RecruitmentPlanCommand.new(world.allocate_command_id(), 1, 0, ids, [0, 2, 1, 2], 60)
	check(world.submit_command(plan).is_accepted(), "custom plan accepted")
	plan.rates[0] = 2
	plan.reserve = 0
	world.advance_tick()
	check(faction.recruitment_reserve == 60 and faction.recruitment_rates[ids[0]] == 0, "queued plan value copy")
	check(old.get_faction(1).recruitment_rates.is_empty() and old.get_faction(1).recruitment_reserve == 12, "old plan snapshot immutable")
	check(world.create_faction_snapshot(2).get_faction(1).recruitment_rates.is_empty(), "opponent cannot read plan")
	check(not world.submit_command(RecruitmentPlanCommand.new(world.allocate_command_id(), 1, 1, ids, [2,2,2,0], 0)).is_accepted(), "reject total above five")
	check(not world.submit_command(RecruitmentPlanCommand.new(world.allocate_command_id(), 1, 1, ids, [0,0,0,3], 0)).is_accepted(), "reject per group above two")
	check(not world.submit_command(RecruitmentPlanCommand.new(world.allocate_command_id(), 1, 1, [&"red_di_tian"], [1], 0)).is_accepted(), "reject hostile/incomplete plan")
	world.command_queue.drain()
	faction.supply = 300
	# Freeze strategic advancement only, retain real logistics, validation and spawning.
	for commander: CommanderState in world.commanders.values():
		commander.last_growth_order_tick = 100000
	var before := faction.population
	for tick in range(22): world.advance_tick()
	check(faction.population == before + 10, "two seconds recruit five each")
	check(faction.recruitment_rates[ids[0]] == 0, "paused group keeps quota zero")
	var paused_strength := 0
	var highlighted := 0
	for card: UnitCardState in world.unit_cards.values():
		if card.commander_definition_id == ids[0]: paused_strength += UnitCardSnapshot.new(card,world.units).current_strength
	for unit: UnitState in world.units.values():
		if unit.faction_id == 1 and unit.reinforced_until_tick > world.current_tick: highlighted += 1
	check(paused_strength == 12 and highlighted == 10, "paused group unchanged and new recruits have ten second halos")
	world.command_queue.drain()
	faction.supply = 60
	var low_before := faction.population
	for tick in range(10): world.advance_tick()
	check(faction.population == low_before and faction.supply == 60, "reserve prevents automatic spend")
	world.command_queue.drain()
	var point := world.strategic_regions[&"blue_mid_outer"] as StrategicRegionState
	point.controller_faction_id = 0
	var hospital := AreaSupportCommand.new(world.allocate_command_id(),1,0,world.current_tick,SupportOrderCommand.SupportKind.FIELD_HOSPITAL,point.position)
	check(world.submit_command(hospital).is_accepted(), "hospital allowed on neutral frontline with no friendly supply")
	world.advance_tick()
	check(faction.supply == 20, "manual support may spend the recruitment reserve")
	world.command_queue.drain()
	faction.support_cooldown_until_by_kind.clear()
	faction.supply = 100
	point.controller_faction_id = 2
	check(not world.validate_command(hospital).is_accepted(), "hospital forbidden inside hostile control radius")
	check(faction.supply == 100, "rejected hospital does not spend")
	# Use an actual road beyond this enemy point rather than a guessed walkable cell.
	var outside := point.position.lerp(world.strategic_regions[&"blue_mid_inner"].position, 0.6)
	if world.logic_grid.is_world_position_walkable(outside):
		hospital.position = outside
		check(world.validate_command(hospital).is_accepted(), "outside hostile control radius allowed")
	world.command_queue.drain()
	# Plain move is temporary; explicit takeover cancels automatic handback.
	var card := world.unit_cards[world.commanders[ids[1]].subordinate_unit_card_ids[0]] as UnitCardState
	var formation := world.formations[card.formation_id] as FormationState
	var move := FormationMoveCommand.new(world.allocate_command_id(),1,0,world.current_tick,formation.leader_entity_id,formation.formation_id,formation.anchor_position + Vector2(64,0))
	check(world.submit_command(move).is_accepted() and card.temporary_micro, "move starts temporary adjustment")
	var returned := false
	for tick in range(180):
		world.advance_tick()
		if not card.temporary_micro:
			returned = true
			break
	check(returned and card.control_state not in [UnitCardState.ControlState.PLAYER_CONTROLLED,UnitCardState.ControlState.PLAYER_OVERRIDDEN], "arrival hands control back through pipeline")
	world.command_queue.drain()
	var manual := UnitCardControlCommand.new(world.allocate_command_id(),1,world.current_tick,card.definition.definition_id,UnitCardControlCommand.Action.TAKEOVER)
	check(world.submit_command(manual).is_accepted(), "explicit takeover accepted")
	world.advance_tick()
	world.command_queue.drain()
	move.command_id = world.allocate_command_id()
	move.issued_tick = world.current_tick
	move.target_position = formation.anchor_position + Vector2(32,0)
	check(world.submit_command(move).is_accepted() and not card.temporary_micro, "explicit manual persists across movement")
	_reserve_ability_boundary()
	_queue_and_feedback_boundaries()
	for failure in failures: push_error(failure)
	print("GROWTH_FEEDBACK19 failures=", failures)
	quit(0 if failures.is_empty() else 1)


func _queue_and_feedback_boundaries() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var faction := world.factions[1] as FactionState
	faction.supply = 300
	var accepted := 0
	var grouped: Dictionary[StringName, int] = {}
	for card: UnitCardState in world.unit_cards.values():
		if card.faction_id != 1: continue
		for attempt in range(3):
			var order := RecruitUnitCardCommand.new(world.allocate_command_id(), 1, GameCommand.IssuerKind.PLAYER, 0, card.definition.definition_id, 1)
			if world.submit_command(order).is_accepted():
				accepted += 1
				grouped[card.commander_definition_id] = grouped.get(card.commander_definition_id, 0) + 1
	check(accepted == 5 and grouped.get(&"di_tian", 0) == 2, "pending commands enforce global five and group quotas")
	world.advance_tick()
	check(faction.population == 53, "all five reserved recruits execute once")
	world.command_queue.drain()
	var sample := world.unit_cards[world.commanders[&"di_tian"].subordinate_unit_card_ids[0]] as UnitCardState
	var order := RecruitUnitCardCommand.new(world.allocate_command_id(), 1, GameCommand.IssuerKind.PLAYER, world.current_tick, sample.definition.definition_id, 1)
	check(not world.submit_command(order).is_accepted(), "executed recruits still consume current second quota")
	world.current_tick = 10
	faction.population = 255
	check(world.submit_command(order).is_accepted(), "last population slot accepted")
	check(not world.submit_command(order).is_accepted(), "pending recruitment reserves last population slot")
	world.command_queue.drain()
	faction.population = 53
	faction.supply = faction.recruitment_reserve + sample.definition.recruitment_cost
	check(world.submit_command(order).is_accepted(), "last spendable recruitment cost accepted")
	check(not world.submit_command(order).is_accepted(), "pending recruitment preserves reserved currency")
	world.command_queue.drain()
	# A newer direction must cancel a handback already queued for this card.
	sample.temporary_micro = true
	var handback := UnitCardControlCommand.new(world.allocate_command_id(), 1, 10, sample.definition.definition_id, UnitCardControlCommand.Action.RETURN_TO_COMMANDER)
	handback.automatic_return = true
	world.submit_command(handback)
	var formation := world.formations[sample.formation_id] as FormationState
	var move := FormationMoveCommand.new(world.allocate_command_id(), 1, 0, 10, formation.leader_entity_id, formation.formation_id, formation.anchor_position + Vector2(64,0))
	check(world.submit_command(move).is_accepted(), "new movement accepted during pending handback")
	for pending in world.command_queue.snapshot():
		check(not (pending is UnitCardControlCommand and pending.automatic_return), "new movement cancels stale handback")
	var snapshot := world.create_faction_snapshot(1)
	var director := BattleFeedbackDirector.new()
	director.audio_enabled = false
	var messages: Array[String] = []
	director.feedback_emitted.connect(func(key: StringName, args: Array, _severity: int) -> void: messages.append(GameText.t(key) % args.map(func(arg): return GameText.t(StringName(str(arg))))))
	var losses: Array[SimulationEvent] = []
	for id in world.commanders[&"di_tian"].subordinate_unit_card_ids:
		var card := world.unit_cards[id] as UnitCardState
		losses.append(SimulationEvent.new(10, SimulationEvent.Kind.UNIT_DESTROYED, card.member_entity_ids[0], ""))
	director.process_events(losses, snapshot)
	check(messages.size() == 1 and messages[0].contains(GameText.t(snapshot.get_commander(&"di_tian").display_name_key)), "same legion losses merge and name its commander in banner")
	director.free()


func _reserve_ability_boundary() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.advance_tick()
	world.advance_tick()
	world.command_queue.drain()
	var faction := world.factions[1] as FactionState
	faction.recruitment_reserve = 60
	faction.supply = 60
	var tested := false
	for card: UnitCardState in world.unit_cards.values():
		if card.faction_id != 1 or card.definition.tactical_ability == null or card.definition.tactical_ability.kind != TacticalAbilityDefinition.Kind.BREAKTHROUGH: continue
		var command := TacticalAbilityCommand.new(world.allocate_command_id(), 1, GameCommand.IssuerKind.AGENT, world.current_tick, card.definition.definition_id)
		command.agent_id = card.assigned_agent_id
		command.task_id = card.assigned_task_id
		command.position = UnitCardSnapshot.new(card,world.units).center_position + Vector2(32,0)
		var result := world.tactical_ability_system.validate(world, command)
		check(result.reason == CommandValidationResult.Reason.INSUFFICIENT_SUPPLY, "automatic tactical ability cannot consume player's missile reserve")
		command.issuer_kind = GameCommand.IssuerKind.PLAYER
		check(world.tactical_ability_system.validate(world, command).is_accepted(), "explicit player ability may spend reserve")
		tested = true
		break
	check(tested, "reserve ability fixture has a real armor ability")
