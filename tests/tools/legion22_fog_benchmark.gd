extends SceneTree
func _initialize() -> void:
	var old_script := load("res://artifacts/legion22-fog-reference.gd")
	var old: RefCounted = old_script.new(1, Vector2i(1024,768))
	var optimized := FactionKnowledge.new(1, Vector2i(1024,768))
	var results: Array = []
	for knowledge in [old, optimized]:
		var started := Time.get_ticks_usec()
		for repeat in range(20):
			knowledge.begin_update()
			for group in range(5):
				for unit in range(60):
					knowledge.reveal(Vector2i(100 + group * 140 + unit % 10, 100 + group * 100 + unit / 10), 12 if unit < 12 else 9)
		results.append((Time.get_ticks_usec() - started) / 1000.0)
	var equal: bool = old.cells == optimized.cells
	print("LEGION22_FOG ", JSON.stringify({"old_ms":results[0],"optimized_ms":results[1],"identical":equal}))
	quit(0 if equal else 1)
