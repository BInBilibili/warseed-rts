extends "res://tests/tools/legion49_narrow_aligned.gd"

func _initialize() -> void:
	var destination := "res://artifacts/legion52/real-birth-integrated01.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): destination=arg.trim_prefix("--output=")
	var world := road_fixture(&"gunner",12,false,true)
	var commander := world.commanders.values()[0] as CommanderState
	for tick in range(250): step(world)
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	var role := LegionTemplate.find(&"gunner").slot_roles()[12]
	var card: UnitCardState
	for id in commander.subordinate_unit_card_ids:
		if world.unit_cards[id].definition.role_key==LegionTemplate.ROLE_KEYS[role]: card=world.unit_cards[id]
	var center := UnitCardSnapshot.new(card,world.units).center_position
	var nearest: StrategicRegionState
	for region: StrategicRegionState in world.strategic_regions.values():
		if nearest==null or region.position.distance_to(center)<nearest.position.distance_to(center): nearest=region
	check(nearest.position.distance_to(center)<=world.battle_definition.reinforcement_supply_radius,"actual map supply node covers controlled recruitment fixture")
	# A controlled owned-node/funds precondition, not a claim of natural capture.
	nearest.controller_faction_id=1;nearest.contested=false
	world.factions[1].supply=100
	world._update_faction_knowledge()
	var before_supply: int = world.factions[1].supply
	var command := RecruitUnitCardCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,card.definition.definition_id,1)
	command.legion_slot=12
	var receipt := world.submit_command(command)
	check(receipt.is_accepted(),"actual player recruitment passes shared validation: "+receipt.describe())
	for queued in world.command_queue.drain(): world._apply_command(queued)
	var recruit := world.units.get(commander.growth_slot_entities[12]) as UnitState
	check(recruit!=null,"actual command produces the fixed next identity")
	if recruit==null:
		print("LEGION52_RECRUIT checks=",checks," failures=",failures.size())
		for failure in failures: print("FAIL ",failure)
		quit(1);return
	var birth_position := recruit.position
	check(world.factions[1].supply==before_supply-card.definition.recruitment_cost,"actual birth deducts its exact fixed role cost once")
	var admitted := -1
	for tick in range(1800):
		step(world)
		if recruit.legion_slot!=null and recruit.legion_slot.admitted:
			admitted=world.current_tick;break
	check(admitted>0,"actual recruited unit physically joins the moving column")
	check(not record.batch_plan.pending_identities.has(12),"actual recruited identity leaves pending after safe admission")
	var data := {"evidence":"SIMULATED_COMPONENT","checks":checks,"failures":failures,"admission_tick":admitted,"birth_position":str(birth_position),"final_position":str(recruit.position),"cost":before_supply-world.factions[1].supply,"node":nearest.region_id,"scope":"shared recruitment command with controlled owned-node and funds; not natural economy or full world tick","full_B":"REWORK"}
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION52_RECRUIT checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
