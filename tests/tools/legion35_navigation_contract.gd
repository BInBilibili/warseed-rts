extends SceneTree

var checks:=0
var failures:Array[String]=[]

func check(value:bool,reason:String)->void:
	checks+=1
	if not value:failures.append(reason)

func _initialize()->void:
	var world:=SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var grid:=world.logic_grid
	check(grid.has_rotationally_symmetric_solidity(),"terrain plus live headquarters rotate exactly")
	var center:=grid.get_world_rect().get_center()
	for size in [Vector2i(4,3),Vector2i(3,4),Vector2i(2,2),Vector2i(3,3)]:
		for point in [Vector2(2064,22544),Vector2(8192,12288),Vector2(16384,8192),Vector2(1024,2048)]:
			var original:=grid.get_footprint_cells(point,size)
			var rotated:=grid.get_footprint_cells(center*2-point,size)
			check(original.size()==size.x*size.y and rotated.size()==original.size(),"footprint area preserved")
			for cell in original:check(rotated.has(grid.grid_size-Vector2i.ONE-cell),"footprint cell rotates")
	var blue:=world.buildings[SimulationWorld.PLAYER_COMMAND_CENTER_ID] as BuildingState
	var red:=world.buildings[SimulationWorld.ENEMY_COMMAND_CENTER_ID] as BuildingState
	var original_blue:=blue.footprint_cells.duplicate()
	var original_red:=red.footprint_cells.duplicate()
	var presentation:=grid.copy_for_presentation()
	world.destroy_building(blue.entity_id)
	for cell in original_blue:
		check(not grid.is_blocked(cell),"destroyed HQ releases real blocked cells")
		check(presentation.is_blocked(cell),"published navigation copy remains immutable")
	for cell in original_red:check(grid.is_blocked(cell),"destroying own HQ leaves opposing footprint")
	world.destroy_building(red.entity_id)
	check(grid.has_rotationally_symmetric_solidity(),"both destroyed HQs restore symmetric terrain")
	var legacy:=LogicGrid.new()
	var legacy_cells:=legacy.get_footprint_cells(Vector2(176,272),Vector2i(4,3))
	check(legacy_cells==[Vector2i(4,7),Vector2i(4,8),Vector2i(4,9),Vector2i(5,7),Vector2i(5,8),Vector2i(5,9),Vector2i(6,7),Vector2i(6,8),Vector2i(6,9),Vector2i(7,7),Vector2i(7,8),Vector2i(7,9)],"legacy footprint golden remains unchanged")
	var map_failures:=TestFinalDecisionMap.new().run()
	check(map_failures.is_empty(),"current full static map contract: "+str(map_failures))
	FileAccess.open("res://artifacts/legion35/navigation.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED","checks":checks,"failures":failures}))
	for failure in failures:push_error(failure)
	print("LEGION35_NAVIGATION checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
