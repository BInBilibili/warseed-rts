extends SceneTree
class ReusableWorker:
	extends RefCounted
	var wake := Semaphore.new()
	var done := Semaphore.new()
	var mutex := Mutex.new()
	var stopping := false
	func run() -> void:
		while true:
			wake.wait()
			mutex.lock()
			var exit_requested := stopping
			mutex.unlock()
			if exit_requested: return
			done.post()
func _initialize() -> void:
	var worker := ReusableWorker.new()
	var resident := Thread.new()
	resident.start(worker.run)
	var measurements := {"create_join_usec":0,"wake_complete_usec":0}
	for i in 500:
		for reuse in ([false,true] if i%2 == 0 else [true,false]):
			var begin := Time.get_ticks_usec()
			if reuse:
				worker.wake.post()
				worker.done.wait()
			else:
				var temporary := Thread.new()
				temporary.start(func(): return)
				temporary.wait_to_finish()
			measurements["wake_complete_usec" if reuse else "create_join_usec"] += Time.get_ticks_usec()-begin
	worker.mutex.lock()
	worker.stopping = true
	worker.mutex.unlock()
	worker.wake.post()
	resident.wait_to_finish()
	var report := {"evidence":"SIMULATED","iterations":500,"total_usec":measurements,"scope":"scheduling overhead only, not full scene"}
	FileAccess.open("res://artifacts/perf27-thread-cost.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF27_THREAD_COST ",JSON.stringify(report))
	quit()
