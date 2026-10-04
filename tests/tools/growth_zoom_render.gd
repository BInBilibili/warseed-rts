extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(960, 640)
	var presentation := WorldPresentation.new()
	for child_name in ["Units", "Buildings", "OreFields"]:
		var child := Node2D.new()
		child.name = child_name
		presentation.add_child(child)
	root.add_child(presentation)
	var origin := Vector2(2064, 22544)
	for count in [48, 128]:
		var units: Array[UnitSnapshot] = []
		for i in range(count):
			var unit := UnitState.new(i + 1, origin + Vector2((i % 16 - 8) * 80, (i / 16 - 4) * 80), 100, 1)
			unit.definition_id = &"scout_vehicle"
			units.append(UnitSnapshot.new(unit))
		var snapshot := WorldSnapshot.new(count, units)
		snapshot.observer_faction_id = 1
		snapshot.navigation_map_id = &"final_decision"
		presentation.set_snapshots(null, snapshot, 1.0)
		for zoom_value in [1.0, 0.5, 0.2, 0.05, 0.02, 0.8]:
			root.canvas_transform = Transform2D(0.0, Vector2.ONE * zoom_value, 0.0, Vector2(480, 320) - origin * zoom_value)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered := root.get_texture().get_image()
			var cyan_pixels := 0
			for x in range(160, 800):
				for y in range(80, 560):
					var color := rendered.get_pixel(x, y)
					if color.b > 0.55 and color.g > 0.4 and color.r < color.b * 0.72:
						cyan_pixels += 1
			if cyan_pixels < 18:
				failures.append("units unreadable count=%d zoom=%.2f pixels=%d" % [count, zoom_value, cyan_pixels])
			rendered.save_png("res://artifacts/growth-zoom-%d-%d.png" % [count, roundi(zoom_value * 100)])
			print("ZOOM_RENDER count=%d zoom=%.2f cyan_pixels=%d" % [count, zoom_value, cyan_pixels])
	# No hidden enemies may be synthesized by the strategic overlay.
	var legal := WorldSnapshot.new(900, [])
	legal.observer_faction_id = 1
	legal.navigation_map_id = &"final_decision"
	presentation.set_snapshots(null, legal, 1.0)
	if not presentation._strategic_units._markers.is_empty():
		failures.append("empty legal snapshot generated markers")
	for failure in failures:
		push_error(failure)
	print("GROWTH_ZOOM_RENDER failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
