extends SceneTree

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1600), Vector2i(640, 800), Vector2i(480, 800)]
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		for resolution in RESOLUTIONS:
			root.size = resolution
			root.content_scale_size = resolution
			var selector := (load("res://scenes/game/battle_selector.tscn") as PackedScene).instantiate() as BattleSelector
			selector.scene_changes_enabled = false
			root.add_child(selector)
			await _settle()
			var context := "%s %s" % [locale, resolution]
			_expect(not selector.deploy_button.has_focus(), context + " entering selector does not focus deploy")
			await _click(selector._mode_buttons[1].get_global_rect().get_center())
			_expect(not selector.get_selected_battle().growth_mode, context + " mouse mode selection works")
			_expect(not selector.deploy_button.has_focus(), context + " mode selection does not steal focus")
			var battle_button := selector.get_battle_button(&"broken_bridge")
			await _click(battle_button.get_global_rect().get_center())
			_expect(selector.get_selected_battle().scenario_id == &"broken_bridge", context + " mouse operation selection works")
			_expect(not selector.deploy_button.has_focus(), context + " operation selection does not focus deploy")
			selector.deploy_button.grab_focus()
			await _click(Vector2(4, 4))
			_expect(not selector.deploy_button.has_focus(), context + " background click clears previous focus")
			await _key(KEY_TAB)
			_expect(root.gui_get_focus_owner() != null, context + " Tab can still navigate")
			battle_button.grab_focus()
			await _key(KEY_ENTER)
			_expect(battle_button.has_focus(), context + " keyboard operation selection keeps focus on operation")
			var request: Dictionary = {}
			selector.battle_requested.connect(func(id: StringName, path: String) -> void:
				request["id"] = id
				request["path"] = path
			)
			selector.deploy_button.grab_focus()
			await _key(KEY_ENTER)
			_expect(request.get("id", &"") == &"broken_bridge", context + " keyboard deploy still activates selected operation")
			selector.free()
	if _failures.is_empty():
		print("WARSEED_BATTLE_SELECTOR_FOCUS_SMOKE PASS locales=2 resolutions=5 mouse=mode,operation,background keyboard=Tab,Enter")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await _settle()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event)
		await _settle()


func _settle() -> void:
	for _index in range(3):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
