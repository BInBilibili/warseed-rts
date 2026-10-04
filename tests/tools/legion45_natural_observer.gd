extends SceneTree

var checks := 0
var failures: Array[String] = []
var cohesion := {}

func observe_cohesion(world: SimulationWorld) -> void:
	for commander: CommanderState in world.commanders.values():
		var hero := world.units.get(commander.hero_entity_id) as UnitState
		if hero==null or not hero.enabled or commander.legion_regrouping: continue
		var record := world.legion_formation_system.snapshot(commander.definition.definition_id)
		var escort := world.units.get(record.state.escort_id) as UnitState
		var key := String(commander.definition.definition_id)+":"+String(record.reason)
		if not cohesion.has(key): cohesion[key]={"ticks":0,"max_gap":0.0,"max_path":0.0,"over_240_ticks":0,"no_escort_ticks":0,"first_over_240":-1}
		var stats: Dictionary=cohesion[key]
		stats.ticks+=1
		if escort==null or not escort.enabled:
			stats.no_escort_ticks+=1
			continue
		var path := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,hero.position,escort.position)
		var distance := LegionProtectionPlanner.path_length(path) if not path.is_empty() else 1.0e12
		stats.max_gap=maxf(stats.max_gap,hero.position.distance_to(escort.position))
		stats.max_path=maxf(stats.max_path,distance)
		if distance>240.01:
			stats.over_240_ticks+=1
			if stats.first_over_240<0: stats.first_over_240=world.current_tick
		# Rejoining/exposed/retreat states are measured, never relabelled as protected.
		if commander.posture!=CommanderState.Posture.DISENGAGE and record.reason in [&"FORMING",&"IN_POSITION"]:
			check(distance<=240.01,"natural forming/in-position actual escort path <=240: "+String(commander.definition.definition_id))

func check(value: bool, message: String) -> void:
	checks += 1
	if not value and not failures.has(message):
		failures.append(message)
		push_error(message)

func fields(detail: String) -> Dictionary:
	var result := {}
	for part in detail.split(";"):
		var separator := part.find("=")
		if separator >= 0: result[part.substr(0, separator)] = part.substr(separator + 1)
	return result

