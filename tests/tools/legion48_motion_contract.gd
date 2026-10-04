extends SceneTree

var checks := 0
var failures: Array[String] = []
var output := "res://artifacts/legion48/motion-final.json"

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value and not failures.has(reason): failures.append(reason)

func member(id: int, position: Vector2) -> UnitState:
	var unit := UnitState.new(id,position,160.0,1)
	unit.control_state = UnitState.ControlState.AGENT_ASSIGNED
	return unit

func independent_paths() -> void:
	var world := SimulationWorld.new(false,false)
	world.units.clear(); world.events.clear()
	world.logic_grid=LogicGrid.new(); world.logic_grid.grid_size=Vector2i(192,96)
	world.pathfinder=GridPathfinder.new(world.logic_grid)
	var hero := member(1,Vector2(1000,1000))
	var escort := member(2,Vector2(1230,1000))
	hero.legion_motion = LegionMotionConstraint.new(2)
	escort.legion_motion = LegionMotionConstraint.new(1)
	world.units[1]=hero; world.units[2]=escort
	escort.path=PackedVector2Array([escort.position,Vector2(1245,1000),Vector2(1500,1000)])
	escort.path_index=1; escort.has_move_target=true
	for tick in range(30):
		var before := escort.position
		world._advance_unit(escort)
		check(escort.position.distance_to(hero.position)<=240.01,"independent escort cannot leave stationary hero")
		check(escort.position.distance_to(before)<=16.01,"independent actual speed budget")
	check(escort.path_index==1 and escort.has_move_target,"blocked independent path cannot consume unreached waypoint")
	check(world.events.is_empty(),"blocked independent path cannot emit arrival")
	# Partner moved earlier in this tick: follower sees its actual new position.
	hero.path=PackedVector2Array([hero.position,Vector2(1100,1000)])
	hero.path_index=1; hero.has_move_target=true
	for tick in range(10):
		world._advance_unit(hero); world._advance_unit(escort)
		check(escort.position.distance_to(hero.position)<=240.01,"reciprocal constraint uses latest partner position")
	check(hero.position.x>1000 and escort.position.x>1240,"coupled pair makes real progress when core can follow")
	# A real blocker is never crossed by a coupled unit, visible or otherwise.
	var obstacle := member(3,escort.position+Vector2(30,0)); world.units[3]=obstacle
	var before := escort.position
	world._advance_unit(escort)
	check(Geometry2D.get_closest_point_to_segment(obstacle.position,before,escort.position).distance_to(obstacle.position)>=23.99,"coupled independent movement obeys swept physical occupancy")

func card_slots() -> void:
	var grid := LogicGrid.new(); grid.grid_size=Vector2i(192,96)
	var movement := FormationMovementSystem.new(grid,GridPathfinder.new(grid))
	var hero := member(1,Vector2(1000,1000))
	var escort := member(2,Vector2(1230,1000))
	escort.following_formation=true; escort.formation_id=1
	escort.legion_motion=LegionMotionConstraint.new(1)
	var units := {1:hero,2:escort}
	var formation := FormationState.new(1,[2],Vector2(1500,1000))
	formation.is_moving=true; formation.anchor_speed_limit=0
	formation.path=PackedVector2Array([formation.anchor_position,Vector2(1600,1000)]); formation.path_index=1
	var events: Array[SimulationEvent] = []
	for tick in range(100):
		var before := escort.position
		movement.advance({1:formation},units,events,tick)
		check(escort.position.distance_to(hero.position)<=240.01,"actual card member stays with hero despite old slot beyond cap")
		check(escort.position.distance_to(before)<=16.01,"actual card member respects speed budget")
	check(formation.anchor_position==Vector2(1500,1000),"fixture anchor really remains stopped")
	check(escort.position.x>1230 and escort.position.x<=1240.01,"card movement reaches constraint boundary without teleport")
	check(events.is_empty(),"intentional core wait creates neither arrival nor false stuck event")
	# Recovery must not commit an index before the constrained move reaches it.
	escort.position=Vector2(1230,1000); escort.move_speed=400
	escort.is_recovering=true; escort.recovery_path=PackedVector2Array([escort.position,Vector2(1250,1000)])
	escort.recovery_path_index=1
	movement.advance({1:formation},units,events,101)
	check(escort.is_recovering and escort.recovery_path_index==1 and escort.recovery_path.size()==2,"coupled recovery preserves unreached waypoint")
	# Final arrival snapping cannot bypass the constraint within tolerance.
	escort.is_recovering=false; escort.position=Vector2(1238,1000)
	formation.anchor_position=Vector2(1244,1000); formation.path_index=formation.path.size()
	formation.is_moving=true
	movement.advance({1:formation},units,events,102)
	check(formation.is_moving and escort.position.x<=1240.01,"card completion cannot snap beyond allowed separation")
	# Arrival tolerance must not add a second displacement after a full step.
	escort.position=Vector2(1100,1000); escort.move_speed=160
	formation.anchor_position=Vector2(1121,1000); formation.is_moving=true
	formation.path_index=formation.path.size()
	movement.advance({1:formation},units,events,103)
	check(escort.position.distance_to(Vector2(1100,1000))<=16.01,"arrival snapping stays in the same physical tick budget")
	check(formation.is_moving,"arrival waits until the endpoint is physically reached")
	movement.advance({1:formation},units,events,104)
	check(not formation.is_moving and escort.position.is_equal_approx(Vector2(1121,1000)),"next tick can complete real arrival")


