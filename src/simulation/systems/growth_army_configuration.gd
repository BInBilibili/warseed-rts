class_name GrowthArmyConfiguration
extends RefCounted

static func apply(battle: BattleDefinition, plan: ArmyPlan) -> BattleDefinition:
	if not battle.growth_mode: return battle
	if plan == null or not plan.legion_errors(battle).is_empty(): return null
	var copy := battle.duplicate() as BattleDefinition
	copy.unit_card_definitions = []
	for source in battle.unit_card_definitions:
		var card := source.duplicate(true) as UnitCardDefinition
		var entry := plan.legion(card.commander_definition_id)
		var role := [&"UNIT_CARD_ROLE_RECON", &"UNIT_CARD_ROLE_ASSAULT", &"UNIT_CARD_ROLE_ARMOR", &"UNIT_CARD_ROLE_FIREPOWER"].find(card.role_key)
		configure_card(card, LegionTemplate.find(entry.profile_id), role)
		var personality := CommanderProfile.find(entry.profile_id).personality_key
		card.recruitment_weight = 2.0 if (role == 0 and personality == &"PERSONALITY_CAUTIOUS") or (role == 2 and personality == &"PERSONALITY_RESOLUTE") or (role == 3 and personality == &"PERSONALITY_METHODICAL") else 1.0
		copy.unit_card_definitions.append(card)
	copy.enemy_formations = []
	for source in battle.enemy_formations:
		var formation := source.duplicate(true) as BattleFormationDefinition
		var card := formation.unit_card_definition
		if card != null:
			var owner := String(card.commander_definition_id).trim_prefix("red_")
			for commander in battle.commander_definitions:
				if String(commander.definition_id) != owner: continue
				var role := [&"UNIT_CARD_ROLE_RECON", &"UNIT_CARD_ROLE_ASSAULT", &"UNIT_CARD_ROLE_ARMOR", &"UNIT_CARD_ROLE_FIREPOWER"].find(card.role_key)
				configure_card(card, LegionTemplate.find(commander.profile.profile_id), role)
				formation.strength = card.starting_strength
		copy.enemy_formations.append(formation)
	return copy

static func configure_card(card: UnitCardDefinition, template: LegionTemplate, role: int) -> void:
	if role == 0 and card.legion_template != null and card.legion_template.armed_recon and not template.armed_recon:
		card.combat_override = null
		card.recruitment_cost = 1
	card.legion_template = template
	card.authorized_strength = template.full[role]
	card.starting_strength = template.opening[role]
	if role == 0 and template.armed_recon:
		card.recruitment_cost = 2
		card.combat_override = card.combat_override.duplicate(true) as CombatDefinition if card.combat_override != null else CombatDefinition.new()
		card.combat_override.max_health = 180
		card.combat_override.armor = 4
		card.combat_override.attack_power = 24
		card.combat_override.attack_range = 220
		card.combat_override.attacks_per_second = 1.25
		card.combat_override.projectile_speed = 560

static func record_losses(world: SimulationWorld) -> void:
	if world.battle_definition == null or not world.battle_definition.growth_mode: return
	for unit: UnitState in world.units.values():
		if unit.enabled or unit.health > 0 or unit.growth_loss_recorded: continue
		unit.growth_loss_recorded = true
		var card := world.unit_cards.get(unit.unit_card_id) as UnitCardState
		if card == null: continue
		card.cumulative_losses += 1
		var entry := card.get_composition_entry(unit.composition_entry_id)
		if entry != null: entry.cumulative_losses += 1
