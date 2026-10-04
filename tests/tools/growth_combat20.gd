extends SceneTree

var failures: Array[String] = []
const ORIGIN := Vector2(16384, 12288)

func check(value: bool, label: String) -> void:
	if not value: failures.append(label)

func fixture(role: StringName) -> SimulationWorld:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.agents.clear()
	world.command_queue.drain()
	for unit: UnitState in world.units.values():
		if unit.hero_commander_id.is_empty(): unit.enabled = false
		else: unit.can_attack = false
	for commander: CommanderState in world.commanders.values(): commander.last_growth_order_tick = 100000
	for faction: FactionState in world.factions.values(): faction.supply = 0
	var card := find_card(world, role)
	card.control_state = UnitCardState.ControlState.PLAYER_CONTROLLED
	card.persistent_manual = true
	var formation := world.formations[card.formation_id] as FormationState
	formation.anchor_position = ORIGIN
	formation.target_position = ORIGIN
	formation.order_destination = ORIGIN
	formation.order_kind = FormationState.OrderKind.IDLE
	formation.is_moving = false
	for index in range(card.member_entity_ids.size()):
		var unit := world.units[card.member_entity_ids[index]] as UnitState
		unit.enabled = true
		unit.position = ORIGIN + Vector2(0,index * 16)
		unit.has_move_target = false
		unit.control_state = UnitState.ControlState.PLAYER_CONTROLLED
	world._update_faction_knowledge()
	return world

func find_card(world: SimulationWorld, role: StringName) -> UnitCardState:
	for card: UnitCardState in world.unit_cards.values():
		if card.faction_id == 1 and card.definition.role_key == role: return card
	return null

func enemy(world: SimulationWorld, position: Vector2, id: int = 99999) -> UnitState:
	var unit := UnitState.new(id, position, 0, 2)
	world._apply_unit_definition(unit, SimulationWorld.UNIT_CATALOG.get_unit(&"assault_vehicle"))
	unit.can_attack = false
	unit.max_health = 10000
	unit.health = 10000
	world.units[id] = unit
	world._update_faction_knowledge()
	return unit

func _initialize() -> void:
	_test_recon_and_manual()
	_test_artillery()
	_test_chase()
	_test_orders_and_support()
	_test_recruit_windows()
	for failure in failures: push_error(failure)
	print("GROWTH_COMBAT20 failures=",failures)
	quit(0 if failures.is_empty() else 1)

func _test_recon_and_manual() -> void:
	var world := fixture(&"UNIT_CARD_ROLE_RECON")
	var card := find_card(world, &"UNIT_CARD_ROLE_RECON")
	var formation := world.formations[card.formation_id] as FormationState
	var target := enemy(world, ORIGIN + Vector2(170,0))
	for tick in range(15): world.advance_tick()
	check(target.health < 10000, "uncommanded recon autonomously damages visible enemy")
	var old_leader := formation.leader_entity_id
	world.units[old_leader].enabled = false
	world.advance_tick()
	check(formation.leader_entity_id != old_leader and world.units[formation.leader_entity_id].enabled, "dead formation leader does not stall surviving units")
	var destination := ORIGIN + Vector2(500,300)
	var move := FormationMoveCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,formation.leader_entity_id,formation.formation_id,destination)
	check(world.submit_command(move).is_accepted(), "manual move accepted")
	var focus := AttackCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.AGENT,world.current_tick,formation.leader_entity_id,target.entity_id,formation.formation_id)
	focus.fire_only = true
	focus.agent_id = world.commanders[card.commander_definition_id].agent_id
	check(world.submit_command(focus).is_accepted(), "commander focus permitted during manual control")
	var queued_focus := false
	for queued in world.command_queue.snapshot():
		if queued is AttackCommand and queued.command_id == focus.command_id: queued_focus = queued.fire_only
	check(world.command_queue.snapshot().has(move) and queued_focus, "fire and movement do not supersede each other")
	focus.fire_only = false
	world.advance_tick()
	check(formation.order_kind == FormationState.OrderKind.MOVE, "mutating original command cannot escalate fire into movement")
	focus.fire_only = true
	world.advance_tick()
	check(formation.order_kind == FormationState.OrderKind.MOVE and formation.order_destination == move.target_position and formation.is_moving, "focus retains manual route and movement")
	check(card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED, "focus does not take movement ownership")
	focus.agent_id += 10000
	check(not world.validate_command(focus).is_accepted(), "unrelated agent cannot focus card")
	focus.agent_id = world.commanders[card.commander_definition_id].agent_id
	target.position = Vector2(30000,2000)
	world._update_faction_knowledge()
	check(not world.validate_command(focus).is_accepted(), "focus rejects hidden target")
	world.battle_outcome.result = BattleOutcome.Result.VICTORY
	check(world.validate_command(focus).reason == CommandValidationResult.Reason.BATTLE_CONCLUDED, "focus cannot bypass concluded battle")

