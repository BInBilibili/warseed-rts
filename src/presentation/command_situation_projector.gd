class_name CommandSituationProjector
extends RefCounted

const LOW_ORGANIZATION_THRESHOLD := 35.0
const CRITICAL_ORGANIZATION_THRESHOLD := 15.0
const REINFORCEMENT_STRENGTH_RATIO := 0.6
const EXPOSED_SUPPORT_RADIUS := 520.0
const EXPOSED_THREAT_MARGIN := 320.0

var last_rejection_reason: StringName


func project(
	snapshot: WorldSnapshot,
	situation: BattlefieldSituationSnapshot,
	observer_faction_id: int
) -> CommandSituationSnapshot:
	last_rejection_reason = &""
	if snapshot == null or situation == null:
		last_rejection_reason = &"SITUATION_REQUIRED"
		return null
	if snapshot.is_true_state:
		last_rejection_reason = &"TRUE_STATE_FORBIDDEN"
		return null
	if snapshot.observer_faction_id != observer_faction_id or situation.observer_faction_id != observer_faction_id:
		last_rejection_reason = &"WRONG_OBSERVER_FACTION"
		return null
	if snapshot.knowledge == null or snapshot.knowledge.faction_id != observer_faction_id:
		last_rejection_reason = &"FACTION_KNOWLEDGE_REQUIRED"
		return null
	if snapshot.tick != situation.source_tick:
		last_rejection_reason = &"SOURCE_TICK_MISMATCH"
		return null

	var intents := _derive_intents(snapshot, observer_faction_id)
	var exceptions := _derive_exceptions(snapshot, situation, observer_faction_id)
	return CommandSituationSnapshot.new(snapshot.tick, observer_faction_id, intents, exceptions)


func _derive_intents(snapshot: WorldSnapshot, observer_faction_id: int) -> Array[HighLevelIntentSnapshot]:
	var commanders: Array[CommanderSnapshot] = []
	for commander in snapshot.commanders:
		if commander.faction_id == observer_faction_id and not commander.active_intent_id.is_empty():
			commanders.append(commander)
	commanders.sort_custom(func(left: CommanderSnapshot, right: CommanderSnapshot) -> bool:
		return String(left.definition_id) < String(right.definition_id)
	)
	var result: Array[HighLevelIntentSnapshot] = []
	for commander in commanders:
		result.append(HighLevelIntentSnapshot.new(commander))
	return result


func _derive_exceptions(
	snapshot: WorldSnapshot,
	situation: BattlefieldSituationSnapshot,
	observer_faction_id: int
) -> Array[CommandExceptionSnapshot]:
	var result: Array[CommandExceptionSnapshot] = []
	if snapshot.growth_mode:
		_append_growth_alerts(result, snapshot)
	for card in situation.card_statuses:
		_append_card_exceptions(result, snapshot, situation, card)
	_append_supply_exception(result, snapshot, situation, observer_faction_id)
	result.sort_custom(func(left: CommandExceptionSnapshot, right: CommandExceptionSnapshot) -> bool:
		if left.severity != right.severity:
			return left.severity > right.severity
		if left.kind != right.kind:
			return left.kind < right.kind
		if snapshot.growth_mode and left.source_tick != right.source_tick:
			return left.source_tick > right.source_tick
		return String(left.exception_id) < String(right.exception_id)
	)
	if snapshot.growth_mode:
		var compact: Array[CommandExceptionSnapshot] = []
		var seen: Dictionary = {}
		for alert in result:
			var key := "%s:%d" % [alert.commander_id, alert.kind] if not alert.commander_id.is_empty() else String(alert.exception_id)
			if seen.has(key): continue
			seen[key] = true
			compact.append(alert)
			if compact.size() >= 6: break
		return compact
	return result


