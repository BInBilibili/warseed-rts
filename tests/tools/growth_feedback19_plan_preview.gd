extends "res://tests/tools/final_decision_ui_smoke.gd"

func run() -> void:
	TranslationServer.set_locale("en")
	root.size = Vector2i(480,800)
	root.content_scale_size = root.size
	var game := load("res://scenes/game/final_decision.tscn").instantiate() as GameRoot
	root.add_child(game)
	current_scene = game
	for frame in range(12): await process_frame
	game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	await _step(game)
	var panel := game.support_panel
	await _click(panel._plan_toggle.get_global_rect().get_center())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/feedback19-plan-en-narrow-top.png")
	var scroll := panel.get_node("Margin/Scroll") as ScrollContainer
	scroll.ensure_control_visible(panel._plan_apply)
	for frame in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/feedback19-plan-en-narrow-bottom.png")
	print("FEEDBACK19_PLAN_PREVIEW complete")
	quit()
