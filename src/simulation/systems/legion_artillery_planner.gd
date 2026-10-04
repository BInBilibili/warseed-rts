class_name LegionArtilleryPlanner
extends RefCounted

const PolicyType = preload("res://src/data/legion_artillery_policy.gd")
const StateType = preload("res://src/simulation/entities/legion_artillery_state.gd")

# Observation only. A relocation candidate is never an authorized movement order.
static func observe(snapshot: WorldSnapshot, commander: CommanderSnapshot, policy: PolicyType, previous: StateType, target_entity_id: int, validated_site_entity_ids: PackedInt32Array, authorized_entities: PackedInt32Array = PackedInt32Array(), restrict_authority: bool = false) -> StateType:
	var result := StateType.new()
	if snapshot == null or commander == null or policy == null or not policy.validation_errors().is_empty():
		result.reason = &"INVALID_INPUT"
		return result
	if snapshot.is_true_state or snapshot.knowledge == null or snapshot.knowledge.faction_id != snapshot.observer_faction_id or snapshot.observer_faction_id != commander.faction_id or snapshot.get_commander(commander.definition_id) != commander or commander.profile_id != policy.profile_id:
		result.reason = &"INVALID_OBSERVER"
		return result
	var record := commander.legion_formation
	if record == null or record.batch_plan == null or not record.batch_plan.valid or record.batch_plan.commander_id != commander.definition_id or record.batch_plan.faction_id != commander.faction_id or record.batch_plan.profile_id != commander.profile_id:
		result.reason = &"NO_LEGION_PLAN"
		return result
	if commander.growth_unlocked_slots < 0 or commander.growth_unlocked_slots > 60 or commander.growth_slot_entities.size() < commander.growth_unlocked_slots:
		result.reason = &"INVALID_ROSTER"
		return result
	var hero := snapshot.get_unit(commander.hero_entity_id)
	if hero == null or hero.faction_id != commander.faction_id or not hero.enabled or hero.control_state != UnitState.ControlState.AGENT_ASSIGNED or commander.growth_recovering:
		result.phase = StateType.Phase.PREEMPTED
		result.reason = &"COMMANDER_UNAVAILABLE"
		return result
	var action := record.spatial.action
	if action == LegionSpatialState.Action.MOVE or action == LegionSpatialState.Action.RETREAT or commander.posture == CommanderState.Posture.DISENGAGE:
		result.phase = StateType.Phase.PREEMPTED
		result.reason = &"MOVEMENT_OR_RETREAT"
		return result
	var target_position := Vector2.ZERO
	var visible_target_id := 0
	var target_unit := snapshot.get_unit(target_entity_id) if target_entity_id > 0 else null
	if target_unit != null and target_unit.faction_id != commander.faction_id and target_unit.enabled and target_unit.is_visible_to_local_player and target_unit.last_seen_tick == snapshot.tick:
		visible_target_id = target_entity_id
		target_position = target_unit.position
	else:
		var target_building := snapshot.get_building(target_entity_id) if target_entity_id > 0 else null
		if target_building != null and target_building.faction_id != commander.faction_id and target_building.enabled and target_building.is_visible and target_building.last_seen_tick == snapshot.tick:
			visible_target_id = target_entity_id
			target_position = target_building.position
	var continuing := previous != null and previous.commander_id == commander.definition_id and previous.profile_id == commander.profile_id and previous.faction_id == commander.faction_id and previous.hero_entity_id == commander.hero_entity_id and previous.navigation_map_id == snapshot.navigation_map_id and previous.batch_epoch == record.batch_plan.epoch and previous.observed_tick == snapshot.tick - 1
	if continuing: result = previous.duplicate_value()
	var target_changed := result.target_entity_id != visible_target_id
	result.commander_id = commander.definition_id
	result.profile_id = commander.profile_id
	result.faction_id = commander.faction_id
	result.hero_entity_id = commander.hero_entity_id
	result.navigation_map_id = snapshot.navigation_map_id
	result.batch_epoch = record.batch_plan.epoch
	result.observed_tick = snapshot.tick
	result.target_entity_id = visible_target_id
	result.suggested_identity = -1
	result.suggestion_requires_validation = false
	result.groups.clear()
	result.actionable = 0
	result.positioned = 0
	result.prepared = 0
	result.fire_ready = false
	result.phase = StateType.Phase.IDLE
	if target_changed:
		result.legal_since_by_identity.clear()
		result.first_observation_tick = -1
		result.no_site_since_tick = -1
		result.last_relocation_tick = -1
	var identities: Array[int] = []
	var members_by_identity: Dictionary[int,LegionBatchPlanner.Member] = {}
	for member in record.batch_plan.members:
		if member.role != 3: continue
		if member.identity < 0 or member.identity >= 60 or members_by_identity.has(member.identity):
			result.reason = &"INVALID_ROSTER"
			return result
		if member.identity >= commander.growth_unlocked_slots: continue
		identities.append(member.identity)
		members_by_identity[member.identity] = member
	identities.sort()
	var group_a := StateType.Group.new()
	group_a.group_id = &"A"
	var group_b := StateType.Group.new()
	group_b.group_id = &"B"
	var active_identities: Dictionary[int,bool] = {}
	var seen_entities: Dictionary[int,bool] = {}
	for ordinal in range(identities.size()):
		var identity := identities[ordinal]
		var group := group_a if ordinal % 2 == 0 else group_b
		group.identities.append(identity)
		var entity_id := commander.growth_slot_entities[identity]
		var member := members_by_identity[identity]
		if restrict_authority and not authorized_entities.has(entity_id):
			_clear_identity_history(result,identity)
			continue
		var unit := snapshot.get_unit(entity_id) if entity_id > 0 and member.entity_id == entity_id and not seen_entities.has(entity_id) else null
		if unit == null or unit.faction_id != commander.faction_id or unit.tactical_role != UnitState.TacticalRole.FIREPOWER or not unit.enabled or unit.legion_returning or unit.rejoin_pending or unit.control_state != UnitState.ControlState.AGENT_ASSIGNED or not commander.subordinate_unit_card_ids.has(unit.unit_card_id):
			_clear_identity_history(result, identity)
			continue
		seen_entities[entity_id] = true
		active_identities[identity] = true
		group.actionable += 1
		result.actionable += 1
		if result.entity_by_identity.get(identity, 0) != entity_id:
			_clear_identity_history(result, identity)
		result.entity_by_identity[identity] = entity_id
		var stationary := not unit.is_moving
		if continuing and result.last_position_by_identity.has(identity) and unit.position.distance_to(result.last_position_by_identity[identity]) > 0.01:
			stationary = false
		result.last_position_by_identity[identity] = unit.position
		if not stationary:
			result.stationary_since_by_identity.erase(identity)
			result.legal_since_by_identity.erase(identity)
		elif not result.stationary_since_by_identity.has(identity):
			result.stationary_since_by_identity[identity] = snapshot.tick
		var weapon_available := unit.can_attack and not unit.using_fallback_weapon and (unit.ammunition_capacity == 0 or unit.ammunition > 0)
		if visible_target_id == 0:
			if stationary and validated_site_entity_ids.has(entity_id) and snapshot.tick - result.stationary_since_by_identity[identity] >= policy.preparation_ticks and unit.deployment_progress >= 0.999:
				group.prepared += 1
				result.prepared += 1
			continue
		var distance := unit.position.distance_to(target_position)
		var in_weapon_range := distance <= unit.attack_range and distance >= unit.minimum_attack_range and unit.can_attack
		var positioned := stationary and in_weapon_range and validated_site_entity_ids.has(entity_id)
		if not positioned:
			result.legal_since_by_identity.erase(identity)
			continue
		group.positioned += 1
		result.positioned += 1
		if not result.legal_since_by_identity.has(identity): result.legal_since_by_identity[identity] = snapshot.tick
		if weapon_available and snapshot.tick - result.legal_since_by_identity[identity] >= policy.preparation_ticks and unit.deployment_progress >= 0.999:
			group.prepared += 1
			result.prepared += 1
	for identity in result.entity_by_identity.keys():
		if not active_identities.has(identity): _clear_identity_history(result, identity)
	result.groups.append(group_a)
	result.groups.append(group_b)
	result.required_for_full = ceili(result.actionable * policy.full_fraction)
	if result.actionable == 0:
		result.phase = StateType.Phase.IDLE
		result.reason = &"NO_ACTIONABLE_ARTILLERY"
		return result
	if visible_target_id == 0:
		result.legal_since_by_identity.clear()
		result.first_observation_tick = -1
		result.no_site_since_tick = -1
		result.phase = StateType.Phase.DEPLOYED if result.prepared > 0 else StateType.Phase.ASSEMBLING
		result.reason = &"DEPLOYED_NO_VISIBLE_TARGET" if result.prepared > 0 else &"NO_VISIBLE_TARGET"
		return result
	if result.first_observation_tick < 0: result.first_observation_tick = snapshot.tick
	if result.positioned > 0:
		result.no_site_since_tick = -1
	else:
		if result.no_site_since_tick < 0: result.no_site_since_tick = snapshot.tick
	if result.prepared >= result.required_for_full:
		result.phase = StateType.Phase.FULL
		result.reason = &"ARTILLERY_FULL"
	elif result.prepared > 0 and snapshot.tick - result.first_observation_tick >= policy.partial_after_ticks:
		result.phase = StateType.Phase.PARTIAL
		result.reason = &"ARTILLERY_PARTIAL"
	elif result.no_site_since_tick >= 0 and snapshot.tick - result.no_site_since_tick >= policy.no_site_timeout_ticks:
		result.phase = StateType.Phase.BLOCKED
		result.reason = &"ARTILLERY_NO_SITE_TIMEOUT"
	else:
		result.phase = StateType.Phase.DEPLOYING if result.positioned > 0 else StateType.Phase.ASSEMBLING
		result.reason = &"ARTILLERY_PREPARING" if result.positioned > 0 else &"ARTILLERY_NO_SITE"
	result.fire_ready = result.phase == StateType.Phase.FULL or result.phase == StateType.Phase.PARTIAL
	if result.positioned == 0 and result.phase != StateType.Phase.BLOCKED and (result.last_relocation_tick < 0 or snapshot.tick - result.last_relocation_tick >= policy.relocation_interval_ticks):
		_suggest_bounded_relocation(result, snapshot, commander, target_position, policy)
	return result

