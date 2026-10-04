extends "res://tests/tools/legion55_exit_execution.gd"

func step(world: SimulationWorld) -> void:
	var before := {}; var speeds := {}; var phased := {}
	for unit: UnitState in world.units.values():
		before[unit.entity_id]=unit.position; speeds[unit.entity_id]=unit.move_speed
	world.legion_formation_system.prepare(world)
	LegionReformationSystem.prepare(world)
	for unit: UnitState in world.units.values():
		phased[unit.entity_id]=unit.reformation!=null and unit.reformation.phase==LegionReformationState.Phase.REFORMING
	world.formation_movement.advance(world.formations,world.units,world.events,world.current_tick)
	LegionSpatialExecutor.advance(world)
	world.legion_formation_system.advance_heroes(world)
	for unit: UnitState in world.units.values():
		if not unit.following_formation and unit.legion_slot==null: world._advance_unit(unit)
		check(unit.position.distance_to(before[unit.entity_id])<=speeds[unit.entity_id]*0.1+0.01,"actual member retains one tick speed budget")
		check(LegionTransitGeometry.segment_fits(world.logic_grid,before[unit.entity_id],unit.position),"reformation never phases through terrain")
	LegionReformationSystem.finish_movement(world)
	LegionSpatialExecutor.refresh(world)
	var ids := world.units.keys(); ids.sort()
	for index in range(ids.size()):
		var a := world.units[ids[index]] as UnitState
		if not a.enabled: continue
		if a.reformation!=null:
			check(a.reformation.active_ticks.size()<=60,"rolling reformation budget bounded")
			if a.reformation.phase!=LegionReformationState.Phase.SOLID:
				check(LegionReformationSystem.damage_factor(a)==1.5,"non-solid reformation member pays damage cost")
		for second in range(index):
			var b := world.units[ids[second]] as UnitState
			if not b.enabled: continue
			if a.faction_id==b.faction_id and (phased[a.entity_id] or phased[b.entity_id]): continue
			var required := minf(24.0,(before[a.entity_id] as Vector2).distance_to(before[b.entity_id]))
			check(a.position.distance_to(b.position)>=required-0.01,"ordinary bodies do not overlap or worsen inherited overlap")
	world.current_tick+=1

func physical_state(world: SimulationWorld, commander: CommanderState, record: LegionFormationState, mouth: float) -> Dictionary:
	var result := super.physical_state(world,commander,record,mouth)
	if record.spatial.deployment==null: return result
	var ready := 0; var max_error := 0.0
	var deployment := record.spatial.deployment
	var tolerance := LegionReformationSystem.policy.tolerance(deployment.spacing)
	for identity in range(commander.growth_unlocked_slots):
		var unit := LegionTransitExecutor._entity(world,commander,identity)
		var offset := deployment.offsets[identity]
		var target := deployment.anchor+deployment.facing*offset.x+deployment.facing.orthogonal()*offset.y
		var error := unit.position.distance_to(target)
		max_error=maxf(error,max_error)
		if error<=tolerance and LegionReformationSystem.damage_factor(unit)==1.0: ready+=1
	result.wide_ready=ready; result.wide_error_max=max_error
	result["spacing"]=deployment.spacing
	return result
