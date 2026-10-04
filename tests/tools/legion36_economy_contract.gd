extends "res://tests/tools/legion35_recruitment_contract.gd"

var traces:Array[Dictionary]=[]

func prepare() -> SimulationWorld:
	var world:=fresh()
	world.factions[2].supply=12
	return world

func test_rounds() -> void:
	for faction_id in [1,2]:
		var world:=prepare()
		var faction:=world.factions[faction_id] as FactionState
		faction.supply=300
		var commander:=leader(world,&"spear",faction_id)
		faction.priority_commander_id=commander.definition.definition_id
		for profile in LegionTemplate.PROFILE_IDS:
			var id:=leader(world,profile,faction_id).definition.definition_id
			faction.recruitment_rates[id]=0 if profile==&"ranger" else (2 if profile==&"spear" else 1)
		RecruitmentArbitrationSystem.propose_commands(world,faction_id)
		var queue:=world.command_queue.snapshot()
		check(queue.size()==5,"two rounds allocate exactly five")
		var seen:Dictionary={}
		var sequence:Array[StringName]=[]
		for command:RecruitUnitCardCommand in queue:
			var card:=world.unit_cards[command.unit_card_id] as UnitCardState
			var id:=card.commander_definition_id
			if seen.has(id):check(seen.size()==4,"second recruit waits until all four eligible first recruits")
			seen[id]=seen.get(id,0)+1
			sequence.append(id)
		check(seen.get(commander.definition.definition_id,0)==2,"priority quota receives second round")
		apply_queue(world)
		check(faction.recruited_by_commander==seen,"actual births match admitted round allocations")
		check(faction.population==65,"five actual additions")
		check(faction.recruitment_arbitration.reserved_commander_id.is_empty(),"no gratuitous reservation with ample funds")
		traces.append({"faction":faction_id,"sequence":sequence})

func isolate(world:SimulationWorld,profiles:Array[StringName],faction_id:int=1)->void:
	for commander:CommanderState in world.commanders.values():
		if commander.faction_id==faction_id:
			world.factions[faction_id].recruitment_rates[commander.definition.definition_id]=1 if profiles.has(commander.definition.profile.profile_id) else 0

func test_saving()->void:
	var world:=prepare()
	isolate(world,[&"spear",&"guardian"])
	var faction:=world.factions[1] as FactionState
	var expensive:=leader(world,&"spear").definition.definition_id
	var cheap:=leader(world,&"guardian").definition.definition_id
	faction.supply=15 # Three spendable: armor costs five, assault costs two.
	RecruitmentArbitrationSystem.propose_commands(world,1)
	check(world.command_queue.size()==0,"next expensive recruit holds funds instead of buying cheap units")
	check(faction.recruitment_arbitration.reserved_commander_id==expensive,"single reservation assigned to unaffordable valid next soldier")
	check(faction.recruitment_arbitration.reserved_cost==5 and faction.recruitment_arbitration.reserved_amount==3,"partial reservation only holds real spendable supply")
	check(faction.supply==15,"reserving never creates or deducts money")
	for extra in range(2):
		world.current_tick+=10
		faction.supply+=1
		RecruitmentArbitrationSystem.propose_commands(world,1)
		if extra==0:check(world.command_queue.size()==0,"one more income still saves for same slot")
	check(world.command_queue.size()==1,"armor admitted once five actual supply available")
	check(faction.recruitment_arbitration.reserved_amount==0,"queued commitment not held twice")
	apply_queue(world)
	check(faction.supply==12 and faction.population==61,"armor paid exactly five on successful birth")
	check(faction.recruitment_arbitration.reserved_commander_id.is_empty(),"successful reserved birth releases")
	world.current_tick+=10
	faction.supply+=2
	RecruitmentArbitrationSystem.propose_commands(world,1)
	var queued:=world.command_queue.snapshot()
	check(queued.size()==1 and world.unit_cards[queued[0].unit_card_id].commander_definition_id==cheap,"successful group rotates behind waiting group")
	apply_queue(world)
	check(faction.supply==12 and faction.population==62,"second group spends actual income")

