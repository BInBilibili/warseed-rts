extends SceneTree
func _initialize() -> void:
	var map := load("res://data/maps/final_decision.tres") as MapDefinition
	var started := Time.get_ticks_usec()
	var first := LogicGrid.create_for_map(map)
	var cold := (Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	var second := LogicGrid.create_for_map(map)
	var warm := (Time.get_ticks_usec() - started) / 1000.0
	var same := first.blocked_cells == second.blocked_cells
	var cell := map.player_spawn_cell
	first.set_blocked(cell, true)
	var isolated := not second.is_blocked(cell)
	print("LEGION22_LOADING ",JSON.stringify({"cold_grid_ms":cold,"warm_grid_ms":warm,"same_geometry":same,"isolated":isolated}))
	quit(0 if same and isolated else 1)
