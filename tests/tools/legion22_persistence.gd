extends SceneTree
func _initialize() -> void:
	var default_battle := BattleContentLoader.load_battle(&"final_decision").battle
	var plan := default_battle.create_default_army_plan()
	plan.legions[0].role_strengths = PackedInt32Array([0,60,0,0])
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION,{},&"",plan)
	var record := ArmyRosterStore.build_battle_record(world.create_snapshot(),{},&"final_decision")
	var valid := ArmyRosterMigration.normalize(record,false).is_success()
	var next := ArmyRosterStore.build_battle_record(world.create_snapshot(),record,&"final_decision")
	valid = valid and int(next.get("battle_count",0)) == 2
	var id := "final_group_1_ironwall_assault_group"
	valid = valid and int(next.cards[id].last_battle_losses) == 0 and int(next.cards[id].cumulative_losses) == 0
	var historical := record.duplicate(true)
	for card_id in historical.cards:
		historical.cards[card_id].authorized_strength = 16
		historical.cards[card_id].composition.main.authorized_strength = 16
	valid = valid and ArmyRosterMigration.normalize(historical,false).is_success()
	var card := world.unit_cards[StringName(id)] as UnitCardState
	var victim := world.units[card.member_entity_ids[0]] as UnitState
	victim.enabled = false
	victim.health = 0
	GrowthArmyConfiguration.record_losses(world)
	GrowthArmyConfiguration.record_losses(world)
	var casualty := ArmyRosterStore.build_battle_record(world.create_snapshot(),historical,&"final_decision")
	valid = valid and int(casualty.cards[id].last_battle_losses) == 1
	var broken := casualty.duplicate(true)
	broken.cards[id].authorized_strength = 61
	broken.cards[id].composition.main.authorized_strength = 61
	valid = valid and not ArmyRosterMigration.normalize(broken,false).is_success()
	print("LEGION22_PERSISTENCE valid=",valid," cards=",record.get("cards",{}).size())
	quit(0 if valid else 1)
