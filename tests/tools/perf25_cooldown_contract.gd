extends SceneTree

func _initialize() -> void:
	TranslationServer.set_locale("en")
	var failures: Array[String] = []
	TestGameIntegration.new()._test_contextual_card_actions(failures)
	print("PERF25_COOLDOWN_CONTRACT failures=", failures)
	quit(0 if failures.is_empty() else 1)
