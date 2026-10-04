extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); print("FAIL ",message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	test_free_route()
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.advance_tick()
	world.advance_tick()
	for id: StringName in world.commanders:
		var commander := world.commanders[id] as CommanderState
		check(commander.formation_mode == CommanderState.FormationMode.FREE,"default free "+str(id))
		check(not world.legion_formation_system.records[id].active,"no mandatory formation "+str(id))
		for entity_id in commander.growth_slot_entities:
			var unit := world.units.get(entity_id) as UnitState
			if unit != null: check(unit.legion_slot == null,"no automatic slot "+str(entity_id))
	var commander := world.commanders[&"lu_zheng"] as CommanderState
	var original_target := commander.target_position
	var id := commander.definition.definition_id
	var snapshot := world.create_faction_snapshot(1)
	check(LegionDeploymentPreview.project(snapshot,world.logic_grid,[],id,original_target).is_empty(),"free preview has no deployment override")
	var command := LegionFormationCommand.new(world.allocate_command_id(),2,world.current_tick,id,CommanderState.FormationMode.MOVE)
	check(not world.submit_command(command).is_accepted(),"foreign faction rejected")
	command = LegionFormationCommand.new(world.allocate_command_id(),1,world.current_tick,id,CommanderState.FormationMode.MOVE)
	command.issuer_kind = GameCommand.IssuerKind.AGENT; command.agent_id = commander.agent_id
	check(not world.submit_command(command).is_accepted(),"agent cannot enable formation")
	command = LegionFormationCommand.new(world.allocate_command_id(),1,world.current_tick,id,99 as CommanderState.FormationMode)
	check(not world.submit_command(command).is_accepted(),"invalid enum rejected")
	for mode in range(1,5):
		command = LegionFormationCommand.new(world.allocate_command_id(),1,world.current_tick,id,mode as CommanderState.FormationMode)
		check(world.submit_command(command).is_accepted(),"mode accepted "+str(mode))
		command.mode = CommanderState.FormationMode.FREE
		world.advance_tick()
		check(commander.formation_mode == mode,"queued command copied "+str(mode))
		check(commander.target_position == original_target,"configuration retains objective "+str(mode))
		var record := world.legion_formation_system.records[id]
		check(record.active and record.spatial.action == mode-1,"chosen shape stays explicit "+str(mode))
		var occupied := 0
		for entity_id in commander.growth_slot_entities:
			var member := world.units.get(entity_id) as UnitState
			if member != null and member.legion_slot != null: occupied += 1
		check(occupied > 0,"explicit formation has real slots "+str(mode))
	check(snapshot.get_commander(id).formation_mode == CommanderState.FormationMode.FREE,"old snapshot isolated")
	check(world.submit_command(LegionFormationCommand.new(world.allocate_command_id(),1,world.current_tick,id,CommanderState.FormationMode.FREE)).is_accepted(),"exit accepted")
	world.advance_tick()
	check(not world.legion_formation_system.records[id].active,"exit releases formation")
	for entity_id in commander.growth_slot_entities:
		var member := world.units.get(entity_id) as UnitState
		if member != null: check(member.legion_slot == null and member.free_legion_movement,"exit releases member "+str(entity_id))
	check(not commander.deployment_goal.is_finite(),"exit clears deployment wait")
	# Reissuing the same MOVE after displacement must rebuild its completed path.
	var repeated_card := world.unit_cards[commander.subordinate_unit_card_ids[0]] as UnitCardState
	var repeated := world.formations[repeated_card.formation_id] as FormationState
	for entity_id in repeated.member_entity_ids:
		var member := world.units[entity_id] as UnitState
		member.free_march_intent = "completed-command"
		member.free_march_waypoint_index = member.free_march_waypoints.size()
	var again := FormationMoveCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,repeated.leader_entity_id,repeated.formation_id,repeated.target_position)
	world._apply_command(again)
	for entity_id in repeated.member_entity_ids:
		check(world.units[entity_id].free_march_intent.is_empty(),"new MOVE resets completed route cache")
	# A completed MOVE must support an explicit stationary layout.
	for card_id in commander.subordinate_unit_card_ids:
		var formation := world.formations[world.unit_cards[card_id].formation_id] as FormationState
		formation.is_moving = false; formation.order_kind = FormationState.OrderKind.MOVE
	world.legion_formation_system.apply(world,LegionFormationCommand.new(world.allocate_command_id(),1,world.current_tick,id,CommanderState.FormationMode.DEFEND))
	world.legion_formation_system.prepare(world)
	var anchor := world.legion_formation_system.records[id].spatial.anchor
	for step in range(12):
		world.legion_formation_system.prepare(world)
		world._advance_unit(world.units[commander.hero_entity_id])
		world.current_tick += 1
		var spatial := world.legion_formation_system.records[id].spatial
		check(spatial.anchor == anchor and spatial.goal == anchor,"stationary formation anchor does not drift")
	# Explicit layout chooses a moving unstopped card, never a stopped source.
	var moving_card := world.unit_cards[commander.subordinate_unit_card_ids[-1]] as UnitCardState
	moving_card.player_stopped = false
	var moving := world.formations[moving_card.formation_id] as FormationState
	moving.is_moving = true
	check(LegionSpatialExecutor._source(world,commander,world.legion_formation_system.records[id]) == moving,"moving card leads explicit layout")
	for card_id in commander.subordinate_unit_card_ids: world.unit_cards[card_id].player_stopped = true
	world.legion_formation_system.prepare(world)
	check(not world.units[commander.hero_entity_id].has_move_target,"all stopped cards stop formation hero")
	await test_layout(world)
	var report := {"evidence":"SIMULATED","checks":checks,"failures":failures}
	FileAccess.open("res://artifacts/legion63/optional01.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("OPTIONAL_FORMATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func test_layout(world: SimulationWorld) -> void:
	for locale in ["zh_CN","en"]:
		TranslationServer.set_locale(locale)
		for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1600),Vector2i(640,800),Vector2i(480,800)]:
			root.size = resolution
			for tactical in [false,true]:
				var board := ArmyBoard.new()
				var margin := MarginContainer.new(); margin.name = "Margin"; board.add_child(margin)
				var layout := VBoxContainer.new(); layout.name = "Layout"; margin.add_child(layout)
				var header := HBoxContainer.new(); header.name = "Header"; layout.add_child(header)
				var title := Label.new(); title.name = "Title"; header.add_child(title)
				var hint := Label.new(); hint.name = "Hint"; header.add_child(hint)
				var scroll := ScrollContainer.new(); scroll.name = "Scroll"; layout.add_child(scroll)
				var row := HBoxContainer.new(); row.name = "CommanderRow"; scroll.add_child(row)
				root.add_child(board)
				board._tactical_cards = tactical
				board.battlegroup_overview = tactical
				board.size.x = minf(resolution.x,1200)
				var snapshot := world.create_faction_snapshot(1)
				board.update_snapshot(snapshot)
				for frame in range(3): await process_frame
				var heights := {}
				for id in board._commander_buttons:
					heights[id] = board._commander_buttons[id].get_parent().size.y
				for phase in range(4):
					for commander in snapshot.commanders:
						commander.formation_mode = (phase+1) as CommanderState.FormationMode
						commander.hero_respawn_tick = 500 if phase==0 else -1
						commander.legion_regrouping = phase==1
						commander.behavior_reason_key = &"LEGION_MODE_HELP"
						commander.legion_artillery = null if phase==0 else LegionArtilleryState.new()
					board.update_snapshot(snapshot)
					for frame in range(3): await process_frame
					for id in board._commander_buttons:
						check(is_equal_approx(heights[id],board._commander_buttons[id].get_parent().size.y),"stable card height %s %s %s %s" % [locale,resolution,tactical,id])
					for label in board._formation_space_labels.values():
						check(not label.text.contains("LEGION_MODE"),"localized footprint")
				board.free()

