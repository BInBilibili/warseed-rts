class_name BattleSelector
extends Control

signal battle_requested(scenario_id: StringName, scene_path: String)

const CATALOG_PATH := BattleContentLoader.DEFAULT_CATALOG_PATH

@onready var title_label: Label = $SafeArea/Layout/Header/Title
@onready var subtitle_label: Label = $SafeArea/Layout/Header/Subtitle
@onready var battle_list: VBoxContainer = $SafeArea/Layout/Body/BattleList
@onready var operation_label: Label = $SafeArea/Layout/Body/Dossier/Content/Operation
@onready var battle_title_label: Label = $SafeArea/Layout/Body/Dossier/Content/BattleTitle
@onready var briefing_label: Label = $SafeArea/Layout/Body/Dossier/Content/Briefing
@onready var mechanics_label: Label = $SafeArea/Layout/Body/Dossier/Content/Mechanics
@onready var persistence_label: Label = $SafeArea/Layout/Body/Dossier/Content/Persistence
@onready var training_status_label: Label = $SafeArea/Layout/Body/Dossier/Content/Training/Status
@onready var replay_tutorial_button: Button = $SafeArea/Layout/Body/Dossier/Content/Training/Replay
@onready var deploy_button: Button = $SafeArea/Layout/Body/Dossier/Content/Deploy
@onready var language_button: Button = $SafeArea/Layout/Footer/Language
@onready var main_menu_button: Button = $SafeArea/Layout/Footer/MainMenu
@onready var exit_button: Button = $SafeArea/Layout/Footer/Exit

var scene_changes_enabled: bool = true
var _battles: Array[BattleDefinition] = []
var _battle_buttons: Array[Button] = []
var _selected_index: int = -1
var _black_well_continuity_confirmed := false
var _roster_error := ""
var _large_mode := true
var _mode_buttons: Array[Button] = []


func _ready() -> void:
	# Export templates disable scene/script CLI overrides. This explicit headless
	# debug check exercises the packaged native kernel without entering a match.
	if OS.is_debug_build() and DisplayServer.get_name() == "headless" and OS.get_cmdline_user_args().has("--verify-art-kernel"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/diagnostics/art_kernel_verification.tscn")
		return
	var session_id := ArmyRosterStore.active_playtest_session_id()
	var roster_path := ArmyRosterStore.campaign_record_path_for_session(session_id, &"black_well")
	var loaded := ArmyRosterStore.load_record_result(roster_path, ArmyRosterStore.runtime_persistence_allowed())
	if loaded.status == ArmyRosterResult.Status.FAILED:
		_roster_error = "; ".join(loaded.errors)
	else:
		_black_well_continuity_confirmed = TutorialProgressStore.confirm_black_well_continuity(loaded.record)
	_load_battles()
	_select_pending_continue_operation()
	language_button.pressed.connect(_toggle_language)
	main_menu_button.pressed.connect(_return_to_main_menu)
	exit_button.pressed.connect(_exit_game)
	deploy_button.pressed.connect(_deploy_selected)
	replay_tutorial_button.pressed.connect(_replay_selected_tutorial)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_apply_responsive_layout):
		viewport.size_changed.connect(_apply_responsive_layout)
	refresh_locale()
	_select_mode(true)
	_apply_responsive_layout()


func _select_pending_continue_operation() -> void:
	var pending := MainMenu.pending_continue_scenario_id
	if pending == &"":
		return
	MainMenu.pending_continue_scenario_id = &""
	for index in range(_battles.size()):
		if _battles[index].scenario_id == pending:
			_select_battle(index)
			return


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and is_ancestor_of(focused):
			# GUI routing gives the clicked control focus afterwards. Background
			# clicks instead leave no stale keyboard highlight on another button.
			focused.release_focus()


