extends "res://tests/tools/legion49_narrow_aligned.gd"

func _initialize() -> void:
	var mirror := OS.get_cmdline_user_args().has("--mirror")
	var destination := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): destination=arg.trim_prefix("--output=")
	var world := road_fixture(&"ranger",36,mirror,true)
	var commander := world.commanders.values()[0] as CommanderState
	var samples: Array = []
	for tick in range(2400):
		step(world)
		if world.current_tick%100!=0: continue
		var state := world.legion_formation_system.records[commander.definition.definition_id].spatial
		var missing: Array = []
		for identity in range(36):
			var unit := world.units[commander.growth_slot_entities[identity]] as UnitState
			var slot := unit.legion_slot
			if slot==null or unit.position.distance_to(slot.target)<=6.0: continue
			var nearest_distance := INF
			var nearest_identity := -1
			var target_nearest_distance := INF
			for other_identity in range(36):
				if other_identity==identity: continue
				var other := world.units[commander.growth_slot_entities[other_identity]] as UnitState
				var distance := unit.position.distance_to(other.position)
				if distance<nearest_distance:
					nearest_distance=distance; nearest_identity=other_identity
				target_nearest_distance=minf(target_nearest_distance,slot.target.distance_to(other.position))
			missing.append({"identity":identity,"position":str(unit.position),"target":str(slot.target),"gap":unit.position.distance_to(slot.target),"slot_reason":slot.reason,"terrain_at_target":LegionTransitGeometry.segment_fits(world.logic_grid,slot.target,slot.target),"terrain_direct":LegionTransitGeometry.segment_fits(world.logic_grid,unit.position,slot.target),"nearest_identity":nearest_identity,"nearest_distance":nearest_distance,"target_nearest_distance":target_nearest_distance,"path":str(slot.path),"path_index":slot.path_index})
		samples.append({"tick":world.current_tick,"phase":state.transit.phase,"ready":state.ready,"reason":state.reason,"missing":missing})
	var final_state := world.legion_formation_system.records[commander.definition.definition_id].spatial
	check(final_state.ready==36,"extended window actually settles all 36 soldiers")
	var data := {"evidence":"SIMULATED_CANDIDATE","profile":"ranger","count":36,"mirror":mirror,"checks":checks,"failures":failures,"samples":samples,"full_B":"REWORK","scope":"extended movement diagnosis; no combat/economy or exit completion claim"}
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION51_GROWTH_STALL checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
