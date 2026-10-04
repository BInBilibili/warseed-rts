extends "res://tests/tools/legion34_transition_lab.gd"

class Column extends RefCounted:
	var army: LabFormation
	var ids: Array[int] = []
	var progress: Array[float] = []
	var lanes: Array[int] = []
	var batches: Array[int] = []
	var lag: Array[float] = []
	var hero := 0

var checks := 0
var failures: Array[String] = []
var output := "res://artifacts/legion41/protected01.json"

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value and not failures.has(reason): failures.append(reason)

func column_for(profile: int, count: int, faction: int, base: int, front: float, units: Dictionary) -> Column:
	var col := Column.new()
	col.army = spawn_army(profile,count,faction,base,Vector2.ZERO,Vector2.RIGHT,"retreat","special",units)
	var core: Array[int] = []
	var other: Array[int] = []
	for id in col.army.member_entity_ids:
		if role_of(units[id]) in [1,2]: core.append(id)
		elif role_of(units[id]) != 4: other.append(id)
		else: col.hero = id
	while not core.is_empty() or not other.is_empty():
		if not core.is_empty(): col.ids.append(core.pop_front())
		if not other.is_empty(): col.ids.append(other.pop_front())
	var insertion := col.ids.size()/2
	if faction == 1:
		var total := col.ids.size()+1
		var parts := ceili(total/12.0)
		insertion = 0
		for b in range(parts/2): insertion += total/parts+int(b<total%parts)
	col.ids.insert(insertion,col.hero)
	var n := col.ids.size()
	var batch_count := ceili(n/12.0)
	var cursor := 0
	var depth := 0.0
	for b in range(batch_count):
		var size: int = n/batch_count+int(b<n%batch_count)
		var has_hero := false
		var has_core := false
		check(size <= 12,"batch size <=12")
		for j in range(size):
			var id := col.ids[cursor]
			cursor += 1
			var lag := depth+floori(j/3.0)*48.0
			col.lag.append(lag)
			col.progress.append(front-lag)
			col.lanes.append(j%3)
			col.batches.append(b)
			units[id].position = point_at(front-lag,j%3)
			has_hero = has_hero or id == col.hero
			has_core = has_core or role_of(units[id]) in [1,2]
		if has_hero: check(has_core,"hero batch has actual escort")
		depth += (ceili(size/3.0)-1)*48.0+160.0
	return col

func advance_column(col: Column, units: Dictionary, front_goal: float) -> void:
	var pace := current_pace(col.army,units)
	for i in range(col.ids.size()-1,-1,-1):
		var unit: UnitState = units[col.ids[i]]
		if not unit.enabled: continue
		var goal := front_goal-col.lag[i]
		var next := maxf(goal,col.progress[i]-minf(pace,unit.move_speed)*0.1)
		for j in range(col.ids.size()):
			if i == j or not units[col.ids[j]].enabled: continue
			if col.batches[j] == col.batches[i]+1: next = maxf(next,col.progress[j]+160.0)
			if col.lanes[j] == col.lanes[i] and col.progress[j] < col.progress[i]:
				next = maxf(next,col.progress[j]+(48.0 if col.batches[i]==col.batches[j] else 160.0))
		next = minf(col.progress[i],next)
		var candidate := point_at(next,col.lanes[i])
		if unit.position.distance_to(candidate) > unit.move_speed*0.1:
			var lo := next
			var hi := col.progress[i]
			for retry in range(14):
				var mid := (lo+hi)*0.5
				if unit.position.distance_to(point_at(mid,col.lanes[i])) > unit.move_speed*0.1: lo = mid
				else: hi = mid
			next = hi
			candidate = point_at(next,col.lanes[i])
		if legal_motion(unit.position,candidate,unit.entity_id,units):
			unit.position = candidate
			col.progress[i] = next

