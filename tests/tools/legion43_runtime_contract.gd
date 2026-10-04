extends SceneTree

var checks := 0
var failures: Array[String] = []
var output := "res://artifacts/legion43/runtime02.json"

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value and not failures.has(reason): failures.append(reason)

func fresh() -> SimulationWorld:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.advance_tick()
	return world

func fingerprint(state: LegionFormationState) -> String:
	return str([state.reason,state.state.escort_id,state.state.facing,state.state.retreat_direction,state.target,state.core_speed,state.batch_plan.total_available if state.batch_plan != null else -1])

func control_and_snapshots() -> void:
	var world := fresh()
	var commander := world.commanders[&"bai_jiuyang"] as CommanderState
	var hero := world.units[commander.hero_entity_id] as UnitState
	var old := world.create_faction_snapshot(1)
	var record := old.get_commander(&"bai_jiuyang").legion_formation
	check(record != null and record.active and record.batch_plan.valid,"real own snapshot exposes active typed formation plan")
	var before := fingerprint(record)
	var second := world.create_faction_snapshot(1).get_commander(&"bai_jiuyang").legion_formation
	second.state.escort_id=-99; second.batch_plan.members[0].entity_id=-99
	second.batch_plan.batches[0].identities[0]=-99
	check(fingerprint(record)==before,"old snapshot not mutated by another view")
	check(world.legion_formation_system.records[&"bai_jiuyang"].batch_plan.members[0].entity_id>0,"nested snapshot does not alias authority")
	var enemy_view := world.create_faction_snapshot(2)
	check(enemy_view.get_commander(&"bai_jiuyang")==null,"opponent cannot read private formation record")
	for item in enemy_view.commanders: check(item.faction_id==2,"all enemy-side commander projections are private to their faction")
	var card: UnitCardState
	for id in commander.subordinate_unit_card_ids:
		var candidate := world.unit_cards[id] as UnitCardState
		if candidate.definition.role_key==&"UNIT_CARD_ROLE_ASSAULT": card=candidate; break
	var takeover := UnitCardControlCommand.new(world.allocate_command_id(),1,world.current_tick,card.definition.definition_id,UnitCardControlCommand.Action.TAKEOVER)
	check(world.submit_command(takeover).is_accepted(),"real takeover admitted")
	world.advance_tick()
	check(card.control_state==UnitCardState.ControlState.PLAYER_OVERRIDDEN,"takeover applied before formation coordination")
	check(not card.member_entity_ids.has(world.legion_formation_system.records[&"bai_jiuyang"].state.escort_id),"manual card cannot supply escort")
	var formation := world.formations[card.formation_id] as FormationState
	check(formation.anchor_speed_limit==FormationMovementSystem.ANCHOR_MOVE_SPEED,"manual card not capped by autonomous group")
	var stop := StopCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,card.member_entity_ids[0],card.formation_id)
	check(world.submit_command(stop).is_accepted(),"whole-card stop admitted")
	world.advance_tick()
	var positions := {}
	for id in card.member_entity_ids: positions[id]=world.units[id].position
	world.legion_formation_system.prepare(world); world.legion_formation_system.advance_heroes(world)
	for id in card.member_entity_ids: check(world.units[id].position==positions[id],"coordinator never moves stopped card")
	check(not formation.is_moving,"coordinator never resurrects stop order")
	var handback := UnitCardControlCommand.new(world.allocate_command_id(),1,world.current_tick,card.definition.definition_id,UnitCardControlCommand.Action.RETURN_TO_COMMANDER)
	check(world.submit_command(handback).is_accepted(),"handback uses common command validation")
	world.advance_tick()
	check(card.control_state != UnitCardState.ControlState.PLAYER_OVERRIDDEN,"handback applied")
	check(fingerprint(record)==before,"world ticks never mutate old formation snapshot")
	var hold := CommanderOrderCommand.new(world.allocate_command_id(),1,world.current_tick,&"bai_jiuyang",CommanderOrderCommand.OrderKind.SET_POSTURE,Vector2.ZERO,&"",CommanderState.Posture.HOLD)
	check(world.submit_command(hold).is_accepted(),"commander hold admitted")
	world.advance_tick()
	check(not hero.has_move_target and world.legion_formation_system.records[&"bai_jiuyang"].reason==&"COMMAND_HOLD","latest commander hold prevents hero follow")

