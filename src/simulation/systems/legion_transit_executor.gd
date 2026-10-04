class_name LegionTransitExecutor
extends RefCounted

static func _entity(world: SimulationWorld, commander: CommanderState, identity: int) -> UnitState:
	var id := commander.hero_entity_id if identity==60 else commander.growth_slot_entities[identity]
	return world.units.get(id) as UnitState

static func _available(world: SimulationWorld, unit: UnitState) -> bool:
	if unit==null or not unit.enabled or unit.rejoin_pending or unit.legion_returning or unit.control_state!=UnitState.ControlState.AGENT_ASSIGNED: return false
	if unit.hero_commander_id!=&"": return true
	return LegionSpatialExecutor.eligible(unit,world.unit_cards.get(unit.unit_card_id) as UnitCardState)

static func _entry_position(world: SimulationWorld, commander: CommanderState, identity: int, origin: Vector2) -> Vector2:
	var unit := _entity(world,commander,identity)
	return unit.position if unit!=null else origin

static func _target(transit: LegionTransitState, batch: LegionTransitState.BatchState, ordinal: int) -> Vector2:
	if batch.exit_stage>0 and transit.phase!=LegionTransitState.Phase.EXPAND and batch.exit_targets.size()==batch.identities.size(): return batch.exit_targets[ordinal]
	if batch.gather_phase!=0 and batch.column_targets.size()==batch.identities.size(): return batch.column_targets[ordinal]
	var lateral := (ordinal%transit.columns-(transit.columns-1)*0.5)*48.0
	var distance := batch.progress-floori(ordinal/float(transit.columns))*48.0
	if batch.gather_phase==0:
		lateral=batch.gather_laterals[ordinal]
		if ordinal<batch.gather_distances.size(): distance=batch.gather_distances[ordinal]
	return LegionTransitGeometry.point_at(transit.path,distance,lateral)

static func _column_targets(world: SimulationWorld, transit: LegionTransitState, batch: LegionTransitState.BatchState, progress: float) -> PackedVector2Array:
	# A miter's inside lane contracts at a bend. Nominal 48-spaced centerline
	# distances therefore do not guarantee distinct physical target positions.
	# Keep the stable lateral/identity order and stretch only occupied rows back.
	var result := PackedVector2Array()
	for ordinal in range(batch.identities.size()):
		var lateral := (ordinal%transit.columns-(transit.columns-1)*0.5)*48.0
		var distance := progress-floori(ordinal/float(transit.columns))*48.0
		var found := false
		for shift in range(25):
			var point := LegionTransitGeometry.point_at(transit.path,distance-shift*8.0,lateral)
			if not LegionTransitGeometry.segment_fits(world.logic_grid,point,point): continue
			var clear := true
			# Vector2 is float32: mirrored world coordinates can round nominal
			# 48 spacing by a few thousandths. Do not turn that into an 8-unit
			# slot jump on every subsequent tick. Physical 24 remains unchanged.
			for occupied in result:
				if point.distance_squared_to(occupied)<47.99*47.99: clear=false; break
			if not clear: continue
			result.append(point); found=true; break
		if not found: return PackedVector2Array()
	return result

static func _plan_exit(world: SimulationWorld, transit: LegionTransitState) -> bool:
	# Public geometry only. The order destination is not the physical mouth.
	var narrow := false; var wide_start := -1.0
	for distance in range(0,ceili(transit.path.total+640.0)+1,32):
		var point := LegionTransitGeometry.point_at(transit.path,distance)
		var forward := (LegionTransitGeometry.point_at(transit.path,distance+1)-point).normalized()
		if LegionTransitGeometry.columns_at(world.logic_grid,point,forward)<8:
			narrow=true; wide_start=-1.0
		elif narrow:
			if wide_start<0.0: wide_start=distance
			if distance-wide_start>=640.0 and LegionTransitGeometry.window_fits(world.logic_grid,transit.path,wide_start,wide_start+640.0,8):
				transit.exit_mouth=wide_start; break
	if transit.exit_mouth<0.0: return false
	var origin := LegionTransitGeometry.point_at(transit.path,transit.exit_mouth)
	transit.exit_forward=(LegionTransitGeometry.point_at(transit.path,transit.exit_mouth+1)-origin).normalized()
	var depth := 0.0
	for batch in transit.batches: depth=maxf(depth,(ceili(batch.identities.size()/float(transit.columns))-1)*48.0)
	transit.exit_head=transit.exit_mouth+maxf(208.0,depth+64.0)
	if transit.exit_head-transit.exit_mouth>384.0: return false
	var reserved := PackedVector2Array()
	var clearance := (transit.columns-1)*24.0+160.0
	for index in range(transit.batches.size()):
		var batch := transit.batches[index]
		var targets := PackedVector2Array()
		var side := -1.0 if index%2==0 else 1.0
		for ordinal in range(batch.identities.size()):
			# Parked batches share a wide, off-road formation area. The 96 gap
			# continues to constrain every batch still using the road; it is not
			# an extra empty row between units already clear of that road.
			var longitudinal := transit.exit_head-transit.exit_mouth+floori(index/2.0)*(depth+48.0)-floori(ordinal/3.0)*48.0
			# Keep a full additional body gap beyond the mathematical lane edge.
			# Dynamic collision avoidance can otherwise leave the innermost slot
			# a few units inside the measured clearance after a curved exit.
			var lateral := side*(clearance+112.0)+(ordinal%3-1)*48.0
			var point := origin+transit.exit_forward*longitudinal+transit.exit_forward.orthogonal()*lateral
			if not _staging_clear(world,point,reserved):
				transit.exit_plan_reason=&"TRANSIT_EXIT_POCKET_CAPACITY"; return false
			reserved.append(point); targets.append(point)
		batch.exit_targets=targets
	transit.exit_planned=true
	return true

