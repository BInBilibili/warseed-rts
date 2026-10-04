extends SceneTree
func _initialize() -> void:
	var a := WsArtBatch.new()
	var b := WsArtBatch.new()
	b.reserve_capacity = true
	var poses: Array[WsArtPose] = []
	for id in range(610):
		var pose := WsArtPose.new()
		pose.entity_id = id
		pose.blue = id % 2 == 0
		pose.position = Vector2(id * 2, id * 3)
		poses.append(pose)
	var failures: Array[String] = []
	var durations := {"exact":0,"reserved":0}
	for frame in range(300):
		var shown: Array[WsArtPose] = []
		for i in range(610 - (frame % 70)):
			shown.append(poses[i])
		for batch in ([a,b] if frame % 2 == 0 else [b,a]):
			var start := Time.get_ticks_usec()
			batch.submit(shown)
			durations["exact" if batch == a else "reserved"] += Time.get_ticks_usec()-start
		for key in a._groups:
			for layer in range(2):
				var old: MultiMeshInstance2D = a._groups[key][layer]
				var actual: MultiMeshInstance2D = b._groups[key][layer]
				if old.multimesh.visible_instance_count != actual.multimesh.visible_instance_count or old.visible != actual.visible or old.multimesh.custom_aabb != actual.multimesh.custom_aabb: failures.append("visibility")
				var buffer_key := "%s:%d" % [key,layer]
				var prefix: PackedFloat32Array = b._buffers[buffer_key].slice(0,a._buffers[buffer_key].size())
				if a._buffers[buffer_key] != prefix: failures.append("active buffer prefix")
	a.submit([])
	b.submit([])
	if b.debug_visible_instance_count() != 0: failures.append("empty visible count")
	a.free()
	b.free()
	var report := {"evidence":"SIMULATED","frames":300,"failures":failures,"submit_usec":durations,"scope":"CPU only; GPU allocation/upload cost unmeasured"}
	FileAccess.open("res://artifacts/perf27-capacity.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF27_CAPACITY ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
