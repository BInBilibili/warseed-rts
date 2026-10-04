extends SceneTree
# Isolated design laboratory: real movement/pathfinding/projectile damage,
# candidate formation policy. Never loaded by production or the release gate.

class LabFormation extends FormationState:
	var offsets: Array[Vector2] = []
	var pace := 135.0
	var facing := Vector2.RIGHT
	var action := "attack"
	var compact := false
	var profile := 0
	var revised := true
	var held_cannons: Dictionary = {}
	var contact_tick := -1
	var retreat_reason := ""
	var scouts_recalled := false
	var risk_ticks := 0
	var damage_window: Array[float] = []
	var damage_window_max: Array[float] = []
	var hold_until := -1
	func get_wide_offset(slot_id: int) -> Vector2:
		if slot_id < 0 or slot_id >= offsets.size(): return Vector2.ZERO
		if compact:
			return Vector2(-floori(slot_id / 5.0) * 38.0, (slot_id % 5 - 2) * 38.0)
		return offsets[slot_id]
	func get_recon_offset(slot_id: int) -> Vector2:
		return get_wide_offset(slot_id)
	func uses_recon_spread(_units: Dictionary) -> bool:
		return false

class LabMovement extends FormationMovementSystem:
	var raw_speed_corrections := 0
	func _update_mode(formation: FormationState) -> void:
		if (formation as LabFormation).revised and not (formation as LabFormation).compact:
			# Local combat fixtures are open ground. Legacy recovery must not
			# overwrite the candidate's protected slots with an ID-sorted column.
			formation.mode = FormationState.MovementMode.WIDE
			formation.forced_column_ticks = 0
		else: super(formation)
	func _create_desired_positions(formation: FormationState, tangent: Vector2, recon_spread: bool = false) -> Dictionary:
		var desired := super(formation, tangent, recon_spread)
		for id in (formation as LabFormation).held_cannons:
			if desired.has(id): desired[id] = (formation as LabFormation).held_cannons[id]
		return desired
	func _init(grid: LogicGrid, finder: GridPathfinder) -> void:
		super(grid, finder, true)
	func _advance_formation(formation: FormationState, units: Dictionary, events: Array[SimulationEvent], tick: int) -> void:
		var stable_members:=formation.member_entity_ids.duplicate()
		# Production world prunes dead members before movement; preserve lab slot
		# IDs and statistics while excluding corpses from separation.
		for id in stable_members:
			if not units[id].enabled:formation.member_entity_ids.erase(id)
		var before: Dictionary={}
		for id in formation.member_entity_ids: before[id]=units[id].position
		super(formation,units,events,tick)
		# Prototype adapter: existing hard separation can push farther than speed.
		# Clamp with segment validation; count corrections instead of hiding them.
		for id in formation.member_entity_ids:
			var u: UnitState=units[id]
			if not u.enabled:continue
			var start: Vector2=before[id]
			var maximum:=u.move_speed*SimulationWorld.TICK_SECONDS
			if start.distance_to(u.position)>maximum+0.001:
				raw_speed_corrections+=1
				var limited:=start.move_toward(u.position,maximum)
				u.position=limited if logic_grid.is_segment_walkable(start,limited) else start
		formation.member_entity_ids.assign(stable_members)
	func _get_tangent(formation: FormationState) -> Vector2:
		return (formation as LabFormation).facing
	func _advance_anchor(formation: FormationState, speed_scale: float = 1.0) -> void:
		if formation.path_index >= formation.path.size(): return
		var distance := (formation as LabFormation).pace * SimulationWorld.TICK_SECONDS * speed_scale
		while distance > 0 and formation.path_index < formation.path.size():
			var target := formation.path[formation.path_index]
			var gap := formation.anchor_position.distance_to(target)
			if gap <= distance:
				formation.anchor_position = target
				formation.path_index += 1
				distance -= gap
			else:
				formation.anchor_position = formation.anchor_position.move_toward(target, distance)
				distance = 0
			formation.append_anchor_history(formation.anchor_position, 42 * formation.member_entity_ids.size() + 36)

var profiles: Array = []
var results: Array = []
var errors: Array = []
var base_version := ""
const OUT := "res://artifacts/legion34/v3/"

