class_name LegionConfiguration
extends Resource

@export var legion_id: StringName
@export var profile_id: StringName
@export var role_strengths: PackedInt32Array = PackedInt32Array([12, 20, 16, 12])

func select_profile(id: StringName) -> void:
	profile_id = id
	var template := LegionTemplate.find(id)
	if template != null: role_strengths = template.full.duplicate()

func starting_strengths() -> PackedInt32Array:
	var template := LegionTemplate.find(profile_id)
	if template != null: return template.opening.duplicate()
	var result := PackedInt32Array([0, 0, 0, 0])
	var used := 0
	for i in range(4):
		result[i] = role_strengths[i] / 5
		used += result[i]
	while used < 12:
		var best := -1
		var remainder := -1
		for i in range(4):
			var value := role_strengths[i] - result[i] * 5
			if value > remainder and result[i] < role_strengths[i]:
				best = i
				remainder = value
		if best < 0: break
		result[best] += 1
		used += 1
	return result