func _load_battles() -> void:
	var resource := ResourceLoader.load(CATALOG_PATH) as BattleContentCatalog
	if resource == null:
		deploy_button.disabled = true
		return
	_battles = resource.get_selectable_battles()
	if _mode_buttons.is_empty():
		var modes := HBoxContainer.new()
		modes.name = "MatchModes"
		battle_list.get_parent().add_child(modes)
		# Keep the two-column dossier layout intact; place mode tabs above Body.
		battle_list.get_parent().remove_child(modes)
		var layout := $SafeArea/Layout
		layout.add_child(modes)
		layout.move_child(modes, $SafeArea/Layout/Body.get_index())
		for large in [true, false]:
			var mode_button := Button.new()
			mode_button.toggle_mode = true
			mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mode_button.pressed.connect(_select_mode.bind(large))
			modes.add_child(mode_button)
			_mode_buttons.append(mode_button)
	for child in battle_list.get_children():
		child.queue_free()
	_battle_buttons.clear()
	for index in range(_battles.size()):
		var button := Button.new()
		button.name = "Battle_%s" % _battles[index].scenario_id
		button.custom_minimum_size = Vector2(0.0, 76.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_select_battle.bind(index))
		battle_list.add_child(button)
		_battle_buttons.append(button)


func refresh_locale() -> void:
	title_label.text = GameText.t(&"BATTLE_SELECT_TITLE")
	subtitle_label.text = GameText.t(&"BATTLE_SELECT_SUBTITLE")
	persistence_label.text = GameText.t(&"BATTLE_SELECT_PERSISTENCE")
	if not _roster_error.is_empty():
		persistence_label.text += "\n" + GameText.t(&"ROSTER_LOAD_FAILED")
		persistence_label.tooltip_text = _roster_error
	if _black_well_continuity_confirmed:
		persistence_label.text = "%s\n%s" % [persistence_label.text, GameText.t(&"BLACK_WELL_CONTINUITY_CONFIRMED")]
	deploy_button.text = GameText.t(&"BATTLE_SELECT_DEPLOY")
	replay_tutorial_button.text = GameText.t(&"BATTLE_SELECT_TUTORIAL_REPLAY")
	replay_tutorial_button.tooltip_text = GameText.t(&"BATTLE_SELECT_TUTORIAL_REPLAY_TOOLTIP")
	language_button.text = GameText.t(&"BATTLE_SELECT_LANGUAGE")
	main_menu_button.text = GameText.t(&"RETURN_TO_MAIN_MENU")
	exit_button.text = GameText.t(&"EXIT_GAME")
	if _mode_buttons.size() == 2:
		_mode_buttons[0].text = GameText.t(&"GROWTH_MODE")
		_mode_buttons[1].text = GameText.t(&"TACTICAL_MODE")
	for index in range(_battle_buttons.size()):
		var battle := _battles[index]
		_battle_buttons[index].text = GameText.t(battle.display_name_key) if battle.growth_mode else GameText.t(&"BATTLE_SELECT_OPERATION_BUTTON") % [
			battle.operation_number,
			GameText.t(battle.display_name_key),
		]
	if _selected_index >= 0:
		_refresh_dossier()


func _select_battle(index: int) -> void:
	if index < 0 or index >= _battles.size():
		return
	_selected_index = index
	_large_mode = _battles[index].growth_mode
	_refresh_mode_visibility()
	for button_index in range(_battle_buttons.size()):
		_battle_buttons[button_index].button_pressed = button_index == index
	_refresh_dossier()
	deploy_button.disabled = false


func _refresh_dossier() -> void:
	var battle := get_selected_battle()
	if battle == null:
		return
	operation_label.text = GameText.t(&"BATTLE_SELECT_OPERATION") % battle.operation_number
	persistence_label.text = GameText.t(&"GROWTH_MATCH_HELP" if battle.growth_mode else &"BATTLE_SELECT_PERSISTENCE")
	if not battle.growth_mode:
		if not _roster_error.is_empty():
			persistence_label.text += "\n" + GameText.t(&"ROSTER_LOAD_FAILED")
		if _black_well_continuity_confirmed:
			persistence_label.text += "\n" + GameText.t(&"BLACK_WELL_CONTINUITY_CONFIRMED")
	persistence_label.tooltip_text = _roster_error if not battle.growth_mode else ""
	training_status_label.get_parent().visible = not battle.growth_mode
	if battle.growth_mode:
		operation_label.text = GameText.t(&"GROWTH_MODE")
	battle_title_label.text = GameText.t(battle.display_name_key)
	briefing_label.text = GameText.t(battle.selector_briefing_key)
	mechanics_label.text = GameText.t(&"BATTLE_SELECT_MECHANICS") % GameText.t(battle.selector_mechanics_key)
	var status := TutorialProgressStore.get_scenario_status(battle.scenario_id)
	training_status_label.text = "%s: %s" % [
		GameText.t(&"BATTLE_SELECT_TUTORIAL_STATUS"),
		GameText.t(StringName("TUTORIAL_STATUS_%s" % status.to_upper())),
	]


