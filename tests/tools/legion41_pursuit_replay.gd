extends "res://tests/tools/legion41_protected_pursuit.gd"

const Baseline = preload("res://tests/tools/legion41_pursuit_lab.gd")

func _initialize() -> void:
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/legion34/v5/config.json")).profiles
	actual_map = load("res://data/maps/final_decision.tres") as MapDefinition
	var baseline = Baseline.new()
	baseline.profiles = profiles
	baseline.actual_map = actual_map
	var rows: Array[Dictionary] = []
	for variant in ["matrix02", "protected01"]:
		var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/legion41/"+variant+".json"))
		for profile in range(5):
			for count in [12, 60]:
				# Immediate covers all profiles/sizes; delayed covers the distinct
				# sentinel/ranger failures and ranger's reversed small-army result.
				for delay in ([0, 30] if profile in [3, 4] else [0]):
					var current: Dictionary = baseline.run_pursuit(profile,count,delay,false) if variant == "matrix02" else run_pursuit(profile,count,delay,false)
					var expected: Dictionary = {}
					for row in reference.results:
						if row.profile == profiles[profile].id and int(row.count) == count and int(row.delay) == delay and not row.mirror:
							expected = row
					# Compare parsed JSON values: persisted numeric types match.
					var persisted: Dictionary = JSON.parse_string(JSON.stringify(current))
					var equal := persisted == expected
					rows.append({"variant":variant,"profile":profiles[profile].id,"count":count,"delay":delay,"equal":equal,"result":current})
					FileAccess.open("res://artifacts/legion41/replay01-partial.json",FileAccess.WRITE).store_string(JSON.stringify({"results":rows,"complete":false}))
					print("LEGION41_REPLAY_PROGRESS ",variant," ",profiles[profile].id," count=",count," delay=",delay," equal=",equal)
	baseline.free()
	var failed := rows.any(func(r: Dictionary) -> bool: return not r.equal or not r.result.invariant_failures.is_empty())
	FileAccess.open("res://artifacts/legion41/replay01.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PROTOTYPE","repeat_pairs":rows.size(),"results":rows,"failed":failed}))
	print("LEGION41_REPLAY_DONE pairs=",rows.size()," failed=",failed)
	quit(1 if failed else 0)