func test_release()->void:
	for cause in ["unsafe","quota","control","reserve","hero","supply","space"]:
		var world:=prepare()
		isolate(world,[&"spear"])
		var faction:=world.factions[1] as FactionState
		var commander:=leader(world)
		var card:=next_card(world,commander)
		faction.supply=15
		RecruitmentArbitrationSystem.refresh(world,1)
		check(faction.recruitment_arbitration.reserved_cost==5,"release fixture has reservation "+cause)
		match cause:
			"unsafe":card.last_damage_tick=world.current_tick
			"quota":faction.recruitment_rates[commander.definition.definition_id]=0
			"control":card.control_state=UnitCardState.ControlState.PLAYER_CONTROLLED
			"reserve":faction.recruitment_reserve=16
			"hero":commander.legion_regrouping=true
			"supply":
				for region:StrategicRegionState in world.strategic_regions.values():
					if region.controller_faction_id==1:region.contested=true
			"space":
				faction.supply=17
				RecruitmentArbitrationSystem.propose_commands(world,1)
				block_birth_area(world,card)
				apply_queue(world)
		if cause!="space":RecruitmentArbitrationSystem.refresh(world,1)
		check(faction.recruitment_arbitration.reserved_commander_id.is_empty(),"reservation released "+cause)
		check(faction.recruitment_arbitration.reserved_amount==0,"held funds released "+cause)
		if cause=="space":
			check(faction.supply==17 and faction.population==60,"blocked reserved birth does not charge")
			check(faction.recruitment_arbitration.reasons[commander.definition.definition_id]==&"GROWTH_WAIT_SPACE","blocked birth has visible wait reason")

func test_support_and_visibility()->void:
	var world:=prepare()
	isolate(world,[&"spear"])
	var faction:=world.factions[1] as FactionState
	var kind:=SupportOrderCommand.SupportKind.AIR_RECON
	var cost:=world.get_support_cost(kind)
	faction.supply=cost
	faction.recruitment_reserve=cost-3
	RecruitmentArbitrationSystem.refresh(world,1)
	var owner:=faction.recruitment_arbitration.reserved_commander_id
	var copy:=world.create_logistics_snapshot(1,true)
	var hidden:=world.create_faction_snapshot(2).get_faction(1)
	check(hidden.recruitment_arbitration.reserved_commander_id.is_empty() and hidden.recruitment_arbitration.waiting_since.is_empty(),"enemy cannot read reservation or waiting age")
	var support:=AreaSupportCommand.new(world.allocate_command_id(),1,GameCommand.IssuerKind.PLAYER,world.current_tick,kind,world.battle_definition.player_headquarters_position)
	var support_result:=world.submit_command(support)
	check(support_result.is_accepted(),"player support allowed to spend soft-reserved money: "+support_result.describe())
	check(faction.recruitment_arbitration.reserved_commander_id.is_empty(),"support commitment below minimum releases immediately")
	apply_queue(world)
	check(faction.supply==0,"support cost paid without invented funds")
	check(copy.get_faction(1).recruitment_arbitration.reserved_commander_id==owner and copy.get_faction(1).recruitment_arbitration.reserved_amount==3,"old reservation snapshot remains a value copy")
	faction.recruitment_arbitration.waiting_since.clear()
	check(not copy.get_faction(1).recruitment_arbitration.waiting_since.is_empty(),"old waiting dictionary not aliased")

func test_income_stream()->void:
	var hashes:Array[String]=[]
	for repeat in range(2):
		var world:=prepare()
		var faction:=world.factions[1] as FactionState
		faction.supply=12
		var trace:Array[String]=[]
		var spent:=0
		for second in range(100):
			world.current_tick=300+second*10
			faction.supply+=1
			var before:=faction.supply
			RecruitmentArbitrationSystem.propose_commands(world,1)
			apply_queue(world)
			spent+=before-faction.supply
			check(faction.supply>=12,"small-income stream never spends minimum reserve")
			check(faction.recruitment_arbitration.reserved_amount<=5,"only bounded real funds reserved")
			trace.append(str([world.current_tick,faction.supply,faction.population,faction.recruitment_arbitration.reserved_commander_id,faction.recruitment_arbitration.reserved_slot]))
		for profile in LegionTemplate.PROFILE_IDS:
			check(leader(world,profile).growth_unlocked_slots>12,"small-income stream serves every legion "+str(profile))
		check(faction.supply+spent==112,"100 income exactly conserved")
		hashes.append("\n".join(trace).sha256_text())
		traces.append({"repeat":repeat,"stream_hash":hashes[-1],"population":faction.population,"spent":spent,"supply":faction.supply})
	check(hashes[0]==hashes[1],"same small-income stream produces identical schedule")

func _initialize()->void:
	test_rounds()
	test_saving()
	test_release()
	test_support_and_visibility()
	test_income_stream()
	FileAccess.open("res://artifacts/legion36/economy.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED","checks":checks,"failures":failures,"traces":traces,"scope":"real command queue/application with controlled income; not full match"}))
	print("LEGION36_ECONOMY checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
