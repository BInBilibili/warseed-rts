extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	for commander: CommanderState in world.commanders.values(): commander.posture = CommanderState.Posture.HOLD
	for card: UnitCardState in world.unit_cards.values():
		world._apply_field_reinforcement(card,card.definition.authorized_strength - UnitCardSnapshot.new(card,world.units).current_strength)
	world._refresh_battle_population()
	world.command_queue.drain()
	world.agents.clear()
	for task: TaskState in world.tasks.values(): task.lifecycle = TaskState.Lifecycle.PAUSED
	for card: UnitCardState in world.unit_cards.values():
		card.control_state = UnitCardState.ControlState.PLAYER_CONTROLLED
		card.persistent_manual = true
	for formation: FormationState in world.formations.values():
		formation.is_moving = false
		formation.order_kind = FormationState.OrderKind.IDLE
	var index := 0
	for unit: UnitState in world.units.values():
		var flank := -1 if unit.faction_id == 1 else 1
		var distance := 210 if unit.tactical_role == UnitState.TacticalRole.FIREPOWER else 70
		unit.position = Vector2(16384,12288) + Vector2(flank * (distance + index % 6 * 8),(index % 50 - 25)*18)
		unit.health = 100000
		unit.max_health = 100000
		unit.has_move_target = false
		unit.following_formation = false
		unit.control_state = UnitState.ControlState.PLAYER_CONTROLLED
		unit.assigned_task_id = 0
		index += 1
	world._update_faction_knowledge()
	for tick in range(20): world.advance_tick()
	var host := SimulationHost.new()
	host.scenario_kind = SimulationWorld.ScenarioKind.FINAL_DECISION
	host.world = world
	root.add_child(host)
	host.set_process(false)
	host._grey_ridge_battle_started = true
	host._start_playtest_session()
	RuntimeMeasurement.reset()
	RuntimeMeasurement.enabled = true
	var start_events := world.events.size()
	for tick in range(150):
		var main_usec := 0
		var started := Time.get_ticks_usec()
		host._process(0.1)
		main_usec += Time.get_ticks_usec()-started
		while host._tick_thread != null:
			started = Time.get_ticks_usec()
			host._process(0.0)
			main_usec += Time.get_ticks_usec()-started
			await process_frame
		RuntimeMeasurement.sample(&"main.total_work_per_tick_usec",main_usec)
	var shots := 0
	var firing_roles := {}
	var suppression_events := 0
	for event_index in range(start_events,world.events.size()):
		var event := world.events[event_index]
		if event.kind == SimulationEvent.Kind.PROJECTILE_FIRED:
			shots += 1
			var source: UnitState = world.units[event.entity_id]
			firing_roles["%d/%d" % [source.faction_id, source.tactical_role]] = true
		if event.kind == SimulationEvent.Kind.SUPPRESSION_APPLIED: suppression_events += 1
	var failures: Array[String] = []
	if world.current_tick != 170: failures.append("wrong tick count")
	if world.factions[1].population != 300 or world.factions[2].population != 300: failures.append("population reduced")
	for faction in [1, 2]:
		for role in [UnitState.TacticalRole.SCOUT, UnitState.TacticalRole.ASSAULT, UnitState.TacticalRole.ARMOR, UnitState.TacticalRole.FIREPOWER]:
			if not firing_roles.has("%d/%d" % [faction, role]): failures.append("missing firing role")
	if suppression_events > 0: failures.append("obsolete suppression projectile")
	var report := {"failures":failures,"firing_roles":firing_roles,"evidence":"SIMULATED","fixture":"610 entities, HP100000,20 warmup+150ticks; main publishing includes real observability reports; no renderer; artillery26 single unlimited missile rules","measurements":RuntimeMeasurement.summary(),"shots":shots,"tick":world.current_tick}
	RuntimeMeasurement.enabled = false
	var report_path := "res://artifacts/perf25-thread-pressure01.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PERF25_THREAD_PRESSURE ",JSON.stringify(report))
	host.free()
	quit(0 if failures.is_empty() else 1)
