extends "res://tests/tools/legion49_narrow_aligned.gd"

func _initialize() -> void:
	var world := road_fixture(&"gunner",60,false,true)
	var commander := world.commanders.values()[0] as CommanderState
	for tick in range(350): step(world)
	var transit := world.legion_formation_system.records[commander.definition.definition_id].spatial.transit
	var rows: Array = []
	for identity in range(61):
		var unit := LegionTransitExecutor._entity(world,commander,identity)
		if unit.position.distance_to(unit.desired_position)<=6.0: continue
		var state := transit.gather_navigation[identity]
		var own := PackedVector2Array()
		for other: UnitState in world.units.values():
			if other.entity_id!=unit.entity_id: own.append(other.position)
		var path := LegionGatherNavigation.local_route(world.logic_grid,unit.position,unit.desired_position,own)
		rows.append({"identity":identity,"position":str(unit.position),"goal":str(unit.desired_position),"stalled":state.stalled,"last_retry":state.retry_tick,"cached":state.route.size(),"index":state.index,"diagnostic_route":str(path)})
	FileAccess.open("res://artifacts/legion51/gather-diagnostic01.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows}))
	print("LEGION51_GATHER_DIAGNOSTIC checks=",checks," failures=",failures.size()," blocked=",rows.size())
	quit(0 if failures.is_empty() else 1)
