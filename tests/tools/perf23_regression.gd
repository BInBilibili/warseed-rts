extends "res://tests/tools/growth_combat20.gd"
const ReferenceProjector = preload("res://tests/tools/perf23_reference_projector.gd")

func _initialize() -> void:
	var world := fixture(&"UNIT_CARD_ROLE_FIREPOWER")
	for i in range(60): enemy(world, ORIGIN + Vector2((i%10)*120-600,(i/10)*100-300),99000+i)
	var projector := TacticalActionProjector.new()
	for ammo in [0,1,10]:
		for unit: UnitState in world.units.values():
			if unit.faction_id == 1: unit.ammunition = ammo
		for faction in [1,2]:
			var view := world.create_faction_snapshot(faction)
			var expected := ReferenceProjector.new().project(view,world.battle_definition)
			var actual := projector.project(view,world.battle_definition)
			check(expected.size()==actual.size(),"projection count")
			for i in range(mini(expected.size(),actual.size())):
				for property in expected[i].get_property_list():
					if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
						check(expected[i].get(property.name)==actual[i].get(property.name),"projection field "+property.name)
		var index := GrowthCombatSystem._visible_target_buckets(world)
		for unit: UnitState in world.units.values():
			for preferred in [0,99000,99999]:
				check(GrowthCombatSystem._pick(world,unit,preferred)==GrowthCombatSystem._pick(world,unit,preferred,index),"broad phase exact target")
	# Same tick, different world value: never reuse another world's ID index.
	var presentation := WorldPresentation.new()
	for name_value in ["Units","Buildings","OreFields"]:
		var container := Node2D.new()
		container.name=name_value
		presentation.add_child(container)
	root.add_child(presentation)
	await process_frame
	var a := world.create_faction_snapshot(1)
	presentation.set_snapshots(a,a,0.5)
	var b := world.create_faction_snapshot(1)
	b.units.clear()
	presentation.set_snapshots(a,b,0.5)
	check(presentation._lookup_unit(b,99000)==null,"same tick new snapshot invalidates index")
	var changed_previous:=world.create_faction_snapshot(1)
	changed_previous.units[0].position+=Vector2(17,29)
	presentation.set_snapshots(changed_previous,b,0.5)
	check(presentation._previous_unit_positions.get(changed_previous.units[0].entity_id)==changed_previous.units[0].position,"same current updates previous interpolation")
	presentation.set_snapshots(null,b,0.5)
	check(presentation._previous_unit_positions.is_empty() and presentation._previous_projectile_positions.is_empty(),"null previous clears interpolation")
	check(presentation._lookup_unit(null,99000)==null,"null previous clears index")
	presentation.set_snapshots(null,null,0.5)
	check(presentation._lookup_unit(null,99000)==null,"null current clears index")
	presentation.queue_free()
	await process_frame
	_test_recon_clearance(world)
	_test_final_slots()
	_test_oscillation()
	_test_restored_route(world)
	for failure in failures: push_error(failure)
	print("PERF23_REGRESSION failures=",failures)
	quit(0 if failures.is_empty() else 1)

func _test_final_slots() -> void:
	var grid := LogicGrid.new()
	grid.grid_size=Vector2i(64,64)
	var mover := FormationMovementSystem.new(grid,GridPathfinder.new(grid))
	var formation := FormationState.new(1,[1,2,3],Vector2(600,600))
	formation.strict_deployment_slots=true
	formation.path=PackedVector2Array([Vector2(500,600),Vector2(600,600)])
	formation.path_index=2
	formation.is_moving=true
	formation.mode=FormationState.MovementMode.COLUMN
	formation.forced_column_ticks=10
	formation.reset_anchor_history(Vector2.RIGHT)
	var members: Dictionary={}
	for id in formation.member_entity_ids:
		var u := UnitState.new(id,formation.sample_anchor_history(42.0*(id-1)),0,1)
		u.definition_id=&"assault_vehicle"
		u.following_formation=true
		u.move_speed=100
		members[id]=u
	var events: Array[SimulationEvent]=[]
	mover.advance({1:formation},members,events,1)
	check(formation.is_moving,"column arrival cannot stop before unfolding")
	for tick in range(2,160): mover.advance({1:formation},members,events,tick)
	check(not formation.is_moving,"final deployed slots reached")
	for id in members:
		check(members[id].position.distance_to(formation.anchor_position+formation.get_wide_offset(id-1))<=6,"actual final slot")

