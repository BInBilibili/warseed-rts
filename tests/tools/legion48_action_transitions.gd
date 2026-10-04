extends "res://tests/tools/legion48_spatial_execution.gd"

func layouts() -> void:
	for profile: StringName in LegionTemplate.PROFILE_IDS:
		var template := LegionTemplate.find(profile)
		for action in [LegionSpatialState.Action.MOVE,LegionSpatialState.Action.ATTACK,LegionSpatialState.Action.DEFEND]:
			var points: Array[Vector2] = []
			var roles := template.slot_roles(); var indices := [0,0,0,0]
			var geometry := LegionSpatialExecutor.layout(profile,action)
			check(geometry.valid and geometry.offsets.size()==60,"full sixty-member layout exists")
			for identity in range(60):
				var role := roles[identity]
				var point := geometry.offsets[identity]
				check(point.distance_to(Vector2(-LegionSpatialExecutor.protection_offset(profile),0))>=47.99,"sixty-one bodies reserve physical hero space")
				indices[role]+=1
				for other in points: check(point.distance_to(other)>=47.99,"full layout physical capacity "+String(profile)+" action="+str(action))
				points.append(point)

func transitions(profile: StringName) -> void:
	var world := fixture(profile)
	var commander := world.commanders.values()[0] as CommanderState
	for tick in range(40): step(world)
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	var action_trace := [record.spatial.action]
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		var formation := world.formations.get(card.formation_id) as FormationState
		if formation!=null: formation.order_kind=FormationState.OrderKind.ATTACK_MOVE; formation.is_moving=true
	for tick in range(30): step(world)
	action_trace.append(record.spatial.action)
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		var formation := world.formations.get(card.formation_id) as FormationState
		if formation!=null: formation.is_moving=false
	for tick in range(100): step(world)
	action_trace.append(record.spatial.action)
	var before := {}
	for unit: UnitState in world.units.values(): before[unit.entity_id]=unit.position
	var retreat := CommanderOrderCommand.new(world.allocate_command_id(),1,world.current_tick,commander.definition.definition_id,CommanderOrderCommand.OrderKind.SET_POSTURE,Vector2.ZERO,&"",CommanderState.Posture.DISENGAGE)
	check(world.submit_command(retreat).is_accepted(),"retreat transition uses common command admission")
	for command in world.command_queue.drain(): world._apply_command(command)
	world.legion_formation_system.prepare(world)
	for unit: UnitState in world.units.values(): check(unit.position==before[unit.entity_id],"retreat planning never teleports or swaps members")
	for tick in range(30): step(world)
	action_trace.append(record.spatial.action)
	check(action_trace==[LegionSpatialState.Action.MOVE,LegionSpatialState.Action.ATTACK,LegionSpatialState.Action.DEFEND,LegionSpatialState.Action.RETREAT],"actual execution traverses all four actions "+String(profile))
	rows.append({"profile":profile,"actions":action_trace,"eligible":record.spatial.eligible,"ready":record.spatial.ready})

func loss_and_growth() -> void:
	var world := fixture(&"sentinel")
	step(world)
	var commander := world.commanders.values()[0] as CommanderState
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	var escort := world.units[record.state.escort_id] as UnitState
	escort.enabled=false
	LegionSpatialExecutor.refresh(world)
	check(record.reason==&"REJOIN_CORE" and record.state.escort_id==0,"same-tick dead escort never remains labeled protected")
	var template := LegionTemplate.find(&"sentinel")
	var role := template.slot_roles()[12]
	var card: UnitCardState
	for id in commander.subordinate_unit_card_ids:
		if world.unit_cards[id].definition.role_key==LegionTemplate.ROLE_KEYS[role]: card=world.unit_cards[id]
	var recruit := UnitState.new(90001,world.units[commander.hero_entity_id].position-Vector2(1500,0),168.0,1)
	recruit.control_state=UnitState.ControlState.AGENT_ASSIGNED; recruit.unit_card_id=card.definition.definition_id
	recruit.tactical_role=[UnitState.TacticalRole.SCOUT,UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR,UnitState.TacticalRole.FIREPOWER][role]
	world.units[recruit.entity_id]=recruit; card.member_entity_ids.append(recruit.entity_id)
	commander.growth_unlocked_slots=13; commander.growth_slot_entities[12]=recruit.entity_id
	world.legion_formation_system.prepare(world)
	check(recruit.legion_slot!=null and not recruit.legion_slot.admitted,"new identity gets a rear staging order")
	check(record.spatial.eligible==11,"remote new identity does not freeze active denominator")
	var hero := world.units[commander.hero_entity_id] as UnitState
	for unit: UnitState in world.units.values():
		if unit.tactical_role in [UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR]: unit.enabled=false
	var snapshot := world.create_commander_task_snapshot(1,false)
	snapshot.tick=1000
	# Legal value-input boundary: enough scouts to defeat the old strength<8
	# condition. This checks the no-core criterion, not an actual recruitment.
	for view in snapshot.unit_cards:
		if view.commander_definition_id!=commander.definition.definition_id: continue
		view.current_strength=20 if view.role_key==&"UNIT_CARD_ROLE_RECON" else 0
		view.organization=100
	var proposals := GrowthCommanderAgent.new().propose(snapshot,world.battle_definition,commander.definition.definition_id)
	check(not proposals.is_empty() and proposals[0].action==GrowthCommanderCommand.Action.RECOVER,"healthy scout-only remnant requests recovery through agent command pipeline")
	commander.posture=CommanderState.Posture.DISENGAGE
	var start := hero.position
	for tick in range(50): step(world)
	check(hero.position.distance_to(start)>100,"accepted withdrawal moves hero even with no qualified core")
	check(record.reason not in [&"FORMING",&"IN_POSITION"],"scout-only withdrawal never claims core protection")

func _initialize() -> void:
	output="res://artifacts/legion48/actions01.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	layouts()
	for profile: StringName in LegionTemplate.PROFILE_IDS: transitions(profile)
	loss_and_growth()
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED","checks":checks,"failures":failures,"rows":rows}))
	print("LEGION48_ACTIONS checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
