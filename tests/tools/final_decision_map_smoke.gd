extends SceneTree


func _initialize() -> void:
	var failures := TestFinalDecisionMap.new().run()
	for failure in failures:
		push_error(failure)
	print("FINAL_DECISION_MAP failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
