class_name LegionHeroSystem
extends RefCounted

const DEFINITION: UnitDefinition = preload("res://data/units/legion_hero.tres")

static func respawn_delay(tick: int) -> int:
	return (tick / 6000 + 1) * 100

static func initialize(world: SimulationWorld) -> void:
	if world.battle_definition == null or not world.battle_definition.growth_mode: return
	var ids := world.commanders.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id in ids:
		var commander := world.commanders[id] as CommanderState
		var position := _home(world, commander)
		for card_id in commander.subordinate_unit_card_ids:
			var card := world.unit_cards[card_id] as UnitCardState
			if world.formations.has(card.formation_id):
				position = world.formations[card.formation_id].anchor_position
				break
		_spawn(world, commander, position)

static func _home(world: SimulationWorld, commander: CommanderState) -> Vector2:
	var base := world.battle_definition.player_headquarters_position if commander.faction_id == 1 else world.battle_definition.enemy_headquarters_position
	var direction := Vector2(1, -1) if commander.faction_id == 1 else Vector2(-1, 1)
	return base + direction * 320.0

static func _spawn(world: SimulationWorld, commander: CommanderState, position: Vector2) -> void:
	position=world.find_legion_birth_position(position,commander.faction_id)
	var id := world._next_unit_id
	world._next_unit_id += 1
	var hero := UnitState.new(id, position, DEFINITION.move_speed, commander.faction_id)
	world._apply_unit_definition(hero, DEFINITION)
	hero.attack_cooldown_ticks = 6
	var template := LegionTemplate.find(commander.definition.profile.profile_id)
	if template != null:
		hero.max_health = template.hero_health
		hero.health = template.hero_health
		hero.base_armor = template.hero_armor
		hero.armor = template.hero_armor
		hero.base_move_speed = template.hero_speed
		hero.move_speed = template.hero_speed
		hero.base_attack_damage = template.hero_damage
		hero.attack_damage = template.hero_damage
		hero.base_attack_range = template.hero_range
		hero.attack_range = template.hero_range
		hero.attack_cooldown_ticks = template.hero_cooldown
		hero.primary_cooldown_ticks = template.hero_cooldown
		hero.base_sight_range = template.hero_sight
		hero.sight_range = template.hero_sight
	hero.hero_commander_id = commander.definition.definition_id
	hero.hero_lane_id = commander.definition.strategic_lane_id
	hero.control_state = UnitState.ControlState.AGENT_ASSIGNED
	hero.assigned_agent_id = commander.agent_id
	world.units[id] = hero
	commander.hero_entity_id = id
	commander.hero_respawn_tick = -1
	world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.TASK_STATE_CHANGED, id, "HERO_READY;commander=%s" % commander.definition.definition_id))

static func command_blocked(world: SimulationWorld, command: GameCommand) -> bool:
	if world.battle_definition == null or not world.battle_definition.growth_mode: return false
	if command is StrategicOrderCommand:
		if _members_locked(world, command.participant_entity_ids, command.issuer_id): return true
		var formation := world.formations.get(command.formation_id) as FormationState
		if formation != null and _members_locked(world, formation.member_entity_ids, command.issuer_id): return true
	if command is FormationMoveCommand or command is AttackCommand or command is AttackMoveCommand or command is StopCommand:
		var formation := world.formations.get(command.formation_id) as FormationState
		if formation != null and _members_locked(world, formation.member_entity_ids, command.issuer_id): return true
	if command is UnitDispositionCommand:
		var destination := world.formations.get(command.destination_formation_id) as FormationState
		if destination != null and _members_locked(world, destination.member_entity_ids, command.issuer_id): return true
	if command is TaskControlCommand:
		var task := world.tasks.get(command.controlled_task_id) as TaskState
		if task != null and _members_locked(world, task.participant_entity_ids, command.issuer_id): return true
	var commander_id: StringName
	var card_id: StringName
	if command is CommanderOrderCommand or command is GrowthCommanderCommand or command is EquipDoctrineCommand:
		commander_id = command.commander_id
	elif command is UnitCardControlCommand or command is RecruitUnitCardCommand or command is TacticalAbilityCommand or command is SupportOrderCommand:
		card_id = command.unit_card_id
	elif command is CommanderCardTaskCommand:
		card_id = command.target_card_id
	elif command is StaffPlanApprovalCommand and command.request != null:
		for id in command.request.allowed_card_ids:
			var card := world.unit_cards.get(id) as UnitCardState
			if card != null and _locked(world, card.commander_definition_id, command.issuer_id): return true
	var source_is_unit := command is MoveCommand or command is FormationMoveCommand or command is AttackCommand or command is AttackMoveCommand or command is StopCommand or command is UnitDispositionCommand or command is HarvestCommand or command is BuildBuildingCommand or command is RepairBuildingCommand
	var unit := world.units.get(command.target_entity_id) as UnitState if source_is_unit else null
	if unit != null:
		if unit.faction_id != command.issuer_id: return false
		if unit.legion_returning: return true
		if not unit.hero_commander_id.is_empty(): commander_id = unit.hero_commander_id
		else: card_id = unit.unit_card_id
	if not card_id.is_empty():
		var card := world.unit_cards.get(card_id) as UnitCardState
		if card != null: commander_id = card.commander_definition_id
	if command.issuer_kind == GameCommand.IssuerKind.AGENT:
		for owner: CommanderState in world.commanders.values():
			if owner.faction_id == command.issuer_id and owner.agent_id == command.agent_id and owner.legion_regrouping: return true
	return _locked(world, commander_id, command.issuer_id)

