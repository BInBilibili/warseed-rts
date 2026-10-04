extends "res://tests/tools/legion35_recruitment_contract.gd"

const HERO_ROWS := [[800,22,165,36,190,6,900], [900,22,150,28,200,8,900], [560,14,150,24,260,8,950], [500,10,195,26,240,6,900], [650,16,190,30,200,6,950]]

func check_numbers(actual: Array, expected: Array, label: String) -> void:
	for index in range(expected.size()):
		check(absf(float(actual[index]) - float(expected[index])) < 0.00001, label + " field=" + str(index) + " actual=" + str(actual[index]) + " expected=" + str(expected[index]))

func test_hero_parameters_and_respawn() -> void:
	for faction_id in [1, 2]:
		for index in range(5):
			var world := fresh()
			var commander := leader(world, LegionTemplate.PROFILE_IDS[index], faction_id)
			var hero := world.units[commander.hero_entity_id] as UnitState
			var old_id := hero.entity_id
			check_numbers([hero.max_health, hero.armor, hero.move_speed, hero.attack_damage, hero.attack_range, hero.attack_cooldown_ticks, hero.sight_range], HERO_ROWS[index], "actual opening hero uses all seven documented parameters")
			hero.health = 0
			hero.enabled = false
			LegionHeroSystem.advance(world)
			check(commander.legion_regrouping and commander.hero_respawn_tick == 400, "real hero death starts regroup and correct revival clock")
			world.current_tick = 400
			LegionHeroSystem.advance(world)
			hero = world.units[commander.hero_entity_id]
			check(hero.entity_id != old_id and hero.enabled, "real revival creates a new live hero")
			check_numbers([hero.max_health, hero.armor, hero.move_speed, hero.attack_damage, hero.attack_range, hero.attack_cooldown_ticks, hero.sight_range], HERO_ROWS[index], "revival preserves legion parameters without soldier buffs")
			world._refresh_battle_population()
			check(world.factions[faction_id].population == 60, "revival does not consume soldier population")

func test_scout_capture_and_weapon() -> void:
	for faction_id in [1, 2]:
		for profile in LegionTemplate.PROFILE_IDS:
			var world := fresh()
			var commander := leader(world, profile, faction_id)
			var scout_card := next_card(world, commander, 0)
			var scout := world.units[scout_card.member_entity_ids[0]] as UnitState
			var armed := profile == &"sentinel"
			check(scout.tactical_role == UnitState.TacticalRole.SCOUT and scout.scout_capture_allowed == armed, "capture permission is exclusive and keeps scout role")
			check(scout_card.definition.recruitment_cost == (2 if armed else 1), "exclusive recon replacement cost")
			if armed:
				check_numbers([scout.max_health, scout.base_armor, scout.base_move_speed, scout.base_attack_damage, scout.base_attack_range, scout.primary_cooldown_ticks, scout.base_sight_range], [180,4,210,24,220,8,792], "armed recon documented combat and aura parameters")
			for unit: UnitState in world.units.values(): unit.enabled = unit == scout
			var region: StrategicRegionState
			for candidate: StrategicRegionState in world.strategic_regions.values():
				if candidate.capturable and candidate.controller_faction_id == 0:
					region = candidate
					break
			scout.position = region.position
			for tick in range(region.capture_required_ticks):
				world._advance_strategic_regions()
				world.current_tick += 1
			check(region.controller_faction_id == (faction_id if armed else 0), "actual region capture honors exclusive scout qualification")
			if armed:
				region.controller_faction_id = 0
				region.capture_faction_id = 0
				region.capture_progress_ticks = 0
				scout.legion_returning = true
				world._advance_strategic_regions()
				check(region.capture_progress_ticks == 0, "armed scouts returning after hero death cannot capture")
				scout.legion_returning = false
				scout_card.organization = 0
				world._advance_strategic_regions()
				check(region.capture_progress_ticks == 0, "armed recon cannot bypass zero organization capture restriction")
				scout_card.organization = 100
				var target := world.units[leader(world, &"guardian", 3 - faction_id).hero_entity_id] as UnitState
				target.enabled = true
				target.position = scout.position + Vector2(100, 0)
				scout.attack_target_entity_id = target.entity_id
				var before := target.health
				var next_projectile := 1
				for tick in range(8):
					next_projectile = CombatSystem.new().advance(world.units, world.buildings, world.projectiles, next_projectile, world.events, world.current_tick + tick)
				check(scout.weapon_shots_fired > 0 and target.health < before, "actual armed scout projectile damages an opponent")

