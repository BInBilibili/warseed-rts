extends "res://tests/tools/legion34_candidate_lab.gd"
# Controlled A/B of bounded facing updates and surviving role-slot packing.
# Statistics, combat, targeting, opposing tactics and initial inputs are shared.
const DEFENSE_OUT := "res://artifacts/legion34/v4/"
var adaptive := false
var turns := 0
var repairs := 0
var last_counts:Dictionary={}

func _initialize() -> void:
	profiles=JSON.parse_string(FileAccess.get_file_as_string(DEFENSE_OUT+"config.json")).profiles
	var mode:="smoke"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	for profile in range(5):
		if mode=="smoke" and profile!=2:continue
		for count in ([12] if mode=="smoke" else [12,24,36,48,60]):
			for scenario in ["flank","attack_defense"]:
				for mirror in [false,true]:
					for policy in [false,true]:
						adaptive=policy;turns=0;repairs=0;last_counts.clear()
						var row:=battle(profile,0,count,count,scenario,"special",0,mirror)
						row["adaptive_defense"]=adaptive;row["turn_updates"]=turns;row["repair_updates"]=repairs
						results.append(row)
			print("DEFENSE_PROGRESS ",profile," ",count," cases=",results.size())
	FileAccess.open(DEFENSE_OUT+"defense_"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PROTOTYPE","cases":results.size(),"results":results,"errors":errors}))
	print("DEFENSE_DONE cases=",results.size()," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)

func revise_policy(army: LabFormation, units: Dictionary, legal: Array, tick: int, grid: LogicGrid) -> void:
	if adaptive and army.action=="defend" and army.revised:
		var nearest:=INF
		var selected:=0
		for id in legal:
			var distance:float=army.anchor_position.distance_squared_to(units[id].position)
			if distance<nearest:nearest=distance;selected=id
		if selected:
			var intended:Vector2=(units[selected].position-army.anchor_position).normalized()
			var angle:=army.facing.angle_to(intended)
			if absf(angle)>deg_to_rad(5):
				army.facing=army.facing.rotated(clampf(angle,-deg_to_rad(10),deg_to_rad(10)))
				turns+=1
				# Cannons keep a legal stationary firing position while the escort
				# faces the contact; super() releases only unsafe/out-of-range guns.
		var live_counts:=[0,0,0,0,0]
		for id in army.member_entity_ids:
			if units[id].enabled:live_counts[int(String(units[id].definition_id).trim_prefix("lab_"))]+=1
		if last_counts.has(army.formation_id) and last_counts[army.formation_id]!=live_counts:
			var indices:=[0,0,0,0,0]
			for slot in range(army.member_entity_ids.size()):
				var u:UnitState=units[army.member_entity_ids[slot]]
				if not u.enabled:continue
				var role:=int(String(u.definition_id).trim_prefix("lab_"))
				army.offsets[slot]=offset_for(army.profile,role,indices[role],live_counts[role],"defend",false,slot,alive(units,army,true))
				indices[role]+=1
			repairs+=1
		last_counts[army.formation_id]=live_counts.duplicate()
	super(army,units,legal,tick,grid)
