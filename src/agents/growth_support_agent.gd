class_name GrowthSupportAgent
extends RefCounted

func propose(snapshot: WorldSnapshot, battle: BattleDefinition, agent_id: int) -> AreaSupportCommand:
	if snapshot == null or snapshot.is_true_state or snapshot.knowledge == null or snapshot.observer_faction_id != snapshot.knowledge.faction_id or not battle.growth_mode:
		return null
	var faction := snapshot.get_faction(snapshot.observer_faction_id)
	if faction == null: return null
	var missile := battle.support_for_kind(SupportOrderCommand.SupportKind.MISSILE_BARRAGE)
	if _available(snapshot, faction, missile):
		for target in snapshot.units:
			if target.faction_id == snapshot.observer_faction_id or not target.enabled or not target.is_visible_to_local_player: continue
			var enemies := 0
			var allies := 0
			for unit in snapshot.units:
				if not unit.enabled or unit.position.distance_to(target.position) > missile.area_radius + 200.0: continue
				if unit.faction_id == snapshot.observer_faction_id: allies += 1
				elif unit.is_visible_to_local_player: enemies += 1
			if enemies >= 6 and allies == 0:
				return _command(snapshot, missile.support_kind, target.position, agent_id)
	var hospital := battle.support_for_kind(SupportOrderCommand.SupportKind.FIELD_HOSPITAL)
	if _available(snapshot, faction, hospital):
		for candidate in snapshot.units:
			if not candidate.enabled or candidate.faction_id != snapshot.observer_faction_id or candidate.health >= candidate.max_health * 0.7: continue
			if not AreaSupportSystem.hospital_position_allowed(snapshot, candidate.position): continue
			var injured := 0
			for unit in snapshot.units:
				if unit.enabled and unit.faction_id == snapshot.observer_faction_id and unit.health < unit.max_health * 0.7 and unit.position.distance_to(candidate.position) < hospital.area_radius:
					injured += 1
			if injured >= 4:
				return _command(snapshot, hospital.support_kind, candidate.position, agent_id)
	var recon := battle.support_for_kind(SupportOrderCommand.SupportKind.AIR_RECON)
	if _available(snapshot, faction, recon):
		for commander in snapshot.commanders:
			var target := snapshot.get_strategic_region(commander.target_region_id)
			if target == null or target.controller_faction_id == snapshot.observer_faction_id or snapshot.knowledge.is_visible(Vector2i((target.position - battle.battlefield_bounds.position) / battle.map_definition.cell_size)): continue
			for card in snapshot.unit_cards:
				if card.commander_definition_id == commander.definition_id and card.current_strength > 0 and card.center_position.distance_to(target.position) < 3000.0:
					return _command(snapshot, recon.support_kind, target.position, agent_id)
	return null

func _available(snapshot: WorldSnapshot, faction: FactionSnapshot, definition: BattleSupportDefinition) -> bool:
	return definition != null and faction.supply >= definition.supply_cost + 60 and int(faction.support_cooldown_until_by_kind.get(definition.support_kind, 0)) <= snapshot.tick

func _command(snapshot: WorldSnapshot, kind: SupportOrderCommand.SupportKind, position: Vector2, agent_id: int) -> AreaSupportCommand:
	var result := AreaSupportCommand.new(0, snapshot.observer_faction_id, GameCommand.IssuerKind.AGENT, snapshot.tick, kind, position)
	result.agent_id = agent_id
	return result
