extends SceneTree

# Bounded diagnostic only. Preserve the completed natural matches untouched.
func collect() -> Array[String]:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var result: Array[String] = []
	var cursor := world.events.size()
	for tick in range(600):
		world.advance_tick()
		while cursor < world.events.size():
			var event := world.events[cursor]
			result.append("%d:%d:%d:%s" % [event.tick,event.kind,event.entity_id,event.detail])
			cursor += 1
	return result

func _initialize() -> void:
	var first := collect()
	var second := collect()
	var differences: Array[Dictionary] = []
	for index in range(mini(first.size(),second.size())):
		if first[index] != second[index]:
			differences.append({"index":index,"first":first[index],"second":second[index]})
			if differences.size() >= 20: break
	var report := {"evidence":"SIMULATED_DIAGNOSTIC","ticks_per_run":600,"first_count":first.size(),"second_count":second.size(),"first_differences":differences,"equal":first==second,"does_not_certify_full_match":true}
	FileAccess.open("res://artifacts/legion38/event-diagnostic01.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("LEGION38_EVENT_DIAGNOSTIC ",JSON.stringify(report))
	quit(0)
