extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var failures: Array[String] = []
	var old = preload("res://tests/tools/perf27_reference_presentation.gd").new()
	var actual := WorldPresentation.new()
	var old_draw = preload("res://tests/tools/perf27_draw_old.gd").new()
	var new_draw = preload("res://tests/tools/perf27_draw_new.gd").new()
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var snapshot := world.create_snapshot()
	var previous := snapshot
	var checks := 0
	for frame in range(120):
		if frame % 5 == 0:
			previous = snapshot
			snapshot = world.create_snapshot()
			for unit in snapshot.units:
				unit.position += Vector2(frame*0.25,-frame*0.1)
				unit.deployment_progress = float((frame+unit.entity_id)%100)/100
				unit.is_visible_to_local_player = (frame+unit.entity_id)%9 != 0
		for node in [old,actual]:
			node.current_snapshot = snapshot
			node.previous_snapshot = previous
			node._cache_previous_interpolation_state()
			node.interpolation_alpha = float(frame%5)/5
			node._update_unit_batches()
		for key in old._art_batch._buffers:
			checks += 1
			if old._art_batch._buffers[key] != actual._art_batch._buffers[key]: failures.append("presentation buffer %s frame %d" % [key,frame])
		if frame == 60:
			old.reset_art_feedback()
			actual.reset_art_feedback()
	for locale in ["en","zh_CN"]:
		TranslationServer.set_locale(locale)
		for phase in range(12):
			var effects: Array[Dictionary] = []
			for kind in [&"muzzle",&"impact",&"engagement",&"focus",&"pressure",&"reinforcement",&"engineering_route",&"recon_support",&"deployment_started",&"fire_support",&"headquarters",&"destroyed"]:
				effects.append({"kind":kind,"entity_id":snapshot.units[phase%snapshot.units.size()].entity_id,"position":Vector2(12,42),"faction_id":1,"direction":Vector2(0.3,0.7),"duration":1.0,"elapsed":phase/12.0,"label_key":&"HERO_HELP"})
			for node in [old_draw,new_draw]:
				node.current_snapshot = snapshot
				node._combat_effects = effects
				node.commands.clear()
				node._draw_combat_effects()
			checks += 1
			if old_draw.commands != new_draw.commands: failures.append("draw commands %s/%d" % [locale,phase])
	for node in [old,actual,old_draw,new_draw]: node.free()
	var report := {"evidence":"SIMULATED","checks":checks,"failures":failures,"scope":"same draw calls and arguments, exact instance buffers, animation steps, reveal and reset; no rasterization"}
	FileAccess.open("res://artifacts/perf27-presentation-contract.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF27_PRESENTATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
