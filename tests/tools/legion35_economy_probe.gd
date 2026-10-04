extends SceneTree

func _initialize()->void:
	var world:=SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	world.current_tick=300
	var faction:=world.factions[1] as FactionState
	faction.supply=300
	var profiles:Dictionary={}
	var eligible:Array[StringName]=[]
	for commander:CommanderState in world.commanders.values():
		if commander.faction_id!=1:continue
		profiles[commander.definition.definition_id]=commander.definition.profile.profile_id
		var rate:=0 if commander.definition.profile.profile_id==&"ranger" else 1
		if commander.definition.profile.profile_id==&"spear":
			rate=2
			faction.priority_commander_id=commander.definition.definition_id
		faction.recruitment_rates[commander.definition.definition_id]=rate
		if rate>0:eligible.append(commander.definition.definition_id)
	world._advance_automatic_logistics()
	var seen:Dictionary={}
	var sequence:Array[Dictionary]=[]
	var second_before_first:=false
	for command in world.command_queue.snapshot():
		if not command is RecruitUnitCardCommand or command.issuer_id!=1:continue
		var card:=world.unit_cards[command.unit_card_id] as UnitCardState
		var id:=card.commander_definition_id
		if seen.has(id) and seen.size()<eligible.size():second_before_first=true
		seen[id]=seen.get(id,0)+1
		sequence.append({"commander":id,"profile":profiles[id],"number_for_commander":seen[id],"slot":command.legion_slot,"cost":card.definition.recruitment_cost})
	var report:={"evidence":"SIMULATED_DIAGNOSTIC","contract":"one per eligible commander in first round before a second in round two","sequence":sequence,"second_before_all_first":second_before_first,"shared_next_unit_reservation":"NOT_IMPLEMENTED","status":"REWORK" if second_before_first else "ORDER_FIXTURE_PASS_RESERVATION_MISSING"}
	FileAccess.open("res://artifacts/legion35/economy_probe.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("ECONOMY_PROBE ",JSON.stringify(report))
	quit(1 if second_before_first else 0)
