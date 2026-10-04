extends SceneTree

var checks := 0
var failures: Array[String] = []
var steps: Array[Dictionary] = []

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures.append(reason)
		push_error(reason)

func fresh() -> SimulationWorld:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.current_tick = 300
	for faction: FactionState in world.factions.values():
		faction.supply = 300
	return world

func leader(world: SimulationWorld, profile: StringName = &"spear", faction: int = 1) -> CommanderState:
	for commander: CommanderState in world.commanders.values():
		if commander.faction_id == faction and commander.definition.profile.profile_id == profile:
			return commander
	return null

func next_card(world: SimulationWorld, commander: CommanderState, slot: int = -1) -> UnitCardState:
	if slot < 0:
		slot = LegionGrowthSystem.next_for_world(world, commander)
	if slot < 0:
		return null
	var role := LegionTemplate.find(commander.definition.profile.profile_id).slot_roles()[slot]
	for id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards[id] as UnitCardState
		if card.definition.role_key == LegionTemplate.ROLE_KEYS[role]:
			return card
	return null

func order(world: SimulationWorld, card: UnitCardState) -> RecruitUnitCardCommand:
	return RecruitUnitCardCommand.new(world.allocate_command_id(), card.faction_id, GameCommand.IssuerKind.PLAYER, world.current_tick, card.definition.definition_id, 1)

func apply_queue(world: SimulationWorld) -> void:
	for command in world.command_queue.drain():
		world._apply_command(command)

func state(world: SimulationWorld, card: UnitCardState) -> String:
	var commander := world.commanders[card.commander_definition_id] as CommanderState
	var faction := world.factions[card.faction_id] as FactionState
	var formation := world.formations.get(card.formation_id) as FormationState
	var task_data: Array = []
	for task: TaskState in world.tasks.values():
		task_data.append([task.task_id, task.participant_entity_ids.duplicate(), task.lifecycle, task.phase])
	var composition: Array = []
	for entry in card.composition:
		composition.append(entry.member_entity_ids.duplicate())
	return var_to_str([
		world._next_unit_id, world._next_formation_id, world._next_task_id,
		world.units.keys(), world.formations.keys(), task_data,
		card.member_entity_ids.duplicate(), composition, card.formation_id, card.organization,
		card.last_total_health, card.last_active_strength, card.assigned_task_id,
		[] if formation == null else [formation.member_entity_ids.duplicate(), formation.slot_by_entity_id.duplicate(), formation.anchor_position, formation.target_position, formation.path.duplicate(), formation.is_moving, formation.order_kind],
		commander.growth_slot_entities.duplicate(), commander.growth_unlocked_slots,
		faction.supply, faction.population, faction.recruitment_window, faction.recruited_by_commander.duplicate(),
		faction.spend_window, faction.recruitment_spend, faction.support_spend
	])

func block_birth_area(world: SimulationWorld, card: UnitCardState) -> Array[Vector2i]:
	var view := world.create_logistics_snapshot(card.faction_id, false)
	var origin := AutomaticLogisticsAgent.recruitment_position(view, UnitCardSnapshot.new(card, world.units), world.battle_definition)
	var center := world.logic_grid.world_to_cell(origin)
	var changed: Array[Vector2i] = []
	for y in range(-13, 14):
		for x in range(-13, 14):
			var cell := center + Vector2i(x, y)
			if not world.logic_grid.is_blocked(cell):
				changed.append(cell)
				world.logic_grid.set_blocked(cell, true)
	return changed

func failure_is_atomic(world: SimulationWorld, card: UnitCardState, label: String) -> void:
	var input := order(world, card)
	check(world.submit_command(input).is_accepted(), label + " accepted before birth-space resolution")
	var changed := block_birth_area(world, card)
	var before := state(world, card)
	var event_start := world.events.size()
	apply_queue(world)
	check(state(world, card) == before, label + " leaves IDs, tasks, formation, organization, slots and economy unchanged")
	var rejected := false
	for event in world.events.slice(event_start):
		if event.kind == SimulationEvent.Kind.COMMAND_REJECTED and event.detail.contains("PATH_UNAVAILABLE"):
			rejected = true
		check(event.kind not in [SimulationEvent.Kind.UNIT_CARD_REINFORCED, SimulationEvent.Kind.SUPPLY_CHANGED], label + " no fake success event")
	check(rejected, label + " reports unavailable birth space")
	for cell in changed:
		world.logic_grid.set_blocked(cell, false)
	check(world.submit_command(order(world, card)).is_accepted(), label + " retry accepted")
	var units_before := world.units.size()
	apply_queue(world)
	check(world.units.size() == units_before + 1, label + " retry births exactly once")

