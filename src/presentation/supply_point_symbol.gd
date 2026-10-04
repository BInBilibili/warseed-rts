class_name SupplyPointSymbol
extends RefCounted

# Public node category, shared by the strategic map and world overlay. Ownership
# tint is supplied by the legal snapshot, never by the initial map owner.
static func draw_on(canvas: CanvasItem, center: Vector2, tier: int, radius: float, color: Color, line_width: float) -> void:
	var shape := PackedVector2Array()
	match tier:
		MapSupplyPointDefinition.Tier.HIGH_GROUND:
			for i in range(6):
				shape.append(Vector2.RIGHT.rotated(TAU * float(i) / 6.0) * radius)
		MapSupplyPointDefinition.Tier.INNER:
			shape = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
		MapSupplyPointDefinition.Tier.OUTER:
			shape = PackedVector2Array([Vector2(0, -1.25), Vector2(1, 0.7), Vector2(-1, 0.7)])
		MapSupplyPointDefinition.Tier.JUNGLE_SMALL, MapSupplyPointDefinition.Tier.JUNGLE_LARGE:
			shape = PackedVector2Array([Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)])
		_:
			canvas.draw_circle(center, radius, Color(color, 0.25))
			canvas.draw_circle(center, radius, color, false, line_width)
			return
	for i in range(shape.size()):
		shape[i] = center + shape[i] * (1.0 if tier == MapSupplyPointDefinition.Tier.HIGH_GROUND else radius)
	canvas.draw_colored_polygon(shape, Color(0.025, 0.04, 0.045, 0.94))
	shape.append(shape[0])
	canvas.draw_polyline(shape, color, line_width, true)
	if tier in [MapSupplyPointDefinition.Tier.HIGH_GROUND, MapSupplyPointDefinition.Tier.JUNGLE_LARGE]:
		canvas.draw_circle(center, radius * 0.35, color)
