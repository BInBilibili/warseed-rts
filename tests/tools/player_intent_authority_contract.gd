extends SceneTree

const Mode := CommanderState.IntentMode
var failures: Array[String] = []
var checks := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
		print("FAIL ", message)


func order(w: SimulationWorld, c: CommanderState, mode: int = -1) -> CommanderOrderCommand:
	var prefix := "blue" if c.faction_id == 1 else "red"
	var region := w.strategic_regions[StringName(prefix + "_mid_outer")] as StrategicRegionState
	var command := CommanderOrderCommand.new(w.allocate_command_id(), c.faction_id, w.current_tick,
		c.definition.definition_id, CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE, region.position, region.region_id)
	command.requested_intent_mode = mode
	return command


func control(w: SimulationWorld, card: UnitCardState, action: UnitCardControlCommand.Action) -> UnitCardControlCommand:
	return UnitCardControlCommand.new(w.allocate_command_id(), card.faction_id, w.current_tick, card.definition.definition_id, action)


func stop(w: SimulationWorld, card: UnitCardState) -> StopCommand:
	var f := w.formations[card.formation_id] as FormationState
	return StopCommand.new(w.allocate_command_id(), card.faction_id, GameCommand.IssuerKind.PLAYER, w.current_tick, f.leader_entity_id, f.formation_id)


