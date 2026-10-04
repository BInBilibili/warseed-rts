extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 40: failures.append(label)
func _initialize() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var host := SimulationHost.new()
	host.scenario_kind = world.scenario_kind
	host.world = world
	host._grey_ridge_battle_started = true
	var old = preload("res://tests/tools/perf28_reference_report.gd").new()
	var report := GameplayObservabilityReport.new()
	var situation := BattlefieldSituationProjector.new()
	var command := CommandSituationProjector.new()
	var first := world.create_snapshot()
	old.start(first)
	report.start(first)
	var observed := EnemyObservedAction.new()
	observed.observation_id = 1
	observed.action = &"MOVING"
	observed.visible_strength = 4
	var cursor := 0
	var retained: BattlePresentationView
	var retained_value := {}
	var input := InputController.new()
	input.simulation_host = host
	for step in 80:
		host._process(0.1)
		host._finish_background_tick(true)
		var snapshot := host.current_snapshot
		var view := host.get_presentation_view(snapshot)
		check(view == host.get_presentation_view(snapshot),"cache identity")
		var battle := world.battle_definition
		var costs := {}
		for support in battle.support_abilities: costs[String(support.support_id)] = support.supply_cost
		var expected := situation.project(snapshot,1,battle.battlefield_bounds,battle.base_supply_interval_ticks,battle.region_settlement_interval_ticks,costs,battle.base_supply_amount)
		check(view.situation.to_dictionary() == expected.to_dictionary(),"situation %d" % step)
		check(view.command_situation.to_dictionary() == command.project(snapshot,expected,1).to_dictionary(),"command situation %d" % step)
		if step == 0:
			retained = view
			retained_value = view.situation.to_dictionary().duplicate(true)
		else: check(retained.situation.to_dictionary() == retained_value,"retained projection")
		observed.last_tick = step
		observed.visible_strength = step % 8
		observed.action = &"ENGAGING" if step % 2 else &"MOVING"
		snapshot.enemy_observed_actions = [observed.duplicate_value()]
		if step % 7 == 0: snapshot.enemy_observed_actions.clear()
		var events: Array[SimulationEvent] = []
		for i in range(cursor,world.events.size()): events.append(world.events[i])
		cursor = world.events.size()
		# Exercise every parser branch, including ignored high-volume kinds.
		for kind in SimulationEvent.Kind.values():
			events.append(SimulationEvent.new(step,kind,1,"card=missing;faction=1;target=1;amount=7;controller=2;region=test;delta=-1"))
		old.observe(snapshot,events)
		report.observe(snapshot,events)
		old.observe_command_situation(view.command_situation)
		report.observe_command_situation(view.command_situation)
		check(old.create_report() == report.create_report(),"report %d" % step)
		input.selected_entity_ids.clear()
		for unit in snapshot.units:
			if unit.enabled and unit.controller_id == 1: input.selected_entity_ids.append(unit.entity_id)
		var selected := input.selected_entity_ids.duplicate()
		input.prune_selection()
		check(input.selected_entity_ids == selected,"selection %d" % step)
		check(host._presentation_views.size() <= 3,"bounded cache")
	input.free()
	var same_tick := world.create_snapshot()
	check(host.get_presentation_view(same_tick).source == same_tick,"same tick different snapshot")
	host.world = world
	check(host._presentation_views.is_empty(),"world replacement clears views")
	host.free()
	var legacy_host := SimulationHost.new()
	var legacy_root := GameRoot.new()
	legacy_root.simulation_host = legacy_host
	legacy_root._pending_ui_snapshot = first
	legacy_root._pending_ui_phase = 0
	legacy_root._advance_pending_ui_refresh()
	check(legacy_root._pending_situation == null and legacy_root._pending_command_situation == null,"legacy no card situation")
	legacy_root.free()
	legacy_host.free()
	for detail in ["not_target=1;target=2","target=;target=3","abc=3",";target=-4;;","target=a=b;c=d"]:
		var expected_value := ""
		for part in detail.split(";"):
			if part.begins_with("target="):
				expected_value = part.trim_prefix("target=")
				break
		check(EventDetailReader.first_value(detail,"target") == expected_value,"event parser boundary")
	print("PERF28_CONTRACT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
