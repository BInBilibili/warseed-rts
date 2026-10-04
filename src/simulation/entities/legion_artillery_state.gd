class_name LegionArtilleryState
extends RefCounted

enum Phase { IDLE, ASSEMBLING, DEPLOYING, DEPLOYED, FULL, PARTIAL, BLOCKED, PREEMPTED }

class Group extends RefCounted:
	var group_id: StringName
	var identities := PackedInt32Array()
	var actionable := 0
	var positioned := 0
	var prepared := 0
	func duplicate_value() -> Group:
		var copy := Group.new()
		copy.group_id = group_id
		copy.identities = identities.duplicate()
		copy.actionable = actionable
		copy.positioned = positioned
		copy.prepared = prepared
		return copy

var commander_id: StringName
var profile_id: StringName
var faction_id := 0
var hero_entity_id := 0
var navigation_map_id: StringName
var batch_epoch := -1
var observed_tick := -1
var target_entity_id := 0
var phase: Phase = Phase.IDLE
var reason: StringName = &"NO_TARGET"
var groups: Array[Group] = []
var actionable := 0
var positioned := 0
var prepared := 0
var fire_ready := false
var guards_actionable := 0
var guards_positioned := 0
var guard_reason: StringName = &"NO_DEPLOYED_ARTILLERY"
var required_for_full := 0
var first_observation_tick := -1
var first_positioned_tick := -1
var no_site_since_tick := -1
var last_relocation_tick := -1
var stationary_since_by_identity: Dictionary[int,int] = {}
var legal_since_by_identity: Dictionary[int,int] = {}
var entity_by_identity: Dictionary[int,int] = {}
var last_position_by_identity: Dictionary[int,Vector2] = {}
var suggested_identity := -1
var suggested_position := Vector2.ZERO
var suggestion_requires_validation := false

func duplicate_value() -> LegionArtilleryState:
	var copy: LegionArtilleryState = get_script().new()
	copy.commander_id = commander_id
	copy.profile_id = profile_id
	copy.faction_id = faction_id
	copy.hero_entity_id = hero_entity_id
	copy.navigation_map_id = navigation_map_id
	copy.batch_epoch = batch_epoch
	copy.observed_tick = observed_tick
	copy.target_entity_id = target_entity_id
	copy.phase = phase
	copy.reason = reason
	for group in groups: copy.groups.append(group.duplicate_value())
	copy.actionable = actionable
	copy.positioned = positioned
	copy.prepared = prepared
	copy.fire_ready = fire_ready
	copy.guards_actionable = guards_actionable
	copy.guards_positioned = guards_positioned
	copy.guard_reason = guard_reason
	copy.required_for_full = required_for_full
	copy.first_observation_tick = first_observation_tick
	copy.first_positioned_tick = first_positioned_tick
	copy.no_site_since_tick = no_site_since_tick
	copy.last_relocation_tick = last_relocation_tick
	copy.stationary_since_by_identity = stationary_since_by_identity.duplicate()
	copy.legal_since_by_identity = legal_since_by_identity.duplicate()
	copy.entity_by_identity = entity_by_identity.duplicate()
	copy.last_position_by_identity = last_position_by_identity.duplicate()
	copy.suggested_identity = suggested_identity
	copy.suggested_position = suggested_position
	copy.suggestion_requires_validation = suggestion_requires_validation
	return copy
