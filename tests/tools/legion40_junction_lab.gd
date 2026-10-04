extends "res://tests/tools/legion34_transition_lab.gd"

# Three physical columns merge on the existing upper-major platform. This
# fixture does not implement the world command pipeline or cyclic exit waits.
class Batch extends RefCounted:
	var group := 0
	var index := 0
	var ids: Array[int] = []
	var lag: Array[float] = []
	var column: Array[int] = []
	var progress: Array[float] = []
	var target_front := 0.0
	var admitted := -1
	var cleared := -1
	var finished := -1
	var serial := -1
	var wait_since := -1
	func tail() -> float:
		return progress.min()

var center := Vector2.ZERO
var in_rays: Array[Vector2] = []
var out_ray := Vector2.ZERO
var buckets: Dictionary = {}
var claims: Array[Vector2] = []
var reserved_front_limit := 7200.0
var defects: Array[String] = []
var checks := 0
var output := "res://artifacts/legion40/smoke01.json"

func expect(value: bool, reason: String) -> void:
	checks += 1
	if not value and not defects.has(reason): defects.append(reason)

func cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x/64.0),floori(position.y/64.0))

func insert_position(id: int, position: Vector2) -> void:
	var key := cell(position)
	if not buckets.has(key): buckets[key] = []
	buckets[key].append(id)

func nearby(position: Vector2, radius: float = 48.0) -> Array[int]:
	var found: Array[int] = []
	var lo := cell(position-Vector2.ONE*radius)
	var hi := cell(position+Vector2.ONE*radius)
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			for id in buckets.get(Vector2i(x,y),[]): found.append(id)
	return found

func point(group: int, progress: float, column: int) -> Vector2:
	var incoming := -in_rays[group]
	var normal_in := Vector2(-incoming.y,incoming.x)
	var normal_out := Vector2(-out_ray.y,out_ray.x)
	# A circular fillet keeps distinct lane radii through the sharp turn.
	# Each member still obeys its physical per-tick travel budget.
	var angle := incoming.angle_to(out_ray)
	var radius := 160.0
	var setback := radius*tan(absf(angle)*0.5)
	var arc_length := radius*absf(angle)
	var arc_end := -setback+arc_length
	# After the turn every approach uses the same outgoing distance. Different
	# turn lengths must not reserve one physical exit with incompatible scalars.
	progress -= 2.0*setback-arc_length
	var tangent_point: Vector2
	var normal: Vector2
	if progress < -setback:
		tangent_point = center+incoming*progress
		normal = normal_in
	elif progress > arc_end:
		tangent_point = center+out_ray*(setback+progress-arc_end)
		normal = normal_out
	else:
		var begin := center-incoming*setback
		var pivot := begin+normal_in*radius*signf(angle)
		var rotated := angle*(progress+setback)/maxf(0.001,arc_length)
		tangent_point = pivot+(begin-pivot).rotated(rotated)
		var tangent := incoming.rotated(rotated)
		normal = Vector2(-tangent.y,tangent.x)
	return tangent_point+normal*(column-1)*48.0

func move_member(unit: UnitState, candidate: Vector2, units: Dictionary) -> bool:
	if not actual_grid.is_segment_walkable(unit.position+origin,candidate+origin): return false
	for other_id in nearby(candidate):
		if other_id == unit.entity_id: continue
		var other: UnitState = units[other_id]
		if Geometry2D.get_closest_point_to_segment(other.position,unit.position,candidate).distance_squared_to(other.position) < 24.0*24.0-0.01: return false
	buckets[cell(unit.position)].erase(unit.entity_id)
	unit.position = candidate
	insert_position(unit.entity_id,candidate)
	return true

