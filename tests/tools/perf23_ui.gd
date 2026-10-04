extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await BattleLoadingScreen.enter_final_battle(self, "res://scenes/game/final_decision.tscn")
	var game := current_scene as GameRoot
	if game == null:
		push_error("loaded game missing")
		quit(1)
		return
	for frame in range(10): await process_frame
	if game.prebattle_planner.commander_grid.get_child_count() != 5: failures.append("five configuration panels")
	if not game.prebattle_planner.is_plan_valid(): failures.append("default plan valid")
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		game._on_language_changed(locale)
		for resolution in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1600), Vector2i(640,800), Vector2i(480,800)]:
			root.size = resolution
			root.content_scale_size = resolution
			for frame in range(8): await process_frame
			if not Rect2(Vector2.ZERO, Vector2(resolution)).encloses(game.prebattle_planner.start_button.get_global_rect()): failures.append("start clipped " + str(resolution))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/perf23-prebattle-%s-%dx%d.png" % [locale, resolution.x, resolution.y])
	await game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		game._on_language_changed(locale)
		for resolution in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1600), Vector2i(640,800), Vector2i(480,800)]:
			root.size = resolution
			root.content_scale_size = resolution
			for frame in range(12): await process_frame
			if game.army_board.get_commander_card_count() != 5: failures.append("5 legion HUD")
			for button: Button in game.army_board._commander_buttons.values():
				if not button.text.contains("100"): failures.append("organization absent " + button.text)
			for control in [game.army_board, game.minimap, game.task_panel]:
				if not Rect2(Vector2.ZERO, Vector2(resolution)).encloses(control.get_global_rect()): failures.append("HUD clipped " + str(resolution) + str(control.name))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/perf23-battle-%s-%dx%d.png" % [locale, resolution.x, resolution.y])
	var view := game.simulation_host.world.create_snapshot()
	view.tick = 100
	var marker := MinimapMarkerProjector.Marker.new()
	marker.faction_id = 1
	marker.label = "LEGION_ICON_TOP"
	marker.warning = 1
	game.minimap.snapshot = view
	game.minimap._legion_markers = [marker]
	game.minimap._warning_levels.clear()
	game.minimap._last_sound_tick = -1000
	game.minimap._update_warning_audio()
	if game.minimap._warning_player == null or game.minimap._warning_player.stream == null: failures.append("contact warning sound")
	view.tick += 31
	marker.warning = 2
	game.minimap._update_warning_audio()
	if game.minimap._last_sound_tick != view.tick: failures.append("attack warning sound")
	for unit: UnitState in game.simulation_host.world.units.values():
		if unit.weapon_preparation_ticks <= 0: continue
		unit.weapon_prepared_ticks = unit.weapon_preparation_ticks / 2
		var half := UnitSnapshot.new(unit)
		unit.weapon_prepared_ticks = unit.weapon_preparation_ticks
		var full := UnitSnapshot.new(unit)
		if not is_equal_approx(half.deployment_progress,0.5) or full.deployment_progress != 1: failures.append("deployment animation progress")
		break
	print("PERF23_UI ", failures)
	quit(0 if failures.is_empty() else 1)
