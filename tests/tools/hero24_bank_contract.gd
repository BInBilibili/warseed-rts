extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
 checks+=1
 if not value:failures.append(label)
func _initialize()->void:
 var w:=SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
 var grid:=w.logic_grid
 var pos:=Vector2(28166.095703125,20885.759765625)
 var old_waypoint:=Vector2(28048,21008)
 check(not grid.is_segment_walkable(pos,old_waypoint),"long segment crossing bank corner rejected")
 var path:=w.pathfinder.find_path(pos,old_waypoint)
 check(path.size()>2,"path routes around corner")
 for i in range(1,path.size()):
  var steps:=maxi(1,ceili(path[i-1].distance_to(path[i])/16.8))
  for j in range(steps):
   check(grid.is_segment_walkable(path[i-1].lerp(path[i],float(j)/steps),path[i-1].lerp(path[i],float(j+1)/steps)),"valid short movement "+str(i)+"/"+str(j))
 var center:=grid.get_world_rect().get_center()
 var rotated:=w.pathfinder.find_path(center*2-pos,center*2-old_waypoint)
 check(rotated.size()==path.size(),"mirrored path length")
 for i in range(mini(rotated.size(),path.size())):check(rotated[i].distance_to(center*2-path[i])<0.01,"mirrored waypoint "+str(i))
 var u:=UnitState.new(999999,pos,168,2)
 u.following_formation=true
 var f:=FormationState.new(999999,[u.entity_id],pos)
 f.strict_deployment_slots=true
 f.path=w.pathfinder.find_path(pos,Vector2(22528,22528))
 f.path_index=1
 f.is_moving=true
 f.target_position=Vector2(22528,22528)
 var events:Array[SimulationEvent]=[]
 var last:=pos
 for tick in range(200):
  w.formation_movement.advance({f.formation_id:f},{u.entity_id:u},events,tick)
  check(grid.is_segment_walkable(last,u.position),"movement respects terrain "+str(tick))
  last=u.position
 check(u.position.distance_to(pos)>1000,"previously stuck unit makes sustained progress")
 print("HERO24_BANK_CONTRACT ",JSON.stringify({"checks":checks,"failures":failures,"moved":u.position.distance_to(pos)}))
 quit(0 if failures.is_empty() else 1)