static func _members_locked(world: SimulationWorld, ids: Array[int], faction: int) -> bool:
	for id in ids:
		var unit := world.units.get(id) as UnitState
		if unit != null and unit.faction_id == faction and (unit.legion_returning or _locked(world, unit.hero_commander_id, faction)): return true
	return false

static func _locked(world: SimulationWorld, id: StringName, faction: int) -> bool:
	var commander := world.commanders.get(id) as CommanderState
	return commander != null and commander.faction_id == faction and commander.legion_regrouping

static func advance(world: SimulationWorld, move_heroes: bool = false) -> void:
	if world.battle_definition == null or not world.battle_definition.growth_mode: return
	var ids := world.commanders.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id in ids:
		var commander := world.commanders[id] as CommanderState
		var hero := world.units.get(commander.hero_entity_id) as UnitState
		if (hero == null or not hero.enabled) and commander.hero_respawn_tick < 0:
			_begin_return(world, commander)
		if commander.hero_respawn_tick >= 0 and world.current_tick >= commander.hero_respawn_tick:
			_spawn(world, commander, _home(world, commander))
			hero = world.units[commander.hero_entity_id]
		if commander.legion_regrouping:
			_returning(world, commander, hero)
		# Growth-mode movement belongs exclusively to LegionFormationSystem.
		# Death, recall and respawn above remain the lifecycle authority.