func reserve_exit(batch: Batch, units: Dictionary) -> bool:
	# Capacity derives from real slots/occupants and all outstanding promises.
	# The existing outgoing corridor has no need for a newly invented platform.
	for front in range(7200,1200,-48):
		if front > reserved_front_limit: continue
		var slots: Array[Vector2] = []
		var valid := true
		for i in range(batch.ids.size()):
			var position := point(batch.group,front-batch.lag[i],batch.column[i])
			if not actual_grid.is_world_position_walkable(position+origin): valid = false; break
			for claimed in claims:
				if position.distance_to(claimed) < 159.99: valid = false; break
			if not valid: break
			slots.append(position)
		if valid:
			# A passing earlier batch can temporarily occupy these slots. Wait
			# for it instead of wasting this space then allowing a later batch
			# to reserve ahead of an already parked predecessor.
			for position in slots:
				for id in nearby(position,160.0):
					if position.distance_to(units[id].position) < 159.99: return false
			batch.target_front = front
			reserved_front_limit = front-batch.lag.max()-160.0
			claims.append_array(slots)
			return true
	return false

func junction(count: int, scenario: String, mirror: bool) -> Dictionary:
	defects = []
	checks = 0
	buckets.clear()
	claims.clear()
	reserved_front_limit = 7200.0
	unmodified_speeds.clear()
	actual_grid = LogicGrid.create_for_map(actual_map)
	origin = actual_grid.get_world_rect().get_center()
	var sign_value := -1.0 if mirror else 1.0
	center = (Vector2(8192,9216)-origin)*sign_value
	in_rays = [(Vector2(2048,12288)-Vector2(8192,9216)).normalized()*sign_value,(Vector2(12288,8192)-Vector2(8192,9216)).normalized()*sign_value,(Vector2(10688,16384)-Vector2(8192,9216)).normalized()*sign_value]
	out_ray = (Vector2(4864,16384)-Vector2(8192,9216)).normalized()*sign_value
	var units: Dictionary = {}
	var armies: Array[LabFormation] = []
	var batches: Array[Batch] = []
	var profile_ids := [0,1,4]
	for group in range(3):
		var army := spawn_army(profile_ids[group],count,1,group*100+1,Vector2.ZERO,-in_rays[group],"move","special",units)
		armies.append(army)
		var core: Array[int] = []
		var others: Array[int] = []
		var ordered: Array[int] = []
		for id in army.member_entity_ids:
			if role_of(units[id]) in [1,2]: core.append(id)
			elif role_of(units[id]) != 4: others.append(id)
		while not core.is_empty() or not others.is_empty():
			if not core.is_empty(): ordered.append(core.pop_front())
			if not others.is_empty(): ordered.append(others.pop_front())
		var hero_id: int = army.member_entity_ids[-1]
		ordered.insert(ordered.size()/2,hero_id)
		var n := ordered.size()
		var batch_count := ceili(n/12.0)
		var cursor := 0
		var depth := 0.0
		for index in range(batch_count):
			var batch := Batch.new()
			batch.group = group
			batch.index = index
			var size: int = n/batch_count+int(index<n%batch_count)
			for i in range(size):
				var id := ordered[cursor]
				cursor += 1
				batch.ids.append(id)
				batch.lag.append(floori(i/3.0)*48.0)
				batch.column.append(i%3)
				batch.progress.append(-832.0-depth-batch.lag[-1])
				units[id].position = point(group,batch.progress[-1],i%3)
				insert_position(id,units[id].position)
			expect(size <= 12,"batch at most twelve real entities")
			if batch.ids.has(hero_id):
				expect(batch.ids.any(func(id: int) -> bool: return role_of(units[id]) in [1,2]),"hero shares batch with actual core")
			batches.append(batch)
			depth += batch.lag.max()+160.0
	if scenario == "exit_occupied":
		for p in range(1152,7297,96):
			for col in range(3):
				var id := 1000+units.size()
				var blocker := UnitState.new(id,point(0,p,col),0.0,1)
				blocker.definition_id = &"lab_1"
				units[id] = blocker
				insert_position(id,blocker.position)
	var expected_count := units.size()
	var owner: Batch
	var next_group := 0
	var serial := 0
	var stop_tick := -1
	var stopped_group := -1
	var grants: Array[Dictionary] = []
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	var state := "timeout"
	var ended := -1
	var max_hero_gap := 0.0
	var stationary_ticks := 0
	for tick in range(8000):
		refresh_speeds(units)
		if owner != null and owner.tail() > 704.0:
			for id in owner.ids: expect(units[id].position.distance_to(center) > 672.0,"release only after actual tail clears conflict")
			owner.cleared = tick
			owner = null
		if owner == null:
			var ready: Array[Batch] = []
			for batch in batches:
				if batch.admitted < 0 and batch.progress[0] >= -720.01:
					if batch.wait_since < 0: batch.wait_since = tick
					ready.append(batch)
			ready.sort_custom(func(a: Batch,b: Batch) -> bool:
				if a.wait_since != b.wait_since: return a.wait_since < b.wait_since
				return (a.group-next_group+3)%3 < (b.group-next_group+3)%3)
			for batch in ready:
				if scenario == "exit_occupied" and tick%10 != 0: continue
				if not reserve_exit(batch,units): continue
				batch.admitted = tick
				batch.serial = serial
				serial += 1
				owner = batch
				next_group = (batch.group+1)%3
				grants.append({"group":batch.group,"batch":batch.index,"tick":tick,"exit_front":batch.target_front})
				break
		if stop_tick < 0 and scenario in ["manual_resumes","permanent_stop"] and owner != null and tick-owner.admitted >= 5:
			stop_tick = tick
			stopped_group = owner.group
		var held := stop_tick >= 0 and (scenario == "permanent_stop" or tick-stop_tick < 200)
		var before: Dictionary = {}
		for id in units: before[id] = units[id].position
		var ordered_batches: Array[Batch] = []
		ordered_batches.assign(batches)
		ordered_batches.sort_custom(func(a: Batch,b: Batch) -> bool:
			if (a.admitted >= 0) != (b.admitted >= 0): return a.admitted >= 0
			if a.admitted >= 0: return a.serial < b.serial
			return a.group < b.group or a.group == b.group and a.index < b.index)
		for batch in ordered_batches:
			if batch.finished >= 0 or held and batch.group == stopped_group: continue
			var pace := current_pace(armies[batch.group],units)
			var front_limit := batch.target_front if batch.admitted >= 0 else -720.0
			for other in batches:
				if other == batch: continue
				if batch.admitted >= 0 and other.admitted >= 0 and other.serial < batch.serial and other.tail() >= 0:
					front_limit = minf(front_limit,other.tail()-160.0)
				elif batch.admitted < 0 and other.group == batch.group and other.index < batch.index:
					front_limit = minf(front_limit,other.tail()-160.0)
			for i in range(batch.ids.size()):
				var u: UnitState = units[batch.ids[i]]
				var goal := front_limit-batch.lag[i]
				var next := maxf(batch.progress[i],minf(goal,batch.progress[i]+pace*0.1))
				var candidate := point(batch.group,next,batch.column[i])
				if u.position.distance_to(candidate) > u.move_speed*0.1:
					var lo := batch.progress[i]
					var hi := next
					for retry in range(14):
						var mid := (lo+hi)*0.5
						if u.position.distance_to(point(batch.group,mid,batch.column[i])) > u.move_speed*0.1: hi = mid
						else: lo = mid
					next = lo
					candidate = point(batch.group,next,batch.column[i])
				if move_member(u,candidate,units): batch.progress[i] = next
			var arrived := batch.admitted >= 0
			for i in range(batch.ids.size()):
				if absf(batch.progress[i]-(batch.target_front-batch.lag[i])) > 0.1: arrived = false
			if arrived: batch.finished = tick
			for id in batch.ids:
				if role_of(units[id]) != 4: continue
				var nearest := INF
				for core_id in batch.ids:
					if role_of(units[core_id]) in [1,2]: nearest = minf(nearest,units[id].position.distance_to(units[core_id].position))
				max_hero_gap = maxf(max_hero_gap,nearest)
				expect(nearest <= 240.01,"hero remains near its physical batch core")
		var conflict_batches := 0
		for batch in batches:
			var inside := false
			for id in batch.ids:
				if units[id].position.distance_to(center) < 672.0: inside = true
			if inside:
				conflict_batches += 1
				expect(batch == owner,"every physical conflict occupant owns the junction")
			if held and batch.group == stopped_group:
				for id in batch.ids: expect(units[id].position == before[id],"manual stop preserves actual position")
		expect(conflict_batches <= 1,"no intersecting batch admission")
		for id in units:
			var u: UnitState = units[id]
			expect(before[id].distance_to(u.position) <= u.move_speed*0.1+0.01,"physical tick speed bounded")
			expect(actual_grid.is_segment_walkable(before[id]+origin,u.position+origin),"physical path walkable")
			for other in nearby(u.position,24.0):
				if other < id: expect(u.position.distance_to(units[other].position) >= 23.99,"physical separation at least 24")
			trace.update(("%d:%d:%.3f:%.3f;" % [tick,id,u.position.x*sign_value,u.position.y*sign_value]).to_utf8_buffer())
		expect(units.size() == expected_count,"exited and stopped units retain occupancy")
		var changed := false
		for id in units:
			if units[id].position.distance_to(before[id]) > 0.001: changed = true; break
		stationary_ticks = 0 if changed else stationary_ticks+1
		if batches.all(func(b: Batch) -> bool: return b.finished >= 0): state = "done"; ended = tick; break
		if scenario == "permanent_stop" and stop_tick >= 0 and tick-stop_tick >= 120: state = "blocked_manual"; ended = tick; break
		if scenario == "exit_occupied" and tick >= 120: state = "blocked_capacity"; ended = tick; break
		if not held and scenario != "exit_occupied" and stationary_ticks >= 200:
			state = "stalled"; ended = tick; break
	var expected := "blocked_manual" if scenario == "permanent_stop" else ("blocked_capacity" if scenario == "exit_occupied" else "done")
	expect(state == expected,"expected completion or explicit blocking")
	if scenario == "exit_occupied": expect(grants.is_empty(),"actual occupied exit admits nobody")
	if scenario == "permanent_stop": expect(grants.size() == 1 and owner != null,"manual blockage never times out its physical owner")
	var rows: Array[Dictionary] = []
	for batch in batches: rows.append({"group":batch.group,"batch":batch.index,"size":batch.ids.size(),"admitted":batch.admitted,"tail_clear":batch.cleared,"finished":batch.finished,"progress":batch.progress})
	return {"soldiers_per_legion":count,"scenario":scenario,"mirror":mirror,"state":state,"tick":ended,"checks":checks,"failures":defects.duplicate(),"grants":grants,"batches":rows,"entities_retained":units.size(),"max_hero_core_gap":max_hero_gap,"trace":trace.finish().hex_encode()}