func fire_targets(own: Column, enemies: Column, units: Dictionary) -> Array[int]:
	var seen := visible_contacts(units,own.army,enemies.army)
	seen.sort()
	for id in own.ids:
		var unit: UnitState = units[id]
		unit.attack_target_entity_id = 0
		if not unit.enabled: continue
		var nearest := INF
		for target in seen:
			var distance: float = unit.position.distance_to(units[target].position)
			if distance <= unit.attack_range and distance < nearest:
				nearest = distance
				unit.attack_target_entity_id = target
	return seen

func run_pursuit(profile: int, count: int, delay: int, mirror: bool) -> Dictionary:
	checks = 0
	failures = []
	build_route(mirror)
	var units: Dictionary = {}
	var own := column_for(profile,count,1,1,5000.0,units)
	# Enemy front is its far end: nearest actual pursuer starts 192 beyond the
	# withdrawing front. Both armies remain in the real narrow corridor.
	var own_depth: float = own.lag.max()
	var enemy := column_for(4,count,2,1001,5192.0+own_depth,units)
	check(not visible_contacts(units,own.army,enemy.army).is_empty() and not visible_contacts(units,enemy.army,own.army).is_empty(),"pressure fixture starts with mutually legal contact")
	var events: Array[SimulationEvent] = []
	var projectiles: Dictionary = {}
	var combat := CombatSystem.new()
	var projectile_id := 1
	var first_contact := -1
	var last_contact := -1
	var retreat_tick := -1
	var exit_tick := -1
	var safe_tick := -1
	var last_seen_tick := -10000
	var last_seen_progress := enemy.progress[0]
	var enemy_moved := 0.0
	var max_hero_gap := 0.0
	var gap_ticks := 0
	var shots := [0,0]
	var hit_events := 0
	var exit_front := own_depth+320.0
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	var end_tick := -1
	var outcome := "timeout"
	for tick in range(1800):
		refresh_speeds(units)
		var before := {}
		for id in units: before[id] = units[id].position
		var seen_own := visible_contacts(units,own.army,enemy.army)
		var seen_enemy := visible_contacts(units,enemy.army,own.army)
		if not seen_own.is_empty() and first_contact < 0: first_contact = tick
		if first_contact >= 0 and tick-first_contact >= delay:
			if retreat_tick < 0: retreat_tick = tick
			advance_column(own,units,exit_front)
		if not seen_enemy.is_empty():
			last_seen_tick = tick
			last_seen_progress = INF
			for id in seen_enemy:
				# Only already visible targets supply pursuit coordinates.
				var i := own.ids.find(id)
				last_seen_progress = minf(last_seen_progress,own.progress[i])
		if tick-last_seen_tick <= 30:
			advance_column(enemy,units,maxf(enemy.lag.max()+32.0,last_seen_progress+enemy.lag.max()+48.0))
		for id in units:
			var unit: UnitState = units[id]
			unit.has_move_target = unit.position.distance_to(before[id]) > 0.01
			if not unit.enabled: continue
			check(unit.position.distance_to(before[id]) <= unit.move_speed*0.1+0.01,"actual tick speed bounded")
			check(actual_grid.is_segment_walkable(before[id]+origin,unit.position+origin),"actual map path walkable")
			if unit.faction_id == 2: enemy_moved += unit.position.distance_to(before[id])
			for other in units:
				if other < id and units[other].enabled: check(unit.position.distance_to(units[other].position) >= 23.99,"live physical centers separated")
		fire_targets(own,enemy,units)
		fire_targets(enemy,own,units)
		var threat := false
		for id in enemy.ids:
			if units[id].enabled and units[id].attack_target_entity_id != 0: threat = true
		if threat: last_contact = tick
		projectile_id = combat.advance(units,{},projectiles,projectile_id,events,tick)
		for event in events:
			if event.kind == SimulationEvent.Kind.PROJECTILE_FIRED:
				var attacker: UnitState = units.get(event.entity_id)
				if attacker != null: shots[attacker.faction_id-1] += 1
			if event.kind == SimulationEvent.Kind.DAMAGE_APPLIED: hit_events += 1
		events.clear()
		for col: Column in [own,enemy]:
			for b in range(1,ceili(col.ids.size()/12.0)):
				var previous_tail := INF
				var next_front := -INF
				for i in range(col.ids.size()):
					if not units[col.ids[i]].enabled: continue
					if col.batches[i] == b-1: previous_tail = minf(previous_tail,col.progress[i])
					if col.batches[i] == b: next_front = maxf(next_front,col.progress[i])
				if previous_tail < INF and next_front > -INF: check(previous_tail-next_front >= 159.98,"actual live batch gap >=96 plus envelopes")
		var hero: UnitState = units[own.hero]
		var nearest := INF
		for id in own.ids:
			if units[id].enabled and role_of(units[id]) in [1,2]: nearest = minf(nearest,hero.position.distance_to(units[id].position))
		if hero.enabled and nearest < INF:
			max_hero_gap = maxf(max_hero_gap,nearest)
			if nearest > 240.01: gap_ticks += 1
		var at_exit := true
		for i in range(own.ids.size()):
			if units[own.ids[i]].enabled and own.progress[i] > exit_front-own.lag[i]+1.0: at_exit = false
		if at_exit and exit_tick < 0: exit_tick = tick
		var in_flight := projectiles.values().any(func(p: ProjectileState) -> bool: return p.faction_id == 2)
		for id in units:
			var unit: UnitState = units[id]
			var factor := -1.0 if mirror else 1.0
			hash.update(("%d:%d:%.3f:%.3f:%.3f:%s;" % [tick,id,unit.position.x*factor,unit.position.y*factor,unit.health,unit.enabled]).to_utf8_buffer())
		end_tick = tick
		if not hero.enabled: outcome = "hero_lost"; break
		if at_exit and not threat and not in_flight and tick-last_contact >= 30:
			safe_tick = tick; outcome = "disengaged"; break
		if at_exit and tick-exit_tick >= 100: outcome = "exit_reached_still_contested"; break
	check(shots[1] > 0,"pursuer actually fired")
	check(enemy_moved > 100.0,"pursuer actually advanced")
	return {"profile":profiles[profile].id,"count":count,"delay":delay,"mirror":mirror,"checks":checks,"invariant_failures":failures.duplicate(),"outcome":outcome,"end_tick":end_tick,"first_contact":first_contact,"retreat_tick":retreat_tick,"exit_tick":exit_tick,"safe_tick":safe_tick,"last_contact":last_contact,"soldiers_survived":alive(units,own.army,true),"hero_alive":units[own.hero].enabled,"enemy_survived":alive(units,enemy.army,true),"shots":shots,"damage_events":hit_events,"enemy_distance_sum":enemy_moved,"max_hero_core_gap":max_hero_gap,"hero_gap_ticks":gap_ticks,"trace":hash.finish().hex_encode()}

