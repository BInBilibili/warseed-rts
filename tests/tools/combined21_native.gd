extends SceneTree
var game: GameRoot
var panel: StaffPlanPanel
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.position = Vector2i(120,80)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	TranslationServer.set_locale("zh_CN")
	game = load("res://scenes/game/final_decision.tscn").instantiate() as GameRoot
	root.add_child(game)
	current_scene = game
	game.prebattle_planner._start_battle()
	game.simulation_host.advance_tick()
	game.simulation_host.set_tactical_paused(true)
	for frame in range(16): await process_frame
	panel = StaffPlanPanel.new()
	root.add_child(panel)
	panel.open_plans(game.simulation_host,&"blue_mid_outer")
	panel.coordination.select(1)
	panel.formation_choice.select(1)
	panel.generate()
	panel.status_changed.connect(func(message: String) -> void: print("NATIVE21_STATUS ",message))
func _process(_delta: float) -> bool:
	if game != null and panel != null and not panel.visible and panel.pending_command_id > 0:
		game.simulation_host.set_tactical_paused(false)
		game.simulation_host.advance_tick()
		game.simulation_host.set_tactical_paused(true)
		print("NATIVE21_GRAPHS ",game.simulation_host.current_snapshot.commander_task_graphs.size())
	return false