func _test_restored_route(world: SimulationWorld) -> void:
	var card := find_card(world,&"UNIT_CARD_ROLE_FIREPOWER")
	var formation := world.formations[card.formation_id] as FormationState
	formation.anchor_position=ORIGIN
	formation.local_engagement_origin=ORIGIN+Vector2(32,0)
	formation.local_engagement_resume_path=PackedVector2Array([ORIGIN+Vector2(96,0),ORIGIN+Vector2(160,0)])
	formation.local_engagement_resume_destination=ORIGIN+Vector2(160,0)
	formation.local_engagement_resume_kind=FormationState.OrderKind.MOVE
	world.logic_grid.set_blocked(world.logic_grid.world_to_cell(formation.local_engagement_origin),true)
	GrowthCombatSystem._resume(world,formation)
	check(formation.path.is_empty() and not formation.is_moving,"unreachable connector cannot reuse unchecked saved route")
	check(formation.order_destination==ORIGIN+Vector2(160,0),"failed reconnect preserves strategic destination")

	check(formation.local_engagement_active and formation.local_engagement_returning,"failed reconnect retains retry state")
	world.logic_grid.set_blocked(world.logic_grid.world_to_cell(formation.local_engagement_origin),false)
	for unit: UnitState in world.units.values():
		if unit.faction_id!=1: unit.enabled=false
	world._update_faction_knowledge()
	GrowthCombatSystem.advance(world)
	check(formation.is_moving and not formation.local_engagement_active,"uncommanded route resumes after obstacle removed")
	for i in range(1,formation.path.size()): check(world.logic_grid.is_segment_walkable(formation.path[i-1],formation.path[i]),"restored segments walkable")

func _test_oscillation() -> void:
	var grid:=LogicGrid.new()
	grid.grid_size=Vector2i(64,64)
	var mover:=FormationMovementSystem.new(grid,GridPathfinder.new(grid),true)
	var formation:=FormationState.new(1,[1],Vector2(600,600))
	formation.reset_anchor_history(Vector2.RIGHT)
	var unit:=UnitState.new(1,Vector2(300,600),0,1)
	unit.desired_position=Vector2(600,600)
	unit.recovery_attempts=5
	unit.is_recovering=true
	var events: Array[SimulationEvent]=[]
	for tick in range(1,42):
		var before:=unit.position
		unit.position=Vector2(300+(tick%2)*4,600)
		mover._update_stuck_state(unit,formation,before,events,tick)
	check(not unit.recovery_path.is_empty(),"net-zero oscillation replans beyond old three-attempt cap")
	check(events.size()>0,"oscillation remains reported, not hidden")

func _test_recon_clearance(world: SimulationWorld) -> void:
	var ids: Array[int]=[]
	for i in range(12):
		var id:=97000+i
		var unit:=UnitState.new(id,ORIGIN,0,1)
		unit.definition_id=&"scout_vehicle"
		unit.following_formation=true
		world.units[id]=unit
		ids.append(id)
	var formation:=FormationState.new(97000,ids,ORIGIN)
	formation.strict_deployment_slots=true
	world.formations[97000]=formation
	var destination:=ORIGIN+Vector2(400,0)
	var offset:=formation.get_recon_offset(0)
	world.logic_grid.set_blocked(world.logic_grid.world_to_cell(destination+offset),true)
	check(not world._formation_can_deploy_at(formation,destination),"commander rejects obstructed wide recon slot")
	var command:=FormationMoveCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,ids[0],formation.formation_id,destination)
	check(world.validate_command(command).reason==CommandValidationResult.Reason.INVALID_POSITION,"player and commander agree on recon clearance")
	world.logic_grid.set_blocked(world.logic_grid.world_to_cell(destination+offset),false)
