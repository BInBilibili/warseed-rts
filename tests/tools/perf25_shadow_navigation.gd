extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var reference := GridPathfinder.new(world.logic_grid)
	var candidate = preload("res://tests/tools/perf25_shadow_pathfinder.gd").new(world.logic_grid)
	var pairs: Array = []
	var points := world.battle_definition.map_definition.supply_points
	for i in range(points.size()):
		for offset in [1,7,13]: pairs.append([points[i].position,points[(i+offset)%points.size()].position])
	var commander: CommanderState = world.commanders[&"bai_jiuyang"]
	var origin: Vector2 = world.strategic_regions[&"red_top_inner"].position
	for i in range(60): pairs.append([origin+Vector2((i%10-5)*24,(i/10-3)*24),LegionHeroSystem._home(world,commander)])
	RuntimeMeasurement.reset()
	RuntimeMeasurement.enabled = true
	for index in range(pairs.size()):
		var pair: Array = pairs[index]
		var started := RuntimeMeasurement.begin()
		var expected := reference.find_path(pair[0],pair[1])
		RuntimeMeasurement.end(&"shadow.reference_usec",started)
		started = RuntimeMeasurement.begin()
		var actual: PackedVector2Array = candidate.find_path(pair[0],pair[1])
		RuntimeMeasurement.end(&"shadow.candidate_usec",started)
		if expected != actual: failures.append("path mismatch %d" % index)
	var report := {"evidence":"SIMULATED","paths":pairs.size(),"failures":failures,"measurements":RuntimeMeasurement.summary()}
	RuntimeMeasurement.enabled = false
	FileAccess.open("res://artifacts/perf25-shadow-navigation01.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF25_SHADOW ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
