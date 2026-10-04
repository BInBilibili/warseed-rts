extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/perf23-flow-"+label+".png")
func run() -> void:
	DisplayServer.window_set_title("WARSEED PERF23 Complete Flow")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	change_scene_to_file("res://scenes/game/battle_selector.tscn")
	await process_frame
	await process_frame
	var selector=current_scene
	selector._select_mode(true)
	await capture("menu")
	selector._deploy_selected()
	while not current_scene is GameRoot: await process_frame
	var game:=current_scene as GameRoot
	for frame in range(8): await process_frame
	var strategy:="support"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--strategy="): strategy=arg.trim_prefix("--strategy=")
	var policy=preload("res://tests/tools/perf23_blue_policy.gd").new(strategy)
	game.prebattle_planner.open_prebattle(policy.army_plan())
	if not game.prebattle_planner.is_plan_valid(): failures.append("prebattle invalid")
	await capture("prebattle")
	await game.prebattle_planner._start_battle()
	var host:=game.simulation_host
	policy.command_sink=host.submit_command
	host.set_process(false)
	# Accelerated SIMULATED complete flow: five full authoritative ticks per frame,
	# normal host command/report/persistence plumbing; not a realtime FPS benchmark.
	var started:=Time.get_ticks_msec()
	while not host.current_snapshot.outcome.is_terminal():
		for step in range(5):
			if host.current_snapshot.outcome.is_terminal(): break
			policy.advance(host.world)
			host.advance_tick()
		await process_frame
		if host.world.current_tick in [2000,4000,6000]:
			print("PERF23_FLOW tick=",host.world.current_tick," wall=",(Time.get_ticks_msec()-started)/1000.0)
			await capture("battle-"+str(host.world.current_tick))
	for frame in range(10): await process_frame
	if not game.battle_debrief.visible: failures.append("terminal without debrief")
	if host.has_campaign_error(): failures.append("campaign persistence error")
	await capture("debrief")
	var result:=host.current_snapshot.outcome.result_key()
	var tick:=host.world.current_tick
	var trace:=HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	for event in host.world.events: trace.update(("%d:%d:%d:%s\n" % [event.tick,event.kind,event.entity_id,event.detail]).to_utf8_buffer())
	var fingerprint:=trace.finish().hex_encode()
	var report:=host.get_gameplay_observability_report()
	FileAccess.open("res://artifacts/perf23-flow-gameplay.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF23_FLOW_DEBRIEF result=",result," tick=",tick," actions=",policy.actions.size())
	# Give native UI inspection a stable conclusion screen without changing combat.
	if OS.get_cmdline_user_args().has("--inspect-debrief"):
		while game.battle_debrief.visible: await process_frame
	else: game.battle_debrief.fight_again_button.pressed.emit()
	for frame in range(8): await process_frame
	if not game.prebattle_planner.visible or host.world.current_tick!=0: failures.append("restart did not open fresh planning")
	await capture("restart")
	await game.prebattle_planner._start_battle()
	host.advance_tick()
	if host.world.current_tick!=1: failures.append("second battle failed")
	FileAccess.open("res://artifacts/perf23-flow-result.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED","strategy":strategy,"ticks_per_frame":5,"outcome":result,"tick":tick,"actions":policy.actions,"fingerprint":fingerprint,"second_battle_tick":host.world.current_tick,"failures":failures}))
	print("PERF23_FLOW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
