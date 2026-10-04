extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var checks := 0
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var snapshot := world.create_snapshot()
	var reference_script = preload("res://tests/tools/perf28_reference_situation.gd")
	var timings := {"reference": [], "candidate": []}
	for trial in range(6):
		for side in (["reference", "candidate"] if trial % 2 == 0 else ["candidate", "reference"]):
			var projector = reference_script.new() if side == "reference" else BattlefieldSituationProjector.new()
			var started := Time.get_ticks_usec()
			projector.project(snapshot, 1, world.battle_definition.battlefield_bounds)
			timings[side].append(Time.get_ticks_usec() - started)
	var reference = reference_script.new()
	var actual := BattlefieldSituationProjector.new()
	var random := RandomNumberGenerator.new()
	random.seed = 280921
	var retained: Array[Dictionary] = []
	var retained_value: Array[Dictionary] = []
	for size in [Vector2i.ZERO, Vector2i(1,1), Vector2i(1,7), Vector2i(9,1), Vector2i(17,13), Vector2i(128,64)]:
		for mode in range(8):
			var knowledge := FactionKnowledge.new(1, size)
			for y in range(size.y):
				for x in range(size.x):
					var value := mode % 3
					if mode == 3: value = y % 3
					if mode == 4: value = x % 3
					if mode == 5: value = random.randi_range(0,2)
					if mode == 6: value = 2 if x == size.x - 1 else 0
					if mode == 7: value = 2 if x == 0 else 1
					knowledge.cells[y * size.x + x] = value
			snapshot.knowledge = FactionKnowledgeSnapshot.new(knowledge)
			for bounds in [Rect2(LogicGrid.WORLD_ORIGIN, Vector2(100000,100000)), Rect2(LogicGrid.WORLD_ORIGIN + Vector2(13,19), Vector2(145,218)), Rect2(Vector2(200000,200000), Vector2.ONE)]:
				for repeat in range(2):
					var result := actual._derive_uncertainty(snapshot,bounds)
					var expected: Array[Dictionary] = reference._derive_uncertainty(snapshot,bounds)
					checks += 2
					if result != expected: failures.append("fog mismatch %s/%d/%s/%d" % [size,mode,bounds,repeat])
					if retained != retained_value: failures.append("retained fog mutated")
					retained = result
					retained_value = result.duplicate(true)
	var report := {"evidence":"SIMULATED", "checks":checks, "failures":failures, "cold_projection_usec":timings}
	FileAccess.open("res://artifacts/perf28-uncertainty-contract.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF28_UNCERTAINTY ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
