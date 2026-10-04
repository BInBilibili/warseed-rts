extends RefCounted

class Marker extends RefCounted:
	var position := Vector2.ZERO
	var faction_id := 0
	var kind: StringName
	var selected := false
	var remembered := false
	var observed_count := 0
	var label := ""
	var warning := 0


func project(snapshot: WorldSnapshot, selected_ids: Array[int]) -> Array[Marker]:
	var result: Array[Marker] = []
	if snapshot == null or snapshot.is_true_state:
		return result
	if snapshot.growth_mode: return _legions(snapshot, selected_ids)
	var grouped: Dictionary = {}
	var covered: Dictionary = {}
	for card in snapshot.unit_cards:
		if card.faction_id != snapshot.observer_faction_id or card.current_strength <= 0 or card.deployment_state != UnitCardState.DeploymentState.DEPLOYED:
			continue
		var marker := Marker.new()
		marker.position = card.center_position
		marker.faction_id = card.faction_id
		marker.kind = &"tank" if card.tactical_kind == TacticalAbilityDefinition.Kind.BREAKTHROUGH else card.unit_definition_id
		marker.observed_count = card.current_strength
		for id in card.active_member_entity_ids:
			covered[id] = true
			marker.selected = marker.selected or selected_ids.has(id)
		result.append(marker)
	for unit in snapshot.units:
		if not unit.enabled or covered.has(unit.entity_id):
			continue
		# Cluster only information actually present in this observer's snapshot.
		# Remembered contacts never merge with currently visible forces.
		var cell := Vector2i((unit.position / 512.0).floor())
		var key := "%d:%s:%s:%s" % [unit.faction_id, unit.definition_id, cell, unit.is_visible_to_local_player]
		if not grouped.has(key):
			var marker := Marker.new()
			marker.kind = unit.definition_id
			marker.faction_id = unit.faction_id
			marker.remembered = not unit.is_visible_to_local_player
			grouped[key] = marker
		var marker := grouped[key] as Marker
		marker.position += unit.position
		marker.observed_count += 1
		marker.selected = marker.selected or selected_ids.has(unit.entity_id)
	var keys := grouped.keys()
	keys.sort()
	for key in keys:
		var marker := grouped[key] as Marker
		marker.position /= marker.observed_count
		result.append(marker)
	for building in snapshot.buildings:
		if not building.enabled:
			continue
		var marker := Marker.new()
		marker.position = building.position
		marker.kind = &"headquarters" if building.definition_id == &"command_center" else &"building"
		marker.faction_id = building.faction_id
		marker.remembered = not building.is_visible
		marker.selected = selected_ids.has(building.entity_id)
		result.append(marker)
	return result

func _legions(snapshot: WorldSnapshot, selected: Array[int]) -> Array[Marker]:
	var result: Array[Marker] = []
	for unit in snapshot.units:
		if not unit.enabled or not unit.is_visible_to_local_player or unit.hero_lane_id.is_empty(): continue
		var marker := Marker.new()
		marker.position = unit.position
		marker.kind = &"legion"
		marker.faction_id = unit.faction_id
		marker.label = "LEGION_ICON_%s" % String(unit.hero_lane_id).to_upper()
		marker.selected = selected.has(unit.entity_id)
		if unit.faction_id == snapshot.observer_faction_id:
			for card in snapshot.unit_cards:
				if card.commander_definition_id != unit.hero_commander_id: continue
				marker.observed_count += card.current_strength
				if snapshot.tick - card.last_damage_tick <= 30: marker.warning = 2
				for id in card.active_member_entity_ids:
					marker.selected = marker.selected or selected.has(id)
			for hostile in snapshot.units:
				if hostile.enabled and hostile.is_visible_to_local_player and hostile.faction_id != snapshot.observer_faction_id and hostile.position.distance_squared_to(marker.position) < 4000000.0:
					marker.warning = maxi(marker.warning, 1)
		result.append(marker)
	return result
