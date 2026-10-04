extends SceneTree

var failures: Array[String] = []
var routes := [
	[&"blue_top_high", &"blue_top_inner", &"red_top_inner", &"red_base"],
	[&"blue_mid_high", &"blue_mid_outer", &"blue_mid_outer", &"red_mid_high", &"red_base"],
	[&"blue_bottom_inner", &"red_bottom_inner", &"red_bottom_high", &"red_base"],
	[&"jungle_upper_rear", &"jungle_upper_major", &"blue_mid_outer", &"red_mid_outer", &"red_base"],
]
var stages := [0, 0, 0, 0]
var assigned := [false, false, false, false]

func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	print("FINAL_MATCH world ready")
	# Scripted route audit; current natural growth playtest is growth_match_selfplay.gd.
	var commanders: Array[StringName] = []
	for commander: CommanderState in world.commanders.values():
		if commander.faction_id == 1: commanders.append(commander.definition.definition_id)
	commanders.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var counts := {}
	var event_index := 0
	for tick in range(world.battle_definition.time_limit_ticks + 5):
		if tick % 50 == 0:
			var legal := world.create_faction_snapshot(1)
			for group in range(4):
				var target_id: StringName = routes[group][stages[group]]
				var target := legal.get_strategic_region(target_id)
				if target.capturable and target.controller_faction_id == 1 and not target.contested and stages[group] < routes[group].size() - 1:
					stages[group] += 1
					assigned[group] = false
					target_id = routes[group][stages[group]]
					target = legal.get_strategic_region(target_id)
				if assigned[group]: continue
				if target.capturable:
					var request := StaffPlanRequest.new()
					request.objective_region_id = target_id
					request.allowed_card_ids.assign(legal.get_commander(commanders[group]).subordinate_unit_card_ids)
					var plans := StaffPlanGenerator.new().generate(legal, 1, request)
					if plans == null: continue
					var plan: StaffCourseOfAction
					for option in plans.plans:
						if option.profile_id == &"direct_commitment": plan = option
					if plan == null: plan = plans.plans[0]
					var command := StaffPlanApprovalCommand.new(world.allocate_command_id(), 1, world.current_tick, request, plan.profile_id, plan.fingerprint())
					assigned[group] = world.submit_command(command).is_accepted()
				else:
					var command := CommanderOrderCommand.new(world.allocate_command_id(), 1, world.current_tick, commanders[group], CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE, target.position + Vector2(0, 256), target_id)
					assigned[group] = world.submit_command(command).is_accepted()
		world.advance_tick()
		while event_index < world.events.size():
			var event := world.events[event_index]
			var kind: String = SimulationEvent.Kind.keys()[event.kind]
			counts[kind] = int(counts.get(kind, 0)) + 1
			event_index += 1
		if world.current_tick % 1000 == 0 or world.battle_outcome.is_terminal():
			var owned := {1: 0, 2: 0}
			for region in world.strategic_regions.values():
				if region.capturable and owned.has(region.controller_faction_id): owned[region.controller_faction_id] += 1
			print("FINAL_MATCH tick=%d population=%d/%d supply=%d/%d points=%s stages=%s events=%s" % [world.current_tick, world.factions[1].population, world.factions[2].population, world.factions[1].supply, world.factions[2].supply, owned, stages, counts])
		if world.battle_outcome.is_terminal(): break
	if not world.battle_outcome.is_terminal(): failures.append("terminal outcome required")
	for kind in ["PROJECTILE_FIRED", "REGION_CONTROL_CHANGED", "TACTICAL_IDENTIFIED", "UNIT_CARD_REINFORCED"]:
		if int(counts.get(kind, 0)) == 0: failures.append("missing actual match event: " + kind)
	var positions: PackedStringArray = []
	var ids := world.units.keys()
	ids.sort()
	for id in ids:
		var unit := world.units[id] as UnitState
		positions.append("%d:%s:%s:%s" % [id, unit.position, unit.health, unit.enabled])
	var trace: PackedStringArray = []
	for event in world.events:
		trace.append("%d:%d:%d:%s" % [event.tick, event.kind, event.entity_id, event.detail])
	print("FINAL_MATCH_FINGERPRINT ",("|".join(positions) + "|".join(trace)).sha256_text())
	print("FINAL_MATCH_RESULT tick=%d outcome=%s failures=%s" % [world.current_tick, world.battle_outcome.result_key(), failures])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