func _initialize() -> void:
	for faction in [1, 2]: exercise(faction)
	check(replay() == replay(), "identical authority and physical event replay")
	var output := "res://artifacts/control-contract/authority.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "evidence": "SIMULATED"}))
	print("PLAYER_INTENT_AUTHORITY checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)


func exercise(faction: int) -> void:
	var w := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	w.advance_tick()
	w.command_queue.drain()
	var c: CommanderState
	for candidate: CommanderState in w.commanders.values():
		if candidate.faction_id == faction and candidate.definition.profile.profile_id == &"guardian": c = candidate
	var card := w.unit_cards[c.subordinate_unit_card_ids[0]] as UnitCardState
	var f := w.formations[card.formation_id] as FormationState
	var ai := FormationMoveCommand.new(w.allocate_command_id(), faction, GameCommand.IssuerKind.AGENT, w.current_tick, f.leader_entity_id, f.formation_id, f.anchor_position)
	ai.agent_id = c.agent_id
	ai.task_id = card.assigned_task_id
	check(w.submit_command(ai).is_accepted(), "old AI accepted " + str(faction))
	var force := order(w, c, Mode.FORCE_ATTACK)
	check(w.submit_command(force).is_accepted(), "force accepted " + str(faction))
	force.target_position = Vector2(-100, -100)
	w.advance_tick()
	check(c.intent_mode == Mode.FORCE_ATTACK and c.player_target_position != force.target_position, "frozen command value " + str(faction))
	check(w.events.any(func(e: SimulationEvent) -> bool: return e.kind == SimulationEvent.Kind.COMMAND_REJECTED and e.detail.contains("AUTHORITY_STALE")), "stale AI application rejected " + str(faction))
	var version := c.authority_version
	var old_goal := c.player_target_position
	var invalid := order(w, c)
	invalid.target_position = Vector2(-100, -100)
	check(not w.submit_command(invalid).is_accepted(), "invalid goal rejected " + str(faction))
	check(c.authority_version == version and c.player_target_position == old_goal, "rejection retains authority " + str(faction))
	var transfer := order(w, c)
	check(w.submit_command(transfer).is_accepted(), "transfer accepted " + str(faction))
	w.advance_tick()
	check(c.intent_mode == Mode.FORCE_ATTACK, "transfer retains force mode " + str(faction))
	var view := w.create_commander_task_snapshot(faction)
	view.tick += 100
	for owned in view.unit_cards:
		if owned.commander_definition_id == c.definition.definition_id: owned.organization = 20.0
	check(not GrowthCommanderAgent.new().propose(view, w.battle_definition).any(func(cmd: GrowthCommanderCommand) -> bool: return cmd.commander_id == c.definition.definition_id), "force low organization cannot retreat " + str(faction))
	var recover := GrowthCommanderCommand.new(w.allocate_command_id(), faction, w.current_tick, c.definition.definition_id, GrowthCommanderCommand.Action.RECOVER, &"", old_goal)
	recover.agent_id = c.agent_id
	check(w.submit_command(recover).reason == CommandValidationResult.Reason.AGENT_OVERRIDE_BLOCKED, "forged force recovery rejected " + str(faction))
	check(w.submit_command(stop(w, card)).is_accepted(), "card stop accepted " + str(faction))
	var retreat := CommanderOrderCommand.new(w.allocate_command_id(), faction, w.current_tick, c.definition.definition_id, CommanderOrderCommand.OrderKind.SET_POSTURE, Vector2.ZERO, &"", CommanderState.Posture.DISENGAGE)
	check(w.submit_command(retreat).is_accepted(), "retreat accepted " + str(faction))
	w.advance_tick()
	check(c.intent_mode == Mode.RETREAT and card.control_state == UnitCardState.ControlState.AGENT_ASSIGNED, "later legion retreat overrides card and force " + str(faction))
	check(w.submit_command(order(w, c, Mode.FORCE_ATTACK)).is_accepted(), "new force after retreat accepted " + str(faction))
	check(w.submit_command(stop(w, card)).is_accepted(), "later scoped stop accepted " + str(faction))
	w.advance_tick()
	check(c.intent_mode == Mode.FORCE_ATTACK and card.persistent_manual and card.player_stopped, "later card only overrides own scope " + str(faction))
	for id in c.subordinate_unit_card_ids:
		if id != card.definition.definition_id:
			check((w.unit_cards[id] as UnitCardState).control_state == UnitCardState.ControlState.AGENT_ASSIGNED, "other card still executes " + str(id))
	check(w.submit_command(control(w, card, UnitCardControlCommand.Action.RETURN_TO_COMMANDER)).is_accepted(), "card return accepted " + str(faction))
	w.advance_tick()
	check(c.intent_mode == Mode.FORCE_ATTACK and not card.persistent_manual and card.assigned_task_id != 0, "card return retains legion intent " + str(faction))
	var frozen := w.create_commander_task_snapshot(faction).get_commander(c.definition.definition_id)
	check(w.submit_command(stop(w, card)).is_accepted(), "cancel setup manual " + str(faction))
	w.advance_tick()
	var cancel := CommanderOrderCommand.new(w.allocate_command_id(), faction, w.current_tick, c.definition.definition_id, CommanderOrderCommand.OrderKind.CANCEL_INTENT)
	check(w.submit_command(cancel).is_accepted(), "cancel accepted " + str(faction))
	w.advance_tick()
	check(c.intent_mode == Mode.HOLD and not card.persistent_manual and c.active_intent_id.is_empty(), "cancel whole legion holds " + str(faction))
	check(frozen.intent_mode == Mode.FORCE_ATTACK and frozen.player_target_position == old_goal, "snapshot value copy " + str(faction))
	var released := CommanderOrderCommand.new(w.allocate_command_id(), faction, w.current_tick, c.definition.definition_id, CommanderOrderCommand.OrderKind.RETURN_AI)
	check(w.submit_command(released).is_accepted(), "legion return accepted " + str(faction))
	w.advance_tick()
	check(c.intent_mode == Mode.AUTONOMOUS and c.active_intent_id.is_empty() and c.growth_resume_route.is_empty(), "return does not revive old intent " + str(faction))
	# Persistent route stays owned beyond the old 100-tick quiet timeout.
	var move := FormationMoveCommand.new(w.allocate_command_id(), faction, GameCommand.IssuerKind.PLAYER, w.current_tick, f.leader_entity_id, f.formation_id, f.anchor_position)
	check(w.submit_command(move).is_accepted(), "manual route accepted " + str(faction))
	w.advance_tick()
	for n in range(105): w.advance_tick()
	check(card.persistent_manual and card.control_state == UnitCardState.ControlState.PLAYER_OVERRIDDEN, "completed route not stolen by timer " + str(faction))
	var auto := control(w, card, UnitCardControlCommand.Action.RETURN_TO_COMMANDER)
	auto.automatic_return = true
	check(w.submit_command(auto).reason == CommandValidationResult.Reason.AGENT_OVERRIDE_BLOCKED, "automatic return prohibited " + str(faction))
	# Hidden truth pollution does not alter either side's legitimate proposals.
	var before := proposal_signature(w, faction)
	var hidden_count := 0
	for enemy: UnitState in w.units.values():
		if enemy.faction_id != faction and not w.is_entity_visible_to_faction(enemy.entity_id, faction):
			enemy.position += Vector2(32, 0)
			enemy.health = 1.0
			enemy.attack_target_entity_id = f.leader_entity_id
			hidden_count += 1
	check(hidden_count > 0 and before == proposal_signature(w, faction), "hidden pollution cannot affect plans " + str(faction))
	var hidden_id := 0
	for enemy: UnitState in w.units.values():
		if enemy.faction_id != faction and not w.is_entity_visible_to_faction(enemy.entity_id, faction): hidden_id = enemy.entity_id; break
	var attack := AttackCommand.new(w.allocate_command_id(), faction, GameCommand.IssuerKind.PLAYER, w.current_tick, f.leader_entity_id, hidden_id, f.formation_id)
	var card_version := card.authority_version
	check(w.submit_command(attack).reason == CommandValidationResult.Reason.HIDDEN_TARGET, "hidden attack rejected " + str(faction))
	check(card.authority_version == card_version, "hidden rejection cannot steal control " + str(faction))
	check(GrowthCommanderAgent.new().propose(w.create_true_state_snapshot(), w.battle_definition).is_empty(), "agent rejects true state " + str(faction))
	# Accepted order then hero death must be interrupted before application.
	check(w.submit_command(order(w, c, Mode.FORCE_ATTACK)).is_accepted(), "predeath accepted " + str(faction))
	(w.units[c.hero_entity_id] as UnitState).enabled = false
	w.advance_tick()
	check(c.legion_regrouping and c.intent_mode == Mode.AUTONOMOUS and c.intent_receipt == CommanderState.IntentReceipt.INTERRUPTED, "death hard rule interrupts " + str(faction))
	check(w.submit_command(order(w, c, Mode.FORCE_ATTACK)).reason == CommandValidationResult.Reason.ENTITY_DISABLED, "death lock rejects reattack " + str(faction))


func proposal_signature(w: SimulationWorld, faction: int) -> Array:
	var result := []
	for command in GrowthCommanderAgent.new().propose(w.create_commander_task_snapshot(faction), w.battle_definition):
		result.append([command.commander_id, command.action, command.target_region_id, command.target_position])
	return result


func replay() -> String:
	var w := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var c := w.commanders[&"di_tian"] as CommanderState
	w.submit_command(order(w, c, Mode.FORCE_ATTACK))
	for n in range(12): w.advance_tick()
	var result := []
	for e in w.events: result.append([e.tick, e.kind, e.entity_id, e.detail])
	for u: UnitState in w.units.values(): result.append([u.entity_id, u.position, u.health])
	return var_to_str(result)