func test_free_route() -> void:
	var grid := LogicGrid.new()
	var finder := GridPathfinder.new(grid)
	var mover := FormationMovementSystem.new(grid,finder)
	var unit := UnitState.new(1,Vector2(400,400),135,1)
	unit.following_formation = true; unit.free_legion_movement = true; unit.flexible_legion_movement = true
	unit.legion_motion = LegionMotionConstraint.new(); unit.legion_motion.ground_radius = 32.0
	var units := {1:unit}
	var formation := FormationState.new(1,[1],unit.position)
	formation.order_kind = FormationState.OrderKind.MOVE
	formation.target_position = Vector2(800,1000); formation.order_destination = formation.target_position
	formation.planned_route = PackedVector2Array([Vector2(800,400),formation.target_position])
	formation.path = finder.find_body_path(unit.position,formation.target_position); formation.path_index = 1; formation.is_moving = true
	var events: Array[SimulationEvent] = []
	var changed := false
	var interrupted := false
	for tick in range(160):
		if unit.free_march_waypoint_index >= 1 and not changed:
			grid.set_blocked(Vector2i(40,40),true)
			changed = true
		if changed and unit.position.y>600 and not interrupted:
			unit.legion_slot = LegionSpatialOrder.new()
			mover.advance({1:formation},units,events,tick)
			unit.position.y += 20
			unit.legion_slot = null
			interrupted = true
		var before := unit.position
		mover.advance({1:formation},units,events,tick)
		check(before.distance_to(unit.position)<=13.501,"free march respects speed")
		if changed: check(unit.position.x>=790 and unit.position.y>=before.y-0.001,"replan keeps completed waypoint progress")
	check(changed and interrupted,"route includes grid change and local takeover")
	check(not formation.is_moving and unit.position.distance_to(formation.target_position)<=6.0,"free route completes after interruptions")