func get_selected_battle() -> BattleDefinition:
	if _selected_index < 0 or _selected_index >= _battles.size():
		return null
	return _battles[_selected_index]


func _select_mode(large: bool) -> void:
	_large_mode = large
	for index in range(_battles.size()):
		if _battles[index].growth_mode == large:
			_select_battle(index)
			return


func _refresh_mode_visibility() -> void:
	for index in range(_battle_buttons.size()):
		_battle_buttons[index].visible = _battles[index].growth_mode == _large_mode
	for index in range(_mode_buttons.size()):
		_mode_buttons[index].set_pressed_no_signal(_large_mode == (index == 0))


func get_selectable_battle_count() -> int:
	return _battles.size()


func get_battle_button(scenario_id: StringName) -> Button:
	for index in range(_battles.size()):
		if _battles[index].scenario_id == scenario_id:
			return _battle_buttons[index]
	return null


func _replay_selected_tutorial() -> void:
	var battle := get_selected_battle()
	if battle == null:
		return
	TutorialProgressStore.reset_scenario(battle.scenario_id)
	_refresh_dossier()


func _deploy_selected() -> void:
	var battle := get_selected_battle()
	if battle == null or battle.scene_path.is_empty():
		return
	battle_requested.emit(battle.scenario_id, battle.scene_path)
	if scene_changes_enabled:
		if battle.scenario_id == &"final_decision":
			BattleLoadingScreen.enter_final_battle(get_tree(), battle.scene_path)
		else:
			get_tree().change_scene_to_file(battle.scene_path)


func _toggle_language() -> void:
	TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("zh") else "zh_CN")
	refresh_locale()


func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _exit_game() -> void:
	get_tree().quit()


func _apply_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var body := $SafeArea/Layout/Body as GridContainer
	var viewport_width := get_viewport_rect().size.x
	var narrow := viewport_width < 820.0
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_title_label.add_theme_font_size_override("font_size", 21 if narrow else 25)
	$SafeArea/Layout.add_theme_constant_override("separation", 10 if narrow else 16)
	$SafeArea/Layout/Body/Dossier/Content.add_theme_constant_override("separation", 8 if narrow else 12)
	for button in _mode_buttons:
		button.custom_minimum_size.y = 30
		button.clip_text = true
	body.columns = 1 if narrow else 2
	battle_list.custom_minimum_size = Vector2(0.0 if narrow else 310.0, 156.0)
	briefing_label.custom_minimum_size.y = 60.0 if narrow else 92.0
	for button in _battle_buttons:
		button.custom_minimum_size.y = 44.0 if narrow else 76.0
	body.add_theme_constant_override("h_separation", 22)
	body.add_theme_constant_override("v_separation", 12)
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.024, 0.025))
	var grid_color := Color(0.12, 0.18, 0.175, 0.22)
	for x in range(0, ceili(size.x / 64.0) + 1):
		draw_line(Vector2(x * 64.0, 0.0), Vector2(x * 64.0, size.y), grid_color, 1.0)
	for y in range(0, ceili(size.y / 64.0) + 1):
		draw_line(Vector2(0.0, y * 64.0), Vector2(size.x, y * 64.0), grid_color, 1.0)
	var river_points := PackedVector2Array([
		Vector2(size.x * 0.08, size.y * 0.16), Vector2(size.x * 0.28, size.y * 0.29),
		Vector2(size.x * 0.43, size.y * 0.52), Vector2(size.x * 0.66, size.y * 0.61),
		Vector2(size.x * 0.92, size.y * 0.88),
	])
	draw_polyline(river_points, Color(0.12, 0.30, 0.31, 0.34), 26.0, true)
	draw_polyline(river_points, Color(0.24, 0.58, 0.55, 0.28), 2.0, true)