static func _batch_cleared_lane(world: SimulationWorld, commander: CommanderState, transit: LegionTransitState, index: int) -> bool:
	var origin := LegionTransitGeometry.point_at(transit.path,transit.exit_mouth)
	var side := -1.0 if index%2==0 else 1.0
	var clearance := (transit.columns-1)*24.0+160.0
	for identity in transit.batches[index].identities:
		var unit := _entity(world,commander,identity)
		if not _available(world,unit): continue
		if LegionTransitGeometry.progress_at(transit.path,unit.position)-32.0<transit.exit_mouth: return false
		if (unit.position-origin).dot(transit.exit_forward.orthogonal())*side<clearance: return false
	return true

static func _prepare_exit_expansion(world: SimulationWorld, commander: CommanderState, record: LegionFormationState) -> bool:
	var transit := record.spatial.transit
	for batch in transit.batches:
		if batch.exit_stage!=2: return false
	var facing := record.spatial.facing
	if commander.deployment_goal==transit.goal and not commander.deployment_facing.is_zero_approx():
		facing=commander.deployment_facing.normalized(); record.spatial.facing=facing
	var identities := PackedInt32Array()
	var member_ids := PackedInt32Array()
	for batch in transit.batches:
		for identity in batch.identities:
			identities.append(identity)
			var unit := _entity(world,commander,identity)
			if unit!=null: member_ids.append(unit.entity_id)
	var occupied := PackedVector2Array()
	for unit: UnitState in world.units.values():
		if unit.enabled and unit.faction_id==commander.faction_id and not member_ids.has(unit.entity_id):
			occupied.append(unit.position)
	var deployment := LegionDeploymentPlanner.plan(commander.definition.profile.profile_id,record.spatial.action,identities,transit.goal,facing,world.logic_grid,occupied)
	if deployment.status not in [LegionDeploymentPlan.Status.STANDARD,LegionDeploymentPlan.Status.COMPRESSED]: return false
	if not _fit_exit_escort(world,commander,transit,deployment,occupied): return false
	record.spatial.deployment=deployment
	var targets := PackedVector2Array(); targets.resize(61)
	for batch in transit.batches:
		for identity in batch.identities:
			var offset: Vector2 = deployment.offsets[identity]
			var target := transit.goal+facing*offset.x+facing.orthogonal()*offset.y
			if not LegionTransitGeometry.segment_fits(world.logic_grid,target,target): return false
			targets[identity]=target
	for batch in transit.batches:
		batch.column_targets.clear()
		for identity in batch.identities: batch.column_targets.append(targets[identity])
	record.spatial.anchor=transit.goal
	return true

