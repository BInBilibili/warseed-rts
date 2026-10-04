class_name LegionGrowthSystem
extends RefCounted

const ROLE_KEYS: Array[StringName] = LegionTemplate.ROLE_KEYS

static func initialize(world: SimulationWorld) -> void:
	if not world.battle_definition.growth_mode: return
	for commander: CommanderState in world.commanders.values():
		commander.growth_slot_entities.resize(60)
		commander.growth_slot_entities.fill(0)
		commander.growth_unlocked_slots = 12
		var slot := 0
		for role in range(4):
			for card_id in commander.subordinate_unit_card_ids:
				var card := world.unit_cards[card_id] as UnitCardState
				if card.definition.role_key != ROLE_KEYS[role]: continue
				var ids := card.member_entity_ids.duplicate()
				ids.sort()
				for id in ids:
					commander.growth_slot_entities[slot] = id
					slot += 1
		assert(slot == 12)

static func next_for_snapshot(view: WorldSnapshot, commander: CommanderSnapshot, pending: Array[RecruitUnitCardCommand] = []) -> int:
	var template := LegionTemplate.find(commander.profile_id)
	if template == null or commander.growth_slot_entities.size() != 60: return -1
	var living: Array[int] = []
	for card_id in commander.subordinate_unit_card_ids:
		var card := view.get_unit_card(card_id)
		if card != null: living.append_array(card.active_member_entity_ids)
	var occupied := PackedByteArray()
	occupied.resize(60)
	for slot in range(60): occupied[slot] = int(living.has(commander.growth_slot_entities[slot]))
	var unlocked := commander.growth_unlocked_slots
	var faction := view.get_faction(commander.faction_id)
	var selected: int = faction.recruitment_arbitration.selected_slots.get(commander.definition_id, -1) if faction != null else -1
	for command in pending:
		var card := view.get_unit_card(command.unit_card_id)
		if command.issuer_id != commander.faction_id or card == null or card.commander_definition_id != commander.definition_id: continue
		var slot := _selected_or_next(template, unlocked, occupied, selected)
		if slot < 0: return -1
		if command.legion_slot >= 0 and command.legion_slot != slot: continue
		if ROLE_KEYS[template.slot_roles()[slot]] != card.role_key: continue
		occupied[slot] = 1
		unlocked = maxi(unlocked, slot + 1)
	return _selected_or_next(template, unlocked, occupied, selected)

static func _selected_or_next(template: LegionTemplate, unlocked: int, occupied: PackedByteArray, selected: int) -> int:
	if selected >= 0 and selected < occupied.size() and selected <= unlocked and occupied[selected] == 0:
		return selected
	return template.next_slot(unlocked, occupied)

static func next_for_world(world: SimulationWorld, commander: CommanderState, pending: Array[RecruitUnitCardCommand] = []) -> int:
	var view := world.create_logistics_snapshot(commander.faction_id, true)
	return next_for_snapshot(view, view.get_commander(commander.definition.definition_id), pending)

static func bind_recruit(commander: CommanderState, slot: int, entity_id: int) -> void:
	commander.growth_slot_entities[slot] = entity_id
	commander.growth_unlocked_slots = maxi(commander.growth_unlocked_slots, slot + 1)


