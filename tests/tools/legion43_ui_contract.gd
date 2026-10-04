extends SceneTree

var checks := 0
var failures: Array[String] = []
var output := "res://artifacts/legion43/ui02.json"

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value and not failures.has(reason): failures.append(reason)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	var game := load("res://scenes/game/final_decision.tscn").instantiate() as GameRoot
	root.add_child(game); current_scene=game
	for frame in range(4): await process_frame
	game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	for frame in range(4): await process_frame
	game.set_process(false); game.simulation_host.set_process(false)
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.advance_tick()
	var snapshot := world.create_faction_snapshot(1)
	game.simulation_host.current_snapshot=snapshot
	var reasons: Array[StringName] = [&"PENDING",&"REGROUPING",&"PLAYER_CONTROL",&"COMMAND_HOLD",&"NO_CORE",&"INVALID_PROFILE",&"EXPOSED",&"PATH_UNAVAILABLE",&"PROTECTED_TARGET",&"IN_POSITION",&"FORMING"]
	var localized: Array[String] = []
	for language in ["zh_CN","en"]:
		TranslationServer.set_locale(language); game._on_language_changed(language)
		for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1600),Vector2i(640,800),Vector2i(480,800)]:
			root.size=resolution; root.content_scale_size=resolution
			for reason in reasons:
				for commander in snapshot.commanders: commander.legion_formation.reason=reason
				game.army_board.update_snapshot(snapshot)
				for frame in range(3):
					game._apply_grey_ridge_hud_layout()
					await process_frame
				check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(game.army_board.get_global_rect()),"board stays in viewport "+language+str(resolution))
				check(game.army_board.get_global_rect().encloses(game.army_board.commander_row.get_global_rect()),"all legion controls stay within board "+language+str(resolution))
				for commander in snapshot.commanders:
					var button: Button = game.army_board._commander_buttons[commander.definition_id]
					var message := GameText.t(commander.legion_formation.reason_key())
					check(message!=String(commander.legion_formation.reason_key()),"reason localized "+language+String(reason))
					check(button.text.contains(message) and button.tooltip_text.contains(message),"visible status and detail show current protection reason")
					check(button.tooltip_text.contains(GameText.t(&"LEGION_FORMATION_SPEED") % commander.legion_formation.core_speed),"pace detail uses own current value snapshot")
					var font := button.get_theme_font("font")
					var style := button.get_theme_stylebox("normal")
					var width := button.size.x-style.get_content_margin(SIDE_LEFT)-style.get_content_margin(SIDE_RIGHT)
					var size := font.get_multiline_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,width,button.get_theme_font_size("font_size"),-1,TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE)
					check(button.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART,"full status wraps instead of clipping")
					check(size.y<=button.size.y,"status height fits "+language+str(resolution))
					check(size.x<=width+0.1,"status width fits "+language+str(resolution)+String(reason))
					check(game.army_board.get_global_rect().encloses(button.get_global_rect()),"commander status stays within board")
		localized.append(GameText.t(&"LEGION_FORMATION_FORMING"))
	check(localized[0]!=localized[1],"live locale change updates formation wording")
	game.free()
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_HEADLESS_UI","checks":checks,"failures":failures,"locales":2,"sizes":5,"reasons":11,"rendered_pixels":"NOT_RUN","scope":"actual ArmyBoard status and tooltip layout using own value snapshots; representative reason fixtures"}))
	print("LEGION43_UI checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
