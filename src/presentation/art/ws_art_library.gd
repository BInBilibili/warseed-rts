class_name WsArtLibrary
extends RefCounted
## Original vector art. All rectangles are WORLD units; never divide by camera zoom.
const IDS: Array[StringName] = [&"scout_vehicle", &"assault_vehicle", &"missile_vehicle", &"engineer_vehicle", &"supply_truck", &"legion_hero"]
const UNIT_RECT := Rect2(-32, -24, 64, 48)
const HQ_RECT := Rect2(-64, -48, 128, 96)
const FIRE_SECONDS := 0.16
const HIT_SECONDS := 0.18
static var _muzzle_points := PackedVector2Array([Vector2(26, -2), Vector2(36, -6), Vector2(45, 0), Vector2(36, 6), Vector2(26, 2)])
static var _textures: Dictionary = {}

static func texture_for(definition_id: StringName, blue: bool, weapon: bool = false) -> Texture2D:
	var side := "blue" if blue else "red"
	var id := String(definition_id) if definition_id in IDS else "fallback"
	var path := "res://assets/warseed/units/%s_%s_%s.svg" % [side, id, "weapon" if weapon else "body"]
	return _texture(path)

static func headquarters_texture(blue: bool) -> Texture2D:
	return _texture("res://assets/warseed/buildings/%s_command_center.svg" % ("blue" if blue else "red"))

static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	return _textures[path] as Texture2D

static func recoil(fire_remaining: float) -> float:
	return 3.0 * clampf(fire_remaining / FIRE_SECONDS, 0.0, 1.0)

static func draw_unit(canvas: CanvasItem, definition_id: StringName, blue: bool, fire_remaining: float = 0.0, heading: float = 0.0, deployment: float = 0.0) -> void:
	canvas.draw_set_transform(Vector2.ZERO, heading)
	canvas.draw_texture_rect(texture_for(definition_id, blue), UNIT_RECT, false)
	var weapon_rect := UNIT_RECT
	if definition_id in [&"missile_vehicle", &"legion_hero"]:
		draw_deployment(canvas, deployment, blue)
		weapon_rect.size *= Vector2(1.0 - deployment * 0.35, 1.0 + deployment * 0.5)
		weapon_rect.position = -weapon_rect.size * 0.5
	weapon_rect.position.x -= recoil(fire_remaining)
	canvas.draw_texture_rect(texture_for(definition_id, blue, true), weapon_rect, false)
	if fire_remaining > 0.0:
		draw_muzzle(canvas, fire_remaining, blue)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_muzzle(canvas: CanvasItem, remaining: float, blue: bool) -> void:
	var alpha := clampf(remaining / FIRE_SECONDS, 0.0, 1.0)
	var tint := Color("b8faff") if blue else Color("ffd28a")
	tint.a = alpha
	canvas.draw_colored_polygon(_muzzle_points, tint)
	canvas.draw_line(Vector2(28, 0), Vector2(39, 0), Color(1, 1, 0.93, alpha), 2.0)

static func draw_headquarters(canvas: CanvasItem, blue: bool) -> void:
	# Opaque footprint stays inside the existing 110 x 82 building envelope.
	canvas.draw_texture_rect(headquarters_texture(blue), HQ_RECT, false)

static func draw_deployment(canvas: CanvasItem, progress: float, blue: bool) -> void:
	if progress <= 0.01: return
	var tint := Color("76dcf5") if blue else Color("f4aa65")
	for side in [-1.0, 1.0]:
		for front in [-1.0, 1.0]:
			var foot := Vector2(front * 22, side * (14 + progress * 18))
			canvas.draw_line(Vector2(front * 15, side * 10), foot, Color("465860"), 5)
			canvas.draw_line(foot + Vector2(-5, 0), foot + Vector2(5, 0), tint, 3)
	canvas.draw_arc(Vector2.ZERO, 34, -PI * 0.5, -PI * 0.5 + TAU * progress, 24, Color(tint, 0.65), 1.5)
