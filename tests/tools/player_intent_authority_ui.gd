extends SceneTree

var failures: Array[String] = []
var checks := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); print("FAIL ", message)


func _initialize() -> void:
	call_deferred("run")


func publish(game: GameRoot) -> void:
	var snapshot := game.simulation_host.current_snapshot
	game.army_board.update_snapshot(snapshot)
	var view := game.simulation_host.get_presentation_view(snapshot)
	game.command_desk.update_command_situation(snapshot, view.command_situation)


func step(game: GameRoot) -> void:
	game.simulation_host.set_tactical_paused(false)
	game.simulation_host.advance_tick()
	game.simulation_host.set_tactical_paused(true)
	publish(game)


func run() -> void:
	await BattleLoadingScreen.enter_final_battle(self, "res://scenes/game/final_decision.tscn")
	var game := current_scene as GameRoot
	await game.prebattle_planner._start_battle()
	var host := game.simulation_host
	host.set_tactical_paused(true)
	host.set_process(false)
	host.background_simulation_enabled = false
	host._finish_background_tick(true)
	game.set_process(false)
	for frame in range(3): await process_frame
	publish(game)
	var commander_id := &"di_tian"
	var commander := host.world.commanders[commander_id] as CommanderState
	var baseline_version := commander.authority_version
	var baseline_queue := host.get_queue_size()
	game.input_controller.select_commander_card(commander_id)
	game.input_controller.cancel_command_mode()
	check(host.get_queue_size() == baseline_queue and commander.authority_version == baseline_version, "selection and Esc do not submit control")
	game.army_board._set_commander_posture(5, commander_id)
	check(host.get_queue_size() > baseline_queue and commander.intent_mode == CommanderState.IntentMode.AUTONOMOUS, "force UI accepts pending without changing paused authority")
	check(game.input_controller.last_command_status == GameText.t(&"AUTHORITY_RECEIPT_QUEUED"), "UI distinguishes queue acceptance from execution")
	step(game)
	check(commander.intent_mode == CommanderState.IntentMode.FORCE_ATTACK, "force UI applies through simulation pipeline")
	check((game.army_board._posture_menus[commander_id] as OptionButton).selected == 5, "force menu reflects executed mode")
	check(PlayerIntentPresenter.detail(host.current_snapshot.get_commander(commander_id), host.current_snapshot).contains(GameText.t(&"AUTHORITY_FORCE_RISK")), "force detail explains organizational risk")
	var card := host.world.unit_cards[commander.subordinate_unit_card_ids[1]] as UnitCardState
	var formation := host.world.formations[card.formation_id] as FormationState
	var stop := StopCommand.new(host.allocate_command_id(), 1, GameCommand.IssuerKind.PLAYER, host.world.current_tick, formation.leader_entity_id, formation.formation_id)
	check(host.submit_command(stop).is_accepted(), "manual stop via host accepted")
	step(game)
	check(PlayerIntentPresenter.detail(host.current_snapshot.get_commander(commander_id), host.current_snapshot).contains(GameText.t(card.definition.display_name_key)), "commander tooltip names manual card")
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		game.army_board.refresh_locale()
		game.command_desk.refresh_locale()
		publish(game)
		for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1600), Vector2i(640, 800), Vector2i(480, 800)]:
			root.size = resolution
			root.content_scale_size = resolution
			game._hud_layout_signature = ""
			for frame in range(6):
				game._apply_grey_ridge_hud_layout()
				await process_frame
			var board := game.army_board
			var rect := board.get_global_rect()
			check(rect.position.y >= -1 and rect.end.y <= resolution.y + 1, "authority board fits %s %s" % [locale, resolution])
			check(board._posture_menus.size() == 5, "five commander authority controls")
			for value in board._posture_menus.values():
				var menu := value as OptionButton
				check(menu.item_count == 8 and menu.get_item_text(5) == GameText.t(&"AUTHORITY_FORCE_ACTION") and menu.get_item_text(7) == GameText.t(&"AUTHORITY_RETURN_ACTION"), "authority menu localized")
				check(menu.get_global_rect().end.y <= rect.end.y + 1 and menu.get_global_rect().size.y >= 30, "authority action reachable within existing board")
			var text := PlayerIntentPresenter.detail(host.current_snapshot.get_commander(commander_id), host.current_snapshot)
			check(not text.contains("AUTHORITY_") and text.contains(GameText.t(&"AUTHORITY_MODE_FORCE_ATTACK")), "authority detail uses translated legal snapshot")
	game.army_board._set_commander_posture(6, commander_id)
	step(game)
	check(commander.intent_mode == CommanderState.IntentMode.HOLD and not card.persistent_manual, "cancel UI holds entire legion and releases individual override")
	check(commander.intent_receipt == CommanderState.IntentReceipt.CANCELLED, "cancel reports actual cancellation")
	game.army_board._set_commander_posture(7, commander_id)
	step(game)
	check(commander.intent_mode == CommanderState.IntentMode.AUTONOMOUS and commander.player_route.is_empty() and commander.active_intent_id.is_empty(), "return UI restores autonomy without reviving old intent")
	var output := "res://artifacts/control-contract/ui.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var report := {"checks": checks, "failures": failures, "evidence": "SIMULATED_HEADLESS_REAL_FINAL_SCENE", "locales": ["zh_CN", "en"], "viewports": 5, "HUMAN": "NOT_RUN", "FPS": "NOT_RUN"}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report))
	print("AUTHORITY_UI ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
