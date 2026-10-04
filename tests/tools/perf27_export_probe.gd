extends SceneTree
func _initialize() -> void:
	var failures: Array[String] = []
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var host := SimulationHost.new()
	host.scenario_kind = world.scenario_kind
	host.world = world
	host._grey_ridge_battle_started = true
	host._process(0.1)
	host._finish_background_tick(true)
	var worker := host._tick_worker
	host._process(0.1)
	host._finish_background_tick(true)
	if host.current_snapshot.tick != 2 or host._tick_worker != worker: failures.append("resident worker missing")
	var view := world.create_logistics_snapshot(1,false)
	if view.is_true_state or view.observer_faction_id != 1 or not view.tasks.is_empty(): failures.append("logistics view")
	var batch := WsArtBatch.new()
	if batch.reserve_capacity: failures.append("experimental capacity enabled")
	for unit: UnitState in world.units.values():
		if unit.tactical_role == UnitState.TacticalRole.FIREPOWER:
			if unit.attack_range != 420 or unit.ammunition_capacity != 0: failures.append("artillery rules")
	batch.free()
	host.free()
	print("PERF27_EXPORT ",JSON.stringify({"evidence":"SIMULATED","failures":failures,"world_script":world.get_script().resource_path}))
	quit(0 if failures.is_empty() else 1)