static func _fit_exit_escort(world: SimulationWorld, commander: CommanderState, transit: LegionTransitState, deployment: LegionDeploymentPlan, occupied: PackedVector2Array, allow_adjustment: bool = true) -> bool:
	var hero := _entity(world,commander,60)
	if not _available(world,hero) or transit.hero_batch<0 or deployment==null: return false
	var roles := LegionTemplate.find(commander.definition.profile.profile_id).slot_roles()
	var candidates: Array[int] = []
	for identity in transit.batches[transit.hero_batch].identities:
		if identity==60 or roles[identity] not in [1,2]: continue
		var core := _entity(world,commander,identity)
		if not _available(world,core): continue
		var path := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,hero.position,core.position)
		if path.size()>1 and LegionProtectionPlanner.path_length(path)<=240.0: candidates.append(identity)
	candidates.sort()
	if candidates.has(transit.escort_identity):
		candidates.erase(transit.escort_identity); candidates.push_front(transit.escort_identity)
	# Both final slots must admit the same real escort. Keep the original hero
	# slot when possible; otherwise search a bounded local pocket, retaining
	# every soldier identity/slot and the accepted objective.
	var deltas: Array[Vector2] = []
	# Sample the escort boundary geometrically as well as the coarse grid.
	# Other core exclusions can leave a legal pocket narrower than one unit.
	# The small inward margin absorbs world-coordinate rounding without
	# relaxing either the protection exclusion or the real 240 route limit.
	for identity in candidates:
		var core_offset := deployment.offsets[identity]
		var direction := (deployment.offsets[60]-core_offset).normalized()
		var delta := core_offset+direction*239.9-deployment.offsets[60]
		if delta.length_squared()<=96.0*96.0: deltas.append(delta)
	for x in range(-12,13):
		for y in range(-12,13):
			if x*x+y*y<=144 and not deltas.has(Vector2(x,y)*8.0): deltas.append(Vector2(x,y)*8.0)
	deltas.sort_custom(func(a: Vector2,b: Vector2) -> bool:
		if a.length_squared()!=b.length_squared(): return a.length_squared()<b.length_squared()
		return a.x<b.x if a.x!=b.x else a.y<b.y)
	# Once expansion has begun, a replacement inherits the accepted slots.
	# Repeated casualties must not accumulate further commander displacement.
	if not allow_adjustment: deltas=[Vector2.ZERO]
	for delta in deltas:
		var offset := deployment.offsets[60]+delta
		var point := deployment.anchor+deployment.facing*offset.x+deployment.facing.orthogonal()*offset.y
		if not LegionDeploymentPlanner.fits(PackedVector2Array([point]),world.logic_grid,occupied): continue
		var clear := true
		for identity in deployment.identities:
			if identity==60: continue
			var required := deployment.spacing
			if roles[identity] in [1,2]: required=LegionSpatialExecutor.protection_offset(commander.definition.profile.profile_id)
			elif roles[identity]==3: required=48.0
			if offset.distance_to(deployment.offsets[identity])<required-0.01: clear=false; break
		if not clear: continue
		for identity in candidates:
			var core_offset := deployment.offsets[identity]
			var core_point := deployment.anchor+deployment.facing*core_offset.x+deployment.facing.orthogonal()*core_offset.y
			var path := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,point,core_point)
			if path.size()<2 or LegionProtectionPlanner.path_length(path)>240.0: continue
			deployment.offsets[60]=offset
			deployment.points[deployment.identities.find(60)]=point
			transit.escort_identity=identity
			return true
	return false

static func _update_column_targets(world: SimulationWorld, transit: LegionTransitState, batch: LegionTransitState.BatchState) -> bool:
	if transit.phase==LegionTransitState.Phase.EXPAND or batch.exit_stage>0: return true
	if batch.gather_phase==0: return true
	if batch.targets_progress==batch.progress and batch.column_targets.size()==batch.identities.size(): return true
	var targets := _column_targets(world,transit,batch,batch.progress)
	if targets.size()!=batch.identities.size(): return false
	batch.column_targets=targets; batch.targets_progress=batch.progress
	return true

static func _staging_clear(world: SimulationWorld, point: Vector2, occupied: PackedVector2Array) -> bool:
	if not LegionTransitGeometry.segment_fits(world.logic_grid,point,point): return false
	for other in occupied:
		# Rotated Vector2 coordinates can round a nominal 48-unit separation
		# slightly below 48. Match the established column-slot tolerance.
		if point.distance_squared_to(other)<47.99*47.99: return false
	return true

static func _allocate_staging(world: SimulationWorld, commander: CommanderState, transit: LegionTransitState) -> bool:
	var occupied := PackedVector2Array()
	var targets: Array[Vector2] = []; targets.resize(61); targets.fill(Vector2(INF,INF))
	for batch in transit.batches:
		batch.gather_distances.resize(batch.identities.size())
		for ordinal in range(batch.identities.size()):
			batch.gather_distances[ordinal]=batch.progress-floori(ordinal/float(transit.columns))*48.0
	for batch in transit.batches:
		for ordinal in range(batch.identities.size()):
			var identity := batch.identities[ordinal]
			if identity==60: continue
			var base := batch.gather_distances[ordinal]
			for extra in range(61):
				var point := LegionTransitGeometry.point_at(transit.path,base-extra*48.0,batch.gather_laterals[ordinal])
				if _staging_clear(world,point,occupied):
					batch.gather_distances[ordinal]=base-extra*48.0
					targets[identity]=point; occupied.append(point); break
			if not targets[identity].is_finite(): return false
	var protected := transit.batches[transit.hero_batch]
	var escort := -1
	for identity in protected.identities:
		var unit := _entity(world,commander,identity)
		if _available(world,unit) and unit.tactical_role in [UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR]: escort=identity; break
	if escort<0: return false
	var base := protected.gather_distances[transit.hero_ordinal]
	for delta in range(49):
		var shift := ceili(delta/2.0)*(1 if delta%2 else -1)*48.0
		var point := LegionTransitGeometry.point_at(transit.path,base+shift,protected.gather_laterals[transit.hero_ordinal])
		if not _staging_clear(world,point,occupied): continue
		var route := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,point,targets[escort])
		if not route.is_empty() and LegionProtectionPlanner.path_length(route)<=240.0:
			protected.gather_distances[transit.hero_ordinal]=base+shift
			return true
	return false

