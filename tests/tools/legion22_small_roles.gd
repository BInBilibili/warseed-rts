extends SceneTree
func _initialize() -> void:
	var plan := BattleContentLoader.load_battle(&"final_decision").battle.create_default_army_plan()
	plan.legions[0].role_strengths = PackedInt32Array([1,1,1,57])
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION,{},&"",plan)
	var valid: bool = world.factions[1].population == 60
	for commander: CommanderState in world.commanders.values(): commander.posture = CommanderState.Posture.HOLD
	for tick in range(900):
		if tick % 100 == 0:
			for faction: FactionState in world.factions.values(): faction.supply = 300
		world.advance_tick()
		if world.factions[1].population == 300: break
	var strengths: Array[int] = []
	for role in ["falcon_recon_group","ironwall_assault_group","armored_spearhead","thunder_fire_group"]:
		var card := world.unit_cards.get(StringName("final_group_1_"+role)) as UnitCardState
		if card == null:
			valid = false
			continue
		strengths.append(UnitCardSnapshot.new(card,world.units).current_strength)
	valid = valid and strengths == [1,1,1,57]
	print("LEGION22_SMALL_ROLES valid=",valid," strengths=",strengths)
	quit(0 if valid else 1)
