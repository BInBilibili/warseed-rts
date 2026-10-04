extends "res://tests/tools/legion48_spatial_execution.gd"

var duration := 1200

func road_fixture(profile: StringName, count: int, mirror: bool, narrow: bool) -> SimulationWorld:
	var world := fixture(profile,false,count)
	var map := world.battle_definition.map_definition
	world.logic_grid=LogicGrid.create_for_map(map)
	var hq := load("res://data/buildings/command_center.tres") as BuildingDefinition
	for position in [world.battle_definition.player_headquarters_position,world.battle_definition.enemy_headquarters_position]:
		for cell in world.logic_grid.get_footprint_cells(position,hq.footprint_size): world.logic_grid.set_blocked(cell,true)
	world.pathfinder=GridPathfinder.new(world.logic_grid)
	world.formation_movement=FormationMovementSystem.new(world.logic_grid,world.pathfinder,true)
	var route := PackedVector2Array([Vector2(2048,20000),Vector2(2048,18432),Vector2(4864,16384),Vector2(6656,19456)]) if narrow else PackedVector2Array([Vector2(2048,20000),Vector2(2048,15000)])
	if mirror:
		for i in range(route.size()): route[i]=map.mirror_point(route[i])
	var forward := (route[1]-route[0]).normalized()
	var commander := world.commanders.values()[0] as CommanderState
	for unit: UnitState in world.units.values():
		var offset := unit.position-Vector2(6000,3000)
		unit.position=route[0]+forward*offset.x+forward.orthogonal()*offset.y
		check(world.logic_grid.is_world_position_walkable(unit.position),"fixture initial entity walkable: "+String(profile)+str(count)+str(mirror))
	for i in range(1,route.size()): check(world.logic_grid.is_segment_walkable(route[i-1],route[i]),"fixture actual center route walkable")
	commander.target_position=route[-1]
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		var formation := world.formations.get(card.formation_id) as FormationState
		if formation==null: continue
		formation.anchor_position=route[0]; formation.order_destination=route[-1]; formation.target_position=route[-1]
		formation.path=route.duplicate(); formation.path_index=1
		formation.planned_route=route.slice(1); formation.is_moving=true
	return world