static func _start(world: SimulationWorld, commander: CommanderState, record: LegionFormationState, source: FormationState, force: bool = false) -> bool:
	var state := record.spatial
	if not source.is_moving or (not force and state.action not in [LegionSpatialState.Action.MOVE,LegionSpatialState.Action.ATTACK]): return false
	var waypoints := source.planned_route.duplicate()
	if not force and state.intent==str([source.order_kind,source.order_destination,source.planned_route]):
		waypoints=state.route.slice(state.route_index)
	if waypoints.is_empty() or waypoints[-1]!=source.order_destination: waypoints.append(source.order_destination)
	var probe := LegionTransitGeometry.build(world.logic_grid,world.pathfinder,state.anchor,waypoints)
	if not probe.valid: return false
	var columns := 8
	for distance in range(0,641,32):
		var d := minf(distance,probe.total)
		var p := LegionTransitGeometry.point_at(probe,d)
		var tangent := LegionTransitGeometry.point_at(probe,d+1)-p
		columns=mini(columns,LegionTransitGeometry.columns_at(world.logic_grid,p,tangent))
	if columns>=8 and not force: return false
	# Plan the whole connected constriction before merging. A short apparent
	# widening at a bend is not an exit; demand 640 continuous wide space.
	var encountered_narrow := false; var wide_length := 0.0
	for distance in range(0,ceili(probe.total)+1,32):
		var point := LegionTransitGeometry.point_at(probe,distance)
		var tangent := LegionTransitGeometry.point_at(probe,distance+1)-point
		var capacity := LegionTransitGeometry.columns_at(world.logic_grid,point,tangent)
		if capacity<8:
			encountered_narrow=true; wide_length=0.0; columns=mini(columns,capacity)
		elif encountered_narrow:
			wide_length+=32.0
			if wide_length>=640.0: break
	var transit := state.transit
	transit.columns=maxi(1,columns); transit.intent=str([source.order_destination,source.planned_route])
	transit.source_route=source.planned_route.duplicate()
	transit.goal=source.order_destination; transit.path=probe; transit.started_tick=world.current_tick
	transit.phase=LegionTransitState.Phase.GATHER; transit.reason=&"TRANSIT_GATHER"
	for identity in range(61): transit.gather_navigation.append(LegionGatherNavigation.State.new())
	var depth := 0.0
	var forward := (probe.points[1]-probe.points[0]).normalized()
	for batch in record.batch_plan.batches:
		var next := LegionTransitState.BatchState.new()
		# Membership stays stable. Assign spatial rows from current positions
		# once at entry, then preserve left/right order within each row.
		var spatial_order: Array[int] = []
		for identity in batch.identities: spatial_order.append(identity)
		spatial_order.sort_custom(func(a: int,b: int) -> bool:
			var pa := _entry_position(world,commander,a,probe.points[0]).dot(forward)
			var pb := _entry_position(world,commander,b,probe.points[0]).dot(forward)
			return pa>pb if not is_equal_approx(pa,pb) else a<b)
		for start in range(0,spatial_order.size(),maxi(1,columns)):
			var row := spatial_order.slice(start,mini(start+maxi(1,columns),spatial_order.size()))
			row.sort_custom(func(a: int,b: int) -> bool:
				var pa := _entry_position(world,commander,a,probe.points[0]).dot(forward.orthogonal())
				var pb := _entry_position(world,commander,b,probe.points[0]).dot(forward.orthogonal())
				return pa<pb if not is_equal_approx(pa,pb) else a<b)
			for ordinal in range(row.size()): spatial_order[start+ordinal]=row[ordinal]
		next.identities=PackedInt32Array(spatial_order); next.progress=-depth
		for identity in next.identities: next.gather_laterals.append((_entry_position(world,commander,identity,probe.points[0])-probe.points[0]).dot(forward.orthogonal()))
		next.depth=(ceili(next.identities.size()/float(transit.columns))-1)*48.0+64.0
		for ordinal in range(next.identities.size()):
			if next.identities[ordinal]==60:
				transit.hero_batch=transit.batches.size(); transit.hero_ordinal=ordinal
		# A six-unit arrival tolerance on each adjacent batch must not consume
		# the required 96 physical clearance at column admission.
		transit.batches.append(next); depth+=next.depth+108.0
	if transit.hero_batch<0 or columns==0:
		# A narrow-road convoy is an optimisation for roads that can admit a
		# complete staging plan.  It is not allowed to take ownership of the
		# command when that local plan is impossible: the normal formation
		# executor can still move the hero/core through a valid route and retry
		# the convoy after the next command or terrain change.
		transit.phase=LegionTransitState.Phase.BLOCKED; transit.reason=&"TRANSIT_NO_CAPACITY"
		state.transit=LegionTransitState.new()
		return false
	elif not _allocate_staging(world,commander,transit):
		transit.phase=LegionTransitState.Phase.BLOCKED; transit.reason=&"TRANSIT_GATHER_NO_SPACE"
		state.transit=LegionTransitState.new()
		return false
	_plan_exit(world,transit)
	return true

