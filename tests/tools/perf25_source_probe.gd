extends SceneTree

func _initialize() -> void:
	var paths: Array[String] = []
	var failures: Array[String] = []
	for script: Script in [SimulationWorld,SimulationHost,SimulationTickJob,LogicGrid,GridPathfinder,FactionKnowledge,GrowthCommanderAgent,StrategicTaskSystem,TacticalAbilitySystem,Battlefield,MinimapControl,RuntimeMeasurement]:
		paths.append(script.resource_path)
		if not script.resource_path.begins_with("res://src/"): failures.append(script.resource_path)
	print("PERF25_SOURCE_PROBE ",JSON.stringify({"paths":paths,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
