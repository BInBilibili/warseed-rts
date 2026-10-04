extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, why: String) -> void:
	if not value: failures.append(why)
func run() -> void:
	var session := ArmyRosterStore.active_playtest_session_id()
	if not session.begins_with("legion22-history"):
		quit(2)
		return
	var path := ArmyRosterStore.campaign_record_path_for_session(session,&"final_decision")
	var original := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var record := ArmyRosterStore.build_battle_record(original.create_snapshot(),{},&"final_decision")
	check(ArmyRosterStore.save_record_result(record,path).is_success(),"write isolated seed")
	original = null
	await BattleLoadingScreen.enter_final_battle(self,"res://scenes/game/final_decision.tscn")
	var game := current_scene as GameRoot
	check(game.simulation_host.get_campaign_record().get("battle_count",0) == 1,"adoption preserves history")
	await game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	game.simulation_host.world.current_tick = game.simulation_host.world.battle_definition.time_limit_ticks-1
	game.simulation_host.set_tactical_paused(false)
	game.simulation_host.advance_tick()
	check(game.simulation_host.get_campaign_record().get("battle_count",0) == 2,"terminal saves one new battle")
	var loaded := ArmyRosterStore.load_record_result(path,false)
	check(loaded.is_success() and loaded.record.get("battle_count",0) == 2,"v4 roundtrip")
	game.queue_free()
	await process_frame
	# A malformed isolated file must not be replaced by an empty record.
	var bad := FileAccess.open(path,FileAccess.WRITE)
	bad.store_string("{invalid-isolated-roster")
	bad.close()
	var before := FileAccess.get_file_as_bytes(path)
	await BattleLoadingScreen.enter_final_battle(self,"res://scenes/game/final_decision.tscn")
	game = current_scene as GameRoot
	check(game.simulation_host._campaign_load_failed,"adoption retains failed-load guard")
	await game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	game.simulation_host.world.current_tick = game.simulation_host.world.battle_definition.time_limit_ticks-1
	game.simulation_host.set_tactical_paused(false)
	game.simulation_host.advance_tick()
	check(FileAccess.get_file_as_bytes(path) == before,"corrupt original bytes preserved")
	print("LEGION22_HISTORY ",failures)
	quit(0 if failures.is_empty() else 1)
