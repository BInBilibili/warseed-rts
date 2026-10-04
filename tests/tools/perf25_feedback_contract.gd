extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	for card: UnitCardState in world.unit_cards.values():
		world._apply_field_reinforcement(card,card.definition.authorized_strength-UnitCardSnapshot.new(card,world.units).current_strength)
	var snapshot := world.create_snapshot()
	var reference = preload("res://tests/tools/perf25_reference_feedback.gd").new()
	var actual := BattleFeedbackDirector.new()
	var expected: Array = []
	var observed: Array = []
	for pair in [[reference,expected],[actual,observed]]:
		var output: Array = pair[1]
		pair[0].feedback_emitted.connect(func(key: StringName,args: Array,severity: int) -> void: output.append([key,args.duplicate(true),severity]))
		pair[0].effect_requested.connect(func(kind: StringName,at: Vector2,faction: int,id: int) -> void: output.append([kind,at,faction,id]))
	var events: Array[SimulationEvent] = []
	RuntimeMeasurement.reset()
	RuntimeMeasurement.enabled = true
	for tick in range(100):
		snapshot.tick = tick
		TranslationServer.set_locale("zh_CN" if tick < 50 else "en")
		for i in range(snapshot.units.size()):
			var unit := snapshot.units[i]
			var target := snapshot.units[(i+40)%snapshot.units.size()]
			unit.is_visible_to_local_player = i % 7 != tick % 7
			for kind in [SimulationEvent.Kind.ATTACK_STARTED,SimulationEvent.Kind.PROJECTILE_FIRED,SimulationEvent.Kind.DAMAGE_APPLIED]:
				events.append(SimulationEvent.new(tick,kind,unit.entity_id,"target=%d;amount=30" % target.entity_id))
		if tick == 99:
			events.append(BattleConclusionEvent.new(tick,BattleOutcome.new(BattleOutcome.Result.ORDERED_WITHDRAWAL)))
		var started := RuntimeMeasurement.begin()
		reference.process_events(events,snapshot)
		RuntimeMeasurement.end(&"feedback.reference_usec",started)
		started = RuntimeMeasurement.begin()
		actual.process_events(events,snapshot)
		RuntimeMeasurement.end(&"feedback.optimized_usec",started)
		if expected != observed: failures.append("ordered UI/effects mismatch tick %d" % tick)
		if reference._last_feedback_tick_by_scope != actual._last_feedback_tick_by_scope or reference._damage_windows != actual._damage_windows or reference._focus_windows != actual._focus_windows:
			failures.append("cooldown/windows mismatch tick %d" % tick)
		for key in ["play_count","visual_count","dropped_audio_count","preempted_audio_count","peak_concurrent_voice_count"]:
			if reference.get(key) != actual.get(key): failures.append("audio state mismatch %s tick %d" % [key,tick])
	var report := {"evidence":"SIMULATED","events":events.size(),"feedback":observed.size(),"failures":failures,"measurements":RuntimeMeasurement.summary()}
	FileAccess.open("res://artifacts/perf25-feedback01.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF25_FEEDBACK ",JSON.stringify(report))
	RuntimeMeasurement.enabled = false
	reference.free()
	actual.free()
	quit(0 if failures.is_empty() else 1)
