extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var rows: Array[Dictionary] = []
	for faction in [1,2]:
		for location in [&"red_mid_outer",&"red_top_inner",&"red_base"]:
			var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
			var commander: CommanderState = world.commanders[&"bai_jiuyang" if faction == 1 else &"red_bai_jiuyang"]
			var origin: Vector2 = world.strategic_regions[location].position
			# An open staging area beside the HQ, not inside its footprint.
			if location == &"red_base": origin += Vector2(-480,480)
			if faction == 2: origin = world.battle_definition.battlefield_bounds.size-origin
			var count := 0
			for card_id in commander.subordinate_unit_card_ids:
				var card: UnitCardState = world.unit_cards[card_id]
				world._apply_field_reinforcement(card,card.definition.authorized_strength-UnitCardSnapshot.new(card,world.units).current_strength)
				for id in card.member_entity_ids:
					var unit: UnitState = world.units[id]
					var offset := Vector2((count%10-5)*24,(count/10-3)*24)
					unit.position = origin+offset*(1 if faction == 1 else -1)
					if not world.logic_grid.is_world_position_walkable(unit.position): failures.append("invalid fixture start")
					count += 1
			RuntimeMeasurement.reset()
			RuntimeMeasurement.enabled = true
			var started := Time.get_ticks_usec()
			LegionHeroSystem._begin_return(world,commander)
			var elapsed := Time.get_ticks_usec()-started
			var moving := 0
			for card_id in commander.subordinate_unit_card_ids:
				for id in world.unit_cards[card_id].member_entity_ids:
					var unit: UnitState = world.units[id]
					if unit.legion_returning and unit.has_move_target: moving += 1
			if count != 60 or moving != 60: failures.append("return paths missing")
			rows.append({"faction":faction,"staging":location,"soldiers":count,"returning_with_path":moving,"elapsed_usec":elapsed,"measurements":RuntimeMeasurement.summary()})
			RuntimeMeasurement.enabled = false
	var report := {"evidence":"SIMULATED","scope":"six synthetic full-legion death transitions at public staging areas; cold path caches; not natural match timing","rows":rows,"failures":failures}
	var report_path := "res://artifacts/perf25-regroup-measure02.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF25_REGROUP_MEASURE ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
