class_name LegionDeploymentPreview
extends RefCounted

class Group extends RefCounted:
	var commander: CommanderSnapshot
	var formation_id := 0
	var identities := PackedInt32Array()
	var own_ids := PackedInt32Array()
	var start := Vector2.ZERO
	var lateral_min := INF
	var lateral_max := -INF

static func project(snapshot: WorldSnapshot, grid: LogicGrid, selected: Array[int], commander_id: StringName, goal: Vector2) -> Array[LegionDeploymentPlan]:
	var plans: Array[LegionDeploymentPlan] = []
	if snapshot==null or grid==null or not snapshot.growth_mode: return plans
	var groups: Array[Group] = []
	var commanders := snapshot.commanders.duplicate()
	commanders.sort_custom(func(a: CommanderSnapshot,b: CommanderSnapshot) -> bool: return String(a.definition_id)<String(b.definition_id))
	for commander: CommanderSnapshot in commanders:
		if commander.faction_id!=SimulationWorld.LOCAL_PLAYER_ID or commander.formation_mode==CommanderState.FormationMode.FREE: continue
		if not commander_id.is_empty() and commander.definition_id!=commander_id: continue
		var whole := commander.definition_id==commander_id and not commander_id.is_empty()
		var formations: Array[int] = []
		if whole: formations.append(0)
		else:
			for unit in snapshot.units:
				if selected.has(unit.entity_id) and unit.formation_id!=0 and commander.growth_slot_entities.has(unit.entity_id) and not formations.has(unit.formation_id): formations.append(unit.formation_id)
		formations.sort()
		for formation_id in formations:
			var group := Group.new(); group.commander=commander; group.formation_id=formation_id
			var full_card := true
			for identity in range(61):
				if identity!=60 and identity>=commander.growth_slot_entities.size(): continue
				var id: int = commander.hero_entity_id if identity==60 else commander.growth_slot_entities[identity]
				var unit := snapshot.get_unit(id)
				if unit==null or not unit.enabled: continue
				if whole and (unit.rejoin_pending or unit.legion_returning): continue
				if not whole and unit.formation_id!=formation_id: continue
				if not whole and not selected.has(id): full_card=false; break
				group.identities.append(identity); group.own_ids.append(id); group.start+=unit.position
			if not full_card or group.identities.is_empty(): continue
			group.start/=float(group.identities.size())
			if whole:
				var hero := snapshot.get_unit(commander.hero_entity_id)
				if hero!=null and hero.enabled: group.start=hero.position
			var formation := snapshot.get_formation(formation_id)
			if formation!=null: group.start=formation.anchor_position
			elif commander.legion_formation!=null and commander.legion_formation.spatial.initialized: group.start=commander.legion_formation.spatial.anchor
			var offsets := LegionDeploymentPlanner.offsets(commander.profile_id,(commander.formation_mode-1) as LegionSpatialState.Action,48.0)
			for identity in group.identities:
				group.lateral_min=minf(group.lateral_min,offsets[identity].y-32.0)
				group.lateral_max=maxf(group.lateral_max,offsets[identity].y+32.0)
			groups.append(group)
	var finder := GridPathfinder.new(grid)
	var total_width := maxf(0,groups.size()-1)*96.0
	var center := Vector2.ZERO
	for group in groups:
		total_width+=group.lateral_max-group.lateral_min; center+=group.start
	if groups.is_empty(): return plans
	center/=float(groups.size())
	var approach := LegionProtectionPlanner.route(grid,finder,center,goal)
	var direction := (approach[-1]-approach[-2]).normalized() if approach.size()>1 else Vector2.RIGHT
	var cursor := -total_width*0.5
	var reserved := PackedVector2Array()
	for group in groups:
		var anchor := goal
		if groups.size()>1: anchor+=direction.orthogonal()*(cursor-group.lateral_min)
		cursor+=group.lateral_max-group.lateral_min+96.0
		var occupied := reserved.duplicate()
		for unit in snapshot.units:
			if unit.enabled and unit.faction_id==group.commander.faction_id and not group.own_ids.has(unit.entity_id): occupied.append(unit.position)
		for formation in snapshot.formations:
			if formation.formation_id==group.formation_id or formation.legion_deployment==null: continue
			if group.formation_id==0 and group.own_ids.has(formation.leader_entity_id): continue
			var leader := snapshot.get_unit(formation.leader_entity_id)
			if leader!=null and leader.faction_id==group.commander.faction_id: occupied.append_array(formation.legion_deployment.points)
		var result := LegionDeploymentPlanner.movement_plan(group.commander.profile_id,group.identities,group.start,anchor,direction if groups.size()>1 else Vector2.ZERO,grid,occupied,true,finder,(group.commander.formation_mode-1) as LegionSpatialState.Action)
		result.formation_id=group.formation_id; result.commander_id=group.commander.definition_id
		plans.append(result)
		if result.status!=LegionDeploymentPlan.Status.BLOCKED: reserved.append_array(result.points)
	return plans
