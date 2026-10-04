class_name LegionArtillerySystem
extends RefCounted

const GuardSystem = preload("res://src/simulation/systems/legion_artillery_guard.gd")
var guard_system := GuardSystem.new()

# Local execution of an already accepted card intent, never a new strategic order.
class Commitment extends RefCounted:
	var intent := ""
	var target_id := 0
	var entity_by_identity: Dictionary[int,int] = {}
	var positions: Dictionary[int,Vector2] = {}
	var origins: Dictionary[int,Vector2] = {}
	var last_adjustment: Dictionary[int,int] = {}
	var target_positions: Dictionary[int,Vector2] = {}

var states: Dictionary[StringName,LegionArtilleryState] = {}
var commitments: Dictionary[StringName,Commitment] = {}
var known_grids: Dictionary[int,LogicGrid] = {}
var known_finders: Dictionary[int,GridPathfinder] = {}
var known_signatures: Dictionary[int,String] = {}

func snapshot(commander_id: StringName) -> LegionArtilleryState:
	return states[commander_id].duplicate_value() if states.has(commander_id) else null

func prepare(world: SimulationWorld) -> void:
	if world.battle_definition == null or not world.battle_definition.growth_mode: return
	var policy := world.battle_definition.legion_artillery_policy
	if policy == null: return
	var ids := world.commanders.keys()
	ids.sort_custom(func(a: StringName,b: StringName) -> bool: return String(a)<String(b))
	var views: Dictionary[int,WorldSnapshot] = {}
	for id: StringName in ids:
		var commander := world.commanders[id] as CommanderState
		if commander.definition.profile == null or commander.definition.profile.profile_id != policy.profile_id: continue
		if not views.has(commander.faction_id): views[commander.faction_id]=world.create_faction_snapshot(commander.faction_id)
		var view := views[commander.faction_id]
		var own := view.get_commander(id)
		var record := world.legion_formation_system.records.get(id) as LegionFormationState
		if own == null or record == null or record.batch_plan == null: continue
		_known_navigation(world,view)
		var grid := known_grids[commander.faction_id]
		var finder := known_finders[commander.faction_id]
		var authorized := _authorized_members(world,commander)
		var target_id := _target(view,own,authorized,true)
		var sites := _sites(world,grid,view,own,target_id,authorized,true)
		var local_authority := not authorized.is_empty()
		# An automatic strategic route can engage a visible contact locally.
		# An explicit contextual deployment remains MOVE and always preempts.
		if own.legion_formation.spatial.action==LegionSpatialState.Action.MOVE and local_authority and target_id!=0:
			own.legion_formation.spatial.action=LegionSpatialState.Action.ATTACK
		if not local_authority:
			own.legion_formation.spatial.action=LegionSpatialState.Action.MOVE
		var observed := LegionArtilleryPlanner.observe(view,own,policy,states.get(id),target_id,sites,authorized,true)
		observed.guards_actionable=0; observed.guards_positioned=0; observed.guard_reason=&"GUARDS_INTERRUPTED"
		states[id]=observed
		if observed.phase in [LegionArtilleryState.Phase.PREEMPTED,LegionArtilleryState.Phase.BLOCKED] or commander.legion_regrouping or commander.posture == CommanderState.Posture.HOLD:
			commitments.erase(id)
			guard_system.clear(id)
			continue
		var source := LegionSpatialExecutor._source(world,commander,record)
		if source == null: commitments.erase(id); guard_system.clear(id); continue
		var intent := str([record.spatial.intent,source.order_kind,source.order_destination,commander.last_growth_order_tick,commander.posture,commander.legion_execution_authority,_task_signature(world,commander,authorized)])
		if not commitments.has(id) or commitments[id].intent!=intent or commitments[id].target_id!=target_id:
			var fresh := Commitment.new(); fresh.intent=intent; fresh.target_id=target_id
			commitments[id]=fresh
		var commitment := commitments[id]
		var target_position := _target_position(view,target_id)
		var artillery_ordinal := 0
		for member in record.batch_plan.members:
			if member.role!=3 or member.identity>=commander.growth_unlocked_slots: continue
			var group := artillery_ordinal%2; artillery_ordinal+=1
			var unit := world.units.get(member.entity_id) as UnitState
			var card := world.unit_cards.get(unit.unit_card_id) as UnitCardState if unit!=null else null
			var task := world.tasks.get(unit.assigned_task_id) as TaskState if unit!=null else null
			var withdrawing := task!=null and task.phase in [TaskState.Phase.RETREATING,TaskState.Phase.EVADING]
			if not authorized.has(member.entity_id) or not LegionSpatialExecutor.eligible(unit,card) or card.player_stopped or card.continuing_player_order or withdrawing:
				_forget(commitment,member.identity); continue
			if commitment.entity_by_identity.get(member.identity,0)!=unit.entity_id:
				_forget(commitment,member.identity)
				commitment.entity_by_identity[member.identity]=unit.entity_id
				commitment.origins[member.identity]=unit.position
			var observed_unit := view.get_unit(unit.entity_id)
			if observed_unit==null: continue
			if target_id != 0 and not _authorized_target(world,unit,target_id):
				_forget(commitment,member.identity)
				continue
			var danger := _direct_threat(view,observed_unit)
			# A nearby attacker interrupts the emplacement, including its leash
			# origin. Keep the movement slot already chosen by the normal authority;
			# a different firing target cannot justify stepping toward this threat.
			if danger:
				_forget(commitment,member.identity)
				continue
			if target_id==0:
				commitment.positions.erase(member.identity)
				continue
			# Keep a valid existing emplacement; a late gun never pulls it along.
			var distance := unit.position.distance_to(target_position)
			if not danger and sites.has(unit.entity_id) and distance<=unit.attack_range and distance>=unit.minimum_attack_range:
				commitment.positions[member.identity]=unit.position
				commitment.target_positions[member.identity]=target_position
			elif commitment.positions.has(member.identity) and commitment.positions[member.identity].distance_to(target_position)>unit.attack_range and (unit.position.distance_to(commitment.positions[member.identity])<=6.0 or _target_replan_due(commitment,member.identity,target_position,world.current_tick,policy)):
				commitment.positions.erase(member.identity)
			if commitment.positions.has(member.identity) and not _site_clear(grid,view,commitment.positions[member.identity],unit.entity_id):
				commitment.positions.erase(member.identity)
			if not commitment.positions.has(member.identity) and world.current_tick-int(commitment.last_adjustment.get(member.identity,-1000))>=policy.relocation_interval_ticks:
				commitment.last_adjustment[member.identity]=world.current_tick
				# A defending gun must not chase bait beyond its accepted position.
				var can_advance := own.legion_formation.spatial.action==LegionSpatialState.Action.ATTACK
				var candidate := _candidate(grid,finder,view,observed_unit,target_position,commitment.origins[member.identity],policy,group,can_advance,danger)
				if not candidate.is_finite() and not can_advance:
					candidate = _rejoin_candidate(grid,finder,view,observed_unit,target_position,commitment.origins[member.identity],policy,sites)
				if candidate.is_finite():
					commitment.positions[member.identity]=candidate
					commitment.target_positions[member.identity]=target_position
			if commitment.positions.has(member.identity):
				var destination := commitment.positions[member.identity]
				# Plan with known occupancy; the normal physical executor still
				# enforces actual terrain/enemy collision when the body advances.
				var path := finder.find_body_path(unit.position,destination)
				if path.is_empty(): commitment.positions.erase(member.identity); continue
				var slot := unit.legion_slot
				if slot==null:
					# A held card may have no ordinary movement slot. The existing
					# local authority still permits a late gun to reach its firing line.
					slot=LegionSpatialOrder.new(); slot.identity=member.identity
					slot.entity_id=unit.entity_id; slot.admitted=true
					unit.legion_slot=slot
				slot.target=destination; slot.path=path; slot.path_index=1
				slot.reason=&"ARTILLERY_EMPLACEMENT"; slot.at_destination=false
				unit.desired_position=destination
		guard_system.prepare(world,commander,record,view,grid,finder,policy,observed,sites,target_position,intent,authorized)

