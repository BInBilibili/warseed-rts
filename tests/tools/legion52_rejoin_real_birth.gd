extends "res://tests/tools/legion49_narrow_aligned.gd"
const Rejoin = preload("res://artifacts/legion52/legion_transit_rejoin.gd")
var joining := Rejoin.State.new()

func _initialize() -> void:
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
	FileAccess.open("res://artifacts/legion52/rejoin-real-birth02.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	print("LEGION52_RECRUIT checks=",checks," failures=",failures.size())
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
