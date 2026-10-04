extends Node2D
var current_snapshot: WorldSnapshot
var _combat_effects: Array[Dictionary] = []
var commands: Array = []
func _lookup_unit(snapshot: WorldSnapshot, id: int) -> UnitSnapshot: return snapshot.get_unit(id)
func _lookup_building(snapshot: WorldSnapshot,id: int) -> BuildingSnapshot: return snapshot.get_building(id)
func _record_draw_colored_polygon(points, color): commands.append(["draw_colored_polygon", points, color])
func _record_draw_circle(position, radius, color): commands.append(["draw_circle", position, radius, color])
func _record_draw_arc(position, radius, start_angle, end_angle, count, color, width): commands.append(["draw_arc", position, radius, start_angle, end_angle, count, color, width])
func _record_draw_line(from, to, color, width): commands.append(["draw_line", from, to, color, width])
func _record_draw_rect(rect, color, filled, width = -1.0): commands.append(["draw_rect", rect, color, filled, width])
func _record_draw_string(font, position, text, alignment, width, size, color): commands.append(["draw_string", font, position, text, alignment, width, size, color])

var _effect_label_sizes: Dictionary = {}
var _effect_label_font: Font
var _effect_label_locale := ""
var _effect_rays: Dictionary[int, PackedVector2Array] = {}

func _effect_directions(count: int, seed_id: int = -1) -> PackedVector2Array:
	var key := count if seed_id < 0 else 100 + seed_id % 17
	if not _effect_rays.has(key):
		var points := PackedVector2Array()
		var angle := 0.0 if seed_id < 0 else float(seed_id % 17) * 0.19
		for index in count:
			points.append(Vector2.RIGHT.rotated(angle + float(index) * TAU / float(count)))
		_effect_rays[key] = points
	return _effect_rays[key]


