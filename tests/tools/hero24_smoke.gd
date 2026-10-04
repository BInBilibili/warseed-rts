extends SceneTree
func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	print("HERO24_CREATED units=",world.units.size()," commanders=",world.commanders.size())
	for i in range(30): world.advance_tick()
	print("HERO24_SMOKE_PASS tick=",world.current_tick)
	quit()
