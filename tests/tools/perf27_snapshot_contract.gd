extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var world := SimulationWorld.new(true,false,SimulationWorld.ScenarioKind.FINAL_DECISION)
	var reference_unit = preload("res://tests/tools/perf27_reference_unit.gd")
	var unit: UnitState = world.units.values()[0]
	for count in [0,1,2,500]:
		unit.path.clear()
		for i in count: unit.path.append(Vector2(i * 7, i * 13))
		for moving in [false,true]:
			unit.has_move_target = moving
			for index in [-2,0,1,count,count+5]:
				unit.path_index = index
				var old = reference_unit.new(unit)
				var actual := UnitSnapshot.new(unit)
				check(actual.path == old.path, "path boundary %d/%s/%d" % [count,moving,index])
				if count > 0:
					var source := unit.path.duplicate()
					actual.path[0] += Vector2(999,888)
					check(unit.path == source, "snapshot write cannot mutate world path")
					var retained: PackedVector2Array = old.path.duplicate()
					unit.path[0] += Vector2(11,12)
					check(old.path == retained, "world write cannot mutate old path")
	unit.has_move_target = false
	var timings := {"reference":0,"candidate":0}
	for phase in range(30):
		world.current_tick = phase * 10
		for enemy: UnitState in world.units.values():
			enemy.enabled = (enemy.entity_id + phase) % 9 != 0
			enemy.position = Vector2(16384 + enemy.entity_id % 20 * 12, 12288 + enemy.entity_id % 13 * 14) if phase % 2 == 0 else Vector2(1000 if enemy.faction_id == 1 else 30000,1000)
		world._update_faction_knowledge()
		for faction in [1,2]:
			var begin := Time.get_ticks_usec()
			var old := world.create_commander_task_snapshot(faction)
			timings.reference += Time.get_ticks_usec()-begin
			begin = Time.get_ticks_usec()
			var actual := world.create_logistics_snapshot(faction,true)
			timings.candidate += Time.get_ticks_usec()-begin
			var compact := world.create_logistics_snapshot(faction,false)
			for card in old.unit_cards:
				var point := AutomaticLogisticsAgent.recruitment_position(old,card,world.battle_definition)
				check(point == AutomaticLogisticsAgent.recruitment_position(compact,card,world.battle_definition),"recruit position")
				for offset in [Vector2.ZERO,Vector2(world.battle_definition.reinforcement_safe_radius,0),Vector2(1,0)]:
					check(AutomaticLogisticsAgent.is_safe(old,point+offset,world.battle_definition) == AutomaticLogisticsAgent.is_safe(compact,point+offset,world.battle_definition),"safety equivalence")
					check(AutomaticLogisticsAgent.is_in_supply(old,point+offset,world.battle_definition) == AutomaticLogisticsAgent.is_in_supply(compact,point+offset,world.battle_definition),"supply equivalence")
			var a := AutomaticLogisticsAgent.new().propose(old,world.battle_definition)
			var b := AutomaticLogisticsAgent.new().propose(actual,world.battle_definition)
			check((a == null) == (b == null),"same proposal presence")
			if a is RecruitUnitCardCommand and b is RecruitUnitCardCommand:
				check(a.unit_card_id == b.unit_card_id and a.member_count == b.member_count and a.agent_id == b.agent_id and a.task_id == b.task_id,"same proposal values")
			if not compact.units.is_empty():
				var prior := compact.units[0].position
				world.units[compact.units[0].entity_id].position += Vector2(13,17)
				check(compact.units[0].position == prior,"logistics snapshot position isolation")
	var report := {"evidence":"SIMULATED","checks":checks,"failures":failures,"view_build_usec":timings}
	FileAccess.open("res://artifacts/perf27-snapshot-contract.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("PERF27_SNAPSHOT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
