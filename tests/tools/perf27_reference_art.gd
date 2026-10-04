extends Node2D
## Two textured MultiMeshes per faction / definition, bulk 16-float buffer.
## No world/simulation reference, no camera scaling, no per-unit child nodes.
const STRIDE := 16
const FLASH_SHADER := preload("res://src/presentation/art/ws_art_flash.gdshader")
var _buffers: Dictionary = {}
var _groups: Dictionary = {}
var _feedback: Dictionary = {}
var _poses: Array[WsArtPose] = []

func advance(delta: float) -> void:
	for id in _feedback.keys():
		var timers: Vector2 = _feedback[id]
		timers.x = maxf(0.0, timers.x - delta)
		timers.y = maxf(0.0, timers.y - delta)
		if timers == Vector2.ZERO:
			_feedback.erase(id)
		else:
			_feedback[id] = timers

func fire(entity_id: int) -> void:
	var timers: Vector2 = _feedback.get(entity_id, Vector2.ZERO)
	timers.x = WsArtLibrary.FIRE_SECONDS
	_feedback[entity_id] = timers

func hit(entity_id: int) -> void:
	var timers: Vector2 = _feedback.get(entity_id, Vector2.ZERO)
	timers.y = WsArtLibrary.HIT_SECONDS
	_feedback[entity_id] = timers

func reset() -> void:
	_feedback.clear()
	submit([])

func submit(poses: Array[WsArtPose]) -> void:
	_poses = poses
	var members: Dictionary = {}
	var active: Dictionary = {}
	for pose in poses:
		active[pose.entity_id] = true
		if pose.contact_only:
			_feedback.erase(pose.entity_id)
			continue
		var id := pose.definition_id if pose.definition_id in WsArtLibrary.IDS else &"fallback"
		var key := "%s:%s" % ["blue" if pose.blue else "red",id]
		if not members.has(key):
			members[key] = []
			_ensure_group(key,id,pose.blue)
		members[key].append(pose)
	for id in _feedback.keys():
		if not active.has(id): _feedback.erase(id)
	for key in _groups:
		var rows: Array = members.get(key,[])
		var pair: Array = _groups[key]
		var body := pair[0] as MultiMeshInstance2D
		var weapon := pair[1] as MultiMeshInstance2D
		body.visible = not rows.is_empty()
		weapon.visible = body.visible
		if body.multimesh.instance_count != rows.size():
			body.multimesh.instance_count = rows.size()
			weapon.multimesh.instance_count = rows.size()
		if rows.is_empty(): continue
		var body_key := "%s:0" % key
		var weapon_key := "%s:1" % key
		var body_data := _initialized_buffer(body_key,rows.size())
		var weapon_data := _initialized_buffer(weapon_key,rows.size())
		var bounds := Rect2((rows[0] as WsArtPose).position,Vector2.ZERO)
		for index in range(rows.size()):
			var pose := rows[index] as WsArtPose
			bounds = bounds.expand(pose.position)
			var timers: Vector2 = _feedback.get(pose.entity_id,Vector2.ZERO)
			var at := pose.position - Vector2.RIGHT.rotated(pose.heading)*WsArtLibrary.recoil(timers.x)
			var o := index*STRIDE
			var c := cos(pose.heading)
			var s := sin(pose.heading)
			var deploy := pose.deployment_progress if pose.definition_id in [&"missile_vehicle",&"legion_hero"] else 0.0
			var scale_x := 1.0-deploy*0.35
			var scale_y := 1.0+deploy*0.5
			body_data[o] = c
			body_data[o+1] = -s
			body_data[o+3] = pose.position.x
			body_data[o+4] = s
			body_data[o+5] = c
			body_data[o+7] = pose.position.y
			weapon_data[o] = c*scale_x
			weapon_data[o+1] = -s*scale_y
			weapon_data[o+3] = at.x
			weapon_data[o+4] = s*scale_x
			weapon_data[o+5] = c*scale_y
			weapon_data[o+7] = at.y
			weapon_data[o+11] = 1.0 if pose.enabled else 0.0
			var flash := clampf(timers.y/WsArtLibrary.HIT_SECONDS,0.0,1.0)
			var wreck := 0.0 if pose.enabled else 1.0
			body_data[o+12] = flash
			weapon_data[o+12] = flash
			body_data[o+13] = wreck
			weapon_data[o+13] = wreck
		_buffers[body_key] = body_data
		_buffers[weapon_key] = weapon_data
		body.multimesh.set_buffer(body_data)
		weapon.multimesh.set_buffer(weapon_data)
		bounds = bounds.grow(WsArtLibrary.UNIT_RECT.size.length())
		var box := AABB(Vector3(bounds.position.x,bounds.position.y,-1.0),Vector3(bounds.size.x,bounds.size.y,2.0))
		body.multimesh.custom_aabb = box
		weapon.multimesh.custom_aabb = box
	queue_redraw()

func _initialized_buffer(key: String,count: int) -> PackedFloat32Array:
	var buffer: PackedFloat32Array = _buffers.get(key,PackedFloat32Array())
	if buffer.size() != count*STRIDE:
		buffer.resize(count*STRIDE)
		for i in range(count):
			var o := i*STRIDE
			buffer[o+8] = 1.0
			buffer[o+9] = 1.0
			buffer[o+10] = 1.0
			buffer[o+11] = 1.0
			buffer[o+15] = 1.0
	return buffer

func _ensure_group(key: String, id: StringName, blue: bool) -> void:
	if _groups.has(key):
		return
	var pair: Array[MultiMeshInstance2D] = []
	for layer in range(2):
		var batch := MultiMeshInstance2D.new()
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_2D
		mesh.use_colors = true
		mesh.use_custom_data = true
		var quad := QuadMesh.new()
		quad.size = WsArtLibrary.UNIT_RECT.size
		mesh.mesh = quad
		batch.multimesh = mesh
		batch.texture = WsArtLibrary.texture_for(id, blue, layer == 1)
		var material_value := ShaderMaterial.new()
		material_value.shader = FLASH_SHADER
		batch.material = material_value
		batch.z_index = layer
		add_child(batch)
		pair.append(batch)
	_groups[key] = pair

func _draw() -> void:
	for pose in _poses:
		draw_set_transform(pose.position, pose.heading)
		if pose.contact_only:
			var tint := Color(0.95, 0.68, 0.28, clampf(pose.intel_freshness, 0.18, 1.0) * 0.62)
			for segment in range(8):
				var start := float(segment) * TAU / 8.0
				draw_arc(Vector2.ZERO, 24, start, start + TAU / 16.0, 5, tint, 2.0)
			draw_polyline(PackedVector2Array([Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0), Vector2(0, -12)]), tint, 2.0)
		elif pose.enabled:
			if pose.definition_id in [&"missile_vehicle", &"legion_hero"]: WsArtLibrary.draw_deployment(self, pose.deployment_progress, pose.blue)
			var timers: Vector2 = _feedback.get(pose.entity_id, Vector2.ZERO)
			if timers.x > 0.0:
				WsArtLibrary.draw_muzzle(self, timers.x, pose.blue)
	draw_set_transform(Vector2.ZERO)

func debug_visible_instance_count() -> int:
	var count := 0
	for pair: Array in _groups.values():
		count += (pair[0] as MultiMeshInstance2D).multimesh.instance_count
	return count
