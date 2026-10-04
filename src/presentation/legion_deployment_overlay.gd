class_name LegionDeploymentOverlay
extends Node2D

enum Marker { SOLDIER, COMMANDER, FIREPOWER }
var markers := PackedInt32Array()
var standard := PackedVector2Array()
var actual := PackedVector2Array()
var anchor := Vector2.ZERO
var facing := Vector2.RIGHT
var status := 3
var spacing := 48.0
var uncertain := false

func set_preview(standard_points: PackedVector2Array, actual_points: PackedVector2Array, origin: Vector2, forward: Vector2, new_status: int, new_spacing: float, unknown: bool = false, point_markers: PackedInt32Array = PackedInt32Array()) -> void:
	standard=standard_points.duplicate(); actual=actual_points.duplicate()
	markers=point_markers.duplicate()
	anchor=origin; facing=forward.normalized(); status=new_status; spacing=new_spacing; uncertain=unknown
	queue_redraw()

func clear_preview() -> void:
	standard.clear(); actual.clear(); markers.clear(); queue_redraw()

func _hull(points: PackedVector2Array) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for point in points:
		for offset in [Vector2(-32,-32),Vector2(32,-32),Vector2(32,32),Vector2(-32,32)]: corners.append(point+offset)
	return Geometry2D.convex_hull(corners) if corners.size()>2 else corners

func _draw() -> void:
	if standard.is_empty(): return
	var colors: Array[Color] = [Color("65d98a"),Color("f2d663"),Color("ff9d50"),Color("f06d6d")]
	var color := Color("a7b1bc") if uncertain else colors[clampi(status,0,3)]
	var ghost := _hull(standard)
	for index in range(1,ghost.size()): draw_dashed_line(ghost[index-1],ghost[index],Color(0.7,0.8,0.8,0.6),2.0,12.0)
	var points := actual if not actual.is_empty() else standard
	var hull := _hull(points)
	if hull.size()>2: draw_polyline(hull,color,3.0,true)
	var minimum := Vector2(INF,INF); var maximum := Vector2(-INF,-INF)
	for index in range(points.size()):
		var point := points[index]
		draw_arc(point,32.0,0,TAU,16,Color(color,0.2),1.0,true)
		var marker := markers[index] if index<markers.size() else Marker.SOLDIER
		match marker:
			Marker.COMMANDER:
				draw_polyline(PackedVector2Array([point+Vector2(0,-12),point+Vector2(12,0),point+Vector2(0,12),point+Vector2(-12,0),point+Vector2(0,-12)]),color,3.0,true)
			Marker.FIREPOWER:
				draw_rect(Rect2(point-Vector2(9,9),Vector2(18,18)),color,false,3.0,true)
			_:
				if index%2==0: draw_circle(point,4.0,color)
		var offset := point-anchor
		var projection := Vector2(offset.dot(facing),offset.dot(facing.orthogonal()))
		minimum=minimum.min(projection); maximum=maximum.max(projection)
	var end := anchor+facing*96.0
	draw_line(anchor,end,color,3.0,true)
	draw_line(end,end-facing.rotated(0.5)*24,color,3.0,true)
	draw_line(end,end-facing.rotated(-0.5)*24,color,3.0,true)
	if status==3: draw_line(anchor-Vector2(48,48),anchor+Vector2(48,48),color,4.0,true)
	var keys: Array[StringName] = [&"DEPLOYMENT_STANDARD",&"DEPLOYMENT_COMPRESSED",&"DEPLOYMENT_TRANSIT_ONLY",&"DEPLOYMENT_NO_SPACE"]
	var label := GameText.t(&"DEPLOYMENT_UNCERTAIN" if uncertain else keys[clampi(status,0,3)])
	var size := maximum-minimum+Vector2.ONE*64.0
	label+="  %d  %.0f×%.0f  ↔%.0f" % [points.size(),size.y,size.x,spacing]
	var text_position := anchor+Vector2(-160,-160)
	for point in hull: text_position.y=minf(text_position.y,point.y-24.0)
	draw_string(ThemeDB.fallback_font,text_position,label,HORIZONTAL_ALIGNMENT_LEFT,-1,22,color)
	draw_string(ThemeDB.fallback_font,text_position+Vector2(0,28),GameText.t(&"REFORMATION_DAMAGE_HINT"),HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
