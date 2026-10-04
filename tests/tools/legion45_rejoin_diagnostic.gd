extends SceneTree

func _initialize() -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/legion45/natural0.json"))
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var rows: Array[Dictionary] = []
	var mismatches: Array[int] = []
	var previous_escort := -1
	for step in range(4450):
		world.advance_tick()
		if world.current_tick % 100 == 0:
			var trace := HashingContext.new()
			trace.start(HashingContext.HASH_SHA256)
			var ids := world.units.keys()
			ids.sort()
			for id in ids:
				var unit: UnitState = world.units[id]
				trace.update(var_to_bytes([unit.entity_id,unit.faction_id,unit.position,unit.health,unit.enabled,unit.ammunition,unit.attack_target_entity_id,unit.formation_id,unit.unit_card_id,unit.move_target,unit.path,unit.path_index]))
			if trace.finish().hex_encode() != reference.state_samples[world.current_tick/100-1].unit_state_hash:
				mismatches.append(world.current_tick)
		var commander: CommanderState = world.commanders[&"red_bai_jiuyang"]
		var record: LegionFormationState = world.legion_formation_system.records[&"red_bai_jiuyang"]
		if world.current_tick >= 3850 and (world.current_tick <= 3990 or world.current_tick % 10 == 0 or previous_escort != record.state.escort_id):
			var hero: UnitState = world.units.get(commander.hero_entity_id)
			var escort: UnitState = world.units.get(record.state.escort_id)
			var core: Array[Dictionary] = []
			var army: Array[Dictionary] = []
			for card_id in commander.subordinate_unit_card_ids:
				var card: UnitCardState = world.unit_cards[card_id]
				for id in card.member_entity_ids:
					var unit := world.units.get(id) as UnitState
					if unit == null: continue
					army.append({"id":id,"position":unit.position,"gap":unit.position.distance_to(hero.position),"enabled":unit.enabled,"health":unit.health,"role":unit.tactical_role,"rejoin":unit.rejoin_pending,"returning":unit.legion_returning,"control":unit.control_state,"card_control":card.control_state})
					if not unit.enabled or unit.tactical_role not in [UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR]: continue
					var formation: FormationState = world.formations.get(unit.formation_id)
					core.append({"id":id,"card":card_id,"position":unit.position,"gap":unit.position.distance_to(hero.position),"role":unit.tactical_role,"health":unit.health,"rejoin":unit.rejoin_pending,"returning":unit.legion_returning,"control":unit.control_state,"card_control":card.control_state,"speed":unit.move_speed,"anchor":formation.anchor_position if formation != null else Vector2.ZERO,"anchor_speed_limit":formation.anchor_speed_limit if formation != null else -1.0})
			rows.append({"tick":world.current_tick,"reason":record.reason,"core_speed":record.core_speed,"hero":hero.entity_id,"hero_alive":hero.enabled,"hero_position":hero.position,"hero_move_target":hero.move_target,"hero_has_path":hero.has_move_target,"hero_path_length":LegionProtectionPlanner.path_length(hero.path),"selected_escort":record.state.escort_id,"escort_alive":escort != null and escort.enabled,"selected_gap":hero.position.distance_to(escort.position) if escort != null else -1.0,"regrouping":commander.legion_regrouping,"posture":commander.posture,"target":commander.target_position,"core":core,"army":army})
		previous_escort = record.state.escort_id
		if world.current_tick % 500 == 0:
			FileAccess.open("res://artifacts/legion45/rejoin-diagnostic01-partial.json",FileAccess.WRITE).store_string(JSON.stringify({"tick":world.current_tick,"rows":rows,"state_mismatches":mismatches}))
			print("LEGION45_GAP_DIAGNOSTIC tick=",world.current_tick," state_mismatches=",mismatches.size())
	FileAccess.open("res://artifacts/legion45/rejoin-diagnostic01.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_DIAGNOSTIC","ticks":world.current_tick,"rows":rows,"state_mismatches":mismatches,"scope":"read-only natural replay through first distant escort switch; not a fix"}))
	print("LEGION45_GAP_DONE state_mismatches=",mismatches.size())
	quit(0 if mismatches.is_empty() else 1)
