extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(180.0).timeout.connect(func(): push_error("HERO24_FLOW timed out"); quit(1))
	print("HERO24_FLOW menu")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	change_scene_to_file("res://scenes/game/battle_selector.tscn")
	await process_frame
	await process_frame
	var selector = current_scene
	selector._select_mode(true)
	selector._deploy_selected()
	while not current_scene is GameRoot: await process_frame
	print("HERO24_FLOW prebattle")
	var game := current_scene as GameRoot
	for frame in range(8): await process_frame
	if not game.prebattle_planner.is_plan_valid(): failures.append("invalid prebattle")
	await game.prebattle_planner._start_battle()
	print("HERO24_FLOW battle")
	var host := game.simulation_host
	host.set_process(false)
	# A terminal-state fixture tests the UI/persistence flow; natural full matches
	# are independently simulated by perf23_natural without this time-limit edit.
	host.world.battle_definition.time_limit_ticks = host.world.current_tick + 3
	for tick in range(5): host.advance_tick()
	for frame in range(15): await process_frame
	if not host.current_snapshot.outcome.is_terminal(): failures.append("terminal fixture did not conclude")
	if not game.battle_debrief.visible: failures.append("no debrief")
	if host.has_campaign_error(): failures.append("persistence error")
	var outcome := host.current_snapshot.outcome.result_key()
	print("HERO24_FLOW debrief ",outcome)
	game.battle_debrief.fight_again_button.pressed.emit()
	for frame in range(8): await process_frame
	if not game.prebattle_planner.visible or host.world.current_tick != 0: failures.append("restart failed")
	await game.prebattle_planner._start_battle()
	print("HERO24_FLOW restarted")
	host.advance_tick()
	if host.world.current_tick != 1: failures.append("second battle failed")
	var report := {"evidence":"SIMULATED","mode":"headless terminal-time fixture, not natural victory evidence","outcome":outcome,"second_battle_tick":host.world.current_tick,"failures":failures}
	FileAccess.open("res://artifacts/hero24-flow.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("HERO24_FLOW ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
