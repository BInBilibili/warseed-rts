extends SceneTree

var failures:Array[String]=[]
var checks:=0

func check(value: bool, reason: String) -> void:
	checks+=1
	if not value:failures.append(reason)

func _initialize() -> void:
	var loaded:=BattleContentLoader.load_battle(&"final_decision")
	check(loaded.is_valid(),"source battle valid")
	if not loaded.is_valid():finish();return
	var battle:=loaded.battle
	var plan:=battle.create_default_army_plan()
	check(plan.legion_errors(battle).is_empty(),"default fixed plan")
	var configured:=GrowthArmyConfiguration.apply(battle,plan)
	check(configured!=null,"configured battle")
	if configured==null:finish();return
	var validation:=configured.validate(SimulationWorld.UNIT_CATALOG)
	check(validation.is_valid(),"configured validation: "+str(validation.issues))
	var total_cost:=0
	var expected_costs:=[160,156,157,105,124]
	for index in range(LegionTemplate.PROFILE_IDS.size()):
		var template:=LegionTemplate.find(LegionTemplate.PROFILE_IDS[index])
		check(template.validation_errors().is_empty(),"template valid "+str(template.profile_id))
		var occupied:=PackedByteArray();occupied.resize(60)
		for slot in range(12):occupied[slot]=1
		var cost:=0
		for slot in range(12,60):
			check(template.next_slot(slot,occupied)==slot,"sequential unique slot "+str(template.profile_id)+":"+str(slot))
			var role:=template.slot_roles()[slot]
			cost+=([2 if template.armed_recon else 1,2,5,4][role])
			occupied[slot]=1
		check(cost==expected_costs[index],"per-step total "+str(template.profile_id))
		check(template.next_slot(60,occupied)==-1,"full has no extra slot")
		total_cost+=cost
	check(total_cost==702,"all 240 additions cost 702")
	var original_roles:Dictionary={}
	for card in battle.unit_card_definitions:original_roles[card.definition_id]=card.authorized_strength
	var first:=plan.legions[0]
	var second:=plan.legions[1]
	var first_profile:=first.profile_id
	var second_profile:=second.profile_id
	var unchanged:=plan.duplicate_plan()
	check(plan.swap_legion_profile(first.legion_id,second_profile),"profile swap accepted")
	check(first.role_strengths==LegionTemplate.find(second_profile).full and first.starting_strengths()==LegionTemplate.find(second_profile).opening,"swapped complete roster")
	check(second.profile_id==first_profile and second.role_strengths==LegionTemplate.find(first_profile).full,"displaced general keeps roster")
	check(unchanged.legions[0].profile_id==first_profile,"plan copy remains unchanged")
	var swapped:=GrowthArmyConfiguration.apply(battle,plan)
	check(swapped!=null and swapped.validate(SimulationWorld.UNIT_CATALOG).is_valid(),"swapped fixed content valid")
	for i in range(configured.enemy_formations.size()):
		check(configured.enemy_formations[i].strength==swapped.enemy_formations[i].strength,"enemy does not copy player swap")
	for card in battle.unit_card_definitions:
		check(card.authorized_strength==original_roles[card.definition_id] and card.legion_template==null,"source card resource unchanged")
	var ordinary:=battle.unit_card_definitions[0].duplicate(true) as UnitCardDefinition
	ordinary.authorized_strength=0;ordinary.starting_strength=0
	check(not UnitCardCompositionCompiler.validate(ordinary,SimulationWorld.UNIT_CATALOG).is_valid(),"ordinary empty card rejected")
	for card in configured.unit_card_definitions:
		if card.is_absent_legion_role():
			check(UnitCardCompositionCompiler.expand(card).is_empty(),"absent role spawns nobody")
			var forged:=card.duplicate(true) as UnitCardDefinition
			forged.role_key=&"UNIT_CARD_ROLE_ASSAULT"
			check(not UnitCardCompositionCompiler.validate(forged,SimulationWorld.UNIT_CATALOG).is_valid(),"template cannot authorize wrong empty role")
	plan.legions[0].role_strengths[0]+=1
	check(GrowthArmyConfiguration.apply(battle,plan)==null,"invalid fixed roster rejected")
	var world:=SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION,{},&"",unchanged)
	check(world.units.size()==130,"both factions have 60 soldiers plus 5 heroes")
	for commander:CommanderState in world.commanders.values():
		var template:=LegionTemplate.find(commander.definition.profile.profile_id)
		var amounts:=PackedInt32Array([0,0,0,0])
		for card_id in commander.subordinate_unit_card_ids:
			var card:UnitCardState=world.unit_cards[card_id]
			var role:=LegionTemplate.ROLE_KEYS.find(card.definition.role_key)
			amounts[role]=card.member_entity_ids.size()
		check(amounts==template.opening,"actual opening "+str(commander.definition.definition_id))
		check(commander.growth_unlocked_slots==12 and commander.growth_slot_entities.size()==60,"actual growth identity slots")
		var hero:UnitState=world.units.get(commander.hero_entity_id)
		check(hero!=null and hero.max_health==template.hero_health,"actual hero template")
	for tick in range(5):world.advance_tick()
	check(world.battle_definition.validate(SimulationWorld.UNIT_CATALOG).is_valid(),"live configured content remains valid")
	finish()

func finish() -> void:
	var report:={"evidence":"SIMULATED","checks":checks,"failures":failures,"scope":"fixed configuration, 240 growth choices and nominal costs, actual opening and five ticks; not recruitment application or full release"}
	FileAccess.open("res://artifacts/legion36/roster.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	for failure in failures:push_error(failure)
	print("LEGION36_ROSTER checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
