class_name GrowthCommanderAgent
extends RefCounted

func propose(snapshot: WorldSnapshot, battle: BattleDefinition, only_commander: StringName = &"") -> Array[GrowthCommanderCommand]:
	var result: Array[GrowthCommanderCommand] = []
	if snapshot == null or snapshot.is_true_state or snapshot.knowledge == null or snapshot.knowledge.faction_id != snapshot.observer_faction_id or battle == null or not battle.growth_mode:
		return result
	for commander in snapshot.commanders:
		if not only_commander.is_empty() and commander.definition_id != only_commander: continue
		if commander.legion_regrouping or commander.faction_id != snapshot.observer_faction_id or snapshot.tick - commander.last_growth_order_tick < (20 if commander.strategic_lane_id == &"mobile" else 80) or commander.posture in [CommanderState.Posture.HOLD, CommanderState.Posture.DISENGAGE]:
			continue
		var center := Vector2.ZERO
		var strength := 0
		var organization := 0.0
		var frontline_strength := 0
		var frontline_organization := 0.0
		var active_cards := 0
		var ammunition := 0
		var ammunition_capacity := 0
		for id in commander.subordinate_unit_card_ids:
			var card := snapshot.get_unit_card(id)
			if card == null or card.current_strength <= 0 or card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED or card.is_player_overridden:
				continue
			center += card.center_position * card.current_strength
			strength += card.current_strength
			organization += card.organization
			if card.role_key in [&"UNIT_CARD_ROLE_ASSAULT", &"UNIT_CARD_ROLE_ARMOR"]:
				frontline_strength += card.current_strength
				frontline_organization += card.organization * card.current_strength
			active_cards += 1
			if not card.can_fight_without_ammunition:
				ammunition += card.ammunition
				ammunition_capacity += card.ammunition_capacity
		if strength == 0:
			continue
		center /= strength
		organization /= active_cards
		frontline_organization = frontline_organization / frontline_strength if frontline_strength > 0 else organization
		var supported_strength := strength
		for friendly in snapshot.unit_cards:
			if friendly.faction_id != commander.faction_id or commander.subordinate_unit_card_ids.has(friendly.definition_id) or friendly.current_strength <= 0 or friendly.control_state == UnitCardState.ControlState.RETURNING: continue
			if friendly.organization >= 35.0 and friendly.center_position.distance_squared_to(center) <= 1440000.0:
				supported_strength += friendly.current_strength
		var observed_threat := 0
		for hostile in snapshot.units:
			if hostile.enabled and not hostile.legion_returning and hostile.faction_id != commander.faction_id and hostile.is_visible_to_local_player and hostile.position.distance_to(center) < 1200.0:
				observed_threat += 1
		var cautious := commander.personality_key == &"PERSONALITY_CAUTIOUS"
		var aggressive := commander.personality_key in [&"PERSONALITY_RESOLUTE", &"PERSONALITY_OPPORTUNISTIC"]
		var retreat_ratio := 0.85 if cautious else (1.8 if aggressive else 1.25)
		var resupply := _nearest_safe_supply(snapshot, center)
		if commander.growth_recovering:
			var recovery_point := snapshot.get_strategic_region(commander.target_region_id)
			if resupply != null and resupply.region_id != commander.target_region_id and (recovery_point == null or recovery_point.controller_faction_id != commander.faction_id or recovery_point.contested or observed_threat > supported_strength * retreat_ratio):
				result.append(_order(snapshot, commander, GrowthCommanderCommand.Action.RECOVER, resupply.region_id, resupply.position))
			elif recovery_point != null and recovery_point.controller_faction_id == commander.faction_id and not recovery_point.contested and snapshot.tick - commander.recovery_started_tick >= 200 and observed_threat == 0 and organization >= 65.0 and frontline_organization >= 65.0 and strength >= maxi(12, ceili(commander.recovery_strength * 0.75)) and (ammunition_capacity == 0 or ammunition >= ammunition_capacity * 0.4) and AutomaticLogisticsAgent.is_in_supply(snapshot, center, battle) and AutomaticLogisticsAgent.is_safe(snapshot, center, battle):
				result.append(_order(snapshot, commander, GrowthCommanderCommand.Action.RESUME, commander.growth_resume_region_id, commander.growth_resume_position))
			continue
		if commander.intent_mode == CommanderState.IntentMode.FORCE_ATTACK:
			continue
		var depleted := frontline_strength == 0 or strength < 8 or (ammunition_capacity > 0 and ammunition < ammunition_capacity * 0.15)
		if resupply != null and (organization < 35.0 or frontline_organization < 35.0 or depleted or observed_threat > supported_strength * retreat_ratio):
			result.append(_order(snapshot, commander, GrowthCommanderCommand.Action.RECOVER, resupply.region_id, resupply.position))
			continue
		if commander.intent_mode != CommanderState.IntentMode.AUTONOMOUS:
			continue
		# Strategic intent lasts until accomplished, never permanently disables AI.
		if not commander.autonomous_growth:
			var ordered := snapshot.get_strategic_region(commander.target_region_id)
			if ordered != null and (ordered.controller_faction_id != commander.faction_id or ordered.contested): continue
			if center.distance_to(commander.target_position) > 600.0 or snapshot.tick - commander.last_growth_order_tick < 100: continue
			if (commander.formation_mode == CommanderState.FormationMode.FREE or commander.deployment_goal == commander.target_position) and not _deployment_arrived(snapshot, commander): continue
		if commander.strategic_lane_id == &"mobile":
			var reserve := _reserve_target(snapshot, center)
			if reserve != null and (commander.target_position.distance_to(reserve.position) > 64.0 or commander.target_region_id != reserve.region_id):
				result.append(_order(snapshot, commander, GrowthCommanderCommand.Action.DEFEND_SUPPLY, reserve.region_id, reserve.position))
			continue
		var threatened := _threatened_supply(snapshot, center, supported_strength)
		if threatened != null:
			if commander.target_region_id != threatened.region_id:
				result.append(_order(snapshot, commander, GrowthCommanderCommand.Action.DEFEND_SUPPLY, threatened.region_id, threatened.position))
			continue
		var target := snapshot.get_strategic_region(commander.target_region_id)
		if target != null and (target.controller_faction_id != commander.faction_id or target.contested):
			continue
		# A capture by the vanguard is not permission to leave artillery far behind.
		if target != null and center.distance_to(target.position) > 1300.0:
			continue
		var next := _next_objective(snapshot, battle, commander, center)
		if next != null and next.region_id != commander.target_region_id:
			result.append(_order(snapshot, commander, GrowthCommanderCommand.Action.ADVANCE, next.region_id, next.position))
	return result

