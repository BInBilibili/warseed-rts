class_name MapContentCatalog
extends Resource

@export var maps: Array[MapDefinition] = []

func validate() -> Array[String]:
	var issues: Array[String] = []
	var ids: Dictionary = {}
	for index in range(maps.size()):
		var map := maps[index]
		if map == null:
			issues.append("maps[%d] is null" % index)
			continue
		if map.definition_id.is_empty() or ids.has(map.definition_id):
			issues.append("duplicate or empty map ID at index %d" % index)
		ids[map.definition_id] = true
		issues.append_array(map.validate())
	return issues

func get_map(map_id: StringName) -> MapDefinition:
	for map in maps:
		if map != null and map.definition_id == map_id:
			return map
	return null