func _initialize() -> void:
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/legion34/v5/config.json")).profiles
	actual_map = load("res://data/maps/final_decision.tres") as MapDefinition
	var matrix := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--matrix": matrix = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var rows: Array[Dictionary] = []
	for profile in (range(5) if matrix else [0]):
		for count in ([12,60] if matrix else [12]):
			for delay in [0,30]:
				for mirror in ([false,true] if matrix else [false]):
					var row := run_pursuit(profile,count,delay,mirror)
					rows.append(row)
					FileAccess.open(output.trim_suffix(".json")+"-partial.json",FileAccess.WRITE).store_string(JSON.stringify({"results":rows,"complete":false}))
					print("LEGION41_PROTECTED_PROGRESS ",row.profile," count=",count," delay=",delay," mirror=",mirror," outcome=",row.outcome," remaining=",row.soldiers_survived," failures=",row.invariant_failures)
	var failed := rows.any(func(r: Dictionary) -> bool: return not r.invariant_failures.is_empty())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PROTOTYPE","cases":rows.size(),"results":rows,"invariants_failed":failed,"layout":"middle_batch_toward_exit","scope":"dynamic visible mobile-legion pursuit on actual narrow route; not full production formation"}))
	print("LEGION41_PROTECTED_DONE cases=",rows.size()," invariants_failed=",failed)
	quit(1 if failed else 0)
