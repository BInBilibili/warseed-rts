class_name StrategicUnitOverlay
extends Node2D

var snapshot: WorldSnapshot
var selected_ids: Array[int] = []
var _markers: Array[MinimapMarkerProjector.Marker] = []
var _last_zoom := -1.0

func set_snapshot(value: WorldSnapshot, selected: Array[int]) -> void:
	snapshot = value
	selected_ids.assign(selected)
	_markers = MinimapMarkerProjector.new().project(value, selected)
	queue_redraw()

func _process(_delta: float) -> void:
	var camera_zoom := get_canvas_transform().get_scale().x
	if not is_equal_approx(camera_zoom, _last_zoom):
		_last_zoom = camera_zoom
		queue_redraw()

func _draw() -> void:
	var camera_zoom := maxf(0.001, get_canvas_transform().get_scale().x)
	if snapshot == null or snapshot.navigation_map_id.is_empty() or camera_zoom >= 0.65:
		return
	var inverse := Vector2.ONE / camera_zoom
	var transform := get_canvas_transform()
	var screen := get_viewport_rect().grow(40.0)
	for marker in _markers:
		if not screen.has_point(transform * marker.position):
			continue
		if marker.remembered:
			continue # Memory is already shown as uncertain intelligence, not a live army.
		var color := Color("51c5ed") if marker.faction_id == snapshot.observer_faction_id else Color("f27a61")
		if marker.kind == &"legion":
			draw_set_transform(marker.position, 0.0, inverse)
			draw_rect(Rect2(-12, -12, 24, 24), Color("071318"))
			draw_rect(Rect2(-12, -12, 24, 24), Color.WHITE if marker.selected else color, false, 2)
			draw_string(ThemeDB.fallback_font, Vector2(-8, 7), GameText.t(StringName(marker.label)), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color)
			if marker.warning > 0: draw_arc(Vector2.ZERO, 17, 0, TAU, 24, Color("ff5048") if marker.warning == 2 else Color("ffd64b"), 2.5)
			continue
		var shape := PackedVector2Array()
		match marker.kind:
			&"headquarters":
				shape = PackedVector2Array([Vector2(-8, 6), Vector2(-8, -2), Vector2(-4, -2), Vector2(-4, -7), Vector2(4, -7), Vector2(4, -2), Vector2(8, -2), Vector2(8, 6)])
			&"scout_vehicle":
				shape = PackedVector2Array([Vector2(0, -7), Vector2(6, 0), Vector2(0, 7), Vector2(-6, 0)])
			&"missile_vehicle":
				shape = PackedVector2Array([Vector2(0, -7), Vector2(7, 6), Vector2(-7, 6)])
			&"tank", &"building":
				shape = PackedVector2Array([Vector2(-7, -5), Vector2(7, -5), Vector2(7, 5), Vector2(-7, 5)])
			_:
				shape = PackedVector2Array([Vector2(0, -7), Vector2(7, 6), Vector2(0, 2), Vector2(-7, 6)])
		draw_set_transform(marker.position, 0.0, inverse)
		draw_colored_polygon(shape, Color("071318"))
		shape.append(shape[0])
		draw_polyline(shape, Color.WHITE if marker.selected else color, 2.0, true)
		if marker.kind == &"missile_vehicle":
			draw_line(Vector2.ZERO, Vector2(0, -10), color, 2.0)
		if marker.observed_count > 0 and camera_zoom >= 0.08:
			draw_rect(Rect2(9, -7, 23, 15), Color(0.015, 0.025, 0.03, 0.85))
			draw_string(ThemeDB.fallback_font, Vector2(11, 5), str(marker.observed_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	draw_set_transform(Vector2.ZERO)
