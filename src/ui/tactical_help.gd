class_name TacticalHelp
extends RefCounted


static func posture(value: int) -> String:
	var posture_name: String = CommanderState.Posture.keys()[value]
	return GameText.t(&"COMMANDER_POSTURE_DETAIL") % [
		GameText.t(StringName("COMMANDER_POSTURE_%s" % posture_name)),
		GameText.t(StringName("COMMANDER_POSTURE_%s_TOOLTIP" % posture_name)),
	]


static func personality(key: StringName, growth: bool = false) -> String:
	if growth: return GameText.t(StringName("GROWTH_%s_TOOLTIP" % key))
	return GameText.t(&"PREBATTLE_PERSONALITY_TOOLTIP") % [GameText.t(key), GameText.t(StringName("%s_TOOLTIP" % key))]


static func personality_name(key: StringName, growth: bool = false) -> String:
	return GameText.t(StringName("GROWTH_%s" % key)) if growth else GameText.t(key)

static func growth_unit(definition: UnitCardDefinition, profile: CommanderProfile) -> String:
	# Preview may be showing a newly swapped general before restarting the
	# world. Derive its fixed stats on a private copy, never on live content.
	var template := LegionTemplate.find(profile.profile_id)
	var role := LegionTemplate.ROLE_KEYS.find(definition.role_key)
	if template != null and role >= 0:
		definition = definition.duplicate(true) as UnitCardDefinition
		GrowthArmyConfiguration.configure_card(definition, template, role)
	var unit := SimulationWorld.UNIT_CATALOG.get_unit(definition.unit_definition_id)
	var combat := definition.combat_override if definition.combat_override != null else unit.combat
	var speed := 200.0 if definition.unit_definition_id == &"scout_vehicle" else unit.move_speed
	var text := GameText.t(&"LEGION_UNIT_STATS") % [combat.max_health * profile.health_multiplier, combat.armor, speed * profile.speed_multiplier, combat.attack_power * profile.attack_multiplier, combat.attack_range, 1.0 / combat.attacks_per_second] + "\n" + GameText.t(&"LEGION_UNIT_COST") % definition.recruitment_cost
	if definition.tactical_weapon_override != null and definition.tactical_weapon_override.health_only_damage:
		var weapon := definition.tactical_weapon_override
		text = GameText.t(&"LEGION_MISSILE_STATS") % [combat.max_health * profile.health_multiplier, combat.armor, speed * profile.speed_multiplier, combat.attack_power * weapon.damage_multiplier_min * profile.attack_multiplier, combat.attack_power * weapon.damage_multiplier_max * profile.attack_multiplier, weapon.fixed_attack_range, 1.0 / combat.attacks_per_second, weapon.preparation_ticks / 10.0]
		text += "\n" + GameText.t(&"LEGION_UNIT_COST") % definition.recruitment_cost

	if definition.fallback_weapon != null:
		var weapon := definition.tactical_weapon_override
		var fallback := definition.fallback_weapon
		text += "\n" + GameText.t(&"LEGION_DUAL_STATS") % [weapon.minimum_range, combat.attack_range, weapon.preparation_ticks / 10.0, weapon.damage_multiplier_min, weapon.damage_multiplier_max, fallback.attack_power * profile.attack_multiplier, fallback.attack_range, 1.0 / fallback.attacks_per_second]
		text += "\n" + GameText.t(&"LEGION_MAGAZINE_STATS") % weapon.ammunition_capacity
	var sight := 720.0 if role == 0 and template != null and template.armed_recon else unit.sight_range
	text += "\n" + GameText.t(&"LEGION_SIGHT_STATS") % (sight * profile.sight_multiplier)
	return text

static func growth_hero(profile_id: StringName) -> String:
	var template := LegionTemplate.find(profile_id)
	if template == null: return GameText.t(&"HERO_HELP")
	return GameText.t(&"HERO_TEMPLATE_HELP") % [template.hero_health,template.hero_armor,template.hero_speed,template.hero_damage,template.hero_range,template.hero_cooldown/10.0,template.hero_sight]

static func recruitment_status(faction: FactionSnapshot, commander_id: StringName) -> String:
	if faction == null: return ""
	var state := faction.recruitment_arbitration
	var text := GameText.t(state.reasons.get(commander_id, &"GROWTH_WAIT_READY"))
	if state.reserved_commander_id == commander_id:
		text += "\n" + GameText.t(&"GROWTH_SAVING_DETAIL") % [state.reserved_amount, state.reserved_cost]
	return text


static func current_unit(unit: UnitSnapshot, definition: UnitCardDefinition) -> String:
	var weapon := definition.tactical_weapon_override
	if weapon != null and weapon.health_only_damage:
		return GameText.t(&"LEGION_MISSILE_STATS") % [unit.max_health, unit.armor, unit.move_speed, unit.attack_damage * weapon.damage_multiplier_min, unit.attack_damage * weapon.damage_multiplier_max, unit.attack_range, unit.attack_cooldown_ticks / 10.0, weapon.preparation_ticks / 10.0]
	return GameText.t(&"LEGION_UNIT_STATS") % [unit.max_health, unit.armor, unit.move_speed, unit.attack_damage, unit.attack_range, unit.attack_cooldown_ticks / 10.0]