func _append_card_exceptions(
	result: Array[CommandExceptionSnapshot],
	snapshot: WorldSnapshot,
	situation: BattlefieldSituationSnapshot,
	card: Dictionary
) -> void:
	if int(card["deployment_state"]) != UnitCardState.DeploymentState.DEPLOYED or int(card["current_strength"]) <= 0:
		return
	var card_id := StringName(card["card_id"])
	var commander_id := StringName(card["commander_id"])
	var name_key := StringName(card["display_name_key"])
	var position := card["position"] as Vector2
	var task_id := int(card["task_id"])
	var task := snapshot.get_task(task_id) if task_id != 0 else null
	var safety_actions := _card_safety_actions(snapshot, card)
	if task != null and task.lifecycle == TaskState.Lifecycle.BLOCKED:
		result.append(CommandExceptionSnapshot.new(
			StringName("blocked:%08d" % task.task_id), CommandExceptionSnapshot.Kind.BLOCKED,
			CommandExceptionSnapshot.Severity.CRITICAL, _blocked_reason_key(task.blocked_reason),
			task.last_transition_tick, commander_id, card_id, name_key, task.task_id, position,
			0.0, 0.0, [CommandExceptionSnapshot.Action.RESUME_TASK, CommandExceptionSnapshot.Action.CANCEL_TASK, CommandExceptionSnapshot.Action.FOCUS]
		))
	if bool(card["organization_enabled"]) and float(card["organization"]) < LOW_ORGANIZATION_THRESHOLD:
		var organization := float(card["organization"])
		result.append(CommandExceptionSnapshot.new(
			StringName("organization:%s" % card_id), CommandExceptionSnapshot.Kind.LOW_ORGANIZATION,
			CommandExceptionSnapshot.Severity.CRITICAL if organization <= CRITICAL_ORGANIZATION_THRESHOLD else CommandExceptionSnapshot.Severity.WARNING,
			&"COMMAND_EXCEPTION_LOW_ORGANIZATION", snapshot.tick, commander_id, card_id, name_key,
			task_id, position, organization, LOW_ORGANIZATION_THRESHOLD,
			safety_actions
		))
	var authorized := int(card["authorized_strength"])
	var current := int(card["current_strength"])
	if not snapshot.growth_mode and authorized > 0 and float(current) / float(authorized) <= REINFORCEMENT_STRENGTH_RATIO:
		result.append(CommandExceptionSnapshot.new(
			StringName("reinforcement:%s" % card_id), CommandExceptionSnapshot.Kind.REINFORCEMENT_REQUEST,
			CommandExceptionSnapshot.Severity.WARNING, &"COMMAND_EXCEPTION_REINFORCEMENT_REQUEST",
			snapshot.tick, commander_id, card_id, name_key, task_id, position,
			current, authorized, [CommandExceptionSnapshot.Action.REQUEST_REINFORCEMENT, CommandExceptionSnapshot.Action.KEEP_PLAN, CommandExceptionSnapshot.Action.FOCUS]
		))
	var nearest_threat := _nearest_exposing_threat(card_id, position, situation)
	if not nearest_threat.is_empty():
		var estimated_max := int(nearest_threat["estimated_max"])
		result.append(CommandExceptionSnapshot.new(
			StringName("exposed:%s:%s" % [card_id, nearest_threat["zone_id"]]),
			CommandExceptionSnapshot.Kind.EXPOSED,
			CommandExceptionSnapshot.Severity.CRITICAL if int(nearest_threat["visible_count"]) > 0 and estimated_max >= current else CommandExceptionSnapshot.Severity.WARNING,
			&"COMMAND_EXCEPTION_EXPOSED", int(nearest_threat["last_seen_tick"]),
			commander_id, card_id, name_key, task_id, position,
			estimated_max, current, safety_actions
		))


func _card_safety_actions(snapshot: WorldSnapshot, card: Dictionary) -> Array[int]:
	var fallback: Array[int] = [CommandExceptionSnapshot.Action.FOCUS, CommandExceptionSnapshot.Action.KEEP_PLAN]
	var commander := snapshot.get_commander(StringName(card["commander_id"]))
	var unit_card := snapshot.get_unit_card(StringName(card["card_id"]))
	if commander == null or commander.faction_id != snapshot.observer_faction_id or unit_card == null:
		return fallback
	match unit_card.control_state:
		UnitCardState.ControlState.AGENT_ASSIGNED:
			return [CommandExceptionSnapshot.Action.DISENGAGE_COMMANDER, CommandExceptionSnapshot.Action.KEEP_PLAN, CommandExceptionSnapshot.Action.FOCUS]
		UnitCardState.ControlState.PLAYER_OVERRIDDEN:
			if unit_card.return_formation_id != 0:
				return [CommandExceptionSnapshot.Action.RETURN_TO_COMMANDER, CommandExceptionSnapshot.Action.FOCUS, CommandExceptionSnapshot.Action.KEEP_PLAN]
			return fallback
		_:
			return fallback


func _append_supply_exception(
	result: Array[CommandExceptionSnapshot],
	snapshot: WorldSnapshot,
	situation: BattlefieldSituationSnapshot,
	observer_faction_id: int
) -> void:
	var available := int(situation.supply.get("available", 0))
	var capacity := int(situation.supply.get("capacity", 0))
	var threshold := 4 if not snapshot.navigation_map_id.is_empty() else maxi(2, ceili(float(capacity) * 0.2))
	if capacity <= 0 or available > threshold:
		return
	result.append(CommandExceptionSnapshot.new(
		&"supply:global", CommandExceptionSnapshot.Kind.LOW_SUPPLY,
		CommandExceptionSnapshot.Severity.CRITICAL if available == 0 else CommandExceptionSnapshot.Severity.WARNING,
		&"COMMAND_EXCEPTION_LOW_SUPPLY", snapshot.tick, &"", &"", &"", 0, Vector2.ZERO,
		available, threshold, [CommandExceptionSnapshot.Action.KEEP_PLAN]
	))


