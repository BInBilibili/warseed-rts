extends SceneTree

func _initialize() -> void:
	var output := "res://artifacts/motion29-natural.json"
	var tick_limit := 1800
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
		if arg.begins_with("--ticks="): tick_limit=int(arg.trim_prefix("--ticks="))
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var failures: Array[String] = []
	var stationary: Dictionary = {}
	var max_stationary: Dictionary = {}
	var max_distance: Dictionary = {}
	var windows := {}
	var low_progress_windows: Array[Dictionary] = []
	var ids := world.commanders.keys()
	ids.sort_custom(func(a,b): return String(a)<String(b))
	var route_checks := 0
	var tick_times: Array[int] = []
	for tick in range(tick_limit):
		var before := {}
		for id in ids:
			var hero := world.units.get(world.commanders[id].hero_entity_id) as UnitState
			if hero!=null and hero.enabled: before[hero.entity_id]=hero.position
		var started := Time.get_ticks_usec()
		world.advance_tick()
		tick_times.append(Time.get_ticks_usec()-started)
		for id in ids:
			var commander := world.commanders[id] as CommanderState
			var hero := world.units.get(commander.hero_entity_id) as UnitState
			if hero==null or not hero.enabled or not before.has(hero.entity_id): continue
			var previous: Vector2=before[hero.entity_id]
			route_checks+=1
			if not world.logic_grid.is_segment_walkable(previous,hero.position) and previous.distance_to(hero.position)>0.01 and failures.size()<20: failures.append("terrain %s/%d" % [id,tick])
			if previous.distance_to(hero.position)>14.51 and failures.size()<20: failures.append("speed %s/%d" % [id,tick])
			var nearest := INF
			for card_id in commander.subordinate_unit_card_ids:
				var card := world.unit_cards[card_id] as UnitCardState
				if card.definition.role_key==&"UNIT_CARD_ROLE_RECON": continue
				for member_id in card.member_entity_ids:
					var member := world.units.get(member_id) as UnitState
					if member!=null and member.enabled and not member.legion_returning: nearest=minf(nearest,hero.position.distance_to(member.position))
			var eligible := nearest<INF and not commander.legion_regrouping and commander.posture!=CommanderState.Posture.HOLD
			if eligible:
				max_distance[id]=maxf(max_distance.get(id,0.0),nearest)
			if not windows.has(id) or windows[id].entity_id!=hero.entity_id:
				windows[id]={"entity_id":hero.entity_id,"tick":tick,"position":hero.position,"far":eligible and nearest>640}
			var window: Dictionary=windows[id]
			window.far=window.far and eligible and nearest>640
			if tick-int(window.tick)>=200:
				if window.far and hero.position.distance_to(window.position)<48:
					low_progress_windows.append({"commander":String(id),"tick":tick,"distance":nearest,"net_progress":hero.position.distance_to(window.position)})
				windows[id]={"entity_id":hero.entity_id,"tick":tick,"position":hero.position,"far":eligible and nearest>640}
			stationary[id]=int(stationary.get(id,0))+1 if eligible and nearest>640 and previous.distance_to(hero.position)<0.1 else 0
			max_stationary[id]=maxi(int(max_stationary.get(id,0)),stationary[id])
		if tick%300==299: print("MOTION29_NATURAL_PROGRESS ",tick+1," stalls=",max_stationary)
		if world.battle_outcome.is_terminal(): break
	for id in max_stationary:
		if max_stationary[id]>=200: failures.append("detached stationary >=20 seconds: "+str(id))
	if not low_progress_windows.is_empty(): failures.append("detached low net progress over 20 seconds")
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for event in world.events: hash.update(("%d:%d:%d:%s\n" % [event.tick,event.kind,event.entity_id,event.detail]).to_utf8_buffer())
	tick_times.sort()
	var report := {"evidence":"SIMULATED","scope":"default autonomous march and combat; bounded observation, no human claim","tick_limit":tick_limit,"terminal":world.battle_outcome.is_terminal(),"ticks":world.current_tick,"route_checks":route_checks,"max_detached_stationary_ticks":max_stationary,"max_nearest_main_distance":max_distance,"low_progress_windows":low_progress_windows,"event_sha256":hash.finish().hex_encode(),"tick_p95_usec":tick_times[int(tick_times.size()*0.95)],"tick_max_usec":tick_times.back(),"failures":failures}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report))
	print("MOTION29_NATURAL ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
