class_name WsTerrainArt
extends Node2D
## Static public map geometry only. This node creates NO collision/navigation.
const SHALE := preload("res://assets/warseed/terrain/shale_tile.svg")
const ROAD := preload("res://assets/warseed/terrain/road_tile.svg")
const WILD := preload("res://assets/warseed/terrain/wild_tile.svg")
var world_rect := Rect2(0, 0, 32768, 24576)
var routes: Array[PackedVector2Array] = []
var widths: PackedFloat32Array = PackedFloat32Array()
var supply_pads := PackedVector3Array()
var wild_rects: Array[Rect2] = []

func configure(bounds: Rect2, paths: Array[PackedVector2Array], path_widths: PackedFloat32Array, clearings: Array[Rect2]) -> void:
	assert(paths.size() == path_widths.size())
	world_rect = bounds
	routes = paths.duplicate()
	widths = path_widths.duplicate()
	wild_rects = clearings.duplicate()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(SHALE, world_rect, true)
	for clearing in wild_rects:
		draw_texture_rect(WILD, clearing, true)
	for i in range(routes.size()):
		var path := routes[i]
		if path.size() < 2:
			continue
		# Segment quads + round joins equal the authored corridor widths.
		# Grain UV uses WORLD coordinates so it does not stretch with segment length.
		for j in range(path.size() - 1):
			var a := path[j]
			var b := path[j + 1]
			var side := (b - a).normalized().orthogonal() * widths[i] * 0.5
			var quad := PackedVector2Array([a + side, b + side, b - side, a - side])
			var uv := PackedVector2Array()
			for point in quad:
				uv.append(point / Vector2(256, 256))
			draw_polygon(quad, PackedColorArray([Color.WHITE]), uv, ROAD)
		for point in path:
			_draw_textured_disc(point, widths[i] * 0.5)
	for pad in supply_pads:
		_draw_textured_disc(Vector2(pad.x, pad.y), pad.z)
	# No base/team decorations, blockers or control flags in terrain: fog and
	# authorized strategic overlays remain owned by the host presentation.

func _draw_textured_disc(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for i in range(32):
		var point := center + Vector2.RIGHT.rotated(TAU * float(i) / 32.0) * radius
		points.append(point)
		uv.append(point / Vector2(256, 256))
	draw_polygon(points, PackedColorArray([Color.WHITE]), uv, ROAD)
