extends "res://tests/tools/legion44_equal_distance_pursuit.gd"

func _initialize() -> void:
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/legion34/v5/config.json")).profiles
	actual_map = load("res://data/maps/final_decision.tres") as MapDefinition
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/legion44/matrix01.json"))
	var rows: Array[Dictionary] = []
	for profile in range(5):
		for count in [12,60]:
			for delay in [0,30]:
				var current := run_pursuit(profile,count,delay,false)
				var expected: Dictionary = {}
				for row in reference.results:
					if row.profile == profiles[profile].id and int(row.count) == count and int(row.delay) == delay and not row.mirror:
						expected = row
				var persisted: Dictionary = JSON.parse_string(JSON.stringify(current))
				var equal := persisted == expected
				rows.append({"profile":profiles[profile].id,"count":count,"delay":delay,"equal":equal,"result":current})
				FileAccess.open("res://artifacts/legion44/replay01-partial.json",FileAccess.WRITE).store_string(JSON.stringify({"results":rows,"complete":false}))
				print("LEGION44_REPLAY_PROGRESS ",profiles[profile].id," count=",count," delay=",delay," equal=",equal)
	var failed := rows.any(func(r: Dictionary) -> bool: return not r.equal or not r.result.invariant_failures.is_empty())
	FileAccess.open("res://artifacts/legion44/replay01.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PROTOTYPE","repeat_pairs":rows.size(),"results":rows,"failed":failed}))
	print("LEGION44_REPLAY_DONE pairs=",rows.size()," failed=",failed)
	quit(1 if failed else 0)
