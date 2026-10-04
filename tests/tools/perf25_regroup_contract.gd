extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	var mirrored: Array[PackedVector2Array] = []
	for faction in [1, 2]:
		for location in [&"red_mid_outer", &"red_top_inner", &"red_base"]:
			var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
			var commander: CommanderState = world.commanders[&"bai_jiuyang" if faction == 1 else &"red_bai_jiuyang"]
			var origin: Vector2 = world.strategic_regions[location].position
			if location == &"red_base": origin += Vector2(-480, 480)
			var center2 := world.battle_definition.battlefield_bounds.size
			if faction == 2: origin = center2 - origin
			var count := 0
			var soldiers: Array[UnitState] = []
			for card_id in commander.subordinate_unit_card_ids:
				var card: UnitCardState = world.unit_cards[card_id]
				world._apply_field_reinforcement(card, card.definition.authorized_strength - UnitCardSnapshot.new(card, world.units).current_strength)
				for id in card.member_entity_ids:
					var unit: UnitState = world.units[id]
					unit.position = origin + Vector2((count % 10 - 5) * 24, (count / 10 - 3) * 24) * (1 if faction == 1 else -1)
					soldiers.append(unit)
					count += 1
			LegionHeroSystem._begin_return(world, commander)
			var home := LegionHeroSystem._home(world, commander)
			for unit in soldiers:
				check(unit.has_move_target and unit.path[0] == unit.position and unit.path[-1] == home and unit.desired_position == home, "complete return route")
				var valid := true
				for index in range(1, unit.path.size()):
					var a := unit.path[index - 1]
					var b := unit.path[index]
					valid = valid and world.logic_grid.is_segment_walkable(a, b)
					var steps := maxi(1, ceili(a.distance_to(b) / (unit.move_speed * 0.1)))
					for step in range(steps):
						valid = valid and world.logic_grid.is_segment_walkable(a.lerp(b, float(step) / steps), a.lerp(b, float(step + 1) / steps))
				check(valid, "all full segments and movement-sized segments walkable")
				if faction == 1:
					mirrored.append(unit.path.duplicate())
				else:
					var expected := mirrored.pop_front() as PackedVector2Array
					var equal := expected.size() == unit.path.size()
					if equal:
						for i in range(expected.size()): equal = equal and (center2 - expected[i]).distance_to(unit.path[i]) < 0.01
					check(equal, "rotated recall route")
			var first := soldiers[0].path.duplicate()
			soldiers[1].path[0] += Vector2.ONE
			check(soldiers[0].path == first, "survivor paths are independent values")
	_test_obstacle_fallback()
	_test_subpixel_join()
	var report := {"evidence": "SIMULATED", "checks": checks, "failures": failures}
	FileAccess.open("res://artifacts/perf25-regroup-contract02.json", FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF25_REGROUP_CONTRACT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _test_obstacle_fallback() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var grid := LogicGrid.new()
	grid.grid_size = Vector2i(32, 32)
	grid.centrally_symmetric_navigation = true
	for y in range(11): grid.set_blocked(Vector2i(5, y), true)
	world.logic_grid = grid
	world.pathfinder = GridPathfinder.new(grid)
	var routes: Array[PackedVector2Array] = []
	var home := Vector2(800, 80)
	var leader := UnitState.new(9001, Vector2(80, 80), 145, 1)
	LegionHeroSystem._start_return_path(world, leader, home, routes)
	var opposite := UnitState.new(9002, Vector2(208, 80), 145, 1)
	LegionHeroSystem._start_return_path(world, opposite, home, routes)
	check(routes.size() == 2, "blocked local join requires independent route")
	check(opposite.path == world.pathfinder.find_path(opposite.position, home), "wall fallback uses normal solver")
	var remote := UnitState.new(9003, Vector2(80, 800), 145, 1)
	LegionHeroSystem._start_return_path(world, remote, home, routes)
	check(routes.size() == 3, "distant survivor requires independent route")
	var revision := grid.revision
	grid.set_blocked(Vector2i(20, 2), true)
	routes.clear()
	LegionHeroSystem._start_return_path(world, opposite, home, routes)
	check(grid.revision > revision and opposite.path == world.pathfinder.find_path(opposite.position, home), "next recall observes changed obstacles")
	for i in range(1, opposite.path.size()): check(grid.is_segment_walkable(opposite.path[i - 1], opposite.path[i]), "changed obstacle route remains legal")

func _test_subpixel_join() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var grid := LogicGrid.new()
	grid.grid_size = Vector2i(1024, 768)
	grid.centrally_symmetric_navigation = true
	world.logic_grid = grid
	world.pathfinder = GridPathfinder.new(grid)
	var center2 := Vector2(32768, 24576)
	var paths: Array[PackedVector2Array] = []
	for faction in [1, 2]:
		var route := PackedVector2Array([Vector2(100, 100), Vector2(500, 100)])
		var start := Vector2(100.03125, 100.03125)
		if faction == 2:
			start = center2 - start
			for i in range(route.size()): route[i] = center2 - route[i]
		var routes: Array[PackedVector2Array] = [route]
		var unit := UnitState.new(9100 + faction, start, 145, faction)
		LegionHeroSystem._start_return_path(world, unit, route[-1], routes)
		check(unit.path.size() == 3, "subpixel join retains validated turning point")
		for i in range(1, unit.path.size()): check(grid.is_segment_walkable(unit.path[i - 1], unit.path[i]), "subpixel actual segment validated")
		paths.append(unit.path)
	for i in range(3): check(center2 - paths[0][i] == paths[1][i], "subpixel mirror exact")
