extends SceneTree
func _initialize() -> void:
 var w:=SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
 for pos in [Vector2(28166.095703125,20885.759765625),Vector2(27299.845703125,21467.59765625),Vector2(4571.6474609375,16781.09375)]:
  var target:=w.strategic_regions[&"blue_bottom_outer"].position as Vector2
  var path:=w.pathfinder.find_path(pos,target)
  var bad:=0
  for i in range(1,path.size()):
   if not w.logic_grid.is_segment_walkable(path[i-1],path[i]):bad+=1
  print("BANK_AUDIT pos=",pos," walkable=",w.logic_grid.is_world_position_walkable(pos)," path=",path," blocked_segments=",bad)
 quit()
