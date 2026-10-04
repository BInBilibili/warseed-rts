extends SceneTree

const Planner = preload("res://artifacts/legion38/staging/legion_protection_planner.gd")
var checks := 0
var failures: Array[String] = []
var output := "res://artifacts/legion38/protection-before.json"

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value: failures.append(reason)

func unit(id: int, position: Vector2, role: UnitState.TacticalRole, faction: int = 1) -> UnitSnapshot:
	var state := UnitState.new(id, position, 165, faction)
	state.control_state = UnitState.ControlState.AGENT_ASSIGNED
	state.tactical_role = role
	state.can_attack = true
	state.attack_range = 190
	var view := UnitSnapshot.new(state)
	view.is_visible_to_local_player = true
	return view

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var grid := LogicGrid.new()
	grid.grid_size = Vector2i(192,96)
	var finder := GridPathfinder.new(grid)
	var hero := unit(100, Vector2(800,1000), UnitState.TacticalRole.NONE)
	var own: Array[UnitSnapshot] = [unit(1,Vector2(1000,1000),UnitState.TacticalRole.ASSAULT), unit(2,Vector2(1048,1000),UnitState.TacticalRole.ARMOR), unit(3,Vector2(1000,1048),UnitState.TacticalRole.ASSAULT)]
	var original := Planner.State.new()
	for profile in LegionTemplate.PROFILE_IDS:
		var result := Planner.plan(original,hero,own,[],profile,grid,finder,0,Vector2.RIGHT)
		check(result.safe and result.reason == &"PROTECTED_TARGET", "reachable rear protection "+str(profile))
		check(result.core_path_distance <= 240, "actual core path bounded "+str(profile))
		check(result.target.x < own[0].position.x, "no front chase "+str(profile))
		check(result.path[0] == hero.position and result.path[-1] == result.target, "exact endpoints "+str(profile))
		for index in range(1,result.path.size()): check(grid.is_segment_walkable(result.path[index-1],result.path[index]), "walkable route")
		var reordered: Array[UnitSnapshot] = own.duplicate()
		reordered.reverse()
		var other := Planner.plan(original,hero,reordered,[],profile,grid,finder,0,Vector2.RIGHT)
		check(result.target == other.target and result.path == other.path and result.state.escort_id == other.state.escort_id, "input ordering independent "+str(profile))
		var pivot := Vector2(6144,3072)
		var mirrored_hero := unit(200,pivot-hero.position,UnitState.TacticalRole.NONE,2)
		var mirrored: Array[UnitSnapshot] = []
		for member in own: mirrored.append(unit(member.entity_id,pivot-member.position,member.tactical_role,2))
		var opposite := Planner.State.new()
		opposite.facing = Vector2.LEFT
		var mirror_result := Planner.plan(opposite,mirrored_hero,mirrored,[],profile,grid,finder,0,Vector2.LEFT)
		check(mirror_result.safe and mirror_result.target.is_equal_approx(pivot-result.target), "rotated open geometry "+str(profile))
	check(original.escort_id == 0 and original.pending_since == -1, "planner input state not mutated")
	var protected := Planner.plan(original,hero,own,[],&"spear",grid,finder,0,Vector2.RIGHT)
	protected.state.escort_id = 3
	var kept := Planner.plan(protected.state,hero,own,[],&"spear",grid,finder,1,Vector2.RIGHT)
	check(kept.state.escort_id == 3, "retain eligible real escort")
	kept.state.facing = Vector2.UP
	check(protected.state.facing == Vector2.RIGHT, "future state cannot mutate older value")
	var distant_escort := Planner.State.new()
	distant_escort.escort_id = 2
	check(Planner.plan(distant_escort,hero,own,[],&"spear",grid,finder,1,Vector2.RIGHT).state.escort_id != 2,"replace escort beyond protection limit when local main core is available")
	for invalid in ["scout","firepower","returning","rejoining","manual","enemy","dead"]:
		var member := unit(1,Vector2(1000,1000),UnitState.TacticalRole.ASSAULT)
		match invalid:
			"scout": member.tactical_role = UnitState.TacticalRole.SCOUT
			"firepower": member.tactical_role = UnitState.TacticalRole.FIREPOWER
			"returning": member.legion_returning = true
			"rejoining": member.rejoin_pending = true
			"manual": member.control_state = UnitState.ControlState.TEMPORARILY_OVERRIDDEN
			"enemy": member.faction_id = 2
			"dead": member.enabled = false
		var result := Planner.plan(original,hero,[member],[],&"spear",grid,finder,0,Vector2.RIGHT)
		check(not result.safe and result.reason == &"NO_CORE" and result.path.is_empty(), "exclude ineligible escort "+invalid)
	var distant := unit(9,Vector2(4000,1600),UnitState.TacticalRole.ARMOR)
	var dispersed: Array[UnitSnapshot] = own.duplicate()
	dispersed.append(distant)
	check(Planner.plan(original,hero,dispersed,[],&"spear",grid,finder,0,Vector2.RIGHT).state.escort_id != 9,"remote isolated member does not pull hero")
	var hidden := unit(20,Vector2(850,1000),UnitState.TacticalRole.ARMOR,2)
	hidden.is_visible_to_local_player = false
	var first := Planner.plan(original,hero,own,[hidden],&"spear",grid,finder,0,Vector2.RIGHT)
	hidden.position = Vector2(750,1100)
	hidden.attack_range = 5000
	var second := Planner.plan(original,hero,own,[hidden],&"spear",grid,finder,0,Vector2.RIGHT)
	check(first.target == second.target and first.state.facing == second.state.facing and first.reason == second.reason, "hidden pollution does not affect choice")
	var side := unit(20,Vector2(800,1500),UnitState.TacticalRole.ARMOR,2)
	var state := Planner.State.new()
	for tick in range(21):
		var result := Planner.plan(state,hero,own,[side],&"spear",grid,finder,tick,Vector2.RIGHT,7,Vector2.LEFT)
		check(result.state.facing == (Vector2.RIGHT if tick < 20 else Vector2.DOWN),"stable facing commitment tick="+str(tick))
		check(result.state.retreat_direction == Vector2.LEFT,"retreat independent of protection turn tick="+str(tick))
		state = result.state
	var frozen_exit := Planner.plan(state,hero,own,[side],&"spear",grid,finder,21,Vector2.RIGHT,7,Vector2.RIGHT)
	check(frozen_exit.state.retreat_direction == Vector2.LEFT,"same intent cannot retarget exit")
	var changed_exit := Planner.plan(state,hero,own,[side],&"spear",grid,finder,21,Vector2.RIGHT,8,Vector2.UP)
	check(changed_exit.state.retreat_direction == Vector2.UP,"new valid intent can change exit")
	var hit := unit(20,Vector2(800,1100),UnitState.TacticalRole.ASSAULT,2)
	hit.attack_target_entity_id = hero.entity_id
	var immediate := Planner.plan(original,hero,own,[hit],&"spear",grid,finder,0,Vector2.RIGHT)
	check(immediate.state.facing == Vector2.DOWN,"direct visible attack can bypass facing delay")
	var decoy := unit(21,Vector2(850,1000),UnitState.TacticalRole.ASSAULT,2)
	var priority := Planner.plan(original,hero,own,[decoy,hit],&"spear",grid,finder,0,Vector2.RIGHT)
	check(priority.state.facing == Vector2.DOWN,"direct attacker outranks nearer non-attacking contact")
	var all_covered := unit(30,Vector2(1000,1000),UnitState.TacticalRole.FIREPOWER,2)
	all_covered.attack_range = 5000
	var no_safe := Planner.plan(original,hero,own,[all_covered],&"spear",grid,finder,0,Vector2.RIGHT)
	check(not no_safe.safe and no_safe.reason == &"EXPOSED" and no_safe.path.is_empty(),"no invented safe position under full fire coverage")
	var far_hero := unit(100,Vector2(1400,1000),UnitState.TacticalRole.NONE)
	var crossing_enemy := unit(30,Vector2(1200,1000),UnitState.TacticalRole.ASSAULT,2)
	crossing_enemy.attack_range = 158
	var unsafe_crossing := Planner.plan(original,far_hero,own,[crossing_enemy],&"spear",grid,finder,0,Vector2.RIGHT)
	check(not unsafe_crossing.safe and unsafe_crossing.path.is_empty(),"safe endpoint cannot authorize a route through visible fire")
	var blocked := LogicGrid.new()
	blocked.grid_size = grid.grid_size
	blocked.set_blocked(blocked.world_to_cell(Vector2(840,1000)),true)
	var detour := Planner.plan(original,hero,own,[],&"spear",blocked,GridPathfinder.new(blocked),0,Vector2.RIGHT)
	check(detour.safe and detour.target != Vector2(840,1000) and detour.core_path_distance <= 240,"blocked nominal slot chooses reachable alternative")
	for degrees in [0,30,-30,60,-60,90,-90,180]:
		blocked.set_blocked(blocked.world_to_cell(Vector2(1000,1000)-Vector2.RIGHT.rotated(deg_to_rad(degrees))*160),true)
	var unavailable := Planner.plan(original,hero,own,[],&"spear",blocked,GridPathfinder.new(blocked),0,Vector2.RIGHT)
	check(not unavailable.safe and unavailable.reason == &"PATH_UNAVAILABLE", "all target slots blocked returns explicit refusal")
	var invalid_profile := Planner.plan(original,hero,own,[],&"unknown",grid,finder,0,Vector2.RIGHT)
	check(not invalid_profile.safe and invalid_profile.reason == &"INVALID_PROFILE", "unknown content profile cannot silently get ranger behavior")
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	for faction in [1,2]:
		var snapshot := world.create_faction_snapshot(faction)
		for commander in snapshot.commanders:
			var actual_hero: UnitSnapshot = null
			var actual_own: Array[UnitSnapshot] = []
			var actual_visible: Array[UnitSnapshot] = []
			for view in snapshot.units:
				if view.entity_id == commander.hero_entity_id: actual_hero = view
				if view.faction_id == faction and commander.subordinate_unit_card_ids.has(view.unit_card_id): actual_own.append(view)
				elif view.faction_id != faction and view.is_visible_to_local_player: actual_visible.append(view)
			check(actual_hero != null,"real faction snapshot exposes own hero")
			if actual_hero == null: continue
			var state_for_faction := Planner.State.new()
			state_for_faction.facing = Vector2.RIGHT if faction == 1 else Vector2.LEFT
			var planned := Planner.plan(state_for_faction,actual_hero,actual_own,actual_visible,commander.profile_id,world.logic_grid,world.pathfinder,0,state_for_faction.facing)
			check(planned.state.escort_id != 0,"real core eligibility "+str(commander.definition_id))
			check(planned.safe and planned.core_path_distance <= 240,"real opening protected slot "+str(commander.definition_id)+":"+str(planned.reason))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PREINTEGRATION","checks":checks,"failures":failures}))
	print("LEGION38_PROTECTION checks=",checks," failures=",failures.size())
	for reason in failures: print("FAIL ",reason)
	quit(0 if failures.is_empty() else 1)
