class_name RuntimeMeasurement
extends RefCounted

# Optional engineering telemetry. Never read by simulation decisions.
static var enabled := false
static var samples: Dictionary = {}
static var counters: Dictionary = {}
static var limit := 30000
static var _mutex := Mutex.new()
static var trace_enabled := false
static var trace: Array[Dictionary] = []

static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func end(key: StringName, started: int) -> void:
	if enabled:
		var finished := Time.get_ticks_usec()
		sample(key, finished - started)
		if trace_enabled and finished - started >= 1000:
			_mutex.lock()
			if trace.size() < limit: trace.append({"key":String(key),"start":started,"end":finished,"thread":OS.get_thread_caller_id()})
			_mutex.unlock()

static func trace_copy() -> Array[Dictionary]:
	_mutex.lock()
	var result: Array[Dictionary] = trace.duplicate(true)
	_mutex.unlock()
	return result

static func sample(key: StringName, value: float) -> void:
	if not enabled: return
	_mutex.lock()
	if not samples.has(key): samples[key] = []
	if samples[key].size() < limit: samples[key].append(value)
	_mutex.unlock()

static func count(key: String, amount: int = 1) -> void:
	if not enabled: return
	_mutex.lock()
	counters[key] = int(counters.get(key, 0)) + amount
	_mutex.unlock()

static func reset() -> void:
	_mutex.lock()
	samples.clear()
	counters.clear()
	trace.clear()
	_mutex.unlock()

static func summary() -> Dictionary:
	_mutex.lock()
	var sample_copy := samples.duplicate(true)
	var counter_copy := counters.duplicate()
	_mutex.unlock()
	var result := {}
	for key in sample_copy:
		var values: Array = sample_copy[key]
		values.sort()
		if values.is_empty(): continue
		var total := 0.0
		for value in values: total += value
		result[key] = {"count": values.size(), "p50": values[int((values.size()-1)*0.5)], "p95": values[int((values.size()-1)*0.95)], "max": values.back(), "sum": total}
	return {"samples": result, "counters": counter_copy}
