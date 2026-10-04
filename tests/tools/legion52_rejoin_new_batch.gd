extends "res://tests/tools/legion49_narrow_aligned.gd"
const Rejoin = preload("res://artifacts/legion52/legion_transit_rejoin.gd")
var joining := Rejoin.State.new()

func _initialize() -> void:
	var world := road_fixture(&"gunner",23,false,true)
	var commander := world.commanders.values()[0] as CommanderState
	for tick in range(250): step(world)
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	var initial := record.duplicate_value()
	check(record.spatial.transit.batches[-1].identities.size()==12,"test fills original tail batch before creating another")
	var roles := LegionTemplate.find(&"gunner").slot_roles()
	var recruits: Array[UnitState] = []
	var used := PackedVector2Array()
	for identity in range(23,28):
		var card: UnitCardState
		for id in commander.subordinate_unit_card_ids:
			if world.unit_cards[id].definition.role_key==LegionTemplate.ROLE_KEYS[roles[identity]]: card=world.unit_cards[id]
		var spawn := Vector2(INF,INF)
		for offset in range(240,1400,48):
			var point := LegionTransitGeometry.point_at(record.spatial.transit.path,record.spatial.transit.batches[-1].progress-offset)
			if not LegionTransitGeometry.segment_fits(world.logic_grid,point,point): continue
			var clear := true
			for unit: UnitState in world.units.values():
				if unit.enabled and unit.position.distance_to(point)<47.99: clear=false; break
			if clear: spawn=point; break
		check(spawn.is_finite(),"every injected recruit starts in free valid rear terrain")
		var exemplar := world.units[card.member_entity_ids[0]] as UnitState
		var recruit := UnitState.new(91000+identity,spawn,exemplar.move_speed,1)
		recruit.control_state=UnitState.ControlState.AGENT_ASSIGNED; recruit.unit_card_id=card.definition.definition_id; recruit.tactical_role=exemplar.tactical_role
		world.units[recruit.entity_id]=recruit;card.member_entity_ids.append(recruit.entity_id);commander.growth_slot_entities[identity]=recruit.entity_id
		recruits.append(recruit)
	commander.growth_unlocked_slots=28
	var admission := -1
	for tick in range(1800):
		step(world)
		var all_admitted := true
		for recruit in recruits:
			all_admitted=all_admitted and recruit.legion_slot!=null and recruit.legion_slot.admitted
		if all_admitted: admission=world.current_tick; break
	check(admission>0,"five pending recruits actually join a new tail batch")
	check(record.spatial.transit.batches.size()==initial.spatial.transit.batches.size()+1,"full old tail creates a distinct bounded batch")
	for index in range(initial.spatial.transit.batches.size()): check(record.spatial.transit.batches[index].identities==initial.spatial.transit.batches[index].identities,"new tail never redistributes existing identities")
	for batch in record.spatial.transit.batches: check(batch.identities.size()<=12,"new tail respects twelve-entity ceiling")
	var state_copy := joining.duplicate_value()
	joining.entities[23]+=1
	check(state_copy.entities[23]!=joining.entities[23],"new recruit navigation identities are value copied")
	var data := {"evidence":"SIMULATED_COMPONENT","checks":checks,"failures":failures,"admission_tick":admission,"pending":record.batch_plan.pending_identities,"batches":record.spatial.transit.batches.size(),"full_B":"REWORK"}
	FileAccess.open("res://artifacts/legion52/rejoin-new-batch01.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION52_NEW_BATCH checks=",checks," failures=",failures.size())
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
