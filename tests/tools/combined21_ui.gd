extends "res://tests/tools/growth_feedback19_ui.gd"

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var game := load("res://scenes/game/final_decision.tscn").instantiate() as GameRoot
	root.add_child(game)
	current_scene = game
	for frame in range(8): await process_frame
	game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	await _step(game)
	var panel := StaffPlanPanel.new()
	root.add_child(panel)
	for locale in ["zh_CN","en"]:
		TranslationServer.set_locale(locale)
		game._on_language_changed(locale)
		for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1600),Vector2i(640,800),Vector2i(480,800)]:
			root.size = resolution
			root.content_scale_size = resolution
			for frame in range(8): await process_frame
			panel.open_plans(game.simulation_host,&"blue_mid_outer")
			panel.coordination.select(1)
			panel.formation_choice.select(1)
			await _activate(panel.generate_button)
			for frame in range(4): await process_frame
			if panel.current_plans == null: failures.append("joint UI generation " + str(resolution))
			else:
				if panel.current_plans.plans[0].coordination != StaffPlanRequest.Coordination.JOINT_ATTACK: failures.append("joint mode propagated")
				if panel.current_plans.plans[0].formation != StaffPlanRequest.Formation.WEDGE: failures.append("formation propagated")
			if panel.size.x > resolution.x or panel.size.y > resolution.y: failures.append("popup exceeds viewport " + str(resolution))
			for control in [panel.coordination,panel.formation_choice,panel.objective_selector]:
				if control.size.x < 80 or control.get_global_rect().end.x > panel.size.x: failures.append("planning field clipped " + str(resolution))
			print("COMBINED21_UI ",locale," ",resolution," popup=",panel.size)
			await RenderingServer.frame_post_draw
			panel.get_texture().get_image().save_png("res://artifacts/combined21-ui-%s-%dx%d.png" % [locale,resolution.x,resolution.y])
			panel.hide()
	for frame in range(8): await process_frame
	# Keyboard approve through the actual panel, inspect the authoritative graph.
	panel.open_plans(game.simulation_host,&"blue_mid_outer")
	for frame in range(8): await process_frame
	panel.coordination.select(1)
	await _activate(panel.generate_button)
	if not panel._approve_buttons.is_empty():
		panel.scroll.ensure_control_visible(panel._approve_buttons[0])
		for frame in range(6): await process_frame
		var button := panel._approve_buttons[0]
		print("COOP_BUTTON ",button.get_global_rect()," visible=",button.is_visible_in_tree()," disabled=",button.disabled)
		button.pressed.emit()
		print("COOP_APPROVAL pending=",panel.pending_command_id," status=",panel.status_label.text)
		await _step(game)
		if game.simulation_host.world.commander_task_graph_system.create_snapshots(1).is_empty(): failures.append("UI button callback creates graph")
	else: failures.append("no approval buttons")
	panel.hide()
	panel.queue_free()
	for failure in failures: push_error(failure)
	print("COMBINED21_UI failures=",failures)
	quit(0 if failures.is_empty() else 1)
