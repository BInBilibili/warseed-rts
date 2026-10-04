extends SceneTree

var failures:Array[String]=[]
var checks:=0

func check(value:bool,reason:String)->void:
	checks+=1
	if not value:failures.append(reason)

func _initialize()->void:
	var fingerprints:Array[String]=[]
	var summaries:Array[Dictionary]=[]
	for repeat in range(2):
		var world:=SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
		var old_snapshot:=world.create_logistics_snapshot(1,true)
		var previous_ids:=world.units.keys()
		var initial_count:=world.units.size()
		var trace:Array[String]=[]
		for tick in range(300):
			var snapshot:=world.advance_tick()
			check(snapshot.tick==tick+1,"fixed tick progression")
			for faction:FactionState in world.factions.values():
				var count:=0
				for amount in faction.recruited_by_commander.values():count+=amount
				check(count<=5,"actual faction window <=5")
				check(faction.supply>=0 and faction.supply<=faction.supply_capacity,"actual supply bounds")
				for id in faction.recruited_by_commander:
					check(faction.recruited_by_commander[id]<=2,"actual commander window <=2")
			for commander:CommanderState in world.commanders.values():
				var template:=LegionTemplate.find(commander.definition.profile.profile_id)
				var seen:Dictionary={}
				for slot in range(commander.growth_unlocked_slots):
					var id:=commander.growth_slot_entities[slot]
					var unit:=world.units.get(id) as UnitState
					if unit==null or not unit.enabled:continue
					check(not seen.has(id),"live entity occupies exactly one growth slot")
					seen[id]=true
					var card:=world.unit_cards[unit.unit_card_id] as UnitCardState
					check(card.definition.role_key==LegionTemplate.ROLE_KEYS[template.slot_roles()[slot]],"actual ticking keeps slot role")
			for id in world.units:
				if previous_ids.has(id):continue
				var unit:=world.units[id] as UnitState
				if not unit.hero_commander_id.is_empty():continue
				check(world.logic_grid.is_world_position_walkable(unit.position),"new soldier remains on valid ground after first live tick")
			previous_ids=world.units.keys()
			if tick%50==49:trace.append(JSON.stringify([world.current_tick,world.units.size(),world.factions[1].supply,world.factions[2].supply]))
		for event in world.events:trace.append("%d:%d:%d:%s" % [event.tick,event.kind,event.entity_id,event.detail])
		var ids:=world.units.keys();ids.sort()
		for id in ids:
			var unit:=world.units[id] as UnitState
			trace.append(str([id,unit.position,unit.health,unit.enabled]))
		fingerprints.append("\n".join(trace).sha256_text())
		check(world.units.size()>initial_count,"automatic logistics births through real tick loop")
		check(old_snapshot.get_faction(1).supply==24,"old economy snapshot immutable")
		for commander in old_snapshot.commanders:check(commander.growth_unlocked_slots==12,"old live growth snapshot immutable")
		summaries.append({"repeat":repeat,"ticks":world.current_tick,"units":world.units.size(),"blue_supply":world.factions[1].supply,"red_supply":world.factions[2].supply,"hash":fingerprints[-1]})
		print("LIVE_REPEAT ",summaries[-1])
	check(fingerprints[0]==fingerprints[1],"two autonomous 300-tick runs match event and final entity traces")
	FileAccess.open("res://artifacts/legion35/live.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED","checks":checks,"failures":failures,"runs":summaries,"scope":"30-second autonomous smoke, not a full match or economics acceptance"}))
	for failure in failures:push_error(failure)
	print("LEGION35_LIVE checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