func _nearest_exposing_threat(card_id: StringName, position: Vector2, situation: BattlefieldSituationSnapshot) -> Dictionary:
	var friendly_support := 0
	for other in situation.card_statuses:
		if int(other["deployment_state"]) != UnitCardState.DeploymentState.DEPLOYED or int(other["current_strength"]) <= 0:
			continue
		if (other["position"] as Vector2).distance_to(position) <= EXPOSED_SUPPORT_RADIUS:
			friendly_support += 1
	if friendly_support > 1:
		return {}
	var best := {}
	var best_distance := INF
	for threat in situation.threat_zones:
		if not bool(threat["known_threat"]):
			continue
		var distance := position.distance_to(threat["position"] as Vector2)
		if distance > float(threat["radius"]) + EXPOSED_THREAT_MARGIN:
			continue
		if distance < best_distance or is_equal_approx(distance, best_distance) and String(threat["zone_id"]) < String(best.get("zone_id", "")):
			best = threat
			best_distance = distance
	return best


func _blocked_reason_key(reason: TaskState.BlockedReason) -> StringName:
	return StringName("COMMAND_EXCEPTION_BLOCKED_%s" % TaskState.BlockedReason.keys()[reason])


func _append_growth_alerts(result: Array[CommandExceptionSnapshot], snapshot: WorldSnapshot) -> void:
	for card in snapshot.unit_cards:
		if card.faction_id != snapshot.observer_faction_id or card.current_strength == 0 or snapshot.tick - card.last_damage_tick > 80:
			continue
		result.append(CommandExceptionSnapshot.new(StringName("attacked:%s" % card.commander_definition_id), CommandExceptionSnapshot.Kind.UNDER_ATTACK, CommandExceptionSnapshot.Severity.CRITICAL, &"COMMAND_EXCEPTION_UNDER_ATTACK", card.last_damage_tick, card.commander_definition_id, card.definition_id, card.display_name_key, card.assigned_task_id, card.center_position, card.current_strength, card.authorized_strength, [CommandExceptionSnapshot.Action.FOCUS, CommandExceptionSnapshot.Action.KEEP_PLAN]))
	for region in snapshot.strategic_regions:
		var kind := -1
		var reason: StringName
		var severity := CommandExceptionSnapshot.Severity.INFO
		if region.controller_faction_id == snapshot.observer_faction_id and (region.contested or (region.capture_faction_id != 0 and region.capture_faction_id != snapshot.observer_faction_id)):
			kind = CommandExceptionSnapshot.Kind.SUPPLY_THREAT
			reason = &"COMMAND_EXCEPTION_SUPPLY_THREAT"
			severity = CommandExceptionSnapshot.Severity.CRITICAL
		elif region.controller_changed_tick >= 0 and snapshot.tick - region.controller_changed_tick < 150:
			if region.previous_controller_faction_id == snapshot.observer_faction_id:
				kind = CommandExceptionSnapshot.Kind.SUPPLY_LOST
				reason = &"COMMAND_EXCEPTION_SUPPLY_LOST"
				severity = CommandExceptionSnapshot.Severity.WARNING
			elif region.controller_faction_id == snapshot.observer_faction_id:
				kind = CommandExceptionSnapshot.Kind.SUPPLY_CAPTURED
				reason = &"COMMAND_EXCEPTION_SUPPLY_CAPTURED"
		if kind < 0: continue
		# Offensive planning only accepts unowned points. Friendly captures and
		# contested holdings focus the battlefield instead of opening a different objective.
		var actions: Array[int] = [CommandExceptionSnapshot.Action.FOCUS, CommandExceptionSnapshot.Action.KEEP_PLAN]
		if kind == CommandExceptionSnapshot.Kind.SUPPLY_LOST:
			actions.push_front(CommandExceptionSnapshot.Action.REPLAN)
		var alert := CommandExceptionSnapshot.new(StringName("supply:%s:%d:%d" % [region.region_id, kind, region.controller_changed_tick]), kind as CommandExceptionSnapshot.Kind, severity, reason, maxi(0, region.controller_changed_tick), &"", &"", region.display_name_key, 0, region.position, region.supply_per_settlement, region.capture_required_ticks, actions)
		alert.region_id = region.region_id
		result.append(alert)