func _initialize() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT + "config.json"))
	profiles = config.profiles
	base_version = config.version
	var mode := "smoke"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	if mode == "smoke":
		results.append(battle(0, 1, 12, 12, "duel", "special", 0, false, true))
		results.append(battle(3, 1, 12, 12, "capture", "special", 0, false, true))
	elif mode == "matrix":
		for strength in [12, 36, 60]:
			for a in range(5):
				for b in range(a + 1, 5):
					if a != 3 and b != 3: continue
					for seed in range(2):
						for mirrored in [false, true]:
							results.append(battle(a,b,strength,strength,"duel","special",seed,mirrored))
				print("MATRIX_PROGRESS ",strength," ",a," cases=",results.size())
	elif mode == "roles":
		for strength in [12,24,36,48,60]:
			for a in range(5):
				if a != 3: continue
				for scenario in ["attack_defense","flank","retreat","travel","capture"]:
					for form in ["special","legacy"]:
						for mirrored in [false,true]:
							results.append(battle(a,0,strength,strength,scenario,form,0,mirrored, strength==12 and not mirrored and form=="special"))
				print("ROLES_PROGRESS ",strength," ",a," cases=",results.size())
	elif mode == "budget":
		for budget in [40,80,108]:
			for a in range(5):
				for b in range(a+1,5):
					if a != 3 and b != 3: continue
					for mirrored in [false,true]:
						var row := battle(a,b,affordable(a,budget),affordable(b,budget),"duel","special",1,mirrored)
						row["budget"] = budget
						results.append(row)
	elif mode == "repeat":
		for a in range(5):
			var first := battle(a,(a+1)%5,36,36,"duel","special",7,false)
			var second := battle(a,(a+1)%5,36,36,"duel","special",7,false)
			if JSON.stringify(first) != JSON.stringify(second): errors.append("repeat_"+str(a))
			results.append(first)
	elif mode == "role_extra":
		for strength in [12,24,36,48,60]:
			for form in ["special","legacy"]:
				for mirrored in [false,true]:
					results.append(battle(2,1,strength,24,"siege",form,0,mirrored,true))
					results.append(battle(3,0,strength,int(strength/2),"light_guard",form,0,mirrored))
	elif mode == "contracts":
		for a in range(5):
			var hidden1:=battle(a,0,12,12,"hidden1","special",3,false)
			var hidden2:=battle(a,0,12,12,"hidden2","special",3,false)
			if hidden1.own_trace_sha256!=hidden2.own_trace_sha256:errors.append("hidden_pollution_"+str(a))
			results.append({"profile":profiles[a].id,"hidden_isolation":hidden1.own_trace_sha256==hidden2.own_trace_sha256})
			var units:Dictionary={}
			var army:=spawn_army(a,12,1,1,Vector2(1500,1500),Vector2.RIGHT,"attack","special",units)
			var eligible:=0
			for id in army.member_entity_ids:
				var u:UnitState=units[id]
				var role:=int(String(u.definition_id).trim_prefix("lab_"))
				if role!=0:continue
				if bool(profiles[a].troops[0].capture):eligible+=1
			if (eligible>0)!=(a==3):errors.append("scout_capture_"+str(a))
			results.append({"profile":profiles[a].id,"scout_only_capture_eligible":eligible,"ordinary_capture_ticks":60})
		for armor in [20,22,28]:
			results.append(hero_focus(armor))
	var report := {"version":base_version,"mode":mode,"evidence":"SIMULATED_PROTOTYPE","cases":results.size(),"errors":errors,"results":results}
	FileAccess.open(OUT+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("LEGION34_DONE ",mode," cases=",results.size()," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)

func affordable(profile: int, budget: int) -> int:
	var used := 0
	var p: Dictionary = profiles[profile]
	for step in range(48):
		var cost := int(p.troops[int(p.growth_roles[step])].cost)
		if used+cost > budget: return 12+step
		used += cost
	return 60

func counts(profile: int, strength: int) -> Array[int]:
	var p: Dictionary = profiles[profile]
	var result: Array[int] = []
	for n in p.start: result.append(int(n))
	if strength < 12:
		var remainder: Array[float] = []
		var total := 0
		for role in range(4):
			var exact := float(result[role]) * strength / 12.0
			result[role] = floori(exact)
			remainder.append(exact - result[role])
			total += result[role]
		while total < strength:
			var role := remainder.find(remainder.max())
			result[role] += 1
			remainder[role] = -1.0
			total += 1
		return result
	for step in range(strength-12): result[int(p.growth_roles[step])] += 1
	return result

func offset_for(profile: int, role: int, index: int, count: int, action: String, legacy: bool, ordinal: int, strength: int) -> Vector2:
	if legacy: return legacy_offset_for(profile,role,index,count,action,false,ordinal,strength)
	var offset := legacy_offset_for(profile,role,index,count,action,false,ordinal,strength)
	if role == 4:
		return Vector2(-[160.0,160.0,192.0,128.0,128.0][profile] + 80.0, 0)
	if profile == 2:
		var columns := mini(12, maxi(4, ceili(sqrt(float(strength))*1.5)))
		var row := index / columns
		var span := mini(columns, count - row*columns)
		offset = Vector2(96 if role == 2 else (48 if role == 1 else -80), (index%columns-(span-1)*0.5)*48)
		if role in [1,2]: offset.x -= row*48
		if role == 3: offset.x = -80 - row*48
		if action == "retreat" and role == 3: offset.x -= 64
	if profile == 3 and role == 0:
		if action != "retreat" and index < 4:
			return Vector2(240, (index-1.5)*48)
		var rear := maxi(0,index-4)
		return Vector2(-96-floori(rear/8.0)*48,(rear%8-3.5)*48)
	return offset

func effective_strength(ids: Array, units: Dictionary, observer: LabFormation) -> float:
	var total := 0.0
	for id in ids:
		var unit: UnitState = units[id]
		if not unit.enabled or unit.position.distance_to(observer.anchor_position) > 800: continue
		var role := int(String(unit.definition_id).trim_prefix("lab_"))
		var weight: float = [0.45,1.0,1.5,1.2,1.5][role]
		if role == 0 and unit.max_health >= 180: weight = 0.7
		if role == 3 and unit.weapon_prepared_ticks < 20: weight *= 0.5
		total += weight * unit.health / unit.max_health
	return total

func revise_policy(army: LabFormation, units: Dictionary, legal: Array, tick: int, grid: LogicGrid) -> void:
	if not army.revised: return
	var core: Array[int] = []
	var hero_id := army.member_entity_ids[-1]
	var hero: UnitState = units[hero_id]
	var core_health := 0.0
	var core_max := 0.0
	var scouts := 0
	for id in army.member_entity_ids:
		var u: UnitState = units[id]
		var role := int(String(u.definition_id).trim_prefix("lab_"))
		if u.enabled and role in [1,2]: core.append(id)
		if role == 0:
			if scouts < 4:
				core_health += u.health if u.enabled else 0.0
				core_max += u.max_health if u.enabled else 0.0
			scouts += 1
	if core.is_empty():
		army.action = "retreat"
		army.retreat_reason = "core_lost"
	elif hero.enabled:
		var nearest := core[0]
		for id in core:
			if hero.position.distance_squared_to(units[id].position) < hero.position.distance_squared_to(units[nearest].position): nearest = id
		var desired: Vector2 = units[nearest].position - army.facing * [160.0,160.0,192.0,128.0,128.0][army.profile]
		if grid.is_segment_walkable(hero.position, desired):
			var delta := desired - army.anchor_position
			army.offsets[army.offsets.size()-1] = Vector2(delta.dot(army.facing),delta.dot(Vector2(-army.facing.y,army.facing.x)))
	if army.profile == 3 and army.action != "retreat":
		army.damage_window.append(core_health)
		army.damage_window_max.append(core_max)
		if army.damage_window.size() > 7:
			army.damage_window.pop_front()
			army.damage_window_max.pop_front()
		var own := effective_strength(army.member_entity_ids, units, army)
		var threat := effective_strength(legal, units, army)
		if threat > own*1.1: army.risk_ticks += 5
		else: army.risk_ticks = 0
		if not legal.is_empty() and army.contact_tick < 0: army.contact_tick = tick
		if army.damage_window_max[0]>0 and army.damage_window[0]-core_health >= army.damage_window_max[0]*0.15:
			army.scouts_recalled = true
		if army.risk_ticks >= 10:
			army.action = "retreat"
			army.retreat_reason = "observed_risk"
		elif army.contact_tick == tick and threat > own*0.7:
			army.action = "retreat"
			army.retreat_reason = "declined_strong_contact"
	if army.profile == 3 and (army.scouts_recalled or army.action == "retreat"):
		# Scout recall alone does not cancel a favorable task. The separate
		# observed-risk condition controls whole-legion disengagement.
		for i in range(army.member_entity_ids.size()):
			if units[army.member_entity_ids[i]].tactical_role == UnitState.TacticalRole.SCOUT:
				army.offsets[i].x = minf(army.offsets[i].x,-96.0)
	if army.action == "retreat":
		army.held_cannons.clear()
		return
	if army.profile != 2: return
	for id in army.member_entity_ids:
		var u: UnitState = units[id]
		if not u.enabled or u.tactical_role != UnitState.TacticalRole.FIREPOWER: continue
		var near := INF
		for enemy_id in legal: near = minf(near,u.position.distance_to(units[enemy_id].position))
		if near < 240 or near > 420: army.held_cannons.erase(id)
		elif near <= 400: army.held_cannons[id] = u.position if not army.held_cannons.has(id) else army.held_cannons[id]

func cannon_ready(army: LabFormation, units: Dictionary, legal: Array, tick: int) -> bool:
	var active := 0
	var ready := 0
	for id in army.member_entity_ids:
		var u: UnitState = units[id]
		if not u.enabled or u.tactical_role != UnitState.TacticalRole.FIREPOWER: continue
		active += 1
		if army.held_cannons.has(id): ready += 1
	if ready > 0 and army.contact_tick < 0: army.contact_tick = tick
	var enough := ready >= maxi(1,ceili(active*0.6)) or (ready > 0 and army.contact_tick >= 0 and tick-army.contact_tick >= 40)
	if enough: army.hold_until = maxi(army.hold_until,tick+20)
	return enough or (tick < army.hold_until and ready > 0)

func legacy_offset_for(profile: int, role: int, index: int, count: int, action: String, generic: bool, ordinal: int, strength: int) -> Vector2:
	if generic:
		if role==4:return Vector2(-65,0)
		return Vector2(-floori(ordinal/5.0)*38, (ordinal%5-2)*38)
	if action == "move":
		if role == 4: return Vector2(-90,0)
		var move_y:float=[-125,0,125,-55][role]
		var shift:float=0
		if profile==0:shift=35 if role==2 else 0
		if profile==1:shift=-35 if role==3 else 0
		if profile==2:shift=40 if role in [1,2] else -20
		if profile==3:shift=160 if role==0 else 0
		if profile==4:shift=45 if role==1 else 0
		return Vector2(95+shift-floori(index/2.0)*38,move_y+(index%2-0.5)*38)
	var width := mini(9,maxi(3,ceili(sqrt(float(strength))*1.1)))
	var row := floori(index/float(width))
	var col := index % width
	var actual_width := mini(width,count-row*width)
	var side := (col-(actual_width-1)*0.5)*38
	if role==4: return Vector2(-65,0)
	if role==0:
		if action=="retreat":return Vector2(-100-row*38,side)
		if profile==3: return Vector2(105-row*38,side)
		return Vector2(45-floori(index/2.0)*38,(-1 if index%2==0 else 1)*(190+floori(index/2.0)*12))
	var x: float = [0,45,110,-95][role]-row*38
	if profile==0 and role==2: x=135-absf(side)*0.40-row*36
	if profile==1:
		x=([0,20,85,-110][role])-row*38
		if action=="defend": x-=absf(side)*0.12
	if profile==2:
		x=([0,100,110,-55][role])-row*38
		if role==3: x-=absf(side)*0.12
	if profile==3:
		x=([0,0,60,-90][role])-row*38
		if action=="attack": side+=50
	if profile==4: x=([0,75,120,-80][role])-row*38
	if action=="defend" and profile!=1:
		x-=absf(side)*(0.12 if profile==0 else 0.20)
		if profile==2 and role==3:x-=30
		if profile==4 and role==1:side*=1.1
	if action=="retreat":
		if role==3: x=-170-row*38
		elif role==0: x=-100-row*38
		elif role==2: x=130-row*38
		else: x=45-row*38
		if profile==1 and role in [1,2]:x+=20
		if profile==2 and role==3:x-=30
		if profile==4 and role==1:x+=20
	return Vector2(x,side)

func spawn_army(profile: int, strength: int, faction: int, id_base: int, center: Vector2, facing: Vector2, action: String, form: String, units: Dictionary) -> LabFormation:
	var p: Dictionary = profiles[profile]
	var members: Array[int] = []
	var offsets: Array[Vector2] = []
	var amounts := counts(profile,strength)
	var pace := float(p.hero.speed)
	for role in range(5):
		var number: int = 1 if role==4 else amounts[role]
		var stat: Dictionary = p.hero if role==4 else p.troops[role]
		if role!=0 and number>0: pace=minf(pace,float(stat.speed))
		for i in range(number):
			var id := id_base+members.size()
			var offset := offset_for(profile,role,i,number,action,form!="special",members.size(),strength)
			var position := center+facing*offset.x+Vector2(-facing.y,facing.x)*offset.y
			var unit := UnitState.new(id,position,float(stat.speed),faction)
			unit.max_health=float(stat.hp)
			unit.health=unit.max_health
			unit.armor=float(stat.armor)
			unit.attack_damage=float(stat.damage)
			unit.attack_range=float(stat.range)
			unit.attack_cooldown_ticks=int(stat.cooldown)
			unit.sight_range=float(stat.sight)
			unit.projectile_speed=420 if role==3 else (560 if role==0 else 600)
			unit.definition_id=StringName("lab_"+str(role))
			unit.tactical_role=role+1 if role<4 else 0
			unit.following_formation=true
			if role==4: unit.hero_commander_id=StringName(p.id)
			if role==3:
				var weapon := TacticalWeaponDefinition.new()
				weapon.health_only_damage=true
				weapon.damage_multiplier_min=0.4
				weapon.damage_multiplier_max=1.6
				weapon.preparation_ticks=20
				unit.configure_tactical_weapon(weapon)
			units[id]=unit
			members.append(id)
			offsets.append(offset)
	var formation := LabFormation.new(faction,members,center)
	formation.offsets=offsets
	formation.profile=profile
	formation.revised=form=="special"
	formation.pace=pace
	formation.facing=facing
	formation.action=action
	formation.strict_deployment_slots=true
	formation.reset_anchor_history(facing)
	for id in members: units[id].formation_id=faction
	return formation

func alive(units: Dictionary, army: LabFormation, soldiers_only: bool = false) -> int:
	var result := 0
	for id in army.member_entity_ids:
		var u: UnitState = units[id]
		if u.enabled and (not soldiers_only or u.hero_commander_id.is_empty()): result+=1
	return result

func health_fraction(units: Dictionary, army: LabFormation) -> float:
	var hp := 0.0
	var total := 0.0
	for id in army.member_entity_ids:
		var u: UnitState=units[id]
		total+=u.max_health
		hp+=u.health if u.enabled else 0.0
	return hp/total

func visible_contacts(units: Dictionary, own: LabFormation, enemy: LabFormation) -> Array[int]:
	var visible: Array[int]=[]
	for target_id in enemy.member_entity_ids:
		var target: UnitState=units[target_id]
		if not target.enabled: continue
		for observer_id in own.member_entity_ids:
			var observer: UnitState=units[observer_id]
			if observer.enabled and observer.position.distance_squared_to(target.position)<=observer.sight_range*observer.sight_range:
				visible.append(target_id)
				break
	return visible

func order(army: LabFormation, destination: Vector2, pathfinder: GridPathfinder) -> void:
	army.target_position=destination
	army.path=pathfinder.find_path(army.anchor_position,destination)
	army.path_index=1
	army.is_moving=true
	if army.path.size()<=1: army.path=PackedVector2Array([army.anchor_position]);army.path_index=1

func battle(a: int, b: int, na: int, nb: int, scenario: String, form: String, seed: int, mirrored: bool, replay: bool = false) -> Dictionary:
	var grid := LogicGrid.new()
	grid.grid_size=Vector2i(192,96)
	if scenario=="choke":
		for x in range(78,102):
			for y in range(96):
				if y<43 or y>52: grid.set_blocked(Vector2i(x,y),true)
	var pathfinder := GridPathfinder.new(grid)
	var movement := LabMovement.new(grid,pathfinder)
	var units: Dictionary={}
	var direction := -1.0 if mirrored else 1.0
	var ac:=Vector2(2100 if not mirrored else 3500,1536+seed*3)
	var bc:=Vector2(3500 if not mirrored else 2100,1536-seed*3)
	var action := "defend" if scenario=="attack_defense" else "attack"
	if scenario in ["travel","choke"]: action="move";ac.x=1400 if not mirrored else 4360
	if scenario=="retreat": bc=ac+Vector2(direction*600,0)
	if scenario=="flank": bc=ac+Vector2(direction*300,-850);action="defend"
	if scenario=="capture": ac=Vector2(2000 if not mirrored else 4000,1536);bc=Vector2(5500 if not mirrored else 300,300)
	var fa := spawn_army(a,na,1,seed*10000+(101 if mirrored else 1),ac,Vector2(direction,0),action,form,units)
	var fb := spawn_army(b,nb,2,seed*10000+(1 if mirrored else 101),bc,Vector2(-direction,0),"defend" if scenario in ["siege","light_guard"] else "attack","special",units)
	if scenario in ["travel","choke","capture"]:
		for id in fb.member_entity_ids: units[id].enabled=false;units[id].health=0
	if scenario.begins_with("hidden"):
		for id in fb.member_entity_ids:
			units[id].position=Vector2(5600+(150 if scenario=="hidden2" else 0),250+(id%5)*40)
			units[id].health*=0.5 if scenario=="hidden2" else 1.0
	var formations := {1:fa,2:fb}
	var combat := CombatSystem.new()
	var events: Array[SimulationEvent]=[]
	var projectiles: Dictionary={}
	var next_projectile:=1
	var hero_ids := [fa.member_entity_ids[-1],fb.member_entity_ids[-1]]
	var hero_dead: Array[int]=[-1,-1]
	var returned := [false,false]
	var first_shot := [-1,-1]
	var fired := [0,0]
	var fired_by_role := [[0,0,0,0,0],[0,0,0,0,0]]
	var cannon_shooters: Array[Dictionary] = [{},{}]
	var cannon_first := [-1,-1]
	var hero_gap_ticks := 0
	var speed_errors:=0
	var walk_errors:=0
	var visibility_errors:=0
	var max_hero_gap:=0.0
	var reached_tick:=-1
	var captured_tick:=-1
	var capture_progress:=0
	var retreat_tick:=-1
	var frames: Array=[]
	var winner:=0
	var finished:="time_limit"
	var target:=Vector2(4360 if not mirrored else 1400,1536)
	if scenario=="capture": target=Vector2(3000,1536)
	var ticks:=0
	var cap:=1800
	if scenario in ["travel","choke","capture","retreat"]: cap=900
	if scenario.begins_with("hidden"):cap=100
	var initial_actions: Array=[action,"attack"]
	var trace:=HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	var own_trace:=HashingContext.new()
	own_trace.start(HashingContext.HASH_SHA256)
	for tick in range(cap):
		ticks=tick+1
		var legal := [visible_contacts(units,fa,fb),visible_contacts(units,fb,fa)]
		if scenario=="retreat" and tick>=100 and retreat_tick<0:
			retreat_tick=tick;fa.action="retreat"
			var amounts:=counts(a,na)
			var role_indices := [0,0,0,0,0]
			for index in range(fa.member_entity_ids.size()):
				var u: UnitState=units[fa.member_entity_ids[index]]
				var role := int(String(u.definition_id).trim_prefix("lab_"))
				fa.offsets[index]=offset_for(a,role,role_indices[role],1 if role==4 else amounts[role],"retreat",form!="special",index,na)
				role_indices[role]+=1
		var planned:Array[Vector2]=[fa.anchor_position,fb.anchor_position]
		for side in range(2):
			var army: LabFormation=fa if side==0 else fb
			var enemy: LabFormation=fb if side==0 else fa
			if not units[hero_ids[side]].enabled and hero_dead[side]<0:
				hero_dead[side]=tick;returned[side]=true
				for id in army.member_entity_ids: units[id].legion_returning=true
			if tick%5==0:
				revise_policy(army,units,legal[side],tick,grid)
				if side == 0 and army.action == "retreat" and retreat_tick < 0: retreat_tick = tick
				var destination:=army.anchor_position
				if returned[side]: destination=Vector2(300 if (side==0)==(not mirrored) else 5700,1536)
				elif side==0 and scenario in ["travel","choke","capture"]: destination=target
				elif army.action=="retreat": destination=(ac if side==0 else bc)-army.facing*1200
				elif army.action=="defend": destination=army.anchor_position
				else:
					# A known map objective is legal without enemy vision.
					destination=Vector2(2800,1536)
					var nearest:=INF
					var seen_id:=0
					for id in legal[side]:
						var d:=army.anchor_position.distance_squared_to(units[id].position)
						if d<nearest:nearest=d;seen_id=id
					if seen_id:
						var engage:=false
						var ready:=0
						var fighting:=0
						for id in army.member_entity_ids:
							var u: UnitState=units[id]
							if not u.enabled or not u.hero_commander_id.is_empty():continue
							if int(String(u.definition_id).trim_prefix("lab_"))==0 and (a if side==0 else b)!=3:continue
							fighting+=1
							for contact in legal[side]:
								if u.position.distance_to(units[contact].position)<=u.attack_range*0.92:ready+=1;break
						engage=ready>=maxi(1,ceili(fighting*0.35))
						if army.revised and army.profile == 2: engage=cannon_ready(army,units,legal[side],tick)
						if engage:destination=army.anchor_position
						else:destination=units[seen_id].position
				planned[side]=destination
		# Both policies read the same pre-movement state before either army moves.
		for side in range(2):
			var army:LabFormation=fa if side==0 else fb
			if side==1 and scenario.begins_with("hidden"):continue
			if tick%5==0:order(army,planned[side],pathfinder)
			army.compact=scenario=="choke" and army.anchor_position.x>2200 and army.anchor_position.x<3560
			# Keep settling slots even while the anchor stops in combat.
			army.is_moving=alive(units,army)>0
			for id in army.member_entity_ids:
				var u: UnitState=units[id]
				if not u.enabled:continue
				u.has_move_target=army.path_index<army.path.size() or u.position.distance_to(u.desired_position)>6
			var before: Dictionary={}
			for id in army.member_entity_ids: before[id]=units[id].position
			movement.advance({side+1:army},units,events,tick)
			for id in army.member_entity_ids:
				var u: UnitState=units[id]
				if not u.enabled:continue
				var distance:float=u.position.distance_to(before[id])
				if distance>u.move_speed*0.1+0.01:speed_errors+=1
				if not grid.is_segment_walkable(before[id],u.position):walk_errors+=1
				u.has_move_target=distance>0.1 or (army.path_index<army.path.size() and not army.held_cannons.has(id))
		# Simultaneous observation phase after BOTH sides finish movement.
		legal=[visible_contacts(units,fa,fb),visible_contacts(units,fb,fa)]
		for side in range(2):
			var army: LabFormation=fa if side==0 else fb
			for id in army.member_entity_ids:
				var u:UnitState=units[id]
				if not u.enabled:continue
				u.attack_target_entity_id=0
				var nearest:=INF
				for target_id in legal[side]:
					var hostile: UnitState=units[target_id]
					var d:=u.position.distance_squared_to(hostile.position)
					if hostile.enabled and d<=u.attack_range*u.attack_range and d<nearest:
						nearest=d;u.attack_target_entity_id=target_id
				if u.attack_target_entity_id!=0 and not legal[side].has(u.attack_target_entity_id):visibility_errors+=1
		# Both sides choose targets before the shared production combat step.
		next_projectile=combat.advance(units,{},projectiles,next_projectile,events,tick)
		for event in events:
			trace.update((str(tick)+":"+str(event.kind)+":"+str(event.entity_id)+":"+event.detail).to_utf8_buffer())
			if event.kind==SimulationEvent.Kind.PROJECTILE_FIRED:
				var side:int=units[event.entity_id].faction_id-1
				fired[side]+=1
				var role := int(String(units[event.entity_id].definition_id).trim_prefix("lab_"))
				fired_by_role[side][role] += 1
				if role == 3:
					cannon_shooters[side][event.entity_id] = true
					if cannon_first[side] < 0: cannon_first[side] = tick
				if first_shot[side]<0:first_shot[side]=tick
		events.clear()
		for id in units:
			var sample:UnitState=units[id]
			trace.update(("%d:%d:%.5f:%.5f:%.5f:%d;" % [tick,id,sample.position.x,sample.position.y,sample.health,sample.attack_target_entity_id]).to_utf8_buffer())
			if sample.faction_id==1:own_trace.update(("%d:%d:%.5f:%.5f:%.5f:%d;" % [tick,id,sample.position.x,sample.position.y,sample.health,sample.attack_target_entity_id]).to_utf8_buffer())
		var hero: UnitState=units[hero_ids[0]]
		if hero.enabled:
			var nearest:=INF
			for id in fa.member_entity_ids:
				var u:UnitState=units[id]
				if u.enabled and u.tactical_role in [UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR]:nearest=minf(nearest,hero.position.distance_to(u.position))
			if nearest<INF:max_hero_gap=maxf(max_hero_gap,nearest)
			if nearest>240:hero_gap_ticks+=1
		if scenario in ["travel","choke"]:
			var arrived:=0
			var hero_slot_ready:=false
			for id in fa.member_entity_ids:
				var index:int=fa.slot_by_entity_id[id]
				var offset:=fa.get_wide_offset(index)
				var destination:=target+fa.facing*offset.x+Vector2(-fa.facing.y,fa.facing.x)*offset.y
				if units[id].position.distance_to(destination)<48:arrived+=1
				if id==hero_ids[0]:hero_slot_ready=units[id].position.distance_to(destination)<48
			if reached_tick<0 and arrived>=ceili(fa.member_entity_ids.size()*0.9) and hero_slot_ready:
				reached_tick=tick;finished="arrived";break
		if scenario=="capture":
			var eligible:=false
			for id in fa.member_entity_ids:
				var u:UnitState=units[id]
				var role:=int(String(u.definition_id).trim_prefix("lab_"))
				if u.enabled and u.position.distance_to(target)<=224 and (role==4 or bool(profiles[a].troops[role].capture)):eligible=true
			capture_progress=capture_progress+1 if eligible else 0
			if capture_progress>=60:captured_tick=tick;finished="captured";break
		if scenario not in ["travel","choke","capture"]:
			if not units[hero_ids[0]].enabled or not units[hero_ids[1]].enabled:
				winner=2 if not units[hero_ids[0]].enabled else 1
				if not units[hero_ids[0]].enabled and not units[hero_ids[1]].enabled:winner=0
				finished="commander_down";break
			if alive(units,fa,true)==0 or alive(units,fb,true)==0:
				winner=2 if alive(units,fa,true)==0 else 1;finished="soldiers_eliminated";break
		if retreat_tick>=0:
			var withdrawn:=0
			for id in fa.member_entity_ids:
				var u:UnitState=units[id]
				if u.enabled and (u.position.x-ac.x)*direction < -900:withdrawn+=1
			if units[hero_ids[0]].enabled and (units[hero_ids[0]].position.x-ac.x)*direction < -900 and withdrawn>=ceili(alive(units,fa)*0.9):
				finished="escaped";break
		if replay and tick%10==0:
			var positions:Array=[]
			for id in units:
				var u:UnitState=units[id]
				positions.append([id,u.faction_id,roundf(u.position.x),roundf(u.position.y),snappedf(u.health,0.1),u.enabled,int(String(u.definition_id).trim_prefix("lab_"))])
			frames.append({"tick":tick,"units":positions})
	var summary:Dictionary={"a":profiles[a].id,"b":profiles[b].id,"na":na,"nb":nb,"scenario":scenario,"form":form,"seed":seed,"mirrored":mirrored,"ticks":ticks,"winner":winner,"finish":finished,"alive_a":alive(units,fa,true),"alive_b":alive(units,fb,true),"hp_a":snappedf(health_fraction(units,fa),0.0001),"hp_b":snappedf(health_fraction(units,fb),0.0001),"hero_alive_a":units[hero_ids[0]].enabled,"hero_alive_b":units[hero_ids[1]].enabled,"shots":fired,"first_shot":first_shot,"reached_tick":reached_tick,"captured_tick":captured_tick,"retreat_tick":retreat_tick,"max_hero_gap":snappedf(max_hero_gap,0.1),"speed_errors":speed_errors,"walk_errors":walk_errors,"visibility_errors":visibility_errors,"prototype_speed_corrections":movement.raw_speed_corrections}
	summary["trace_sha256"]=trace.finish().hex_encode()
	summary["shots_by_role"] = fired_by_role
	summary["cannon_shooters"] = [cannon_shooters[0].size(),cannon_shooters[1].size()]
	summary["cannon_first_shot"] = cannon_first
	summary["hero_gap_over240_ticks"] = hero_gap_ticks
	summary["retreat_reason"] = fa.retreat_reason
	summary["scouts_recalled"] = fa.scouts_recalled
	summary["own_trace_sha256"]=own_trace.finish().hex_encode()
	if speed_errors or walk_errors or visibility_errors:errors.append(summary)
	if replay:
		var name:="%s_%s_%s_%d" % [profiles[a].id,scenario,form,na]
		FileAccess.open(OUT+"replay_"+name+".json",FileAccess.WRITE).store_string(JSON.stringify({"summary":summary,"frames":frames}))
	return summary

func hero_focus(armor: int) -> Dictionary:
	var units:Dictionary={}
	var hero:=UnitState.new(100,Vector2(1000,1000),0,2)
	hero.health=900
	hero.max_health=900
	hero.armor=armor
	hero.can_attack=false
	units[100]=hero
	for index in range(10):
		var u:=UnitState.new(index+1,Vector2(850,980+index*4),0,1)
		u.attack_damage=30
		u.attack_range=190
		u.attack_cooldown_ticks=7
		u.projectile_speed=600
		u.attack_target_entity_id=100
		units[index+1]=u
	var combat:=CombatSystem.new()
	var events:Array[SimulationEvent]=[]
	var projectiles:Dictionary={}
	var next:=1
	var death:=-1
	for tick in range(900):
		next=combat.advance(units,{},projectiles,next,events,tick)
		events.clear()
		if not hero.enabled:death=tick;break
	return {"scenario":"hero_focus_10_assault","hp":900,"armor":armor,"death_tick":death,"shots":next-1}
