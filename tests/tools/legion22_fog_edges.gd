extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var unit := world.units.values()[0] as UnitState
	for phase in range(6):
		match phase:
			0: unit.position += Vector2(256,0)
			1: unit.sight_range *= 1.5
			2: unit.enabled = false
			3:
				var effect := AreaSupportEffect.new()
				effect.faction_id = 1
				effect.support_kind = SupportOrderCommand.SupportKind.AIR_RECON
				effect.position = Vector2(16384,12288)
				effect.radius = 1600
				effect.expires_tick = 10
				world.area_support_system.effects.append(effect)
			4: world.current_tick = 11
			5: world.area_support_system.effects.clear()
		world._update_faction_knowledge()
		var expected := (world.faction_knowledge[1] as FactionKnowledge).cells.duplicate()
		world._vision_sources.clear()
		world._update_faction_knowledge()
		if expected != (world.faction_knowledge[1] as FactionKnowledge).cells: failures.append(str(phase))
	print("LEGION22_FOG_EDGES ",failures)
	quit(0 if failures.is_empty() else 1)