func current_control() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.advance_tick()
	var commander: CommanderState = world.commanders[&"bai_jiuyang"]
	var hero: UnitState = world.units[commander.hero_entity_id]
	var record: LegionFormationState = world.legion_formation_system.records[&"bai_jiuyang"]
	var escort: UnitState = world.units[record.state.escort_id]
	check(hero.legion_motion!=null and escort.legion_motion!=null,"production attaches reciprocal constraints")
	var card: UnitCardState=world.unit_cards[escort.unit_card_id]
	var take:=UnitCardControlCommand.new(world.allocate_command_id(),1,world.current_tick,card.definition.definition_id,UnitCardControlCommand.Action.TAKEOVER)
	check(world.submit_command(take).is_accepted(),"takeover command accepted")
	world.advance_tick()
	for id in card.member_entity_ids:
		var unit := world.units.get(id) as UnitState
		if unit!=null: check(unit.legion_motion==null,"manual card has no stale autonomous constraint")
	var retreat:=CommanderOrderCommand.new(world.allocate_command_id(),1,world.current_tick,&"bai_jiuyang",CommanderOrderCommand.OrderKind.SET_POSTURE,Vector2.ZERO,&"",CommanderState.Posture.DISENGAGE)
	check(world.submit_command(retreat).is_accepted(),"retreat command accepted")
	world.advance_tick()
	check(hero.legion_motion!=null and hero.legion_motion.partner_id==0,"approved retreat retains physical collision without a forward-cohesion partner")
	for id in commander.subordinate_unit_card_ids:
		var other: UnitCardState=world.unit_cards[id]
		for entity in other.member_entity_ids:
			var unit := world.units.get(entity) as UnitState
			if unit!=null: check(unit.legion_motion==null,"retreat core not held by old escort constraints")
	var legacy:=SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.GREY_RIDGE)
	legacy.advance_tick()
	for unit: UnitState in legacy.units.values(): check(unit.legion_motion==null,"legacy unit executor unaffected")

func obstacle_routes() -> void:
	var grid := LogicGrid.new(); grid.grid_size=Vector2i(192,96)
	var finder := GridPathfinder.new(grid)
	var hero := member(1,Vector2(1000,1000))
	var escort := member(2,Vector2(1080,1000))
	var blocker := member(3,Vector2(1030,1000))
	var units := {1:hero,2:escort,3:blocker}
	var constraint := LegionMotionConstraint.new(2)
	var side := constraint.constrain(hero.position,hero.position+Vector2(16,0),1,units,grid,finder)
	check(side.distance_to(hero.position)>1.0 and absf(side.y-hero.position.y)>1.0,"physical blocker produces an actual side step instead of permanent zero motion")
	check(side.distance_to(hero.position)<=16.01,"side step stays in original tick movement budget")
	check(Geometry2D.get_closest_point_to_segment(blocker.position,hero.position,side).distance_to(blocker.position)>=23.99,"side step sweeps clear of actual blocker")
	units.erase(3)
	for y in range(28,34): grid.set_blocked(Vector2i(32,y),true)
	escort.position=Vector2(1072,912)
	var found := false
	for y in range(912,1088,2):
		hero.position=Vector2(1008,y)
		var proposed := hero.position+Vector2(0,16)
		var prior := LegionProtectionPlanner.route(grid,finder,hero.position,escort.position)
		var next := LegionProtectionPlanner.route(grid,finder,proposed,escort.position)
		if prior.is_empty() or next.is_empty(): continue
		if LegionProtectionPlanner.path_length(prior)>240.0 or LegionProtectionPlanner.path_length(next)<=240.01: continue
		found=true
		check(proposed.distance_to(escort.position)<240.0,"bent route fixture would pass an insufficient circular distance test")
		var limited := constraint.constrain(hero.position,proposed,1,units,grid,finder)
		var actual := LegionProtectionPlanner.route(grid,finder,limited,escort.position)
		check(not actual.is_empty() and LegionProtectionPlanner.path_length(actual)<=240.01,"bent actual navigation route remains inside protection distance")
		check(limited.distance_to(hero.position)<=16.01 and grid.is_segment_walkable(hero.position,limited),"clipped bend movement is physical and speed bounded")
		break
	check(found,"route fixture contains a real path-length-only violation")

func replacement_cleanup() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.advance_tick()
	var commander: CommanderState=world.commanders[&"lin_mo"]
	var hero: UnitState=world.units[commander.hero_entity_id]
	var old_id: int=world.legion_formation_system.snapshot(&"lin_mo").state.escort_id
	var old: UnitState=world.units[old_id]
	old.enabled=false
	world.legion_formation_system.advance_heroes(world)
	var new_id: int=world.legion_formation_system.snapshot(&"lin_mo").state.escort_id
	check(new_id!=old_id and new_id>0,"disabled escort is replaced by another actual core member")
	check(old.legion_motion==null and hero.legion_motion.partner_id==new_id,"second planning pass removes old reciprocal partner constraint")
	commander.legion_regrouping=true
	world.legion_formation_system.prepare(world)
	check(hero.legion_motion==null and world.units[new_id].legion_motion==null,"regrouping removes both directions of transient coupling")

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	independent_paths(); card_slots(); current_control(); obstacle_routes(); replacement_cleanup()
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED","checks":checks,"failures":failures,"scope":"actual independent and card movement, recovery/arrival, command transitions; not full B"}))
	print("LEGION48_MOTION checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