func test_atomic() -> void:
	var world := fresh()
	var commander := leader(world)
	var card := next_card(world, commander)
	failure_is_atomic(world, card, "living card")
	for remove_formation in [false, true]:
		world = fresh()
		commander = leader(world)
		card = next_card(world, commander)
		for id in card.member_entity_ids:
			(world.units[id] as UnitState).enabled = false
		card.last_damage_tick = world.current_tick - 200
		card.organization = 19.0
		if remove_formation:
			world.formations.erase(card.formation_id)
		world._refresh_battle_population()
		failure_is_atomic(world, card, "empty card missing formation=" + str(remove_formation))

func test_growth() -> void:
	var world := fresh()
	var costs: Dictionary = {}
	check(world.logic_grid.has_rotationally_symmetric_solidity(),"actual map including HQ footprints is symmetric")
	var frozen := world.create_logistics_snapshot(1, true)
	for step in range(48):
		world.current_tick = 300 + step * 10
		for faction in [1, 2]:
			# Controlled funds isolate birth/charge correctness from income/AI timing.
			(world.factions[faction] as FactionState).supply = 300
			for profile in LegionTemplate.PROFILE_IDS:
				var commander := leader(world, profile, faction)
				var slot := LegionGrowthSystem.next_for_world(world, commander)
				var card := next_card(world, commander, slot)
				if card == null:
					check(false, "missing growth card " + str([faction, profile, step]))
					continue
				var expected_cost := card.definition.recruitment_cost
				var birth_origin := UnitCardSnapshot.new(card,world.units).center_position
				var supply_before: int = world.factions[faction].supply
				var units_before := world.units.size()
				var command := order(world, card)
				var valid := world.submit_command(command)
				check(valid.is_accepted(), "growth accepted " + str([faction, profile, step, valid.describe()]))
				check(command.legion_slot == -1, "submitted value left unchanged")
				if not valid.is_accepted():
					continue
				var queued := world.command_queue.snapshot()[0] as RecruitUnitCardCommand
				check(queued.legion_slot == step + 12, "queued slot fixed")
				apply_queue(world)
				check(world.units.size() == units_before + 1, "actual single birth " + str([faction, profile, step]))
				check(supply_before - world.factions[faction].supply == expected_cost, "actual cost " + str([faction, profile, step]))
				check(commander.growth_unlocked_slots == step + 13, "one slot unlocked")
				var entity_id := commander.growth_slot_entities[slot]
				var unit := world.units.get(entity_id) as UnitState
				check(unit != null and unit.unit_card_id == card.definition.definition_id, "slot occupied by correct role")
				if unit != null:
					check(world.logic_grid.is_world_position_walkable(unit.position), "born on walkable ground")
					var separated := true
					for other: UnitState in world.units.values():
						if other.enabled and other.entity_id != entity_id and other.position.distance_squared_to(unit.position) < 24.0 * 24.0:
							separated = false
					check(separated, "born without overlapping another live unit")
					check(unit.assigned_task_id == card.assigned_task_id and unit.control_state == UnitState.ControlState.AGENT_ASSIGNED, "inherits task and control")
				var key := str(faction) + "/" + str(profile)
				costs[key] = costs.get(key, 0) + supply_before - world.factions[faction].supply
				steps.append({"faction":faction,"profile":profile,"slot":slot,"entity":entity_id,"cost":supply_before-world.factions[faction].supply,"position":str(unit.position) if unit!=null else "missing","origin":str(birth_origin)})
		if step % 12 == 11:
			print("GROWTH_PROGRESS step=", step + 1, " units=", world.units.size(), " failures=", failures.size())
	var expected := [160,156,157,105,124]
	for faction in [1,2]:
		for index in range(5):
			var profile := LegionTemplate.PROFILE_IDS[index]
			check(costs.get(str(faction)+"/"+str(profile),0)==expected[index], "480 real births per-legion cost " + str([faction,profile]))
		check(world.factions[faction].population == 300, "full population exactly 300")
	check(world.units.size() == 610, "full battle has 610 actual units")
	for profile in LegionTemplate.PROFILE_IDS:
		var blue := leader(world, profile, 1)
		var red := leader(world, profile, 2)
		for slot in range(12,60):
			var blue_unit := world.units[blue.growth_slot_entities[slot]] as UnitState
			var red_unit := world.units[red.growth_slot_entities[slot]] as UnitState
			check((blue_unit.position + red_unit.position).distance_to(Vector2(32768,24576)) < 0.02,"rotated birth positions " + str([profile,slot]))
			if (blue_unit.position + red_unit.position).distance_to(Vector2(32768,24576)) >= 0.02:
				print("MIRROR_DIAGNOSTIC ",profile," slot=",slot," blue=",blue_unit.position," red=",red_unit.position)
	for commander in frozen.commanders:
		check(commander.growth_unlocked_slots == 12, "old snapshot growth count immutable")
		var occupied := 0
		for id in commander.growth_slot_entities:
			if id > 0: occupied += 1
		check(occupied == 12, "old snapshot slot array immutable")
	# A living reinforcement travelling back still occupies its permanent slot.
	var commander := leader(world)
	var unit := world.units[commander.growth_slot_entities[12]] as UnitState
	unit.legion_returning = true
	check(LegionGrowthSystem.next_for_world(world,commander)==-1,"in-transit recruit not repurchased")
	unit.enabled = false
	world._refresh_battle_population()
	world.current_tick += 10
	world.factions[1].supply=300
	var card := next_card(world,commander)
	check(LegionGrowthSystem.next_for_world(world,commander)==12,"dead recruit reopens same identity slot")
	check(world.submit_command(order(world,card)).is_accepted(),"replacement accepted")
	apply_queue(world)
	check(commander.growth_unlocked_slots==60 and commander.growth_slot_entities[12]!=unit.entity_id,"replacement preserves unlocked count and changes entity")
	check(world.factions[1].population==300,"replacement restores population")

