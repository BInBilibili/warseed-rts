extends SceneTree

func _initialize() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.current_tick = 12000
	for id in range(100000,105000):
		var task := TaskState.new(id,0,[1,2,3,4,5,6,7,8,9,10,11,12])
		task.faction_id = 1
		task.set_lifecycle(TaskState.Lifecycle.CANCELLED,100)
		for point in range(20): task.route.append(Vector2(point*50,point*30))
		world.tasks[id] = task
	RuntimeMeasurement.reset()
	RuntimeMeasurement.enabled = true
	for i in range(30):
		var begin := RuntimeMeasurement.begin()
		world._create_task_snapshots(1,false)
		RuntimeMeasurement.end(&"history.full_usec",begin)
		begin = RuntimeMeasurement.begin()
		world._create_task_snapshots(1,true)
		RuntimeMeasurement.end(&"history.live_usec",begin)
	var history := RuntimeMeasurement.summary()
	for id in range(100000,105000): world.tasks.erase(id)
	world.current_tick = 0
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
	RuntimeMeasurement.reset()
	world.tick_profile_enabled = true
	var start_events := world.events.size()
	for tick in range(150):
		var begin := RuntimeMeasurement.begin()
		world.advance_tick()
		RuntimeMeasurement.end(&"tick.total_usec",begin)
	var shots := 0
	for index_event in range(start_events,world.events.size()):
		if world.events[index_event].kind == SimulationEvent.Kind.PROJECTILE_FIRED: shots += 1
	var report := {"evidence":"SIMULATED","fixture":"610 entities; synthetic full recruitment and HP100000; 20 warmup +150 measured ticks; no renderer","history":history,"combat":RuntimeMeasurement.summary(),"shots":shots,"population":[world.factions[1].population,world.factions[2].population],"entities":world.units.size()}
	var report_path := "res://artifacts/hero24-measure.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("HERO24_MEASURE ",JSON.stringify(report))
	RuntimeMeasurement.enabled = false
	quit(0 if world.factions[1].population == 300 and world.factions[2].population == 300 and shots > 0 else 1)
