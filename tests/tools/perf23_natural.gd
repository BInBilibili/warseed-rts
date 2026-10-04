extends SceneTree

func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var strategy := "passive"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--strategy="): strategy=arg.trim_prefix("--strategy=")
	var policy = preload("res://tests/tools/perf23_blue_policy.gd").new(strategy)
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION,{},&"",policy.army_plan())
	var audit = preload("res://tests/tools/perf23_congestion_audit.gd").new()
	RuntimeMeasurement.reset()
	RuntimeMeasurement.enabled = true
	world.tick_profile_enabled = true
	var rejected: Dictionary = {}
	var stuck_ids: Dictionary = {}
	var stalled_samples: Dictionary = {}
	var prior_positions: Dictionary = {}
	var scripted_support := OS.get_cmdline_user_args().has("--blue-support-policy")
	var player_supports := 0
	if scripted_support:
		world.submit_command(SupplyPriorityCommand.new(world.allocate_command_id(), 1, 0, &"di_tian"))
	print("GROWTH_MATCH_POLICY blue=", strategy, " legacy_support=",scripted_support)
	var counts := {}
	var role_shots := {}
	var recruits := {}
	var max_recruits := 0
	var cursor := 0
	var peak := {1: 48, 2: 48}
	var first_combat := -1
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	for tick in range(world.battle_definition.time_limit_ticks + 1):
		policy.advance(world)
		if scripted_support and world.current_tick % 100 == 0:
			# A scripted player policy, using only blue's legal view and the same
			# purchase pipeline; no money grants or hidden state in this match.
			var support := GrowthSupportAgent.new().propose(world.create_faction_snapshot(1), world.battle_definition, 0)
			if support != null:
				support.issuer_kind = GameCommand.IssuerKind.PLAYER
				support.command_id = world.allocate_command_id()
				if world.submit_command(support).is_accepted(): player_supports += 1
		var measure_start := RuntimeMeasurement.begin()
		world.advance_tick()
		audit.sample(world)
		RuntimeMeasurement.end(&"tick.total_usec",measure_start)
		if world.current_tick % 100 == 0:
			for unit: UnitState in world.units.values():
				if not unit.enabled: continue
				var commanded: bool = unit.following_formation and world.formations.has(unit.formation_id) and world.formations[unit.formation_id].is_moving
				if commanded and unit.attack_target_entity_id == 0 and prior_positions.has(unit.entity_id) and unit.position.distance_to(prior_positions[unit.entity_id]) < 32 and unit.position.distance_to(unit.desired_position) > 64:
					stalled_samples[unit.entity_id] = int(stalled_samples.get(unit.entity_id,0)) + 1
				prior_positions[unit.entity_id] = unit.position
		while cursor < world.events.size():
			var event := world.events[cursor]
			var kind: String = SimulationEvent.Kind.keys()[event.kind]
			if event.kind == SimulationEvent.Kind.COMMAND_REJECTED: rejected[event.detail] = int(rejected.get(event.detail,0))+1
			if event.kind == SimulationEvent.Kind.UNIT_STUCK: stuck_ids[event.entity_id] = int(stuck_ids.get(event.entity_id,0))+1
			counts[kind] = int(counts.get(kind, 0)) + 1
			if event.kind == SimulationEvent.Kind.PROJECTILE_FIRED:
				var unit := world.units.get(event.entity_id) as UnitState
				if unit != null:
					var role := "%d/%s" % [unit.faction_id, UnitState.TacticalRole.keys()[unit.tactical_role]]
					role_shots[role] = int(role_shots.get(role,0)) + 1
			if event.kind == SimulationEvent.Kind.UNIT_CARD_REINFORCED and event.detail.contains("source=recruitment"):
				var count := int(event.detail.split("strength=")[1].split(";")[0])
				var key := "%d/%d" % [event.entity_id,event.tick/10]
				recruits[key] = int(recruits.get(key,0)) + count
				max_recruits = maxi(max_recruits,recruits[key])
			trace.update(("%d:%d:%d:%s\n" % [event.tick, event.kind, event.entity_id, event.detail]).to_utf8_buffer())
			if kind == "PROJECTILE_FIRED" and first_combat < 0:
				first_combat = world.current_tick
			cursor += 1
		for faction in [1, 2]:
			peak[faction] = maxi(peak[faction], world.factions[faction].population)
		if world.current_tick % 1000 == 0 or world.battle_outcome.is_terminal():
			var owned := {1: 0, 2: 0}
			for region in world.strategic_regions.values():
				if region.capturable and owned.has(region.controller_faction_id):
					owned[region.controller_faction_id] += 1
			print("GROWTH_MATCH tick=%d population=%d/%d supply=%d/%d points=%s combat=%d reinforced=%d elapsed=%.2f" % [world.current_tick, world.factions[1].population, world.factions[2].population, world.factions[1].supply, world.factions[2].supply, owned, counts.get("PROJECTILE_FIRED", 0), counts.get("UNIT_CARD_REINFORCED", 0), (Time.get_ticks_msec() - started) / 1000.0])
			for commander: CommanderState in world.commanders.values():
				var detail: Array[String] = []
				for id in commander.subordinate_unit_card_ids:
					var card := world.unit_cards[id] as UnitCardState
					var view := UnitCardSnapshot.new(card, world.units)
					detail.append("%s=%d/%d@%s task=%d" % [card.definition.role_key, view.current_strength, view.organization, view.center_position, card.assigned_task_id])
				print("GROUP %s target=%s recovering=%s %s" % [commander.definition.definition_id, commander.target_region_id, commander.growth_recovering, detail])
		if world.battle_outcome.is_terminal():
			break
	var hero_events: Array[Dictionary] = []
	for event in world.events:
		if event.detail.begins_with("HERO_") or event.detail.begins_with("LEGION_REASSEMBLED"):
			hero_events.append({"tick":event.tick,"entity":event.entity_id,"detail":event.detail})
	FileAccess.open("res://artifacts/hero24-lifecycle-%s.json" % strategy,FileAccess.WRITE).store_string(JSON.stringify(hero_events))
	var failures: Array[String] = []
	if max_recruits>5: failures.append("recruitment window exceeded five")
	for faction in [1,2]:
		for role in ["SCOUT","FIREPOWER"]:
			if int(role_shots.get("%d/%s" % [faction,role],0))==0: failures.append("no real combat for %d/%s" % [faction,role])
	print("COMBAT20_NATURAL shots=",role_shots," max_recruits_per_second=",max_recruits)
	if not world.battle_outcome.is_terminal(): failures.append("no outcome")
	for kind in ["PROJECTILE_FIRED", "REGION_CONTROL_CHANGED", "UNIT_CARD_REINFORCED"]:
		if counts.get(kind, 0) == 0: failures.append("missing " + kind)
	var fingerprint := trace.finish().hex_encode()
	print("GROWTH_MATCH_RESULT evidence=SIMULATED tick=%d game_seconds=%.1f wall_seconds=%.2f first_combat=%d peak=%s outcome=%s fingerprint=%s failures=%s" % [world.current_tick, world.current_tick / 10.0, (Time.get_ticks_msec() - started) / 1000.0, first_combat, peak, world.battle_outcome.result_key(), fingerprint, failures])
	print("GROWTH_MATCH_EVENTS ", counts)
	print("GROWTH_MATCH_PLAYER_SUPPORTS ", player_supports)
	var output_path := "res://artifacts/perf23-natural.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output_path = arg.trim_prefix("--report=")
	var report := {"role_shots":role_shots,"peak":peak,"first_combat":first_combat,"outcome":world.battle_outcome.result_key(),"fingerprint":fingerprint,"strategy":strategy,"player_actions":policy.actions,"congestion_episodes":audit.finish(world.current_tick),"measurements":RuntimeMeasurement.summary(),"rejections":rejected,"stuck_per_unit":stuck_ids,"slow_10s_samples":stalled_samples,"tick":world.current_tick,"events":counts,"max_recruits":max_recruits,"failures":failures}
	RuntimeMeasurement.enabled=false
	FileAccess.open(output_path,FileAccess.WRITE).store_string(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
