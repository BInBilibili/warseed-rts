class_name TacticalWeaponDefinition
extends Resource

enum DamageTag { KINETIC, EXPLOSIVE, GUIDED, SUPPRESSION }
enum TargetTag { LIGHT, ARMORED, AIR, STRUCTURE }

@export var damage_tag: DamageTag = DamageTag.KINETIC
@export var target_tag: TargetTag = TargetTag.LIGHT
@export var allowed_targets: Array[TargetTag] = [TargetTag.LIGHT, TargetTag.ARMORED, TargetTag.STRUCTURE]
@export var ammunition_capacity: int = 0
@export var minimum_range: float = 0.0
@export var suppression: float = 0.0
@export var identification_required: bool = false
@export var preparation_ticks: int = 0
@export var damage_multiplier_min: float = 1.0
@export var damage_multiplier_max: float = 1.0
@export var fixed_attack_range: float = 0.0
@export var health_only_damage: bool = false


func validate() -> DataValidationResult:
	var result := DataValidationResult.new()
	if not is_finite(fixed_attack_range) or fixed_attack_range < 0.0:
		result.add(DataValidationResult.Reason.INVALID_VALUE, "invalid fixed weapon range")
	if health_only_damage and (suppression > 0.0 or damage_tag == DamageTag.SUPPRESSION):
		result.add(DataValidationResult.Reason.INVALID_VALUE, "health-only weapon cannot suppress organization")
	if not is_finite(damage_multiplier_min) or not is_finite(damage_multiplier_max) or damage_multiplier_min <= 0.0 or damage_multiplier_max < damage_multiplier_min or damage_multiplier_max > 10.0:
		result.add(DataValidationResult.Reason.INVALID_VALUE, "invalid weapon damage multiplier range")
	if damage_tag < DamageTag.KINETIC or damage_tag > DamageTag.SUPPRESSION or target_tag < TargetTag.LIGHT or target_tag > TargetTag.STRUCTURE or allowed_targets.is_empty():
		result.add(DataValidationResult.Reason.INVALID_VALUE, "unsupported weapon/target tag")
	for tag in allowed_targets:
		if tag < TargetTag.LIGHT or tag > TargetTag.STRUCTURE:
			result.add(DataValidationResult.Reason.INVALID_VALUE, "unsupported allowed target tag")
	if ammunition_capacity < 0 or preparation_ticks < 0 or not is_finite(minimum_range) or minimum_range < 0.0 or not is_finite(suppression) or suppression < 0.0:
		result.add(DataValidationResult.Reason.INVALID_VALUE, "invalid professional weapon constraints")
	if damage_tag in [DamageTag.GUIDED, DamageTag.SUPPRESSION] and (ammunition_capacity <= 0 or not identification_required):
		result.add(DataValidationResult.Reason.INVALID_VALUE, "professional guided/suppression fire requires finite ammunition and identification")
	if damage_tag == DamageTag.SUPPRESSION and suppression <= 0.0:
		result.add(DataValidationResult.Reason.INVALID_VALUE, "suppression weapon requires organization impact")
	return result
