class_name SimulationTickJob
extends RefCounted

# One long-lived worker owns the world only between dispatch and collect.
# Semaphores transfer ownership; no Node, rendering or persistence API runs here.
var world: SimulationWorld
var elapsed_usec: int
var _thread := Thread.new()
var _wake := Semaphore.new()
var _done := Semaphore.new()
var _mutex := Mutex.new()
var _stopping := false
var _completed := false
var _snapshot: WorldSnapshot
var _prepare_presentation := false
var presentation_view: BattlePresentationView
var _presentation_projector := BattlePresentationProjector.new()

func start() -> Error:
	return _thread.start(_loop)

func dispatch(value: SimulationWorld, prepare_presentation: bool = false) -> void:
	_mutex.lock()
	world = value
	_prepare_presentation = prepare_presentation
	presentation_view = null
	_completed = false
	_mutex.unlock()
	_wake.post()

func is_alive() -> bool:
	_mutex.lock()
	var pending := not _completed
	_mutex.unlock()
	return pending

func wait_to_finish() -> WorldSnapshot:
	_done.wait()
	_mutex.lock()
	var result := _snapshot
	_snapshot = null
	world = null
	_mutex.unlock()
	return result

func stop() -> void:
	if not _thread.is_started(): return
	_mutex.lock()
	_stopping = true
	_mutex.unlock()
	_wake.post()
	_thread.wait_to_finish()

func _loop() -> void:
	while true:
		_wake.wait()
		_mutex.lock()
		var stopping := _stopping
		var owned_world := world
		var prepare_presentation := _prepare_presentation
		_mutex.unlock()
		if stopping: return
		var started := Time.get_ticks_usec()
		var result := owned_world.advance_tick()
		var elapsed := Time.get_ticks_usec() - started
		RuntimeMeasurement.sample(&"tick.world_usec", elapsed)
		var view: BattlePresentationView
		if prepare_presentation:
			var projection_started := RuntimeMeasurement.begin()
			view = _presentation_projector.project(result, owned_world.battle_definition)
			RuntimeMeasurement.end(&"worker.presentation_usec",projection_started)
		_mutex.lock()
		elapsed_usec = elapsed
		_snapshot = result
		presentation_view = view
		_completed = true
		_mutex.unlock()
		# GDScript loop locals otherwise retain the previous world while asleep.
		result = null
		owned_world = null
		view = null
		_done.post()
