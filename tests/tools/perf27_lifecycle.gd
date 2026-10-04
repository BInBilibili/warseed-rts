extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for active in [false,true]:
		var detached := SimulationHost.new()
		detached.scenario_kind = SimulationWorld.ScenarioKind.FINAL_DECISION
		detached.world = SimulationWorld.new(true,false,detached.scenario_kind)
		detached._grey_ridge_battle_started = true
		detached._process(0.1)
		if not active: detached._finish_background_tick(true)
		detached.free()
		check(true,"detached free")
	var host := SimulationHost.new()
	host.scenario_kind = SimulationWorld.ScenarioKind.FINAL_DECISION
	host.world = SimulationWorld.new(true,false,host.scenario_kind)
	root.add_child(host)
	host.set_process(false)
	host._grey_ridge_battle_started = true
	var before := host.current_snapshot.tick
	host._process(0.1)
	host.advance_tick()
	check(host.current_snapshot.tick == before+2,"async followed by synchronous step")
	host._process(0.1)
	host._finish_background_tick(true)
	check(host.current_snapshot.tick == before+3,"worker reusable after sync")
	host._process(0.1)
	root.remove_child(host)
	check(host._tick_thread == null and host._tick_worker == null,"remove joins and stops")
	root.add_child(host)
	host._process(0.1)
	host._finish_background_tick(true)
	check(host.current_snapshot.tick == before+5,"reenter creates fresh worker")
	host.free()
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var decision := StaffPlanDecisionSnapshot.new()
	decision.faction_id = 1
	decision.accepted = true
	decision.approved_plan = StaffCourseOfAction.new()
	decision.approved_plan.reserve_card_ids = [&"a"]
	var assignment := StaffPlanAssignment.new()
	assignment.route_points = PackedVector2Array([Vector2(1,2),Vector2(3,4)])
	decision.approved_plan.assignments.append(assignment)
	world.staff_plan_system._decisions[1] = decision
	var old := world.create_snapshot()
	var expected := old.staff_plan_decisions[0].approved_plan.to_dictionary()
	assignment.route_points[0] = Vector2(50,60)
	decision.approved_plan.reserve_card_ids.append(&"b")
	check(old.staff_plan_decisions[0].approved_plan.to_dictionary() == expected,"deep plan isolation from world")
	var fresh := world.create_snapshot()
	old.staff_plan_decisions[0].approved_plan.assignments[0].route_points[1] = Vector2.ZERO
	check(fresh.staff_plan_decisions[0].approved_plan.assignments[0].route_points[1] == Vector2(3,4),"old plan writes cannot change new snapshot")
	check(assignment.route_points[1] == Vector2(3,4),"old plan writes cannot change world")
	var accepted := 0
	world.factions[1].supply = 300
	world.factions[1].recruitment_reserve = 0
	for card: UnitCardState in world.unit_cards.values():
		if card.faction_id != 1: continue
		var view := UnitCardSnapshot.new(card,world.units)
		var order := RecruitUnitCardCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,view.definition_id,1)
		var result := world.submit_command(order)
		if result.is_accepted(): accepted += 1
	check(accepted > 0 and accepted <= 5,"nonempty recruitment and same-tick quota")
	world.factions[1].supply = 0
	var sample: UnitCardState = world.unit_cards.values()[0]
	var rejected := world.submit_command(RecruitUnitCardCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,sample.definition.definition_id,1))
	check(not rejected.is_accepted(),"same-tick supply change revalidated")
	var report := {"evidence":"SIMULATED","checks":checks,"accepted_recruits":accepted,"failures":failures}
	FileAccess.open("res://artifacts/perf27-lifecycle.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF27_LIFECYCLE ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
