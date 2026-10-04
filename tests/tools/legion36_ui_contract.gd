extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var game := load("res://scenes/game/final_decision.tscn").instantiate() as GameRoot
	root.add_child(game)
	current_scene = game
	for frame in range(4): await process_frame
	game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	for frame in range(4): await process_frame
	# The real scene normally refreshes these panels from its host each frame.
	# Freeze that publisher while exercising an independent legal fixture.
	game.set_process(false)
	game.simulation_host.set_process(false)
	# Build a legal, independent snapshot with a genuine 3/5 supply reservation.
	var fixture := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	fixture.current_tick = 300
	fixture.factions[1].supply = 15
	var owner: StringName
	for commander: CommanderState in fixture.commanders.values():
		if commander.faction_id != 1: continue
		var selected := commander.definition.profile.profile_id == &"spear"
		fixture.factions[1].recruitment_rates[commander.definition.definition_id] = 1 if selected else 0
		if selected: owner = commander.definition.definition_id
	RecruitmentArbitrationSystem.refresh(fixture, 1)
	var snapshot := fixture.create_faction_snapshot(1)
	game.simulation_host.current_snapshot = snapshot
	var faction := snapshot.get_faction(1)
	check(faction.recruitment_arbitration.reserved_amount == 3, "UI fixture produced actual reservation")
	var reasons: Array[StringName] = [&"GROWTH_WAIT_FULL", &"GROWTH_WAIT_PAUSED", &"GROWTH_WAIT_HERO", &"GROWTH_WAIT_CONTROL", &"GROWTH_WAIT_REBUILD", &"GROWTH_WAIT_UNSAFE", &"GROWTH_WAIT_OUT_OF_SUPPLY", &"GROWTH_WAIT_WINDOW", &"GROWTH_WAIT_READY", &"GROWTH_WAIT_QUEUED", &"GROWTH_WAIT_POPULATION", &"GROWTH_WAIT_RESERVE", &"GROWTH_WAIT_SAVING", &"GROWTH_WAIT_OTHER", &"GROWTH_WAIT_FUNDS", &"GROWTH_WAIT_SPACE", &"GROWTH_WAIT_RECHECK"]
	var localized: Array[String] = []
	for language in ["zh_CN", "en"]:
		TranslationServer.set_locale(language)
		game._on_language_changed(language)
		for reason in reasons:
			faction.recruitment_arbitration.reasons[owner] = reason
			check(GameText.t(reason) != String(reason), "wait reason localized " + language + String(reason))
			check(TacticalHelp.recruitment_status(faction, owner).contains(GameText.t(reason)), "help preserves reason")
		faction.recruitment_arbitration.reasons[owner] = &"GROWTH_WAIT_SAVING"
		localized.append(TacticalHelp.recruitment_status(faction, owner))
		for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1600), Vector2i(640, 800), Vector2i(480, 800)]:
			root.size = resolution
			root.content_scale_size = resolution
			game.army_board.update_snapshot(snapshot)
			game.support_panel.update_snapshot(snapshot)
			for frame in range(6): await process_frame
			var board := game.army_board
			var panel := game.support_panel
			var detail := GameText.t(&"GROWTH_SAVING_DETAIL") % [3, 5]
			check(board._supply_priority_buttons.size() == 5, "five legion controls " + str(resolution))
			check(panel._economy_label.text.contains(detail), "economy displays actual held/cost " + language + str(resolution))
			check(panel._economy_label.text.contains(GameText.t(snapshot.get_commander(owner).display_name_key)), "economy identifies reservation owner")
			check(panel._economy_label.tooltip_text.contains(GameText.t(&"GROWTH_SAVING_HELP")), "soft reservation explanation available")
			check(board._supply_priority_buttons[owner].tooltip_text.contains(detail), "legion tooltip displays actual held/cost")
			check(board._commander_buttons[owner].text.contains(GameText.t(&"GROWTH_WAIT_SAVING")), "legion card shows saving reason")
			check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(board.get_global_rect()), "army board stays inside viewport " + str(resolution))
			check(panel._economy_label.size.x <= panel.size.x, "economy wraps inside support panel")
			for button: Button in board._commander_buttons.values():
				var font := button.get_theme_font("font")
				var font_size := button.get_theme_font_size("font_size")
				var text_height := font.get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y
				check(text_height <= button.size.y, "commander status lines fit height " + str(resolution))
	check(localized.size() == 2 and localized[0] != localized[1], "runtime locale refresh changes waiting text")
	# Release is visible on the next value snapshot, without stale owner text.
	faction.recruitment_arbitration.clear_reservation()
	faction.recruitment_arbitration.reasons[owner] = &"GROWTH_WAIT_READY"
	game.support_panel.update_snapshot(snapshot)
	game.army_board.update_snapshot(snapshot)
	check(not game.support_panel._economy_label.text.contains(GameText.t(&"GROWTH_SAVING_DETAIL") % [3, 5]), "released reservation disappears")
	game.free()
	for failure in failures: push_error(failure)
	FileAccess.open("res://artifacts/legion36/ui.json", FileAccess.WRITE).store_string(JSON.stringify({"evidence": "SIMULATED_HEADLESS_UI", "checks": checks, "failures": failures, "rendered_pixels": "NOT_RUN", "scope": "actual ArmyBoard and SupportPanel, two locales and five sizes, waiting text and reservation lifecycle"}))
	print("LEGION36_UI checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