func _deployment_arrived(snapshot: WorldSnapshot, commander: CommanderSnapshot) -> bool:
	# A nearby centroid is not arrival: it can hide a trailing card or a hero
	# still travelling around terrain. Use only our own physical progress.
	var record := commander.legion_formation
	if commander.formation_mode != CommanderState.FormationMode.FREE and (record == null or record.spatial.goal != commander.deployment_goal or record.spatial.anchor.distance_to(commander.deployment_goal) > 6.0 or record.reason != &"IN_POSITION"):
		return false
	for id in commander.subordinate_unit_card_ids:
		var card := snapshot.get_unit_card(id)
		if card == null or card.current_strength <= 0 or card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED or card.is_player_overridden: continue
		var formation := snapshot.get_formation(card.formation_id)
		if formation == null or formation.is_moving or (commander.formation_mode != CommanderState.FormationMode.FREE and formation.order_destination != commander.deployment_goal):
			return false
	return true

func _order(snapshot: WorldSnapshot, commander: CommanderSnapshot, action: GrowthCommanderCommand.Action, region: StringName, position: Vector2) -> GrowthCommanderCommand:
	var command := GrowthCommanderCommand.new(0, commander.faction_id, snapshot.tick, commander.definition_id, action, region, position)
	command.agent_id = commander.agent_id
	return command

func _next_objective(snapshot: WorldSnapshot, battle: BattleDefinition, commander: CommanderSnapshot, center: Vector2) -> StrategicRegionSnapshot:
	if commander.strategic_lane_id == &"jungle":
		var best: StrategicRegionSnapshot
		var best_score := INF
		for point in battle.map_definition.supply_points:
			var region := snapshot.get_strategic_region(point.point_id)
			if not point.is_wild or region.controller_faction_id == commander.faction_id:
				continue
			var distance := center.distance_to(point.position)
			if distance < best_score:
				best = region
				best_score = distance
		if best != null:
			return best
	for lane in battle.map_definition.lanes:
		if lane.lane_id != commander.strategic_lane_id and not (commander.strategic_lane_id == &"jungle" and lane.lane_id == &"mid"):
			continue
		var nodes := lane.supply_point_ids.duplicate()
		if commander.faction_id == 2:
			nodes.reverse()
		for id in nodes:
			var region := snapshot.get_strategic_region(id)
			if region != null and region.controller_faction_id != commander.faction_id:
				return region
	return null

func _nearest_safe_supply(snapshot: WorldSnapshot, center: Vector2) -> StrategicRegionSnapshot:
	var best: StrategicRegionSnapshot
	var best_distance := INF
	for region in snapshot.strategic_regions:
		if region.controller_faction_id != snapshot.observer_faction_id or region.contested:
			continue
		var danger := false
		for hostile in snapshot.units:
			if hostile.enabled and not hostile.legion_returning and hostile.faction_id != snapshot.observer_faction_id and hostile.is_visible_to_local_player and hostile.position.distance_to(region.position) < 1400.0:
				danger = true
		var distance := center.distance_to(region.position)
		if not danger and distance < best_distance:
			best = region
			best_distance = distance
	return best

func _threatened_supply(snapshot: WorldSnapshot, center: Vector2, strength: int) -> StrategicRegionSnapshot:
	for region in snapshot.strategic_regions:
		if region.controller_faction_id != snapshot.observer_faction_id or center.distance_to(region.position) > 5000.0:
			continue
		var threats := 0
		for hostile in snapshot.units:
			if hostile.enabled and not hostile.legion_returning and hostile.is_visible_to_local_player and hostile.faction_id != snapshot.observer_faction_id and hostile.position.distance_to(region.position) < 1200.0:
				threats += 1
		if threats > 0 and threats <= strength:
			return region
	return null

func _reserve_target(snapshot: WorldSnapshot, center: Vector2) -> StrategicRegionSnapshot:
	var prefix := "blue" if snapshot.observer_faction_id == 1 else "red"
	var best: StrategicRegionSnapshot = snapshot.get_strategic_region(StringName(prefix + "_mid_high"))
	var score := -INF
	for suffix in ["base", "top_high", "mid_high", "bottom_high"]:
		var high := snapshot.get_strategic_region(StringName(prefix + "_" + suffix))
		if high == null: continue
		for hostile in snapshot.units:
			if hostile.legion_returning or not hostile.enabled or not hostile.is_visible_to_local_player or hostile.faction_id == snapshot.observer_faction_id or hostile.position.distance_to(high.position) > 2600.0: continue
			var value := (100000.0 if suffix == "base" else 10000.0) - center.distance_to(hostile.position)
			if value > score:
				score = value
				# Fixed public objectives do not reset preparation as contacts move.
				best = high
	return best