func test_malformed_templates() -> void:
	for mutation in ["opening", "growth_role", "growth_count", "full", "recovery_duplicate", "recovery_minimum", "nan_hero", "unknown_profile"]:
		var template := LegionTemplate.find(&"spear").duplicate(true) as LegionTemplate
		match mutation:
			"opening": template.opening[0] = -1
			"growth_role": template.growth_roles[0] = 4
			"growth_count": template.growth_roles.resize(47)
			"full": template.full[0] += 1
			"recovery_duplicate": template.recovery_roles[1] = template.recovery_roles[0]
			"recovery_minimum": template.recovery_minimums[0] = 100
			"nan_hero": template.hero_health = NAN
			"unknown_profile": template.profile_id = &"unknown"
		check(not template.validation_errors().is_empty(), "malformed template is rejected " + mutation)
		var world := fresh()
		var card := next_card(world, leader(world)).definition.duplicate(true) as UnitCardDefinition
		card.legion_template = template
		check(not UnitCardCompositionCompiler.validate(card, SimulationWorld.UNIT_CATALOG).is_valid(), "invalid template rejected through content compiler " + mutation)
	check(LegionTemplate.find(&"spear").validation_errors().is_empty(), "invalid fixtures never poison cached source resource")

func test_actual_recovery_priorities() -> void:
	# Frozen section 8 role/minimum requirements, independent of template arrays.
	var priorities := [[[2,2],[1,3],[0,1]], [[1,3],[2,2],[3,1],[0,1]], [[1,4],[2,2],[3,2],[0,1]], [[1,4],[2,1],[0,2]], [[1,4],[2,2],[0,1]]]
	for faction_id in [1, 2]:
		for index in range(5):
			var world := fresh()
			var commander := leader(world, LegionTemplate.PROFILE_IDS[index], faction_id)
			for card_id in commander.subordinate_unit_card_ids:
				var card := world.unit_cards[card_id] as UnitCardState
				for id in card.member_entity_ids:
					world.units[id].enabled = false
					world.units[id].health = 0
				card.last_damage_tick = 0
			world._refresh_battle_population()
			var bought := 0
			var cost := 0
			for requirement in priorities[index]:
				for member in range(requirement[1]):
					world.current_tick += 10
					var card := next_card(world, commander)
					check(card.definition.role_key == LegionTemplate.ROLE_KEYS[requirement[0]], "actual casualty recovery selects documented critical role first")
					var price := card.definition.recruitment_cost
					check(world.submit_command(order(world, card)).is_accepted(), "critical role replacement admitted after rebuild wait")
					apply_queue(world)
					bought += 1
					cost += price
					check(world.factions[faction_id].population == 48 + bought, "each recovered member born exactly once")
					check(world.factions[faction_id].supply == 300 - cost, "critical replacements pay actual role costs")
			check(commander.growth_unlocked_slots == 12, "recovery does not unlock unearned growth slots")

func _initialize() -> void:
	test_hero_parameters_and_respawn()
	test_scout_capture_and_weapon()
	test_malformed_templates()
	test_actual_recovery_priorities()
	FileAccess.open("res://artifacts/legion36/content.json", FileAccess.WRITE).store_string(JSON.stringify({"evidence": "SIMULATED", "checks": checks, "failures": failures, "scope": "both-faction hero spawn/revival, scout capture/weapon/organization and malformed typed resources"}))
	print("LEGION36_CONTENT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
