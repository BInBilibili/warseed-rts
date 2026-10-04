extends "res://tests/tools/legion49_narrow_aligned.gd"

func _initialize() -> void:
	var destination := "res://artifacts/legion52/burst-diagnostic01.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): destination=arg.trim_prefix("--output=")
	var world := road_fixture(&"gunner",23,false,true)
	var commander := world.commanders.values()[0] as CommanderState
	for tick in range(250): step(world)
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	var initial := record.duplicate_value()
	check(record.spatial.transit.batches[-1].identities.size()==12,"test fills original tail batch before creating another")
	var roles := LegionTemplate.find(&"gunner").slot_roles()
	var recruits: Array[UnitState] = []
	var used := PackedVector2Array()
	for identity in range(23,60):
		var card: UnitCardState
		for id in commander.subordinate_unit_card_ids:
			if world.unit_cards[id].definition.role_key==LegionTemplate.ROLE_KEYS[roles[identity]]: card=world.unit_cards[id]
		var spawn := Vector2(INF,INF)
		for offset in range(240,4400,48):
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
	commander.growth_unlocked_slots=60
	var admission := -1
	for tick in range(1500):
		step(world)
		var all_admitted := true
		for recruit in recruits:
			all_admitted=all_admitted and recruit.legion_slot!=null and recruit.legion_slot.admitted
		if all_admitted: admission=world.current_tick; break
	check(admission>0,"all pending growth eventually joins protected bounded batches")
	check(record.spatial.transit.batches.size()>initial.spatial.transit.batches.size(),"full old tail creates a distinct bounded batch")
	for index in range(initial.spatial.transit.batches.size()): check(record.spatial.transit.batches[index].identities==initial.spatial.transit.batches[index].identities,"new tail never redistributes existing identities")
	for batch in record.spatial.transit.batches: check(batch.identities.size()<=12,"new tail respects twelve-entity ceiling")
	var state_copy := record.spatial.transit.rejoin.duplicate_value()
	record.spatial.transit.rejoin.entities[23]+=1
	check(state_copy.entities[23]!=record.spatial.transit.rejoin.entities[23],"new recruit navigation identities are value copied")
	var slots := []
	for recruit in recruits:
		var nearest := INF; var near_id := 0
		for unit: UnitState in world.units.values():
			if unit.entity_id!=recruit.entity_id and unit.enabled and unit.position.distance_to(recruit.position)<nearest: nearest=unit.position.distance_to(recruit.position); near_id=unit.entity_id
		var slot := recruit.legion_slot
		slots.append({"id":recruit.entity_id,"slot":slot!=null,"admitted":slot.admitted if slot!=null else false,"position":str(recruit.position),"target":str(slot.target) if slot!=null else "", "reason":slot.reason if slot!=null else &"NONE","staging_since":slot.staging_since if slot!=null else -1,"near_id":near_id,"near_distance":nearest})
	var batches := []
	for batch in record.spatial.transit.batches: batches.append({"ids":batch.identities,"progress":batch.progress,"ready":batch.ready,"available":batch.available})
	var data := {"recruits":slots,"batch_details":batches,"approached":record.spatial.transit.rejoin.approached,"evidence":"SIMULATED_COMPONENT","checks":checks,"failures":failures,"admission_tick":admission,"pending":record.batch_plan.pending_identities,"batches":record.spatial.transit.batches.size(),"full_B":"REWORK"}
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION52_NEW_BATCH checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