static func prepare(world: SimulationWorld, commander: CommanderState, record: LegionFormationState, source: FormationState, visible: Array[UnitSnapshot]) -> bool:
	var state := record.spatial; var transit := state.transit
	if transit.phase==LegionTransitState.Phase.WIDE and not _start(world,commander,record,source): return false
	if transit.path==null or not transit.path.valid: return false
	var route_changed := source.planned_route!=transit.source_route and (source.is_moving or not source.planned_route.is_empty())
	if source.order_destination!=transit.goal or route_changed:
		# A new accepted order gets a fresh path from the actual current core.
		# Old progress, detours and reservations never keep driving the old goal.
		state.transit=LegionTransitState.new(); state.goal=source.order_destination
		state.anchor=_entry_position(world,commander,60,state.anchor); state.intent=""
		if not _start(world,commander,record,source,true): return false
		transit=state.transit
	if state.action==LegionSpatialState.Action.RETREAT:
		# Preserve current relative positions for the existing retreat executor.
		# Reverse-direction convoy admission is a separate next integration step.
		state.transit=LegionTransitState.new(); return false
	state.goal=transit.goal; state.relief=false; state.ready=0; state.eligible=0
	var retained_escort := _entity(world,commander,transit.escort_identity) if transit.escort_identity>=0 else null
	var keep_escort := transit.phase==LegionTransitState.Phase.EXPAND and retained_escort!=null and _available(world,retained_escort)
	if not keep_escort: transit.escort_identity=-1
	if not keep_escort and transit.phase==LegionTransitState.Phase.EXPAND:
		if not _fit_exit_escort(world,commander,transit,state.deployment,PackedVector2Array(),false):
			transit.reason=&"NO_CORE"; transit.expand_since=-1
	elif not keep_escort and transit.hero_batch>=0:
		for identity in transit.batches[transit.hero_batch].identities:
			var unit := _entity(world,commander,identity)
			if _available(world,unit) and unit.tactical_role in [UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR]:
				transit.escort_identity=identity; break
	var all_admitted := true
	for index in range(transit.batches.size()):
		var batch := transit.batches[index]
		batch.ready=0; batch.available=0
		if not _update_column_targets(world,transit,batch):
			transit.reason=&"TRANSIT_TARGET_CAPACITY"; all_admitted=false; continue
		for ordinal in range(batch.identities.size()):
			var unit := _entity(world,commander,batch.identities[ordinal])
			if not _available(world,unit): continue
			batch.available+=1
			if unit.position.distance_to(_target(transit,batch,ordinal))<=6.0: batch.ready+=1
		if batch.gather_phase==0 and batch.ready>=ceili(batch.available*0.8):
			batch.gather_phase=1; batch.ready=0
			if not _update_column_targets(world,transit,batch):
				batch.gather_phase=0; all_admitted=false; continue
		if not batch.admitted and batch.gather_phase==1 and batch.available>0 and batch.ready>=ceili(batch.available*0.8):
			var can_enter := true
			if index==transit.hero_batch:
				var hero := _entity(world,commander,60)
				can_enter=transit.escort_identity>=0 and _available(world,hero) and hero.position.distance_to(_target(transit,batch,transit.hero_ordinal))<=6.0
			if index>0:
				can_enter=can_enter and transit.batches[index-1].admitted
				var tail := INF; var head := -INF
				for identity in transit.batches[index-1].identities:
					var unit := _entity(world,commander,identity)
					if _available(world,unit): tail=minf(tail,LegionTransitGeometry.progress_at(transit.path,unit.position))
				for identity in batch.identities:
					var unit := _entity(world,commander,identity)
					if _available(world,unit): head=maxf(head,LegionTransitGeometry.progress_at(transit.path,unit.position))
				if tail-head<160.0: can_enter=false
			if can_enter: batch.admitted=true; batch.gather_phase=2
		if not batch.admitted: all_admitted=false
	if transit.exit_planned:
		if LegionTransitGeometry.window_fits(world.logic_grid,transit.path,transit.exit_mouth,transit.exit_mouth+640.0,8):
			if transit.exit_clear_since<0: transit.exit_clear_since=world.current_tick
		else: transit.exit_clear_since=-1
		for index in range(transit.batches.size()):
			var batch := transit.batches[index]
			if batch.exit_stage==1 and _batch_cleared_lane(world,commander,transit,index): batch.exit_stage=2
			if batch.exit_stage!=0 or not batch.admitted or batch.available==0 or batch.ready<batch.available: continue
			if batch.progress<transit.exit_head-0.01 or transit.exit_clear_since<0 or world.current_tick-transit.exit_clear_since<20: continue
			var tail := INF
			for identity in batch.identities:
				var unit := _entity(world,commander,identity)
				if _available(world,unit): tail=minf(tail,LegionTransitGeometry.progress_at(transit.path,unit.position)-32.0)
			if tail>=transit.exit_mouth: batch.exit_stage=1
	if transit.phase in [LegionTransitState.Phase.GATHER,LegionTransitState.Phase.COLUMN]:
		transit.phase=LegionTransitState.Phase.COLUMN if all_admitted else LegionTransitState.Phase.GATHER
		transit.reason=&"TRANSIT_COLUMN" if all_admitted else (&"TRANSIT_GATHER_BLOCKED" if world.current_tick-transit.started_tick>=50 else &"TRANSIT_GATHER")
	if transit.phase in [LegionTransitState.Phase.GATHER,LegionTransitState.Phase.COLUMN,LegionTransitState.Phase.EXIT_WAIT] and transit.advanced_tick!=world.current_tick:
		transit.advanced_tick=world.current_tick
		for index in range(transit.batches.size()):
			var batch := transit.batches[index]
			if batch.exit_stage>0: continue
			if not batch.admitted or batch.available==0 or batch.ready<ceili(batch.available*0.8): continue
			var pace := INF
			for identity in batch.identities:
				var unit := _entity(world,commander,identity)
				if _available(world,unit): pace=minf(pace,unit.move_speed)
			var limit := (transit.exit_head if transit.exit_mouth>=0.0 else transit.path.total) if all_admitted else minf(640.0,transit.path.total)
			var previous_index := index-1
			while previous_index>=0 and transit.batches[previous_index].exit_stage==2: previous_index-=1
			if previous_index>=0:
				for identity in transit.batches[previous_index].identities:
					var previous := _entity(world,commander,identity)
					if _available(world,previous): limit=minf(limit,LegionTransitGeometry.progress_at(transit.path,previous.position)-160.0)
			var proposed := minf(batch.progress+pace*SimulationWorld.TICK_SECONDS,limit)
			if proposed<=batch.progress: continue
			var rear := batch.progress-(ceili(batch.identities.size()/float(transit.columns))-1)*48.0
			if LegionTransitGeometry.window_fits(world.logic_grid,transit.path,rear-192.0,proposed,transit.columns):
				var targets := _column_targets(world,transit,batch,proposed)
				if targets.size()==batch.identities.size():
					batch.progress=proposed; batch.column_targets=targets; batch.targets_progress=proposed
				else: transit.reason=&"TRANSIT_TARGET_CAPACITY"
			else: transit.reason=&"TRANSIT_PATH_BLOCKED"
		if all_admitted and transit.phase in [LegionTransitState.Phase.COLUMN,LegionTransitState.Phase.GATHER] and transit.batches[0].progress>=(transit.exit_head if transit.exit_mouth>=0.0 else transit.path.total)-0.01:
			transit.phase=LegionTransitState.Phase.EXIT_WAIT; transit.reason=&"TRANSIT_EXIT_CAPACITY"
		if transit.phase==LegionTransitState.Phase.EXIT_WAIT:
			var clear := transit.exit_planned
			for batch in transit.batches:
				if batch.exit_stage!=2 or batch.ready<batch.available: clear=false; break
			if clear and _prepare_exit_expansion(world,commander,record):
				transit.phase=LegionTransitState.Phase.EXPAND; transit.reason=&"TRANSIT_EXIT_EXPAND"; transit.expand_since=-1
			elif clear: transit.reason=&"TRANSIT_EXIT_ROLE_CAPACITY"
			elif not transit.exit_planned: transit.reason=transit.exit_plan_reason
	for index in range(transit.batches.size()):
		var batch := transit.batches[index]
		for ordinal in range(batch.identities.size()):
			var identity := batch.identities[ordinal]
			var unit := _entity(world,commander,identity)
			if not _available(world,unit): continue
			var target := unit.position if transit.phase==LegionTransitState.Phase.BLOCKED else _target(transit,batch,ordinal)
			if identity==60:
				transit.hero_target=target; continue
			if identity==transit.escort_identity:
				var hero := _entity(world,commander,60)
				if hero!=null and hero.path_index<hero.path.size() and hero.position.distance_to(unit.position)>200.0:
					var next := hero.position.move_toward(hero.path[hero.path_index],hero.move_speed*SimulationWorld.TICK_SECONDS)
					if next.distance_to(unit.position)>240.0:
						target=hero.position.move_toward(unit.position,192.0)
			var slot := state.slots[identity]
			slot.entity_id=unit.entity_id; slot.admitted=true; slot.at_destination=false
			slot.tolerance=LegionReformationSystem.policy.tolerance(state.deployment.spacing) if transit.phase==LegionTransitState.Phase.EXPAND and state.deployment!=null else 6.0
			LegionSpatialExecutor._set_target(world,unit,slot,target,visible,false)
			if transit.phase in [LegionTransitState.Phase.GATHER,LegionTransitState.Phase.EXIT_WAIT,LegionTransitState.Phase.EXPAND]:
				var detour := LegionGatherNavigation.route(world,unit,target,transit.gather_navigation[identity])
				if detour.size()>1: slot.path=detour; slot.path_index=1
			if not LegionTransitGeometry.segment_fits(world.logic_grid,target,target):
				slot.target=unit.position; slot.path=PackedVector2Array(); slot.path_index=0; slot.reason=&"PATH_UNAVAILABLE"
			unit.legion_slot=slot; unit.desired_position=slot.target
			unit.local_engagement_active=false; unit.local_engagement_returning=false
			state.eligible+=1
			if unit.position.distance_to(target)<=6.0 and slot.reason!=&"PATH_UNAVAILABLE": state.ready+=1
	if transit.phase==LegionTransitState.Phase.EXPAND:
		var all_exit_ready:=transit.escort_identity>=0
		for batch in transit.batches:
			if batch.available==0 or batch.ready<batch.available: all_exit_ready=false; break
			for identity in batch.identities:
				var unit := _entity(world,commander,identity)
				if _available(world,unit) and LegionReformationSystem.damage_factor(unit)!=1.0: all_exit_ready=false
		if not all_exit_ready: transit.expand_since=-1
		elif transit.expand_since<0: transit.expand_since=world.current_tick
		if all_exit_ready and transit.expand_since>=0 and world.current_tick-transit.expand_since>=20:
			transit.reason=&"TRANSIT_EXIT_COMPLETE"
			for slot in state.slots:
				var unit := world.units.get(slot.entity_id) as UnitState
				if not _available(world,unit): continue
				var formation := world.formations.get(unit.formation_id) as FormationState
				slot.at_destination=formation!=null and formation.order_destination.distance_to(transit.goal)<=0.01 and unit.position.distance_to(slot.target)<=slot.tolerance
	if transit.phase!=LegionTransitState.Phase.EXPAND: state.anchor=transit.hero_target+state.facing*LegionSpatialExecutor.protection_offset(commander.definition.profile.profile_id)
	state.reason=transit.reason
	apply_constraints(world,commander,record)
	LegionTransitRejoin.prepare(world,commander,record,visible,transit.rejoin)
	return true

