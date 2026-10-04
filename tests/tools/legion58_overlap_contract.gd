extends SceneTree
var checks := 0
var failures: Array[String]=[]
func check(value: bool, reason: String) -> void:
	checks+=1
	if not value: failures.append(reason)
func _initialize() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var w := SimulationWorld.new(false)
	w.logic_grid=LogicGrid.new(); w.logic_grid.grid_size=Vector2i(100,100)
	w.pathfinder=GridPathfinder.new(w.logic_grid)
	var a := UnitState.new(1,Vector2(512,512),135,1)
	var b := UnitState.new(2,Vector2(560,512),135,1)
	a.flexible_legion_movement=true; b.flexible_legion_movement=true
	a.can_attack=false; b.can_attack=false; a.health=200; a.max_health=200; a.armor=14
	w.units={1:a,2:b}
	var c := LegionMotionConstraint.new(2); c.ground_radius=32
	check(c.constrain(a.position,b.position,1,w.units,w.logic_grid,w.pathfinder)==b.position,"friendly movement may overlap")
	b.faction_id=2
	check(not c._clear(a.position,b.position,1,w.units,w.logic_grid),"enemy still blocks")
	b.faction_id=1; a.position=b.position
	LegionReformationSystem.finish_movement(w)
	check(LegionReformationSystem.damage_factor(a)==1.5 and LegionReformationSystem.damage_factor(b)==1.5,"both bodies pay")
	var snapshot := UnitSnapshot.new(a)
	check(snapshot.reformation_damage_multiplier==1.5 and snapshot.reformation_phase==LegionReformationState.Phase.SEPARATING,"snapshot warns actual overlap")
	var events: Array[SimulationEvent]=[]
	var projectiles := {1:ProjectileState.new(1,3,1,2,a.position,600,50,-3)}
	CombatSystem.new().advance(w.units,{},projectiles,2,events,2)
	check(is_equal_approx(a.health,146.0),"50 minus 14 armor times 1.5 equals 54")
	a.reformation.phase=LegionReformationState.Phase.REFORMING
	projectiles={2:ProjectileState.new(2,3,1,2,a.position,600,50,-3)}
	CombatSystem.new().advance(w.units,{},projectiles,3,events,3)
	check(is_equal_approx(a.health,92.0),"reformation plus overlap never stacks twice")
	a.reformation.phase=LegionReformationState.Phase.SOLID; a.position+=Vector2(48,0)
	LegionReformationSystem.finish_movement(w)
	check(LegionReformationSystem.damage_factor(a)==1.0 and LegionReformationSystem.damage_factor(b)==1.0,"separation clears both immediately")
	check(snapshot.reformation_damage_multiplier==1.5,"old snapshot unchanged")
	projectiles={3:ProjectileState.new(3,3,1,2,a.position,600,50,-3)}
	CombatSystem.new().advance(w.units,{},projectiles,4,events,4)
	check(is_equal_approx(a.health,56.0),"separated hit returns to 36")
	w.logic_grid.set_blocked(Vector2i(20,16),true)
	check(not c._clear(a.position,Vector2(700,528),1,w.units,w.logic_grid),"terrain still blocks")
	# Continuous legal endpoints on inflated-cell boundaries must still route.
	var edge_grid := LogicGrid.new(); edge_grid.grid_size=Vector2i(64,64)
	for y in range(8,25): edge_grid.set_blocked(Vector2i(10,y),true)
	var edge_finder := GridPathfinder.new(edge_grid)
	var edge_start := Vector2(288,512); var edge_end := Vector2(704,512)
	check(LegionTransitGeometry.segment_fits(edge_grid,edge_start,edge_start),"wall edge is physically legal")
	var edge_path := edge_finder.find_body_path(edge_start,edge_end)
	check(edge_path.size()>1,"wall edge can join a detour")
	for index in range(1,edge_path.size()): check(LegionTransitGeometry.segment_fits(edge_grid,edge_path[index-1],edge_path[index]),"wall detour full body clearance")
	# A previously symmetric map must discard mirroring after asymmetric edits.
	var dynamic_grid := LogicGrid.new(); dynamic_grid.grid_size=Vector2i(64,64); dynamic_grid.centrally_symmetric_navigation=true
	var dynamic_finder := GridPathfinder.new(dynamic_grid)
	for y in range(20,41): dynamic_grid.set_blocked(Vector2i(40,y),true)
	var dynamic_path := dynamic_finder.find_body_path(Vector2(1504,960),Vector2(1120,960))
	check(dynamic_path.size()>1,"asymmetric edit still has a detour")
	for index in range(1,dynamic_path.size()): check(LegionTransitGeometry.segment_fits(dynamic_grid,dynamic_path[index-1],dynamic_path[index]),"dynamic route never mirrors through new obstacle")
	# Exercise the actual second hero pass, not just the collision helper.
	var actual := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	actual.advance_tick()
	actual.legion_formation_system.advance_heroes(actual)
	var flexible_record := actual.legion_formation_system.records[&"di_tian"]
	flexible_record.state.escort_id=0; flexible_record.reason=&"IN_POSITION"
	LegionSpatialExecutor.refresh(actual)
	check(flexible_record.reason==&"IN_POSITION","legacy escort loss cannot override flexible physical arrival")
	for commander: CommanderState in actual.commanders.values():
		var hero: UnitState=actual.units[commander.hero_entity_id]
		check(hero.legion_motion!=null and hero.legion_motion.ground_radius==32.0,"hero retains body collision "+str(commander.definition.definition_id))
	var selected: CommanderState=actual.commanders[&"di_tian"]
	var hero: UnitState=actual.units[selected.hero_entity_id]
	hero.position=Vector2(512,512); hero.path=PackedVector2Array([hero.position,Vector2(612,512)]); hero.path_index=1; hero.has_move_target=true
	var enemy := UnitState.new(99999,Vector2(542,512),135,2)
	actual.units={hero.entity_id:hero,enemy.entity_id:enemy}
	actual.logic_grid=LogicGrid.new(); actual.logic_grid.grid_size=Vector2i(64,64); actual.pathfinder=GridPathfinder.new(actual.logic_grid)
	actual._advance_unit(hero)
	check(hero.position.distance_to(enemy.position)>=24.0-0.001,"actual hero movement respects enemy body")
	var result := {"evidence":"SIMULATED_MAIN","checks":checks,"failures":failures}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result))
	print("OVERLAP_CONTRACT ",result); quit(0 if failures.is_empty() else 1)
