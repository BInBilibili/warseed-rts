class_name LegionArtilleryPolicy
extends Resource

@export var definition_id: StringName = &"gunner_artillery_groups_v1"
@export var profile_id: StringName = &"gunner"
@export var preferred_range_min: float = 320.0
@export var preferred_range_max: float = 400.0
@export var full_fraction: float = 0.6
@export var preparation_ticks: int = 20
@export var partial_after_ticks: int = 40
@export var relocation_interval_ticks: int = 20
@export var no_site_timeout_ticks: int = 60
@export var maximum_relocation_step: float = 96.0
@export var maximum_lateral_step: float = 64.0
@export var guard_minimum_distance: float = 128.0
@export var guard_preferred_distance: float = 160.0
@export var guard_maximum_distance: float = 192.0

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if definition_id.is_empty() or profile_id.is_empty(): errors.append("ARTILLERY_ID_REQUIRED")
	if not is_finite(preferred_range_min) or not is_finite(preferred_range_max) or preferred_range_min <= 0.0 or preferred_range_max < preferred_range_min:
		errors.append("ARTILLERY_RANGE_INVALID")
	if not is_finite(full_fraction) or full_fraction <= 0.0 or full_fraction > 1.0:
		errors.append("ARTILLERY_FRACTION_INVALID")
	if preparation_ticks != 20 or partial_after_ticks != 40 or relocation_interval_ticks != 20 or no_site_timeout_ticks != 60:
		errors.append("ARTILLERY_TICK_CONTRACT_INVALID")
	if not is_finite(maximum_relocation_step) or not is_finite(maximum_lateral_step) or maximum_relocation_step <= 0.0 or maximum_lateral_step < 0.0:
		errors.append("ARTILLERY_RELOCATION_BOUNDS_INVALID")
	if guard_minimum_distance != 128.0 or guard_preferred_distance != 160.0 or guard_maximum_distance != 192.0:
		errors.append("ARTILLERY_GUARD_BAND_INVALID")
	return errors