static func apply_constraints(world: SimulationWorld, commander: CommanderState, record: LegionFormationState) -> void:
	var transit := record.spatial.transit
	for index in range(transit.batches.size()):
		var previous := PackedInt32Array()
		var following := PackedInt32Array()
		var maintain_gap := transit.batches[index].admitted and transit.batches[index].exit_stage!=2 and transit.phase!=LegionTransitState.Phase.EXPAND
		var previous_index := index-1
		while previous_index>=0 and transit.batches[previous_index].exit_stage==2: previous_index-=1
		var following_index := index+1
		while following_index<transit.batches.size() and transit.batches[following_index].exit_stage==2: following_index+=1
		if previous_index>=0 and maintain_gap and transit.batches[previous_index].admitted:
			for identity in transit.batches[previous_index].identities:
				var unit := _entity(world,commander,identity)
				if _available(world,unit): previous.append(unit.entity_id)
		if following_index<transit.batches.size() and maintain_gap and transit.batches[following_index].admitted:
			for identity in transit.batches[following_index].identities:
				var unit := _entity(world,commander,identity)
				if _available(world,unit): following.append(unit.entity_id)
		for identity in transit.batches[index].identities:
			var unit := _entity(world,commander,identity)
			if not _available(world,unit): continue
			var partner := 0
			if identity==60 and transit.escort_identity>=0: partner=_entity(world,commander,transit.escort_identity).entity_id
			elif identity==transit.escort_identity: partner=commander.hero_entity_id
			unit.legion_motion=LegionMotionConstraint.new(partner)
			unit.legion_motion.ground_radius=32.0; unit.legion_motion.transit_path=transit.path
			unit.legion_motion.previous_batch=previous.duplicate()
			unit.legion_motion.next_batch=following.duplicate()
			if transit.batches[index].exit_stage>0 and transit.phase!=LegionTransitState.Phase.EXPAND:
				unit.legion_motion.exit_lane_origin=LegionTransitGeometry.point_at(transit.path,transit.exit_mouth)
				unit.legion_motion.exit_lane_normal=transit.exit_forward.orthogonal()
				unit.legion_motion.exit_lane_side=-1.0 if index%2==0 else 1.0
				unit.legion_motion.exit_lane_clearance=(transit.columns-1)*24.0+160.0

