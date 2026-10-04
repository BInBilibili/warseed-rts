extends SceneTree
var failures:Array[String]=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, reason: String) -> void:
	checks+=1
	if not value:failures.append(reason)
func run() -> void:
	var world:=SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var host:=SimulationHost.new()
	host.scenario_kind=SimulationWorld.ScenarioKind.FINAL_DECISION
	host.world=world
	host._grey_ridge_army_plan=world.grey_ridge_army_plan.duplicate_plan()
	host._grey_ridge_battle_started=false
	var planner:=PrebattlePlanner.new()
	root.add_child(planner)
	planner.configure(host)
	for language in ["zh_CN","en"]:
		TranslationServer.set_locale(language)
		planner.refresh_locale()
		for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1600),Vector2i(640,800),Vector2i(480,800)]:
			root.size=size;root.content_scale_size=size
			for frame in range(3):await process_frame
			check(planner.is_plan_valid(),"valid displayed plan "+language+str(size))
			check(Rect2(Vector2.ZERO,Vector2(size)).encloses(planner.start_button.get_global_rect()),"start visible "+language+str(size))
			check(planner.commander_grid.get_child_count()==5,"five general panels")
			for panel in planner.commander_grid.get_children():
				for role in range(4):
					var label:=panel.find_child("Role%d" % role,true,false)
					check(label is Label and not label is SpinBox,"fixed composition is read only")
		var entry:=planner.get_plan().legions[0]
		var old:=entry.profile_id
		var menu:=planner.commander_grid.get_child(0).find_child("General",true,false) as OptionButton
		var roster:=CommanderProfile.roster()
		var chosen_index:=(menu.selected+1)%roster.size()
		menu.item_selected.emit(chosen_index)
		await process_frame
		var swapped:=planner.get_plan().legion(entry.legion_id)
		check(swapped.profile_id!=old and swapped.role_strengths==LegionTemplate.find(swapped.profile_id).full,"UI selection swaps full template")
		check(planner.is_plan_valid(),"UI swapped plan remains valid")
		for profile in roster:
			var template:=LegionTemplate.find(profile.profile_id)
			check(TacticalHelp.growth_hero(profile.profile_id).contains(str(int(template.hero_health))),"hero help uses actual health")
			check(not TacticalHelp.growth_hero(profile.profile_id).contains("HERO_TEMPLATE_HELP"),"hero help translated")
	planner.free();host.free()
	FileAccess.open("res://artifacts/legion35/ui.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_HEADLESS_UI","checks":checks,"failures":failures,"rendered_pixels":"NOT_RUN"}))
	for failure in failures:push_error(failure)
	print("LEGION35_UI checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