static func _target_replan_due(commitment: Commitment, identity: int, target: Vector2, tick: int, policy: LegionArtilleryPolicy) -> bool:
	return commitment.target_positions.has(identity) and commitment.target_positions[identity].distance_to(target)>0.01 and tick-int(commitment.last_adjustment.get(identity,-1000))>=policy.relocation_interval_ticks

static func _task_signature(world: SimulationWorld, commander: CommanderState, authorized: PackedInt32Array) -> Array:
	var result: Array = []
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards.get(card_id) as UnitCardState
		if card==null: continue
		for entity_id in card.member_entity_ids:
			if authorized.has(entity_id):
				result.append([card_id,card.assigned_task_id]); break
	return result

static func _authorized_members(world: SimulationWorld, commander: CommanderState) -> PackedInt32Array:
	var result := PackedInt32Array()
	if commander.posture in [CommanderState.Posture.HOLD,CommanderState.Posture.DISENGAGE] or commander.growth_recovering or commander.legion_regrouping: return result
	var graph_owns := world.commander_task_graph_system.owns_commander(commander)
	if not graph_owns and not _local_authority(commander): return result
	for card_id in commander.subordinate_unit_card_ids:
		var card := world.unit_cards.get(card_id) as UnitCardState
		if card==null or not card.uses_legion_slots() or card.player_stopped: continue
		if graph_owns and not world.commander_task_graph_system.allows_legion_local_task(world,card_id): continue
		for entity_id in card.member_entity_ids: result.append(entity_id)
	return result

