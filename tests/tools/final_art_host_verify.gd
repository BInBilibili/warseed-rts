extends SceneTree
var failures: Array[String] = []
var presentation: WorldPresentation

func check(ok: bool, note: String) -> void:
	if not ok:
		failures.append(note)
		push_error(note)

func _initialize() -> void:
	call_deferred("run")

func sample(count: int, tick: int) -> WorldSnapshot:
	var units: Array[UnitSnapshot] = []
	for i in range(count):
		var state := UnitState.new(i + 1, Vector2(100 + i % 16 * 75, 100 + floori(i / 16.0) * 60), 100, 1 if i % 2 == 0 else 2)
		state.definition_id = WsArtLibrary.IDS[i % 5]
		var unit := UnitSnapshot.new(state)
		unit.is_visible_to_local_player = true
		units.append(unit)
	return WorldSnapshot.new(tick, units)

func run() -> void:
	presentation = WorldPresentation.new()
	for child_name in ["Units", "Buildings", "OreFields"]:
		var child := Node2D.new()
		child.name = child_name
		presentation.add_child(child)
	root.add_child(presentation)
	var previous: WorldSnapshot = null
	for count in [55, 57, 128, 40]:
		var snapshot := sample(count, count)
		presentation.set_snapshots(previous, snapshot, 0.5)
		check(presentation._art_batch.debug_visible_instance_count() == count, "All bodies in batch at %d" % count)
		check(presentation._art_batch.visible == (count > 56), "Batch switch at %d" % count)
		check(not presentation._unit_bodies_batch.visible, "No duplicate old rectangles")
		previous = snapshot
	var snapshot := sample(128, 201)
	snapshot.units[1].is_visible_to_local_player = false
	presentation.set_snapshots(previous, snapshot, 1.0)
	var events: Array[SimulationEvent] = [
		SimulationEvent.new(200, SimulationEvent.Kind.PROJECTILE_FIRED, 1, "target=2"),
		SimulationEvent.new(200, SimulationEvent.Kind.PROJECTILE_FIRED, 2, "target=1"),
		SimulationEvent.new(200, SimulationEvent.Kind.DAMAGE_APPLIED, 1, "target=2;amount=10"),
		SimulationEvent.new(200, SimulationEvent.Kind.DAMAGE_APPLIED, 2, "target=1;amount=10"),
	]
	presentation.consume_art_events(events, snapshot)
	check(presentation._art_batch._feedback.has(1), "Visible/local fire and damage accepted")
	check(not presentation._art_batch._feedback.has(2), "Hidden enemy fire/damage rejected")
	check(presentation._art_batch.debug_visible_instance_count() == 127, "Hidden contact has no body")
	var effects_count := presentation._combat_effects.size()
	presentation.consume_art_events(events, snapshot)
	check(presentation._combat_effects.size() == effects_count, "Event cursor prevents replay")
	presentation.reset_art_feedback(events.size())
	check(presentation._art_batch._feedback.is_empty(), "Match reset clears feedback")
	check(presentation._combat_effects.is_empty(), "Match reset clears impacts")
	# Events predating this snapshot cannot reappear when the enemy becomes visible.
	snapshot.units[1].is_visible_to_local_player = true
	snapshot.tick = 203
	presentation.reset_art_feedback(0)
	presentation.consume_art_events(events, snapshot)
	check(presentation._art_batch._feedback.is_empty(), "Historical events are not replayed after reveal")
	print("ART_HOST_VERIFY %s: 55/57/128/40 transitions, no duplicate bodies, legal fire/damage, hidden target/source, cursor, reset, stale-event rejection" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
