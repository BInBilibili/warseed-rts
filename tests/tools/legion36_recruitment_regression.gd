extends "res://tests/tools/legion35_recruitment_contract.gd"

func _initialize() -> void:
	test_atomic()
	test_queued_slots()
	test_application_boundaries()
	test_occupied_birth()
	test_growth()
	FileAccess.open("res://artifacts/legion36/recruitment.json", FileAccess.WRITE).store_string(JSON.stringify({"evidence": "SIMULATED", "checks": checks, "failures": failures, "steps": steps, "scope": "legion35 actual birth regression on legion36 runtime; synthetic funding"}))
	print("LEGION36_RECRUITMENT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