func _draw_combat_effects() -> void:
	var visual_scale := 1.0
	for effect in _combat_effects:
		var duration := float(effect["duration"])
		var progress := clampf(float(effect["elapsed"]) / duration, 0.0, 1.0)
		var position_value := effect["position"] as Vector2
		var kind := effect["kind"] as StringName
		if kind in [&"impact", &"destroyed", &"muzzle"] and current_snapshot != null:
			var effect_id := int(effect["entity_id"])
			var effect_unit := _lookup_unit(current_snapshot, effect_id)
			var effect_building := _lookup_building(current_snapshot, effect_id)
			var legal_unit := effect_unit != null and (effect_unit.faction_id == SimulationWorld.LOCAL_PLAYER_ID or effect_unit.is_visible_to_local_player)
			var legal_building := effect_building != null and (effect_building.faction_id == SimulationWorld.LOCAL_PLAYER_ID or effect_building.is_visible)
			if not legal_unit and not legal_building:
				continue
		var faction_id := int(effect["faction_id"])
		var color := Color("ffd75e") if faction_id == SimulationWorld.LOCAL_PLAYER_ID else Color("ff725f")
		if kind == &"muzzle":
			var direction := effect["direction"] as Vector2
			var perpendicular := direction.orthogonal()
			var length := (22.0 + progress * 12.0) * visual_scale
			var width := (9.0 * (1.0 - progress) + 2.0) * visual_scale
			_record_draw_colored_polygon(PackedVector2Array([
				position_value,
				position_value + direction * length + perpendicular * width,
				position_value + direction * length * 1.45,
				position_value + direction * length - perpendicular * width,
			]), Color(color, 1.0 - progress))
			_record_draw_circle(position_value, (8.0 + progress * 8.0) * visual_scale, Color(1.0, 0.95, 0.7, (1.0 - progress) * 0.7))
		elif kind == &"impact":
			var fade := 1.0 - progress
			_record_draw_circle(position_value, (7.0 + progress * 14.0) * visual_scale, Color(1.0, 0.88, 0.58, fade * 0.65))
			_record_draw_arc(position_value, (10.0 + progress * 24.0) * visual_scale, 0.0, TAU, 28, Color(color, fade), 3.0 * visual_scale)
			for ray in _effect_directions(6):
				_record_draw_line(position_value + ray * 8.0 * visual_scale, position_value + ray * (18.0 + progress * 18.0) * visual_scale, Color(color, fade), 2.0 * visual_scale)
		elif kind == &"engagement":
			var fade := 1.0 - progress
			var radius := (20.0 + progress * 44.0) * visual_scale
			_record_draw_arc(position_value, radius, 0.0, TAU, 36, Color(0.35, 0.95, 0.86, fade), 4.0 * visual_scale)
			for direction in _effect_directions(4):
				_record_draw_line(position_value + direction * (radius - 10.0 * visual_scale), position_value + direction * (radius + 8.0 * visual_scale), Color(0.7, 1.0, 0.94, fade), 4.0 * visual_scale)
		elif kind == &"focus":
			var fade := 1.0 - progress
			_record_draw_arc(position_value, (34.0 - progress * 16.0) * visual_scale, 0.0, TAU, 36, Color(1.0, 0.82, 0.28, fade), 3.0 * visual_scale)
			for direction in _effect_directions(3):
				var outer := position_value + direction * (54.0 - progress * 26.0) * visual_scale
				var inner := position_value + direction * 18.0 * visual_scale
				_record_draw_line(outer, inner, Color(1.0, 0.82, 0.28, fade), 4.0 * visual_scale)
		elif kind == &"pressure":
			var fade := 1.0 - progress
			var radius := (28.0 + sin(progress * TAU * 3.0) * 7.0 + progress * 16.0) * visual_scale
			for segment in range(8):
				var start := float(segment) * TAU / 8.0
				_record_draw_arc(position_value, radius, start, start + TAU / 16.0, 5, Color(1.0, 0.35, 0.22, fade), 4.0 * visual_scale)
		elif kind == &"reinforcement":
			var fade := 1.0 - progress
			var radius := (18.0 + progress * 54.0) * visual_scale
			_record_draw_arc(position_value, radius, 0.0, TAU, 40, Color(0.35, 0.95, 0.72, fade), 4.0 * visual_scale)
			_record_draw_line(position_value + Vector2(0.0, 18.0) * visual_scale, position_value + Vector2(0.0, -18.0) * visual_scale, Color(0.65, 1.0, 0.84, fade), 4.0 * visual_scale)
			_record_draw_line(position_value + Vector2(-18.0, 0.0) * visual_scale, position_value + Vector2(18.0, 0.0) * visual_scale, Color(0.65, 1.0, 0.84, fade), 4.0 * visual_scale)
		elif kind == &"engineering_route":
			var fade := 1.0 - progress * 0.65
			var half_width := (62.0 + progress * 24.0) * visual_scale
			for rail_index in range(3):
				var y_offset := float(rail_index - 1) * 16.0 * visual_scale
				_record_draw_line(position_value + Vector2(-half_width, y_offset), position_value + Vector2(half_width, y_offset), Color(0.28, 0.95, 0.84, fade), 6.0 * visual_scale)
			_record_draw_arc(position_value, (42.0 + progress * 50.0) * visual_scale, 0.0, TAU, 40, Color(0.45, 1.0, 0.9, fade), 4.0 * visual_scale)
		elif kind == &"recon_support":
			var fade := 1.0 - progress
			for ring_index in range(3):
				var ring_progress := fposmod(progress + float(ring_index) / 3.0, 1.0)
				_record_draw_arc(position_value, (24.0 + ring_progress * 96.0) * visual_scale, 0.0, TAU, 48, Color(0.34, 0.9, 1.0, fade), 3.0 * visual_scale)
		elif kind in [&"deployment_started", &"deployment_complete", &"fortify", &"mobility", &"logistics", &"effect_ended", &"supply_node", &"region_secured", &"region_enemy", &"region_contested", &"region_capture", &"capture_interrupted", &"organization", &"withdrawal", &"fire_support"]:
			var fade := 1.0 - progress * 0.75
			var operational_color := Color(0.35, 0.95, 0.72, fade)
			if kind in [&"fire_support", &"region_enemy", &"region_contested", &"organization", &"withdrawal"]:
				operational_color = Color(1.0, 0.52, 0.22, fade)
			elif kind == &"effect_ended":
				operational_color = Color(0.68, 0.72, 0.7, fade)
			_record_draw_arc(position_value, (28.0 + progress * 54.0) * visual_scale, 0.0, TAU, 40, operational_color, 4.0 * visual_scale)
			var marker_size := 22.0 * visual_scale
			_record_draw_line(position_value + Vector2(-marker_size, 0.0), position_value + Vector2(marker_size, 0.0), operational_color, 4.0 * visual_scale)
			_record_draw_line(position_value + Vector2(0.0, -marker_size), position_value + Vector2(0.0, marker_size), operational_color, 4.0 * visual_scale)
		elif kind == &"headquarters":
			var pulse := 0.65 + sin(progress * TAU * 5.0) * 0.25
			var fade := 1.0 - progress * 0.5
			var half_size := (64.0 + progress * 14.0) * visual_scale
			_record_draw_rect(Rect2(position_value - Vector2.ONE * half_size, Vector2.ONE * half_size * 2.0), Color(1.0, 0.22, 0.16, pulse * fade), false, 6.0 * visual_scale)
			_record_draw_line(position_value + Vector2(0.0, -38.0) * visual_scale, position_value + Vector2(0.0, 14.0) * visual_scale, Color(1.0, 0.82, 0.58, fade), 7.0 * visual_scale)
			_record_draw_circle(position_value + Vector2(0.0, 30.0) * visual_scale, 5.0 * visual_scale, Color(1.0, 0.82, 0.58, fade))
		else:
			var fade := 1.0 - progress
			_record_draw_circle(position_value, (12.0 + progress * 30.0) * visual_scale, Color(1.0, 0.42, 0.12, fade * 0.42))
			_record_draw_arc(position_value, (18.0 + progress * 46.0) * visual_scale, 0.0, TAU, 36, Color(1.0, 0.72, 0.2, fade), 4.0 * visual_scale)
			for shard in _effect_directions(8, int(effect["entity_id"])):
				_record_draw_line(position_value + shard * 10.0 * visual_scale, position_value + shard * (24.0 + progress * 48.0) * visual_scale, Color(color, fade), 3.0 * visual_scale)
		_draw_effect_label(effect, position_value, progress, visual_scale)


