extends SceneTree
func value(item: Variant) -> Variant:
	if item is Object:
		var result:Dictionary={}
		for property in item.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: result[property.name]=value(item.get(property.name))
		return result
	if item is Array:
		var result:Array=[]
		for child in item: result.append(value(child))
		return result
	return item
func _initialize() -> void:
	var world:=SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var policy=preload("res://tests/tools/perf23_blue_policy.gd").new("economy")
	RuntimeMeasurement.reset()
	RuntimeMeasurement.enabled=true
	policy.advance(world)
	world.advance_tick()
	var view:=world.create_faction_snapshot(1)
	var failures:Array[String]=[]
	if StaffPlanGenerator.navigation_for_snapshot(world.create_true_state_snapshot())!=null: failures.append("true state accepted")
	var timings:Array[Dictionary]=[]
	for decision in view.staff_plan_decisions:
		if decision.approved_plan==null: continue
		var start:=Time.get_ticks_usec()
		var old:=CommanderTaskGraphBuilder.new().build(view,decision.approved_plan)
		var cold:=Time.get_ticks_usec()-start
		start=Time.get_ticks_usec()
		var nav:=StaffPlanGenerator.navigation_for_snapshot(view)
		var actual:=CommanderTaskGraphBuilder.new().build(view,decision.approved_plan,CommanderTaskGraphBuilder.DEFAULT_DEFINITION,nav)
		var warm:=Time.get_ticks_usec()-start
		if old==null or actual==null or value(old)!=value(actual): failures.append("graph differs")
		var changed:=world.create_faction_snapshot(1)
		changed.buildings[0].enabled=false
		if StaffPlanGenerator.navigation_for_snapshot(changed)==nav: failures.append("known footprints not invalidated")
		if StaffPlanGenerator.navigation_for_snapshot(view)!=nav: failures.append("same legal map not reused")
		timings.append({"fresh_graph_usec":cold,"cached_graph_usec":warm,"nodes":actual.nodes.size() if actual!=null else 0})
	if timings.is_empty(): failures.append("no approved graph tested")
	var report:Dictionary={"timings":timings,"measurements":RuntimeMeasurement.summary(),"failures":failures}
	RuntimeMeasurement.enabled=false
	var report_path := "res://artifacts/perf23-plan-cache.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF23_PLAN_CACHE ",report)
	quit(0 if failures.is_empty() else 1)
