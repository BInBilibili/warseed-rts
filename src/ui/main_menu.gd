class_name MainMenu
extends Control

const SETTINGS_PATH := "user://warseed_settings.cfg"
const GREY_RIDGE_SAVE := "user://grey_ridge_roster.json"
const FINAL_DECISION_SAVE := "user://final_decision_roster.json"
const SELECTOR_SCENE := "res://scenes/game/battle_selector.tscn"

static var pending_continue_scenario_id: StringName = &""

var _menu_panel: VBoxContainer
var _settings_panel: VBoxContainer
var _status_label: Label
var _continue_button: Button
var _start_button: Button
var _settings_button: Button
var _exit_button: Button
var _eyebrow_label: Label
var _title_label: Label
var _subtitle_label: Label
var _footer_label: Label
var _settings_title: Label
var _language_label: Label
var _settings_hint: Label
var _back_button: Button
var _fps_toggle: CheckButton
var _fullscreen_toggle: CheckButton
var _language_selector: OptionButton
var _settings: ConfigFile = ConfigFile.new()


func _ready() -> void:
	_load_settings()
	_apply_settings()
	_build_interface()
	_refresh_continue_state()
	_continue_button.grab_focus()


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		_settings.load(SETTINGS_PATH)


func _save_settings() -> void:
	_settings.save(SETTINGS_PATH)


func _apply_settings() -> void:
	var fullscreen := bool(_settings.get_value("display", "fullscreen", false))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	var locale := String(_settings.get_value("display", "locale", "zh_CN"))
	TranslationServer.set_locale(locale)


func _build_interface() -> void:
	var content := $Content as PanelContainer
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 12)
	content.add_child(left)

	_eyebrow_label = Label.new()
	_eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow_label.add_theme_font_size_override("font_size", 14)
	_eyebrow_label.add_theme_color_override("font_color", Color("#8eb4a8"))
	left.add_child(_eyebrow_label)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 58)
	_title_label.add_theme_color_override("font_color", Color("#f0c15b"))
	left.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 20)
	_subtitle_label.add_theme_color_override("font_color", Color("#d9e3dc"))
	left.add_child(_subtitle_label)

	var rule := HSeparator.new()
	left.add_child(rule)

	_menu_panel = VBoxContainer.new()
	_menu_panel.add_theme_constant_override("separation", 10)
	left.add_child(_menu_panel)
	_continue_button = _make_button("", 48)
	_continue_button.pressed.connect(_continue_game)
	_menu_panel.add_child(_continue_button)
	_start_button = _make_button("", 48)
	_start_button.pressed.connect(_start_game)
	_menu_panel.add_child(_start_button)
	_settings_button = _make_button("", 44)
	_settings_button.pressed.connect(_show_settings)
	_menu_panel.add_child(_settings_button)
	_exit_button = _make_button("", 44)
	_exit_button.pressed.connect(_exit_game)
	_menu_panel.add_child(_exit_button)

	_status_label = Label.new()
	_status_label.custom_minimum_size.y = 30.0
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color("#f0c15b"))
	left.add_child(_status_label)

	_settings_panel = _build_settings_panel(left)
	left.add_child(_settings_panel)
	_settings_panel.hide()

	_footer_label = Label.new()
	_footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer_label.add_theme_font_size_override("font_size", 12)
	_footer_label.add_theme_color_override("font_color", Color("#7d918b"))
	_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_footer_label)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_refresh_locale()


func _build_settings_panel(parent: VBoxContainer) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.name = "SettingsPanel"
	panel.add_theme_constant_override("separation", 12)
	_settings_title = Label.new()
	_settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_title.add_theme_font_size_override("font_size", 26)
	_settings_title.add_theme_color_override("font_color", Color("#f0c15b"))
	panel.add_child(_settings_title)

	_fps_toggle = CheckButton.new()
	_fps_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fps_toggle.button_pressed = bool(_settings.get_value("display", "show_fps", false))
	_fps_toggle.toggled.connect(_set_show_fps)
	panel.add_child(_fps_toggle)

	_fullscreen_toggle = CheckButton.new()
	_fullscreen_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fullscreen_toggle.button_pressed = bool(_settings.get_value("display", "fullscreen", false))
	_fullscreen_toggle.toggled.connect(_set_fullscreen)
	panel.add_child(_fullscreen_toggle)

	var language_row := HBoxContainer.new()
	language_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_language_label = Label.new()
	_language_label.custom_minimum_size.x = 140.0
	language_row.add_child(_language_label)
	_language_selector = OptionButton.new()
	_language_selector.add_item("")
	_language_selector.set_item_metadata(0, "zh_CN")
	_language_selector.add_item("")
	_language_selector.set_item_metadata(1, "en")
	_language_selector.select(0 if TranslationServer.get_locale().begins_with("zh") else 1)
	_language_selector.item_selected.connect(_set_language)
	language_row.add_child(_language_selector)
	panel.add_child(language_row)

	_settings_hint = Label.new()
	_settings_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_hint.add_theme_font_size_override("font_size", 12)
	_settings_hint.add_theme_color_override("font_color", Color("#9aada6"))
	panel.add_child(_settings_hint)
	_back_button = _make_button("", 42)
	_back_button.pressed.connect(_show_menu)
	panel.add_child(_back_button)
	return panel


