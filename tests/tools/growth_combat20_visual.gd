extends "res://tests/tools/final_decision_ui_smoke.gd"

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var game := load("res://scenes/game/final_decision.tscn").instantiate() as GameRoot
	root.add_child(game)
	current_scene = game
	for frame in range(12): await process_frame
	game.prebattle_planner._start_battle()
	game.simulation_host.set_tactical_paused(true)
	var world := game.simulation_host.world
	world.command_queue.drain()
	world.agents.clear()
	for task: TaskState in world.tasks.values(): task.lifecycle=TaskState.Lifecycle.PAUSED
	for unit: UnitState in world.units.values(): unit.control_state=UnitState.ControlState.PLAYER_CONTROLLED
	for commander: CommanderState in world.commanders.values(): commander.last_growth_order_tick=100000
	for faction: FactionState in world.factions.values(): faction.supply=0
	var selected: Array[StringName]=[]
	var ids: Array[int]=[]
	var origin:=Vector2(16384,12288)
	for card: UnitCardState in world.unit_cards.values():
		card.control_state=UnitCardState.ControlState.PLAYER_CONTROLLED
		card.persistent_manual=true
		var formation:=world.formations[card.formation_id] as FormationState
		formation.is_moving=false
		formation.order_kind=FormationState.OrderKind.IDLE
		for id in card.member_entity_ids: world.units[id].has_move_target=false
		if card.commander_definition_id not in [&"bai_jiuyang",&"red_bai_jiuyang"]: continue
		selected.append(card.definition.definition_id)
		var sign_side:= -1.0 if card.faction_id==1 else 1.0
		var distance:=80.0 if card.definition.role_key!=&"UNIT_CARD_ROLE_FIREPOWER" else 230.0
		var lateral:= -100.0 if card.definition.role_key==&"UNIT_CARD_ROLE_RECON" else (100.0 if card.definition.role_key==&"UNIT_CARD_ROLE_ARMOR" else 0.0)
		formation.anchor_position=origin+Vector2(sign_side*distance,lateral)
		formation.target_position=formation.anchor_position
		formation.order_destination=formation.anchor_position
		for index in range(card.member_entity_ids.size()):
			var unit:=world.units[card.member_entity_ids[index]] as UnitState
			unit.position=formation.anchor_position+Vector2(0,index*22)
			unit.health=unit.max_health*10
			unit.max_health=unit.health
			ids.append(unit.entity_id)
	world._update_faction_knowledge()
	game.camera_controller.center_on_world_position(origin)
	game.camera_controller.zoom=Vector2(0.85,0.85)
	var counts: Dictionary={}
	for tick in range(48):
		await _step(game)
		if tick in [19,39,47]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/combat20-battle-%d.png"%tick)
	for event in world.events:
		if event.kind!=SimulationEvent.Kind.PROJECTILE_FIRED or not ids.has(event.entity_id): continue
		var unit:=world.units[event.entity_id] as UnitState
		var key:="%d/%s"%[unit.faction_id,UnitState.TacticalRole.keys()[unit.tactical_role]]
		counts[key]=int(counts.get(key,0))+1
	for faction in [1,2]:
		for role in ["SCOUT","FIREPOWER"]:
			if int(counts.get("%d/%s"%[faction,role],0))==0: failures.append("missing actual fire %d/%s"%[faction,role])
	for failure in failures: push_error(failure)
	print("COMBAT20_VISUAL real_units=",world.units.size()," shots=",counts," failures=",failures)
	quit(0 if failures.is_empty() else 1)
