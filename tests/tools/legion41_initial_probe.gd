extends "res://tests/tools/legion41_pursuit_lab.gd"

func _initialize() -> void:
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/legion34/v5/config.json")).profiles
	actual_map = load("res://data/maps/final_decision.tres") as MapDefinition
	build_route(false)
	var units := {}
	var own := column_for(0,60,1,1,5000.0,units)
	var enemy := column_for(4,60,2,1001,5260.0+own.lag.max(),units)
	var nearest := INF
	for a in own.ids:
		for b in enemy.ids: nearest = minf(nearest,units[a].position.distance_to(units[b].position))
	print("INITIAL ",JSON.stringify({"own_ids":own.ids.size(),"enemy_ids":enemy.ids.size(),"own_progress":own.progress,"enemy_progress":enemy.progress,"own_front":str(units[own.ids[0]].position),"enemy_tail":str(units[enemy.ids[-1]].position),"nearest":nearest,"own_seen":visible_contacts(units,own.army,enemy.army),"enemy_seen":visible_contacts(units,enemy.army,own.army),"sight":units[enemy.ids[-1]].sight_range}))
	quit()