func run_match(repeat: int) -> Dictionary:
	cohesion={}
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var ledger := {1: {"opening": world.factions[1].supply, "income": 0, "recruitment": 0, "support": 0, "other": 0}, 2: {"opening": world.factions[2].supply, "income": 0, "recruitment": 0, "support": 0, "other": 0}}
	var groups := {}
	var previous_slots := {}
	var seen_slots := {}
	var births: Array[Dictionary] = []
	var samples: Array[Dictionary] = []
	var event_tick_hashes: Array[String] = []
	var state_samples: Array[Dictionary] = []
	var formation_observations: Array[Dictionary] = []
	var event_stream := FileAccess.open("res://artifacts/legion45/events%d.jsonl" % repeat,FileAccess.WRITE)
	var cursor := world.events.size()
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	for commander: CommanderState in world.commanders.values():
		var id := commander.definition.definition_id
		var times := {}
		for size in [12,24,36,48,60]: times[size] = {"unlocked": 0 if size == 12 else -1, "alive": 0 if size == 12 else -1, "rejoined": 0 if size == 12 else -1}
		groups[id] = {"faction": commander.faction_id, "profile": commander.definition.profile.profile_id, "milestones": times, "growth_spend": 0, "replacement_spend": 0, "births": 0, "replacement_births": 0, "wait_seconds": {}}
		previous_slots[id] = commander.growth_slot_entities.duplicate()
		seen_slots[id] = {}
		for slot in range(12): seen_slots[id][slot] = true
	for step in range(world.battle_definition.time_limit_ticks + 1):
		world.advance_tick()
		observe_cohesion(world)
		for commander: CommanderState in world.commanders.values():
			var id := commander.definition.definition_id
			var alive := 0
			var rejoined := 0
			for slot in range(commander.growth_unlocked_slots):
				var entity := commander.growth_slot_entities[slot]
				if entity != previous_slots[id][slot] and entity != 0:
					var unit := world.units.get(entity) as UnitState
					check(unit != null, "bound slot refers to actual born entity")
					if unit != null:
						var card := world.unit_cards[unit.unit_card_id] as UnitCardState
						var cost := card.definition.recruitment_cost
						var replacement: bool = seen_slots[id].has(slot)
						groups[id]["replacement_spend" if replacement else "growth_spend"] += cost
						groups[id]["births"] += 1
						if replacement: groups[id]["replacement_births"] += 1
						births.append({"tick": world.current_tick, "commander": id, "slot": slot, "entity": entity, "cost": cost, "replacement": replacement})
						seen_slots[id][slot] = true
				var unit := world.units.get(entity) as UnitState
				if unit == null or not unit.enabled: continue
				alive += 1
				if not unit.rejoin_pending and not unit.legion_returning: rejoined += 1
			previous_slots[id] = commander.growth_slot_entities.duplicate()
			for size in [12,24,36,48,60]:
				var milestone: Dictionary = groups[id].milestones[size]
				if milestone.unlocked < 0 and commander.growth_unlocked_slots >= size: milestone.unlocked = world.current_tick
				if milestone.alive < 0 and alive >= size: milestone.alive = world.current_tick
				if milestone.rejoined < 0 and rejoined >= size: milestone.rejoined = world.current_tick
		var tick_trace := HashingContext.new()
		tick_trace.start(HashingContext.HASH_SHA256)
		while cursor < world.events.size():
			var event := world.events[cursor]
			var encoded := ("%d:%d:%d:%s\n" % [event.tick,event.kind,event.entity_id,event.detail]).to_utf8_buffer()
			trace.update(encoded)
			tick_trace.update(encoded)
			event_stream.store_line(JSON.stringify({"tick":event.tick,"kind":event.kind,"entity":event.entity_id,"detail":event.detail}))
			if event.kind == SimulationEvent.Kind.SUPPLY_CHANGED and ledger.has(event.entity_id):
				var values := fields(event.detail)
				check(values.has("delta"), "every natural supply event has an auditable delta")
				var delta := int(values.get("delta", 0))
				var source: String = values.get("source", "")
				if delta > 0: ledger[event.entity_id].income += delta
				elif source == "recruitment": ledger[event.entity_id].recruitment -= delta
				elif source in ["area_support", "support"]: ledger[event.entity_id].support -= delta
				else: ledger[event.entity_id].other += delta
			cursor += 1
		event_tick_hashes.append(tick_trace.finish().hex_encode())
		for faction_id in [1,2]:
			var faction := world.factions[faction_id] as FactionState
			var account: Dictionary = ledger[faction_id]
			check(faction.supply == account.opening + account.income - account.recruitment - account.support + account.other, "actual supply reconciles with event ledger faction=" + str(faction_id))
			check(faction.supply >= 0 and faction.supply <= faction.supply_capacity, "natural supply bounds")
			var total := 0
			for id in faction.recruited_by_commander:
				total += faction.recruited_by_commander[id]
				check(faction.recruited_by_commander[id] <= faction.recruitment_rates.get(id, 2 if faction.priority_commander_id == id else 1), "actual births respect current per-legion quota")
			check(total <= 5, "actual natural births never exceed five per window")
			check(faction.population <= 300, "actual natural population <=300")
			check(faction.recruitment_arbitration.reserved_amount <= 5, "natural reservation bounded")
		if world.current_tick % 10 == 0:
			for id in groups:
				var faction := world.factions[groups[id].faction] as FactionState
				var reason: StringName = faction.recruitment_arbitration.reasons.get(id, &"UNKNOWN")
				groups[id].wait_seconds[reason] = groups[id].wait_seconds.get(reason, 0) + 1
		if world.current_tick % 100 == 0:
			var state_trace := HashingContext.new()
			state_trace.start(HashingContext.HASH_SHA256)
			var unit_ids := world.units.keys()
			unit_ids.sort()
			for entity_id in unit_ids:
				var unit := world.units[entity_id] as UnitState
				state_trace.update(var_to_bytes([unit.entity_id,unit.faction_id,unit.position,unit.health,unit.enabled,unit.ammunition,unit.attack_target_entity_id,unit.formation_id,unit.unit_card_id,unit.move_target,unit.path,unit.path_index]))
			var formation_trace := HashingContext.new()
			formation_trace.start(HashingContext.HASH_SHA256)
			var commander_ids := world.commanders.keys()
			commander_ids.sort_custom(func(a: StringName,b: StringName) -> bool: return String(a)<String(b))
			for commander_id in commander_ids:
				var commander: CommanderState = world.commanders[commander_id]
				var record: LegionFormationState = world.legion_formation_system.records[commander_id]
				formation_trace.update(var_to_bytes([commander_id,record.reason,record.target,record.core_speed,record.state.escort_id,record.state.facing,record.state.pending_facing,record.state.pending_since,record.state.retreat_version,record.state.retreat_direction]))
				if record.batch_plan != null:
					check(record.batch_plan.valid,"natural stable identity plan valid")
					formation_trace.update(var_to_bytes([record.batch_plan.epoch,record.batch_plan.reason,record.batch_plan.advance_ready,record.batch_plan.pending_identities]))
					for member in record.batch_plan.members:
						formation_trace.update(var_to_bytes([member.identity,member.entity_id,member.availability,member.batch,member.ordinal,member.offset]))
				var hero: UnitState = world.units.get(commander.hero_entity_id)
				var escort: UnitState = world.units.get(record.state.escort_id)
				var eligible := hero != null and hero.enabled and not commander.legion_regrouping and hero.control_state == UnitState.ControlState.AGENT_ASSIGNED and escort != null and escort.enabled
				formation_observations.append({"tick":world.current_tick,"commander":commander_id,"reason":record.reason,"core_speed":record.core_speed,"hero_alive":hero != null and hero.enabled,"escort_alive":escort != null and escort.enabled,"measured_gap":hero.position.distance_to(escort.position) if eligible else -1.0,"regrouping":commander.legion_regrouping,"pending":record.batch_plan.pending_identities.size() if record.batch_plan != null else -1})
			state_samples.append({"tick":world.current_tick,"unit_state_hash":state_trace.finish().hex_encode(),"formation_state_hash":formation_trace.finish().hex_encode()})
			samples.append({"tick": world.current_tick, "population": [world.factions[1].population, world.factions[2].population], "supply": [world.factions[1].supply, world.factions[2].supply]})
		if world.current_tick % 1000 == 0 or world.battle_outcome.is_terminal():
			print("LEGION45_NATURAL_PROGRESS repeat=",repeat," tick=",world.current_tick," births=",births.size()," population=",[world.factions[1].population,world.factions[2].population]," supply=",[world.factions[1].supply,world.factions[2].supply]," failures=",failures.size())
		if world.battle_outcome.is_terminal(): break
	check(world.battle_outcome.is_terminal(), "natural match reaches authoritative terminal outcome")
	for faction_id in [1,2]:
		var birth_cost := 0
		for group in groups.values():
			if group.faction == faction_id: birth_cost += group.growth_spend + group.replacement_spend
		check(birth_cost == ledger[faction_id].recruitment, "every natural recruitment debit matches new slot entity")
		ledger[faction_id]["closing"] = world.factions[faction_id].supply
	event_stream.close()
	return {"cohesion":cohesion,"formation_observations":formation_observations,"event_tick_hashes":event_tick_hashes,"state_samples":state_samples,"repeat":repeat,"tick":world.current_tick,"outcome":world.battle_outcome.result_key(),"terminal":world.battle_outcome.is_terminal(),"event_hash":trace.finish().hex_encode(),"ledger":ledger,"commanders":groups,"births":births,"samples":samples}

