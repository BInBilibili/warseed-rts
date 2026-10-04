extends SceneTree
class Probe:
	extends RefCounted
	var value: RefCounted
	var wake := Semaphore.new()
	var done := Semaphore.new()
	var stop_requested := false
	func run() -> void:
		while true:
			wake.wait()
			var owned := value
			if stop_requested: return
			done.post()
func _initialize() -> void:
	var probe := Probe.new()
	probe.value = RefCounted.new()
	var weak: WeakRef = weakref(probe.value)
	var thread := Thread.new()
	thread.start(probe.run)
	probe.wake.post()
	probe.done.wait()
	OS.delay_msec(20)
	probe.value = null
	var retained := weak.get_ref() != null
	probe.stop_requested = true
	probe.wake.post()
	thread.wait_to_finish()
	print("PERF27_LOOP_LOCAL_RETAINED ",retained)
	quit()