func knowledge_and_lifecycle() -> void:
	var world := fresh()
	var commander := world.commanders[&"lin_mo"] as CommanderState
	var system := world.legion_formation_system
	var original := fingerprint(system.snapshot(&"lin_mo"))
	# Same legal knowledge, radically different hidden true-state positions and
	# weapons. The coordinator may not inspect these unlisted hostiles.
	var knowledge := world.faction_knowledge[1] as FactionKnowledge
	var contaminated := 0
	for unit: UnitState in world.units.values():
		if unit.faction_id!=2 or knowledge.visible_hostile_unit_ids.has(unit.entity_id): continue
		unit.position=world.units[commander.hero_entity_id].position+Vector2(4,4)
		unit.attack_range=10000; unit.attack_damage=10000; unit.can_attack=true
		contaminated+=1
	system.prepare(world); system.advance_heroes(world)
	check(contaminated>0 and fingerprint(system.snapshot(&"lin_mo"))==original,"hidden true-state pollution cannot alter formation decision")
	var old_hero := world.units[commander.hero_entity_id] as UnitState
	old_hero.enabled=false; old_hero.health=0
	LegionHeroSystem.advance(world)
	check(commander.legion_regrouping,"existing death lifecycle starts recall")
	system.prepare(world)
	var returning_path := old_hero.path.duplicate()
	system.advance_heroes(world)
	check(system.snapshot(&"lin_mo").reason==&"REGROUPING" and system.snapshot(&"lin_mo").batch_plan==null,"death clears stale protection batch epoch")
	check(old_hero.path==returning_path,"coordinator cannot replace death/return path")
	var expected_hero_id := old_hero.entity_id
	world.current_tick=commander.hero_respawn_tick
	LegionHeroSystem.advance(world)
	check(commander.hero_entity_id!=expected_hero_id and world.units[commander.hero_entity_id].enabled,"formal respawn remains enabled")
	# Bring the controlled lifecycle fixture home; do not mistake this for a
	# physical return journey test or a naturally completed whole match.
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		for id in card.member_entity_ids:
			if world.units[id].enabled: world.units[id].position=commander.target_position
	LegionHeroSystem.advance(world)
	system.prepare(world); system.advance_heroes(world)
	check(not commander.legion_regrouping,"existing home arrival releases recovery lock")
	check(system.snapshot(&"lin_mo").batch_plan.members[60].entity_id==commander.hero_entity_id,"new plan binds revived hero and never resurrects dead identity")
	for member in system.snapshot(&"lin_mo").batch_plan.members:
		check(member.entity_id!=expected_hero_id,"no dead hero in new identity plan")

func legacy_boundary() -> void:
	for kind in [SimulationWorld.ScenarioKind.LEGACY_RTS,SimulationWorld.ScenarioKind.GREY_RIDGE,SimulationWorld.ScenarioKind.BROKEN_BRIDGE,SimulationWorld.ScenarioKind.FOG_FOREST,SimulationWorld.ScenarioKind.BLACK_WELL]:
		var world := SimulationWorld.new(true,false,kind)
		world.advance_tick()
		check(world.legion_formation_system.records.is_empty(),"legacy and original missions do not acquire legion executor")
		for formation: FormationState in world.formations.values(): check(formation.anchor_speed_limit==180.0,"old formation pace stays original")

func immediate_exposure_stop() -> void:
	var world := fresh()
	var commander := world.commanders[&"lin_mo"] as CommanderState
	var hero := world.units[commander.hero_entity_id] as UnitState
	var enemy: UnitState
	for candidate: UnitState in world.units.values():
		if candidate.faction_id==2: enemy=candidate; break
	enemy.position=hero.position+Vector2(64,0); enemy.attack_range=10000; enemy.can_attack=true
	world.faction_knowledge[1].visible_hostile_unit_ids.append(enemy.entity_id)
	world.legion_formation_system.prepare(world)
	var record := world.legion_formation_system.snapshot(&"lin_mo")
	check(record.reason==&"EXPOSED","new legally visible coverage assessed before ordinary movement")
	check(record.core_speed==0.0,"blocked pace snapshot matches applied stop")
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		var formation := world.formations.get(card.formation_id) as FormationState
		if formation!=null and card.control_state==UnitCardState.ControlState.AGENT_ASSIGNED:
			check(formation.anchor_speed_limit==0.0,"new unsafe protection stops same-tick ordinary anchor advance")
	# An accepted retreat must not inherit the normal-advance block.
	var retreat := CommanderOrderCommand.new(world.allocate_command_id(),1,world.current_tick,&"lin_mo",CommanderOrderCommand.OrderKind.SET_POSTURE,Vector2.ZERO,&"",CommanderState.Posture.DISENGAGE)
	check(world.submit_command(retreat).is_accepted(),"retreat is accepted during exposed protection")
	for command in world.command_queue.drain(): world._apply_command(command)
	world.legion_formation_system.prepare(world)
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		var formation := world.formations.get(card.formation_id) as FormationState
		if formation!=null: check(formation.anchor_speed_limit>0.0,"accepted retreat is not frozen by protection exposure")

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	control_and_snapshots()
	knowledge_and_lifecycle()
	legacy_boundary()
	immediate_exposure_stop()
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED","checks":checks,"failures":failures,"scope":"formal control, private snapshots, hidden pollution, lifecycle and legacy boundary; not full B"}))
	print("LEGION43_RUNTIME checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
