class_name LegionReformationPolicy
extends Resource

@export var definition_id: StringName = &"rapid_reformation_v1"
@export var target_ticks: int = 30
@export var maximum_ticks: int = 60
@export var landing_ticks: int = 10
@export var budget_window_ticks: int = 100
@export var cooldown_ticks: int = 30
@export var damage_multiplier: float = 1.5
@export var spacings: PackedFloat32Array = PackedFloat32Array([48.0,40.0,32.0])
@export var body_separation: float = 24.0
@export var artillery_separation: float = 48.0
@export var ground_radius: float = 32.0

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if definition_id.is_empty(): errors.append("REFORMATION_ID_REQUIRED")
	if target_ticks<=0 or maximum_ticks<target_ticks or landing_ticks<=0 or landing_ticks>=maximum_ticks: errors.append("REFORMATION_INVALID_DURATION")
	if budget_window_ticks<maximum_ticks or cooldown_ticks<0: errors.append("REFORMATION_INVALID_BUDGET")
	if not is_finite(damage_multiplier) or damage_multiplier!=1.5: errors.append("REFORMATION_INVALID_DAMAGE")
	if not is_finite(body_separation) or not is_finite(ground_radius) or not is_finite(artillery_separation) or body_separation<24.0 or ground_radius<32.0 or artillery_separation<48.0: errors.append("REFORMATION_INVALID_CLEARANCE")
	var previous := INF
	for spacing in spacings:
		if not is_finite(spacing) or spacing<=body_separation or spacing>=previous: errors.append("REFORMATION_INVALID_SPACING")
		previous=spacing
	if spacings.size()!=3: errors.append("REFORMATION_SPACING_COUNT")
	return errors

func tolerance(spacing: float) -> float:
	return minf(6.0,maxf(0.0,(spacing-body_separation)*0.5))
