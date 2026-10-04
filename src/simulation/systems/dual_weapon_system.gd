class_name DualWeaponSystem
extends RefCounted

# Called after terrain modifiers, before target selection. Missile ammunition
# remains a separate inventory even while the unlimited cannon is selected.
static func refresh(unit: UnitState) -> void:
	if unit.fallback_weapon == null or unit.primary_weapon == null: return
	var fallback := unit.ammunition <= 0
	if fallback != unit.using_fallback_weapon:
		unit.weapon_prepared_ticks = 0
	unit.using_fallback_weapon = fallback
	var weapon := unit.primary_weapon
	unit.minimum_attack_range = 0.0 if fallback else weapon.minimum_range
	unit.identification_required = not fallback and weapon.identification_required
	unit.weapon_preparation_ticks = 0 if fallback else weapon.preparation_ticks
	unit.damage_tag = TacticalWeaponDefinition.DamageTag.KINETIC if fallback else weapon.damage_tag
	unit.suppression_power = 0.0 if fallback else weapon.suppression
	unit.damage_multiplier_min = 1.0 if fallback else weapon.damage_multiplier_min
	unit.damage_multiplier_max = 1.0 if fallback else weapon.damage_multiplier_max
	if fallback:
		unit.attack_range = unit.fallback_weapon.attack_range
		unit.attack_damage = unit.fallback_weapon.attack_power * unit.commander_attack_multiplier
		unit.attack_cooldown_ticks = ceili(10.0 / unit.fallback_weapon.attacks_per_second)
		unit.projectile_speed = unit.fallback_weapon.projectile_speed
	else:
		unit.attack_cooldown_ticks = unit.primary_cooldown_ticks
		unit.projectile_speed = unit.primary_projectile_speed

static func multiplier(unit: UnitState) -> float:
	if unit.damage_multiplier_min == unit.damage_multiplier_max: return unit.damage_multiplier_min
	# Park-Miller step with stable entity/shot inputs; no global RNG, wall clock,
	# snapshot reads or rendering can consume the sequence. All arithmetic is int64.
	var state := (unit.entity_id * 48271 + unit.weapon_shots_fired * 69621 + 104729) % 2147483647
	state = state * 48271 % 2147483647
	state = state * 48271 % 2147483647
	return lerpf(unit.damage_multiplier_min, unit.damage_multiplier_max, float(state) / 2147483646.0)