static func _local_authority(commander: CommanderState) -> bool:
	if commander.posture in [CommanderState.Posture.HOLD,CommanderState.Posture.DISENGAGE]: return false
	if commander.legion_execution_authority == CommanderState.LegionExecutionAuthority.AGENT_OBJECTIVE: return true
	if commander.deployment_goal.is_finite(): return false
	match commander.legion_execution_authority:
		CommanderState.LegionExecutionAuthority.AUTONOMOUS: return commander.autonomous_growth
		CommanderState.LegionExecutionAuthority.PLAYER_INTENT: return commander.intent_mode == CommanderState.IntentMode.FORCE_ATTACK or not commander.active_intent_id.is_empty()
	return false

static func _forget(commitment: Commitment, identity: int) -> void:
	commitment.positions.erase(identity); commitment.entity_by_identity.erase(identity)
	commitment.origins.erase(identity); commitment.last_adjustment.erase(identity)
	commitment.target_positions.erase(identity)

static func _authorized_target(world: SimulationWorld, unit: UnitState, target_id: int) -> bool:
	# Another gun's assignment must never replace this gun's current target.
	if unit.attack_target_entity_id != 0: return unit.attack_target_entity_id == target_id
	var formation := world.formations.get(unit.formation_id) as FormationState
	if formation == null: return false
	if formation.order_kind == FormationState.OrderKind.ATTACK_TARGET:
		return formation.order_target_entity_id == target_id
	if formation.fire_focus_id == target_id and formation.fire_focus_until_tick > world.current_tick: return true
	# A late member may join its own card's ongoing local engagement. This
	# does not borrow an unrelated card's target or override a personal target.
	for member_id in formation.member_entity_ids:
		var member := world.units.get(member_id) as UnitState
		if member != null and member.enabled and member.attack_target_entity_id == target_id: return true
	return false

