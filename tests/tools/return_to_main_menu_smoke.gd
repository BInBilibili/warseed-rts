extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := await _add_game()
	if game != null:
		var pause_menu := game.get_node("PauseMenu") as PauseMenu
		_expect(pause_menu.operations_button.text == GameText.t(&"RETURN_TO_MAIN_MENU"), "pause button uses the main-menu translation")
		_expect(pause_menu.return_confirmation.dialog_text == GameText.t(&"RETURN_TO_MAIN_MENU_CONFIRM_BODY"), "pause confirmation explains returning to the main menu")
		pause_menu._return_to_operations()
		await _wait_for_main_menu()
		_expect(current_scene is MainMenu, "pause-menu confirmation returns to the main menu")
		if current_scene != null:
			current_scene.queue_free()

	game = await _add_game()
	if game != null:
		var debrief := game.battle_debrief
		_expect(debrief.return_to_operations_button.text == GameText.t(&"RETURN_TO_MAIN_MENU"), "debrief button uses the main-menu translation")
		debrief._on_return_to_operations_pressed()
		await _wait_for_main_menu()
		_expect(current_scene is MainMenu, "debrief button returns to the main menu")
		if current_scene != null:
			current_scene.queue_free()

	var selector := (load("res://scenes/game/battle_selector.tscn") as PackedScene).instantiate() as BattleSelector
	root.add_child(selector)
	current_scene = selector
	for _index in range(4):
		await process_frame
	if selector != null:
		_expect(selector.main_menu_button.text == GameText.t(&"RETURN_TO_MAIN_MENU"), "operation selector exposes the localized main-menu button")
		selector._return_to_main_menu()
		await _wait_for_main_menu()
		_expect(current_scene is MainMenu, "operation selector button returns to the main menu")
		if current_scene != null:
			current_scene.queue_free()

	if _failures.is_empty():
		print("WARSEED_RETURN_TO_MAIN_MENU_SMOKE PASS pause=main_menu debrief=main_menu selector=main_menu locales=2")
		quit(0)
		return
	for failure in _failures:
		push_error("RETURN_TO_MAIN_MENU_SMOKE FAILED: " + failure)
	quit(1)


func _add_game() -> GameRoot:
	var game := (load("res://scenes/game/grey_ridge.tscn") as PackedScene).instantiate() as GameRoot
	root.add_child(game)
	current_scene = game
	for _index in range(4):
		await process_frame
	return game


func _wait_for_main_menu() -> void:
	for _index in range(20):
		if current_scene is MainMenu:
			return
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
