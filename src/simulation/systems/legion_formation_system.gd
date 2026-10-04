class_name LegionFormationSystem
extends RefCounted

var records: Dictionary[StringName,LegionFormationState] = {}

func snapshot(commander_id: StringName) -> LegionFormationState:
	return records[commander_id].duplicate_value() if records.has(commander_id) else LegionFormationState.new()

func _ids(world: SimulationWorld) -> Array:
	var ids := world.commanders.keys()
	ids.sort_custom(func(a: StringName,b: StringName) -> bool: return String(a)<String(b))
	return ids

func _own(world: SimulationWorld, commander: CommanderState, filter_control: bool) -> Array[UnitSnapshot]:
	var own: Array[UnitSnapshot] = []
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards.get(card_id) as UnitCardState
		if card == null: continue
		for entity_id in card.member_entity_ids:
			var unit := world.units.get(entity_id) as UnitState
			if unit == null: continue
			var view := UnitSnapshot.new(unit)
			if filter_control and not card.uses_legion_slots():
				view.control_state = UnitState.ControlState.TEMPORARILY_OVERRIDDEN
			own.append(view)
	return own

# The four layouts are opt-in. Free movement retains physical collision and
# artillery roster metadata, but never schedules whole-legion slots or escorts.
func validate(world: SimulationWorld, command: LegionFormationCommand) -> CommandValidationResult:
	var commander := world.commanders.get(command.commander_id) as CommanderState
	var reason := CommandValidationResult.Reason.NONE
	if world.battle_definition == null or not world.battle_definition.growth_mode or commander == null:
		reason = CommandValidationResult.Reason.INVALID_TARGET
	elif commander.faction_id != command.issuer_id:
		reason = CommandValidationResult.Reason.NOT_CONTROLLER
	elif command.issuer_kind != GameCommand.IssuerKind.PLAYER:
		reason = CommandValidationResult.Reason.AGENT_NOT_AUTHORIZED
	elif command.mode < CommanderState.FormationMode.FREE or command.mode > CommanderState.FormationMode.RETREAT:
		reason = CommandValidationResult.Reason.INVALID_DISPOSITION
	elif commander.legion_regrouping:
		reason = CommandValidationResult.Reason.TASK_CONFLICT
	return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED if reason == CommandValidationResult.Reason.NONE else CommandValidationResult.Status.REJECTED, reason)

func apply(world: SimulationWorld, command: LegionFormationCommand) -> void:
	var result := validate(world, command)
	if not result.is_accepted():
		world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.COMMAND_REJECTED, command.issuer_id, result.describe()))
		return
	var commander := world.commanders[command.commander_id] as CommanderState
	if commander.formation_mode == command.mode: return
	commander.formation_mode = command.mode
	commander.deployment_goal = Vector2(INF,INF)
	commander.deployment_facing = Vector2.ZERO
	if records.has(command.commander_id):
		records[command.commander_id].spatial = LegionSpatialState.new()
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		var formation := world.formations.get(card.formation_id) as FormationState
		if formation != null:
			formation.legion_deployment = null
			formation.deployment_entity_ids.clear()
			formation.deployment_ready_since = -1
		for entity_id in card.member_entity_ids:
			var unit := world.units.get(entity_id) as UnitState
			if unit != null:
				unit.legion_slot = null
				unit.free_march_intent = ""
	var hero := world.units.get(commander.hero_entity_id) as UnitState
	if hero != null and hero.control_state == UnitState.ControlState.AGENT_ASSIGNED:
		hero.path.clear(); hero.has_move_target = false
	world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.TASK_STATE_CHANGED, command.issuer_id, "LEGION_FORMATION_MODE;%s;%s" % [command.commander_id,CommanderState.FormationMode.keys()[command.mode]]))

func prepare(world: SimulationWorld) -> void:
	for unit: UnitState in world.units.values():
		unit.legion_motion = null
		unit.legion_slot = null
		unit.free_legion_movement = false
		unit.flexible_legion_movement = world.battle_definition != null and world.battle_definition.growth_mode and (not unit.unit_card_id.is_empty() or not unit.hero_commander_id.is_empty())
		if unit.flexible_legion_movement:
			unit.legion_motion = LegionMotionConstraint.new()
			unit.legion_motion.ground_radius = 32.0
	if world.battle_definition == null or not world.battle_definition.growth_mode: return
	for formation: FormationState in world.formations.values(): formation.anchor_speed_limit = FormationMovementSystem.ANCHOR_MOVE_SPEED
	for id: StringName in _ids(world):
		var commander := world.commanders[id] as CommanderState
		if not records.has(id): records[id] = LegionFormationState.new()
		var record := records[id]
		record.active = commander.formation_mode != CommanderState.FormationMode.FREE
		for card_id in commander.subordinate_unit_card_ids:
			for entity_id in world.unit_cards[card_id].member_entity_ids:
				var member := world.units.get(entity_id) as UnitState
				if member != null: member.free_legion_movement = not record.active
		var hero := world.units.get(commander.hero_entity_id) as UnitState
		if hero == null or not hero.enabled or commander.legion_regrouping:
			record.reason = &"REGROUPING"; record.batch_plan = null
			record.spatial = LegionSpatialState.new()
			continue
		var own := _own(world,commander,false)
		own.append(UnitSnapshot.new(hero))
		var automatic: Array[StringName] = []
		var speed := minf(FormationMovementSystem.ANCHOR_MOVE_SPEED,hero.move_speed)
		for card_id in commander.subordinate_unit_card_ids:
			var card := world.unit_cards.get(card_id) as UnitCardState
			if card != null and card.uses_legion_slots(): automatic.append(card_id)
		for unit in own:
			if unit.enabled and automatic.has(unit.unit_card_id) and unit.tactical_role != UnitState.TacticalRole.SCOUT:
				speed = minf(speed,unit.move_speed)
		# Artillery groups require stable roster identities even in free mode.
		record.batch_plan = LegionBatchPlanner.plan(LegionTemplate.find(commander.definition.profile.profile_id),CommanderSnapshot.new(commander),own,automatic,record.batch_plan)
		record.core_speed = speed
		if record.active:
			for card_id in automatic:
				var formation := world.formations.get(world.unit_cards[card_id].formation_id) as FormationState
				if formation != null: formation.anchor_speed_limit = speed
			LegionFlexibleMovement.prepare(world,commander,record)
		else:
			record.reason = &"FREE"
			var source := LegionSpatialExecutor._source(world,commander,record)
			if source != null:
				record.spatial.action = LegionSpatialExecutor._action(commander,source)
				record.spatial.anchor = hero.position
				record.spatial.goal = source.order_destination
				record.spatial.intent = str([source.order_kind,source.order_destination,source.planned_route])

func advance_heroes(world: SimulationWorld) -> void:
	if world.battle_definition == null or not world.battle_definition.growth_mode: return
	for id: StringName in _ids(world):
		var commander := world.commanders[id] as CommanderState
		var hero := world.units.get(commander.hero_entity_id) as UnitState
		if hero == null or not hero.enabled or commander.legion_regrouping or hero.control_state != UnitState.ControlState.AGENT_ASSIGNED: continue
		if commander.posture == CommanderState.Posture.HOLD:
			hero.path.clear(); hero.has_move_target = false
			continue
		if commander.formation_mode == CommanderState.FormationMode.FREE and (world.current_tick % 10 == 0 or not hero.has_move_target):
			LegionHeroSystem._follow(world,commander,hero)

static func _stop(hero: UnitState) -> void:
	hero.has_move_target = false; hero.path.clear(); hero.path_index = 0
	hero.local_engagement_active = false; hero.local_engagement_returning = false
