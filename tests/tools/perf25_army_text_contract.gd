extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	for card: UnitCardState in world.unit_cards.values():
		world._apply_field_reinforcement(card, card.definition.authorized_strength - UnitCardSnapshot.new(card, world.units).current_strength)
	var snapshot := world.create_snapshot()
	var actual := ArmyBoard.new()
	var reference = preload("res://tests/tools/perf25_reference_army_board.gd").new()
	for board in [actual, reference]:
		board._snapshot = snapshot
		for commander in snapshot.commanders:
			var button := Button.new()
			var priority := Button.new()
			board.add_child(button)
			board.add_child(priority)
			board._commander_buttons[commander.definition_id] = button
			board._supply_priority_buttons[commander.definition_id] = priority
	var phases := 0
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		for phase in range(40):
			snapshot.tick = phase * 10
			actual._indexed_feedback_snapshot = null
			reference._indexed_feedback_snapshot = null
			for unit in snapshot.units:
				unit.is_visible_to_local_player = (unit.entity_id + phase) % 3 == 0
				unit.enabled = (unit.entity_id + phase) % 5 != 0
				unit.is_attacking = phase % 7 == 0
				unit.is_moving = phase % 2 == 0
				unit.position = Vector2((unit.entity_id % 40) * (20 if phase % 2 == 0 else 100), (unit.entity_id % 20) * 100)
			for card in snapshot.unit_cards:
				card.organization = phase * 2.5
				card.temporary_micro = phase % 2 == 0
				card.current_strength = phase % 12
			for commander in snapshot.commanders:
				commander.hero_respawn_tick = snapshot.tick + 37 if phase % 4 == 0 else -1
				commander.legion_regrouping = phase % 4 == 1
				actual._update_tactical_commander(commander)
				reference._update_tactical_commander(commander)
				if actual._tactical_activity(commander) != reference._tactical_activity(commander):
					failures.append("activity mismatch %s %d %s" % [locale, phase, commander.definition_id])
				for name in ["_commander_buttons", "_supply_priority_buttons"]:
					var a: Button = actual.get(name)[commander.definition_id]
					var b: Button = reference.get(name)[commander.definition_id]
					if a.text != b.text or a.tooltip_text != b.tooltip_text or a.button_pressed != b.button_pressed:
						failures.append("display mismatch %s %d %s" % [locale, phase, commander.definition_id])
			phases += 1
	var times := {"reference": 0, "candidate": 0}
	for unit in snapshot.units:
		unit.is_visible_to_local_player = false
		unit.is_attacking = false
	actual._indexed_feedback_snapshot = null
	reference._indexed_feedback_snapshot = null
	for repeat_index in range(100):
		var order: Array = [reference, actual] if repeat_index % 2 == 0 else [actual, reference]
		for board in order:
			var started := Time.get_ticks_usec()
			for commander in snapshot.commanders:
				board._update_tactical_commander(commander)
				board._tactical_activity(commander)
			times["reference" if board == reference else "candidate"] += Time.get_ticks_usec() - started
	actual.free()
	reference.free()
	var report := {"evidence": "SIMULATED", "phases": phases, "failures": failures, "alternating_100_refreshes_usec": times, "scope": "isolated function comparison under concurrent functional verification, not final scene performance"}
	FileAccess.open("res://artifacts/perf25-army-text02.json", FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF25_ARMY_TEXT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
