extends SceneTree

const Protection = preload("res://artifacts/legion38/staging/legion_protection_system.gd")

class MovementHook extends FormationMovementSystem:
	var world: SimulationWorld
	var protection := Protection.new()
	var coordinate_speed := false
	var caps: Dictionary[int,float] = {}
	func _advance_anchor(formation: FormationState, speed_scale: float = 1.0) -> void:
		super(formation, speed_scale * caps.get(formation.formation_id,180.0)/180.0)
	func update_caps() -> void:
		caps.clear()
		if not coordinate_speed: return
		for commander: CommanderState in world.commanders.values():
			var hero := world.units.get(commander.hero_entity_id) as UnitState
			if hero == null or not hero.enabled or commander.legion_regrouping: continue
			var cap := hero.move_speed
			for card_id in commander.subordinate_unit_card_ids:
				var card := world.unit_cards[card_id] as UnitCardState
				if card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED: continue
				for entity_id in card.member_entity_ids:
					var unit := world.units.get(entity_id) as UnitState
					if unit != null and unit.enabled and not unit.rejoin_pending and not unit.legion_returning and unit.tactical_role != UnitState.TacticalRole.SCOUT: cap = minf(cap,unit.move_speed)
			for card_id in commander.subordinate_unit_card_ids:
				var card := world.unit_cards[card_id] as UnitCardState
				if card.control_state == UnitCardState.ControlState.AGENT_ASSIGNED: caps[card.formation_id] = minf(180.0,cap)
	func _init(owner: SimulationWorld) -> void:
		world = owner
		super(owner.logic_grid,owner.pathfinder,owner.formation_movement.sustained_recovery)
	func advance(formations: Dictionary, units: Dictionary, events: Array[SimulationEvent], current_tick: int) -> void:
		update_caps()
		super(formations,units,events,current_tick)
		protection.advance(world)

var checks := 0
var failures: Array[String] = []
var output := "res://artifacts/legion38/pace-long01.json"
var coordinate_speed := false
func check(value: bool, reason: String) -> void:
	checks += 1
	if not value and not failures.has(reason): failures.append(reason)