static func _begin_return(world: SimulationWorld, commander: CommanderState) -> void:
	commander.hero_respawn_tick = world.current_tick + respawn_delay(world.current_tick)
	commander.legion_regrouping = true
	commander.authority_version += 1
	commander.intent_mode = CommanderState.IntentMode.AUTONOMOUS
	commander.intent_receipt = CommanderState.IntentReceipt.INTERRUPTED
	commander.player_route.clear()
	commander.player_target_region_id = &""
	commander.formation_mode = CommanderState.FormationMode.FREE
	commander.deployment_goal=Vector2(INF,INF); commander.deployment_facing=Vector2.ZERO
	commander.growth_recovering = false
	commander.autonomous_growth = true
	commander.legion_execution_authority = CommanderState.LegionExecutionAuthority.AUTONOMOUS
	world.commander_task_graph_system.cancel_commander(world, commander.definition.definition_id)
	world._cancel_commander_intent(commander)
	for task: TaskState in world.tasks.values():
		if commander.subordinate_unit_card_ids.has(task.unit_card_id) and task.lifecycle not in [TaskState.Lifecycle.COMPLETED, TaskState.Lifecycle.FAILED, TaskState.Lifecycle.CANCELLED]:
			task.set_lifecycle(TaskState.Lifecycle.CANCELLED, world.current_tick, TaskState.BlockedReason.NONE, "Commander lost")
			task.set_phase(TaskState.Phase.DONE, world.current_tick)
	commander.target_position = _home(world, commander)
	commander.target_region_id = &"blue_base" if commander.faction_id == 1 else &"red_base"
	commander.planned_route = PackedVector2Array()
	var return_routes: Array[PackedVector2Array] = []
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		LegionControlHandoff.cancel_current(world,card)
		card.authority_version += 1
		card.tactical_command = null
		card.persistent_manual = false
		card.temporary_micro = false
		card.return_task_id = 0
		card.return_formation_id = 0
		card.takeover_reason = ""
		card.assigned_task_id = 0
		card.control_state = UnitCardState.ControlState.RETURNING
		var formation := world.formations.get(card.formation_id) as FormationState
		if formation != null:
			GrowthCombatSystem.clear_formation_response(formation)
			formation.is_moving = false
		for entity_id in card.member_entity_ids:
			var unit := world.units.get(entity_id) as UnitState
			if unit == null or not unit.enabled: continue
			unit.legion_returning = true
			if unit.reformation!=null and unit.reformation.phase==LegionReformationState.Phase.REFORMING:
				unit.reformation.end(world.current_tick,LegionReformationSystem.overlapped(unit,world.units),LegionReformationSystem.policy,&"REFORMATION_CANCELLED")
			unit.following_formation = false
			unit.assigned_task_id = 0
			unit.attack_target_entity_id = 0
			unit.local_engagement_active = false
			unit.local_engagement_returning = false
			unit.is_attack_moving = false
			unit.rejoin_pending = false
			unit.return_task_id = 0
			unit.rejoin_formation_id = 0
			unit.takeover_reason = ""
			_start_return_path(world, unit, commander.target_position, return_routes)
	world.command_queue.remove_if(func(command: GameCommand) -> bool: return command_blocked(world, command) or command.issuer_kind == GameCommand.IssuerKind.AGENT and command.agent_id == commander.agent_id)
	world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.TASK_STATE_CHANGED, commander.hero_entity_id, "HERO_DOWN;commander=%s;respawn=%d" % [commander.definition.definition_id, commander.hero_respawn_tick]))

static func _start_return_path(world: SimulationWorld, unit: UnitState, home: Vector2, routes: Array[PackedVector2Array]) -> void:
	# Nearby survivors can join an already validated corridor. Routes live only
	# for this synchronous recall, so dynamic obstacles cannot stale this cache.
	for route in routes:
		if route.size() < 2: continue
		var join := Geometry2D.get_closest_point_to_segment(unit.position, route[0], route[1])
		if unit.position.distance_squared_to(join) > 256.0 * 256.0: continue
		if not world.logic_grid.is_segment_walkable(unit.position, join): continue
		if not world.logic_grid.is_segment_walkable(join, route[1]): continue
		var path := PackedVector2Array([unit.position])
		if unit.position != join: path.append(join)
		for index in range(1, route.size()):
			if path[-1] != route[index]: path.append(route[index])
		unit.path = path
		unit.path_index = 1
		unit.move_target = home
		unit.desired_position = home
		unit.has_move_target = path.size() > 1
		RuntimeMeasurement.count("navigation.regroup_shared")
		return
	world._start_unit_path(unit, home)
	if unit.path.size() > 1: routes.append(unit.path.duplicate())
	RuntimeMeasurement.count("navigation.regroup_solved")

static func _returning(world: SimulationWorld, commander: CommanderState, hero: UnitState) -> void:
	var arrived := true
	var home := _home(world, commander)
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		for entity_id in card.member_entity_ids:
			var unit := world.units.get(entity_id) as UnitState
			if unit == null or not unit.enabled: continue
			unit.attack_target_entity_id = 0
			if unit.position.distance_to(home) > 160.0:
				arrived = false
				if not unit.has_move_target and world.current_tick % 20 == 0: world._start_unit_path(unit, home)
	if not arrived or hero == null or not hero.enabled: return
	commander.legion_regrouping = false
	commander.posture = CommanderState.Posture.BALANCED
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		card.control_state = UnitCardState.ControlState.AGENT_ASSIGNED
		card.assigned_agent_id = commander.agent_id
		var formation := world.formations.get(card.formation_id) as FormationState
		if formation != null:
			formation.anchor_position = home
			formation.target_position = home
			formation.order_kind = FormationState.OrderKind.IDLE
		for entity_id in card.member_entity_ids:
			var unit := world.units.get(entity_id) as UnitState
			if unit == null or not unit.enabled: continue
			unit.legion_returning = false
			unit.following_formation = formation != null
			unit.has_move_target = false
			unit.control_state = UnitState.ControlState.AGENT_ASSIGNED
	world._assign_commander_objective(commander, home, commander.target_region_id)
	world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.TASK_STATE_CHANGED, hero.entity_id, "LEGION_REASSEMBLED;commander=%s" % commander.definition.definition_id))

