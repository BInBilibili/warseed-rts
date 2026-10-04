extends "res://tests/tools/legion44_equal_distance_pursuit.gd"

var placement := "control"
var placement_record := {}
var layout_failures: Array[String] = []

func column_for(profile: int, count: int, faction: int, base: int, front: float, units: Dictionary) -> Column:
	var col := super.column_for(profile,count,faction,base,front,units)
	if faction!=1: return col
	var original := col.ids.find(col.hero)
	var selected := original
	if placement=="within_batch_exit":
		for i in range(col.ids.size()):
			if col.batches[i]==col.batches[original]: selected=i
	elif placement=="next_batch_exit":
		for i in range(col.ids.size()):
			if col.batches[i]==col.batches[original]+1:
				selected=i
				break
	if placement!="control" and selected==original: layout_failures.append("candidate did not change hero position")
	var swapped := col.ids[selected]
	col.ids[selected]=col.hero; col.ids[original]=swapped
	units[col.hero].position=point_at(col.progress[selected],col.lanes[selected])
	units[swapped].position=point_at(col.progress[original],col.lanes[original])
	var escorts := 0
	for i in range(col.ids.size()):
		if col.batches[i]==col.batches[selected] and role_of(units[col.ids[i]]) in [1,2]: escorts+=1
	if escorts<1: layout_failures.append("candidate hero batch has no actual escort")
	placement_record={"original_index":original,"selected_index":selected,"original_batch":col.batches[original],"selected_batch":col.batches[selected],"exitward_shift":col.progress[original]-col.progress[selected],"actual_same_batch_escorts":escorts,"swapped_role":role_of(units[swapped])}
	return col

func run_case(profile: int,count: int,delay: int,mirror: bool,layout: String) -> Dictionary:
	placement=layout; placement_record={}; layout_failures=[]
	var row := run_pursuit(profile,count,delay,mirror)
	row["layout"]=layout; row["placement"]=placement_record.duplicate(true)
	row["layout_failures"]=layout_failures.duplicate()
	return row

func _initialize() -> void:
	profiles=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/legion34/v5/config.json")).profiles
	actual_map=load("res://data/maps/final_decision.tres") as MapDefinition
	var matrix := false; var replay := false
	output="res://artifacts/legion46/smoke01.json"
	for arg in OS.get_cmdline_user_args():
		if arg=="--matrix": matrix=true
		if arg=="--replay": replay=true
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var rows: Array[Dictionary]=[]
	for profile in (range(5) if matrix or replay else [0,2]):
		for count in ([24,48] if matrix or replay else [24]):
			for delay in ([0,30] if matrix else [0]):
				for mirror in ([false,true] if matrix else [false]):
					for layout in (["within_batch_exit","next_batch_exit"] if replay else ["control","within_batch_exit","next_batch_exit"]):
						var row := run_case(profile,count,delay,mirror,layout)
						rows.append(row)
						FileAccess.open(output.trim_suffix(".json")+"-partial.json",FileAccess.WRITE).store_string(JSON.stringify({"results":rows,"complete":false}))
						print("LEGION46_POSITION_PROGRESS ",row.profile," count=",count," delay=",delay," mirror=",mirror," layout=",layout," outcome=",row.outcome," remaining=",row.soldiers_survived," failures=",row.invariant_failures,row.layout_failures)
	var failed := rows.any(func(r: Dictionary) -> bool: return not r.invariant_failures.is_empty() or not r.layout_failures.is_empty())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PROTOTYPE","cases":rows.size(),"results":rows,"invariants_failed":failed,"scope":"initial position swaps only; not actual formation transition or production formation"}))
	print("LEGION46_POSITION_DONE cases=",rows.size()," invariants_failed=",failed)
	quit(1 if failed else 0)
