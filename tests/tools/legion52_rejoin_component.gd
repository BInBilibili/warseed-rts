extends "res://tests/tools/legion49_narrow_aligned.gd"

const Rejoin = preload("res://artifacts/legion52/legion_transit_rejoin.gd")
var joining := Rejoin.State.new()

func _initialize() -> void:
	var world := road_fixture(&"gunner",12,false,true)
	var commander := world.commanders.values()[0] as CommanderState
	for tick in range(250): step(world)
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	check(record.spatial.transit.phase==LegionTransitState.Phase.COLUMN,"lifecycle fixture is actually in a moving column")
	var before := record.duplicate_value()
	var victim := world.units[record.state.escort_id] as UnitState
	victim.enabled=false
	LegionSpatialExecutor.refresh(world)
	check(record.state.escort_id==0,"same-tick escort death clears protection identity")
	for tick in range(20): step(world)
	for index in range(before.spatial.transit.batches.size()):
		check(before.spatial.transit.batches[index].identities==record.spatial.transit.batches[index].identities,"transit death keeps surviving stable batch identity order")
	check(record.state.escort_id!=victim.entity_id,"dead core never remains selected after replan")
	var role := LegionTemplate.find(&"gunner").slot_roles()[12]
	var card: UnitCardState
	for id in commander.subordinate_unit_card_ids:
		if world.unit_cards[id].definition.role_key==LegionTemplate.ROLE_KEYS[role]: card=world.unit_cards[id]
	var hero := world.units[commander.hero_entity_id] as UnitState
	var spawn := Vector2(INF,INF)
	var transit := record.spatial.transit
	for distance in range(240,800,48):
		var point := LegionTransitGeometry.point_at(transit.path,transit.batches[-1].progress-distance,0.0)
		if not LegionTransitGeometry.segment_fits(world.logic_grid,point,point): continue
		var clear := true
		for unit: UnitState in world.units.values():
			if unit.enabled and unit.position.distance_to(point)<48.0: clear=false; break
		if clear: spawn=point; break
	check(spawn.is_finite(),"controlled new recruit starts in valid unoccupied rear terrain")
	var recruit := UnitState.new(90001,spawn,168.0,1)
	recruit.control_state=UnitState.ControlState.AGENT_ASSIGNED; recruit.unit_card_id=card.definition.definition_id
	recruit.tactical_role=[UnitState.TacticalRole.SCOUT,UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR,UnitState.TacticalRole.FIREPOWER][role]
	world.units[recruit.entity_id]=recruit; card.member_entity_ids.append(recruit.entity_id)
	commander.growth_unlocked_slots=13; commander.growth_slot_entities[12]=recruit.entity_id
	world.legion_formation_system.prepare(world)
	Rejoin.prepare(world,commander,record,[],joining)
	check(record.batch_plan.pending_identities.has(12),"growth identity is pending safe batch admission")
	check(recruit.legion_slot!=null and not recruit.legion_slot.admitted,"new transit recruit receives a physical rear rejoin order")
	var snapshot := joining.duplicate_value()
	var original_position := recruit.position
	var prior_control := card.control_state
	card.control_state=UnitCardState.ControlState.PLAYER_OVERRIDDEN
	recruit.control_state=UnitState.ControlState.TEMPORARILY_OVERRIDDEN
	for tick in range(10): step(world)
	check(recruit.legion_slot==null,"manual pending recruit has no automatic slot")
	check(recruit.position==original_position,"manual stopped recruit is not pulled into the tail")
	card.control_state=prior_control; recruit.control_state=UnitState.ControlState.AGENT_ASSIGNED
	check(snapshot.entities[12]==joining.entities[12],"unmodified snapshot retains recruit identity")
	var start := recruit.position
	var admission_tick := -1
	for tick in range(1600):
		step(world)
		if recruit.legion_slot!=null and recruit.legion_slot.admitted:
			admission_tick=world.current_tick; break
	check(admission_tick>0,"pending growth physically reaches tail and is admitted")
	check(recruit.position.distance_to(start)>100.0,"rejoin requires actual movement")
	check(not record.batch_plan.pending_identities.has(12),"admitted identity leaves pending planning")
	for batch in record.spatial.transit.batches: check(batch.identities.size()<=12,"growth preserves maximum physical batch capacity")
	var data := {"admission_tick":admission_tick,"recruit_position":str(recruit.position),"evidence":"SIMULATED_CANDIDATE","checks":checks,"failures":failures,"old_escort":victim.entity_id,"new_escort":record.state.escort_id,"growth_pending":record.batch_plan.pending_identities,"new_unit_has_slot":recruit.legion_slot!=null,"full_B":"REWORK","scope":"controlled casualty and recruit injection, not combat/economy validation"}
	FileAccess.open("res://artifacts/legion52/rejoin-component04.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION51_LIFECYCLE checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func step(world: SimulationWorld) -> void:
	var before := {}; var speeds := {}
	for unit: UnitState in world.units.values():
		before[unit.entity_id]=unit.position; speeds[unit.entity_id]=unit.move_speed
	world.legion_formation_system.prepare(world)
	var commander := world.commanders.values()[0] as CommanderState
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	Rejoin.prepare(world,commander,record,[],joining)
	var owned := {}
	for unit: UnitState in world.units.values():
		if unit.legion_slot!=null: owned[unit.entity_id]=unit.position
	world.formation_movement.advance(world.formations,world.units,world.events,world.current_tick)
	for id in owned: check(world.units[id].position==owned[id],"legacy mover cannot write a spatially owned soldier")
	LegionSpatialExecutor.advance(world)
	world.legion_formation_system.advance_heroes(world)
	for unit: UnitState in world.units.values():
		if not unit.following_formation and unit.legion_slot==null: world._advance_unit(unit)
		check(unit.position.distance_to(before[unit.entity_id])<=speeds[unit.entity_id]*0.1+0.01,"all actual members respect one tick speed budget")
		check(world.logic_grid.is_segment_walkable(before[unit.entity_id],unit.position),"actual member segment remains walkable")
	LegionSpatialExecutor.refresh(world)
	var ids := world.units.keys(); ids.sort()
	for i in range(ids.size()):
		var a := world.units[ids[i]] as UnitState
		if not a.enabled: continue
		for j in range(i+1,ids.size()):
			var b := world.units[ids[j]] as UnitState
			if not b.enabled: continue
			var required := minf(24.0,(before[a.entity_id] as Vector2).distance_to(before[b.entity_id]))
			if a.position.distance_to(b.position)<required-0.01 and not failures.has("actual pair occupancy never overlaps or worsens inherited overlap"):
				print("COLLISION_DIAGNOSTIC tick=",world.current_tick," a=",a.entity_id," b=",b.entity_id," before=",before[a.entity_id],"/",before[b.entity_id]," after=",a.position,"/",b.position," constraint=",a.legion_motion!=null,"/",b.legion_motion!=null)
			check(a.position.distance_to(b.position)>=required-0.01,"actual pair occupancy never overlaps or worsens inherited overlap")
	world.current_tick+=1