func _test_artillery() -> void:
	var world := fixture(&"UNIT_CARD_ROLE_FIREPOWER")
	var card := find_card(world, &"UNIT_CARD_ROLE_FIREPOWER")
	var target := enemy(world,ORIGIN+Vector2(200,0))
	var before := UnitCardSnapshot.new(card,world.units).ammunition
	for tick in range(35): world.advance_tick()
	check(UnitCardSnapshot.new(card,world.units).ammunition < before, "artillery auto fires without active ability or commander")
	check(target.health < 10000, "D-035 missile deals health damage")
	var fires := 0
	for event in world.events:
		if event.kind == SimulationEvent.Kind.PROJECTILE_FIRED and card.member_entity_ids.has(event.entity_id): fires += 1
	check(fires > 0, "artillery emits real projectiles")
	var first := world.units[card.member_entity_ids[0]] as UnitState
	var near := enemy(world, first.position+Vector2(30,0),99998)
	check(not GrowthCombatSystem.valid_target(world,first,near.entity_id), "minimum range respected")
	target.position = Vector2(30000,2000)
	world._update_faction_knowledge()
	check(not GrowthCombatSystem.valid_target(world,first,target.entity_id), "no hidden artillery target")

func _test_chase() -> void:
	var world := fixture(&"UNIT_CARD_ROLE_ASSAULT")
	var card := find_card(world,&"UNIT_CARD_ROLE_ASSAULT")
	var formation := world.formations[card.formation_id] as FormationState
	var target := enemy(world,ORIGIN+Vector2(160,0))
	for id in card.member_entity_ids:
		world.units[id].sight_range = 800
		world.units[id].base_sight_range = 800
	world._update_faction_knowledge()
	world.advance_tick()
	target.position = ORIGIN+Vector2(360,0)
	world._update_faction_knowledge()
	for tick in range(8): world.advance_tick()
	check(formation.anchor_position.distance_to(ORIGIN) > 0, "idle formation briefly pursues departing contact")
	check(formation.anchor_position.distance_to(ORIGIN) <= GrowthCombatSystem.LEASH+32, "pursuit stays within leash")
	target.enabled = false
	world._update_faction_knowledge()
	for tick in range(80): world.advance_tick()
	check(formation.anchor_position.distance_to(ORIGIN)<40 and not formation.local_engagement_active, "formation returns to original guard point")