func _known_navigation(world: SimulationWorld, view: WorldSnapshot) -> void:
	var occupancy: Array[String] = []
	for building in view.buildings:
		if building.enabled: occupancy.append(str([building.entity_id,building.position,building.footprint_cells]))
	occupancy.sort()
	var signature := str([view.navigation_map_id,occupancy])
	if known_signatures.get(view.observer_faction_id,"")==signature: return
	var grid := LogicGrid.create_for_map(world.battle_definition.map_definition)
	for building in view.buildings:
		if not building.enabled: continue
		for cell in building.footprint_cells: grid.set_blocked(cell,true)
	known_grids[view.observer_faction_id]=grid
	known_finders[view.observer_faction_id]=GridPathfinder.new(grid)
	known_signatures[view.observer_faction_id]=signature

static func _sites(world: SimulationWorld, grid: LogicGrid, view: WorldSnapshot, commander: CommanderSnapshot, target_id: int, authorized: PackedInt32Array = PackedInt32Array(), restricted: bool = false) -> PackedInt32Array:
	var result := PackedInt32Array()
	for entity_id in commander.growth_slot_entities:
		if restricted and not authorized.has(entity_id): continue
		var unit := view.get_unit(entity_id)
		if unit==null or unit.tactical_role!=UnitState.TacticalRole.FIREPOWER or not unit.enabled or unit.legion_returning or unit.rejoin_pending: continue
		if unit.reformation_phase!=LegionReformationState.Phase.SOLID: continue
		if _direct_threat(view,unit): continue
		var physical := world.units.get(entity_id) as UnitState
		if target_id != 0 and (physical == null or physical.attack_target_entity_id != target_id): continue
		if target_id!=0 and (physical==null or not GrowthCombatSystem.valid_target(world,physical,target_id,false) or not physical.weapon_action_ready): continue
		if _site_clear(grid,view,unit.position,entity_id): result.append(entity_id)
	return result

static func _site_clear(grid: LogicGrid, view: WorldSnapshot, position: Vector2, entity_id: int) -> bool:
	if not LegionTransitGeometry.segment_fits(grid,position,position): return false
	for other in view.units:
		if not other.enabled or other.entity_id==entity_id: continue
		if other.faction_id!=view.observer_faction_id and not other.is_visible_to_local_player: continue
		if position.distance_to(other.position)<LegionReformationSystem.policy.artillery_separation-0.01: return false
	return true

static func _target(view: WorldSnapshot, commander: CommanderSnapshot, authorized: PackedInt32Array = PackedInt32Array(), restricted: bool = false) -> int:
	var best := 0; var best_distance := INF
	for entity_id in commander.growth_slot_entities:
		if restricted and not authorized.has(entity_id): continue
		var gun := view.get_unit(entity_id)
		if gun==null or not gun.enabled or gun.legion_returning or gun.rejoin_pending or gun.tactical_role!=UnitState.TacticalRole.FIREPOWER: continue
		var candidates: Array[int] = []
		# Only a target already assigned by the shared combat/command pipeline
		# authorizes local emplacement work; unrelated visible contacts do not.
		if gun.attack_target_entity_id>0: candidates.append(gun.attack_target_entity_id)
		var formation := view.get_formation(gun.formation_id)
		if formation!=null and formation.order_kind==FormationState.OrderKind.ATTACK_TARGET and not candidates.has(formation.order_target_entity_id): candidates.append(formation.order_target_entity_id)
		var visible_candidates: Array[int] = []
		for enemy in view.units:
			if candidates.has(enemy.entity_id) and enemy.enabled and enemy.faction_id!=commander.faction_id and enemy.is_visible_to_local_player and enemy.last_seen_tick==view.tick: visible_candidates.append(enemy.entity_id)
		for building in view.buildings:
			if candidates.has(building.entity_id) and building.enabled and building.faction_id!=commander.faction_id and building.is_visible and building.last_seen_tick==view.tick: visible_candidates.append(building.entity_id)
		visible_candidates.sort()
		for target_id in visible_candidates:
			var distance := gun.position.distance_to(_target_position(view,target_id))
			if distance>gun.attack_range+96.0: continue
			if distance<best_distance or is_equal_approx(distance,best_distance) and (best==0 or target_id<best):
				best=target_id; best_distance=distance
	return best

