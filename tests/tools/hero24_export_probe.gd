extends SceneTree
func _initialize()->void:
 var world:=SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
 var errors:Array[String]=[]
 var heroes:=0
 for u:UnitState in world.units.values():
  if not u.hero_commander_id.is_empty():
   heroes+=1
   if u.health!=600 or u.armor!=20 or u.attack_cooldown_ticks!=6:errors.append("hero stats")
  if u.tactical_role==UnitState.TacticalRole.ARMOR and u.armor!=15:errors.append("armor stats")
 if heroes!=10:errors.append("ten heroes")
 if world.commanders[&"bai_jiuyang"].hero_entity_id!=world.battle_definition.next_dynamic_unit_id:errors.append("unstable hero ID allocation")
 if world.logic_grid.is_segment_walkable(Vector2(28166.095703125,20885.759765625),Vector2(28048,21008)):errors.append("old bank sampling")
 TranslationServer.set_locale("zh_CN")
 if not GameText.t(&"LEGION_ORG_HELP").contains("65"):errors.append("old tooltip")
 var view:=world.create_commander_task_snapshot(1,false)
 view.tick=1000
 view.units.clear()
 var commander:=view.get_commander(&"bai_jiuyang")
 commander.last_growth_order_tick=0
 for card in view.unit_cards:
  if commander.subordinate_unit_card_ids.has(card.definition_id):
   card.center_position=view.get_strategic_region(&"blue_base").position
   card.organization=0 if card.role_key in [&"UNIT_CARD_ROLE_ASSAULT",&"UNIT_CARD_ROLE_ARMOR"] else 100
 var orders:=GrowthCommanderAgent.new().propose(view,world.battle_definition,&"bai_jiuyang")
 if orders.is_empty() or orders[0].action!=GrowthCommanderCommand.Action.RECOVER:errors.append("old frontline recovery")
 print("HERO24_EXPORT_PROBE ",JSON.stringify({"heroes":heroes,"failures":errors}))
 quit(0 if errors.is_empty() else 1)
