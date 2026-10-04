extends "res://tests/tools/legion49_narrow_aligned.gd"

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
	var recruit := UnitState.new(90001,hero.position-Vector2(0,300),168.0,1)
	recruit.control_state=UnitState.ControlState.AGENT_ASSIGNED; recruit.unit_card_id=card.definition.definition_id
	recruit.tactical_role=[UnitState.TacticalRole.SCOUT,UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR,UnitState.TacticalRole.FIREPOWER][role]
	world.units[recruit.entity_id]=recruit; card.member_entity_ids.append(recruit.entity_id)
	commander.growth_unlocked_slots=13; commander.growth_slot_entities[12]=recruit.entity_id
	world.legion_formation_system.prepare(world)
	check(record.batch_plan.pending_identities.has(12),"growth identity is pending safe batch admission")
	check(recruit.legion_slot!=null and not recruit.legion_slot.admitted,"new transit recruit receives a physical rear rejoin order")
	var data := {"evidence":"SIMULATED_CANDIDATE","checks":checks,"failures":failures,"old_escort":victim.entity_id,"new_escort":record.state.escort_id,"growth_pending":record.batch_plan.pending_identities,"new_unit_has_slot":recruit.legion_slot!=null,"full_B":"REWORK","scope":"controlled casualty and recruit injection, not combat/economy validation"}
	FileAccess.open("res://artifacts/legion51/lifecycle01.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION51_LIFECYCLE checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
