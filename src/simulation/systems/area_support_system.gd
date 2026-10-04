class_name AreaSupportSystem
extends RefCounted

const KINDS := [SupportOrderCommand.SupportKind.AIR_RECON, SupportOrderCommand.SupportKind.MISSILE_BARRAGE, SupportOrderCommand.SupportKind.FIELD_HOSPITAL]
var effects: Array[AreaSupportEffect] = []
var _next_id := 1

func validate(world: SimulationWorld, command: AreaSupportCommand) -> CommandValidationResult:
	if world.battle_definition == null or not world.battle_definition.growth_mode or command.support_kind not in KINDS:
		return _reject(CommandValidationResult.Reason.INVALID_TARGET)
	if not command.position.is_finite() or not world.battle_definition.battlefield_bounds.has_point(command.position):
		return _reject(CommandValidationResult.Reason.INVALID_POSITION)
	var faction := world.factions.get(command.issuer_id) as FactionState
	var definition := world.get_support_definition(command.support_kind)
	if faction == null or definition == null or definition.area_radius <= 0.0:
		return _reject(CommandValidationResult.Reason.INVALID_TARGET)
	if command.issuer_kind == GameCommand.IssuerKind.AGENT and (command.agent_id == 0 or not world._agent_authorization_allows(command)):
		return _reject(CommandValidationResult.Reason.AGENT_NOT_AUTHORIZED)
	if int(faction.support_cooldown_until_by_kind.get(command.support_kind, 0)) > world.current_tick:
		return _reject(CommandValidationResult.Reason.SUPPORT_COOLDOWN)
	if command.support_kind == SupportOrderCommand.SupportKind.FIELD_HOSPITAL:
		if not world.logic_grid.is_world_position_walkable(command.position):
			return _reject(CommandValidationResult.Reason.INVALID_POSITION)
		var legal := world.create_commander_task_snapshot(command.issuer_id)
		if not hospital_position_allowed(legal, command.position):
			return _reject(CommandValidationResult.Reason.TACTICAL_UNSAFE)
	for queued in world.command_queue.snapshot():
		if queued is AreaSupportCommand and queued.issuer_id == command.issuer_id and queued.support_kind == command.support_kind:
			return _reject(CommandValidationResult.Reason.TASK_CONFLICT)
	if available_supply(world, command.issuer_id) < definition.supply_cost:
		return _reject(CommandValidationResult.Reason.INSUFFICIENT_SUPPLY)
	return CommandValidationResult.new(CommandValidationResult.Status.ACCEPTED)

func available_supply(world: SimulationWorld, faction_id: int) -> int:
	var faction := world.factions.get(faction_id) as FactionState
	if faction == null: return 0
	var committed := 0
	for queued in world.command_queue.snapshot():
		if queued.issuer_id != faction_id:
			continue
		if queued is AreaSupportCommand:
			committed += world.get_support_cost(queued.support_kind)
		elif queued is SupportOrderCommand:
			committed += world.get_support_cost(queued.support_kind)
		elif queued is RecruitUnitCardCommand:
			var card := world.unit_cards.get(queued.unit_card_id) as UnitCardState
			if card != null:
				committed += card.definition.recruitment_cost * queued.member_count
		elif queued is TacticalAbilityCommand:
			var card := world.unit_cards.get(queued.unit_card_id) as UnitCardState
			if card != null and card.definition.tactical_ability != null:
				committed += card.definition.tactical_ability.supply_cost
		elif queued is DeployUnitCardCommand:
			var card := world.unit_cards.get(queued.unit_card_id) as UnitCardState
			if card != null:
				committed += card.effective_supply_cost()
	return maxi(0, faction.supply - committed)

func apply(world: SimulationWorld, command: AreaSupportCommand) -> void:
	var checked := validate(world, command)
	if not checked.is_accepted():
		world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.COMMAND_REJECTED, command.issuer_id, checked.describe()))
		return
	var faction := world.factions[command.issuer_id] as FactionState
	var definition := world.get_support_definition(command.support_kind)
	faction.supply -= definition.supply_cost
	RecruitmentSystem.record_spend(faction, world.current_tick, 0, definition.supply_cost)
	faction.support_cooldown_until_by_kind[command.support_kind] = world.current_tick + definition.cooldown_ticks
	var effect := AreaSupportEffect.new()
	effect.effect_id = _next_id
	_next_id += 1
	effect.faction_id = command.issuer_id
	effect.support_kind = command.support_kind
	effect.position = command.position
	effect.radius = definition.area_radius
	effect.started_tick = world.current_tick
	effect.active_tick = world.current_tick + definition.activation_delay_ticks
	effect.expires_tick = effect.active_tick + (maxi(50, definition.duration_ticks) if command.support_kind == SupportOrderCommand.SupportKind.MISSILE_BARRAGE else definition.duration_ticks)
	effect.next_pulse_tick = effect.active_tick
	effects.append(effect)
	world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.SUPPORT_STARTED, command.issuer_id, "area=%d;effect=%d;position=%.1f,%.1f;radius=%.1f;active=%d;expires=%d" % [effect.support_kind, effect.effect_id, effect.position.x, effect.position.y, effect.radius, effect.active_tick, effect.expires_tick]))
	world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.SUPPLY_CHANGED, command.issuer_id, "supply=%d;delta=-%d;source=area_support;kind=%d" % [faction.supply, definition.supply_cost, command.support_kind]))

