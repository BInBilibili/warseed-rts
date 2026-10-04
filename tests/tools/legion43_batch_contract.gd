extends SceneTree

const Planner = preload("res://src/simulation/systems/legion_batch_planner.gd")

class Fixture extends RefCounted:
	var commander: CommanderSnapshot
	var own: Array[UnitSnapshot] = []
	var cards: Array[StringName] = []
	var template: LegionTemplate

var checks := 0
var failures: Array[String] = []
var growth_cases := 0
var source_commanders: Array[CommanderState] = []
var output := "res://artifacts/legion43/batch01.json"
var cases: Array[Dictionary] = []

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value and not failures.has(reason): failures.append(reason)

func fixture(source: CommanderState, count: int, id_shift: int = 0) -> Fixture:
	var f := Fixture.new()
	f.template = LegionTemplate.find(source.definition.profile.profile_id)
	var state := CommanderState.new(source.definition,source.faction_id)
	state.growth_unlocked_slots = count
	state.growth_slot_entities.resize(60); state.growth_slot_entities.fill(0)
	for role in range(4):
		f.cards.append(StringName("test_card_%d" % role))
	state.subordinate_unit_card_ids = f.cards.duplicate()
	var roles := f.template.slot_roles()
	var unit_roles := [UnitState.TacticalRole.SCOUT,UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR,UnitState.TacticalRole.FIREPOWER]
	for identity in range(count+1):
		var hero := identity == count
		var entity_id := id_shift+(1000 if hero else identity+1)
		var unit := UnitState.new(entity_id,Vector2(identity*48,0),150,source.faction_id)
		unit.control_state = UnitState.ControlState.AGENT_ASSIGNED
		if hero:
			state.hero_entity_id = entity_id
			unit.hero_commander_id = source.definition.definition_id
		else:
			state.growth_slot_entities[identity] = entity_id
			unit.unit_card_id = f.cards[roles[identity]]
			unit.tactical_role = unit_roles[roles[identity]]
		f.own.append(UnitSnapshot.new(unit))
	f.commander = CommanderSnapshot.new(state)
	return f

func shape(plan: Planner.Plan) -> String:
	var text := ""
	for batch in plan.batches: text += str(batch.identities)+";"
	for member in plan.members: text += "%d:%d:%d:%s;" % [member.identity,member.batch,member.ordinal,member.offset]
	return text

func verify_layout(f: Fixture, plan: Planner.Plan, count: int) -> void:
	check(plan.valid and plan.advance_ready,"healthy plan ready "+String(f.commander.profile_id)+str(count))
	check(plan.members.size()==61 and plan.total_available==count+1,"exact roster and eligible count")
	check(plan.batches.size()==ceili((count+1)/12.0),"minimal balanced batch count")
	var identities: Array[int] = []
	var minimum := 100
	var maximum := 0
	var previous_end := -96.0
	for batch in plan.batches:
		minimum = mini(minimum,batch.identities.size()); maximum = maxi(maximum,batch.identities.size())
		check(batch.identities.size()<=12 and batch.available==batch.identities.size(),"batch capacity and actual eligibility")
		check(batch.depth_start-previous_end>=95.99,"96 reference envelope gap")
		previous_end = batch.depth_start+batch.depth
		if batch.has_hero: check(batch.escorts>=1,"real escort in hero batch")
		if batch.artillery>0: check(batch.escorts>=2,"two actual escorts in artillery batch")
		for identity in batch.identities:
			check(not identities.has(identity),"identity appears in exactly one batch")
			identities.append(identity)
			var member := plan.members[identity]
			check(member.entity_id>0 and member.availability==Planner.Availability.AVAILABLE,"assigned entity exists and available")
			check(absf(member.offset.y)<=48.01,"three-column reference width")
	check(maximum-minimum<=1,"healthy regroup balances batch sizes")
	check(identities.size()==count+1 and identities.has(60),"all and only actual participants assigned")
	check(plan.members[60].batch==plan.batches.size()/2,"hero uses middle batch toward exit")
	for first in identities:
		for second in identities:
			if first<second: check(plan.members[first].offset.distance_to(plan.members[second].offset)>=47.99,"distinct reference slots never overlap")

