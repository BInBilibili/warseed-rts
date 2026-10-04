extends "res://tests/tools/legion49_narrow_executor.gd"

func cause_trial(intervene: bool) -> Dictionary:
	var world := road_fixture(&"gunner",12,false,false)
	var commander := world.commanders.values()[0] as CommanderState
	var samples: Array = []
	var changed_tick := -1
	var changed: Dictionary = {}
	var complete_tick := -1
	for tick in range(600):
		if intervene and world.legion_formation_system.records.has(commander.definition.definition_id):
			var record := world.legion_formation_system.records[commander.definition.definition_id]
			var state := record.spatial
			var source := LegionSpatialExecutor._source(world,commander,record)
			if changed_tick<0 and source!=null and not source.is_moving and state.action==LegionSpatialState.Action.DEFEND and state.anchor.distance_to(state.goal)<=0.01 and not state.route.is_empty() and state.route[-1]==state.goal and state.route_index<state.route.size():
				changed_tick=world.current_tick
				changed={"tick":changed_tick,"source_moving":source.is_moving,"source_route":str(source.planned_route),"state_route":str(state.route),"old_index":state.route_index,"new_index":state.route.size(),"anchor":str(state.anchor),"goal":str(state.goal)}
				# Counterfactual diagnostic only: consume a node physically reached.
				# No production file, unit position, movement flag or slot is changed.
				state.route_index=state.route.size()
		step(world)
		var record := world.legion_formation_system.records[commander.definition.definition_id]
		var state := record.spatial
		var moving := 0
		for card_id in commander.subordinate_unit_card_ids:
			var formation := world.formations.get(world.unit_cards[card_id].formation_id) as FormationState
			if formation!=null and formation.is_moving: moving+=1
		var source := LegionSpatialExecutor._source(world,commander,record)
		var actual_ready := 0
		for unit: UnitState in world.units.values():
			if unit.legion_slot!=null and unit.legion_slot.reason!=&"PATH_UNAVAILABLE" and unit.position.distance_to(unit.legion_slot.target)<=6.0: actual_ready+=1
		samples.append({"tick":world.current_tick,"action":state.action,"anchor":str(state.anchor),"route":str(state.route),"index":state.route_index,"source_route":str(source.planned_route),"source_moving":source.is_moving,"moving":moving,"actual_ready":actual_ready})
		if actual_ready==12 and moving==0 and complete_tick<0: complete_tick=world.current_tick
	return {"intervene":intervene,"changed":changed,"completed_tick":complete_tick,"samples":samples}

func _initialize() -> void:
	var control := cause_trial(false)
	var counterfactual := cause_trial(true)
	check(control.completed_tick<0,"unmodified straight-road arrival failure reproduced")
	check(counterfactual.completed_tick>0,"consuming physically reached node releases remaining card")
	check(not counterfactual.changed.is_empty(),"counterfactual intervention occurred")
	if not counterfactual.changed.is_empty():
		for i in range(counterfactual.changed.tick): check(control.samples[i]==counterfactual.samples[i],"identical execution before counterfactual")
	var data := {"evidence":"SIMULATED_COUNTERFACTUAL","checks":checks,"failures":failures,"control":control,"counterfactual":counterfactual,"production_modified":false}
	FileAccess.open("res://artifacts/legion49/arrival-cause01.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION49_CAUSE checks=",checks," failures=",failures.size()," control_complete=",control.completed_tick," counterfactual_complete=",counterfactual.completed_tick)
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
