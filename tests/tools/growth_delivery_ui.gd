extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var selector := load("res://scenes/game/battle_selector.tscn").instantiate() as BattleSelector
	root.add_child(selector)
	current_scene = selector
	await frames(10)
	check(selector.get_selected_battle().scenario_id == &"final_decision", "independent growth default")
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		selector.refresh_locale()
		for resolution in [Vector2i(1280,720), Vector2i(640,800), Vector2i(480,800)]:
			root.size = resolution
			root.content_scale_size = resolution
			await frames(12)
			check(selector.briefing_label.text.contains("26") and selector.briefing_label.text.contains("48"), "selector describes current population and map")
			await click(selector._mode_buttons[1])
			check(selector.get_selected_battle().scenario_id == &"grey_ridge" and not selector.get_battle_button(&"final_decision").visible, "legacy mode remains selectable")
			await click(selector._mode_buttons[0])
			check(selector.get_selected_battle().scenario_id == &"final_decision" and not selector.get_battle_button(&"grey_ridge").visible, "growth and legacy lists separated")
			check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(selector.deploy_button.get_global_rect()), "deploy fits viewport")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/growth-selector-%s-%dx%d.png" % [locale,resolution.x,resolution.y])
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await frames(10)
	await click(selector.deploy_button)
	await frames(20)
	var game := current_scene as GameRoot
	check(game != null, "selector deploy opens real growth scene")
	if game == null:
		finish()
		return
	await click(game.prebattle_planner.start_button)
	game.simulation_host.set_tactical_paused(true)
	await frames(20)
	check(game.simulation_host.world.factions[1].population == 48 and game.simulation_host.world.factions[2].population == 48, "real prebattle starts small armies")
	# Explicit end-of-match fixture only for host/debrief/save/restart flow.
	# Natural game durations and winners come from growth_match_selfplay.gd.
	game.simulation_host.world.current_tick = game.simulation_host.world.battle_definition.time_limit_ticks - 1
	game.simulation_host.set_tactical_paused(false)
	game.simulation_host.advance_tick()
	await frames(24)
	check(game.simulation_host.current_snapshot.outcome.result == BattleOutcome.Result.DRAW, "host reaches terminal draw")
	var record := game.simulation_host.get_campaign_record()
	check(record.get("last_result") == "draw", "host saved growth outcome")
	check(not _has_visible_legacy_purchase(game.battle_debrief), "growth debrief hides legacy purchases")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/growth-delivery-debrief.png")
	check(game.simulation_host.restart_grey_ridge(), "restart succeeds")
	await frames(20)
	check(game.simulation_host.world.factions[1].population == 48 and game.simulation_host.world.factions[1].supply == 24, "restart resets independent growth economy")
	check(game.camera_controller.get_visible_world_rect().has_point(game.simulation_host.world.battle_definition.player_headquarters_position), "restart returns camera to own HQ")
	finish()

func click(control: Control) -> void:
	check(control.is_visible_in_tree(), "click target visible " + control.name)
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await frames(6)

func frames(count: int) -> void:
	for i in range(count): await process_frame

func check(value: bool, detail: String) -> void:
	if not value: failures.append(detail)

func _has_visible_legacy_purchase(node: Node) -> bool:
	for child in node.get_children():
		if child is Button and (child as Button).visible and ((child as Button).text.contains("补员") or (child as Button).text.to_lower().contains("replenish")):
			return true
		if _has_visible_legacy_purchase(child): return true
	return false

func finish() -> void:
	for failure in failures: push_error(failure)
	print("GROWTH_DELIVERY_UI failures=",failures)
	quit(0 if failures.is_empty() else 1)