func _draw_effect_label(effect: Dictionary, position_value: Vector2, progress: float, visual_scale: float) -> void:
	var label_key := effect.get("label_key", &"") as StringName
	if label_key.is_empty():
		return
	var text_value := GameText.t(label_key)
	var font := ThemeDB.fallback_font
	var font_size := maxi(18, roundi(18.0 * visual_scale))
	var locale := TranslationServer.get_locale()
	if font != _effect_label_font or locale != _effect_label_locale:
		_effect_label_sizes.clear()
		_effect_label_font = font
		_effect_label_locale = locale
	var size_key := [text_value, font_size]
	if not _effect_label_sizes.has(size_key):
		_effect_label_sizes[size_key] = font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_size: Vector2 = _effect_label_sizes[size_key]
	var label_center := position_value + Vector2(0.0, -78.0 * visual_scale)
	var padding := Vector2(12.0, 7.0) * visual_scale
	var label_rect := Rect2(label_center - Vector2(text_size.x * 0.5, text_size.y) - padding, text_size + padding * 2.0)
	var fade := clampf((1.0 - progress) * 1.7, 0.0, 1.0)
	_record_draw_rect(label_rect, Color(0.025, 0.04, 0.04, 0.86 * fade), true)
	_record_draw_rect(label_rect, Color(0.44, 0.9, 0.78, fade), false, maxf(2.0, 2.0 * visual_scale))
	_record_draw_string(font, Vector2(label_rect.position.x + padding.x, label_rect.end.y - padding.y), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.93, 1.0, 0.96, fade))