func test_queued_slots() -> void:
	var world := fresh()
	var commander := leader(world)
	world.factions[1].recruitment_rates[commander.definition.definition_id]=2
	var first := next_card(world,commander,12)
	var second := next_card(world,commander,13)
	check(world.submit_command(order(world,first)).is_accepted(),"first queued slot accepted")
	check(world.submit_command(order(world,second)).is_accepted(),"second queued slot accepted")
	var queued := world.command_queue.snapshot()
	check(queued.size()==2 and queued[0].legion_slot==12 and queued[1].legion_slot==13,"pending slots unique")
	# An intervening casualty changes canonical recovery priority. Neither queued
	# growth order may silently purchase a different slot, even of the same role.
	var casualty := world.units[commander.growth_slot_entities[0]] as UnitState
	casualty.enabled=false
	world._refresh_battle_population()
	var supply_before:int=world.factions[1].supply
	var next_id:=world._next_unit_id
	apply_queue(world)
	check(world._next_unit_id==next_id and world.factions[1].supply==supply_before,"stale slot applications refuse without charge")
	check(commander.growth_unlocked_slots==12,"stale queue does not unlock slots")

func test_application_boundaries() -> void:
	for condition in ["reserve", "quota", "damage", "hero", "supply_cut"]:
		var world := fresh()
		var commander := leader(world)
		var card := next_card(world,commander)
		check(world.submit_command(order(world,card)).is_accepted(),condition + " initially queued")
		match condition:
			"reserve": world.factions[1].recruitment_reserve=300
			"quota": world.factions[1].recruitment_rates[commander.definition.definition_id]=0
			"damage": card.last_damage_tick=world.current_tick
			"hero": commander.legion_regrouping=true
			"supply_cut":
				for region:StrategicRegionState in world.strategic_regions.values():
					if region.controller_faction_id==1:region.contested=true
		var before:=state(world,card)
		apply_queue(world)
		check(before==state(world,card),condition + " application revalidation leaves authority unchanged")
	var world:=fresh()
	var commander:=leader(world)
	var card:=next_card(world,commander)
	var support_kind:=SupportOrderCommand.SupportKind.AIR_RECON
	var support_cost:=world.get_support_cost(support_kind)
	world.factions[1].supply=12 + card.definition.recruitment_cost
	var support:=AreaSupportCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,support_kind,world.battle_definition.player_headquarters_position)
	if support_cost > world.factions[1].supply:
		world.factions[1].supply=support_cost + card.definition.recruitment_cost
		world.factions[1].recruitment_reserve=support_cost
	check(world.submit_command(support).is_accepted(),"player support may consume reserved minimum")
	check(not world.submit_command(order(world,card)).is_accepted(),"queued support commitment cannot be spent twice")
	var before:int=world.factions[1].supply
	apply_queue(world)
	check(world.factions[1].supply==before-support_cost,"real support applies its cost")
	for control in [UnitCardState.ControlState.AGENT_ASSIGNED,UnitCardState.ControlState.PLAYER_CONTROLLED,UnitCardState.ControlState.PLAYER_OVERRIDDEN,UnitCardState.ControlState.RETURNING]:
		world=fresh()
		commander=leader(world)
		card=next_card(world,commander)
		card.control_state=control
		card.return_task_id=card.assigned_task_id
		check(world.submit_command(order(world,card)).is_accepted(),"authorized manual recruit control="+str(control))
		apply_queue(world)
		var unit:=world.units[commander.growth_slot_entities[12]] as UnitState
		var expected:=UnitState.ControlState.AGENT_ASSIGNED
		if control==UnitCardState.ControlState.PLAYER_CONTROLLED:expected=UnitState.ControlState.PLAYER_CONTROLLED
		elif control==UnitCardState.ControlState.PLAYER_OVERRIDDEN:expected=UnitState.ControlState.TEMPORARILY_OVERRIDDEN
		check(unit.control_state==expected,"birth inherits control="+str(control))
		if control==UnitCardState.ControlState.PLAYER_OVERRIDDEN:
			check(unit.return_task_id==card.return_task_id,"override birth retains return task")
		if expected==UnitState.ControlState.AGENT_ASSIGNED:
			check(world.tasks[card.assigned_task_id].participant_entity_ids.has(unit.entity_id),"assigned birth joins task participants")
	world=fresh()
	commander=leader(world)
	card=next_card(world,commander)
	for id in card.member_entity_ids:world.units[id].enabled=false
	card.last_damage_tick=world.current_tick-199
	world._refresh_battle_population()
	check(not world.submit_command(order(world,card)).is_accepted(),"empty card rebuild refuses at 199 ticks")
	world.current_tick+=1
	check(world.submit_command(order(world,card)).is_accepted(),"empty card rebuild accepted at 200 ticks")
	apply_queue(world)
	check(UnitCardSnapshot.new(card,world.units).current_strength==1,"empty card rebuilt as one soldier")

