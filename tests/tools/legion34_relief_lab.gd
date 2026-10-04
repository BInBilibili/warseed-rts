extends "res://tests/tools/legion34_transition_lab.gd"
# Physical two-legion handoff on the real 1024-wide top road. Two disjoint
# lanes are feasible here; do NOT apply this fixture to a 320-wide connector.
const RELIEF_OUT := "res://artifacts/legion34/v5/"

func _initialize() -> void:
	profiles=JSON.parse_string(FileAccess.get_file_as_string(RELIEF_OUT+"config.json")).profiles
	actual_map=load("res://data/maps/final_decision.tres") as MapDefinition
	var mode:="smoke"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	for count in ([12] if mode=="smoke" else [12,36,60]):
		for scenario in ["normal","late","manual","cancel","return_lost","core_missing"]:
			for mirror in ([false] if mode=="smoke" else [false,true]):
				var row:=relief(count,scenario,mirror)
				if mode=="repeat":
					var repeated:=relief(count,scenario,mirror)
					if JSON.stringify(row)!=JSON.stringify(repeated):errors.append("repeat:"+row.key)
				results.append(row)
				if not row.invariant_errors.is_empty():errors.append(row.key)
			print("RELIEF_PROGRESS ",count," ",scenario)
	FileAccess.open(RELIEF_OUT+"relief_"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PROTOTYPE","cases":results.size(),"results":results,"errors":errors}))
	print("RELIEF_DONE cases=",results.size()," invariant_errors=",errors.size())
	quit(0 if errors.is_empty() else 1)

func mapped(point: Vector2, mirror: bool) -> Vector2:
	return (actual_map.mirror_point(point) if mirror else point)-origin

func relief(count: int, scenario: String, mirror: bool) -> Dictionary:
	build_route(mirror)
	var units:Dictionary={}
	var north:=Vector2.DOWN if mirror else Vector2.UP
	var incoming:=spawn_army(4,count,1,1,mapped(Vector2(1800,19232),mirror),north,"move","special",units)
	var defender:=spawn_army(1,12,1,101,mapped(Vector2(2288,18304),mirror),north,"defend","special",units)
	var enemy:=spawn_army(0,6,2,201,mapped(Vector2(2020,18140),mirror),-north,"attack","special",units)
	var ids:Array[int]=[]
	# Actual assault/armor core and hero lead the rescue, other batches trail.
	var buckets:Array=[[],[],[],[],[]]
	for id in incoming.member_entity_ids:buckets[role_of(units[id])].append(id)
	ids.append(buckets[0].pop_front())
	for i in range(4):ids.append(buckets[1].pop_front())
	for i in range(2):ids.append(buckets[2].pop_front())
	ids.insert(3,buckets[4].pop_front())
	while not buckets[1].is_empty() and ids.size()<11:ids.append(buckets[1].pop_front())
	for role in range(4):ids.append_array(buckets[role])
	var required:Array[int]=ids.slice(0,mini(11,ids.size()))
	var starts:Dictionary={}
	var arrival:Dictionary={}
	var returns:Dictionary={}
	var lag:Array[float]=[]
	var batch_count:=ceili(ids.size()/12.0)
	var depth:=0.0
	for b in range(batch_count):
		var size:int=ids.size()/batch_count+int(b<ids.size()%batch_count)
		for j in range(size):lag.append(depth+floori(j/3.0)*48)
		depth+=(ceili(size/3.0)-1)*48+64+96
	for i in range(ids.size()):
		var x:=1800.0+(i%3-1)*48
		starts[ids[i]]=mapped(Vector2(x,19232+lag[i]),mirror)
		arrival[ids[i]]=mapped(Vector2(x,18304+lag[i]),mirror)
		returns[ids[i]]=starts[ids[i]]
		units[ids[i]].position=starts[ids[i]]
	var donor_starts:Dictionary={}
	var donor_exit:Dictionary={}
	for i in range(defender.member_entity_ids.size()):
		var id:int=defender.member_entity_ids[i]
		donor_starts[id]=mapped(Vector2(2288+(i%3-1)*48,18304+floori(i/3.0)*48),mirror)
		donor_exit[id]=mapped(Vector2(2288+(i%3-1)*48,19900+floori(i/3.0)*48),mirror)
		units[id].position=donor_starts[id]
	var hostile_exit:Dictionary={}
	for i in range(enemy.member_entity_ids.size()):
		var id:int=enemy.member_entity_ids[i]
		units[id].position=mapped(Vector2(2020+(i%3-1)*48,18140-floori(i/3.0)*48),mirror)
		hostile_exit[id]=units[id].position+north*1400
	if scenario=="core_missing":
		for id in incoming.member_entity_ids:
			if role_of(units[id])==2:units[id].enabled=false;units[id].health=0
	var state:="approach"
	var head_tick:=-1
	var ready_tick:=-1
	var leave_tick:=-1
	var safe_tick:=-1
	var return_tick:=-1
	var finish_tick:=-1
	var clear_since:=-1
	var reason:=""
	var defects:Array=[]
	var state_log:Array=[]
	var combat:=CombatSystem.new()
	var projectiles:Dictionary={}
	var next_projectile:=1
	var events:Array[SimulationEvent]=[]
	var shots:=0
	var progress_hash:=HashingContext.new()
	progress_hash.start(HashingContext.HASH_SHA256)
	for tick in range(2000):
		refresh_speeds(units)
		var previous:=state
		var before:Dictionary={}
		for id in units:before[id]=units[id].position
		# Prescribed enemy disengagement supplies an observable end of pressure.
		# They physically leave sight; no enemy is deleted to clear the task.
		if tick>=200:
			var hostile_order:=enemy.member_entity_ids.duplicate();hostile_order.reverse()
			for id in hostile_order:
				if units[id].enabled:move_slot(units[id],hostile_exit[id],units)
		if scenario=="cancel" and tick==20:
			state="return";return_tick=tick;reason="new_order_cancelled_handoff"
		if scenario=="late" and tick==30:leave_tick=tick;reason="cover_withdrawal_not_hold"
		var ordering:=ids.duplicate()
		if state=="return":ordering.reverse()
		for id in ordering:
			var u:UnitState=units[id]
			if not u.enabled:continue
			var target:Vector2=returns[id] if state=="return" else arrival[id]
			move_slot(u,target,units)
		if head_tick<0 and units[ids[0]].position.distance_to(arrival[ids[0]])<24:head_tick=tick
		var here:=0
		var assault:=0
		var armor:=0
		for id in required:
			if units[id].enabled and units[id].position.distance_to(arrival[id])<24:
				here+=1
				if role_of(units[id])==1:assault+=1
				if role_of(units[id])==2:armor+=1
		var hero_id:=incoming.member_entity_ids[-1]
		var hero_here:bool=units[hero_id].enabled and units[hero_id].position.distance_to(arrival[hero_id])<24
		var is_ready:bool=here>=ceili(required.size()*0.8) and assault>=4 and armor>=2 and hero_here
		if ready_tick<0 and is_ready and state!="return":
			ready_tick=tick;state="cover"
			if scenario!="manual" and leave_tick<0:leave_tick=tick
		if leave_tick>=0:
			var donor_order:=defender.member_entity_ids.duplicate();donor_order.reverse()
			for id in donor_order:
				if units[id].enabled:move_slot(units[id],donor_exit[id],units)
		var safe:=leave_tick>=0
		for id in defender.member_entity_ids:
			if units[id].enabled and units[id].position.distance_to(donor_exit[id])>24:safe=false
		if safe and safe_tick<0:safe_tick=tick
		# Clear threat is measured from legal local contact after the enemy is
		# defeated; timeout cannot manufacture a safe return.
		var contacts:=visible_contacts(units,incoming,enemy)
		if contacts.is_empty():
			if clear_since<0:clear_since=tick
		else:clear_since=-1
		if state=="cover" and safe_tick>=0 and clear_since>=0 and tick-clear_since>=30:
			state="return";return_tick=tick
			if scenario=="return_lost":
				for id in ids:returns[id]=starts[id]-north*512
				reason="approved_alternate_rally"
		var own_visible:=visible_contacts(units,incoming,enemy)
		for id in visible_contacts(units,defender,enemy):
			if not own_visible.has(id):own_visible.append(id)
		var enemy_visible:=visible_contacts(units,enemy,incoming)
		for id in visible_contacts(units,enemy,defender):
			if not enemy_visible.has(id):enemy_visible.append(id)
		for id in units:
			var u:UnitState=units[id]
			u.attack_target_entity_id=0
			var nearest:=INF
			for hostile in (own_visible if u.faction_id==1 else enemy_visible):
				var distance:float=u.position.distance_to(units[hostile].position)
				if distance<=u.attack_range and distance<nearest:nearest=distance;u.attack_target_entity_id=hostile
		next_projectile=combat.advance(units,{},projectiles,next_projectile,events,tick)
		for event in events:
			if event.kind==SimulationEvent.Kind.PROJECTILE_FIRED:shots+=1
		events.clear()
		if leave_tick>=0 and ready_tick<0 and scenario!="late":defects.append("premature_handoff")
		if scenario in ["manual","cancel","core_missing"]:
			for id in defender.member_entity_ids:
				if units[id].position!=donor_starts[id]:defects.append("unauthorized_donor_move")
		for id in units:
			var u:UnitState=units[id]
			if not u.enabled:continue
			if u.position.distance_to(before[id])>u.move_speed*0.1+0.01:defects.append("speed")
			if not actual_grid.is_segment_walkable(before[id]+origin,u.position+origin):defects.append("segment")
			if not actual_grid.is_world_position_walkable(u.position+origin):defects.append("path")
			for other_id in units:
				if other_id<id and units[other_id].enabled and u.position.distance_to(units[other_id].position)<23.99:defects.append("overlap")
			progress_hash.update(("%d:%d:%.3f:%.3f:%.2f;" % [tick,id,u.position.x,u.position.y,u.health]).to_utf8_buffer())
		if state=="return":
			var home:=true
			for id in ids:
				if units[id].enabled and units[id].position.distance_to(returns[id])>24:home=false
			if home:state="returned";finish_tick=tick
		if scenario=="manual" and ready_tick>=0 and tick-ready_tick>=100:state="cover_player";reason="player_retains_control";finish_tick=tick
		if scenario=="core_missing" and head_tick>=0 and tick-head_tick>=100:state="insufficient_core";reason="missing_two_armor";finish_tick=tick
		if state!=previous:state_log.append({"tick":tick,"state":state})
		if finish_tick>=0:break
	return {"key":"%d_%s_%s" % [count,scenario,str(mirror)],"soldiers":count,"scenario":scenario,"mirror":mirror,"state":state,"reason":reason,"head_tick":head_tick,"ready_tick":ready_tick,"donor_leave_tick":leave_tick,"donor_safe_tick":safe_tick,"return_tick":return_tick,"finish_tick":finish_tick,"state_log":state_log,"shots":shots,"incoming_survivors":alive(units,incoming,true),"donor_survivors":alive(units,defender,true),"incoming_hero_alive":units[incoming.member_entity_ids[-1]].enabled,"donor_hero_alive":units[defender.member_entity_ids[-1]].enabled,"invariant_errors":defects,"trace":progress_hash.finish().hex_encode(),"wide_road_only":true}
