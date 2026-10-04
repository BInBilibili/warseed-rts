extends SceneTree
var failures: Array[String]=[]
var checks:=0
func check(value: bool, reason: String) -> void:
	checks+=1
	if not value and not failures.has(reason): failures.append(reason); print("FAIL ",reason)
func _initialize() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var w := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	for n in range(30): w.advance_tick()
	var cards: Array[UnitCardState]=[]
	for id in w.commanders:
		var c: CommanderState=w.commanders[id]
		if c.faction_id!=1: continue
		for card_id in c.subordinate_unit_card_ids:
			var card: UnitCardState=w.unit_cards[card_id]
			if card.member_entity_ids.size()>0:
				cards.append(card); break
	var stops := {}
	for card in cards:
		var f: FormationState=w.formations[card.formation_id]
		var cmd := StopCommand.new(w.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,w.current_tick,f.leader_entity_id,f.formation_id)
		check(w.submit_command(cmd).is_accepted(),"stop accepted "+str(card.definition.definition_id))
	w.advance_tick()
	for card in cards:
		for id in card.member_entity_ids: stops[id]=w.units[id].position
	for n in range(120): w.advance_tick()
	for id in stops: check(w.units[id].position.distance_to(stops[id])<0.01,"stop persists through auto handoff E"+str(id))
	var goals := {}
	for card in cards:
		var f: FormationState=w.formations[card.formation_id]
		var goal := f.anchor_position+Vector2(640,0)
		if w.pathfinder.find_body_path(f.anchor_position,goal).is_empty(): goal=f.anchor_position+Vector2(0,-640)
		goals[card.definition.definition_id]=goal
		var move := FormationMoveCommand.new(w.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,w.current_tick,f.leader_entity_id,f.formation_id,goal)
		check(w.submit_command(move).is_accepted(),"resume accepted "+str(card.definition.definition_id))
		print("MOVE ",card.definition.definition_id," requested=",goal," accepted=",move.target_position)
	var completed := {}
	for n in range(240):
		w.advance_tick()
		for card in cards:
			var f: FormationState=w.formations[card.formation_id]
			if not f.is_moving and f.order_destination.distance_to(goals[card.definition.definition_id])<0.01:
				completed[card.definition.definition_id]=true
			if f.order_destination.distance_to(goals[card.definition.definition_id])>0.01 and not completed.has(card.definition.definition_id):
				check(false,"overwrote unfinished move "+str(card.definition.definition_id))
	for card in cards:
		var f: FormationState=w.formations[card.formation_id]
		print("END ",card.definition.definition_id," wanted=",goals[card.definition.definition_id]," actual=",f.order_destination," continuation=",card.continuing_player_order," control=",card.control_state," task=",card.assigned_task_id," returned=",card.return_task_id)
		check(completed.has(card.definition.definition_id) or f.order_destination.distance_to(goals[card.definition.definition_id])<0.01,"handoff preserved unfinished destination "+str(card.definition.definition_id))
		for id in card.member_entity_ids:
			if stops.has(id): check(w.units[id].position.distance_to(stops[id])>300,"resumed actual movement E"+str(id))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"checks":checks,"evidence":"SIMULATED_MAIN"}))
	print("CONTROL_CONTRACT checks=",checks," failures=",failures); quit(0 if failures.is_empty() else 1)
