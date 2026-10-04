extends SceneTree

func _initialize() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	RuntimeMeasurement.reset()
	RuntimeMeasurement.enabled = true
	var rows: Array[Dictionary] = []
	for target_id in [&"blue_base",&"blue_mid_high",&"blue_mid_outer",&"red_mid_outer",&"red_base",&"jungle_upper_major"]:
		var region := world.strategic_regions[target_id] as StrategicRegionState
		var command := CommanderOrderCommand.new(world.allocate_command_id(),1,world.current_tick,&"mobile_legion",CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE,region.position,target_id)
		command.apply_requested_posture = true
		command.hand_back_control = true
		var times: Array[int] = []
		var results: Array[String] = []
		for repeat in range(2):
			var started := Time.get_ticks_usec()
			var result := world.validate_command(command)
			times.append(Time.get_ticks_usec()-started)
			results.append(result.describe())
		rows.append({"target":target_id,"first_usec":times[0],"cached_usec":times[1],"results":results})
	var report := {"evidence":"SIMULATED","fixture":"initial mobile legion, six public objectives, full authoritative validation twice each; no mutation or worker join","rows":rows,"measurements":RuntimeMeasurement.summary()}
	RuntimeMeasurement.enabled = false
	var report_path := "res://artifacts/perf25-command-measure01.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF25_COMMAND_MEASURE ",JSON.stringify(report))
	quit()
