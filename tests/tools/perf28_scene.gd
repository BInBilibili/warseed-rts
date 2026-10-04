extends SceneTree
var failures: Array[String] = []
var loading := true
var output_path := "res://artifacts/perf25-headless-frame01.json"
var frames: Array[float] = []
var progress: Dictionary = {}
var last_usec := 0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output_path = arg.trim_prefix("--report=")
	process_frame.connect(_sample)
	call_deferred("run")
func _sample() -> void:
	var now := Time.get_ticks_usec()
	if last_usec > 0: frames.append((now-last_usec)/1000.0)
	last_usec = now
	if loading:
		for child in root.get_children():
			if child is BattleLoadingScreen and child._bar != null: progress[roundi(child._bar.value)] = true
func stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"frames":values.size(),"p50_ms":values[int((values.size()-1)*0.5)],"p95_ms":values[int(values.size()*0.95)],"p99_ms":values[int(values.size()*0.99)],"max_ms":values.back()}
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await BattleLoadingScreen.enter_final_battle(self,"res://scenes/game/final_decision.tscn")
	var game := current_scene as GameRoot
	await game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	print("LEGION22_LOADING_FRAMES ",stats(frames)," progress=",progress.keys()," phases=",BattleLoadingScreen.last_measurement)
	loading = false
	if OS.get_cmdline_user_args().has("--no-native"): game.world_presentation._art_batch.set("native_buffers_enabled",false)
	if OS.get_cmdline_user_args().has("--exact-capacity"): game.world_presentation._art_batch.reserve_capacity = false
	var world := game.simulation_host.world
	for commander: CommanderState in world.commanders.values(): commander.posture = CommanderState.Posture.HOLD
	for card: UnitCardState in world.unit_cards.values():
		world._apply_field_reinforcement(card,card.definition.authorized_strength-UnitCardSnapshot.new(card,world.units).current_strength)
	world._refresh_battle_population()
	world.command_queue.drain()
	world.agents.clear()
	for task: TaskState in world.tasks.values(): task.lifecycle = TaskState.Lifecycle.PAUSED
	for card: UnitCardState in world.unit_cards.values():
		card.control_state = UnitCardState.ControlState.PLAYER_CONTROLLED
		card.persistent_manual = true
	var origin := Vector2(16384,12288)
	for formation: FormationState in world.formations.values():
		formation.is_moving = false
		formation.order_kind = FormationState.OrderKind.IDLE
	var index := 0
	for unit: UnitState in world.units.values():
		if not unit.enabled: continue
		var flank := -1 if unit.faction_id == 1 else 1
		var distance := 210 if unit.tactical_role == UnitState.TacticalRole.FIREPOWER else 70
		unit.position = origin + Vector2(flank * (distance + index % 6 * 8), (index % 50 - 25)*18)
		unit.health = 100000
		unit.max_health = 100000
		unit.has_move_target = false
		unit.following_formation = false
		unit.control_state = UnitState.ControlState.PLAYER_CONTROLLED
		unit.assigned_task_id = 0
		index += 1
	world._update_faction_knowledge()
	game.camera_controller.center_on_world_position(origin)
	game.camera_controller.zoom = Vector2(0.8,0.8)
	for tick in range(20): world.advance_tick()
	game.simulation_host._publish_world_view()
	game.simulation_host.current_snapshot = world.create_snapshot()
	game.simulation_host.previous_snapshot = game.simulation_host.current_snapshot
	for frame in range(15): await process_frame
	frames.clear()
	last_usec = 0
	RuntimeMeasurement.reset()
	var probes := not OS.get_cmdline_user_args().has("--without-probes")
	RuntimeMeasurement.enabled = probes
	world.tick_profile_enabled = probes
	var start_tick := world.current_tick
	game.simulation_host.set_tactical_paused(false)
	while game.simulation_host.current_snapshot.tick < start_tick + 150:
		await process_frame
		game.camera_controller.center_on_world_position(origin+Vector2(sin(game.simulation_host.current_snapshot.tick*0.02)*200,0))
		RuntimeMeasurement.sample(&"frame.live_projectiles", game.simulation_host.current_snapshot.projectiles.size())
		RuntimeMeasurement.sample(&"frame.hud_phase", game._pending_ui_phase)

	game.simulation_host.set_tactical_paused(true)
	var shots := 0
	for event in world.events:
		if event.tick >= start_tick and event.kind == SimulationEvent.Kind.PROJECTILE_FIRED: shots += 1
	if world.factions[1].population != 300 or world.factions[2].population != 300: failures.append("capacity")
	if shots == 0: failures.append("no combat")
	print("PERF25_HEADLESS_SCENE610 ",stats(frames)," detail=", {}," shots=",shots," failures=",failures)
	var report := {"probes_enabled":probes,"evidence":"SIMULATED","scope":"headless full scene CPU callbacks, no rasterization, no native playtest, not FPS","loading_phases":BattleLoadingScreen.last_measurement,"frames_ms":stats(frames), "measurements":RuntimeMeasurement.summary(), "shots":shots,"failures":failures}
	RuntimeMeasurement.enabled = false
	FileAccess.open(output_path,FileAccess.WRITE).store_string(JSON.stringify(report))
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/perf23-dense-final.png")
	quit(0 if failures.is_empty() else 1)
