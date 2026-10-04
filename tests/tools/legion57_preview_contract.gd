extends SceneTree

var checks := 0
var failures: Array[String] = []
var output := "user://legion57_preview_contract.json"

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value: failures.append(reason)

func same_points(left: PackedVector2Array, right: PackedVector2Array) -> bool:
	if left.size() != right.size(): return false
	for index in range(left.size()):
		if left[index].distance_to(right[index]) > 0.01: return false
	return true

func finish() -> void:
	var report := {"evidence":"SIMULATED_CANDIDATE","checks":checks,"failures":failures}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write preview contract result: " + output)
		quit(2)
		return
	file.store_string(JSON.stringify(report))
	file.close()
	print("LEGION57_PREVIEW checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	await BattleLoadingScreen.enter_final_battle(self, "res://scenes/game/final_decision.tscn")
	var game := current_scene as GameRoot
	check(game != null, "final battle scene loaded")
	if game == null: finish(); return
	await game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	for frame in range(2): await process_frame
	var world := game.simulation_host.world
	var snapshot := world.create_snapshot()
	game.simulation_host.current_snapshot = snapshot
	var grid := game.simulation_host.get_presentation_grid()
	check(snapshot.growth_mode and grid != null, "growth battle has presentation grid")
	if not snapshot.growth_mode or grid == null: finish(); return
	var cards: Array[UnitCardSnapshot] = []
	for card: UnitCardSnapshot in snapshot.unit_cards:
		if card.faction_id == SimulationWorld.LOCAL_PLAYER_ID and card.formation_id != 0 and not card.active_member_entity_ids.is_empty():
			cards.append(card)
	cards.sort_custom(func(a: UnitCardSnapshot, b: UnitCardSnapshot) -> bool: return String(a.definition_id) < String(b.definition_id))
	check(cards.size() >= 2, "two deployed player cards available")
	if cards.size() < 2: finish(); return
	var selected: Array[int] = cards[0].active_member_entity_ids.duplicate()
	var both := selected.duplicate()
	both.append_array(cards[1].active_member_entity_ids)
	var first := world.formations.get(cards[0].formation_id) as FormationState
	check(first != null, "first card formation exists")
	if first == null: finish(); return
	var single: Array[LegionDeploymentPlan] = []
	var multi: Array[LegionDeploymentPlan] = []
	var goal := Vector2.ZERO
	var found := false
	for radius in [640.0, 800.0, 960.0, 1280.0, 1600.0, 1920.0, 2560.0]:
		if found: break
		for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			var candidate: Vector2 = first.anchor_position + direction * radius
			if snapshot.knowledge.is_visible(grid.world_to_cell(candidate)): continue
			var one := LegionDeploymentPreview.project(snapshot, grid, selected, &"", candidate)
			var two := LegionDeploymentPreview.project(snapshot, grid, both, &"", candidate)
			if one.size() != 1 or two.size() != 2: continue
			if one[0].status == LegionDeploymentPlan.Status.BLOCKED or two[0].status == LegionDeploymentPlan.Status.BLOCKED or two[1].status == LegionDeploymentPlan.Status.BLOCKED: continue
			goal = candidate
			single = one
			multi = two
			found = true
			break
	check(found, "reachable unseen deployment goal exists")
	if not found: finish(); return
	check(single[0].identities.size() == selected.size() and single[0].points.size() == selected.size(), "single card preview counts current members")
	var order := FormationMoveCommand.new(world.allocate_command_id(), SimulationWorld.LOCAL_PLAYER_ID, GameCommand.IssuerKind.PLAYER, world.current_tick, first.leader_entity_id, first.formation_id, single[0].anchor)
	order.deployment_facing = single[0].facing
	var evaluated := LegionManualDeployment.evaluate(world.units, world.formations, world.unit_cards, world.commanders, first, order, world.logic_grid, world.pathfinder)
	check(evaluated != null, "authority evaluates single card")
	if evaluated != null:
		check(evaluated.identities == single[0].identities and evaluated.status == single[0].status and same_points(evaluated.points, single[0].points), "single card preview matches authority points")
	check(LegionDeploymentPreview.project(snapshot, grid, [selected[0]], &"", goal).is_empty(), "diagnostic single unit has no formation preview")
	check(multi[0].anchor.distance_to(multi[1].anchor) > 0.01, "two card previews use separate anchors")
	game.input_controller._set_selection(both)
	var result := game.input_controller.move_selected_to(goal)
	check(result != null and result.is_accepted(), "two card movement accepted")
	var queued := world.command_queue.drain()
	var matched := 0
	for command: GameCommand in queued:
		if not command is FormationMoveCommand: continue
		var move := command as FormationMoveCommand
		for plan in multi:
			if move.formation_id != plan.formation_id: continue
			check(move.target_position.distance_to(plan.anchor) < 0.01 and move.deployment_facing.distance_to(plan.facing) < 0.01, "submitted target and facing match preview")
			matched += 1
	check(matched == 2, "both formation commands were queued")
	var hidden := UnitState.new(999991, goal, 90.0, SimulationWorld.ENEMY_PLAYER_ID)
	world.units[hidden.entity_id] = hidden
	var with_hidden := world.create_snapshot()
	check(with_hidden.get_unit(hidden.entity_id) == null, "new enemy remains hidden")
	var hidden_plans := LegionDeploymentPreview.project(with_hidden, grid, both, &"", goal)
	check(hidden_plans.size() == multi.size(), "hidden enemy preserves preview count")
	if hidden_plans.size() == multi.size():
		for index in range(multi.size()):
			check(hidden_plans[index].status == multi[index].status and same_points(hidden_plans[index].points, multi[index].points), "hidden enemy does not change preview slots")
	for command: GameCommand in queued:
		if not command is FormationMoveCommand: continue
		world._apply_command(command)
		var applied := world.formations[command.formation_id] as FormationState
		for plan in multi:
			if plan.formation_id!=applied.formation_id: continue
			check(applied.legion_deployment!=null and applied.legion_deployment.status!=LegionDeploymentPlan.Status.BLOCKED,"queued move applies real deployment")
			if applied.legion_deployment!=null:
				check(same_points(applied.legion_deployment.points,plan.points),"applied deployment equals displayed slots")
	var commander_id := cards[0].commander_definition_id
	var commander := world.commanders[commander_id] as CommanderState
	var old_goal := commander.deployment_goal
	var whole := LegionDeploymentPreview.project(world.create_snapshot(),grid,[],commander_id,goal)
	check(whole.size()==1,"commander preview includes available legion")
	if whole.size()==1 and whole[0].status!=LegionDeploymentPlan.Status.BLOCKED:
		var combined := LegionManualDeployment.evaluate_commander(world,commander,goal,whole[0].facing)
		check(same_points(combined.points,whole[0].points),"commander preview equals whole-legion authority")
		var commander_order := game.simulation_host.create_commander_objective_command(commander_id,goal)
		commander_order.use_legion_deployment=true; commander_order.deployment_facing=whole[0].facing
		var validation := world._validate_resolved_commander_objective(commander_order)
		check(validation.is_accepted() and commander.deployment_goal==old_goal,"commander validation is read-only")
		world._apply_commander_order(commander_order)
		check(commander.deployment_goal==goal and commander.deployment_facing==whole[0].facing,"commander accepts displayed goal and facing")
	else: check(false,"fixture has complete commander deployment")
	finish()
