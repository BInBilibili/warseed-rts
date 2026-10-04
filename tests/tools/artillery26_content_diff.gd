extends SceneTree
var differences: Array[String] = []
var checked := 0
func _initialize() -> void:
	var before := load("res://artifacts/artillery26-before-battle.tres") as BattleDefinition
	var after := load("res://data/battles/final_decision.tres") as BattleDefinition
	_compare(before, after, "battle")
	print("ARTILLERY26_CONTENT_DIFF ", JSON.stringify({"checked": checked, "unexpected_differences": differences}))
	quit(0 if differences.is_empty() else 1)
func _compare(a: Variant, b: Variant, path: String) -> void:
	checked += 1
	if a is Resource and b is Resource:
		for property in a.get_property_list():
			var key: String = property.name
			if property.usage & PROPERTY_USAGE_STORAGE == 0 or key in ["script", "resource_local_to_scene", "resource_name", "resource_path"]: continue
			if a is UnitCardDefinition and a.role_key == &"UNIT_CARD_ROLE_FIREPOWER" and key in ["combat_override", "tactical_ability", "tactical_weapon_override", "fallback_weapon"]: continue
			_compare(a.get(key), b.get(key), path + "." + key)
	elif a is Array and b is Array:
		if a.size() != b.size(): differences.append(path + " size")
		else:
			for i in range(a.size()): _compare(a[i], b[i], path + "[%d]" % i)
	elif a is Dictionary and b is Dictionary:
		if a.size() != b.size(): differences.append(path + " keys")
		else:
			for key in a:
				if not b.has(key): differences.append(path + " missing " + str(key))
				else: _compare(a[key], b[key], path + "." + str(key))
	elif a != b:
		differences.append(path + ": " + str(a) + " != " + str(b))
