extends "res://tests/tools/combined21_rules.gd"

func _initialize() -> void:
	_test_mixed()
	_test_pause_clock()
	for failure in failures: push_error(failure)
	print("COMBINED21_EDGES failures=",failures)
	quit(0 if failures.is_empty() else 1)

func _test_mixed() -> void:
	var world := fixture(&"UNIT_CARD_ROLE_FIREPOWER")
	var card := find_card(world,&"UNIT_CARD_ROLE_FIREPOWER")
	for commander: CommanderState in world.commanders.values(): commander.subordinate_unit_card_ids.clear()
	var empty := world.units[card.member_entity_ids[0]] as UnitState
	var loaded := world.units[card.member_entity_ids[1]] as UnitState
	empty.ammunition = 0
	var target := enemy(world,ORIGIN+Vector2(200,0))
	var modes: Dictionary = {}
	for tick in range(35):
		world.advance_tick()
		for projectile: ProjectileState in world.projectiles.values(): modes[projectile.source_entity_id] = projectile.weapon_mode
	check(modes.get(empty.entity_id,0) == 2 and modes.get(loaded.entity_id,0) == 1,"same card members select different weapons")
	check(empty.ammunition == 0 and loaded.ammunition < 4,"cannon does not consume missile inventory")
	check(target.health < 10000,"mixed battery inflicts actual damage")

func _test_pause_clock() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.command_queue.drain()
	var request := StaffPlanRequest.new()
	request.objective_region_id = &"blue_mid_high"
	request.coordination = Mode.JOINT_ATTACK
	for card: UnitCardState in world.unit_cards.values():
		if card.commander_definition_id in [&"bai_jiuyang",&"di_tian"]: request.allowed_card_ids.append(card.definition.definition_id)
	var plans := StaffPlanGenerator.new().generate(world.create_faction_snapshot(1),1,request)
	check(plans != null,"pause fixture generates")
	if plans == null: return
	var plan := plans.plans[0]
	world.submit_command(StaffPlanApprovalCommand.new(world.allocate_command_id(),1,world.current_tick,request,plan.profile_id,plan.fingerprint()))
	world.advance_tick()
	world.command_queue.drain()
	for i in range(2):
		var command := UnitCardControlCommand.new(world.allocate_command_id(),1,world.current_tick,request.allowed_card_ids[i],UnitCardControlCommand.Action.TAKEOVER)
		check(world.submit_command(command).is_accepted(),"takeover two participating cards")
	world.advance_tick()
	var before := world.commander_task_graph_system.create_snapshots(1)[0]
	for tick in range(20): world.advance_tick()
	var paused := world.commander_task_graph_system.create_snapshots(1)[0]
	check(paused.coordination_paused_since_tick >= 0 and paused.coordination_paused_ticks == 0,"one graph clock while two cards paused")
	for i in range(2):
		var command := UnitCardControlCommand.new(world.allocate_command_id(),1,world.current_tick,request.allowed_card_ids[i],UnitCardControlCommand.Action.RETURN_TO_COMMANDER)
		check(world.submit_command(command).is_accepted(),"return participating cards")
	for tick in range(50): world.advance_tick()
	var resumed := world.commander_task_graph_system.create_snapshots(1)[0]
	check(resumed.coordination_paused_since_tick == -1,"shared clock resumes")
	check(resumed.coordination_paused_ticks >= 20 and resumed.coordination_paused_ticks <= 30,"pause duration counted once not per node")
	check(before.coordination_paused_ticks == 0,"old graph snapshot remains immutable")
	print("COOP_PAUSE_TICKS ",resumed.coordination_paused_ticks)
