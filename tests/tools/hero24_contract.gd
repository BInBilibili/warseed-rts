extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	check(world.units.size() == 130 and world.commanders.size() == 10, "ten additional heroes")
	check(world.factions[1].population == 60 and world.factions[2].population == 60, "heroes do not consume soldier population")
	var stable_ids := world.commanders.keys()
	stable_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var stable_heroes := true
	for i in range(stable_ids.size()):
		stable_heroes = stable_heroes and world.commanders[stable_ids[i]].hero_entity_id == world.battle_definition.next_dynamic_unit_id + i
	check(stable_heroes, "hero allocation follows lexical stable IDs, not StringName intern order")
	for commander: CommanderState in world.commanders.values():
		var hero := world.units.get(commander.hero_entity_id) as UnitState
		check(hero != null and hero.max_health == 600 and hero.armor == 20 and hero.move_speed == 145 and hero.attack_damage == 30 and hero.attack_range == 190 and hero.attack_cooldown_ticks == 6 and hero.projectile_speed == 600, "exact hero stats " + str(commander.definition.definition_id))
		check(hero != null and world.logic_grid.is_world_position_walkable(hero.position), "hero spawn walkable")
	for card: UnitCardState in world.unit_cards.values():
		if card.definition.role_key == &"UNIT_CARD_ROLE_ARMOR": check(card.definition.combat_override.armor == 15, "armor fifteen")
	check(LegionHeroSystem.respawn_delay(5999) == 100 and LegionHeroSystem.respawn_delay(6000) == 200 and LegionHeroSystem.respawn_delay(11999) == 200 and LegionHeroSystem.respawn_delay(12000) == 300, "respawn boundaries")
	var commander := world.commanders[&"mobile_legion"] as CommanderState
	var hero := world.units[commander.hero_entity_id] as UnitState
	var before := world.create_faction_snapshot(1)
	var markers := MinimapMarkerProjector.new().project(before, [])
	var anchored := false
	for marker in markers:
		if marker.label == "LEGION_ICON_MOBILE" and marker.faction_id == 1: anchored = marker.position == hero.position
	check(anchored and markers.size() == 5, "friendly hero anchor and hidden enemy exclusion")
	var host := SimulationHost.new()
	host.world = world
	var target := world.strategic_regions[&"blue_mid_high"] as StrategicRegionState
	commander.posture = CommanderState.Posture.HOLD
	var move := host.create_commander_objective_command(commander.definition.definition_id, target.position)
	check(world.submit_command(move).is_accepted(), "held mobile accepts explicit order")
	world.advance_tick()
	check(commander.posture == CommanderState.Posture.BALANCED and commander.target_position == target.position, "held mobile executes new objective")
	commander.posture = CommanderState.Posture.DISENGAGE
	move = host.create_commander_objective_command(commander.definition.definition_id, target.position)
	check(world.submit_command(move).is_accepted(), "disengaged mobile accepts explicit order")
	world.advance_tick()
	check(commander.posture == CommanderState.Posture.BALANCED, "disengaged mobile restored")
	var expected_survivors := 0
	for id in commander.subordinate_unit_card_ids: expected_survivors += UnitCardSnapshot.new(world.unit_cards[id],world.units).current_strength
	for id in commander.subordinate_unit_card_ids: world.unit_cards[id].temporary_micro = true
	var queued := host.create_commander_objective_command(commander.definition.definition_id, target.position)
	world.submit_command(queued)
	hero.health = 0
	hero.enabled = false
	hero.death_tick = world.current_tick
	var death_tick := world.current_tick
	world.advance_tick()
	check(commander.legion_regrouping and commander.hero_respawn_tick == death_tick + 100, "death immediately recalls and starts timer")
	check(not world.submit_command(host.create_commander_objective_command(commander.definition.definition_id, target.position)).is_accepted(), "player command locked during recall")
	check(before.get_unit(hero.entity_id).enabled and not before.get_commander(commander.definition.definition_id).legion_regrouping, "old snapshot immutable")
	var returning := 0
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		check(card.assigned_task_id == 0 and not card.temporary_micro and card.control_state == UnitCardState.ControlState.RETURNING, "old task/control cancelled")
		for id in card.member_entity_ids:
			var unit := world.units[id] as UnitState
			if unit.enabled:
				returning += 1
				check(unit.legion_returning and not unit.following_formation and unit.attack_target_entity_id == 0 and not unit.path.is_empty(), "survivor has recall path")
	check(returning == expected_survivors, "all survivors recalled")
	var first_card := world.unit_cards[commander.subordinate_unit_card_ids[0]] as UnitCardState
	var halt := StopCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,0,first_card.formation_id)
	check(not world.submit_command(halt).is_accepted(), "formation-only stop cannot interrupt recall")
	var foreign := CommanderOrderCommand.new(world.allocate_command_id(),2,world.current_tick,commander.definition.definition_id,CommanderOrderCommand.OrderKind.SET_POSTURE)
	check(world.validate_command(foreign).reason == CommandValidationResult.Reason.NOT_CONTROLLER, "foreign issuer cannot probe hidden regroup state")
	var bypass := StrategicOrderCommand.new(world.allocate_command_id(),1,world.current_tick,StrategicOrderCommand.OrderKind.DEFEND_AREA,0,0,target.position,100)
	bypass.participant_entity_ids.assign(first_card.member_entity_ids)
	check(not world.submit_command(bypass).is_accepted(), "strategic participants cannot steal recalled soldiers")
	var tactical := TacticalAbilityCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,first_card.definition.definition_id,target.position,world.commanders[&"red_di_tian"].hero_entity_id)
	check(LegionHeroSystem.command_blocked(world,tactical), "tactical hostile target does not bypass source legion lock")
	var normal_card := world.unit_cards[(world.commanders[&"di_tian"] as CommanderState).subordinate_unit_card_ids[0]] as UnitCardState
	tactical.unit_card_id = normal_card.definition.definition_id
	check(not LegionHeroSystem.command_blocked(world,tactical), "hostile target does not leak regroup state")

	# Use the actual movement implementation, accelerated without evaluating unrelated armies.
	for tick in range(600):
		world.current_tick += 1
		for unit: UnitState in world.units.values():
			if unit.legion_returning: world._advance_unit(unit)
		LegionHeroSystem.advance(world)
		if not commander.legion_regrouping: break
	check(not commander.legion_regrouping and commander.hero_entity_id != hero.entity_id, "new hero ID and completed recall release legion")
	check(world.units[commander.hero_entity_id].health == 600, "respawn full health")
	check(world.submit_command(host.create_commander_objective_command(commander.definition.definition_id, target.position)).is_accepted(), "legion controllable after regroup")
	# Kill via real area damage as well as the direct fixture above.
	var alive := world.units[commander.hero_entity_id] as UnitState
	alive.health = 1
	var effect := AreaSupportEffect.new()
	effect.position = alive.position
	effect.radius = 80
	effect.faction_id = 2
	effect.support_kind = SupportOrderCommand.SupportKind.MISSILE_BARRAGE
	world.area_support_system._bombard(world, effect, 180.0)
	LegionHeroSystem.advance(world)
	check(commander.legion_regrouping, "missile death also recalls")
	_test_combat()
	_test_tactics(world)
	_test_capture_and_slots(world)
	var report := {"evidence":"SIMULATED", "checks":checks,"failures":failures}
	FileAccess.open("res://artifacts/hero24-contract.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("HERO24_CONTRACT ",JSON.stringify(report))
	host.free()
	quit(0 if failures.is_empty() else 1)

func _test_combat() -> void:
	var hero := UnitState.new(1,Vector2.ZERO,145,1)
	hero.attack_damage = 30
	hero.attack_range = 190
	hero.attack_cooldown_ticks = 6
	hero.projectile_speed = 600
	hero.attack_target_entity_id = 2
	var target := UnitState.new(2,Vector2(100,0),0,2)
	target.health = 1000
	target.max_health = 1000
	var units := {1:hero,2:target}
	var projectiles := {}
	var events: Array[SimulationEvent] = []
	var next := 1
	var combat := CombatSystem.new()
	for tick in range(13): next = combat.advance(units,{},projectiles,next,events,tick)
	var fired: Array[int] = []
	for event in events:
		if event.kind == SimulationEvent.Kind.PROJECTILE_FIRED and event.entity_id == 1: fired.append(event.tick)
	check(fired == [0,6,12] and target.health < 1000, "actual fire cadence and projectile damage")
	hero.legion_returning = true
	for tick in range(13,25): next = combat.advance(units,{},projectiles,next,events,tick)
	check(next == 4, "returning units cannot fire")

func _test_tactics(world: SimulationWorld) -> void:
	var snapshot := world.create_commander_task_snapshot(1)
	var commander := snapshot.get_commander(&"di_tian")
	snapshot.commanders.assign([commander])
	snapshot.tick = 1000
	commander.last_growth_order_tick = 0
	commander.autonomous_growth = true
	commander.growth_recovering = false
	commander.posture = CommanderState.Posture.BALANCED
	var point := snapshot.get_strategic_region(&"blue_mid_high")
	point.controller_faction_id = 1
	point.contested = false
	for card in snapshot.unit_cards:
		if commander.subordinate_unit_card_ids.has(card.definition_id):
			card.center_position = point.position
			card.control_state = UnitCardState.ControlState.AGENT_ASSIGNED
			card.is_player_overridden = false
			card.organization = 100
	var hostile := UnitSnapshot.new(UnitState.new(999999,point.position + Vector2(1000,0),0,2))
	hostile.is_visible_to_local_player = true
	snapshot.units.assign([hostile])
	commander.target_region_id = &"blue_mid_outer"
	var agent := GrowthCommanderAgent.new()
	var first := agent.propose(snapshot,world.battle_definition)
	check(first.size() == 1 and first[0].action == GrowthCommanderCommand.Action.DEFEND_SUPPLY, "visible sustained threat triggers defense")
	commander.target_region_id = point.region_id
	commander.target_position = point.position
	check(agent.propose(snapshot,world.battle_definition).is_empty(), "sustained threat does not alternate into advance")
	# A locally supported legion must not evaluate the same coalition battle as 1vN.
	for friendly in snapshot.unit_cards:
		if not commander.subordinate_unit_card_ids.has(friendly.definition_id):
			friendly.center_position = point.position
			friendly.organization = 100
			friendly.current_strength = 15
			friendly.control_state = UnitCardState.ControlState.AGENT_ASSIGNED
	for i in range(30):
		var enemy := UnitSnapshot.new(UnitState.new(999000+i,point.position+Vector2(1000,i),0,2))
		enemy.is_visible_to_local_player = true
		snapshot.units.append(enemy)
	var supported := agent.propose(snapshot,world.battle_definition)
	check(supported.is_empty() or supported[0].action != GrowthCommanderCommand.Action.RECOVER, "nearby friendly legions count as support")
	snapshot.units.clear()
	for card in snapshot.unit_cards:
		if commander.subordinate_unit_card_ids.has(card.definition_id):
			card.organization = 0 if card.role_key in [&"UNIT_CARD_ROLE_ASSAULT", &"UNIT_CARD_ROLE_ARMOR"] else 100
	var broken_front := agent.propose(snapshot,world.battle_definition)
	check(broken_front.size() == 1 and broken_front[0].action == GrowthCommanderCommand.Action.RECOVER, "healthy rear squads do not hide a broken frontline")
	for card in snapshot.unit_cards:
		if commander.subordinate_unit_card_ids.has(card.definition_id): card.organization = 20
	var recover := agent.propose(snapshot,world.battle_definition)
	check(recover.size() == 1 and recover[0].action == GrowthCommanderCommand.Action.RECOVER, "depleted army already at supply still rests")
	commander.growth_recovering = true
	commander.recovery_started_tick = 950
	commander.recovery_strength = 12
	for card in snapshot.unit_cards:
		if commander.subordinate_unit_card_ids.has(card.definition_id): card.organization = 100
	check(agent.propose(snapshot,world.battle_definition).is_empty(), "minimum recovery commitment")
	commander.recovery_started_tick = 0
	for card in snapshot.unit_cards:
		if commander.subordinate_unit_card_ids.has(card.definition_id) and card.role_key in [&"UNIT_CARD_ROLE_ASSAULT", &"UNIT_CARD_ROLE_ARMOR"]: card.organization = 0
	var broken_resume := agent.propose(snapshot,world.battle_definition)
	check(broken_resume.is_empty() or broken_resume[0].action != GrowthCommanderCommand.Action.RESUME, "broken frontline cannot resume behind healthy rear squads")
	for card in snapshot.unit_cards:
		if commander.subordinate_unit_card_ids.has(card.definition_id): card.organization = 100
	var restored := agent.propose(snapshot,world.battle_definition)
	check(restored.size() == 1 and restored[0].action == GrowthCommanderCommand.Action.RESUME, "restored frontline at safe supply resumes")
	point.controller_faction_id = 2
	commander.recovery_started_tick = 0
	var lost := agent.propose(snapshot,world.battle_definition)
	check(lost.is_empty() or lost[0].action != GrowthCommanderCommand.Action.RESUME, "lost recovery point cannot resume attack")


func _test_capture_and_slots(world: SimulationWorld) -> void:
	var commander := world.commanders[&"lin_mo"] as CommanderState
	var hero := world.units[commander.hero_entity_id] as UnitState
	var region := world.strategic_regions[&"blue_bottom_outer"] as StrategicRegionState
	for unit: UnitState in world.units.values():
		if unit.entity_id != hero.entity_id: unit.enabled = false
	hero.position = region.position
	region.controller_faction_id = 0
	region.capture_progress_ticks = 0
	for i in range(region.capture_required_ticks): world._advance_strategic_regions()
	check(region.controller_faction_id == 1, "hero alone captures supply")
	commander.posture = CommanderState.Posture.HOLD
	hero.has_move_target = true
	LegionHeroSystem._follow(world,commander,hero)
	check(not hero.has_move_target and UnitSnapshot.new(hero).deployment_progress == 1.0, "hero can deploy in place")
	var members: Array[int] = [1,2,3,4]
	var formation := FormationState.new(999999,members,region.position)
	formation.strict_deployment_slots = true
	var desired := formation.anchor_position + formation.get_wide_offset(0)
	var blocked := world.logic_grid.world_to_cell(desired)
	world.logic_grid.set_blocked(blocked,true)
	var slots := world.formation_movement._create_desired_positions(formation,Vector2.RIGHT)
	check(world.logic_grid.is_world_position_walkable(slots[1]), "blocked riverbank slot resolves to walkable cell")
	world.logic_grid.set_blocked(blocked,false)
