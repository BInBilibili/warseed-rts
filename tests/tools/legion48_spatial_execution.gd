extends SceneTree

var checks := 0
var failures: Array[String] = []
var output := "res://artifacts/legion48/spatial01.json"
var rows: Array = []

func check(value: bool, reason: String) -> void:
	checks+=1
	if not value and not failures.has(reason): failures.append(reason)

func fixture(profile: StringName, mirrored: bool = false, count: int = 12) -> SimulationWorld:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var selected: CommanderState
	for commander: CommanderState in world.commanders.values():
		if commander.definition.profile.profile_id==profile and commander.faction_id==1: selected=commander
	world.commanders.clear(); world.commanders[selected.definition.definition_id]=selected
	var ids: Array[int] = [selected.hero_entity_id]
	for card_id in selected.subordinate_unit_card_ids: ids.append_array(world.unit_cards[card_id].member_entity_ids)
	for id in world.units.keys():
		if not ids.has(id): world.units.erase(id)
	world.logic_grid=LogicGrid.new(); world.logic_grid.grid_size=Vector2i(320,160)
	world.pathfinder=GridPathfinder.new(world.logic_grid)
	world.formation_movement=FormationMovementSystem.new(world.logic_grid,world.pathfinder,true)
	# Both mirrored x ranges stay within the same float32 exponent interval.
	# The original center=5000 crossed 4096 on only one side, producing a
	# 0.01 coordinate-rounding discrepancy (spatial01 is retained).
	var center := Vector2(6000,3000)
	var direction := Vector2.LEFT if mirrored else Vector2.RIGHT
	var ordinals := [0,0,0,0]
	var roles := LegionTemplate.find(profile).slot_roles()
	# Physical-capacity fixture only. These extra bodies are initialized here,
	# never presented as evidence of recruitment costs or natural growth.
	for identity in range(12,count):
		var card: UnitCardState
		for card_id in selected.subordinate_unit_card_ids:
			if world.unit_cards[card_id].definition.role_key==LegionTemplate.ROLE_KEYS[roles[identity]]: card=world.unit_cards[card_id]
		var exemplar := world.units[card.member_entity_ids[0]] as UnitState
		var unit := UnitState.new(90000+identity,center,exemplar.move_speed,1)
		unit.unit_card_id=card.definition.definition_id; unit.tactical_role=exemplar.tactical_role
		unit.formation_id=card.formation_id; unit.following_formation=true
		world.units[unit.entity_id]=unit; card.member_entity_ids.append(unit.entity_id)
		world.formations[card.formation_id].add_member(unit.entity_id)
		selected.growth_slot_entities[identity]=unit.entity_id
	selected.growth_unlocked_slots=count
	for identity in range(count):
		var unit := world.units[selected.growth_slot_entities[identity]] as UnitState
		var role := roles[identity]
		var offset := LegionSpatialExecutor.layout(profile,LegionSpatialState.Action.MOVE).offsets[identity]
		ordinals[role]+=1
		unit.position=center+direction*offset.x+direction.orthogonal()*offset.y
		unit.control_state=UnitState.ControlState.AGENT_ASSIGNED; unit.rejoin_pending=false
		unit.has_move_target=false
	var hero := world.units[selected.hero_entity_id] as UnitState
	hero.position=center-direction*LegionSpatialExecutor.protection_offset(profile); hero.control_state=UnitState.ControlState.AGENT_ASSIGNED
	selected.target_position=center+direction*1600
	for card_id in selected.subordinate_unit_card_ids:
		var card := world.unit_cards[card_id] as UnitCardState
		card.control_state=UnitCardState.ControlState.AGENT_ASSIGNED
		var formation := world.formations.get(card.formation_id) as FormationState
		if formation==null: continue
		formation.anchor_position=center
		formation.order_destination=selected.target_position; formation.target_position=selected.target_position
		formation.path=PackedVector2Array([center,selected.target_position]); formation.path_index=1
		formation.order_kind=FormationState.OrderKind.MOVE; formation.is_moving=true
		formation.planned_route=PackedVector2Array([selected.target_position])
	world.faction_knowledge[1].visible_hostile_unit_ids.clear()
	world.events.clear()
	return world