func run_world() -> Dictionary:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var movement := MovementHook.new(world)
	world.formation_movement = movement
	movement.coordinate_speed = coordinate_speed
	var starting := {}
	for commander: CommanderState in world.commanders.values(): starting[commander.definition.definition_id] = (world.units[commander.hero_entity_id] as UnitState).position
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	var reasons := {}
	var max_gap := {}
	var settled_gap := {}
	var nearest_gap := {}
	var final_gap := {}
	var actual_path_gap := {}
	for tick in range(1200):
		var before := {}
		var speeds := {}
		for commander: CommanderState in world.commanders.values():
			var hero := world.units.get(commander.hero_entity_id) as UnitState
			before[hero.entity_id] = hero.position
			speeds[hero.entity_id] = hero.move_speed
		world.advance_tick()
		for commander: CommanderState in world.commanders.values():
			var hero := world.units.get(commander.hero_entity_id) as UnitState
			var record = movement.protection.snapshot(commander.definition.definition_id)
			reasons[record.reason] = reasons.get(record.reason,0)+1
			if hero.enabled and before.has(hero.entity_id):
				check(hero.position.distance_to(before[hero.entity_id]) <= float(speeds[hero.entity_id])*0.1+0.01,"actual hero respects tick speed")
				check(world.logic_grid.is_segment_walkable(before[hero.entity_id],hero.position),"actual hero movement segment walkable")
			var escort := world.units.get(record.state.escort_id) as UnitState
			if hero.enabled and escort != null and escort.enabled:
				var actual_path := Protection.Planner.route(world.logic_grid,world.pathfinder,hero.position,escort.position)
				var actual_distance := Protection.Planner.path_length(actual_path) if not actual_path.is_empty() else 1.0e12
				actual_path_gap[commander.definition.definition_id] = maxf(actual_path_gap.get(commander.definition.definition_id,0.0),actual_distance)
				check(actual_distance <= 240.01,"actual selected escort reachable within 240: " + String(commander.definition.definition_id))
				max_gap[commander.definition.definition_id] = maxf(max_gap.get(commander.definition.definition_id,0.0),hero.position.distance_to(escort.position))
				final_gap[commander.definition.definition_id] = hero.position.distance_to(escort.position)
				if tick>=50:
					settled_gap[commander.definition.definition_id] = maxf(settled_gap.get(commander.definition.definition_id,0.0),hero.position.distance_to(escort.position))
					var nearest := INF
					for card_id in commander.subordinate_unit_card_ids:
						var card := world.unit_cards[card_id] as UnitCardState
						if card.control_state != UnitCardState.ControlState.AGENT_ASSIGNED: continue
						for member_id in card.member_entity_ids:
							var member := world.units.get(member_id) as UnitState
							if member != null and member.enabled and not member.rejoin_pending and not member.legion_returning and member.tactical_role in [UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR]: nearest = minf(nearest,hero.position.distance_to(member.position))
					if nearest < INF:
						nearest_gap[commander.definition.definition_id] = maxf(nearest_gap.get(commander.definition.definition_id,0.0),nearest)
						check(nearest <= 240.01,"actual nearest core <=240: " + String(commander.definition.definition_id))
			trace.update(("%d:%s:%s:%.5f:%.5f:%d;" % [world.current_tick,commander.definition.definition_id,record.reason,hero.position.x,hero.position.y,record.state.escort_id]).to_utf8_buffer())
			if tick==30:
				var original = movement.protection.snapshot(commander.definition.definition_id)
				record.state.escort_id = -999
				check(movement.protection.snapshot(commander.definition.definition_id).state.escort_id == original.state.escort_id,"value view does not mutate executor")
	var commander := world.commanders[&"bai_jiuyang"] as CommanderState
	var hero := world.units[commander.hero_entity_id] as UnitState
	for card_id in commander.subordinate_unit_card_ids:
		(world.unit_cards[card_id] as UnitCardState).control_state = UnitCardState.ControlState.PLAYER_OVERRIDDEN
	movement.protection.advance(world)
	check(movement.protection.snapshot(&"bai_jiuyang").reason == &"NO_CORE","controlled cards cannot be borrowed as protection core")
	hero.control_state = UnitState.ControlState.TEMPORARILY_OVERRIDDEN
	hero.move_target = hero.position+Vector2(64,0)
	hero.path = PackedVector2Array([hero.position,hero.move_target])
	hero.path_index = 1
	hero.has_move_target = true
	var manual_path := hero.path.duplicate()
	movement.protection.advance(world)
	check(hero.path == manual_path and movement.protection.snapshot(&"bai_jiuyang").reason == &"PLAYER_CONTROL","diagnostic hero control not overwritten")
	var displacement := {}
	for item: CommanderState in world.commanders.values():
		var unit := world.units[item.hero_entity_id] as UnitState
		displacement[item.definition.definition_id] = unit.position.distance_to(starting[item.definition.definition_id])
		if item.definition.profile.profile_id != &"ranger": check(displacement[item.definition.definition_id] >= 500.0,"moving legion makes at least 500 progress: " + String(item.definition.definition_id))
	movement.world = null
	return {"actual_escort_path_gap":actual_path_gap,"ticks":1200,"displacement":displacement,"hash":trace.finish().hex_encode(),"reasons":reasons,"max_escort_gap":max_gap,"after_5s_escort_gap":settled_gap,"after_5s_nearest_core_gap":nearest_gap,"final_escort_gap":final_gap}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--coordinate-speed": coordinate_speed = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var runs := [run_world(),run_world()]
	check(runs[0] == runs[1],"real tick execution repeats")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PREINTEGRATION","checks":checks,"failures":failures,"runs":runs,"coordinate_speed":coordinate_speed,"scope":"1200 ticks actual core distance and travel progress; isolated pace experiment, not full B"}))
	print("LEGION38_PACE checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
