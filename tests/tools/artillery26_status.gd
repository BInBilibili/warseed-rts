extends SceneTree
func _initialize() -> void:
	var failures: Array[String] = []
	TestGameIntegration.new()._test_tactical_card_status(failures)
	print("ARTILLERY26_STATUS failures=", failures)
	quit(0 if failures.is_empty() else 1)
