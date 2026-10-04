extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	for card: UnitCardState in world.unit_cards.values():
		world._apply_field_reinforcement(card, card.definition.authorized_strength - UnitCardSnapshot.new(card, world.units).current_strength)
	for unit: UnitState in world.units.values():
		unit.position = Vector2(16384 + unit.entity_id % 30 * 8, 12288 + unit.entity_id % 19 * 7)
	world._update_faction_knowledge()
	var snapshot := world.create_snapshot()
	var actual := BattlefieldSituationProjector.new()
	var reference = preload("res://tests/tools/perf27_reference_situation.gd").new()
	var timings := {"reference": 0, "candidate": 0}
	var checks := 0
	var retained: BattlefieldSituationSnapshot
	var retained_data: Dictionary
	for phase in range(80):
		snapshot.tick = phase * 10
		for unit in snapshot.units:
			unit.is_visible_to_local_player = (unit.entity_id + phase) % 3 != 0
			unit.enabled = (unit.entity_id + phase) % 5 != 0
		if phase == 10:
			snapshot.strategic_regions.reverse()
		if phase == 20:
			snapshot.strategic_regions[0].position += Vector2(55, -70)
		if phase == 30:
			snapshot.strategic_regions[0].controller_faction_id = 2
		var a: BattlefieldSituationSnapshot
		var b: BattlefieldSituationSnapshot
		for projector in ([reference, actual] if phase % 2 == 0 else [actual, reference]):
			var started := Time.get_ticks_usec()
			var result: BattlefieldSituationSnapshot = projector.project(snapshot, 1, world.battle_definition.battlefield_bounds)
			timings["candidate" if projector == actual else "reference"] += Time.get_ticks_usec() - started
			if projector == actual: a = result
			else: b = result
		checks += 1
		if a.to_dictionary() != b.to_dictionary(): failures.append("situation mismatch phase %d" % phase)
		if retained != null and retained.to_dictionary() != retained_data: failures.append("old projected snapshot mutated")
		retained = a
		retained_data = a.to_dictionary()
	var report := {"evidence":"SIMULATED", "checks":checks, "failures":failures, "alternating_projection_usec":timings}
	FileAccess.open("res://artifacts/perf27-ui-contract.json", FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF27_UI ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
