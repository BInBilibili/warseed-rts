class_name GrowthCombatSystem
extends RefCounted

# Authority-side weapon reactions. Strategic agents only submit fire focus;
# movement ownership, local pursuit and return are resolved here at 10 Hz.
const LEASH := 256.0
const CHASE_TICKS := 30
const SUPPORT_RADIUS := 640.0

static func validate_focus(world: SimulationWorld, command: AttackCommand) -> CommandValidationResult:
	if world.battle_definition == null or not world.battle_definition.growth_mode or command.formation_id == 0:
		return _reject(CommandValidationResult.Reason.INVALID_TARGET)
	var card := world._unit_card_for_formation(command.formation_id)
	var commander := world.commanders.get(card.commander_definition_id) as CommanderState if card != null else null
	if card == null or commander == null or card.faction_id != command.issuer_id:
		return _reject(CommandValidationResult.Reason.NOT_CONTROLLER)
	if command.issuer_kind == GameCommand.IssuerKind.AGENT and (command.agent_id != commander.agent_id or not world._agent_authorization_allows(command)):
		return _reject(CommandValidationResult.Reason.AGENT_NOT_AUTHORIZED)
	var probe := AttackCommand.new(command.command_id, command.issuer_id, GameCommand.IssuerKind.PLAYER, command.issued_tick, command.target_entity_id, command.attack_target_entity_id, command.formation_id)
	return world.command_validator.validate(probe, world.units, world._battlefield_bounds(), world.pathfinder, world.formations, world.buildings, world.ore_fields, world.factions, world.UNIT_CATALOG, world.BUILDING_CATALOG, world.faction_knowledge, world.logic_grid)

static func _reject(reason: CommandValidationResult.Reason) -> CommandValidationResult:
	return CommandValidationResult.new(CommandValidationResult.Status.REJECTED, reason)

static func propose_focus(world: SimulationWorld) -> void:
	if world.current_tick % 5 != 0: return
	var ids := world.commanders.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id in ids:
		var commander := world.commanders[id] as CommanderState
		if commander.legion_regrouping or commander.posture == CommanderState.Posture.DISENGAGE or commander.growth_recovering: continue
		var cards: Array[UnitCardState] = []
		for card_id in commander.subordinate_unit_card_ids:
			var card := world.unit_cards.get(card_id) as UnitCardState
			if card != null and card.deployment_state == UnitCardState.DeploymentState.DEPLOYED and world.formations.has(card.formation_id): cards.append(card)
		# No focus command can be applied when every visible contact is outside
		# every participating anchor's support radius. Avoid scoring that no-op.
		var knowledge := world.faction_knowledge.get(commander.faction_id) as FactionKnowledge
		var can_submit := false
		if knowledge != null:
			var contacts := knowledge.visible_hostile_unit_ids.duplicate()
			contacts.append_array(knowledge.visible_hostile_building_ids)
			for card in cards:
				var anchor: Vector2 = world.formations[card.formation_id].anchor_position
				for contact in contacts:
					if anchor.distance_squared_to(world.get_entity_position(contact)) <= world.COMMANDER_SUPPORT_DISTANCE * world.COMMANDER_SUPPORT_DISTANCE:
						can_submit = true
						break
				if can_submit: break
		if not can_submit: continue
		var focus_cards := cards.duplicate()
		for shared_id in world.commander_task_graph_system.cooperation_cards(id):
			var shared := world.unit_cards.get(shared_id) as UnitCardState
			if shared != null and shared.faction_id == commander.faction_id and shared.deployment_state == UnitCardState.DeploymentState.DEPLOYED and not focus_cards.has(shared): focus_cards.append(shared)
		# Maintain an effective volley until its target dies/leaves contact. This
		# prevents expensive rescoring and indecisive target switching every 0.5s.
		var target := 0
		for card in focus_cards:
			var formation := world.formations.get(card.formation_id) as FormationState
			if formation == null: continue
			var retained := formation.fire_focus_id
			if retained != 0 and world.is_entity_enabled(retained) and world.get_entity_faction_id(retained) != commander.faction_id and world.is_entity_visible_to_faction(retained, commander.faction_id) and world._formation_has_target_in_weapon_range(formation, retained):
				target = retained
				break
		if target == 0: target = world._select_commander_focus_target(focus_cards, commander.faction_id)
		if target == 0: continue
		for card in cards:
			var formation := world.formations[card.formation_id] as FormationState
			if formation.anchor_position.distance_to(world.get_entity_position(target)) > world.COMMANDER_SUPPORT_DISTANCE: continue
			var command := AttackCommand.new(world.allocate_command_id(), commander.faction_id, GameCommand.IssuerKind.AGENT, world.current_tick, formation.leader_entity_id, target, formation.formation_id)
			command.fire_only = true
			command.agent_id = commander.agent_id
			world.submit_command(command)