func _initialize() -> void:
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/legion34/v5/config.json")).profiles
	actual_map = load("res://data/maps/final_decision.tres") as MapDefinition
	var matrix := false
	var full_smoke := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--matrix": matrix = true
		if arg == "--full-smoke": full_smoke = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var rows: Array[Dictionary] = []
	for count in ([12,60] if matrix else ([60] if full_smoke else [12])):
		for scenario in (["normal","manual_resumes","permanent_stop","exit_occupied"] if matrix else ["normal"]):
			for mirror in ([false,true] if matrix else [false]):
				var result := junction(count,scenario,mirror)
				rows.append(result)
				FileAccess.open(output.trim_suffix(".json")+"-partial.json",FileAccess.WRITE).store_string(JSON.stringify({"results":rows,"complete":false}))
				print("LEGION40_PROGRESS count=",count," scenario=",scenario," mirror=",mirror," state=",result.state," failures=",result.failures)
	var failed := rows.any(func(r: Dictionary) -> bool: return not r.failures.is_empty())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PROTOTYPE","cases":rows.size(),"results":rows,"failed":failed,"scope":"three physical legions merging on actual upper-major; not cyclic exit deadlocks, combat or production"}))
	print("LEGION40_DONE cases=",rows.size()," failed=",failed)
	quit(1 if failed else 0)
