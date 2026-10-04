extends SceneTree

const Protection = preload("res://artifacts/legion38/staging/legion_protection_system.gd")

class MovementHook extends FormationMovementSystem:
	var world: SimulationWorld
	var protection := Protection.new()
	func _init(owner: SimulationWorld) -> void:
		world = owner
		super(owner.logic_grid,owner.pathfinder,owner.formation_movement.sustained_recovery)
	func advance(formations: Dictionary, units: Dictionary, events: Array[SimulationEvent], current_tick: int) -> void:
		super(formations,units,events,current_tick)
		protection.advance(world)

var checks := 0
var failures: Array[String] = []
var output := "res://artifacts/legion38/execution02.json"
func check(value: bool, reason: String) -> void:
	checks += 1
	if not value and not failures.has(reason): failures.append(reason)

func run_world() -> Dictionary:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var movement := MovementHook.new(world)
	world.formation_movement = movement
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	var reasons := {}
	var max_gap := {}
	var settled_gap := {}
	var nearest_gap := {}
	var final_gap := {}
	for tick in range(300):
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
					if nearest < INF: nearest_gap[commander.definition.definition_id] = maxf(nearest_gap.get(commander.definition.definition_id,0.0),nearest)
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
	movement.world = null
	return {"hash":trace.finish().hex_encode(),"reasons":reasons,"max_escort_gap":max_gap,"after_5s_escort_gap":settled_gap,"after_5s_nearest_core_gap":nearest_gap,"final_escort_gap":final_gap}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var runs := [run_world(),run_world()]
	check(runs[0] == runs[1],"real tick execution repeats")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PREINTEGRATION","checks":checks,"failures":failures,"runs":runs,"scope":"staged executor in real tick pipeline, not full B integration"}))
	print("LEGION38_EXECUTION checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
