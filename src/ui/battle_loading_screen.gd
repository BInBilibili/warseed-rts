class_name BattleLoadingScreen
extends CanvasLayer

static var _entering := false
static var last_measurement: Dictionary = {}
var _stage_times: Dictionary = {}
var _build_started_usec := 0
var _progress := 0.0
var _mutex := Mutex.new()
var _thread := Thread.new()
var _bar: ProgressBar
var _label: Label

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var center := CenterContainer.new()
	panel.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 120)
	center.add_child(box)
	_label = Label.new()
	_label.text = GameText.t(&"LOADING_BATTLE")
	box.add_child(_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(300, 28)
	box.add_child(_bar)

func _stage(value: float) -> void:
	_mutex.lock()
	_progress = value
	_stage_times[str(value)] = Time.get_ticks_usec() - _build_started_usec
	_mutex.unlock()

func _construct(kind: SimulationWorld.ScenarioKind, record: Dictionary, plan: ArmyPlan) -> SimulationWorld:
	return SimulationWorld.new(true, false, kind, record, &"", plan, _stage)

func build_world(kind: SimulationWorld.ScenarioKind, record: Dictionary, plan: ArmyPlan) -> SimulationWorld:
	await get_tree().process_frame
	_build_started_usec = Time.get_ticks_usec()
	_stage_times.clear()
	var error := _thread.start(_construct.bind(kind, record.duplicate(true), plan.duplicate_plan() if plan != null else null))
	if error != OK:
		return _construct(kind, record, plan)
	while _thread.is_alive():
		_mutex.lock()
		_bar.value = _progress * 100.0
		_mutex.unlock()
		await get_tree().process_frame
	var result: SimulationWorld = _thread.wait_to_finish()
	last_measurement["world_build_usec"] = Time.get_ticks_usec() - _build_started_usec
	last_measurement["world_stage_cumulative_usec"] = _stage_times.duplicate()
	_bar.value = 100
	await get_tree().process_frame
	return result

static func enter_final_battle(tree: SceneTree, scene_path: String) -> void:
	if _entering: return
	_entering = true
	var screen := BattleLoadingScreen.new()
	tree.root.add_child(screen)
	last_measurement = {}
	var resource_started := Time.get_ticks_usec()
	var error := ResourceLoader.load_threaded_request(scene_path)
	if error != OK:
		screen.queue_free()
		_entering = false
		return
	while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var progress: Array = []
		ResourceLoader.load_threaded_get_status(scene_path, progress)
		screen._bar.value = float(progress[0]) * 10 if not progress.is_empty() else 0
		await tree.process_frame
	var scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if scene == null:
		screen.queue_free()
		_entering = false
		return
	last_measurement["resource_wait_usec"] = Time.get_ticks_usec() - resource_started
	var record: Dictionary = {}
	if ArmyRosterStore.runtime_persistence_allowed():
		var session := ArmyRosterStore.active_playtest_session_id()
		var path := ArmyRosterStore.campaign_record_path_for_session(session, &"final_decision")
		var loaded := ArmyRosterStore.load_record_result(path, true)
		record = loaded.record
	SimulationHost.prepared_world = await screen.build_world(SimulationWorld.ScenarioKind.FINAL_DECISION, record, null)
	var switch_started := Time.get_ticks_usec()
	tree.change_scene_to_packed(scene)
	await tree.process_frame
	await tree.process_frame
	last_measurement["scene_switch_two_frames_usec"] = Time.get_ticks_usec() - switch_started
	screen.queue_free()

	_entering = false

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if _thread.is_started(): _thread.wait_to_finish()
	_entering = false