func road_trial(profile: StringName, count: int, mirror: bool, narrow: bool) -> Dictionary:
	var first_check := checks
	var world := road_fixture(profile,count,mirror,narrow)
	var commander := world.commanders.values()[0] as CommanderState
	var initial := (world.units[commander.hero_entity_id] as UnitState).position
	var samples: Array = []
	var trace := HashingContext.new(); trace.start(HashingContext.HASH_SHA256)
	var stationary := 0; var longest_stationary := 0; var unavailable_max := 0
	var previous_anchor := Vector2(INF,INF)
	var completed_tick := -1
	var physical_arrival_tick := -1
	var members_arrived := 0
	for tick in range(duration):
		step(world)
		var record := world.legion_formation_system.records[commander.definition.definition_id]
		var state := record.spatial
		stationary=stationary+1 if state.anchor.distance_to(previous_anchor)<=0.01 else 0
		longest_stationary=maxi(longest_stationary,stationary); previous_anchor=state.anchor
		var unavailable := 0
		var physical_arrived := 0
		members_arrived=0
		var payload: Array = [world.current_tick,str(state.anchor),state.route_index,state.reason,state.ready,state.eligible]
		for identity in range(count):
			var unit := world.units[commander.growth_slot_entities[identity]] as UnitState
			var slot := unit.legion_slot
			check(slot!=null,"all road fixture soldiers retain executor ownership")
			if slot==null: continue
			if slot.reason==&"PATH_UNAVAILABLE": unavailable+=1
			elif unit.position.distance_to(slot.target)<=6.0:
				physical_arrived+=1
				if slot.at_destination: members_arrived+=1
			payload.append([unit.entity_id,str(unit.position),str(slot.target),slot.reason,slot.at_destination])
		var hero := world.units[commander.hero_entity_id] as UnitState
		if physical_arrived==count and state.anchor.distance_to(state.goal)<=6.0 and hero.position.distance_to(state.anchor)<=240.01 and physical_arrival_tick<0: physical_arrival_tick=world.current_tick
		payload.append([hero.entity_id,str(hero.position),record.reason])
		trace.update(JSON.stringify(payload).to_utf8_buffer())
		unavailable_max=maxi(unavailable_max,unavailable)
		var moving := 0
		for card_id in commander.subordinate_unit_card_ids:
			var formation := world.formations.get(world.unit_cards[card_id].formation_id) as FormationState
			if formation!=null and formation.is_moving: moving+=1
		if world.current_tick%100==0:
			samples.append({"tick":world.current_tick,"anchor":str(state.anchor),"hero":str(hero.position),"ready":state.ready,"eligible":state.eligible,"unavailable":unavailable,"reason":state.reason,"hero_reason":record.reason,"route_index":state.route_index,"route_size":state.route.size(),"action":state.action,"moving_cards":moving,"arrived":members_arrived,"physical_arrived":physical_arrived})
		if members_arrived==count and moving==0 and state.anchor.distance_to(state.goal)<=6.0 and hero.position.distance_to(state.anchor)<=240.01:
			completed_tick=world.current_tick; break
	var hero := world.units[commander.hero_entity_id] as UnitState
	var state := world.legion_formation_system.records[commander.definition.definition_id].spatial
	var final_cards: Array = []
	for card_id in commander.subordinate_unit_card_ids:
		var formation := world.formations.get(world.unit_cards[card_id].formation_id) as FormationState
		if formation!=null: final_cards.append({"id":card_id,"moving":formation.is_moving,"destination":str(formation.order_destination),"planned_route":str(formation.planned_route)})
	var final_members: Array = []
	for identity in range(count):
		var unit := world.units[commander.growth_slot_entities[identity]] as UnitState
		var slot := unit.legion_slot
		if slot==null: continue
		var intended := state.anchor+state.facing*slot.offset.x+state.facing.orthogonal()*slot.offset.y
		final_members.append({"identity":identity,"id":unit.entity_id,"position":str(unit.position),"target":str(slot.target),"intended":str(intended),"intended_walkable":world.logic_grid.is_world_position_walkable(intended),"reason":slot.reason,"at_destination":slot.at_destination})
	return {"profile":profile,"count":count,"mirror":mirror,"narrow":narrow,"ticks":world.current_tick,"completed_tick":completed_tick,"physical_arrival_tick":physical_arrival_tick,"members_arrived":members_arrived,"hero_displacement":hero.position.distance_to(initial),"anchor":str(state.anchor),"longest_anchor_stationary_ticks":longest_stationary,"max_unavailable":unavailable_max,"checks":checks-first_check,"trace":trace.finish().hex_encode(),"samples":samples,"final_cards":final_cards,"final_members":final_members}

func _initialize() -> void:
	var mode := "smoke"
	output="res://artifacts/legion49/smoke01.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode=arg.trim_prefix("--mode=")
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	for profile: StringName in LegionTemplate.PROFILE_IDS:
		if mode=="smoke" and profile!=&"gunner": continue
		for count in ([12] if mode=="smoke" else [12,60]):
			for mirror in ([false,true] if mode=="matrix" else [false]):
				for narrow in [false,true]:
					var row := road_trial(profile,count,mirror,narrow); rows.append(row)
					print("LEGION49_PROGRESS profile=",profile," count=",count," mirror=",mirror," narrow=",narrow," completed=",row.completed_tick," unavailable=",row.max_unavailable," errors=",failures.size())
	var incomplete := 0
	for row in rows:
		if row.completed_tick<0: incomplete+=1
	var data := {"evidence":"SIMULATED","mode":mode,"checks":checks,"execution_failures":failures,"cases":rows.size(),"incomplete":incomplete,"rows":rows,"scope":"production physical executor on actual map; isolated initialized units; no world command/economy/combat certification"}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION49_DONE cases=",rows.size()," incomplete=",incomplete," execution_failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() and incomplete==0 else 1)
