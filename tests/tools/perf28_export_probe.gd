extends SceneTree
func _initialize() -> void:
	print("PERF28_EXPORT_STAGE begin")
	var failures: Array[String] = []
	var batch := WsArtBatch.new()
	if not batch.reserve_capacity or not batch.native_buffers_enabled: failures.append("defaults disabled")
	var poses: Array[WsArtPose] = []
	for id in 610:
		var pose := WsArtPose.new()
		pose.entity_id = id
		pose.position = Vector2(id*3,id*2)
		pose.definition_id = &"scout_vehicle"
		pose.enabled = true
		poses.append(pose)
	batch.submit(poses)
	print("PERF28_EXPORT_STAGE batch")
	if batch._native_kernels.is_empty(): failures.append("native kernel missing")
	if batch.debug_visible_instance_count() != 610: failures.append("instance count")
	for key in batch._buffers:
		var values: PackedFloat32Array = batch._buffers[key]
		if values.size() < 610*16 or values[0] != 1.0 or values[609*16+3] != 1827.0 or values[609*16+7] != 1218.0: failures.append("buffer values")
	for pair: Array in batch._groups.values():
		var bounds: AABB = pair[0].multimesh.custom_aabb
		if bounds.position != Vector3(-80,-80,-1) or bounds.size != Vector3(1987,1378,2): failures.append("bounds")
	batch.reset()
	if batch.debug_visible_instance_count() != 0: failures.append("reset")
	batch.free()
	print("PERF28_EXPORT_STAGE world")
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var host := SimulationHost.new()
	host.scenario_kind = world.scenario_kind
	host.world = world
	host._grey_ridge_battle_started = true
	host._process(0.1)
	print("PERF28_EXPORT_STAGE dispatched")
	host._finish_background_tick(true)
	print("PERF28_EXPORT_STAGE joined")
	if host._presentation_views.is_empty() or host.current_snapshot.tick != 1: failures.append("worker projection missing")
	for unit: UnitState in world.units.values():
		if unit.tactical_role == UnitState.TacticalRole.FIREPOWER and (unit.attack_range != 420 or unit.ammunition_capacity != 0): failures.append("artillery changed")
	host.free()
	print("PERF28_EXPORT ",JSON.stringify({"native_loaded":true,"instances":610,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
