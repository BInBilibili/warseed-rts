extends "res://tests/tools/legion48_spatial_execution.gd"

func _initialize() -> void:
	var world := fixture(&"ranger",false,60)
	var commander := world.commanders.values()[0] as CommanderState
	for tick in range(161):
		step(world)
		if tick%20!=0: continue
		var record := world.legion_formation_system.records[commander.definition.definition_id]
		var members := []
		for unit: UnitState in world.units.values():
			members.append({"id":unit.entity_id,"pos":str(unit.position),"target":str(unit.desired_position),"owned":unit.legion_slot!=null})
		rows.append({"tick":tick,"reason":record.reason,"target":str(record.target),"escort":record.state.escort_id,"spatial_anchor":str(record.spatial.anchor),"ready":record.spatial.ready,"eligible":record.spatial.eligible,"members":members})
	FileAccess.open("res://artifacts/legion48/capacity-diagnostic01.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
	print("LEGION48_CAPACITY_DIAGNOSTIC checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
