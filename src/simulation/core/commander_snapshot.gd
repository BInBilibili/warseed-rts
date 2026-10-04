class_name CommanderSnapshot
extends RefCounted

var profile_id: StringName
var intent_mode: CommanderState.IntentMode
var authority_version: int
var player_command_id: int
var player_target_position: Vector2
var player_target_region_id: StringName
var player_route: PackedVector2Array
var intent_receipt: CommanderState.IntentReceipt
var legion_execution_authority: CommanderState.LegionExecutionAuthority
var formation_mode: CommanderState.FormationMode = CommanderState.FormationMode.FREE
var legion_formation: LegionFormationState
var legion_artillery: LegionArtilleryState
var definition_id: StringName
var display_name_key: StringName
var faction_id: int
var capacity: int
var personality_key: StringName
var strategic_lane_id: StringName
var hero_entity_id: int
var growth_unlocked_slots: int
var growth_slot_entities: PackedInt32Array
var hero_respawn_tick: int
var legion_regrouping: bool
var recovery_started_tick: int
var recovery_strength: int
var autonomous_growth: bool
var growth_recovering: bool
var growth_resume_position: Vector2
var growth_resume_region_id: StringName
var growth_resume_route: PackedVector2Array
var last_growth_order_tick: int
var specialty_keys: Array[StringName]
var doctrine_keys: Array[StringName]
var subordinate_unit_card_ids: Array[StringName]
var agent_id: int = 0
var posture: CommanderState.Posture = CommanderState.Posture.BALANCED
var target_position: Vector2
var deployment_goal := Vector2(INF,INF)
var deployment_facing := Vector2.ZERO
var target_region_id: StringName
var planned_route: PackedVector2Array
var current_task_ids: Array[int]
var last_detail: String
var behavior_state_key: StringName
var behavior_reason_key: StringName
var behavior_changed_tick: int
var estimated_arrival_min_ticks: int
var estimated_arrival_max_ticks: int
var risk_key: StringName
var risk_reason_key: StringName
var exit_condition_key: StringName
var doctrine_slot_count: int
var equipped_doctrine_ids: Array[StringName]
var available_doctrine_ids: Array[StringName]
var active_intent_id: StringName
var intent_objective_region_id: StringName
var intent_axis_region_id: StringName
var intent_reserve_policy: CommanderState.ReservePolicy
var intent_accepted_tick: int


func _init(state: CommanderState) -> void:
	intent_mode = state.intent_mode
	authority_version = state.authority_version
	player_command_id = state.player_command_id
	player_target_position = state.player_target_position
	player_target_region_id = state.player_target_region_id
	player_route = state.player_route.duplicate()
	intent_receipt = state.intent_receipt
	legion_execution_authority = state.legion_execution_authority
	formation_mode = state.formation_mode
	deployment_goal=state.deployment_goal; deployment_facing=state.deployment_facing
	profile_id = state.definition.profile.profile_id if state.definition.profile != null else &""
	definition_id = state.definition.definition_id
	display_name_key = state.definition.display_name_key
	faction_id = state.faction_id
	capacity = state.definition.capacity
	personality_key = state.definition.personality_key
	strategic_lane_id = state.definition.strategic_lane_id
	hero_entity_id = state.hero_entity_id
	growth_unlocked_slots = state.growth_unlocked_slots
	growth_slot_entities = state.growth_slot_entities.duplicate()
	hero_respawn_tick = state.hero_respawn_tick
	legion_regrouping = state.legion_regrouping
	recovery_started_tick = state.recovery_started_tick
	recovery_strength = state.recovery_strength
	autonomous_growth = state.autonomous_growth
	growth_recovering = state.growth_recovering
	growth_resume_position = state.growth_resume_position
	growth_resume_region_id = state.growth_resume_region_id
	growth_resume_route = state.growth_resume_route.duplicate()
	last_growth_order_tick = state.last_growth_order_tick
	specialty_keys = state.definition.specialty_keys.duplicate()
	doctrine_keys = state.definition.doctrine_keys.duplicate()
	subordinate_unit_card_ids = state.subordinate_unit_card_ids.duplicate()
	agent_id = state.agent_id
	posture = state.posture
	target_position = state.target_position
	target_region_id = state.target_region_id
	planned_route = state.planned_route.duplicate()
	current_task_ids = state.current_task_ids.duplicate()
	last_detail = state.last_detail
	behavior_state_key = state.behavior_state_key
	behavior_reason_key = state.behavior_reason_key
	behavior_changed_tick = state.behavior_changed_tick
	estimated_arrival_min_ticks = state.estimated_arrival_min_ticks
	estimated_arrival_max_ticks = state.estimated_arrival_max_ticks
	risk_key = state.risk_key
	risk_reason_key = state.risk_reason_key
	exit_condition_key = state.exit_condition_key
	doctrine_slot_count = state.doctrine_slot_count
	equipped_doctrine_ids = state.equipped_doctrine_ids.duplicate()
	available_doctrine_ids = state.available_doctrine_ids.duplicate()
	active_intent_id = state.active_intent_id
	intent_objective_region_id = state.intent_objective_region_id
	intent_axis_region_id = state.intent_axis_region_id
	intent_reserve_policy = state.intent_reserve_policy
	intent_accepted_tick = state.intent_accepted_tick
