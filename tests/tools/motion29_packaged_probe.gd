extends SceneTree
func _initialize() -> void:
	var failures: Array[String] = []
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var host := SimulationHost.new()
	host.world=world
	host.scenario_kind=world.scenario_kind
	host.current_snapshot=world.create_snapshot()
	host.previous_snapshot=host.current_snapshot
	host._grey_ridge_battle_started=true
	host._accumulator=0.099
	host._process(0.002)
	if host.get_interpolation_alpha()<0.99: failures.append("packaged interpolation fix missing")
	host._finish_background_tick(true)
	var commander: CommanderState
	for candidate: CommanderState in world.commanders.values():
		if candidate.faction_id==1 and candidate.definition.strategic_lane_id==&"jungle": commander=candidate
	var hero := world.units[commander.hero_entity_id] as UnitState
	hero.position=Vector2(21264,8400)
	hero.has_move_target=false
	var i:=0
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		if card.definition.role_key==&"UNIT_CARD_ROLE_RECON": continue
		for id in card.member_entity_ids:
			world.units[id].position=Vector2(21264,7760) if i%2==0 else Vector2(22032,7760)
			i+=1
	commander.posture=CommanderState.Posture.BALANCED
	LegionHeroSystem._follow(world,commander,hero)
	if not hero.has_move_target or not world.logic_grid.is_world_position_walkable(hero.move_target): failures.append("packaged follow fix missing")
	var path := hero.path.duplicate()
	hero.local_engagement_active=true
	hero.local_engagement_returning=true
	hero.local_engagement_origin=Vector2(21264,7760)
	GrowthCombatSystem._individual(world,hero)
	if hero.local_engagement_active or hero.local_engagement_returning or hero.path!=path: failures.append("packaged escort ownership missing")
	host.free()
	print("MOTION29_PACKAGED ",JSON.stringify({"evidence":"SIMULATED","failures":failures}))
	quit(0 if failures.is_empty() else 1)
