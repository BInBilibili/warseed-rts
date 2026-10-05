extends SceneTree

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1600),
	Vector2i(640, 800),
	Vector2i(480, 800),
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu := (load(MENU_SCENE) as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	var overlay := root.get_node_or_null("FpsOverlay")
	_expect(overlay != null, "global FPS overlay autoload is present")
	if overlay == null:
		_finish()
		return
	var fps_label := overlay.get_node_or_null("FpsLabel") as Label
	_expect(fps_label != null, "global FPS label is created")
	if fps_label == null:
		_finish()
		return

	var original_show_fps := bool(menu._settings.get_value("display", "show_fps", false))
	menu._set_show_fps(false)
	await process_frame
	_expect(not fps_label.visible, "FPS hides immediately when the setting is disabled")
	menu._set_show_fps(true)
	await process_frame
	_expect(fps_label.visible, "FPS shows immediately when the setting is enabled")
	menu._set_show_fps(false)

	for locale in ["zh_CN", "en"]:
		menu._set_language(1 if locale == "en" else 0)
		await process_frame
		_expect(menu._start_button.text == GameText.t(&"MAIN_MENU_START"), "main menu text refreshes for %s" % locale)
		_expect(menu._fps_toggle.text == GameText.t(&"MAIN_MENU_SHOW_FPS"), "FPS setting text refreshes for %s" % locale)

	for resolution in RESOLUTIONS:
		root.size = resolution
		root.content_scale_size = resolution
		await process_frame
		var panel_rect: Rect2 = (menu.get_node("Content") as Control).get_global_rect()
		if not (panel_rect.position.x >= 0.0 and panel_rect.end.x <= resolution.x):
			_failures.append("menu panel fits width at %s rect=%s viewport=%s" % [resolution, panel_rect, root.get_visible_rect()])
		_expect(panel_rect.position.y >= 0.0 and panel_rect.end.y <= resolution.y, "menu panel fits height at %s" % resolution)

	menu._set_show_fps(true)
	var selector := (load("res://scenes/game/battle_selector.tscn") as PackedScene).instantiate() as BattleSelector
	root.add_child(selector)
	await process_frame
	_expect(root.get_node_or_null("FpsOverlay") == overlay, "FPS overlay persists across scene changes")
	_expect(fps_label.visible, "FPS remains visible after changing scenes")
	menu._set_show_fps(original_show_fps)
	selector.queue_free()
	menu.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("WARSEED_MAIN_MENU_SMOKE PASS resolutions=%d locales=2 fps_toggle=immediate" % RESOLUTIONS.size())
		quit(0)
		return
	for failure in _failures:
		push_error("MAIN_MENU_SMOKE FAILED: " + failure)
	print("WARSEED_MAIN_MENU_SMOKE FAIL count=%d" % _failures.size())
	quit(1)
