extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("UI create scene")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var game := load("res://scenes/game/final_decision.tscn").instantiate() as GameRoot
	print("UI add scene")
	root.add_child(game)
	print("UI scene ready")
	current_scene = game
	for frame in range(8): await process_frame
	print("UI start battle")
	game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		game._on_language_changed(locale)
		for resolution in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1600), Vector2i(640,800), Vector2i(480,800)]:
			root.size = resolution
			root.content_scale_size = resolution
			for frame in range(12): await process_frame
			var viewport := Rect2(Vector2.ZERO, Vector2(resolution))
			print("UI_CAMERA viewport=%s position=%s visible=%s headquarters_screen=%s" % [resolution, game.camera_controller.position, game.camera_controller.get_visible_world_rect(), game.camera_controller.world_to_screen(game.simulation_host.world.battle_definition.player_headquarters_position)])
			if not game.camera_controller.get_visible_world_rect().has_point(game.simulation_host.world.battle_definition.player_headquarters_position):
				failures.append("resize preserves visible starting army " + str(resolution))
			for priority in game.army_board._supply_priority_buttons.values():
				if not priority.is_visible_in_tree() or priority.size.x < 60 or priority.size.y < 20:
					failures.append("priority supply button readable " + str(resolution))
			for control in [game.army_board, game.minimap, game.task_panel]:
				if not viewport.encloses(control.get_global_rect()):
					failures.append("control outside viewport %s %s" % [control.name, resolution])
			if game.army_board.get_commander_card_count() != 4:
				failures.append("four battlegroup summaries required")
			if game.army_board.get_unit_card_button_count() != 0:
				failures.append("detachments collapsed by default")
			if game.command_desk.risk_label.visible or game.command_desk.reserve_label.visible:
				failures.append("advanced labels remain collapsed")
			if game.command_desk.exception_count.text != "0":
				failures.append("opening needs no routine decisions")
			await _activate(game.minimap._expand_button)
			if game.minimap._expanded_popup == null or not game.minimap._expanded_popup.visible:
				failures.append("keyboard opens tactical map")
			else:
				var popup := game.minimap._expanded_popup
				if popup.size.x > resolution.x or popup.size.y > resolution.y:
					failures.append("expanded map fits viewport")
				var content := popup.get_child(0) as VBoxContainer
				var old_position := game.camera_controller.position
				game.minimap._expanded_map.navigate_camera(game.minimap._expanded_map.size * 0.5)
				if game.camera_controller.position.is_equal_approx(old_position):
					failures.append("expanded map navigates camera")
				game.camera_controller.position = old_position
				await _activate(content.get_node("Close") as Button)
				if popup.visible: failures.append("keyboard closes tactical map")
			await _feedback19_controls(game)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/feedback19-ui-%s-%dx%d.png" % [locale,resolution.x,resolution.y])
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	for frame in range(6): await process_frame
	# Open the actual planning panel; exercise the route disclosure and group selectors.
	var panel := StaffPlanPanel.new()
	root.add_child(panel)
	panel.open_plans(game.simulation_host, &"blue_top_high")
	for frame in range(8): await process_frame
	if panel.current_plans == null:
		failures.append("actual UI generates tactical alternatives")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/final-ui-planning.png")
	panel.hide()
	panel.queue_free()
	await _verify_interaction(game)
	for failure in failures: push_error(failure)
	print("FEEDBACK19_UI failures=", failures)
	quit(0 if failures.is_empty() else 1)


func _activate(button: Button) -> void:
	button.grab_focus()
	await process_frame
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		button.get_viewport().push_input(event, true)
		await process_frame
	for frame in range(4): await process_frame


