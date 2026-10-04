extends "res://tests/tools/growth_combat20.gd"

const Mode := StaffPlanRequest.Coordination
const Phase := CommanderTaskStageDefinition.Phase
const Life := CommanderTaskNodeSnapshot.Lifecycle

func _initialize() -> void:
	_test_stats()
	_test_weapons()
	_test_cooperation()
	_test_recruit_stats()
	_test_empty_approach()
	_test_route_projection()
	for failure in failures: push_error(failure)
	print("COMBINED21_RULES failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _test_stats() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	check(world.battle_definition.validate(SimulationWorld.UNIT_CATALOG).is_valid(), "new typed content valid")
	for card: UnitCardState in world.unit_cards.values():
		for id in card.member_entity_ids:
			var unit := world.units[id] as UnitState
			if card.definition.role_key == &"UNIT_CARD_ROLE_ASSAULT": check(unit.max_health == 300 and unit.health == 300, "both assault factions 300 HP")
			if card.definition.role_key == &"UNIT_CARD_ROLE_ARMOR": check(unit.max_health == 400 and unit.base_armor == 25 and card.definition.recruitment_cost == 5, "both armor factions 400 HP 25 armor cost 5")
	var card := find_card(world, &"UNIT_CARD_ROLE_ARMOR")
	var veteran := world.units[card.member_entity_ids[0]] as UnitState
	veteran.health = 213
	world._bind_unit_card_members(card)
	check(veteran.health == 213 and veteran.max_health == 400 and veteran.base_armor == 25, "rebind preserves old wounds and armor")
	var old := SimulationWorld.UNIT_CATALOG.get_unit(&"assault_vehicle")
	check(old.combat.max_health == 180 and old.combat.armor == 10, "legacy global unit unchanged")
	var request := StaffPlanRequest.new()
	request.objective_region_id = &"blue_top_outer"
	request.coordination = Mode.JOINT_ATTACK
	request.formation = StaffPlanRequest.Formation.WEDGE
	var copy := request.duplicate_value()
	request.formation = StaffPlanRequest.Formation.LINE
	check(copy.formation == StaffPlanRequest.Formation.WEDGE, "request values copied")

func _test_weapons() -> void:
	var traces: Array[String] = []
	for repeat in range(2):
		var world := fixture(&"UNIT_CARD_ROLE_FIREPOWER")
		var card := find_card(world, &"UNIT_CARD_ROLE_FIREPOWER")
		for commander: CommanderState in world.commanders.values(): commander.subordinate_unit_card_ids.clear()
		var target := enemy(world, ORIGIN + Vector2(200, 0))
		var unit := world.units[card.member_entity_ids[0]] as UnitState
		var old_snapshot := world.create_faction_snapshot(1)
		var shot_values: Array[float] = []
		var seen: Array[int] = []
		var modes: Array[int] = []
		for tick in range(115):
			world.advance_tick()
			for projectile: ProjectileState in world.projectiles.values():
				if seen.has(projectile.projectile_id): continue
				seen.append(projectile.projectile_id)
				modes.append(projectile.weapon_mode)
				if projectile.weapon_mode == 1:
					check(projectile.damage_multiplier >= .5 and projectile.damage_multiplier <= 2, "missile multiplier in bounds")
					check(is_equal_approx(projectile.attack_power, 70 * projectile.damage_multiplier), "missile rolls before armor")
					shot_values.append(projectile.attack_power)
				elif projectile.weapon_mode == 2: check(projectile.attack_power == 40, "cannon actual damage 40")
		check(target.health < 10000, "missiles inflict health damage")
		check(modes.has(1) and modes.has(2), "real missile then fallback projectile")
		check(unit.using_fallback_weapon and unit.ammunition == 0 and unit.attack_range == 300 and unit.minimum_attack_range == 0 and not unit.identification_required, "empty missile switches all effective constraints")
		check(not old_snapshot.get_unit(unit.entity_id).using_fallback_weapon, "snapshot remains primary")
		unit.health = 82
		world._bind_unit_card_members(card)
		check(unit.health == 82 and unit.ammunition == 0, "rebind does not heal or reload")
		unit.ammunition = 1
		world._update_grey_ridge_terrain_effects()
		check(not unit.using_fallback_weapon and unit.minimum_attack_range == 140 and unit.weapon_preparation_ticks == 20, "reload restores missile constraints")
		check(unit.attack_range >= 420, "reload restores long range")
		traces.append(str(shot_values))
	check(traces[0] == traces[1], "deterministic damage sequence")
	print("COMBINED21_DAMAGE ", traces[0])

func _test_cooperation() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var request := StaffPlanRequest.new()
	request.objective_region_id = &"blue_mid_outer"
	request.coordination = Mode.JOINT_ATTACK
	request.formation = StaffPlanRequest.Formation.WEDGE
	for card: UnitCardState in world.unit_cards.values():
		if card.commander_definition_id in [&"bai_jiuyang", &"di_tian"]: request.allowed_card_ids.append(card.definition.definition_id)
	var generator := StaffPlanGenerator.new()
	var plans := generator.generate(world.create_faction_snapshot(1), 1, request)
	check(plans != null, "joint plan generated: %s" % generator.last_rejection_reason)
	if plans == null: return
	var plan := plans.plans[0]
	check(plan.assignments.size() == 8, "joint alternatives retain every selected legion")
	var approval := StaffPlanApprovalCommand.new(world.allocate_command_id(), 1, world.current_tick, request, plan.profile_id, plan.fingerprint())
	check(world.submit_command(approval).is_accepted(), "joint approval shared pipeline")
	world.advance_tick()
	var graphs := world.commander_task_graph_system.create_snapshots(1)
	check(graphs.size() == 1, "approved operation installed")
	if graphs.is_empty(): return
	var graph := graphs[0]
	var engage: CommanderTaskNodeSnapshot
	var slots: Array[Vector2] = []
	var shared_deadlines: Array[int] = []
	for node in graph.nodes:
		if node.phase == Phase.ENGAGE:
			check(node.prerequisite_ids.size() == 8, "all eight deployments gate every engagement")
			shared_deadlines.append(node.timeout_ticks)
			engage = node
			if not slots.has(node.target_position): slots.append(node.target_position)
		if node.phase == Phase.DEPLOY: node.lifecycle = Life.COMPLETED
	check(shared_deadlines.min() == shared_deadlines.max(), "all legions share longest staging budget")
	check(slots.size() >= 4, "actual differentiated formation positions")
	var snapshot := world.create_faction_snapshot(1)
	var agent := CommanderTaskGraphAgent.new()
	check(agent.expected_action(snapshot, graph, engage) == CommanderCardTaskCommand.Action.START, "all ready allows attack")
	var foreign_deploy: CommanderTaskNodeSnapshot
	for node in graph.nodes:
		if node.phase == Phase.DEPLOY and node.commander_id != engage.commander_id:
			foreign_deploy = node
			break
	foreign_deploy.lifecycle = Life.WAITING
	check(agent.expected_action(snapshot, graph, engage) == -1, "other legion late blocks attack")
	foreign_deploy.lifecycle = Life.CANCELLED
	check(agent.expected_action(snapshot, graph, engage) == CommanderCardTaskCommand.Action.CANCEL, "withdrawn participant cancels assault")
	foreign_deploy.lifecycle = Life.COMPLETED
	snapshot.get_unit_card(foreign_deploy.card_id).control_state = UnitCardState.ControlState.PLAYER_CONTROLLED
	check(agent.expected_action(snapshot, graph, engage) == -1, "manual other legion cannot silently count ready")
	for node in graph.nodes:
		if node.phase == Phase.ENGAGE: node.lifecycle = Life.ACTIVE
	check(CoalitionTactics.shared_cards(graph, &"di_tian").size() == 8, "cross commander support pool")
	graph.retreat_requested = true
	check(CoalitionTactics.shared_cards(graph, &"di_tian").is_empty(), "retreat cuts cooperation fire pool")
	var bad := request.duplicate_value()
	bad.allowed_card_ids = [request.allowed_card_ids[0]]
	check(generator.generate(world.create_faction_snapshot(1),1,bad) == null, "incomplete coalition rejected")
	var defense_world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var region := defense_world.strategic_regions[request.objective_region_id] as StrategicRegionState
	region.controller_faction_id = 1
	request.coordination = Mode.MUTUAL_SUPPORT
	var defense := generator.generate(defense_world.create_faction_snapshot(1),1,request)
	check(defense != null, "friendly point support generates")
	request.objective_region_id = &"red_mid_outer"
	check(generator.generate(defense_world.create_faction_snapshot(1),1,request) == null, "mutual defense rejects nonfriendly point")

func _test_route_projection() -> void:
	var route := PackedVector2Array([Vector2.ZERO, Vector2(10000,0)])
	var prefix := CoalitionTactics.projected_prefix(route, Vector2(9360,100))
	check(prefix[-1] == Vector2(9360,0) and not prefix.has(route[-1]), "staging never traverses objective first")
	var bent := PackedVector2Array([Vector2.ZERO,Vector2(0,1000),Vector2(1000,1000)])
	prefix = CoalitionTactics.projected_prefix(bent,Vector2(800,1100))
	check(prefix.has(Vector2(0,1000)) and prefix[-1] == Vector2(800,1000), "ordered detour waypoint preserved")
	var loop := PackedVector2Array([Vector2.ZERO,Vector2(9360,0),Vector2(12000,1000),Vector2(10000,0)])
	prefix = CoalitionTactics.projected_prefix(loop,Vector2(9360,0),2)
	check(prefix.has(Vector2(12000,1000)), "mandatory later waypoint survives early near-objective segment")
	prefix = CoalitionTactics.projected_prefix(loop,Vector2(9360,0),loop.size()-1)
	check(prefix == loop,"zero length last leg preserves all mandatory waypoints")

func _test_recruit_stats() -> void:
	for role in [&"UNIT_CARD_ROLE_ASSAULT", &"UNIT_CARD_ROLE_ARMOR", &"UNIT_CARD_ROLE_FIREPOWER"]:
		var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
		world.current_tick = 1
		world.command_queue.drain()
		world.agents.clear()
		for commander: CommanderState in world.commanders.values(): commander.last_growth_order_tick = 100000
		var faction := world.factions[1] as FactionState
		faction.supply = 300
		faction.recruitment_reserve = 0
		var card := find_card(world,role)
		var veteran := world.units[card.member_entity_ids[0]] as UnitState
		veteran.health = 82
		if role == &"UNIT_CARD_ROLE_FIREPOWER": veteran.ammunition = 1
		var before := card.member_entity_ids.duplicate()
		var command := RecruitUnitCardCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,card.definition.definition_id,1)
		check(world.submit_command(command).is_accepted(), "real recruitment accepts " + str(role))
		world.advance_tick()
		var expected_hp := 400 if role == &"UNIT_CARD_ROLE_ARMOR" else (300 if role == &"UNIT_CARD_ROLE_ASSAULT" else 130)
		check(card.member_entity_ids.size() == before.size()+1, "one new member")
		check(faction.supply == 300-card.definition.recruitment_cost, "real recruitment cost")
		for id in card.member_entity_ids:
			if not before.has(id):
				var recruit := world.units[id] as UnitState
				check(recruit.max_health == expected_hp and recruit.health == expected_hp, "recruit receives configured health")
				if role == &"UNIT_CARD_ROLE_ARMOR": check(recruit.base_armor == 25, "recruit receives armor25")
		check(veteran.health == 82, "actual recruit preserves veteran wounds")
		if role == &"UNIT_CARD_ROLE_FIREPOWER": check(veteran.ammunition == 1, "actual recruit preserves veteran ammo")
		# Entire card lost, rebuilt through the same validated recruit command.
		for id in card.member_entity_ids: world.units[id].enabled = false
		world.current_tick = 10
		world.command_queue.drain()
		command = RecruitUnitCardCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,card.definition.definition_id,1)
		check(world.submit_command(command).is_accepted(), "destroyed card rebuild accepts")
		world.advance_tick()
		var active := UnitCardSnapshot.new(card,world.units)
		check(active.current_strength >= 1, "destroyed card rebuilt")
		for id in active.active_member_entity_ids: check(world.units[id].max_health == expected_hp, "rebuilt HP correct")

func _test_empty_approach() -> void:
	var world := fixture(&"UNIT_CARD_ROLE_FIREPOWER")
	var card := find_card(world,&"UNIT_CARD_ROLE_FIREPOWER")
	var formation := world.formations[card.formation_id] as FormationState
	var target := enemy(world,ORIGIN+Vector2(360,0))
	var observer := enemy(world,ORIGIN+Vector2(210,40),99997)
	observer.faction_id = 1
	world._update_faction_knowledge()
	for commander: CommanderState in world.commanders.values(): commander.subordinate_unit_card_ids.clear()
	for id in card.member_entity_ids: world.units[id].ammunition = 0
	world._update_grey_ridge_terrain_effects()
	var order := AttackCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,formation.leader_entity_id,target.entity_id,formation.formation_id)
	check(world.submit_command(order).is_accepted(), "empty battery full-card attack valid")
	for tick in range(65): world.advance_tick()
	check(formation.anchor_position.distance_to(ORIGIN) > 10, "empty battery closes from360")
	check(target.health < 10000, "empty battery closes and cannon damages")
