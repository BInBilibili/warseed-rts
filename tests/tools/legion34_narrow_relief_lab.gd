extends "res://tests/tools/legion34_transition_lab.gd"
# Two real columns share the actual upper_rear corridor. Donors retain their
# main-road parking occupancy; an abstract capacity token never removes them.
const NARROW_OUT := "res://artifacts/legion34/v5/"

func _initialize() -> void:
	profiles=JSON.parse_string(FileAccess.get_file_as_string(NARROW_OUT+"config.json")).profiles
	actual_map=load("res://data/maps/final_decision.tres") as MapDefinition
	var mode:="smoke"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	for count in ([12] if mode=="smoke" else [12,60]):
		for scenario in ["normal","manual_resumes","permanent_stop","exit_full"]:
			for mirror in ([false] if mode=="smoke" else [false,true]):
				var row:=passage(count,scenario,mirror)
				results.append(row)
				if not row.invariant_errors.is_empty():errors.append(row.key)
			print("NARROW_PROGRESS ",count," ",scenario)
	FileAccess.open(NARROW_OUT+"narrow_"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PROTOTYPE","cases":results.size(),"results":results,"errors":errors}))
	print("NARROW_DONE cases=",results.size()," invariant_errors=",errors.size())
	quit(0 if errors.is_empty() else 1)

func parking_point(distance: float, col: int, mirror: bool) -> Vector2:
	var amount:=clampf((lengths[1]-distance)/640,0,1)*240
	return point_at(distance,col)+Vector2.LEFT*amount if mirror else point_at(distance,col)+Vector2.RIGHT*amount

func passage(count: int, scenario: String, mirror: bool) -> Dictionary:
	build_route(mirror)
	var units:Dictionary={}
	var donor:=spawn_army(1,count,1,1,Vector2.ZERO,Vector2.UP,"retreat","special",units)
	var relief_army:=spawn_army(4,count,1,101,Vector2.ZERO,Vector2.UP,"move","special",units)
	var n:=count+1
	var lag:Array[float]=[]
	var cols:Array[int]=[]
	var batches:Array[int]=[]
	var bn:=ceili(n/12.0)
	var depth:=0.0
	for b in range(bn):
		var size:int=n/bn+int(b<n%bn)
		for j in range(size):lag.append(depth+floori(j/3.0)*48);cols.append(j%3);batches.append(b)
		depth+=(ceili(size/3.0)-1)*48+64
		if b<bn-1:depth+=96
	var donor_p:Array[float]=[]
	var relief_p:Array[float]=[]
	var merge:Dictionary={}
	var starts:Dictionary={}
	for i in range(n):
		donor_p.append(lengths[1]+512+lag[i])
		relief_p.append(1900-lag[i])
		units[donor.member_entity_ids[i]].position=parking_point(donor_p[i],cols[i],mirror)
		var id:int=relief_army.member_entity_ids[i]
		merge[id]=point_at(relief_p[i],cols[i])
		starts[id]=merge[id]+(Vector2.RIGHT if mirror else Vector2.LEFT)*240
		units[id].position=starts[id]
	var final_front:=lengths[3]+640+depth
	var released:=-1
	var donor_head_clear:=-1
	var donor_tail_clear:=-1
	var incoming_enter:=-1
	var completed:=-1
	var state:="wait_donor"
	var defects:Array=[]
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	var blocked_since:=-1
	for tick in range(4000):
		refresh_speeds(units)
		var held:bool=scenario=="exit_full" or (scenario in ["manual_resumes","permanent_stop"] and tick>=20 and (scenario=="permanent_stop" or tick<120))
		var before:Dictionary={}
		for id in units:before[id]=units[id].position
		if not held:
			for i in range(n):
				var u:UnitState=units[donor.member_entity_ids[i]]
				var target:=1900.0+lag[i]
				# Parking rows extend SOUTH from the main-road front, so every
				# donor must cross the mouth. Stable column order is retained.
				target=1900.0-lag[n-1]+lag[i]
				var next:=maxf(target,donor_p[i]-minf(current_pace(donor,units),u.move_speed)*0.1)
				for j in range(i):
					if cols[j]==cols[i]:next=maxf(next,donor_p[j]+(48 if batches[j]==batches[i] else 160))
				var pos:=parking_point(next,cols[i],mirror)
				if u.position.distance_to(pos)>u.move_speed*0.1:
					var low:=0.0
					var high:=1.0
					for retry in range(14):
						var mid:=(low+high)*0.5
						if u.position.distance_to(parking_point(lerpf(donor_p[i],next,mid),cols[i],mirror))>u.move_speed*0.1:high=mid
						else:low=mid
					next=lerpf(donor_p[i],next,low);pos=parking_point(next,cols[i],mirror)
				if legal_motion(u.position,pos,u.entity_id,units):u.position=pos;donor_p[i]=next
		if donor_head_clear<0 and donor_p[0]<lengths[1]-32:donor_head_clear=tick
		var donor_clear:=true
		for p in donor_p:
			if p>=lengths[1]-32:donor_clear=false
		if donor_clear and released<0:released=tick;donor_tail_clear=tick;state="merge"
		if state=="merge":
			var merged:=true
			for id in relief_army.member_entity_ids:
				move_slot(units[id],merge[id],units)
				if units[id].position.distance_to(merge[id])>0.01:merged=false
			if merged:state="advance"
		elif state=="advance":
			for i in range(n):
				var u:UnitState=units[relief_army.member_entity_ids[i]]
				var next:=minf(final_front-lag[i],relief_p[i]+minf(current_pace(relief_army,units),u.move_speed)*0.1)
				for j in range(i):
					if cols[j]==cols[i]:next=minf(next,relief_p[j]-(48 if batches[j]==batches[i] else 160))
				var pos:=point_at(next,cols[i])
				if u.position.distance_to(pos)>u.move_speed*0.1:
					var low:=0.0
					var high:=1.0
					for retry in range(14):
						var mid:=(low+high)*0.5
						if u.position.distance_to(point_at(lerpf(relief_p[i],next,mid),cols[i]))>u.move_speed*0.1:high=mid
						else:low=mid
					next=lerpf(relief_p[i],next,low);pos=point_at(next,cols[i])
				if legal_motion(u.position,pos,u.entity_id,units):u.position=pos;relief_p[i]=next
		if incoming_enter<0 and relief_p[0]>lengths[1]:incoming_enter=tick
		if incoming_enter>=0 and not donor_clear:defects.append("direction_conflict")
		if scenario in ["permanent_stop","exit_full"] and released>=0:defects.append("false_release")
		if held:
			for id in donor.member_entity_ids:
				if units[id].position!=before[id]:defects.append("manual_override")
		for id in units:
			var u:UnitState=units[id]
			if before[id].distance_to(u.position)>u.move_speed*0.1+0.01:defects.append("speed")
			if not actual_grid.is_segment_walkable(before[id]+origin,u.position+origin):defects.append("path")
			for other in units:
				if other<id and units[other].position.distance_to(u.position)<23.99:defects.append("overlap")
			hash.update(("%d:%d:%.3f:%.3f;" % [tick,id,u.position.x,u.position.y]).to_utf8_buffer())
		var arrived:=true
		for i in range(n):
			if absf(relief_p[i]-(final_front-lag[i]))>1:arrived=false
		if arrived:state="done";completed=tick;break
		if scenario in ["permanent_stop","exit_full"] and tick>=200:state="blocked";blocked_since=20 if scenario=="permanent_stop" else 0;break
	return {"key":"%d_%s_%s" % [count,scenario,str(mirror)],"soldiers":count,"scenario":scenario,"mirror":mirror,"state":state,"finish_tick":completed,"donor_head_clear":donor_head_clear,"donor_tail_clear":donor_tail_clear,"release_tick":released,"incoming_enter":incoming_enter,"blocked_since":blocked_since,"invariant_errors":defects,"trace":hash.finish().hex_encode(),"retained_entities":units.size(),"combat":false}