static func _follow(world: SimulationWorld, commander: CommanderState, hero: UnitState) -> void:
	if commander.posture == CommanderState.Posture.HOLD:
		hero.has_move_target = false
		hero.local_engagement_active = false
		hero.local_engagement_returning = false
		return
	var candidates := _follow_candidates(world, commander)
	if candidates.is_empty(): candidates.append(commander.target_position)
	var current_path_valid := hero.has_move_target and hero.path_index < hero.path.size()
	var start := hero.position
	for index in range(hero.path_index, hero.path.size()):
		current_path_valid = current_path_valid and world.logic_grid.is_segment_walkable(start,hero.path[index])
		start = hero.path[index]
	# Only actual friendly positions are destinations. A centroid can be inside
	# a cliff/river or between distant recruits and the marching main body.
	var tried := {}
	for target in candidates:
		var cell := world.logic_grid.world_to_cell(target)
		if tried.has(cell): continue
		tried[cell] = true
		if tried.size() > 8: break
		if hero.position.distance_to(target) <= 96.0 and world.logic_grid.is_segment_walkable(hero.position,target):
			hero.has_move_target = false
			hero.path = PackedVector2Array()
			hero.path_index = 0
			hero.local_engagement_active = false
			hero.local_engagement_returning = false
			return
		if current_path_valid and hero.move_target.distance_to(target) <= 96.0: return
		var path := world.pathfinder.find_body_path(hero.position,target)
		if path.size() < 2: continue
		hero.local_engagement_active = false
		hero.local_engagement_returning = false
		hero.move_target = target
		hero.desired_position = target
		hero.path = path
		hero.path_index = 1
		hero.has_move_target = true
		return
	# Keep a valid previous route while retrying the moving group next second.
	# Invalid routes must not walk through newly occupied terrain.
	if not current_path_valid:
		hero.has_move_target = false
		hero.path = PackedVector2Array()
		hero.path_index = 0
	if world.current_tick % 20 == 0:
		world.events.append(SimulationEvent.new(world.current_tick,SimulationEvent.Kind.UNIT_STUCK,hero.entity_id,"HERO_FOLLOW_UNREACHABLE"))

static func _follow_candidates(world: SimulationWorld, commander: CommanderState) -> PackedVector2Array:
	var main: Array[UnitState] = []
	var scouts: Array[UnitState] = []
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		for id in card.member_entity_ids:
			var unit := world.units.get(id) as UnitState
			if unit == null or not unit.enabled or unit.legion_returning: continue
			if card.definition.role_key == &"UNIT_CARD_ROLE_RECON": scouts.append(unit)
			else: main.append(unit)
	if main.is_empty(): main = scouts
	var total := Vector2.ZERO
	for unit in main: total += unit.position
	var center := total / maxi(main.size(),1)
	var neighbours := {}
	for unit in main:
		var count := 0
		for other in main:
			if unit.position.distance_squared_to(other.position) <= 640.0 * 640.0: count += 1
		neighbours[unit.entity_id] = count
	main.sort_custom(func(a: UnitState, b: UnitState) -> bool:
		if neighbours[a.entity_id] != neighbours[b.entity_id]: return neighbours[a.entity_id] > neighbours[b.entity_id]
		var first := a.position.distance_squared_to(center)
		var second := b.position.distance_squared_to(center)
		return first < second or (first == second and a.entity_id < b.entity_id))
	var result := PackedVector2Array()
	for unit in main: result.append(unit.position)
	return result
