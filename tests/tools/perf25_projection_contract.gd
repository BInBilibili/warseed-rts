extends SceneTree

func fields(decision: CardActionSnapshot) -> Dictionary:
	var result := {}
	for property in decision.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: result[property.name] = decision.get(property.name)
	return result

func _initialize() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var failures: Array[String] = []
	var checks := 0
	var projector := CardActionProjector.new()
	for phase in range(3):
		for card: UnitCardState in world.unit_cards.values():
			if phase == 1: world._apply_field_reinforcement(card,card.definition.authorized_strength-UnitCardSnapshot.new(card,world.units).current_strength)
			card.organization = 100.0 if phase < 2 else 0.0
		for unit: UnitState in world.units.values():
			unit.position = Vector2(16384+(unit.faction_id-1)*150,12288)
			if phase == 2: unit.ammunition = 0
		world.current_tick = phase*100
		world._update_faction_knowledge()
		var view := world.create_faction_snapshot(1)
		var full := projector.project(view,world.battle_definition)
		var selected_ids: Array[StringName] = [&""]
		for card in view.unit_cards:
			if card.faction_id == 1: selected_ids.append(card.definition_id)
		for selected in selected_ids:
			for commander_id in [&"bai_jiuyang",&"mobile_legion"]:
				var expected: Array[Dictionary] = []
				for decision in full:
					if decision.action_kind == SupportOrderCommand.SupportKind.FIELD_REINFORCEMENT: continue
					if decision.action_kind in [CardActionSnapshot.ATTACK_HEADQUARTERS,CardActionSnapshot.CONTINUE_RECON]:
						if decision.commander_id == commander_id: expected.append(fields(decision))
					elif not selected.is_empty() and decision.unit_card_id == selected: expected.append(fields(decision))
				var actual: Array[Dictionary] = []
				for decision in projector.project(view,world.battle_definition,true,selected,commander_id): actual.append(fields(decision))
				checks += 1
				if expected != actual: failures.append("projection mismatch %d/%s/%s" % [phase,selected,commander_id])
	var report := {"checks":checks,"failures":failures,"evidence":"SIMULATED","scope":"ordered contextual actions equal full projection then original display filter; all decision fields"}
	print("PERF25_PROJECTIONS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
