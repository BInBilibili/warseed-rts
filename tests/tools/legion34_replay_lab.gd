extends "res://tests/tools/legion34_narrow_relief_lab.gd"

func _initialize() -> void:
	profiles=JSON.parse_string(FileAccess.get_file_as_string(NARROW_OUT+"config.json")).profiles
	actual_map=load("res://data/maps/final_decision.tres") as MapDefinition
	for profile in range(5):
		for scenario in ["gather","cut"]:
			var first:=transition(profile,12,scenario,false)
			var second:=transition(profile,12,scenario,false)
			var same:=JSON.stringify(first)==JSON.stringify(second)
			results.append({"key":first.key,"identical":same,"trace":first.trace})
			if not same:errors.append(first.key)
		print("REPLAY_PROGRESS ",profile)
	for scenario in ["normal","permanent_stop"]:
		var first:=passage(60,scenario,false)
		var second:=passage(60,scenario,false)
		var same:=JSON.stringify(first)==JSON.stringify(second)
		results.append({"key":first.key,"identical":same,"trace":first.trace})
		if not same:errors.append(first.key)
	FileAccess.open(NARROW_OUT+"replay.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PROTOTYPE","pairs":results.size(),"results":results,"errors":errors}))
	print("REPLAY_DONE pairs=",results.size()," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)
