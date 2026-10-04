extends SceneTree
func _initialize() -> void:
	var failures: Array[String] = []
	var checks := 0
	var old = preload("res://tests/tools/perf28_reference_art.gd").new()
	var exact := WsArtBatch.new()
	exact.reserve_capacity = false
	var reserved := WsArtBatch.new()
	var fallback := WsArtBatch.new()
	fallback.reserve_capacity = false
	fallback.native_buffers_enabled = false
	var poses: Array[WsArtPose] = []
	var samples := {"baseline":[],"native_exact":[],"native_reserved":[],"gd_fallback":[]}
	for id in range(610):
		var pose := WsArtPose.new()
		pose.entity_id = id
		poses.append(pose)
	for frame in range(300):
		var shown: Array[WsArtPose] = []
		for pose in poses:
			pose.position = Vector2(sin(pose.entity_id+frame)*32000,cos(pose.entity_id-frame)*24000)
			pose.heading = [PI,-PI,0.0,0.000000001,TAU, -TAU,sin((pose.entity_id+frame)*0.123456789)*PI][(pose.entity_id+frame)%7]
			pose.definition_id = WsArtLibrary.IDS[(pose.entity_id+frame/10 as int)%6]
			pose.blue = (pose.entity_id+frame/20 as int)%2 == 0
			pose.enabled = (pose.entity_id+frame)%17 != 0
			pose.contact_only = (pose.entity_id+frame)%13 == 0
			pose.deployment_progress = float((pose.entity_id+frame)%101)/100.0
			for batch in [old,exact,reserved,fallback]:
				if (pose.entity_id+frame)%7 == 0: batch.fire(pose.entity_id)
				if (pose.entity_id+frame)%11 == 0: batch.hit(pose.entity_id)
			if frame%41 != 0 and pose.entity_id < (frame*37)%611: shown.append(pose)
		var batches := [old,exact,reserved,fallback] if frame%2 == 0 else [fallback,reserved,exact,old]
		for batch in batches:
			batch.advance(0.016)
			var started := Time.get_ticks_usec()
			batch.submit(shown)
			var label := "baseline" if batch == old else ("native_exact" if batch == exact else ("native_reserved" if batch == reserved else "gd_fallback"))
			samples[label].append(Time.get_ticks_usec()-started)
		for key in old._groups:
			var count: int = old._groups[key][0].multimesh.instance_count
			for candidate in [exact,reserved,fallback]:
				for layer in 2:
					var expected: MultiMeshInstance2D = old._groups[key][layer]
					var actual: MultiMeshInstance2D = candidate._groups[key][layer]
					checks += 1
					if expected.visible != actual.visible or expected.multimesh.custom_aabb != actual.multimesh.custom_aabb or actual.multimesh.visible_instance_count != count:
						if failures.size()<20: failures.append("bounds/count %d %s" % [frame,key])
					var buffer_key := "%s:%d" % [key,layer]
					if count > 0:
						checks += 1
						if old._buffers[buffer_key] != candidate._buffers[buffer_key].slice(0,count*16):
							if failures.is_empty():
								for i in count*16:
									if old._buffers[buffer_key][i] != candidate._buffers[buffer_key][i]:
										print("FIRST_DIFFERENCE ",i," ",old._buffers[buffer_key][i]," ",candidate._buffers[buffer_key][i])
										break
							if failures.size()<20: failures.append("buffer %d %s" % [frame,buffer_key])
		if frame%47 == 0:
			for batch in [old,exact,reserved,fallback]: batch.reset()
	if exact._native_kernels.is_empty() or reserved._native_kernels.is_empty(): failures.append("native not loaded")
	if not fallback._native_kernels.is_empty(): failures.append("fallback not used")
	for batch in [old,exact,reserved,fallback]: batch.free()
	var timings := {}
	for key in samples:
		var values: Array = samples[key]
		values.sort()
		var total := 0
		for value in values: total += value
		timings[key] = {"p95_usec":values[285],"max_usec":values.back(),"total_usec":total}
	var report := {"checks":checks,"frames":300,"failures":failures,"timings":timings}
	FileAccess.open("res://artifacts/perf28-native-contract.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF28_NATIVE ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