func _test_orders_and_support() -> void:
	var world := fixture(&"UNIT_CARD_ROLE_RECON")
	var card := find_card(world,&"UNIT_CARD_ROLE_RECON")
	var formation := world.formations[card.formation_id] as FormationState
	var target := enemy(world,ORIGIN+Vector2(160,0))
	target.can_attack = true
	check(not GrowthCombatSystem.has_support(world,formation),"isolated scout has no imaginary support")
	var support := UnitState.new(99990,ORIGIN+Vector2(-120,0),0,1)
	world._apply_unit_definition(support,SimulationWorld.UNIT_CATALOG.get_unit(&"assault_vehicle"))
	world.units[support.entity_id]=support
	check(GrowthCombatSystem.has_support(world,formation),"nearby assault provides scout support")
	card.control_state=UnitCardState.ControlState.AGENT_ASSIGNED
	var commander := world.commanders[card.commander_definition_id] as CommanderState
	formation.local_engagement_active=true
	world._assign_unit_card_task(commander,card,ORIGIN+Vector2(300,0))
	check(not formation.local_engagement_active,"new strategic task cancels old local return")
	formation.local_engagement_resume_kind=FormationState.OrderKind.MOVE
	formation.local_engagement_resume_destination=ORIGIN+Vector2(300,0)
	formation.local_engagement_origin=ORIGIN
	formation.local_engagement_resume_route=PackedVector2Array([ORIGIN-Vector2(100,0),ORIGIN+Vector2(300,0)])
	formation.local_engagement_resume_path=PackedVector2Array([ORIGIN+Vector2(100,0),ORIGIN+Vector2(300,0)])
	GrowthCombatSystem._resume(world,formation)
	check(not formation.path.has(ORIGIN-Vector2(100,0)),"return resumes unconsumed route without revisiting passed waypoint")
	check(formation.is_moving and formation.target_position==formation.order_destination,"resumed route restores target and moving state")
	check(world.units[formation.leader_entity_id].has_move_target,"resumed route prevents moving artillery preparation")
	# A detached diagnostic unit still follows explicit attack commands.
	var unit := world.units[card.member_entity_ids[0]] as UnitState
	unit.following_formation=false
	unit.has_move_target=false
	unit.attack_target_entity_id=target.entity_id
	unit.attack_is_retaliation=false
	unit.sight_range=800
	unit.base_sight_range=800
	target.position=ORIGIN+Vector2(400,0)
	world._update_faction_knowledge()
	GrowthCombatSystem._individual(world,unit)
	check(unit.has_move_target,"independent explicit attack pursues target outside range")
	unit.has_move_target=false
	unit.attack_target_entity_id=0
	unit.attack_is_retaliation=true
	unit.local_engagement_active=false
	target.position=unit.position+Vector2(100,0)
	world._update_faction_knowledge()
	GrowthCombatSystem._individual(world,unit)
	check(unit.local_engagement_active and unit.attack_target_entity_id==target.entity_id,"independent idle unit acquires target")

func _test_recruit_windows() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.command_queue.drain()
	for commander: CommanderState in world.commanders.values(): commander.last_growth_order_tick=100000
	var faction := world.factions[1] as FactionState
	faction.supply=300
	faction.recruitment_reserve=0
	var initial := faction.population
	var previous := initial
	var buckets: Dictionary = {}
	for step in range(31):
		var tick := world.current_tick
		world.advance_tick()
		var delta := faction.population-previous
		buckets[tick/10] = int(buckets.get(tick/10,0))+delta
		previous=faction.population
	for count in buckets.values(): check(count<=5,"at most five actual recruits per fixed second")
	check(previous>initial,"recruitment test actually spawns recruits")
	print("RECRUIT_WINDOWS ",buckets)
	world = SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.command_queue.drain()
	faction=world.factions[1]
	faction.supply=300
	faction.recruitment_reserve=0
	var cards: Array[UnitCardState]=[]
	var seen: Array[StringName]=[]
	for card: UnitCardState in world.unit_cards.values():
		if card.faction_id==1 and not seen.has(card.commander_definition_id):
			cards.append(card)
			seen.append(card.commander_definition_id)
	var start:=faction.population
	for tick in [9,10]:
		world.current_tick=tick
		for card in cards:
			var count:=2 if card.commander_definition_id==faction.priority_commander_id else 1
			var command:=RecruitUnitCardCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,tick,card.definition.definition_id,count)
			check(world.validate_command(command).is_accepted(),"boundary recruit valid")
			world._apply_command(command)
		var sixth:=RecruitUnitCardCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,tick,cards[0].definition.definition_id,1)
		check(not world.validate_command(sixth).is_accepted(),"sixth recruit rejected inside same fixed second")
	check(faction.population==start+10,"adjacent fixed seconds each admit five, not sliding-window semantics")
	print("RECRUIT_BOUNDARY ticks=9,10 actual_new=",faction.population-start)
