extends "res://tests/tools/legion34_candidate_lab.gd"

const BUDGET_OUT := "res://artifacts/legion37/"
var policy := "baseline"
var initial_count := 0
var initial_hp := 0.0
var initial_scout_hp := 0.0
var scout_health: Array[float] = []
var recalls := 0
var budget_exits := 0

func sample(count: int, mirror: bool, selected: String) -> Dictionary:
	policy = selected
	initial_count = count
	initial_hp = 0.0
	initial_scout_hp = 0.0
	scout_health.clear()
	recalls = 0
	budget_exits = 0
	var row := battle(3, 0, count, int(count / 2), "light_guard", "special", 0, mirror)
	row["policy"] = policy
	row["budget_exits"] = budget_exits
	row["whole_scout_recall"] = recalls
	return row

func _initialize() -> void:
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/legion34/v3/config.json")).profiles
	for count in [12,24,36,48,60]:
		for mirror in [false,true]:
			for selected in ["baseline", "whole_scout_recall", "loss_budget"]:
				results.append(sample(count, mirror, selected))
		print("LEGION37_SENTINEL_PROGRESS count=", count)
	var repeats: Array = []
	for selected in ["baseline", "whole_scout_recall", "loss_budget"]:
		var first: Dictionary = {}
		for row in results:
			if row.na == 60 and not row.mirrored and row.policy == selected: first = row
		var second := sample(60, false, selected)
		var same := JSON.stringify(first) == JSON.stringify(second)
		repeats.append({"policy": selected, "same": same, "first": first, "second": second})
		if not same: errors.append("sentinel_repeat_" + selected)
	FileAccess.open(BUDGET_OUT + "sentinel.json", FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_PROTOTYPE", "cases":results.size(), "results":results, "repeat_pairs":repeats, "errors":errors}))
	print("LEGION37_SENTINEL_DONE cases=", results.size(), " errors=", errors.size())
	quit(0 if errors.is_empty() else 1)

func spawn_army(profile: int, strength: int, faction: int, id_base: int, center: Vector2, facing: Vector2, action: String, form: String, units: Dictionary) -> LabFormation:
	var army := super(profile, strength, faction, id_base, center, facing, action, form, units)
	if faction == 1:
		for id in army.member_entity_ids:
			var u: UnitState = units[id]
			initial_hp += u.max_health
			if u.tactical_role == UnitState.TacticalRole.SCOUT: initial_scout_hp += u.max_health
	return army

func revise_policy(army: LabFormation, units: Dictionary, legal: Array, tick: int, grid: LogicGrid) -> void:
	if army.formation_id == 1 and army.action != "retreat" and policy != "baseline":
		var hp := 0.0
		var scout_hp := 0.0
		for id in army.member_entity_ids:
			var u: UnitState = units[id]
			if not u.enabled: continue
			hp += u.health
			if u.tactical_role == UnitState.TacticalRole.SCOUT: scout_hp += u.health
		scout_health.append(scout_hp)
		if scout_health.size() > 7: scout_health.pop_front()
		if scout_health[0] - scout_hp >= initial_scout_hp * 0.15 and not army.scouts_recalled:
			army.scouts_recalled = true
			recalls += 1
		if policy == "loss_budget" and (alive(units, army, true) <= initial_count * 0.75 or hp <= initial_hp * 0.7):
			army.action = "retreat"
			army.retreat_reason = "loss_budget"
			budget_exits += 1
	super(army, units, legal, tick, grid)
