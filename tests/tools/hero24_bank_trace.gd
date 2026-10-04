extends SceneTree
func _initialize() -> void:
 var p=preload("res://tests/tools/perf23_blue_policy.gd").new("decisive")
 var w:=SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION,{},&"",p.army_plan())
 for tick in range(2600):
  p.advance(w)
  w.advance_tick()
  if tick<1650 or tick%50!=0:continue
  var u:=w.units.get(1035) as UnitState
  var f:=w.formations.get(u.formation_id) as FormationState
  var positions:Dictionary={}
  for id in f.member_entity_ids:positions[id]=w.units[id].position
  var proposed:=w.formation_movement._propose_position(u,f,positions)
  print("TRACE ",tick," pos=",u.position," slot=",u.desired_position," recovery=",u.is_recovering," index=",u.recovery_path_index," path=",u.recovery_path," moving=",f.is_moving," following=",u.following_formation," proposed=",proposed," segment=",w.logic_grid.is_segment_walkable(u.position,proposed)," attempts=",u.recovery_attempts)
 quit()
