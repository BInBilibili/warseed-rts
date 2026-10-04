extends SceneTree

class Overview extends Node2D:
	var map: MapDefinition
	var factor := 0.038
	var offset := Vector2(108, 100)
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 1460, 1180), Color("101b20"))
		draw_string(font, Vector2(72, 52), "WARSEED  /  FINAL DECISION", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("deebe8"))
		draw_string(font, Vector2(72, 80), "32,768 x 24,576   |   26 supply points   |   48 -> 256 per faction", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("9cb7b1"))
		for connector in map.connectors:
			_draw_route(connector.route_points, connector.width_cells * 32.0 * factor, Color("438da8") if connector.connector_id == &"river" else (Color("d7b869") if String(connector.connector_id).ends_with("_river_link") else Color("3c5854")))
		for lane in map.lanes:
			_draw_route(lane.route_points, lane.width_cells * 32.0 * factor, Color("647872"))
		for point in map.supply_points:
			var position := offset + point.position * factor
			var color := Color("54d0f3") if String(point.point_id).begins_with("blue") else (Color("f97863") if String(point.point_id).begins_with("red") else Color("d8c17c"))
			SupplyPointSymbol.draw_on(self, position, point.tier, 10 if point.is_base else 8, color, 2)
			var label: String = "HQ" if point.is_base else ["", "", "H", "I", "O", "s", "L"][point.tier]
			draw_string(font, position + Vector2(12, -10), "%s +%d" % [label, point.supply_per_settlement], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		draw_string(font, Vector2(80, 1090), "H  High ground +4     I  Inner +6     O  Outer +8     s  Small jungle +3     L  Major jungle +7", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d4dfd9"))
		draw_string(font, Vector2(80, 1122), "Income every 20s. HQ +12. All non-HQ points start neutral; team colors here identify mirrored geography.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("9cb7b1"))
		draw_string(font, Vector2(80, 1150), "Main lanes: 1,024 wide   /   Jungle: 320 wide   /   River crossing: 512 wide   /   Exact 180-degree terrain symmetry", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("9cb7b1"))
	func _draw_route(points: PackedVector2Array, width: float, color: Color) -> void:
		var projected := PackedVector2Array()
		for point in points: projected.append(offset + point * factor)
		draw_polyline(projected, color, width, true)
		for point in projected: draw_circle(point, width * 0.5, color)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1460, 1180)
	root.content_scale_size = root.size
	var canvas := Overview.new()
	canvas.map = load("res://data/maps/final_decision.tres") as MapDefinition
	root.add_child(canvas)
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://docs/FINAL_DECISION_MAP_OVERVIEW.png")
	print("GROWTH_MAP_RENDER error=", error)
	quit(error)
