extends "res://tests/tools/legion34_candidate_lab.gd"

# Isolate the two rejected factors. Do not change the historical lab or runtime.
const FACTOR_OUT := "res://artifacts/legion37/"
var policy := "baseline"
var turns := 0
var repairs := 0
var last_counts: Dictionary = {}
var hidden_defense := false

func sample(profile: int, count: int, scenario: String, mirror: bool, selected: String) -> Dictionary:
	policy = selected
	turns = 0
	repairs = 0
	last_counts.clear()
	hidden_defense = scenario.begins_with("hidden")
	var row := battle(profile, 0, count, count, scenario, "special", 0, mirror)
	row["policy"] = policy
	row["turn_updates"] = turns
	row["repair_updates"] = repairs
	return row

func spawn_army(profile: int, strength: int, faction: int, id_base: int, center: Vector2, facing: Vector2, action: String, form: String, units: Dictionary) -> LabFormation:
	return super(profile, strength, faction, id_base, center, facing, "defend" if hidden_defense and faction == 1 else action, form, units)

func _initialize() -> void:
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/legion34/v4/config.json")).profiles
	DirAccess.make_dir_recursive_absolute(FACTOR_OUT)
	var mode := "smoke"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	for profile in range(5):
		if mode == "smoke" and profile != 2: continue
		for count in ([12] if mode == "smoke" else [12,24,36,48,60]):
			for scenario in ["flank", "attack_defense"]:
				for mirror in [false, true]:
					for selected in ["baseline", "turn_only", "repair_only", "combined"]:
						results.append(sample(profile, count, scenario, mirror, selected))
			print("LEGION37_PROGRESS profile=", profile, " count=", count, " cases=", results.size())
	var repeats: Array = []
	var hidden: Array = []
	if mode == "matrix":
		for profile in range(5):
			for selected in ["turn_only", "repair_only"]:
				var first := sample(profile, 36, "flank", false, selected)
				var second := sample(profile, 36, "flank", false, selected)
				var same := JSON.stringify(first) == JSON.stringify(second)
				repeats.append({"profile": profile, "policy": selected, "same": same, "first": first, "second": second})
				if not same: errors.append("repeat_" + str(profile) + "_" + selected)
			for selected in ["baseline", "turn_only", "repair_only", "combined"]:
				var first := sample(profile, 12, "hidden1", false, selected)
				var second := sample(profile, 12, "hidden2", false, selected)
				var same: bool = first.own_trace_sha256 == second.own_trace_sha256
				hidden.append({"profile": profile, "policy": selected, "same": same})
				if not same: errors.append("hidden_" + str(profile) + "_" + selected)
	FileAccess.open(FACTOR_OUT + mode + ".json", FileAccess.WRITE).store_string(JSON.stringify({"evidence": "SIMULATED_PROTOTYPE", "cases": results.size(), "results": results, "repeat_pairs": repeats, "hidden_pairs": hidden, "errors": errors}))
	print("LEGION37_DONE cases=", results.size(), " errors=", errors.size())
	quit(0 if errors.is_empty() else 1)

func revise_policy(army: LabFormation, units: Dictionary, legal: Array, tick: int, grid: LogicGrid) -> void:
	if army.formation_id == 1 and army.action == "defend" and army.revised:
		if policy in ["turn_only", "combined"]:
			var nearest := INF
			var selected := 0
			for id in legal:
				var distance: float = army.anchor_position.distance_squared_to(units[id].position)
				if distance < nearest: nearest = distance; selected = id
			if selected:
				var intended: Vector2 = (units[selected].position - army.anchor_position).normalized()
				var angle := army.facing.angle_to(intended)
				if absf(angle) > deg_to_rad(5):
					army.facing = army.facing.rotated(clampf(angle, -deg_to_rad(10), deg_to_rad(10)))
					turns += 1
		if policy in ["repair_only", "combined"]:
			var live_counts := [0,0,0,0,0]
			for id in army.member_entity_ids:
				if units[id].enabled: live_counts[int(String(units[id].definition_id).trim_prefix("lab_"))] += 1
			if last_counts.has(army.formation_id) and last_counts[army.formation_id] != live_counts:
				var indices := [0,0,0,0,0]
				for slot in range(army.member_entity_ids.size()):
					var u: UnitState = units[army.member_entity_ids[slot]]
					if not u.enabled: continue
					var role := int(String(u.definition_id).trim_prefix("lab_"))
					army.offsets[slot] = offset_for(army.profile, role, indices[role], live_counts[role], "defend", false, slot, alive(units, army, true))
					indices[role] += 1
				repairs += 1
			last_counts[army.formation_id] = live_counts.duplicate()
	super(army, units, legal, tick, grid)