func step(world: SimulationWorld) -> void:
	var before := {}; var speeds := {}
	for unit: UnitState in world.units.values():
		before[unit.entity_id]=unit.position; speeds[unit.entity_id]=unit.move_speed
	world.legion_formation_system.prepare(world)
	var owned := {}
	for unit: UnitState in world.units.values():
		if unit.legion_slot!=null: owned[unit.entity_id]=unit.position
	world.formation_movement.advance(world.formations,world.units,world.events,world.current_tick)
	for id in owned: check(world.units[id].position==owned[id],"legacy mover cannot write a spatially owned soldier")
	LegionSpatialExecutor.advance(world)
	world.legion_formation_system.advance_heroes(world)
	for unit: UnitState in world.units.values():
		if not unit.following_formation and unit.legion_slot==null: world._advance_unit(unit)
		check(unit.position.distance_to(before[unit.entity_id])<=speeds[unit.entity_id]*0.1+0.01,"all actual members respect one tick speed budget")
		check(world.logic_grid.is_segment_walkable(before[unit.entity_id],unit.position),"actual member segment remains walkable")
	LegionSpatialExecutor.refresh(world)
	var ids := world.units.keys(); ids.sort()
	for i in range(ids.size()):
		var a := world.units[ids[i]] as UnitState
		if not a.enabled: continue
		for j in range(i+1,ids.size()):
			var b := world.units[ids[j]] as UnitState
			if not b.enabled: continue
			var required := minf(24.0,(before[a.entity_id] as Vector2).distance_to(before[b.entity_id]))
			if a.position.distance_to(b.position)<required-0.01 and not failures.has("actual pair occupancy never overlaps or worsens inherited overlap"):
				print("COLLISION_DIAGNOSTIC tick=",world.current_tick," a=",a.entity_id," b=",b.entity_id," before=",before[a.entity_id],"/",before[b.entity_id]," after=",a.position,"/",b.position," constraint=",a.legion_motion!=null,"/",b.legion_motion!=null)
			check(a.position.distance_to(b.position)>=required-0.01,"actual pair occupancy never overlaps or worsens inherited overlap")
	world.current_tick+=1

func trial(profile: StringName, mirrored: bool, count: int = 12) -> Dictionary:
	var world := fixture(profile,mirrored,count)
	var commander := world.commanders.values()[0] as CommanderState
	var hero := world.units[commander.hero_entity_id] as UnitState
	var start := hero.position
	for tick in range(160): step(world)
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	check(record.spatial.eligible==count,"all initialized identities physically owned")
	check(hero.position.distance_to(start)>500,"open-ground marching makes actual progress: "+String(profile))
	var old := record.duplicate_value()
	var kept := old.spatial.slots[1].target
	record.spatial.slots[1].target+=Vector2(1,0)
	check(old.spatial.slots[1].target==kept,"spatial slot snapshot does not alias authority")
	# Loss leaves all other role slots intact; no survivor-count recentering.
	var offsets := []
	for slot in record.spatial.slots: offsets.append(slot.offset)
	var casualty := world.units[commander.growth_slot_entities[0]] as UnitState
	casualty.enabled=false
	world.legion_formation_system.prepare(world)
	for identity in range(1,count): check(record.spatial.slots[identity].offset==offsets[identity],"casualty does not renumber surviving slots")
	var manual := world.unit_cards[commander.subordinate_unit_card_ids[0]] as UnitCardState
	manual.control_state=UnitCardState.ControlState.PLAYER_OVERRIDDEN
	world.legion_formation_system.prepare(world)
	for id in manual.member_entity_ids: check(world.units[id].legion_slot==null,"card takeover immediately releases spatial ownership")
	var delta := hero.position-start
	return {"profile":profile,"count":count,"mirror":mirrored,"hero_delta":[snappedf(delta.x*( -1 if mirrored else 1),0.01),snappedf(delta.y*(-1 if mirrored else 1),0.01)],"eligible":record.spatial.eligible,"ready":record.spatial.ready,"reason":record.spatial.reason}

func relief() -> void:
	var world := fixture(&"sentinel")
	var commander := world.commanders.values()[0] as CommanderState
	var hero := world.units[commander.hero_entity_id] as UnitState
	world.legion_formation_system.prepare(world)
	var record := world.legion_formation_system.records[commander.definition.definition_id]
	var surviving: UnitState
	for unit: UnitState in world.units.values():
		if unit.tactical_role not in [UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR]: continue
		if surviving==null: surviving=unit
		else: unit.enabled=false
	surviving.position=hero.position+Vector2(2000,0)
	var origin := hero.position; var core_origin := surviving.position
	for tick in range(50): step(world)
	check(hero.position==origin,"hero stays with remnant while remote core approaches")
	check(surviving.position.distance_to(origin)<core_origin.distance_to(origin)-500,"remote core really moves toward local remnant")
	check(record.reason==&"REJOIN_CORE","distant core is not represented as protected arrival")
	for tick in range(150): step(world)
	var gap := LegionProtectionPlanner.path_length(LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,hero.position,surviving.position))
	check(gap<=240.01,"relief completes through actual movement")
	rows.append({"relief_gap":gap,"hero_travel":hero.position.distance_to(origin),"core_travel":surviving.position.distance_to(core_origin)})

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	for profile: StringName in LegionTemplate.PROFILE_IDS:
		for count in [12,60]:
			var first := trial(profile,false,count); var mirror := trial(profile,true,count)
			check(first.hero_delta==mirror.hero_delta,"actual mirrored marching agrees: "+String(profile)+str(count))
			rows.append(first); rows.append(mirror)
	relief()
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED","checks":checks,"failures":failures,"rows":rows}))
	print("LEGION48_SPATIAL checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