static func has_support(world: SimulationWorld, formation: FormationState) -> bool:
	var leader := world.units.get(formation.leader_entity_id) as UnitState
	if leader == null: return false
	for other: UnitState in world.units.values():
		if other.enabled and other.faction_id == leader.faction_id and other.can_attack and other.tactical_role in [UnitState.TacticalRole.ASSAULT, UnitState.TacticalRole.ARMOR] and other.position.distance_to(formation.anchor_position) <= SUPPORT_RADIUS:
			return true
	return false

static func valid_target(world: SimulationWorld, unit: UnitState, id: int, require_range: bool = true) -> bool:
	if id == 0 or not world.is_entity_enabled(id) or world.get_entity_faction_id(id) == unit.faction_id or not world.is_entity_visible_to_faction(id, unit.faction_id): return false
	var hostile := world.units.get(id) as UnitState
	var tag := hostile.target_tag if hostile != null else TacticalWeaponDefinition.TargetTag.STRUCTURE
	if not unit.allowed_target_tags.is_empty() and not unit.allowed_target_tags.has(tag): return false
	var distance := unit.position.distance_to(world.get_entity_position(id))
	return not require_range or distance <= unit.attack_range and distance >= unit.minimum_attack_range

const TARGET_BUCKET_SIZE := 256.0

static func _visible_target_buckets(world: SimulationWorld) -> Dictionary:
	# Tick-local broad phase: only legal visible contacts, never hidden truth.
	var result: Dictionary = {}
	for faction in world.faction_knowledge:
		var knowledge := world.faction_knowledge[faction] as FactionKnowledge
		var buckets: Dictionary = {}
		var ids: Array[int] = []
		ids.assign(knowledge.visible_hostile_unit_ids)
		ids.append_array(knowledge.visible_hostile_building_ids)
		for id in ids:
			var cell := Vector2i((world.get_entity_position(id) / TARGET_BUCKET_SIZE).floor())
			if not buckets.has(cell): buckets[cell] = []
			buckets[cell].append(id)
		result[faction] = buckets
	return result

static func _pick(world: SimulationWorld, unit: UnitState, preferred: int, target_index: Dictionary = {}) -> int:
	if not unit.can_attack or not unit.can_accept_attack_orders or unit.ammunition_capacity > 0 and unit.ammunition <= 0 and not unit.using_fallback_weapon: return 0
	if valid_target(world, unit, preferred): return preferred
	# Retain a legal target rather than resetting preparation/focus every frame.
	if valid_target(world, unit, unit.attack_target_entity_id): return unit.attack_target_entity_id
	var knowledge := world.faction_knowledge.get(unit.faction_id) as FactionKnowledge
	if knowledge == null: return 0
	var ids: Array[int] = []
	if target_index.has(unit.faction_id):
		var buckets: Dictionary = target_index[unit.faction_id]
		var low := Vector2i(((unit.position - Vector2.ONE * unit.attack_range) / TARGET_BUCKET_SIZE).floor())
		var high := Vector2i(((unit.position + Vector2.ONE * unit.attack_range) / TARGET_BUCKET_SIZE).floor())
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				ids.append_array(buckets.get(Vector2i(x,y), []))
	else:
		ids.assign(knowledge.visible_hostile_unit_ids)
		ids.append_array(knowledge.visible_hostile_building_ids)
	# Preserve nearest-target tie breaks exactly, independent of bucket order.
	ids.sort()
	var best := 0
	var distance := INF
	for id in ids:
		var candidate := unit.position.distance_squared_to(world.get_entity_position(id))
		if candidate >= distance or candidate > unit.attack_range * unit.attack_range or candidate < unit.minimum_attack_range * unit.minimum_attack_range: continue
		if not valid_target(world, unit, id, false): continue
		if candidate < distance:
			best = id
			distance = candidate
	return best