func _initialize() -> void:
	var reports: Array[Dictionary] = []
	for repeat in range(2):
		var report := run_match(repeat)
		reports.append(report)
		FileAccess.open("res://artifacts/legion45/natural%d.json" % repeat, FileAccess.WRITE).store_string(JSON.stringify(report))
	if reports.size() == 2:
		check(reports[0].cohesion==reports[1].cohesion,"natural per-tick cohesion observations repeat")
		check(reports[0].formation_observations == reports[1].formation_observations,"natural formation observations repeat")
		check(reports[0].state_samples == reports[1].state_samples,"natural sampled physical unit states repeat")
		check(reports[0].event_tick_hashes == reports[1].event_tick_hashes,"natural per-tick event hashes repeat")
		check(reports[0].event_hash == reports[1].event_hash, "natural identical input repeats all authority events")
		check(reports[0].ledger == reports[1].ledger and reports[0].commanders == reports[1].commanders and reports[0].births == reports[1].births, "natural accounting and growth timelines repeat")
	FileAccess.open("res://artifacts/legion45/natural.json", FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED","checks":checks,"failures":failures,"runs":reports,"scope":"natural final-decision on production escort/pace and stable identity runtime; full B/C/D remain incomplete","rejoined_definition":"alive, not rejoin_pending, not legion_returning; not tactical core readiness"}))
	print("LEGION45_NATURAL checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
