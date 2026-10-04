extends SceneTree
func _initialize() -> void:
	var worker := SimulationTickJob.new()
	var world := SimulationWorld.new(false)
	var world_ref: WeakRef = weakref(world)
	if worker.start() != OK:
		quit(1)
		return
	worker.dispatch(world)
	var snapshot := worker.wait_to_finish()
	var snapshot_ref: WeakRef = weakref(snapshot)
	world = null
	snapshot = null
	OS.delay_msec(20)
	var retained_world: bool = world_ref.get_ref() != null
	var retained_snapshot: bool = snapshot_ref.get_ref() != null
	worker.stop()
	print("PERF27_WORKER_RELEASE ", JSON.stringify({"retained_world":retained_world,"retained_snapshot":retained_snapshot}))
	quit(1 if retained_world or retained_snapshot else 0)
