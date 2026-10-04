extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var reference = preload("res://tests/tools/perf27_reference_art.gd").new()
	var candidate := WsArtBatch.new()
	var poses: Array[WsArtPose] = []
	for id in range(610):
		var pose := WsArtPose.new()
		pose.entity_id = id
		pose.definition_id = WsArtLibrary.IDS[id % WsArtLibrary.IDS.size()]
		pose.blue = id % 2 == 0
		poses.append(pose)
	RuntimeMeasurement.reset()
	RuntimeMeasurement.enabled = true
	for frame in range(120):
		var displayed: Array[WsArtPose] = []
		for pose in poses:
			pose.position = Vector2(pose.entity_id*23+frame,pose.entity_id*13-frame*3)
			pose.heading = sin(float(frame+pose.entity_id)*0.13)*PI
			pose.enabled = (frame+pose.entity_id)%19!=0
			pose.contact_only = (frame+pose.entity_id)%11==0
			pose.deployment_progress = float((pose.entity_id+frame)%100)/100.0
			if pose.entity_id%7==frame%7:
				reference.fire(pose.entity_id)
				candidate.fire(pose.entity_id)
			if pose.entity_id%9==frame%9:
				reference.hit(pose.entity_id)
				candidate.hit(pose.entity_id)
			if pose.entity_id%13!=frame%13: displayed.append(pose)
		reference.advance(0.016)
		candidate.advance(0.016)
		var started := RuntimeMeasurement.begin()
		reference.submit(displayed)
		RuntimeMeasurement.end(&"art.reference_usec",started)
		started = RuntimeMeasurement.begin()
		candidate.submit(displayed)
		RuntimeMeasurement.end(&"art.candidate_usec",started)
		for key in reference._buffers:
			if reference._buffers[key] != candidate._buffers.get(key): failures.append("buffer mismatch %s frame %d" % [key,frame])
		for key in reference._groups:
			for layer in range(2):
				var old: MultiMeshInstance2D = reference._groups[key][layer]
				var new: MultiMeshInstance2D = candidate._groups[key][layer]
				if old.visible != new.visible or old.multimesh.custom_aabb != new.multimesh.custom_aabb or old.multimesh.instance_count != new.multimesh.instance_count:
					failures.append("visibility/bounds mismatch %s frame %d" % [key,frame])
		if reference._feedback != candidate._feedback: failures.append("feedback mismatch frame %d" % frame)
	var report := {"evidence":"SIMULATED","frames":120,"failures":failures,"measurements":RuntimeMeasurement.summary(),"scope":"exact CPU buffers, counts, visibility, culling bounds, feedback; no rendered image evidence"}
	RuntimeMeasurement.enabled = false
	FileAccess.open("res://artifacts/perf27-art-contract.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF25_ART_CANDIDATE ",JSON.stringify(report))
	reference.free()
	candidate.free()
	quit(0 if failures.is_empty() else 1)