static func _clear_identity_history(result: StateType, identity: int) -> void:
	result.stationary_since_by_identity.erase(identity)
	result.legal_since_by_identity.erase(identity)
	result.entity_by_identity.erase(identity)
	result.last_position_by_identity.erase(identity)

static func _suggest_bounded_relocation(result: StateType, snapshot: WorldSnapshot, commander: CommanderSnapshot, target_position: Vector2, policy: PolicyType) -> void:
	for group in result.groups:
		for identity in group.identities:
			var entity_id := commander.growth_slot_entities[identity]
			if result.entity_by_identity.get(identity, 0) != entity_id: continue
			var unit := snapshot.get_unit(entity_id)
			if unit == null: continue
			var away := (unit.position - target_position).normalized()
			if away.is_zero_approx(): continue
			var desired_range := minf(policy.preferred_range_max, unit.attack_range)
			if desired_range < policy.preferred_range_min: desired_range = unit.attack_range
			var radial := target_position + away * desired_range - unit.position
			var tangent := Vector2(-away.y, away.x) * (1.0 if group.group_id == &"A" else -1.0)
			var bounded := (radial.limit_length(policy.maximum_relocation_step) + tangent * policy.maximum_lateral_step).limit_length(policy.maximum_relocation_step)
			result.suggested_identity = identity
			result.suggested_position = unit.position + bounded
			result.suggestion_requires_validation = true
			result.last_relocation_tick = snapshot.tick
			return