static func _target_position(view: WorldSnapshot, entity_id: int) -> Vector2:
	var unit := view.get_unit(entity_id)
	if unit!=null: return unit.position
	var building := view.get_building(entity_id)
	return building.position if building!=null else Vector2(INF,INF)

static func _direct_threat(view: WorldSnapshot, unit: UnitSnapshot) -> bool:
	for other in view.units:
		if other.enabled and other.faction_id!=unit.faction_id and other.is_visible_to_local_player and other.last_seen_tick==view.tick and other.can_attack and other.position.distance_to(unit.position)<190.0: return true
	return false

static func _candidate(grid: LogicGrid, finder: GridPathfinder, view: WorldSnapshot, unit: UnitSnapshot, target: Vector2, origin: Vector2, policy: LegionArtilleryPolicy, group: int, advance: bool, danger: bool) -> Vector2:
	var away := (unit.position-target).normalized()
	if away.is_zero_approx(): return Vector2(INF,INF)
	var tangent := away.orthogonal()*(1.0 if group==0 else -1.0)
	var preferred := target+away*minf(policy.preferred_range_max,unit.attack_range)
	# Sample inner lateral positions as well: the full sideways step may be
	# outside the local leash while the straight site is occupied by a sibling.
	var offsets := [tangent*policy.maximum_lateral_step,-tangent*policy.maximum_lateral_step,tangent*policy.maximum_lateral_step*0.5,-tangent*policy.maximum_lateral_step*0.5,Vector2.ZERO]
	for offset: Vector2 in offsets:
		var position := unit.position+(preferred+offset-unit.position).limit_length(policy.maximum_relocation_step)
		if position.distance_to(origin)>GrowthCombatSystem.LEASH: continue
		if not advance and not danger and position.distance_to(target)<unit.position.distance_to(target)-0.01: continue
		if not _site_clear(grid,view,position,unit.entity_id): continue
		var path := finder.find_body_path(unit.position,position)
		if path.is_empty() or LegionProtectionPlanner.path_length(path)>policy.maximum_relocation_step*2.0: continue
		return position
	return Vector2(INF,INF)


static func _rejoin_candidate(grid: LogicGrid, finder: GridPathfinder, view: WorldSnapshot, unit: UnitSnapshot, target: Vector2, origin: Vector2, policy: LegionArtilleryPolicy, sites: PackedInt32Array) -> Vector2:
	# A stationary defense may receive a late gun at its existing firing line.
	# It may not pull that line forward in pursuit of a retreating target.
	for id in sites:
		var reference := view.get_unit(id)
		if reference==null or reference.entity_id==unit.entity_id or reference.unit_card_id!=unit.unit_card_id or reference.is_moving: continue
		if reference.position.distance_to(target)>reference.attack_range: continue
		var forward := (target-reference.position).normalized()
		if forward.is_zero_approx() or (unit.position-reference.position).dot(forward)>=0.0: continue
		for side: float in [-1.0,1.0]:
			for spacing: float in [64.0,96.0,48.0]:
				var desired := reference.position+forward.orthogonal()*side*spacing
				var at := unit.position+(desired-unit.position).limit_length(policy.maximum_relocation_step)
				if at.distance_to(origin)>GrowthCombatSystem.LEASH or (at-reference.position).dot(forward)>0.01: continue
				if not _site_clear(grid,view,at,unit.entity_id): continue
				var route := finder.find_body_path(unit.position,at)
				if route.is_empty() or LegionProtectionPlanner.path_length(route)>policy.maximum_relocation_step*2.0: continue
				return at
	return Vector2(INF,INF)
