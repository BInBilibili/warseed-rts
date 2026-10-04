extends "res://tests/tools/final_decision_ui_smoke.gd"

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var game := load("res://scenes/game/final_decision.tscn").instantiate() as GameRoot
	root.add_child(game)
	current_scene=game
	for frame in range(12): await process_frame
	game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	await _step(game)
	game.camera_controller.center_on_world_position(Vector2(12288,8192))
	game.camera_controller.zoom = Vector2.ONE*0.08
	for frame in range(16): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/jungle-links-north-game.png")
	game.camera_controller.center_on_world_position(Vector2(20480,16384))
	for frame in range(16): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/jungle-links-south-game.png")
	print("JUNGLE_LINKS_VISUAL complete")
	quit()