static func advance(world: SimulationWorld) -> void:
	var target_index := _visible_target_buckets(world)
	var ids := world.formations.keys()
	ids.sort()
	for id in ids:
		var formation := world.formations[id] as FormationState
		world._prune_disabled_formation_members(formation)
		var leader := world.units.get(formation.leader_entity_id) as UnitState
		if leader == null or not leader.enabled: continue
		var card := world._unit_card_for_formation(id)
		var manual := card == null or card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED
		var task := world.tasks.get(leader.assigned_task_id) as TaskState
		var commander := world.commanders.get(card.commander_definition_id) as CommanderState if card != null else null
		var withdrawing := task != null and task.phase in [TaskState.Phase.EVADING, TaskState.Phase.RETREATING]
		withdrawing = withdrawing or commander != null and (commander.posture == CommanderState.Posture.DISENGAGE or commander.growth_recovering)
		withdrawing = withdrawing or card != null and world.commander_task_graph_system.is_retreating_card(card.definition.definition_id)
		var preferred := formation.order_target_entity_id if formation.order_kind == FormationState.OrderKind.ATTACK_TARGET else (formation.fire_focus_id if formation.fire_focus_until_tick > world.current_tick else 0)
		var firing_target := 0
		for member_id in formation.member_entity_ids:
			var unit := world.units.get(member_id) as UnitState
			if unit == null or not unit.enabled or not unit.following_formation: continue
			var previous := unit.attack_target_entity_id
			unit.attack_target_entity_id = _pick(world, unit, preferred, target_index)
			unit.attack_is_retaliation = formation.order_kind != FormationState.OrderKind.ATTACK_TARGET
			if firing_target == 0: firing_target = unit.attack_target_entity_id
			if previous != unit.attack_target_entity_id and unit.attack_target_entity_id != 0:
				world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.ATTACK_STARTED, member_id, "target=%d;local_fire=1" % unit.attack_target_entity_id))
		# A manual route always wins. Fire assignment never changes its path or slots.
		if manual and formation.order_kind == FormationState.OrderKind.MOVE and formation.is_moving: continue
		if withdrawing: continue
		if formation.order_kind == FormationState.OrderKind.ATTACK_TARGET:
			if valid_target(world, leader, preferred, false):
				if firing_target != 0: _stop(world, formation)
				else: _approach(world, formation, leader, preferred, false)
			else:
				formation.order_target_entity_id = 0
				formation.order_kind = FormationState.OrderKind.IDLE
			continue
		# Manual completion/stop allows self-defense fire, never AI pursuit.
		if manual: continue
		if formation.local_engagement_returning:
			if formation.anchor_position.distance_to(formation.local_engagement_origin) < 40.0:
				_resume(world, formation)
			else: _move(world, formation, formation.local_engagement_origin)
			continue
		# Approved coalition fire support can close a short gap to a shared,
		# visible target. It uses the same leash/return logic and never moves a
		# player's card or a withdrawing commander.
		var support_target := 0
		if not manual and commander != null and firing_target == 0 and not world.commander_task_graph_system.cooperation_cards(commander.definition.definition_id).is_empty():
			if formation.fire_focus_until_tick > world.current_tick and valid_target(world, leader, formation.fire_focus_id, false) and formation.anchor_position.distance_to(world.get_entity_position(formation.fire_focus_id)) <= leader.attack_range + LEASH:
				support_target = formation.fire_focus_id
		if not formation.local_engagement_active and (firing_target != 0 or support_target != 0):
			formation.local_engagement_active = true
			formation.local_engagement_origin = formation.anchor_position
			formation.local_engagement_resume_destination = formation.order_destination
			formation.local_engagement_resume_route = formation.planned_route.duplicate()
			formation.local_engagement_resume_path = formation.path.slice(formation.path_index)
			formation.local_engagement_resume_kind = formation.order_kind
			formation.local_engagement_until_tick = world.current_tick + CHASE_TICKS
			formation.fire_focus_id = firing_target if firing_target != 0 else support_target
		if not formation.local_engagement_active: continue
		if firing_target != 0:
			formation.fire_focus_id = firing_target
			formation.local_engagement_until_tick = world.current_tick + CHASE_TICKS
			_stop(world, formation)
		else:
			var target := formation.fire_focus_id
			if world.current_tick >= formation.local_engagement_until_tick or not valid_target(world, leader, target, false) or world.get_entity_position(target).distance_to(formation.local_engagement_origin) > leader.attack_range + LEASH:
				formation.local_engagement_returning = true
				_move(world, formation, formation.local_engagement_origin)
			else: _approach(world, formation, leader, target, true)
	var unit_ids := world.units.keys()
	unit_ids.sort()
	for id in unit_ids:
		var unit := world.units[id] as UnitState
		if unit.enabled and not unit.legion_returning and not unit.following_formation: _individual(world, unit, target_index)