static func prepare_hero(world: SimulationWorld, commander: CommanderState, record: LegionFormationState, visible: Array[UnitSnapshot]) -> bool:
	var transit := record.spatial.transit
	if transit.phase==LegionTransitState.Phase.WIDE: return false
	var hero := world.units.get(commander.hero_entity_id) as UnitState
	if not _available(world,hero): return false
	apply_constraints(world,commander,record)
	var escort := _entity(world,commander,transit.escort_identity) if transit.escort_identity>=0 else null
	record.state.escort_id=escort.entity_id if escort!=null else 0
	if escort==null or not escort.enabled:
		record.reason=&"NO_CORE"; LegionFormationSystem._stop(hero); return true
	var steering_target := transit.hero_target
	if escort.legion_slot!=null:
		var core_slot := escort.legion_slot
		if core_slot.path_index<core_slot.path.size() and hero.position.distance_to(escort.position)>200.0:
			var next := escort.position.move_toward(core_slot.path[core_slot.path_index],escort.move_speed*SimulationWorld.TICK_SECONDS)
			if next.distance_to(hero.position)>240.0:
				# Give the real escort room to take a necessary detour while
				# maintaining the same physical protection radius.
				steering_target=escort.position.move_toward(hero.position,192.0)
	var route := LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,hero.position,steering_target)
	if transit.phase in [LegionTransitState.Phase.GATHER,LegionTransitState.Phase.EXIT_WAIT,LegionTransitState.Phase.EXPAND]:
		var detour := LegionGatherNavigation.route(world,hero,steering_target,transit.gather_navigation[60])
		if detour.size()>1: route=detour
	if route.is_empty() or LegionProtectionPlanner.route_adds_exposure(route,visible,hero.faction_id):
		record.reason=&"PATH_UNAVAILABLE"; LegionFormationSystem._stop(hero); return true
	var gap := LegionProtectionPlanner.path_length(LegionProtectionPlanner.route(world.logic_grid,world.pathfinder,hero.position,escort.position))
	record.reason=&"FORMING" if gap<=240.01 else &"REJOIN_CORE"
	hero.path=route; hero.path_index=1; hero.move_target=steering_target; hero.desired_position=transit.hero_target
	hero.has_move_target=hero.position.distance_to(steering_target)>6.0
	return true

static func refresh(world: SimulationWorld, commander: CommanderState, record: LegionFormationState) -> void:
	var state := record.spatial; var transit := state.transit
	state.ready=0; state.eligible=0
	for batch in transit.batches:
		batch.ready=0; batch.available=0
		for ordinal in range(batch.identities.size()):
			var identity := batch.identities[ordinal]
			var unit := _entity(world,commander,identity)
			if not _available(world,unit): continue
			batch.available+=1
			var tolerance := LegionReformationSystem.policy.tolerance(state.deployment.spacing) if transit.phase==LegionTransitState.Phase.EXPAND and state.deployment!=null else 6.0
			var ready := unit.position.distance_to(_target(transit,batch,ordinal))<=tolerance and LegionReformationSystem.damage_factor(unit)==1.0
			if ready: batch.ready+=1
			if identity==60: continue
			state.eligible+=1
			if ready and state.slots[identity].reason!=&"PATH_UNAVAILABLE": state.ready+=1
	state.reason=transit.reason