func test_occupied_birth() -> void:
	var world:=fresh()
	var commander:=leader(world)
	var card:=next_card(world,commander)
	check(world.submit_command(order(world,card)).is_accepted(),"occupied fixture initially queued")
	var center:=UnitCardSnapshot.new(card,world.units).center_position
	var blocker_ids:Array[int]=[]
	for y in range(-8,9):
		for x in range(-8,9):
			if x*x+y*y>64:continue
			var id:=world._next_unit_id
			world._next_unit_id+=1
			var unit:=UnitState.new(id,center+Vector2(x,y)*48.0,0.0,1)
			world.units[id]=unit
			blocker_ids.append(id)
	var before:=state(world,card)
	apply_queue(world)
	check(before==state(world,card),"physically full birth area refuses atomically")
	for id in blocker_ids:world.units.erase(id)
	check(world.submit_command(order(world,card)).is_accepted(),"space released retry accepted")
	apply_queue(world)
	check(commander.growth_unlocked_slots==13,"space released births next slot")

func _initialize() -> void:
	test_atomic()
	test_queued_slots()
	test_application_boundaries()
	test_occupied_birth()
	test_growth()
	var report := {"evidence":"SIMULATED","checks":checks,"failures":failures,"steps":steps,"scope":"actual command submission/application, synthetic funding and controlled tick windows; not natural economy or complete battle"}
	FileAccess.open("res://artifacts/legion35/recruitment.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("LEGION35_RECRUITMENT checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