func _verify_interaction(game: GameRoot) -> void:
	TranslationServer.set_locale("zh_CN")
	game._on_language_changed("zh_CN")
	var camera := game.camera_controller
	var origin := game.simulation_host.world.battle_definition.player_headquarters_position
	for zoom_value in [0.9, 0.5, 0.2, 0.05, 0.02, 0.8]:
		camera.zoom_at_screen_position(camera.active_screen_rect.get_center(), zoom_value - camera.zoom.x)
		camera.center_on_world_position(origin)
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var rendered := root.get_texture().get_image()
		var pixels := 0
		var map_rect := camera.active_screen_rect.grow(-5)
		for x in range(int(map_rect.position.x), int(map_rect.end.x)):
			for y in range(int(map_rect.position.y), int(map_rect.end.y)):
				var color := rendered.get_pixel(x, y)
				if color.b > 0.55 and color.g > 0.4 and color.r < color.b * 0.72: pixels += 1
		if pixels < 18: failures.append("live army disappears at zoom " + str(zoom_value))
		for marker in game.world_presentation._strategic_units._markers:
			if marker.faction_id == 2 and not marker.remembered: failures.append("zoom reveals hidden enemy")
		rendered.save_png("res://artifacts/growth-live-zoom-%d.png" % roundi(zoom_value * 100))
		print("LIVE_ZOOM zoom=%.2f army_pixels=%d" % [zoom_value, pixels])
	# Actual viewport input selects a whole card, then pans the live camera.
	var unit_position: Vector2 = game.simulation_host.world.units[1].position
	await _click(camera.world_to_screen(unit_position))
	if game.input_controller.selected_entity_ids.is_empty(): failures.append("actual map click selects unit card")
	var old_position := camera.position
	var at := camera.active_screen_rect.get_center()
	await _button(at, MOUSE_BUTTON_MIDDLE, true)
	await _motion(at + Vector2(45, -25), Vector2(45, -25), MOUSE_BUTTON_MASK_MIDDLE)
	await _button(at + Vector2(45, -25), MOUSE_BUTTON_MIDDLE, false)
	if camera.position.is_equal_approx(old_position): failures.append("middle drag pans camera")
	var expected_priority: StringName = &"" if game.simulation_host.current_snapshot.get_faction(1).priority_commander_id == &"di_tian" else &"di_tian"
	var priority := game.army_board._supply_priority_buttons[&"di_tian"] as Button
	await _click(priority.get_global_rect().get_center())
	await _step(game)
	if game.simulation_host.current_snapshot.get_faction(1).priority_commander_id != expected_priority: failures.append("priority button changes authoritative allocation")
	var recon := game.support_panel.recon_button
	if not recon.disabled: failures.append("support affordability includes queued recruitment cost")
	# Advance real income/recruitment until this purchase can be made.
	game.simulation_host.set_tactical_paused(false)
	for tick in range(600):
		game.simulation_host.advance_tick()
		if game.simulation_host.get_available_support_supply() >= 20: break
	game.simulation_host.set_tactical_paused(true)
	for frame in range(16): await process_frame
	if recon.disabled: failures.append("support becomes affordable from actual income")
	await _activate(recon)
	await _motion(camera.active_screen_rect.get_center())
	if not game.world_presentation._area_preview_active: failures.append("recon mouse movement previews area")
	var supply := game.simulation_host.current_snapshot.get_faction(1).supply
	await _click(camera.active_screen_rect.get_center(), MOUSE_BUTTON_RIGHT)
	if game.world_presentation._area_preview_active or game.input_controller.command_mode == InputController.CommandMode.AREA_SUPPORT_TARGETING: failures.append("right click cancels area targeting")
	if game.simulation_host.current_snapshot.get_faction(1).supply != supply: failures.append("cancel consumes no supply")
	var enemy_position: Vector2 = game.simulation_host.world.units[1001].position
	camera.center_on_world_position(enemy_position)
	await _activate(recon)
	await _motion(camera.world_to_screen(enemy_position))
	await _click(camera.world_to_screen(enemy_position))
	await _step(game)
	var enemy := game.simulation_host.current_snapshot.get_unit(1001)
	if enemy == null or not enemy.is_visible_to_local_player: failures.append("map-targeted recon reveals moving enemy view")
	if game.simulation_host.current_snapshot.get_faction(1).supply != supply - 20: failures.append("recon UI pays displayed cost")
	if not recon.disabled or not recon.text.contains("60"): failures.append("recon cooldown visible after use")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/feedback19-ui-recon-active.png")


func _step(game: GameRoot) -> void:
	game.simulation_host.set_tactical_paused(false)
	game.simulation_host.advance_tick()
	game.simulation_host.set_tactical_paused(true)
	# The HUD intentionally spreads one snapshot across eleven refresh stages.
	for frame in range(16): await process_frame


func _click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await _motion(position)
	await _button(position, button, true)
	await _button(position, button, false)
	for frame in range(3): await process_frame


func _button(position: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _motion(position: Vector2, relative: Vector2 = Vector2.ZERO, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = mask
	root.push_input(event, true)
	await process_frame

func _feedback19_controls(game: GameRoot) -> void:
	var panel := game.support_panel
	var scroll := panel.get_node("Margin/Scroll") as ScrollContainer
	scroll.ensure_control_visible(panel._plan_toggle)
	for frame in range(3): await process_frame
	await _click(panel._plan_toggle.get_global_rect().get_center())
	if not panel._plan_box.visible: failures.append("plan opens through viewport input")
	if panel._plan_rates.size() != 4: failures.append("four group rates")
	for rate in panel._plan_rates.values(): rate.value = 1
	panel._plan_rates[&"di_tian"].value = 2
	panel._plan_reserve.value = 60
	scroll.ensure_control_visible(panel._plan_apply)
	for frame in range(3): await process_frame
	await _click(panel._plan_apply.get_global_rect().get_center())
	await _step(game)
	if game.simulation_host.current_snapshot.get_faction(1).recruitment_reserve != 60: failures.append("apply sets actual reserve")
	if not panel._economy_label.text.contains("60"): failures.append("reserve visible")
	panel._plan_reserve.value = 12
	await _click(panel._plan_apply.get_global_rect().get_center())
	await _step(game)
	scroll.ensure_control_visible(panel._plan_toggle)
	for frame in range(3): await process_frame
	await _click(panel._plan_toggle.get_global_rect().get_center())
	if panel._plan_box.visible: failures.append("plan collapses")
	scroll.scroll_vertical = 0
