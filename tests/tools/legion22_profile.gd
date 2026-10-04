extends SceneTree
func _initialize() -> void:
	var start := Time.get_ticks_usec()
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var load_ms := (Time.get_ticks_usec() - start) / 1000.0
	world.tick_profile_enabled = true
	var samples: Array[float] = []
	var sections: Dictionary = {}
	for i in range(120):
		start = Time.get_ticks_usec()
		world.advance_tick()
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
		for key in world.last_tick_profile_usec:
			sections[key] = float(sections.get(key, 0)) + world.last_tick_profile_usec[key] / 1000.0
	samples.sort()
	print("LEGION22_PROFILE ", JSON.stringify({"load_ms":load_ms,"tick_p95_ms":samples[113],"tick_max_ms":samples[-1],"total_section_ms":sections,"units":world.units.size()}))
	quit()
