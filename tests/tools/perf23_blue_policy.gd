extends RefCounted
const LEGIONS: Array[StringName] = [&"bai_jiuyang",&"di_tian",&"lin_mo",&"lu_zheng",&"mobile_legion"]
var command_sink: Callable
var strategy: String
var actions: Array[Dictionary] = []
var objective_index := 0
var active_objective: StringName
var jungle_index := 0
var active_jungle: StringName
var configured := false
var last_attempt := -1000
var concentration_targets: Dictionary = {}
func _init(value: String = "passive") -> void: strategy=value
func army_plan() -> ArmyPlan:
	var army := BattleContentLoader.load_battle(&"final_decision").battle.create_default_army_plan()
	if strategy in ["economy","jungle","flank"]:
		for i in range(army.legions.size()):
			army.legions[i].role_strengths=PackedInt32Array([5,45,0,10])
			if strategy=="jungle" and i in [1,4]: army.legions[i].role_strengths=PackedInt32Array([5,25,20,10])
	if strategy in ["concentration","decisive"]:
		for legion in army.legions: legion.role_strengths=PackedInt32Array([10,40,0,10])
	if strategy=="decisive":
		for legion in army.legions: legion.role_strengths=PackedInt32Array([4,48,0,8])
	if strategy=="artillery":
		for legion in army.legions: legion.role_strengths=PackedInt32Array([6,12,12,30])
	return army
func _submit(world: SimulationWorld,command: GameCommand,label: String) -> bool:
	var result: CommandValidationResult = command_sink.call(command) if command_sink.is_valid() else world.submit_command(command)
	actions.append({"tick":world.current_tick,"action":label,"result":result.describe()})
	return result.is_accepted()
func advance(world: SimulationWorld) -> void:
	if strategy=="passive": return
	if not configured:
		configured=true
		var rates: Array[int]=[1,1,1,1,1]
		if strategy=="jungle": rates=[1,1,1,2,0]
		_submit(world,RecruitmentPlanCommand.new(world.allocate_command_id(),1,world.current_tick,LEGIONS,rates,12 if strategy in ["decisive","flank"] else 40),"recruitment reserve12" if strategy in ["decisive","flank"] else "recruitment reserve40")
	if world.current_tick%20!=0: return
	var view := world.create_faction_snapshot(1)
	_support(world,view)
	if strategy in ["economy","jungle"]: _central(world,view)
	if strategy=="jungle": _jungle(world,view)
	if strategy in ["concentration","maneuver","decisive","flank"]: _concentrate(world,view)

func _concentrate(world: SimulationWorld,view: WorldSnapshot) -> void:
	# Public map/blue knowledge only: mass three combat legions and the reserve
	# along the central supply chain; leave the bottom legion autonomous.
	var targets: Array[StringName]=[&"blue_mid_high",&"blue_mid_inner",&"blue_mid_outer",&"red_mid_outer",&"red_mid_inner",&"red_mid_high",&"red_base"]
	if strategy=="flank": targets.assign([&"blue_top_high",&"blue_top_inner",&"blue_top_outer",&"red_top_outer",&"red_top_inner",&"red_top_high",&"red_base"])
	while objective_index<targets.size()-1:
		var point:=view.get_strategic_region(targets[objective_index])
		if point==null or point.controller_faction_id!=1 or point.contested: break
		objective_index+=1
	var target:=view.get_strategic_region(targets[objective_index])
	if target==null: return
	var committed:Array[StringName]=[]
	committed.assign([&"di_tian",&"mobile_legion"] if strategy=="maneuver" else [&"bai_jiuyang",&"di_tian",&"lu_zheng",&"mobile_legion"])
	if strategy=="decisive": committed.assign(LEGIONS)
	if strategy=="flank": committed.assign([&"bai_jiuyang",&"mobile_legion"])
	for id: StringName in committed:
		var commander:=view.get_commander(id)
		if commander==null or commander.growth_recovering: continue
		if concentration_targets.get(id,&"")==target.region_id and commander.target_region_id==target.region_id: continue
		if _order(world,id,target): concentration_targets[id]=target.region_id
func _support(world: SimulationWorld,view: WorldSnapshot) -> void:
	var faction := view.get_faction(1)
	for kind in [SupportOrderCommand.SupportKind.FIELD_HOSPITAL,SupportOrderCommand.SupportKind.MISSILE_BARRAGE]:
		var definition := world.battle_definition.support_for_kind(kind)
		if faction.supply<definition.supply_cost or int(faction.support_cooldown_until_by_kind.get(kind,0))>view.tick: continue
		var best_count:=0
		var best: UnitSnapshot
		for candidate in view.units:
			if not candidate.enabled: continue
			var hospital: bool=kind==SupportOrderCommand.SupportKind.FIELD_HOSPITAL
			if hospital:
				if candidate.faction_id!=1 or candidate.health>=candidate.max_health*0.7 or not AreaSupportSystem.hospital_position_allowed(view,candidate.position): continue
			elif candidate.faction_id==1 or not candidate.is_visible_to_local_player: continue
			var count:=0
			var friendlies:=0
			var unsafe:=false
			for unit in view.units:
				if not unit.enabled: continue
				var distance:=unit.position.distance_to(candidate.position)
				if hospital:
					if unit.faction_id==1 and unit.health<unit.max_health*0.7 and distance<definition.area_radius: count+=1
				else:
					if unit.faction_id==1 and distance<definition.area_radius+200:
						if strategy in ["fire_support","maneuver","decisive"]: friendlies+=1
						else: unsafe=true; break
					if unit.faction_id!=1 and unit.is_visible_to_local_player and distance<definition.area_radius: count+=1
			if strategy in ["fire_support","maneuver","decisive"] and not hospital:
				for building in view.buildings:
					if building.enabled and building.faction_id==1 and building.position.distance_to(candidate.position)<definition.area_radius+200: unsafe=true
				if friendlies>0 and count<friendlies*3: unsafe=true
				count-=friendlies
			if not unsafe and count>best_count: best=candidate; best_count=count
		if best!=null and best_count>=(4 if kind==SupportOrderCommand.SupportKind.FIELD_HOSPITAL else 6):
			if _submit(world,AreaSupportCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,view.tick,kind,best.position),"support %d cluster%d" % [kind,best_count]): return
