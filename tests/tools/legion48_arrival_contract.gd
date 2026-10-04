extends "res://tests/tools/legion48_spatial_execution.gd"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	for profile: StringName in LegionTemplate.PROFILE_IDS:
		var world := fixture(profile)
		var commander := world.commanders.values()[0] as CommanderState
		for tick in range(350): step(world)
		var record := world.legion_formation_system.records[commander.definition.definition_id]
		var maximum := 0.0
		for unit: UnitState in world.units.values():
			if unit.legion_slot!=null: maximum=maxf(maximum,unit.position.distance_to(unit.legion_slot.target))
		check(maximum<=6.0,"actual full opening formation reaches its slots: "+String(profile))
		var moving := 0
		for id in commander.subordinate_unit_card_ids:
			var card := world.unit_cards[id] as UnitCardState
			var formation := world.formations.get(card.formation_id) as FormationState
			if formation!=null and formation.is_moving: moving+=1
		check(moving==0,"completed real march releases original card movement: "+String(profile))
		rows.append({"profile":profile,"moving_cards":moving,"maximum_slot_gap":maximum,"anchor":str(record.spatial.anchor),"goal":str(record.spatial.goal)})
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED","checks":checks,"failures":failures,"rows":rows}))
	print("LEGION48_ARRIVAL checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
