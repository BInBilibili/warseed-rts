extends SceneTree

func _initialize() -> void:
	var reference := FactionKnowledge.new(1,Vector2i(1024,768))
	var actual := FactionKnowledge.new(1,Vector2i(1024,768))
	var failures: Array[String] = []
	var reference_times: Array[int] = []
	var actual_times: Array[int] = []
	var previous: FactionKnowledgeSnapshot
	var previous_cells := PackedByteArray()
	for phase in range(36):
		var sources: Array[Vector3i] = []
		for i in range(610):
			var x := 512 + (i * 17 + phase * 3) % 90 - 45
			var y := 384 + (i * 11 + phase) % 70 - 35
			if phase < 6:
				x = (i * 97 + phase * 13) % 1080 - 28
				y = (i * 67 + phase * 7) % 810 - 20
			if phase == 5 and i % 3 == 0: continue
			sources.append(Vector3i(x,y,(i*7+phase)%40))
		if phase == 4: sources.clear()
		var start := Time.get_ticks_usec()
		reference.begin_update()
		for source in sources: reference.reveal(Vector2i(source.x,source.y),source.z)
		var before := Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		actual.begin_update()
		actual.reveal_circles(sources)
		var after := Time.get_ticks_usec() - start
		if phase >= 6:
			reference_times.append(before)
			actual_times.append(after)
		# Region and card recon still use the single-circle API after unit vision.
		for center in [Vector2i(-2,15),Vector2i(1023,767),Vector2i(512,384)]:
			reference.reveal(center,phase)
			actual.reveal(center,phase)
		if reference.cells != actual.cells: failures.append("visibility/history differs at phase %d" % phase)
		if previous != null and previous.cells != previous_cells: failures.append("old snapshot changed")
		previous = FactionKnowledgeSnapshot.new(actual)
		previous_cells = actual.cells.duplicate()
	var report := {"evidence":"SIMULATED","phases":36,"samples":30,"failures":failures,"reference_usec":stats(reference_times),"actual_usec":stats(actual_times)}
	FileAccess.open("res://artifacts/perf25-vision01.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF25_VISION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func stats(values: Array[int]) -> Dictionary:
	values.sort()
	return {"p50":values[int((values.size()-1)*0.5)],"p95":values[int((values.size()-1)*0.95)],"max":values[-1]}
