extends SceneTree

func _initialize() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var host := SimulationHost.new()
	host.world = world
	host.scenario_kind = world.scenario_kind
	host.current_snapshot = world.create_snapshot()
	host.previous_snapshot = host.current_snapshot
	host._grey_ridge_battle_started = true
	host._accumulator = 0.099
	var before := host.get_interpolation_alpha()
	host._process(0.002)
	var after := host.get_interpolation_alpha()
	host._finish_background_tick(true)
	var commander: CommanderState
	for candidate: CommanderState in world.commanders.values():
		if candidate.faction_id == 1 and candidate.definition.strategic_lane_id == &"jungle": commander = candidate
	var hero := world.units[commander.hero_entity_id] as UnitState
	var members: Array[UnitState] = []
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		if card.definition.role_key == &"UNIT_CARD_ROLE_RECON": continue
		for id in card.member_entity_ids:
			if world.units[id].enabled: members.append(world.units[id])
	# Find a real map barrier with walkable cells on both sides and a legal route.
	var positions: Array[Vector2] = []
	for y in range(200, world.logic_grid.grid_size.y-200, 7):
		for x in range(200,world.logic_grid.grid_size.x-200,7):
			var cell := Vector2i(x,y)
			if not world.logic_grid.is_blocked(cell): continue
			var a := world.logic_grid.cell_to_world(cell+Vector2i(-12,0))
			var b := world.logic_grid.cell_to_world(cell+Vector2i(12,0))
			if world.logic_grid.is_world_position_walkable(a) and world.logic_grid.is_world_position_walkable(b) and world.pathfinder.find_path(a,b).size()>1:
				positions=[a,b]
				break
		if not positions.is_empty(): break
	if positions.is_empty():
		push_error("no map barrier fixture")
		quit(1)
		return
	if members.size() % 2:
		members.back().enabled = false
		members.pop_back()
	for i in members.size(): members[i].position = positions[i % 2]
	var mean := Vector2.ZERO
	for member in members: mean += member.position
	mean /= members.size()
	hero.position = positions[0] + Vector2(0,640)
	if not world.logic_grid.is_world_position_walkable(hero.position): hero.position = positions[1]
	hero.has_move_target = false
	commander.posture = CommanderState.Posture.BALANCED
	LegionHeroSystem._follow(world,commander,hero)
	var report := {"evidence":"SIMULATED","alpha_before":before,"alpha_after_dispatch":after,"display_rewinds":after<before,"mean":str(mean),"mean_walkable":world.logic_grid.is_world_position_walkable(mean),"hero":str(hero.position),"hero_has_path":hero.has_move_target,"member_positions":[str(positions[0]),str(positions[1])],"chosen_target":str(hero.move_target)}
	print("MOTION29_REPRO ",JSON.stringify(report))
	FileAccess.open("res://artifacts/motion29-repro.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	host.free()
	quit()
