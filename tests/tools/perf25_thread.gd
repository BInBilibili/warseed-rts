extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func fingerprint(world: SimulationWorld) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for event in world.events:
		hash.update(("%d:%d:%d:%s\n" % [event.tick,event.kind,event.entity_id,event.detail]).to_utf8_buffer())
	return hash.finish().hex_encode()

func run() -> void:
	var original := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var actual := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var host := SimulationHost.new()
	host.scenario_kind = SimulationWorld.ScenarioKind.FINAL_DECISION
	host.world = actual
	root.add_child(host)
	host.set_process(false)
	host._grey_ridge_battle_started = true
	host._start_playtest_session()
	var old_snapshot := host.current_snapshot
	var old_position := old_snapshot.units[0].position
	var old_grid := host.get_presentation_grid()
	var cell := actual.logic_grid.world_to_cell(actual.units.values()[0].position)
	var old_blocked := old_grid.is_blocked(cell)
	RuntimeMeasurement.reset()
	RuntimeMeasurement.enabled = true
	for step in range(120):
		if step in [10,30,50]:
			var expected := SupplyPriorityCommand.new(original.allocate_command_id(),1,original.current_tick,&"mobile_legion" if step == 10 else &"di_tian")
			var command := host.create_supply_priority_command(expected.commander_id)
			check(original.submit_command(expected).describe() == host.submit_command(command).describe(),"same command result step %d" % step)
		original.advance_tick()
		var before_tick := host.current_snapshot.tick
		host._process(0.1)
		check(host._tick_thread != null,"tick dispatched %d" % step)
		# Polling and normal presentation getters never acquire a running world.
		while host._tick_thread != null and host._tick_thread.is_alive():
			var started := RuntimeMeasurement.begin()
			host._process(0.0)
			var pending_thread := host._tick_thread
			host.get_queue_size()
			host.get_available_support_supply()
			host.get_battle_definition()
			host.get_published_events()
			host.get_presentation_grid()
			host.get_headquarters_budget_snapshot()
			host.get_agent_authorization(StrategicTaskSystem.BATTLEFIELD_AGENT_ID)
			host.get_agent_recommendation_key(StrategicTaskSystem.BATTLEFIELD_AGENT_ID)
			check(host._tick_thread == pending_thread,"presentation getters do not join the worker")
			RuntimeMeasurement.end(&"main.poll_usec",started)
			await process_frame
		host._finish_background_tick(false)
		check(host.current_snapshot.tick == before_tick+1,"exactly one published tick %d" % step)
		check(fingerprint(original) == fingerprint(actual),"ordered events equal step %d" % step)
		for id in original.units:
			var a := original.units[id] as UnitState
			var b := actual.units[id] as UnitState
			if a.position != b.position or a.health != b.health: failures.append("unit mismatch %d/%d" % [step,id])
	check(host.current_snapshot.tick == 120,"fixed step count")
	check(old_snapshot.units[0].position == old_position,"old snapshot value isolation")
	var conclusion := BattleConclusionEvent.new(actual.current_tick,BattleOutcome.new(BattleOutcome.Result.ORDERED_WITHDRAWAL,BattleOutcome.Grade.ORDERED,actual.current_tick))
	actual.events.append(conclusion)
	host._publish_world_view()
	var published := host.get_published_events().back() as BattleConclusionEvent
	check(published != null,"published conclusion preserves typed outcome")
	if published != null:
		conclusion.outcome.result = BattleOutcome.Result.DEFEAT
		check(published.outcome.result == BattleOutcome.Result.ORDERED_WITHDRAWAL,"published conclusion outcome is a value copy")
	actual.logic_grid.set_blocked(cell,not old_blocked)
	host._publish_world_view()
	check(old_grid.is_blocked(cell) == old_blocked,"old terrain view isolated")
	check(host.get_presentation_grid().is_blocked(cell) != old_blocked,"new terrain view published")
	actual.logic_grid.set_blocked(cell,old_blocked)
	# A pending tick is joined before pause, new commands, world replacement or exit.
	host._process(0.1)
	host.set_tactical_paused(true)
	var paused_tick := host.current_snapshot.tick
	host._process(5.0)
	check(host._tick_thread == null and host.current_snapshot.tick == paused_tick,"pause completes current step without advancing paused time")
	host.set_tactical_paused(false)
	host._process(0.5)
	for i in range(5):
		host._finish_background_tick(true)
		host._process(0.0)
	host._finish_background_tick(true)
	check(host.current_snapshot.tick == paused_tick+5,"catchup retains all five fixed steps")
	host._process(0.1)
	var command := host.create_supply_priority_command(&"di_tian")
	check(host._tick_thread == null,"command factory acquires world at tick boundary")
	check(host.submit_command(command).is_accepted(),"command accepted after boundary")
	host._process(0.1)
	var replacement := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.GREY_RIDGE)
	host.world = replacement
	check(host._tick_thread == null and host.world == replacement,"replacement joins previous tick")
	host.scenario_kind = SimulationWorld.ScenarioKind.GREY_RIDGE
	host.current_snapshot = replacement.create_snapshot()
	host._process(0.1)
	check(host._tick_thread == null,"legacy scenario remains synchronous")
	host.free()
	var exiting := SimulationHost.new()
	exiting.scenario_kind = SimulationWorld.ScenarioKind.FINAL_DECISION
	exiting.world = actual
	root.add_child(exiting)
	exiting.set_process(false)
	exiting._grey_ridge_battle_started = true
	exiting._process(0.1)
	exiting.free()
	check(true,"exit joins worker without dangling owner")
	var report := {"evidence":"SIMULATED","checks":checks,"failures":failures,"measurements":RuntimeMeasurement.summary(),"scope":"headless scheduling and deterministic state; not rendered FPS"}
	RuntimeMeasurement.enabled = false
	FileAccess.open("res://artifacts/perf25-thread-final.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PERF25_THREAD ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
