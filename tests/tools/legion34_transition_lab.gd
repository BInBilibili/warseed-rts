extends "res://tests/tools/legion34_candidate_lab.gd"
# Independent physical transition experiment. Uses real map walkability,
# candidate UnitState statistics and production CombatSystem; NOT the world
# command pipeline. Every survivor remains physically present at the exit.

const TRANSITION_OUT := "res://artifacts/legion34/v5/"
const TerrainProjection = preload("res://tests/tools/legion34_terrain.gd")
var terrain_projection = TerrainProjection.new()
var unmodified_speeds:Dictionary={}
var actual_map: MapDefinition
var actual_grid: LogicGrid
var origin := Vector2.ZERO
var route := PackedVector2Array()
var lengths := PackedFloat64Array()
var tracks: Array[PackedVector2Array] = []

func _initialize() -> void:
	profiles = JSON.parse_string(FileAccess.get_file_as_string(TRANSITION_OUT+"config.json")).profiles
	actual_map = load("res://data/maps/final_decision.tres") as MapDefinition
	var mode := "smoke"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode=arg.trim_prefix("--mode=")
	var scenarios: Array = ["gather", "contact_retreat", "cut", "cancel", "exit_blocked", "manual_stop"]
	if mode=="cut":scenarios=["cut"]
	for profile in range(5):
		if mode == "smoke" and profile != 2: continue
		for count in ([12] if mode == "smoke" else [12,24,36,48,60]):
			for scenario in scenarios:
				for mirror in ([false] if mode == "smoke" else [false,true]):
					var row := transition(profile,count,scenario,mirror)
					results.append(row)
					if not row.invariant_errors.is_empty(): errors.append(row.key)
				print("TRANSITION_PROGRESS ",profile," ",count," ",scenario)
	var report := {"evidence":"SIMULATED_PROTOTYPE","mode":mode,"cases":results.size(),"errors":errors,"results":results,
		"scope":"Actual upper_rear route and rotated counterpart; broad-to-column and retained exit occupancy; prescribed contact and public corridor cut; no economy, world commands, organization recovery or full match."}
	FileAccess.open(TRANSITION_OUT+"transition_"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("TRANSITION_DONE cases=",results.size()," invariant_errors=",errors.size())
	quit(0 if errors.is_empty() else 1)

func build_route(mirror: bool) -> void:
	unmodified_speeds.clear()
	actual_grid = LogicGrid.create_for_map(actual_map)
	origin = actual_grid.get_world_rect().get_center()
	var battle_def := load("res://data/battles/final_decision.tres") as BattleDefinition
	var hq := load("res://data/buildings/command_center.tres") as BuildingDefinition
	for location in [battle_def.player_headquarters_position,battle_def.enemy_headquarters_position]:
		for cell in actual_grid.get_footprint_cells(location,hq.footprint_size): actual_grid.set_blocked(cell,true)
	# Main road approach -> actual two-leg upper_rear -> main road departure.
	route=PackedVector2Array([Vector2(2048,21000),Vector2(2048,18432),Vector2(4864,16384),Vector2(6656,19456),Vector2(10688,16384)])
	for i in range(route.size()): route[i]=(actual_map.mirror_point(route[i]) if mirror else route[i])-origin
	lengths=PackedFloat64Array([0])
	for i in range(1,route.size()): lengths.append(lengths[-1]+route[i-1].distance_to(route[i]))
	tracks.clear()
	for column in range(3):
		var track:=PackedVector2Array()
		for i in range(route.size()):
			var before: Vector2=(route[i]-route[i-1]).normalized() if i>0 else (route[1]-route[0]).normalized()
			var after: Vector2=(route[i+1]-route[i]).normalized() if i<route.size()-1 else before
			var n1:=Vector2(-before.y,before.x)
			var n2:=Vector2(-after.y,after.x)
			var normal:=(n1+n2).normalized()
			track.append(route[i]+normal*(column-1)*48/maxf(0.25,normal.dot(n1)))
		tracks.append(track)

func point_at(distance: float, column: int) -> Vector2:
	for i in range(1,route.size()):
		if distance<=lengths[i]:
			var tangent:=(route[i]-route[i-1]).normalized()
			var offset:=Vector2(-tangent.y,tangent.x)*(column-1)*48
			var local:=distance-lengths[i-1]
			var remaining:=lengths[i]-distance
			# Blend the miter only within 128 of a corner. Applying its offset
			# along the entire straight segment shears nominal transverse rows.
			if i>1 and local<128: return tracks[column][i-1].lerp(route[i-1]+tangent*128+offset,maxf(0,local)/128)
			if i<route.size()-1 and remaining<128: return (route[i]-tangent*128+offset).lerp(tracks[column][i],1-remaining/128)
			return route[i-1]+tangent*local+offset
	return tracks[column][-1]

func role_of(unit: UnitState) -> int:
	return int(String(unit.definition_id).trim_prefix("lab_"))

func refresh_speeds(units: Dictionary) -> void:
	for id in units:
		var u:UnitState=units[id]
		if not unmodified_speeds.has(id):unmodified_speeds[id]=u.move_speed
		u.move_speed=unmodified_speeds[id]*terrain_projection.multiplier(u.position+origin,role_of(u))

func current_pace(army: LabFormation, units: Dictionary) -> float:
	var pace:=army.pace
	for id in army.member_entity_ids:
		if units[id].enabled and role_of(units[id])!=0:pace=minf(pace,units[id].move_speed)
	return pace

func legal_motion(old: Vector2, target: Vector2, id: int, units: Dictionary) -> bool:
	if not actual_grid.is_segment_walkable(old+origin,target+origin): return false
	for other_id in units:
		var other: UnitState=units[other_id]
		if other_id!=id and other.enabled and Geometry2D.get_closest_point_to_segment(other.position,old,target).distance_squared_to(other.position)<24*24-0.01: return false
	return true

func move_slot(u: UnitState, target: Vector2, units: Dictionary) -> void:
	var old:=u.position
	var next:=old.move_toward(target,u.move_speed*0.1)
	if legal_motion(old,next,u.entity_id,units): u.position=next
	u.has_move_target=u.position.distance_to(old)>0.01

func transition(profile: int, count: int, scenario: String, mirror: bool) -> Dictionary:
	build_route(mirror)
	var units:Dictionary={}
	var direction:=(route[1]-route[0]).normalized()
	var lateral:=Vector2(-direction.y,direction.x)
	var own:=spawn_army(profile,count,1,1,point_at(1928,1),direction,"move","special",units)
	var ids:Array[int]=[]
	var core_ids:Array[int]=[]
	var noncore:Array[int]=[]
	for id in own.member_entity_ids:
		if role_of(units[id]) in [1,2]: core_ids.append(id)
		elif role_of(units[id])!=4: noncore.append(id)
	while not core_ids.is_empty() or not noncore.is_empty():
		if not core_ids.is_empty(): ids.append(core_ids.pop_front())
		if not noncore.is_empty(): ids.append(noncore.pop_front())
	var hero_id:=own.member_entity_ids[-1]
	ids.insert(ids.size()/2,hero_id)
	var batch_count:=ceili(ids.size()/12.0)
	var lag:Array[float]=[]
	var column:Array[int]=[]
	var batch:Array[int]=[]
	var depth:=0.0
	for b in range(batch_count):
		var number:int=ids.size()/batch_count+int(b<ids.size()%batch_count)
		for j in range(number):
			lag.append(depth+floori(j/3.0)*48);column.append(j%3);batch.append(b)
		depth+=(ceili(number/3.0)-1)*48+64
		if b<batch_count-1: depth+=96
	# Preserve lateral order within each new row; a row can straddle an old
	# eight-column row boundary. Sorting prevents crossing targets at the merge.
	for i in range(ids.size()):
		var rank:=0
		for j in range(ids.size()):
			if lag[j]==lag[i] and j%8<i%8:rank+=1
		column[i]=rank
	var progress:Array[float]=[]
	var initial:Array[float]=[]
	for i in range(ids.size()):
		var p:=1928.0-lag[i]
		progress.append(p);initial.append(p)
		units[ids[i]].position=point_at(1928-floori(i/8.0)*48,1)+lateral*(i%8-3.5)*48
	var initial_positions:Dictionary={}
	for id in ids: initial_positions[id]=units[id].position
	var enemy:LabFormation
	if scenario=="contact_retreat":
		enemy=spawn_army(0,maxi(6,count/2),2,1001,point_at(4750,1),-direction,"defend","special",units)
		for i in range(enemy.member_entity_ids.size()): units[enemy.member_entity_ids[i]].position=point_at(4800+floori(i/3.0)*48,i%3)
	var state:="stretch"
	var state_log:Array=[{"tick":0,"state":state}]
	var front:=1928.0
	var gather_tick:=-1
	var head_tick:=-1
	var tail_tick:=-1
	var finish_tick:=-1
	var incident_tick:=-1
	var cut_distance:=-1.0
	var split_forward:Dictionary={}
	var held:Dictionary={}
	var narrow_slots:Array[Vector2]=[]
	for i in range(ids.size()): narrow_slots.append(point_at(initial[i],column[i]))
	var stretched_slots:Array[Vector2]=[]
	for i in range(ids.size()): stretched_slots.append(narrow_slots[i]+lateral*((i%8-3.5)*48-(narrow_slots[i]-point_at(initial[i],1)).dot(lateral)))
	var finals:Array[Vector2]=[]
	var final_front:=lengths[3]+640+depth
	var final_tangent:=(route[4]-route[3]).normalized()
	var lateral_slots:Array[Vector2]=[]
	for i in range(ids.size()): lateral_slots.append(point_at(final_front-lag[i],1)+Vector2(-final_tangent.y,final_tangent.x)*(i%8-3.5)*48)
	for i in range(ids.size()): finals.append(point_at(final_front-floori(i/8.0)*48,1)+Vector2(-final_tangent.y,final_tangent.x)*(i%8-3.5)*48)
	var invariant_errors:Array=[]
	var max_hero_gap:=0.0
	var hero_gap_ticks:=0
	var blocked_ticks:=0
	var minimum_batch_gap:=INF
	var core_tick:=-1
	var shots:=0
	var combat:=CombatSystem.new()
	var projectiles:Dictionary={}
	var projectile_id:=1
	var events:Array[SimulationEvent]=[]
	var hash:=HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	var stopped_at:Dictionary={}
	var frames:Array=[]
	for tick in range(5000):
		refresh_speeds(units)
		var terrain_pace:=current_pace(own,units)
		var previous_state:=state
		if state=="transit" and (float(progress.max()) if scenario=="cut" else front)>=(4640 if scenario=="contact_retreat" else 4100) and incident_tick<0 and scenario!="gather":
			incident_tick=tick
			if scenario=="contact_retreat": state="contact"
			elif scenario=="cancel": state="retreat"
			elif scenario=="exit_blocked": state="blocked"
			elif scenario=="manual_stop":
				state="blocked"
				for id in ids:
					if role_of(units[id])==1: stopped_at[id]=units[id].position
			elif scenario=="cut":
				state="split"
				# Select a real inter-batch gap. The closure is an explicit public
				# fixture input; neither units nor obstacles are placed over units.
				var ordered_progress:=progress.duplicate()
				ordered_progress.sort()
				var best_score:=INF
				for j in range(1,ordered_progress.size()):
					var middle:float=(ordered_progress[j-1]+ordered_progress[j])*0.5
					if ordered_progress[j]-ordered_progress[j-1]<128 or middle<lengths[1]+128 or middle>lengths[2]-128:continue
					var score:=absf(j-ids.size()*0.5)
					if score<best_score:best_score=score;cut_distance=middle
				assert(cut_distance>=0,"No unoccupied public-cut fixture location")
				var cp:=point_at(cut_distance,1)+origin
				var tangent:=(point_at(cut_distance+1,1)-point_at(cut_distance-1,1)).normalized()
				var normal:=Vector2(-tangent.y,tangent.x)
				for side in range(-8,9):
					var blocked_cell:=actual_grid.world_to_cell(cp+normal*side*32)
					for id in ids:assert(actual_grid.world_to_cell(units[id].position+origin)!=blocked_cell,"Cut fixture overlaps unit")
					actual_grid.set_blocked(blocked_cell,true)
				for i in range(ids.size()): split_forward[ids[i]]=progress[i]>cut_distance
		if state=="contact" and tick-incident_tick>=30: state="retreat"
		var order_ids:Array[int]=[]
		for i in range(ids.size()): order_ids.append(i)
		if state in ["stretch","gather","retreat"]: order_ids.reverse()
		if state in ["transit","split"]:
			var behind:=0.0
			for i in range(ids.size()):
				if units[ids[i]].enabled: behind=maxf(behind,front-lag[i]-progress[i])
			front=minf(final_front,front+terrain_pace*0.1*(0.25 if behind>96 else 1.0))
		var moved:=false
		for i in order_ids:
			var u:UnitState=units[ids[i]]
			if not u.enabled:continue
			var old:=u.position
			if state=="stretch": move_slot(u,stretched_slots[i],units)
			elif state=="gather": move_slot(u,narrow_slots[i],units)
			elif state=="widen_lateral": move_slot(u,lateral_slots[i],units)
			elif state=="widen": move_slot(u,finals[i],units)
			elif state in ["transit","retreat","split"]:
				var target:=final_front-lag[i]
				var signum:=1.0
				if state=="retreat" or (state=="split" and not split_forward[u.entity_id]): target=initial[i];signum=-1.0
				elif state=="transit": target=minf(target,front-lag[i])
				var next:=move_toward(progress[i],target,minf(terrain_pace,u.move_speed)*0.1)
				for j in range(ids.size()):
					if j==i or not units[ids[j]].enabled:continue
					# The gap is between COMPLETE batch envelopes, not merely
					# same-column neighbors; corner lag must propagate across lanes.
					if signum>0 and batch[j]==batch[i]-1:next=minf(next,progress[j]-160)
					if signum<0 and batch[j]==batch[i]+1:next=maxf(next,progress[j]+160)
					if column[j]!=column[i]:continue
					if signum*(progress[j]-progress[i])>0:
						var spacing:=48.0 if batch[j]==batch[i] else 160.0
						if signum>0: next=minf(next,progress[j]-spacing)
						else: next=maxf(next,progress[j]+spacing)
				if signum*(next-progress[i])<0:next=progress[i]
				var proposed:=point_at(next,column[i])
				# Track corner miters have unequal length; enforce real distance.
				if old.distance_to(proposed)>u.move_speed*0.1:
					var low:=0.0
					var high:=1.0
					for retry in range(14):
						var mid:=(low+high)*0.5
						if old.distance_to(point_at(lerpf(progress[i],next,mid),column[i]))>u.move_speed*0.1:high=mid
						else:low=mid
					next=lerpf(progress[i],next,low);proposed=point_at(next,column[i])
				if legal_motion(old,proposed,u.entity_id,units):u.position=proposed;progress[i]=next
			u.has_move_target=old.distance_to(u.position)>0.01
			moved=moved or u.has_move_target
			if old.distance_to(u.position)>u.move_speed*0.1+0.01: invariant_errors.append("speed")
			if not actual_grid.is_segment_walkable(old+origin,u.position+origin): invariant_errors.append("path")
			if stopped_at.has(u.entity_id) and u.position!=stopped_at[u.entity_id]:invariant_errors.append("manual_override")
		if not moved: blocked_ticks+=1
		if state in ["transit","retreat","split","contact","blocked"]:
			for b in range(1,batch_count):
				var previous_tail:=INF
				var following_head:=-INF
				for i in range(ids.size()):
					if not units[ids[i]].enabled:continue
					if batch[i]==b-1:previous_tail=minf(previous_tail,progress[i])
					if batch[i]==b:following_head=maxf(following_head,progress[i])
				if previous_tail<INF and following_head>-INF:
					minimum_batch_gap=minf(minimum_batch_gap,previous_tail-following_head-64)
					if previous_tail-following_head<159.98:invariant_errors.append("batch_gap")
		if enemy!=null:
			var seen:=[visible_contacts(units,own,enemy),visible_contacts(units,enemy,own)]
			for side in range(2):
				var army:LabFormation=own if side==0 else enemy
				for id in army.member_entity_ids:
					var u:UnitState=units[id]
					u.attack_target_entity_id=0
					var nearest:=INF
					for target_id in seen[side]:
						var distance:float=u.position.distance_to(units[target_id].position)
						if distance<=u.attack_range and distance<nearest:nearest=distance;u.attack_target_entity_id=target_id
			projectile_id=combat.advance(units,{},projectiles,projectile_id,events,tick)
			for event in events:
				if event.kind==SimulationEvent.Kind.PROJECTILE_FIRED:shots+=1
			events.clear()
		var settled:=true
		var all_clear:=true
		var core_here:=0
		var core_total:=0
		var nearest_guard:=INF
		for i in range(ids.size()):
			var u:UnitState=units[ids[i]]
			if not u.enabled:continue
			if role_of(u) in [1,2]:
				nearest_guard=minf(nearest_guard,u.position.distance_to(units[hero_id].position))
				core_total+=1
				if progress[i]>lengths[3]+192:core_here+=1
			if progress[i]<lengths[3]+640:all_clear=false
			if state=="transit" and absf(progress[i]-(final_front-lag[i]))>1:all_clear=false
			if state=="stretch" and u.position.distance_to(stretched_slots[i])>1:settled=false
			if state=="gather" and u.position.distance_to(narrow_slots[i])>1:settled=false
			if state=="widen_lateral" and u.position.distance_to(lateral_slots[i])>1:settled=false
			if state=="widen" and u.position.distance_to(finals[i])>1:settled=false
			if state=="retreat" and absf(progress[i]-initial[i])>1:settled=false
			if state=="split" and absf(progress[i]-(final_front-lag[i] if split_forward[u.entity_id] else initial[i]))>1:settled=false
			for j in range(i):
				if units[ids[j]].enabled and u.position.distance_to(units[ids[j]].position)<23.99:invariant_errors.append("overlap")
			if scenario=="cut" and cut_distance>0 and (progress[i]>cut_distance)!=bool(split_forward[u.entity_id]):invariant_errors.append("cross_cut")
		if units[hero_id].enabled and nearest_guard<INF:
			max_hero_gap=maxf(max_hero_gap,nearest_guard)
			if nearest_guard>240:hero_gap_ticks+=1
		if head_tick<0 and progress[0]>=lengths[3]:head_tick=tick
		if core_tick<0 and core_here>=ceili(core_total*0.8) and progress[ids.find(hero_id)]>=lengths[3]+192:core_tick=tick
		if state=="stretch" and settled:state="gather"
		elif state=="gather" and settled:state="transit";gather_tick=tick
		if state=="transit" and all_clear:
			if tail_tick<0:tail_tick=tick
			if tick-tail_tick>=20:state="widen_lateral"
		if previous_state=="widen_lateral" and settled:state="widen"
		elif previous_state=="widen" and settled:state="done";finish_tick=tick
		if state in ["retreat","split"] and settled:state="withdrawn";finish_tick=tick
		if state=="blocked" and tick-incident_tick>=100:finish_tick=tick
		if state!=previous_state:state_log.append({"tick":tick,"state":state})
		for id in ids:
			var u:UnitState=units[id]
			hash.update(("%d:%d:%.3f:%.3f:%.2f;" % [tick,id,u.position.x,u.position.y,u.health]).to_utf8_buffer())
		if tick%20==0:
			var frame:Array=[]
			for id in ids:frame.append([id,units[id].position.x+origin.x,units[id].position.y+origin.y,units[id].enabled])
			frames.append({"tick":tick,"state":state,"units":frame})
		if finish_tick>=0:break
	var unsettled:Array=[]
	for i in range(ids.size()):
		if units[ids[i]].position.distance_to(narrow_slots[i])>1:unsettled.append([ids[i],str(units[ids[i]].position),str(narrow_slots[i]),column[i],lag[i]])
	var expected:="done" if scenario=="gather" else ("blocked" if scenario in ["exit_blocked","manual_stop"] else "withdrawn")
	var row:Dictionary={"key":"%s_%d_%s_%s" % [profiles[profile].id,count,scenario,str(mirror)],"profile":profiles[profile].id,"soldiers":count,"scenario":scenario,"mirror":mirror,"state":state,"expected":expected,"completed":state==expected and finish_tick>=0,"gather_tick":gather_tick,"head_tick":head_tick,"core_tick":core_tick,"tail_clear_tick":tail_tick,"finish_tick":finish_tick,"incident_tick":incident_tick,"state_log":state_log,"invariant_errors":invariant_errors,"max_hero_gap":max_hero_gap,"hero_gap_over240_ticks":hero_gap_ticks,"blocked_ticks":blocked_ticks,"shots":shots,"survivors":alive(units,own,true),"hero_alive":units[hero_id].enabled,"split_front":split_forward.values().count(true),"split_rear":split_forward.values().count(false),"trace":hash.finish().hex_encode()}
	if not mirror and profile==2 and count in [12,60]:FileAccess.open(TRANSITION_OUT+"transition_frames_"+row.key+".json",FileAccess.WRITE).store_string(JSON.stringify(frames))
	row["unsettled"]=unsettled
	row["minimum_batch_clear_gap"]=minimum_batch_gap
	return row