func _order(world: SimulationWorld,commander: StringName,target: StrategicRegionSnapshot) -> bool:
	# The headquarters footprint is occupied; give a public-map approach point.
	var destination:=target.position+Vector2(-256,256) if target.region_id==&"red_base" else target.position
	var command:=CommanderOrderCommand.new(world.allocate_command_id(),1,world.current_tick,commander,CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE,destination,target.region_id,CommanderState.Posture.AGGRESSIVE if strategy=="decisive" else CommanderState.Posture.BALANCED)
	command.hand_back_control=true
	command.apply_requested_posture=true
	return _submit(world,command,"objective %s -> %s" % [commander,target.region_id])
func _central(world: SimulationWorld,view: WorldSnapshot) -> void:
	if not active_objective.is_empty() and active_objective!=&"red_base":
		for graph in view.commander_task_graphs:
			if graph.approved_plan==null or graph.approved_plan.objective_region_id!=active_objective: continue
			var unfinished:=false
			var failed:=false
			for node in graph.nodes:
				if node.phase==CommanderTaskStageDefinition.Phase.RETREAT: continue
				if node.lifecycle in [CommanderTaskNodeSnapshot.Lifecycle.FAILED,CommanderTaskNodeSnapshot.Lifecycle.CANCELLED]: failed=true
				elif not node.is_satisfied(): unfinished=true
			if not failed and unfinished and not graph.retreat_requested: return
			if (failed or graph.retreat_requested) and view.tick-last_attempt<300: return
		active_objective=&""
	var targets: Array[StringName]=[&"blue_mid_high",&"blue_mid_inner",&"blue_mid_outer",&"red_mid_outer",&"red_mid_inner",&"red_mid_high",&"red_base"]
	while objective_index<targets.size()-1:
		var point:=view.get_strategic_region(targets[objective_index])
		if point==null or point.controller_faction_id!=1 or point.contested: break
		objective_index+=1
	var target:=view.get_strategic_region(targets[objective_index])
	if target==null or active_objective==target.region_id or view.tick-last_attempt<100: return
	last_attempt=view.tick
	if target.region_id==&"red_base":
		if _order(world,&"di_tian",target) and _order(world,&"mobile_legion",target): active_objective=target.region_id
		return
	var request:=StaffPlanRequest.new()
	request.objective_region_id=target.region_id
	request.coordination=StaffPlanRequest.Coordination.JOINT_ATTACK
	request.formation=StaffPlanRequest.Formation.DEPTH
	for card in view.unit_cards:
		if card.commander_definition_id in [&"di_tian",&"mobile_legion"] and card.authorized_strength>0: request.allowed_card_ids.append(card.definition_id)
	var generator:=StaffPlanGenerator.new()
	var plans:=generator.generate(view,1,request)
	if plans==null:
		actions.append({"tick":view.tick,"action":"joint generation", "result":str(generator.last_rejection_reason)})
		return
	for plan in plans.plans:
		if plan.kind!=StaffPlanProfile.Kind.DIRECT: continue
		if _submit(world,StaffPlanApprovalCommand.new(world.allocate_command_id(),1,view.tick,request,plan.profile_id,plan.fingerprint()),"joint -> "+String(target.region_id)): active_objective=target.region_id
		return
func _jungle(world: SimulationWorld,view: WorldSnapshot) -> void:
	var targets: Array[StringName]=[&"jungle_upper_rear",&"jungle_upper_major",&"jungle_upper_forward"]
	while jungle_index<targets.size()-1:
		var region:=view.get_strategic_region(targets[jungle_index])
		if region==null or region.controller_faction_id!=1 or region.contested: break
		jungle_index+=1
	var target:=view.get_strategic_region(targets[jungle_index])
	var commander:=view.get_commander(&"lu_zheng")
	if target!=null and (active_jungle!=target.region_id or commander!=null and commander.target_region_id!=target.region_id and not commander.growth_recovering):
		if _order(world,&"lu_zheng",target):
			active_jungle=target.region_id
			if jungle_index==2: _submit(world,RecruitmentPlanCommand.new(world.allocate_command_id(),1,view.tick,LEGIONS,[1,1,1,0,2],40),"jungle income -> mobile priority")
