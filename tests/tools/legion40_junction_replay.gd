extends "res://tests/tools/legion40_junction_lab.gd"

func _initialize() -> void:
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/legion34/v5/config.json")).profiles
	actual_map = load("res://data/maps/final_decision.tres") as MapDefinition
	var rows: Array[Dictionary] = []
	for count in [12,60]:
		for scenario in ["normal","manual_resumes","permanent_stop","exit_occupied"]:
			var first := junction(count,scenario,false)
			var second := junction(count,scenario,false)
			var equal := first == second
			rows.append({"count":count,"scenario":scenario,"equal":equal,"first":first,"second":second})
			FileAccess.open("res://artifacts/legion40/replay01-partial.json",FileAccess.WRITE).store_string(JSON.stringify({"results":rows,"complete":false}))
			print("LEGION40_REPLAY_PROGRESS count=",count," scenario=",scenario," equal=",equal)
	var failed := rows.any(func(r: Dictionary) -> bool: return not r.equal or not r.first.failures.is_empty() or not r.second.failures.is_empty())
	FileAccess.open("res://artifacts/legion40/replay01.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PROTOTYPE","pairs":rows.size(),"results":rows,"failed":failed}))
	print("LEGION40_REPLAY pairs=",rows.size()," failed=",failed)
	quit(1 if failed else 0)
