extends SceneTree
var failures: Array[String] = []
var checks := 0

class DelayedJob extends SimulationTickJob:
	var released := false
	var published_tick := 1
	func dispatch(value: SimulationWorld, _prepare: bool = false) -> void:
		world = value
		released = false
	func is_alive() -> bool: return not released
	func wait_to_finish() -> WorldSnapshot:
		published_tick += 1
		var unit := UnitState.new(999,Vector2(published_tick*10,100),100,1)
		unit.is_visible_to_local_player = true
		return WorldSnapshot.new(published_tick,[UnitSnapshot.new(unit)])
	func stop() -> void: world = null

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size()<30: failures.append(label)

func _initialize() -> void:
	_test_display()
	_test_follow()
	var report := {"evidence":"SIMULATED","checks":checks,"failures":failures}
	print("MOTION29_CONTRACT ",JSON.stringify(report))
	FileAccess.open("res://artifacts/motion29-contract.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _test_display() -> void:
	var host := SimulationHost.new()
	host.scenario_kind = SimulationWorld.ScenarioKind.FINAL_DECISION
	host._grey_ridge_battle_started = true
	var job := DelayedJob.new()
	host._tick_worker = job
	var unit := UnitState.new(999,Vector2(0,100),100,1)
	unit.is_visible_to_local_player = true
	host.previous_snapshot = WorldSnapshot.new(0,[UnitSnapshot.new(unit)])
	unit.position.x = 10
	host.current_snapshot = WorldSnapshot.new(1,[UnitSnapshot.new(unit)])
	var presentation := WorldPresentation.new()
	var last_x := 0.0
	var pending_frames := 0
	for frame in range(180):
		if host._tick_thread != null:
			pending_frames += 1
			# Cover both faster-than-tick and overloaded workers, without OS sleeps.
			if pending_frames >= (2 if frame<60 else 7): job.released = true
		else: pending_frames = 0
		host._process(0.016 if frame<120 else 0.04)
		presentation.previous_snapshot = host.previous_snapshot
		presentation.current_snapshot = host.current_snapshot
		presentation.interpolation_alpha = host.get_interpolation_alpha()
		presentation._cache_previous_interpolation_state()
		presentation._update_unit_batches()
		var x: float = presentation._batch_poses[0].position.x
		check(x+0.0001>=last_x,"visible position rewinds on frame %d" % frame)
		check(x<=host.current_snapshot.units[0].position.x,"no unpublished extrapolation")
		last_x = x
	var expected := host.current_snapshot.tick + (1 if host._tick_thread != null else 0)
	host.set_tactical_paused(true)
	check(host.current_snapshot.tick==expected,"pause collects exactly pending tick")
	var paused_alpha := host.get_interpolation_alpha()
	host._process(3.0)
	check(host.get_interpolation_alpha()==paused_alpha,"pause freezes display time")
	host.set_tactical_paused(false)
	host._finish_background_tick(true)
	host.background_simulation_enabled = false
	host._accumulator = 0.025
	check(is_equal_approx(host.get_interpolation_alpha(),0.25),"synchronous interpolation preserved")
	presentation.free()
	host.free()

func _test_follow() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	for faction in [1,2]:
		var commander: CommanderState
		for candidate: CommanderState in world.commanders.values():
			if candidate.faction_id == faction and candidate.definition.strategic_lane_id == &"jungle": commander = candidate
		var hero := world.units[commander.hero_entity_id] as UnitState
		commander.posture = CommanderState.Posture.BALANCED
		var main: Array[UnitState] = []
		var scouts: Array[UnitState] = []
		for card_id in commander.subordinate_unit_card_ids:
			var card := world.unit_cards[card_id] as UnitCardState
			for id in card.member_entity_ids:
				if card.definition.role_key == &"UNIT_CARD_ROLE_RECON": scouts.append(world.units[id])
				else: main.append(world.units[id])
		var a := Vector2(21264,7760)
		var b := Vector2(22032,7760)
		var origin := Vector2(21264,8400)
		if faction==2:
			a=Vector2(32768,24576)-a
			b=Vector2(32768,24576)-b
			origin=Vector2(32768,24576)-origin
		if main.size()%2:
			main.back().enabled=false
			main.pop_back()
		for i in main.size(): main[i].position=a if i%2==0 else b
		for scout in scouts: scout.position=LegionHeroSystem._home(world,commander)
		hero.position=origin
		hero.has_move_target=false
		check(not world.logic_grid.is_world_position_walkable((a+b)*0.5),"real barrier centroid blocked")
		LegionHeroSystem._follow(world,commander,hero)
		check(hero.has_move_target,"blocked centroid uses reachable troop position")
		var path := hero.path.duplicate()
		for i in range(1,path.size()): check(world.logic_grid.is_segment_walkable(path[i-1],path[i]),"follow path legal")
		for tick in range(160):
			world.current_tick=tick
			if tick%10==0: LegionHeroSystem._follow(world,commander,hero)
			var before := hero.position
			world._advance_unit(hero)
			check(world.logic_grid.is_segment_walkable(before,hero.position),"hero does not cut terrain")
			check(before.distance_to(hero.position)<=14.501,"hero retains 145 speed; no teleport")
		check(minf(hero.position.distance_to(a),hero.position.distance_to(b))<=96.01,"rejoins reachable main body")
		# A distant recruit must not pull the group marker into empty geography.
		for member in main: member.position=b
		main.back().position=origin
		var targets := LegionHeroSystem._follow_candidates(world,commander)
		check(targets[0]==b,"main body outranks isolated recruit and scouts")
		# A stale solo pursuit must not replace the live escort route.
		hero.position=origin
		hero.has_move_target=false
		LegionHeroSystem._follow(world,commander,hero)
		var escort_path := hero.path.duplicate()
		hero.local_engagement_active=true
		hero.local_engagement_returning=true
		hero.local_engagement_origin=a
		GrowthCombatSystem._individual(world,hero)
		check(hero.path==escort_path and hero.has_move_target,"combat preserves escort path")
		check(not hero.local_engagement_active and not hero.local_engagement_returning,"stale pursuit cleared")
		# Failed route is retried when the real destination becomes available.
		var cell := world.logic_grid.world_to_cell(b)
		world.logic_grid.set_blocked(cell,true)
		for member in main: member.position=b
		hero.has_move_target=false
		hero.path=PackedVector2Array()
		LegionHeroSystem._follow(world,commander,hero)
		check(not hero.has_move_target,"unreachable destinations do not teleport")
		world.logic_grid.set_blocked(cell,false)
		LegionHeroSystem._follow(world,commander,hero)
		check(hero.has_move_target,"route retry recovers after blockage clears")
		commander.posture=CommanderState.Posture.HOLD
		LegionHeroSystem._follow(world,commander,hero)
		check(not hero.has_move_target,"explicit hold preserved")
		for member in main: member.enabled=false
		check(LegionHeroSystem._follow_candidates(world,commander).size()==scouts.size(),"scout-only army still has escort")