func advance(world: SimulationWorld) -> void:
	for effect in effects.duplicate():
		if world.current_tick >= effect.expires_tick:
			effects.erase(effect)
			world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.SUPPORT_ENDED, effect.faction_id, "area=%d;effect=%d" % [effect.support_kind, effect.effect_id]))
			continue
		if world.current_tick < effect.active_tick:
			continue
		var definition := world.get_support_definition(effect.support_kind)
		if effect.support_kind == SupportOrderCommand.SupportKind.MISSILE_BARRAGE and not effect.executed:
			effect.executed = true
			_bombard(world, effect, definition.damage)
		elif effect.support_kind == SupportOrderCommand.SupportKind.FIELD_HOSPITAL and world.current_tick >= effect.next_pulse_tick:
			effect.next_pulse_tick = world.current_tick + definition.pulse_interval_ticks
			var healed := 0.0
			for unit: UnitState in world.units.values():
				if unit.enabled and unit.faction_id == effect.faction_id and unit.position.distance_to(effect.position) <= effect.radius:
					var amount := minf(definition.health_restore, unit.max_health - unit.health)
					unit.health += amount
					healed += amount
			if healed > 0.0:
				world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.SUPPORT_STARTED, effect.faction_id, "hospital=%d;healed=%.1f" % [effect.effect_id, healed]))

func reveal(world: SimulationWorld, knowledge: FactionKnowledge) -> void:
	for effect in effects:
		if effect.faction_id == knowledge.faction_id and effect.support_kind == SupportOrderCommand.SupportKind.AIR_RECON and world.current_tick >= effect.active_tick and world.current_tick < effect.expires_tick:
			knowledge.reveal(world.logic_grid.world_to_cell(effect.position), ceili(effect.radius / LogicGrid.CELL_SIZE))

func snapshots(world: SimulationWorld, observer: int) -> Array[AreaSupportEffect]:
	var result: Array[AreaSupportEffect] = []
	var knowledge := world.faction_knowledge.get(observer) as FactionKnowledge
	for effect in effects:
		# Missile warning zones are public to both sides. Recon areas remain private.
		var visible := observer == 0 or effect.faction_id == observer or effect.support_kind == SupportOrderCommand.SupportKind.MISSILE_BARRAGE
		visible = visible or (effect.support_kind == SupportOrderCommand.SupportKind.FIELD_HOSPITAL and knowledge != null and knowledge.is_visible(world.logic_grid.world_to_cell(effect.position)))
		if visible:
			result.append(effect.duplicate_value())
	return result

func _bombard(world: SimulationWorld, effect: AreaSupportEffect, damage: float) -> void:
	var targets: Array[int] = []
	for unit: UnitState in world.units.values():
		if unit.enabled and unit.position.distance_to(effect.position) <= effect.radius:
			targets.append(unit.entity_id)
	for building: BuildingState in world.buildings.values():
		if building.enabled and building.position.distance_to(effect.position) <= effect.radius:
			targets.append(building.entity_id)
	targets.sort()
	for id in targets:
		var amount := maxf(1.0, damage - world.combat_system._entity_armor(id, world.units, world.buildings))
		world.combat_system._apply_damage(id, amount, world.units, world.buildings)
		var remaining := world.combat_system._entity_health(id, world.units, world.buildings)
		world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.DAMAGE_APPLIED, effect.faction_id, "target=%d;amount=%.3f;remaining=%.3f;source=missile_barrage" % [id, amount, remaining]))
		if remaining <= 0.0:
			world.combat_system._disable_destroyed_target(id, world.units, world.buildings, world.current_tick)
			var kind := SimulationEvent.Kind.UNIT_DESTROYED if world.units.has(id) else SimulationEvent.Kind.BUILDING_DESTROYED
			world.events.append(SimulationEvent.new(world.current_tick, kind, id, "source=missile_barrage"))

func _reject(reason: CommandValidationResult.Reason) -> CommandValidationResult:
	return CommandValidationResult.new(CommandValidationResult.Status.REJECTED, reason)

static func hospital_position_allowed(snapshot: WorldSnapshot, position: Vector2) -> bool:
	for region in snapshot.strategic_regions:
		if region.controller_faction_id != 0 and region.controller_faction_id != snapshot.observer_faction_id and position.distance_to(region.position) <= region.radius:
			return false
	return true