func transitions(source: CommanderState) -> void:
	var f := fixture(source,24)
	var original := Planner.plan(f.template,f.commander,f.own,f.cards)
	var frozen := shape(original)
	var dead := f.own[0]
	dead.enabled = false
	var damaged := Planner.plan(f.template,f.commander,f.own,f.cards,original)
	check(shape(damaged)==frozen,"death does not compact survivors")
	check(damaged.members[0].availability==Planner.Availability.ABSENT,"death creates actual vacancy")
	check(original.members[0].availability==Planner.Availability.AVAILABLE,"old plan is a value snapshot")
	dead.entity_id = 9000; dead.enabled = true; dead.rejoin_pending = true
	f.commander.growth_slot_entities[0] = dead.entity_id
	var incoming := Planner.plan(f.template,f.commander,f.own,f.cards,damaged)
	check(incoming.members[0].entity_id==9000 and incoming.members[0].availability==Planner.Availability.REJOINING,"replacement binds original identity while rejoining")
	check(shape(incoming)==frozen and incoming.total_available==24,"in-transit replacement excluded from current denominator")
	dead.rejoin_pending = false
	var restored := Planner.plan(f.template,f.commander,f.own,f.cards,incoming)
	check(restored.members[0].availability==Planner.Availability.AVAILABLE and shape(restored)==frozen,"replacement returns to same authorized slot")
	var cards := f.cards.duplicate()
	cards.erase(f.cards[1])
	var manual := Planner.plan(f.template,f.commander,f.own,cards,restored)
	check(shape(manual)==frozen,"manual whole-card departure does not repack others")
	for member in manual.members:
		if member.role==1 and member.entity_id>0: check(member.availability==Planner.Availability.MANUAL,"manual card never borrowed for batch")
	f.own[1].legion_returning = true
	var returning := Planner.plan(f.template,f.commander,f.own,f.cards,restored)
	check(returning.members[1].availability==Planner.Availability.RETURNING and shape(returning)==frozen,"return-home precedes forming")
	var grown := fixture(source,25)
	var queued := Planner.plan(grown.template,grown.commander,grown.own,grown.cards,original)
	check(shape(queued)==frozen and queued.pending_identities==PackedInt32Array([24]),"new growth waits without shifting marching identities")
	check(queued.advance_ready and queued.reason==&"REJOIN_WAIT","waiting new soldier does not stall existing healthy core")
	var regroup := Planner.plan(grown.template,grown.commander,grown.own,grown.cards,queued,true)
	verify_layout(grown,regroup,25)
	check(regroup.epoch==queued.epoch+1 and regroup.pending_identities.is_empty(),"explicit safe regroup admits new identity")
	for unit in grown.own:
		if unit.tactical_role in [UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR]: unit.enabled=false
	var no_core := Planner.plan(grown.template,grown.commander,grown.own,grown.cards,regroup)
	check(no_core.valid and not no_core.advance_ready and no_core.reason==&"NO_CORE","loss of all core is explicit and does not fake readiness")
	check(shape(no_core)==shape(regroup),"no-core failure does not erase existing exit layout")
	grown.own[-1].control_state = UnitState.ControlState.TEMPORARILY_OVERRIDDEN
	var hero_manual := Planner.plan(grown.template,grown.commander,grown.own,grown.cards,regroup)
	check(hero_manual.reason==&"HERO_UNAVAILABLE" and not hero_manual.advance_ready,"manual hero is not moved by planner")
	var copy := original.duplicate_value()
	copy.members[0].entity_id=-5; copy.batches[0].identities[0]=-5
	check(original.members[0].entity_id>0 and original.batches[0].identities[0]>=0,"nested plan copy is independent")
	var invalid := fixture(source,12)
	invalid.commander.growth_slot_entities[1]=invalid.commander.growth_slot_entities[0]
	check(not Planner.plan(invalid.template,invalid.commander,invalid.own,invalid.cards).valid,"duplicate roster identity rejected")
	invalid=fixture(source,12); invalid.own[0].faction_id=3
	check(not Planner.plan(invalid.template,invalid.commander,invalid.own,invalid.cards).valid,"foreign view rejected")
	invalid=fixture(source,12); invalid.own.append(invalid.own[0])
	check(not Planner.plan(invalid.template,invalid.commander,invalid.own,invalid.cards).valid,"duplicate input unit rejected")
	invalid=fixture(source,12); invalid.own[0].tactical_role=UnitState.TacticalRole.NONE
	check(not Planner.plan(invalid.template,invalid.commander,invalid.own,invalid.cards).valid,"wrong role rejected")
	invalid=fixture(source,12); invalid.own[0].unit_card_id=&"other_legion_card"
	invalid.cards.append(&"other_legion_card")
	check(not Planner.plan(invalid.template,invalid.commander,invalid.own,invalid.cards).valid,"foreign legion card cannot fill roster identity")
	var reborn := fixture(source,12)
	reborn.own[-1].enabled=false
	var dead_hero_plan := Planner.plan(reborn.template,reborn.commander,reborn.own,reborn.cards)
	reborn.own[-1].enabled=true
	var hero_pending := Planner.plan(reborn.template,reborn.commander,reborn.own,reborn.cards,dead_hero_plan)
	check(not hero_pending.advance_ready and hero_pending.reason==&"HERO_REJOIN_WAIT","respawn without protected slot cannot authorize advance")
	var hero_joined := Planner.plan(reborn.template,reborn.commander,reborn.own,reborn.cards,hero_pending,true)
	check(hero_joined.advance_ready and hero_joined.members[60].batch>=0,"safe regroup restores actual protected hero slot")
	reborn.commander.legion_regrouping=true
	var recovery := Planner.plan(reborn.template,reborn.commander,reborn.own,reborn.cards,hero_joined)
	check(not recovery.advance_ready and recovery.reason==&"REGROUPING","commander recovery overrides geometry readiness")
	var shrink := fixture(source,12)
	check(not Planner.plan(shrink.template,shrink.commander,shrink.own,shrink.cards,original).valid,"unlocked identity history cannot silently regress")
	var deprived := fixture(source,24)
	var protected := Planner.plan(deprived.template,deprived.commander,deprived.own,deprived.cards)
	var hero_batch := protected.members[60].batch
	for identity in protected.batches[hero_batch].identities:
		if protected.members[identity].role in [1,2]: deprived.own[identity].enabled=false
	var shortage := Planner.plan(deprived.template,deprived.commander,deprived.own,deprived.cards,protected)
	check(not shortage.advance_ready and shortage.reason==&"ESCORT_SHORTAGE","distant core cannot replace missing same-batch escort")
	check(shape(shortage)==shape(protected),"escort loss preserves physical exit order")

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	for commander: CommanderState in world.commanders.values(): source_commanders.append(commander)
	for faction in [1,2]:
		var view := world.create_faction_snapshot(faction)
		var own: Array[UnitSnapshot] = []
		var automatic: Array[StringName] = []
		for unit in view.units:
			if unit.faction_id==faction: own.append(unit)
		for card in view.unit_cards:
			if card.faction_id==faction and card.control_state==UnitCardState.ControlState.AGENT_ASSIGNED: automatic.append(card.definition_id)
		for commander in view.commanders:
			if commander.faction_id!=faction: continue
			var plan := Planner.plan(LegionTemplate.find(commander.profile_id),commander,own,automatic)
			check(plan.valid and plan.advance_ready and plan.total_available==13,"real own opening snapshot usable "+String(commander.definition_id))
	for source in source_commanders:
		for count in range(12,61):
			var f := fixture(source,count)
			var first := Planner.plan(f.template,f.commander,f.own,f.cards)
			verify_layout(f,first,count)
			f.own.reverse()
			var reverse := Planner.plan(f.template,f.commander,f.own,f.cards)
			check(shape(first)==shape(reverse),"input permutation preserves identity slots")
			var renumbered := fixture(source,count,2000)
			check(shape(first)==shape(Planner.plan(renumbered.template,renumbered.commander,renumbered.own,renumbered.cards)),"entity number changes do not change identity layout")
			cases.append({"profile":String(f.commander.profile_id),"faction":f.commander.faction_id,"count":count,"shape":shape(first).sha256_text(),"batches":first.batches.size(),"available":first.total_available,"depth":first.batches[-1].depth_start+first.batches[-1].depth,"hero_batch":first.members[60].batch})
			growth_cases+=1
		transitions(source)
	var result := {"evidence":"SIMULATED_PREINTEGRATION","checks":checks,"failures":failures,"growth_cases":growth_cases,"cases":cases,"real_opening_commanders":10,"scope":"typed stable identity/batch planning; no physical movement or full B certification"}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result))
	print("LEGION43_BATCH checks=",checks," growth_cases=",growth_cases," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
