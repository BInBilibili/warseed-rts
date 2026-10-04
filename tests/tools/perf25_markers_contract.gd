extends SceneTree

func values(markers: Array) -> Array:
	var result: Array = []
	for marker in markers:
		result.append([marker.position,marker.faction_id,marker.kind,marker.selected,marker.remembered,marker.observed_count,marker.label,marker.warning])
	return result

func _initialize() -> void:
	var failures: Array[String] = []
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var reference = preload("res://tests/tools/perf25_reference_markers.gd").new()
	var actual := MinimapMarkerProjector.new()
	for faction in [1,2]:
		var snapshot := world.create_commander_task_snapshot(faction,false)
		var own_id: StringName = &"mobile_legion" if faction == 1 else &"red_mobile_legion"
		var enemy_id: StringName = &"red_mobile_legion" if faction == 1 else &"mobile_legion"
		var origin: Vector2 = world.units[world.commanders[own_id].hero_entity_id].position
		var enemy := UnitSnapshot.new(world.units[world.commanders[enemy_id].hero_entity_id])
		snapshot.units.append(enemy)
		for tick in range(80):
			snapshot.tick = tick
			var selected: Array[int] = []
			for unit in snapshot.units:
				unit.enabled = unit.entity_id % 13 != tick % 13
				unit.is_visible_to_local_player = unit.entity_id % 7 != tick % 7
				if unit.entity_id % 5 == tick % 5 and tick % 2 == 1: selected.append(unit.entity_id)
			for card in snapshot.unit_cards: card.last_damage_tick = tick-31 if tick % 3 == 0 else tick-30
			enemy.position = origin + Vector2(1999 if tick % 2 == 0 else 2000,0)
			if values(reference.project(snapshot,selected)) != values(actual.project(snapshot,selected)):
				failures.append("marker mismatch faction %d tick %d" % [faction,tick])
	print("PERF25_MARKERS phases=160 failures=",failures)
	quit(0 if failures.is_empty() else 1)
