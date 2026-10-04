extends SceneTree


func _initialize() -> void:
	var source := load("res://data/battles/black_well.tres") as BattleDefinition
	var map := load("res://data/maps/final_decision.tres") as MapDefinition
	var battle := source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as BattleDefinition
	battle.scenario_id = &"final_decision"
	battle.display_name_key = &"FINAL_DECISION_TITLE"
	battle.operation_number = 5
	battle.scene_path = "res://scenes/game/final_decision.tscn"
	battle.selector_briefing_key = &"FINAL_DECISION_BRIEFING"
	battle.selector_mechanics_key = &"FINAL_DECISION_MECHANICS"
	battle.map_definition = map
	battle.battlefield_bounds = map.get_world_rect()
	battle.time_limit_ticks = 18000
	battle.objective_set.objective_set_id = &"final_decision_objectives"
	for group in battle.objective_set.conclusion_groups:
		if group.group_id == &"time_limit_defeat":
			group.group_id = &"time_limit_draw"
			group.outcome_result = BattleOutcome.Result.DRAW
			group.outcome_grade = BattleOutcome.Grade.NONE
			group.priority = 50
		else:
			group.priority = 100
	var mutual := ObjectiveGroupDefinition.new()
	mutual.group_id = &"mutual_headquarters_draw"
	mutual.objective_ids.assign([&"enemy_headquarters_destroyed", &"player_headquarters_destroyed"])
	mutual.outcome_result = BattleOutcome.Result.DRAW
	mutual.outcome_grade = BattleOutcome.Grade.NONE
	mutual.priority = 200
	battle.objective_set.conclusion_groups.append(mutual)
	battle.base_supply_interval_ticks = 200
	battle.base_supply_amount = 12
	battle.base_supply_faction_ids.assign([1, 2])
	battle.region_settlement_interval_ticks = 200
	battle.starting_supply = 24
	battle.supply_capacity = 300
	battle.population_capacity = 300
	battle.automatic_reinforcement = true
	battle.growth_mode = true
	battle.headquarters_health_multiplier = 4.0
	battle.reinforcement_supply_reserve = 12
	battle.recruitment_interval_ticks = 10
	battle.reinforcement_supply_radius = 1400.0
	battle.tutorial_available = false
	battle.support_abilities.clear()
	for kind in [SupportOrderCommand.SupportKind.AIR_RECON, SupportOrderCommand.SupportKind.MISSILE_BARRAGE, SupportOrderCommand.SupportKind.FIELD_HOSPITAL]:
		var support := BattleSupportDefinition.new()
		support.support_kind = kind
		if kind == SupportOrderCommand.SupportKind.AIR_RECON:
			support.support_id = &"area_recon"
			support.supply_cost = 20
			support.duration_ticks = 250
			support.cooldown_ticks = 600
			support.area_radius = 1600.0
		elif kind == SupportOrderCommand.SupportKind.MISSILE_BARRAGE:
			support.support_id = &"missile_barrage"
			support.supply_cost = 60
			support.duration_ticks = 20
			support.cooldown_ticks = 1200
			support.activation_delay_ticks = 30
			support.area_radius = 900.0
			support.damage = 180.0
		else:
			support.support_id = &"field_hospital"
			support.supply_cost = 40
			support.duration_ticks = 600
			support.cooldown_ticks = 900
			support.area_radius = 850.0
			support.health_restore = 8.0
		battle.support_abilities.append(support)
	battle.deployment_radius = 720.0
	battle.player_headquarters_position = map.cell_to_world(map.player_spawn_cell)
	battle.enemy_headquarters_position = map.cell_to_world(map.enemy_spawn_cell)
	battle.starting_card_count = 20
	battle.next_dynamic_unit_id = 5000
	battle.next_dynamic_formation_id = 201
	battle.enemy_agent_id = 305
	battle.enemy_task_id = 9401
	battle.enemy_offensive_followup_tick = 6000
	battle.initial_intel.clear()
	battle.navigation_blocked_rects.clear()
	battle.engineering_routes.clear()
	battle.withdrawal_region_id = &""
	battle.withdrawal_arrival_radius = 0.0
	battle.organization_recovery_region_id = &"blue_mid_outer"
	# A faction's headquarters is its safe recovery point; center adds no free bonus.
	battle.organization_recovery_region_bonus = 0.0
	battle.enemy_reaction_rules.clear()
	battle.strategic_regions.clear()
	var regions: Dictionary = {}
	for point in map.supply_points:
		var region := BattleRegionDefinition.new()
		region.region_id = point.point_id
		region.supply_tier = point.tier
		region.display_name_key = point.display_name_key
		region.terrain_key = &"TERRAIN_FOREST" if point.is_wild else &"TERRAIN_OPEN"
		region.position = point.position
		region.radius = point.radius
		region.capture_ticks = point.capture_ticks
		region.capturable = not point.is_base
		region.initial_controller_faction_id = point.owner_faction_id
		region.supply_per_settlement = point.supply_per_settlement
		battle.strategic_regions.append(region)
		regions[point.point_id] = region
	var region_paths: Array[Array] = []
	for lane in map.lanes:
		region_paths.append(lane.supply_point_ids)
	for connector in map.connectors:
		region_paths.append(connector.supply_point_ids)
	for path in region_paths:
		for i in range(1, path.size()):
			for pair in [[path[i - 1], path[i]], [path[i], path[i - 1]]]:
				var from := regions[pair[0]] as BattleRegionDefinition
				if not from.adjacent_region_ids.has(pair[1]):
					from.adjacent_region_ids.append(pair[1])
	# Five stable legions; commanders are independently configurable profiles.
	battle.commander_definitions.resize(4)
	var mobile := battle.commander_definitions[1].duplicate(true) as CommanderDefinition
	mobile.definition_id = &"mobile_legion"
	battle.commander_definitions.append(mobile)
	battle.commander_agent_ids[mobile.definition_id] = 206
	battle.default_posture_by_commander[mobile.definition_id] = CommanderState.Posture.BALANCED
	battle.default_doctrine_by_commander[mobile.definition_id] = battle.default_doctrine_by_commander[&"di_tian"]
	battle.default_posture_by_commander[&"lin_mo"] = CommanderState.Posture.BALANCED
	battle.default_doctrine_by_commander[&"lin_mo"] = &"overwatch_lattice"
	battle.default_posture_by_commander[&"lu_zheng"] = CommanderState.Posture.AGGRESSIVE
	var templates: Array[UnitCardDefinition] = []
	for i in range(4):
		var template := battle.unit_card_definitions[i].duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as UnitCardDefinition
		if i in [0, 2, 3]:
			var tactical := load("res://data/army/grey_ridge/%s.tres" % template.definition_id) as UnitCardDefinition
			template.tactical_ability = tactical.tactical_ability.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			if tactical.tactical_weapon_override != null:
				template.tactical_weapon_override = tactical.tactical_weapon_override.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		templates.append(template)
	battle.unit_card_definitions.clear()
	battle.default_commander_by_unit_card.clear()
	battle.default_starting_unit_card_ids.clear()
	battle.friendly_formation_ids.clear()
	battle.friendly_spawn_positions.clear()
	battle.enemy_formations.clear()
	for group in range(5):
		var commander := battle.commander_definitions[group]
		commander.capacity = 4
		commander.profile = CommanderProfile.roster()[group]
		commander.personality_key = commander.profile.personality_key
		commander.display_name_key = [&"LEGION_TOP", &"LEGION_MID", &"LEGION_BOTTOM", &"LEGION_JUNGLE", &"LEGION_MOBILE"][group]
		commander.strategic_lane_id = [&"top", &"mid", &"bottom", &"jungle", &"mobile"][group]
		for role in range(4):
			var i := group * 4 + role
			var card := templates[role].duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as UnitCardDefinition
			card.definition_id = StringName("final_group_%d_%s" % [group + 1, templates[role].definition_id])
			card.commander_definition_id = commander.definition_id
			card.authorized_strength = [12, 20, 16, 12][role]
			card.configurable_max_strength = 60
			card.starting_strength = [3, 4, 3, 2][role]
			card.recruitment_cost = [1, 2, 5, 4][role]
			if role in [1, 2]:
				card.combat_override = SimulationWorld.UNIT_CATALOG.get_unit(card.unit_definition_id).combat.duplicate() as CombatDefinition
				card.combat_override.max_health = 300 if role == 1 else 400
				card.combat_override.armor = 10 if role == 1 else 15
			if role == 3:
				card.combat_override = SimulationWorld.UNIT_CATALOG.get_unit(card.unit_definition_id).combat.duplicate() as CombatDefinition
				card.combat_override.attack_power = 50
				card.combat_override.attack_range = 420
				card.tactical_weapon_override.damage_tag = TacticalWeaponDefinition.DamageTag.EXPLOSIVE
				card.tactical_weapon_override.damage_multiplier_min = 0.4
				card.tactical_weapon_override.damage_multiplier_max = 1.6
				card.tactical_weapon_override.fixed_attack_range = 420
				card.tactical_weapon_override.health_only_damage = true
				card.tactical_weapon_override.ammunition_capacity = 0
				card.tactical_weapon_override.minimum_range = 0
				card.tactical_weapon_override.suppression = 0
				card.tactical_weapon_override.identification_required = false
				card.tactical_ability = null
				card.fallback_weapon = null
			card.recruitment_weight = 1.0
			if (commander.personality_key == &"PERSONALITY_CAUTIOUS" and role == 0) or (commander.personality_key == &"PERSONALITY_METHODICAL" and role == 3) or (commander.personality_key == &"PERSONALITY_RESOLUTE" and role == 2):
				card.recruitment_weight = 2.0
			card.composition.clear()
			card.supply_cost = 8
			card.enforce_organization_rules = true
			card.deployment_ticks = 100
			card.starts_in_reserve = false
			card.command_cost = 1
			battle.unit_card_definitions.append(card)
			battle.default_commander_by_unit_card[card.definition_id] = card.commander_definition_id
			battle.default_starting_unit_card_ids.append(card.definition_id)
			battle.friendly_formation_ids.append(i + 1)
			var spawn := battle.player_headquarters_position + Vector2((role - 1.5) * 256.0, (group - 2.0) * 256.0)
			battle.friendly_spawn_positions.append(spawn)
			var formation := BattleFormationDefinition.new()
			formation.formation_id = 101 + i
			formation.role_id = &"assault" if i == 0 else (&"probe" if i == 1 else StringName("wing_%d" % i))
			formation.unit_definition_id = card.unit_definition_id
			formation.strength = card.starting_strength
			formation.spawn_position = map.mirror_point(spawn)
			formation.facing = Vector2.UP
			formation.first_entity_id = 1001 + i * 16
			formation.agent_id = battle.enemy_agent_id
			formation.task_id = battle.enemy_task_id + i
			formation.unit_card_definition = card.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as UnitCardDefinition
			formation.unit_card_definition.definition_id = StringName("red_%s" % card.definition_id)
			formation.unit_card_definition.commander_definition_id = StringName("red_%s" % commander.definition_id)
			battle.enemy_formations.append(formation)
	battle.enemy_plans.clear()
	for plan_index in range(3):
		var plan := BattleEnemyPlanDefinition.new()
		plan.plan_id = [&"central_assault", &"western_hook", &"western_feint"][plan_index]
		plan.action_key = &"ENEMY_ACTION_CENTRAL_ASSAULT"
		plan.assault_target_region_id = &"blue_mid_outer"
		plan.assault_target_position = regions[&"blue_mid_outer"].position
		plan.probe_target_region_id = &"red_top_outer"
		plan.probe_target_position = regions[&"red_top_outer"].position
		var operation := EnemyOperationDefinition.new()
		operation.operation_id = plan.plan_id
		operation.doctrine = plan.operation_doctrine.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as EnemyOperationDoctrine
		operation.doctrine.max_committed_strength = 300
		operation.retreat_position = battle.enemy_headquarters_position + Vector2(-256, 256)
		var routes: Array = [
			[&"red_top_high", &"red_top_inner", &"red_top_outer", &"blue_top_outer", &"blue_top_inner", &"blue_top_high", &"blue_base"],
			[&"red_mid_high", &"red_mid_inner", &"red_mid_outer", &"blue_mid_outer", &"blue_mid_inner", &"blue_mid_high", &"blue_base"],
			[&"red_bottom_high", &"red_bottom_inner", &"red_bottom_outer", &"blue_bottom_outer", &"blue_bottom_inner", &"blue_bottom_high", &"blue_base"],
			[&"jungle_lower_rear", &"jungle_lower_major", &"blue_mid_outer", &"blue_mid_inner", &"blue_mid_high", &"blue_base"],
		]
		if plan_index == 1:
			routes[1] = [&"red_mid_high", &"jungle_lower_rear", &"jungle_lower_major", &"blue_bottom_inner", &"blue_bottom_high", &"blue_base"]
		elif plan_index == 2:
			routes[0] = [&"red_top_high", &"red_top_inner", &"jungle_upper_forward", &"blue_mid_outer", &"blue_mid_high", &"blue_base"]
		for i in range(battle.enemy_formations.size()):
			var itinerary: Array = routes[mini(i / 4, 3)]
			for stage in range(itinerary.size()):
				var phase := EnemyOperationPhaseDefinition.new()
				phase.phase_id = StringName("group_%d_card_%d_stage_%d" % [i / 4, i % 4, stage])
				phase.formation_role_id = battle.enemy_formations[i].role_id
				phase.target_region_id = itinerary[stage]
				phase.target_position = regions[phase.target_region_id].position
				if phase.target_region_id == &"blue_base":
					phase.target_position += Vector2(0, -256)
				phase.kind = EnemyOperationPhaseDefinition.Kind.EXPLOIT
				if stage == 0:
					phase.kind = EnemyOperationPhaseDefinition.Kind.OPENING if i < 12 else EnemyOperationPhaseDefinition.Kind.RESERVE
				else:
					phase.prerequisite_phase_ids.append(StringName("group_%d_card_%d_stage_%d" % [i / 4, i % 4, stage - 1]))
					phase.require_control_region_id = itinerary[stage - 1]
				operation.phases.append(phase)
		operation.reserve_policy = operation.reserve_policy.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as EnemyReservePolicy
		operation.reserve_policy.release_on_objective_reached = true
		operation.reserve_policy.release_phase_id = &"group_1_card_0_stage_0"
		operation.reserve_policy.max_release_strength = 60
		plan.operation = operation
		battle.enemy_plans.append(plan)
	var validation := battle.validate(SimulationWorld.UNIT_CATALOG)
	if not validation.is_valid():
		push_error(str(validation.issues))
		quit(1)
		return
	var error := ResourceSaver.save(battle, "res://data/battles/final_decision.tres")
	print("FINAL_DECISION_BATTLE_GENERATED error=%d" % error)
	quit(error)