func _make_button(label: String, height: float) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(360.0, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("#dce7df"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#152522"), Color("#38534c")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#25463d"), Color("#e0b957"), 2))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#356759"), Color("#f0c15b"), 3))
	return button


func _button_style(fill: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 18
	return style


func _refresh_locale() -> void:
	_eyebrow_label.text = GameText.t(&"MAIN_MENU_EYEBROW")
	_title_label.text = GameText.t(&"MAIN_MENU_TITLE")
	_subtitle_label.text = GameText.t(&"MAIN_MENU_SUBTITLE")
	_continue_button.text = GameText.t(&"MAIN_MENU_CONTINUE")
	_start_button.text = GameText.t(&"MAIN_MENU_START")
	_settings_button.text = GameText.t(&"MAIN_MENU_SETTINGS")
	_exit_button.text = GameText.t(&"MAIN_MENU_EXIT")
	_footer_label.text = GameText.t(&"MAIN_MENU_FOOTER")
	_settings_title.text = GameText.t(&"MAIN_MENU_SETTINGS_TITLE")
	_fps_toggle.text = GameText.t(&"MAIN_MENU_SHOW_FPS")
	_fullscreen_toggle.text = GameText.t(&"MAIN_MENU_FULLSCREEN")
	_language_label.text = GameText.t(&"MAIN_MENU_LANGUAGE")
	_settings_hint.text = GameText.t(&"MAIN_MENU_SETTINGS_HINT")
	_back_button.text = GameText.t(&"MAIN_MENU_BACK")
	_language_selector.set_item_text(0, GameText.t(&"MAIN_MENU_LANGUAGE_ZH"))
	_language_selector.set_item_text(1, GameText.t(&"MAIN_MENU_LANGUAGE_EN"))
	_language_selector.select(0 if TranslationServer.get_locale().begins_with("zh") else 1)
	_refresh_continue_state()


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_width := minf(560.0, maxf(360.0, viewport_size.x - 32.0))
	var content := $Content as PanelContainer
	content.offset_left = -panel_width * 0.5
	content.offset_right = panel_width * 0.5
	content.custom_minimum_size.x = panel_width


func _refresh_continue_state() -> void:
	var save := _find_latest_save()
	_continue_button.disabled = save.is_empty()
	if save.is_empty():
		_status_label.text = GameText.t(&"MAIN_MENU_NO_SAVE")
	else:
		_status_label.text = GameText.t(&"MAIN_MENU_SAVE_STATUS") % [int(save.record.get("battle_count", 0)), String(save.record.get("last_scenario_id", "grey_ridge"))]


func _find_latest_save() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for path in [GREY_RIDGE_SAVE, FINAL_DECISION_SAVE]:
		if not FileAccess.file_exists(path):
			continue
		var loaded := ArmyRosterStore.load_record_result(path, false)
		if loaded.is_success() or loaded.status == ArmyRosterResult.Status.LOADED or loaded.status == ArmyRosterResult.Status.MIGRATED:
			candidates.append({"path": path, "record": loaded.record, "mtime": FileAccess.get_modified_time(path)})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.mtime) > int(b.mtime))
	return candidates[0]


func _continue_game() -> void:
	var save := _find_latest_save()
	if save.is_empty():
		return
	var record := save.record as Dictionary
	var scenario_id := StringName(record.get("last_scenario_id", record.get("scenario_id", "grey_ridge")))
	var scene_path := _scene_path_for_scenario(scenario_id)
	if scene_path.is_empty():
		pending_continue_scenario_id = scenario_id
		get_tree().change_scene_to_file(SELECTOR_SCENE)
		return
	if scenario_id == &"final_decision":
		BattleLoadingScreen.enter_final_battle(get_tree(), scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)


func _scene_path_for_scenario(scenario_id: StringName) -> String:
	match scenario_id:
		&"grey_ridge", &"broken_bridge", &"fog_forest", &"black_well", &"final_decision":
			return "res://scenes/game/%s.tscn" % String(scenario_id)
	return ""


func _start_game() -> void:
	pending_continue_scenario_id = &""
	get_tree().change_scene_to_file(SELECTOR_SCENE)


func _show_settings() -> void:
	_menu_panel.hide()
	_status_label.hide()
	_settings_panel.show()
	_fps_toggle.grab_focus()


func _show_menu() -> void:
	_settings_panel.hide()
	_menu_panel.show()
	_status_label.show()
	_refresh_continue_state()
	_continue_button.grab_focus()


func _set_show_fps(enabled: bool) -> void:
	_settings.set_value("display", "show_fps", enabled)
	_save_settings()
	var fps_overlay := get_node_or_null("/root/FpsOverlay")
	if fps_overlay != null and fps_overlay.has_method("set_show_fps"):
		fps_overlay.set_show_fps(enabled)


func _set_fullscreen(enabled: bool) -> void:
	_settings.set_value("display", "fullscreen", enabled)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _set_language(index: int) -> void:
	var locale := String(_language_selector.get_item_metadata(index))
	TranslationServer.set_locale(locale)
	_settings.set_value("display", "locale", locale)
	_save_settings()
	_refresh_locale()


func _exit_game() -> void:
	get_tree().quit()