static func _stop(world: SimulationWorld, formation: FormationState) -> void:
	formation.is_moving = false
	formation.engagement_state = FormationState.EngagementState.ENGAGING
	for id in formation.member_entity_ids:
		var unit := world.units.get(id) as UnitState
		if unit != null and unit.following_formation: unit.has_move_target = false

static func _move(world: SimulationWorld, formation: FormationState, destination: Vector2) -> void:
	if formation.is_moving and formation.target_position.distance_to(destination) < 32.0: return
	formation.path = world.pathfinder.find_path(formation.anchor_position, destination)
	formation.path_index = 1
	formation.target_position = destination
	formation.is_moving = formation.path.size() > 1
	formation.reset_anchor_history(destination - formation.anchor_position)
	for id in formation.member_entity_ids:
		var unit := world.units.get(id) as UnitState
		if unit != null and unit.following_formation: unit.has_move_target = formation.is_moving

static func _approach(world: SimulationWorld, formation: FormationState, unit: UnitState, target: int, limited: bool) -> void:
	var position := world.get_entity_position(target)
	var away := (formation.anchor_position - position).normalized()
	var destination := position + away * maxf(unit.minimum_attack_range + 32.0, unit.attack_range * 0.8)
	if limited:
		destination = formation.local_engagement_origin + (destination - formation.local_engagement_origin).limit_length(LEASH)
	_move(world, formation, destination)
	if limited:
		for waypoint in formation.path:
			if waypoint.distance_to(formation.local_engagement_origin) > LEASH + 16.0:
				formation.local_engagement_returning = true
				_move(world, formation, formation.local_engagement_origin)
				break

static func _resume(world: SimulationWorld, formation: FormationState) -> void:
	formation.local_engagement_active = false
	formation.local_engagement_returning = false
	formation.order_kind = formation.local_engagement_resume_kind
	formation.order_destination = formation.local_engagement_resume_destination
	formation.planned_route = formation.local_engagement_resume_route.duplicate()
	if formation.order_kind in [FormationState.OrderKind.MOVE, FormationState.OrderKind.ATTACK_MOVE]:
		# Reconnect each saved segment against current navigation. An empty
		# connector must never turn a saved route into an unchecked straight line.
		var waypoints := PackedVector2Array([formation.local_engagement_origin])
		waypoints.append_array(formation.local_engagement_resume_path)
		if formation.local_engagement_resume_path.is_empty(): waypoints.append(formation.order_destination)
		var restored := PackedVector2Array([formation.anchor_position])
		for point in waypoints:
			if restored[-1].is_equal_approx(point): continue
			var connector := world.pathfinder.find_path(restored[-1], point)
			if connector.is_empty():
				# Retain local return state too: even a card without a commander
				# retries after navigation changes; new commands still cancel it.
				formation.local_engagement_active = true
				formation.local_engagement_returning = true
				restored = PackedVector2Array()
				break
			restored.append_array(connector.slice(1))
		formation.path = restored
		formation.path_index = 1
		formation.target_position = formation.order_destination
		formation.is_moving = formation.path.size() > 1
		formation.reset_anchor_history(formation.order_destination - formation.anchor_position)
		for id in formation.member_entity_ids:
			var unit := world.units.get(id) as UnitState
			if unit != null and unit.following_formation: unit.has_move_target = formation.is_moving
	else: _stop(world, formation)

