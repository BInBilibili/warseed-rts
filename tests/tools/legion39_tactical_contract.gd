extends SceneTree

func _initialize() -> void:
	var failures := TestTacticalCards.new().run()
	FileAccess.open("res://artifacts/legion39/tactical.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED","failures":failures,"scope":"existing tactical suite plus lexical completion/identification/interruption under reversed insertion"}))
	print("LEGION39_TACTICAL failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
