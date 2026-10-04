extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	check(world.battle_definition.validate(SimulationWorld.UNIT_CATALOG).is_valid(), "typed battle validates")
	var artillery_cards := 0
	for card: UnitCardState in world.unit_cards.values():
		if card.definition.role_key != &"UNIT_CARD_ROLE_FIREPOWER": continue
		artillery_cards += 1
		var local_validation := DataValidationResult.new()
		world.battle_definition._validate_card_tactics(card.definition, null, local_validation)
		check(local_validation.is_valid(), "ordinary weapon local validation allows absent external catalog")
		check(card.definition.tactical_ability == null and card.definition.fallback_weapon == null, "no suppress action or secondary weapon")
		var weapon := card.definition.tactical_weapon_override
		check(weapon.health_only_damage and weapon.fixed_attack_range == 420 and weapon.minimum_range == 0 and weapon.ammunition_capacity == 0 and weapon.suppression == 0 and not weapon.identification_required, "single infinite health-only missile")
		world._apply_field_reinforcement(card, 2)
		world._bind_unit_card_members(card)
		for id in card.member_entity_ids:
			var unit: UnitState = world.units[id]
			check(unit.primary_weapon == weapon and unit.ammunition_capacity == 0 and unit.ammunition == 0 and unit.minimum_attack_range == 0 and unit.suppression_power == 0 and unit.fallback_weapon == null and not unit.identification_required, "birth and reinforcement bind ordinary weapon")
			check(unit.attack_range == 420 and unit.attack_damage == 50 * unit.commander_attack_multiplier, "range and commander damage modifiers")
	check(artillery_cards == 10, "both factions five artillery cards")
	var card: UnitCardState = world.unit_cards[&"final_group_1_thunder_fire_group"]
	var attacker: UnitState = world.units[card.member_entity_ids[0]]
	var original_range := attacker.attack_range
	for region in world.battle_definition.strategic_regions:
		attacker.position = region.position
		world._update_grey_ridge_terrain_effects()
		check(attacker.attack_range == original_range and original_range == 420, "terrain preserves fixed420")
	var first := _shoot_sequence(attacker, 1)
	var second := _shoot_sequence(attacker, 1)
	check(first == second and first.size() > 4, "unlimited deterministic repeated attacks")
	var unique := {}
	for damage in first:
		check(damage >= 20 and damage <= 80, "base roll within20-80")
		unique[damage] = true
	check(unique.size() > 4, "damage varies by shot")
	_shoot_sequence(attacker, 420)
	check(_shoot_sequence(attacker, 421).is_empty(), "outside420 never fires")
	_test_health_only(world, card, attacker)
	_test_autonomy()
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		var help := TacticalHelp.growth_unit(card.definition, CommanderProfile.find(&"sentinel"))
		check(help.contains("20–80") and help.contains("420") and not help.contains("LEGION_MISSILE_STATS"), "localized range and unlimited help")
		var current := TacticalHelp.current_unit(UnitSnapshot.new(attacker), card.definition)
		check(current.contains("20–80") and current.contains("420"), "live tooltip range")
	var invalid := card.definition.tactical_weapon_override.duplicate() as TacticalWeaponDefinition
	invalid.suppression = 1
	check(not invalid.validate().is_valid(), "reject health-only suppression")
	invalid.suppression = 0
	invalid.fixed_attack_range = NAN
	check(not invalid.validate().is_valid(), "reject invalid fixed range")
	var report := {"evidence": "SIMULATED", "checks": checks, "failures": failures, "damage_sequence": first}
	FileAccess.open("res://artifacts/artillery26-contract01.json", FileAccess.WRITE).store_string(JSON.stringify(report))
	print("ARTILLERY26_CONTRACT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _shoot_sequence(source: UnitState, distance: float) -> Array[float]:
	var shooter := UnitState.new(8001, Vector2.ZERO, 135, 1)
	shooter.configure_tactical_weapon(source.primary_weapon)
	shooter.attack_damage = 50
	shooter.attack_range = 420
	shooter.attack_cooldown_ticks = 20
	shooter.projectile_speed = 420
	shooter.attack_target_entity_id = 8002
	var target := UnitState.new(8002, Vector2(distance, 0), 0, 2)
	target.health = 100000
	target.max_health = 100000
	target.armor = 0
	var units := {8001: shooter, 8002: target}
	var projectiles := {}
	var events: Array[SimulationEvent] = []
	var next := 1
	var damages: Array[float] = []
	var combat := CombatSystem.new()
	for tick in range(300):
		var before := next
		next = combat.advance(units, {}, projectiles, next, events, tick)
		if next > before:
			var projectile: ProjectileState = projectiles[next - 1]
			damages.append(projectile.attack_power)
			check(projectile.weapon_mode == 1 and projectile.health_only_damage and projectile.suppression_power == 0, "all projectiles are health-only missiles")
	check(shooter.ammunition == 0 and shooter.ammunition_capacity == 0 and not shooter.using_fallback_weapon, "no ammo accounting or weapon switch")
	check(target.pending_suppression == 0, "no direct organization pressure")
	for event in events: check(event.kind != SimulationEvent.Kind.SUPPRESSION_APPLIED, "no suppression event")
	if distance <= 420: check(target.health < target.max_health and damages.size() >= 14, "real HP damage beyond four shots")
	return damages

func _test_health_only(world: SimulationWorld, _source_card: UnitCardState, attacker: UnitState) -> void:
	var target_card: UnitCardState
	for candidate: UnitCardState in world.unit_cards.values():
		if candidate.faction_id == 2 and candidate.definition.role_key == &"UNIT_CARD_ROLE_ASSAULT":
			target_card = candidate
			break
	var target: UnitState = world.units[target_card.member_entity_ids[0]]
	attacker.position = Vector2.ZERO
	attacker.attack_target_entity_id = 0
	target.position = Vector2.ZERO
	var participants := {attacker.entity_id: attacker, target.entity_id: target}
	var projectiles := {}
	var events: Array[SimulationEvent] = []
	var combat := CombatSystem.new()
	for stage in range(4):
		target.health = 200 if stage != 1 else 10
		target.enabled = true
		target_card.organization = 80
		world._reset_unit_card_organization_baseline(target_card)
		var shot := ProjectileState.new(stage + 1, attacker.entity_id, target.entity_id, 1, Vector2.ZERO, 420, 50, -1)
		shot.health_only_damage = stage != 2
		projectiles[stage + 1] = shot
		if stage == 3:
			projectiles[100] = ProjectileState.new(100, attacker.entity_id, target.entity_id, 1, Vector2.ZERO, 420, 40, -1)
		world.current_tick = stage
		combat.advance(participants, {}, projectiles, stage + 2, events, stage)
		world._advance_unit_card_organization()
		check(target.health < (200 if stage != 1 else 10), "projectile HP loss")
		check(target_card.organization == 80 if stage < 2 else target_card.organization < 80, "missile hit/death exempts organization; normal and mixed damage still affect it")
		if stage == 3:
			check(is_equal_approx(target_card.organization, 80 - maxf(1, 40 - target.armor) * world.battle_definition.organization_damage_factor), "mixed damage only deducts normal-hit organization")
		check(target.pending_health_only_loss == 0 and not target.pending_health_only_death, "per-tick damage accounting cleared")

func _test_autonomy() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var card: UnitCardState = world.unit_cards[&"final_group_1_thunder_fire_group"]
	var attacker: UnitState = world.units[card.member_entity_ids[0]]
	for unit: UnitState in world.units.values():
		if unit != attacker and unit.hero_commander_id.is_empty(): unit.enabled = false
	attacker.position = Vector2(16384, 12288)
	attacker.following_formation = false
	attacker.has_move_target = false
	attacker.control_state = UnitState.ControlState.PLAYER_CONTROLLED
	card.persistent_manual = true
	card.control_state = UnitCardState.ControlState.PLAYER_CONTROLLED
	for commander: CommanderState in world.commanders.values(): commander.posture = CommanderState.Posture.HOLD
	var target := UnitState.new(999001, attacker.position + Vector2(30, 0), 0, 2)
	target.health = 10000
	target.max_health = 10000
	target.armor = 0
	world.units[target.entity_id] = target
	world._update_faction_knowledge()
	for tick in range(150): world.advance_tick()
	var shots := 0
	for event in world.events:
		if event.kind == SimulationEvent.Kind.PROJECTILE_FIRED and event.entity_id == attacker.entity_id: shots += 1
	check(shots > 4 and target.health < 10000, "autonomous close-range missile fire without general fire command or identification")
