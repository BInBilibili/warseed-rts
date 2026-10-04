extends SceneTree
# Isolated traversal of actual map geometry. Traffic fixtures below test the
# proposed arbitration state machine, not production combat or dynamic physics.

const OUT := "res://artifacts/legion34/v5/"
const TerrainProjection = preload("res://tests/tools/legion34_terrain.gd")
var terrain_projection = TerrainProjection.new()
var errors: Array[String] = []
var profiles: Array = []
var results: Array = []
var grid: LogicGrid
var map: MapDefinition
var center := Vector2.ZERO
var include_hq := false

func _initialize() -> void:
	profiles = JSON.parse_string(FileAccess.get_file_as_string(OUT+"config.json")).profiles
	map = load("res://data/maps/final_decision.tres") as MapDefinition
	grid = LogicGrid.create_for_map(map)
	center = grid.get_world_rect().get_center()
	var mode := "smoke"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode=arg.trim_prefix("--mode=")
	include_hq = mode == "envelope"
	if include_hq:
		var battle := load("res://data/battles/final_decision.tres") as BattleDefinition
		var hq := load("res://data/buildings/command_center.tres") as BuildingDefinition
		for location in [battle.player_headquarters_position,battle.enemy_headquarters_position]:
			for cell in grid.get_footprint_cells(location,hq.footprint_size): grid.set_blocked(cell,true)
	if mode == "traffic":
		for same in [false,true]:
			for stopped in [false,true]:
				for closed in [false,true]:
					results.append(traffic(same,stopped,closed,false))
		results.append(traffic(false,false,false,true))
	else:
		var roads: Array = []
		roads.append_array(map.lanes)
		roads.append_array(map.connectors)
		for road in roads:
			var id: String = String(road.lane_id) if road is MapLaneDefinition else String(road.connector_id)
			if mode == "smoke" and id != "upper_river_link": continue
			if mode == "symmetry" and id not in ["top","mid","bottom"]: continue
			var stages: Array = [60] if mode == "smoke" else ([36] if mode=="symmetry" else [12,24,36,48,60])
			for count in stages:
				var profile := int(count/12)-1
				for reverse in [false,true]:
					var reference: Dictionary = {}
					for mirror in [false,true]:
						var row := traverse(id,road.route_points,road.width_cells*32,profile,count,reverse,mirror)
						if not mirror: reference=row
						else:
							if row.finish_tick != reference.finish_tick or row.path_errors != reference.path_errors:
								errors.append("mirror_difference:"+id+":"+str(count)+":"+str(reverse))
						results.append(row)
			print("MAP_PROGRESS ",id," cases=",results.size())
	var report := {"evidence":"SIMULATED_PROTOTYPE", "mode":mode,"cases":results.size(),"errors":errors,"results":results,
		"scope":"Actual map navigation; pre-collected batches; traffic is a separate deterministic reservation fixture; no enemy battle, gathering, production command/UI/economy verification."}
	FileAccess.open(OUT+"map_"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("LEGION34_MAP_DONE ",mode," cases=",results.size()," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)

func lane_points(route: PackedVector2Array, offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(route.size()):
		var before := (route[i]-route[maxi(0,i-1)]).normalized() if i>0 else (route[1]-route[0]).normalized()
		var after := (route[mini(route.size()-1,i+1)]-route[i]).normalized() if i<route.size()-1 else before
		var n1 := Vector2(-before.y,before.x)
		var n2 := Vector2(-after.y,after.x)
		var normal := (n1+n2).normalized()
		points.append(route[i]+normal*offset/maxf(0.25,normal.dot(n1)))
	return points

func at_distance(points: PackedVector2Array, cumulative: PackedFloat64Array, distance: float) -> Vector2:
	for i in range(1,points.size()):
		if distance <= cumulative[i]:
			return points[i-1].lerp(points[i],clampf((distance-cumulative[i-1])/(cumulative[i]-cumulative[i-1]),0,1))
	return points[-1]

func traverse(id: String, source: PackedVector2Array, width: int, profile: int, soldiers: int, reverse: bool, mirror: bool) -> Dictionary:
	var route := source.duplicate()
	if include_hq and id in ["top","mid","bottom"]:
		# The headquarters center is occupied. Arrival is at its public approach
		# apron, not inside the building footprint.
		route[0] = route[0].move_toward(route[1],768)
		route[-1] = route[-1].move_toward(route[-2],768)
	if reverse: route.reverse()
	if mirror:
		for i in range(route.size()): route[i]=map.mirror_point(route[i])
	# A common map-centered coordinate frame avoids different float32 ULPs
	# near opposite world edges. No reference run or opponent state is used.
	for i in range(route.size()): route[i]-=center
	var columns := 8 if width>=1024 else (4 if width>=512 else 3)
	var n := soldiers+1
	var batch_count := ceili(n/12.0)
	var batches: Array[int] = []
	for b in range(batch_count): batches.append(n/batch_count+int(b<n%batch_count))
	var cumulative := PackedFloat64Array([0])
	for i in range(1,route.size()): cumulative.append(cumulative[-1]+route[i-1].distance_to(route[i]))
	var tracks: Array[PackedVector2Array] = []
	for column in range(columns): tracks.append(lane_points(route,(column-(columns-1)*0.5)*48))
	var envelope_errors := 0
	if include_hq:
		for track in tracks:
			for segment in range(1,track.size()):
				var steps := ceili(track[segment-1].distance_to(track[segment])/32.0)
				for sample in range(steps+1):
					var point := track[segment-1].lerp(track[segment],float(sample)/maxi(1,steps))+center
					for y in [-32.0,0.0,32.0]:
						for x in [-32.0,0.0,32.0]:
							if not grid.is_world_position_walkable(point+Vector2(x,y)): envelope_errors+=1
	var entities: Array[UnitState] = []
	var lane_for: Array[int] = []
	var lag: Array[float] = []
	var progress: Array[float] = []
	var kinds: Array[int] = []
	var p: Dictionary = profiles[profile]
	var counts: Array[int]=[]
	for v in p.start: counts.append(int(v))
	for s in range(soldiers-12): counts[int(p.growth_roles[s])]+=1
	# Distribute real guards through the column, then insert the real hero at
	# the middle. Every entity keeps a stable ID; no synthetic escort units.
	var guards: Array[int]=[]
	var others: Array[int]=[]
	for role in range(4):
		for i in range(counts[role]):
			if role in [1,2]: guards.append(role)
			else: others.append(role)
	while not guards.is_empty() or not others.is_empty():
		if not guards.is_empty(): kinds.append(guards.pop_front())
		if not others.is_empty(): kinds.append(others.pop_front())
	kinds.insert(n/2,4)
	var pace := float(p.hero.speed)
	for role in range(4):
		if counts[role]>0 and role!=0: pace=minf(pace,float(p.troops[role].speed))
	var depth := 0.0
	for b in range(batch_count):
		for i in range(batches[b]):
			lag.append(depth+floori(i/float(columns))*48)
			lane_for.append(i%columns)
		depth += (ceili(batches[b]/float(columns))-1)*48+64
		if b<batch_count-1: depth+=96
	var front := depth+64.0
	for i in range(n):
		var role := kinds[i]
		var speed := float(p.hero.speed if role==4 else p.troops[role].speed)
		progress.append(front-lag[i])
		entities.append(UnitState.new(i+1,at_distance(tracks[lane_for[i]],cumulative,progress[i]),speed,1))
	var bad_paths := 0
	var overspeed := 0
	var near_pairs := 0
	var samples := 0
	var head_arrival := -1
	var core_arrival := -1
	var finish := -1
	var max_gap := 0.0
	var min_actual_pace:=pace
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	# Observe each unit crossing the exit section, not just reaching a trailing
	# slot while the tail is still inside the road. Exit parking is a separate
	# capacity fixture, not silently claimed by this trajectory experiment.
	var target := cumulative[-1]-64.0
	for tick in range(10000):
		var actual_pace:=pace
		for i in range(n):
			var role:=kinds[i]
			entities[i].move_speed=float(p.hero.speed if role==4 else p.troops[role].speed)*terrain_projection.multiplier(entities[i].position+center,role)
			if entities[i].enabled and role!=0:actual_pace=minf(actual_pace,entities[i].move_speed)
		min_actual_pace=minf(min_actual_pace,actual_pace)
		var maximum_lag := 0.0
		for i in range(n):
			if entities[i].enabled: maximum_lag=maxf(maximum_lag,minf(target,front-lag[i])-progress[i])
		front=minf(target+lag[-1],front+actual_pace*0.1*(0.25 if maximum_lag>96 else 1.0))
		var arrived := 0
		for i in range(n):
			var u:=entities[i]
			if not u.enabled:
				arrived+=1
				continue
			var old:=u.position
			var next:=minf(target,minf(front-lag[i],progress[i]+u.move_speed*0.1))
			for ahead in range(i):
				if entities[ahead].enabled and lane_for[ahead] == lane_for[i]:
					next=minf(next,progress[ahead]-(lag[i]-lag[ahead]))
			next=maxf(progress[i],next)
			var position:=at_distance(tracks[lane_for[i]],cumulative,next)
			if old.distance_to(position)>u.move_speed*0.1:
				var low:=progress[i]
				var high:=next
				for retry in range(12):
					var mid:=(low+high)*0.5
					if old.distance_to(at_distance(tracks[lane_for[i]],cumulative,mid))>u.move_speed*0.1:high=mid
					else:low=mid
				next=low
				position=at_distance(tracks[lane_for[i]],cumulative,next)
			for other in range(n):
				if other != i and entities[other].enabled and position.distance_to(entities[other].position)<24:
					next=progress[i]
					position=old
					break
			if not grid.is_segment_walkable(old+center,position+center):bad_paths+=1
			if old.distance_to(position)>u.move_speed*0.1+0.01:overspeed+=1
			u.position=position
			progress[i]=next
			samples+=1
			if target-progress[i]<1:
				arrived+=1
				u.enabled=false
		if head_arrival<0 and target-progress[0]<1:head_arrival=tick
		if core_arrival<0 and target-progress[n/2]<1:core_arrival=tick
		if tick%10==0:
			var hero:UnitState=entities[n/2]
			var nearest:=INF
			for i in range(n):
				if not entities[i].enabled:continue
				if kinds[i] in [1,2]:nearest=minf(nearest,hero.position.distance_to(entities[i].position))
				for j in range(i):
					if entities[j].enabled and entities[i].position.distance_to(entities[j].position)<24:near_pairs+=1
			if hero.enabled and nearest<INF:max_gap=maxf(max_gap,nearest)
			hash.update((str(tick)+":"+str(front)+":"+str(arrived)).to_utf8_buffer())
		if arrived==n:finish=tick;break
	var row:Dictionary={"road":id,"width":width,"columns":columns,"profile":p.id,"soldiers":soldiers,"entities":n,"batches":batches,"depth":depth,"reverse":reverse,"mirror":mirror,"length":cumulative[-1],"pace":pace,"finish_tick":finish,"head_arrival":head_arrival,"core_arrival":core_arrival,"max_hero_gap":max_gap,"path_errors":bad_paths,"speed_errors":overspeed,"near_pairs":near_pairs,"samples":samples,"pre_collected":true,"exit_crossing_only":true,"trace":hash.finish().hex_encode()}
	row["coordinate_frame"]="map_center"
	row["minimum_terrain_pace"]=min_actual_pace
	row["hq_occupancy"]=include_hq
	row["envelope_errors"]=envelope_errors
	if envelope_errors:errors.append("envelope:"+id+":"+str(soldiers)+":"+str(reverse)+":"+str(mirror)+":"+str(envelope_errors))
	if bad_paths or overspeed or finish<0 or near_pairs:errors.append("traversal:"+id+":"+str(soldiers)+":"+str(reverse)+":"+str(mirror)+":"+str([bad_paths,overspeed,finish,near_pairs]))
	return row

func traffic(same: bool, stopped: bool, closed: bool, permanent: bool) -> Dictionary:
	# Segments measured from the actual rear->major route. A, B, C are friendly
	# columns. B is an approved relief; C a dangerous withdrawal. Reservations
	# admit only batches with a real exit pocket. Position occupancy persists
	# after an intent is cancelled, including the final batch of a long segment.
	var length:=Vector2(4864,16384).distance_to(Vector2(8192,9216))
	var positions:Dictionary={}
	var entered:Dictionary={}
	var exited:Dictionary={}
	var outstanding:Dictionary={0:6,1:6,2:2}
	var direction:Dictionary={0:1,1:1 if same else -1,2:-1}
	var priority:Dictionary={0:0,1:1,2:2}
	var waits:Dictionary={0:0,1:20,2:40}
	var current_direction:=0
	var last_entry:=-1000
	var errors_count:=0
	var blocked_ticks:=0
	var switches:=0
	var close_requested:=false
	var last_exit_tick:=-1
	var elapsed:=0
	for tick in range(14000):
		elapsed=tick
		var exit_blocked:bool=(closed and tick<400) or permanent
		var manually_stopped:bool=stopped and tick<300
		for key in positions.keys():
			positions[key]+=135.0*0.1
			if positions[key]>=length+208:
				positions.erase(key)
				exited[key]=tick
				last_exit_tick=tick
		if positions.is_empty():
			current_direction=0
			close_requested=false
		var candidates:Array[int]=[]
		for group in outstanding:
			if outstanding[group]>0 and tick>=waits[group]:candidates.append(group)
		candidates.sort_custom(func(a:int,b:int)->bool:
			return priority[a]>priority[b] if priority[a]!=priority[b] else waits[a]<waits[b])
		if candidates.is_empty() and positions.is_empty():break
		if candidates.is_empty():continue
		var group:=candidates[0]
		if current_direction!=0 and direction[group]!=current_direction:close_requested=true
		if exit_blocked or manually_stopped or close_requested:
			blocked_ticks+=1
			continue
		# A single exit bay accommodates one batch. Its occupancy is committed
		# on admission, so a full road cannot overbook the destination platform.
		if positions.size()>=1 or tick-last_entry<23:continue
		if current_direction==0:
			current_direction=direction[group]
			switches+=1
		if current_direction!=direction[group]:errors_count+=1
		var key:=str(group)+":"+str(outstanding[group])
		outstanding[group]-=1
		positions[key]=0.0
		entered[key]=tick
		last_entry=tick
	var finished:bool=outstanding.values().all(func(v:int)->bool:return v==0) and positions.is_empty()
	if errors_count or (not permanent and not finished) or (permanent and not entered.is_empty()):
		errors.append("traffic:"+str([same,stopped,closed,permanent,finished,errors_count]))
	return {"same_direction":same,"manual_stop":stopped,"temporary_exit_block":closed,"permanent_block":permanent,"length":length,"entered":entered,"exited":exited,"remaining":outstanding,"in_segment":positions.size(),"completed":finished,"elapsed":elapsed,"blocked_ticks":blocked_ticks,"direction_phases":switches,"violations":errors_count,"last_exit_tick":last_exit_tick}
