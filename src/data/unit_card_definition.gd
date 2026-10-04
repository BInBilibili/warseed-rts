class_name UnitCardDefinition
extends Resource

@export var definition_id: StringName
@export var display_name_key: StringName
@export var role_key: StringName
@export var commander_definition_id: StringName
@export var command_cost: int = 1
@export var authorized_strength: int = 1
@export var starting_strength: int = 0 # Zero retains the legacy full-strength opening.
@export var recruitment_cost: int = 1 # Supply per member in growth matches.
@export var recruitment_weight: float = 1.0 # Commander personality preference.
@export var unit_definition_id: StringName
@export var composition: Array[UnitCardCompositionEntry] = []
@export var tactical_ability: TacticalAbilityDefinition
@export var tactical_weapon_override: TacticalWeaponDefinition
@export var combat_override: CombatDefinition
@export var fallback_weapon: CombatDefinition
@export var enforce_organization_rules: bool = false
@export var supply_cost: int = 0
@export var deployment_ticks: int = 0
@export var starts_in_reserve: bool = false

# Independent-match historical rosters may record a player-chosen role capacity.
@export var configurable_max_strength: int = 0

# Runtime copies of the final-decision roster carry the typed fixed template.
# A missing role is explicit; ordinary zero-size cards remain invalid.
@export var legion_template: LegionTemplate

func is_absent_legion_role() -> bool:
	if legion_template == null or not legion_template.validation_errors().is_empty(): return false
	var role := LegionTemplate.ROLE_KEYS.find(role_key)
	return role >= 0 and legion_template.full[role] == 0 and authorized_strength == 0 and starting_strength == 0 and composition.is_empty()