# Growth births are staged without changing authority. In particular a failed
# empty-card rebuild must not allocate a formation or reset its previous task.
static func reinforce(world: SimulationWorld, card: UnitCardState, count: int) -> Array[int]:
	if card == null or count != 1 or card.definition.authorized_strength <= 0:
		return []
	var card_view := UnitCardSnapshot.new(card, world.units)
	if card_view.current_strength >= card_view.authorized_strength:
		return []
	var formation := world.formations.get(card.formation_id) as FormationState
	var rebuilding := card_view.current_strength == 0
	if formation == null and not rebuilding:
		return []
	var entries: Array[UnitCardCompositionState] = card.composition.duplicate()
	entries.sort_custom(func(a: UnitCardCompositionState, b: UnitCardCompositionState) -> bool:
		return a.replacement_priority < b.replacement_priority if a.replacement_priority != b.replacement_priority else String(a.entry_id) < String(b.entry_id))
	var entry: UnitCardCompositionState
	for candidate in entries:
		if candidate.active_count(world.units) < candidate.authorized_strength:
			entry = candidate
			break
	if entry == null:
		return []
	var definition := SimulationWorld.UNIT_CATALOG.get_unit(entry.unit_definition_id)
	if definition == null:
		return []
	var knowledge := world.create_logistics_snapshot(card.faction_id, false)
	var origin := AutomaticLogisticsAgent.recruitment_position(knowledge, card_view, world.battle_definition)
	var position := _birth_position(world, card, knowledge, origin, rebuilding)
	if not position.is_finite():
		return []

	# Nothing above this point consumes IDs, changes membership or grants funds.
	if formation == null:
		formation = FormationState.new(world._next_formation_id, [], position)
		world._next_formation_id += 1
		world.formations[formation.formation_id] = formation
		card.formation_id = formation.formation_id
		formation.strict_deployment_slots = true
	world._prune_disabled_formation_members(formation)
	if rebuilding:
		formation.anchor_position = position
		formation.target_position = position
		formation.order_destination = position
		formation.is_moving = false
		formation.path = PackedVector2Array()
		formation.path_index = 0
		formation.planned_route = PackedVector2Array()
		formation.order_target_entity_id = 0
		formation.order_kind = FormationState.OrderKind.IDLE
		formation.engagement_state = FormationState.EngagementState.NONE
		formation.has_deployment_line = false
		formation.reset_anchor_history(Vector2.RIGHT if card.faction_id == 1 else Vector2.LEFT)
		GrowthCombatSystem.clear_formation_response(formation)
	var entity_id := world._next_unit_id
	world._next_unit_id += 1
	var slot := formation.add_member(entity_id)
	var unit := UnitState.new(entity_id, position, definition.move_speed, card.faction_id)
	world._apply_unit_definition(unit, definition)
	unit.composition_entry_id = entry.entry_id
	unit.formation_id = formation.formation_id
	unit.formation_slot_id = slot
	unit.following_formation = true
	unit.desired_position = position
	unit.has_move_target = formation.is_moving
	unit.move_target = formation.target_position
	unit.original_formation_id = formation.formation_id
	match card.control_state:
		UnitCardState.ControlState.AGENT_ASSIGNED, UnitCardState.ControlState.RETURNING:
			unit.control_state = UnitState.ControlState.AGENT_ASSIGNED
			unit.assigned_agent_id = card.assigned_agent_id
			unit.assigned_task_id = card.assigned_task_id
			if world.tasks.has(unit.assigned_task_id):
				(world.tasks[unit.assigned_task_id] as TaskState).add_participant(entity_id)
		UnitCardState.ControlState.PLAYER_OVERRIDDEN:
			unit.control_state = UnitState.ControlState.TEMPORARILY_OVERRIDDEN
			unit.assigned_agent_id = card.assigned_agent_id
			unit.assigned_task_id = card.assigned_task_id
			unit.return_task_id = card.return_task_id
		UnitCardState.ControlState.PLAYER_CONTROLLED:
			unit.control_state = UnitState.ControlState.PLAYER_CONTROLLED
		_:
			unit.control_state = UnitState.ControlState.UNASSIGNED
	world.units[entity_id] = unit
	card.member_entity_ids.append(entity_id)
	card.member_entity_ids.sort()
	for member_id in formation.member_entity_ids:
		var member := world.units.get(member_id) as UnitState
		if member != null:
			member.formation_slot_id = formation.get_slot_id(member_id)
	world._bind_unit_card_members(card)
	if rebuilding:
		card.organization = world.battle_definition.organization_max
		var commander := world.commanders.get(card.commander_definition_id) as CommanderState
		if commander != null:
			world._assign_unit_card_task(commander, card, commander.target_position, commander.planned_route)
	world._reset_unit_card_organization_baseline(card)
	world._refresh_battle_population()
	return [entity_id]


static func _birth_position(world: SimulationWorld, card: UnitCardState, knowledge: WorldSnapshot, origin: Vector2, rebuilding: bool) -> Vector2:
	if not origin.is_finite():
		return Vector2(INF, INF)
	var approaches: Array[Vector2] = []
	if rebuilding:
		approaches.append(origin)
	else:
		for entity_id in card.member_entity_ids:
			var member := world.units.get(entity_id) as UnitState
			if member != null and member.enabled:
				approaches.append(member.position)
		# Sum scalar doubles around the common map center, then use a sub-pixel
		# birth lattice. Large world-coordinate float sums otherwise choose
		# different sides of a 24-unit occupancy boundary after rotation.
		if not approaches.is_empty():
			var center := world.battle_definition.battlefield_bounds.get_center()
			var sum_x := 0.0
			var sum_y := 0.0
			for approach in approaches:
				sum_x += float(approach.x) - float(center.x)
				sum_y += float(approach.y) - float(center.y)
			var mean_x := sum_x / approaches.size()
			var mean_y := sum_y / approaches.size()
			origin = center + Vector2(signf(mean_x) * floorf(absf(mean_x) * 8.0 + 0.5) / 8.0, signf(mean_y) * floorf(absf(mean_y) * 8.0 + 0.5) / 8.0)
	var direction := 1.0 if card.faction_id == 1 else -1.0
	for ring in range(9):
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring or x * x + y * y > 64:
					continue
				var position := origin + Vector2(x, y) * (48.0 * direction)
				if not LegionTransitGeometry.segment_fits(world.logic_grid,position,position):
					continue
				if not AutomaticLogisticsAgent.is_in_supply(knowledge, position, world.battle_definition) or not AutomaticLogisticsAgent.is_safe(knowledge, position, world.battle_definition):
					continue
				var connected := false
				for approach in approaches:
					if approach.distance_squared_to(position) <= 384.0 * 384.0 and world.logic_grid.is_segment_walkable(approach, position):
						connected = true
						break
				if not connected:
					continue
				var occupied := false
				# Physical occupancy is authoritative; only observed threats inform safety.
				for other: UnitState in world.units.values():
					if other.enabled and other.position.distance_squared_to(position) < FormationMovementSystem.HARD_SEPARATION * FormationMovementSystem.HARD_SEPARATION:
						occupied = true
						break
				if not occupied:
					return position
	return Vector2(INF, INF)
