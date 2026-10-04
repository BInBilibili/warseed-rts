extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var heroes := 0
	for unit: UnitState in world.units.values():
		if not unit.hero_commander_id.is_empty():
			heroes += 1
			if unit.health != 600 or unit.armor != 20 or unit.attack_cooldown_ticks != 6: failures.append("hero stats")
		if unit.tactical_role == UnitState.TacticalRole.ARMOR and unit.armor != 15: failures.append("armor")
	if heroes != 10: failures.append("hero count")
	var batteries := 0
	for card: UnitCardState in world.unit_cards.values():
		if card.definition.role_key != &"UNIT_CARD_ROLE_FIREPOWER": continue
		batteries += 1
		var weapon := card.definition.tactical_weapon_override
		if weapon == null or not weapon.health_only_damage or weapon.fixed_attack_range != 420 or weapon.ammunition_capacity != 0 or weapon.suppression != 0 or card.definition.fallback_weapon != null or card.definition.tactical_ability != null: failures.append("old artillery rules")
	if batteries != 10: failures.append("artillery count")
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		var help := TacticalHelp.growth_unit(world.unit_cards[&"final_group_1_thunder_fire_group"].definition, CommanderProfile.find(&"sentinel"))
		if not help.contains("20–80") or not help.contains("420"): failures.append("exported missile tooltip")
		var organization_help := GameText.t(&"LEGION_ORG_HELP")
		if not organization_help.contains("炮车导弹" if locale == "zh_CN" else "artillery missile"): failures.append("exported organization exception")
	var base: StrategicRegionState = world.strategic_regions[&"blue_base"]
	var command := CommanderOrderCommand.new(world.allocate_command_id(),1,0,&"mobile_legion",CommanderOrderCommand.OrderKind.ASSIGN_OBJECTIVE,base.position,base.region_id)
	command.hand_back_control = true
	command.apply_requested_posture = true
	if not world.submit_command(command).is_accepted(): failures.append("HQ center command")
	var host := SimulationHost.new()
	host.scenario_kind = SimulationWorld.ScenarioKind.FINAL_DECISION
	host.world = world
	if not host.background_simulation_enabled: failures.append("worker disabled")
	if host.get_presentation_grid() == world.logic_grid: failures.append("mutable presentation terrain")
	var event := BattleConclusionEvent.new(5,BattleOutcome.new(BattleOutcome.Result.ORDERED_WITHDRAWAL))
	world.events.append(event)
	host._publish_world_view()
	var published := host.get_published_events().back() as BattleConclusionEvent
	if published == null or published.outcome == event.outcome: failures.append("conclusion value type")
	var art := WsArtBatch.new()
	if not art.has_method("_initialized_buffer"): failures.append("old art batch")
	art.free()
	host.free()
	print("PERF25_EXPORT_PROBE ",JSON.stringify({"heroes":heroes,"failures":failures,"evidence":"SIMULATED"}))
	quit(0 if failures.is_empty() else 1)