static func clear_formation_response(formation: FormationState) -> void:
	formation.local_engagement_active = false
	formation.local_engagement_returning = false
	formation.local_engagement_resume_route = PackedVector2Array()
	formation.local_engagement_resume_path = PackedVector2Array()

static func cancel_local_response(world: SimulationWorld, command: GameCommand) -> void:
	if world.battle_definition == null or not world.battle_definition.growth_mode: return
	var id: int = command.formation_id if command is FormationMoveCommand or command is AttackCommand or command is StopCommand else 0
	var formation := world.formations.get(id) as FormationState
	if formation != null:
		clear_formation_response(formation)
	var unit := world.units.get(command.target_entity_id) as UnitState
	if unit != null:
		unit.local_engagement_active = false
		unit.local_engagement_returning = false

static func _individual(world: SimulationWorld, unit: UnitState, target_index: Dictionary = {}) -> void:
	if not unit.can_attack or not unit.can_accept_attack_orders: return
	if not unit.hero_commander_id.is_empty():
		# The hero's movement belongs to legion escort, including withdrawal.
		# Local pursuit/return must not replace it with a stale solo rally point.
		unit.local_engagement_active = false
		unit.local_engagement_returning = false
		unit.attack_target_entity_id = _pick(world, unit, 0, target_index)
		unit.attack_is_retaliation = true
		return
	var previous := unit.attack_target_entity_id
	# Explicit attack orders may pursue; ordinary movement may only fire en route.
	if not unit.local_engagement_active and not unit.attack_is_retaliation and previous != 0 and valid_target(world, unit, previous, false):
		if valid_target(world, unit, previous):
			unit.has_move_target = false
		else:
			var position := world.get_entity_position(previous)
			world._start_individual_attack_path(unit, position + (unit.position-position).normalized() * maxf(unit.minimum_attack_range+32.0,unit.attack_range*0.8))
		return
	var target := _pick(world, unit, previous, target_index)
	if unit.has_move_target and not unit.local_engagement_active and not unit.is_attack_moving:
		unit.attack_target_entity_id = target
		unit.attack_is_retaliation = true
		return
	if unit.local_engagement_returning:
		unit.attack_target_entity_id = target
		if unit.position.distance_to(unit.local_engagement_origin) <= 16.0:
			unit.local_engagement_active = false
			unit.local_engagement_returning = false
			if unit.is_attack_moving: world._start_individual_attack_path(unit, unit.attack_move_destination)
		return
	if target != 0:
		if not unit.local_engagement_active: unit.local_engagement_origin = unit.position
		unit.local_engagement_active = true
		unit.local_engagement_until_tick = world.current_tick + CHASE_TICKS
		unit.attack_target_entity_id = target
		unit.attack_is_retaliation = true
		unit.has_move_target = false
	elif unit.local_engagement_active:
		var destination := unit.local_engagement_origin
		if world.current_tick < unit.local_engagement_until_tick and valid_target(world, unit, previous, false) and world.get_entity_position(previous).distance_to(unit.local_engagement_origin) <= unit.attack_range + LEASH:
			destination = world.get_entity_position(previous) + (unit.position - world.get_entity_position(previous)).normalized() * unit.attack_range * 0.8
			destination = unit.local_engagement_origin + (destination - unit.local_engagement_origin).limit_length(LEASH)
		else:
			unit.local_engagement_returning = true
			unit.attack_target_entity_id = 0
		world._start_individual_attack_path(unit, destination)
