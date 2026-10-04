extends "res://tests/tools/final_decision_ui_smoke.gd"

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var game := load("res://scenes/game/final_decision.tscn").instantiate() as GameRoot
	root.add_child(game)
	current_scene = game
	for frame in range(12): await process_frame
	game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	var world := game.simulation_host.world
	var faction := world.factions[1] as FactionState
	faction.supply = 300
	for tick in range(12):
		await _step(game)
		if faction.population > 48: break
	var highlighted := 0
	for unit in game.simulation_host.current_snapshot.units:
		if unit.faction_id == 1 and unit.reinforced_until_tick > world.current_tick: highlighted += 1
	if highlighted != 5: failures.append("actual five new recruits highlighted")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/feedback19-new-recruits.png")
	# Isolate area effects at a real neutral battlefield node, away from friendly supply.
	var position: Vector2 = world.strategic_regions[&"blue_mid_outer"].position
	var friendly := world.units[2] as UnitState
	friendly.position = position
	friendly.health = 10
	friendly.has_move_target = false
	friendly.following_formation = false
	game.camera_controller.center_on_world_position(position)
	await _step(game)
	await _activate(game.support_panel.frontline_logistics_button)
	await _motion(game.camera_controller.world_to_screen(position))
	await _click(game.camera_controller.world_to_screen(position))
	await _step(game)
	var hospital_found := false
	for effect in game.simulation_host.current_snapshot.area_support_effects:
		if effect.support_kind == SupportOrderCommand.SupportKind.FIELD_HOSPITAL: hospital_found = true
	if not hospital_found or friendly.health <= 10: failures.append("map click deploys and heals at neutral battlefield")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/feedback19-field-hospital.png")
	await _activate(game.support_panel.fire_support_button)
	await _motion(game.camera_controller.world_to_screen(position))
	await _click(game.camera_controller.world_to_screen(position))
	await _step(game)
	if not game.support_panel._economy_label.text.contains(GameText.t(&"AREA_MISSILE_WARNING")): failures.append("offscreen missile warning is visible in HUD")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/feedback19-missile-warning.png")
	var health_before := friendly.health
	for tick in range(42):
		game.simulation_host.set_tactical_paused(false)
		game.simulation_host.advance_tick()
		game.simulation_host.set_tactical_paused(true)
	for frame in range(16): await process_frame
	if friendly.health >= health_before: failures.append("visible strike actually damages friendly unit")
	if not game.support_panel._economy_label.text.contains(GameText.t(&"AREA_MISSILE_IMPACT")): failures.append("impact confirmation in HUD")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/feedback19-missile-impact.png")
	# Legion subject names must replace duplicate card names in every group alert.
	for card: UnitCardState in world.unit_cards.values():
		if card.faction_id == 1: card.last_damage_tick = world.current_tick
	await _step(game)
	var alerts := game.command_desk.current_command_situation.exceptions
	var seen: Array[StringName] = []
	for alert in alerts:
		if alert.kind != CommandExceptionSnapshot.Kind.UNDER_ATTACK: continue
		if seen.has(alert.commander_id): failures.append("duplicate legion attack alert")
		seen.append(alert.commander_id)
		var commander := game.simulation_host.current_snapshot.get_commander(alert.commander_id)
		if not game.command_desk._exception_text(alert).contains(GameText.t(commander.display_name_key)): failures.append("alert has unique legion name")
	if seen.size() != 4: failures.append("four independent legion alerts")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/feedback19-legion-alerts.png")
	for failure in failures: push_error(failure)
	print("FEEDBACK19_VISUAL failures=",failures)
	quit(0 if failures.is_empty() else 1)
