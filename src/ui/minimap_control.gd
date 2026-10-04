class_name MinimapControl
extends Control

const WORLD_RECT := SimulationWorld.BATTLEFIELD_BOUNDS

var snapshot: WorldSnapshot
var camera_controller: CameraController
var selected_entity_ids: Array[int] = []
var logic_grid := LogicGrid.create_test_map()
var dragging_camera: bool = false
var _contact_pings: Array[Dictionary] = []
var _last_camera_rect := Rect2()
var world_rect: Rect2 = WORLD_RECT
var situation: BattlefieldSituationSnapshot
var show_frontlines := false
var show_tasks := true
var show_threats := true
var show_intelligence := true
var _terrain_grid: LogicGrid
var _terrain_revision := -1
var _terrain_texture: ImageTexture
var expanded_view := false
var _expanded_popup: PopupPanel
var _expanded_map: MinimapControl
var _expand_button: Button

var _legion_markers: Array[MinimapMarkerProjector.Marker] = []
var _warning_levels: Dictionary = {}
var _last_sound_tick := -1000
var _warning_player: AudioStreamPlayer

const CONTACT_PING_DURATION := 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)
	if not expanded_view:
		_expand_button = Button.new()
		_expand_button.text = "⛶"
		_expand_button.tooltip_text = GameText.t(&"MINIMAP_EXPAND")
		_expand_button.custom_minimum_size = Vector2(28, 24)
		add_child(_expand_button)
		_expand_button.pressed.connect(open_expanded)


func _process(delta: float) -> void:
	var needs_redraw := false
	for ping in _contact_pings:
		ping["remaining"] = float(ping["remaining"]) - delta
		needs_redraw = true
	_contact_pings = _contact_pings.filter(func(ping: Dictionary) -> bool: return float(ping["remaining"]) > 0.0)
	if camera_controller != null:
		var camera_rect := camera_controller.get_visible_world_rect()
		if camera_rect != _last_camera_rect:
			_last_camera_rect = camera_rect
			needs_redraw = true
	if needs_redraw:
		queue_redraw()


func add_contact_ping(world_position: Vector2) -> void:
	_contact_pings.append({"position": world_position, "remaining": CONTACT_PING_DURATION})
	queue_redraw()


func get_contact_ping_count() -> int:
	return _contact_pings.size()


func set_state(
	new_snapshot: WorldSnapshot,
	new_camera_controller: CameraController,
	new_selected_entity_ids: Array[int]
) -> void:
	if snapshot != null and new_snapshot != null and new_snapshot.tick < snapshot.tick:
		_warning_levels.clear()
		_last_sound_tick = -1000
	snapshot = new_snapshot
	camera_controller = new_camera_controller
	selected_entity_ids = new_selected_entity_ids.duplicate()
	_legion_markers = MinimapMarkerProjector.new().project(snapshot, selected_entity_ids)
	_update_warning_audio()
	if _expanded_map != null and _expanded_popup.visible:
		_expanded_map.set_state(snapshot, camera_controller, selected_entity_ids)
		_expanded_map.set_situation(situation)
	queue_redraw()


func set_world_rect(value: Rect2) -> void:
	world_rect = value if value.size.x > 0.0 and value.size.y > 0.0 else WORLD_RECT
	queue_redraw()


func set_situation(new_situation: BattlefieldSituationSnapshot) -> void:
	situation = new_situation
	queue_redraw()


func set_layer_visibility(frontlines: bool, tasks: bool, threats: bool, intelligence: bool) -> void:
	show_frontlines = false # Frontline design removed; signature retained for compatibility.
	show_tasks = tasks
	show_threats = threats
	show_intelligence = intelligence
	queue_redraw()


func get_content_rect() -> Rect2:
	var world_aspect := world_rect.size.x / world_rect.size.y
	var control_aspect := size.x / size.y if size.y > 0.0 else world_aspect
	var content_size := size
	if control_aspect > world_aspect:
		content_size.x = size.y * world_aspect
	else:
		content_size.y = size.x / world_aspect
	return Rect2((size - content_size) * 0.5, content_size)


func world_to_minimap(world_position: Vector2) -> Vector2:
	var content := get_content_rect()
	var normalized := (world_position - world_rect.position) / world_rect.size
	return content.position + normalized * content.size


func minimap_to_world(local_position: Vector2) -> Vector2:
	var content := get_content_rect()
	var clamped := local_position.clamp(content.position, content.end)
	var normalized := (clamped - content.position) / content.size
	return world_rect.position + normalized * world_rect.size


func navigate_camera(local_position: Vector2) -> void:
	if camera_controller != null:
		camera_controller.center_on_world_position(minimap_to_world(local_position))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			dragging_camera = mouse.pressed
			if mouse.pressed:
				navigate_camera(mouse.position)
			accept_event()
	elif event is InputEventMouseMotion and dragging_camera:
		navigate_camera((event as InputEventMouseMotion).position)
		accept_event()


func _draw() -> void:
	var content := get_content_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.035, 0.04, 0.94), true)
	draw_rect(content, Color("162326"), true)
	_update_terrain_texture()
	var terrain_origin := logic_grid.cell_to_world(Vector2i.ZERO) - Vector2.ONE * LogicGrid.CELL_SIZE * 0.5
	var terrain_start := world_to_minimap(terrain_origin)
	var terrain_end := world_to_minimap(terrain_origin + Vector2(logic_grid.grid_size) * LogicGrid.CELL_SIZE)
	draw_texture_rect(_terrain_texture, Rect2(terrain_start, terrain_end - terrain_start), false)
	if snapshot != null:
		for region in snapshot.strategic_regions:
			if not region.capturable:
				continue
			var region_color := Color("7f898e")
			if region.contested:
				region_color = Color("f3c44e")
			elif region.controller_faction_id == SimulationWorld.LOCAL_PLAYER_ID:
				region_color = Color("3b8eea")
			elif region.controller_faction_id != 0:
				region_color = Color("d95c5c")
			var point := world_to_minimap(region.position)
			if expanded_view and snapshot.growth_mode:
				draw_string(ThemeDB.fallback_font, point + Vector2(8,-8), "+%d/20s" % region.supply_per_settlement, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e4c96f"))
			var node_size := 4.0 if region.supply_tier == MapSupplyPointDefinition.Tier.JUNGLE_SMALL else 6.0
			SupplyPointSymbol.draw_on(self, point, region.supply_tier, node_size, region_color, 1.5)
			if region.capture_faction_id != 0 and region.capture_faction_id != region.controller_faction_id and region.capture_progress > 0.0:
				var capture_color := Color("3b8eea") if region.capture_faction_id == SimulationWorld.LOCAL_PLAYER_ID else Color("d95757")
				draw_arc(point, 8.5, -PI * 0.5, -PI * 0.5 + TAU * region.capture_progress, 24, capture_color, 2.5)
		for marker in _legion_markers:
			_draw_marker(marker)
	_draw_situation()
	for ping in _contact_pings:
		var progress := 1.0 - float(ping["remaining"]) / CONTACT_PING_DURATION
		var radius := lerpf(4.0, 16.0, progress)
		var alpha := 1.0 - progress
		draw_arc(world_to_minimap(ping["position"]), radius, 0.0, TAU, 32, Color(1.0, 0.76, 0.2, alpha), 2.0)
	if camera_controller != null:
		var camera_rect := camera_controller.get_visible_world_rect().intersection(world_rect)
		var camera_start := world_to_minimap(camera_rect.position)
		var camera_end := world_to_minimap(camera_rect.end)
		draw_rect(Rect2(camera_start, camera_end - camera_start), Color(0.96, 0.84, 0.38, 0.95), false, 1.5)
	draw_rect(content, Color("91a9ad"), false, 2.0)


func _update_terrain_texture() -> void:
	if _terrain_grid == logic_grid and _terrain_revision == logic_grid.revision:
		return
	var terrain := Image.create(logic_grid.grid_size.x, logic_grid.grid_size.y, false, Image.FORMAT_RGBA8)
	terrain.fill(Color.TRANSPARENT)
	var rows := logic_grid.blocked_row_spans()
	for y in range(rows.size()):
		var spans := rows[y]
		for index in range(0,spans.size(),2):
			terrain.fill_rect(Rect2i(spans[index],y,spans[index+1],1),Color("53676b"))
	_terrain_texture = ImageTexture.create_from_image(terrain)
	_terrain_grid = logic_grid
	_terrain_revision = logic_grid.revision


func _draw_situation() -> void:
	if situation == null:
		return
	if show_intelligence:
		for zone in situation.uncertainty_zones:
			if int(zone["state"]) != FactionKnowledge.CellState.UNEXPLORED:
				continue
			var world_zone := zone["rect"] as Rect2
			var top_left := world_to_minimap(world_zone.position)
			var bottom_right := world_to_minimap(world_zone.end)
			draw_rect(Rect2(top_left, bottom_right - top_left), Color(0.01, 0.018, 0.02, 0.16), true)
	if show_tasks:
		for axis in situation.task_axes:
			var route := axis["route"] as PackedVector2Array
			var points := PackedVector2Array()
			for world_point in route:
				points.append(world_to_minimap(world_point))
			if points.size() >= 2:
				draw_polyline(points, Color("52d1c8"), 1.5)
	if show_frontlines:
		for segment in situation.frontline_segments:
			draw_line(world_to_minimap(segment["start"]), world_to_minimap(segment["end"]), Color("f1c75b"), 2.0)
	if show_threats:
		for threat in situation.threat_zones:
			var point := world_to_minimap(threat["position"])
			var radius := maxf(4.0, float(threat["radius"]) / world_rect.size.x * get_content_rect().size.x)
			var color := Color("ef6758") if bool(threat["known_threat"]) else Color("9aa7a2")
			draw_circle(point, radius, Color(color, 0.12))
			draw_arc(point, radius, 0.0, TAU, 20, Color(color, 0.8), 1.5)


func _draw_marker(marker: MinimapMarkerProjector.Marker) -> void:
	var point := world_to_minimap(marker.position)
	if marker.kind == &"legion":
		var tint := Color("51c5ed") if marker.faction_id == snapshot.observer_faction_id else Color("f27a61")
		draw_rect(Rect2(point - Vector2(10, 10), Vector2(20, 20)), Color("071318"))
		draw_rect(Rect2(point - Vector2(10, 10), Vector2(20, 20)), Color.WHITE if marker.selected else tint, false, 1.5)
		draw_string(ThemeDB.fallback_font, point + Vector2(-7, 6), GameText.t(StringName(marker.label)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint)
		if marker.warning > 0:
			draw_arc(point, 14, 0, TAU, 24, Color("ff5048") if marker.warning == 2 else Color("ffd64b"), 2.5)
		return
	var color := Color("51c5ed") if marker.faction_id == snapshot.observer_faction_id else Color("f27a61")
	if marker.remembered:
		color.a = 0.42
	var shape := PackedVector2Array()
	match marker.kind:
		&"headquarters":
			shape = PackedVector2Array([Vector2(-7, 6), Vector2(-7, -3), Vector2(-4, -3), Vector2(-4, -7), Vector2(4, -7), Vector2(4, -3), Vector2(7, -3), Vector2(7, 6)])
		&"scout_vehicle":
			shape = PackedVector2Array([Vector2(0, -6), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0)])
		&"tank", &"building":
			shape = PackedVector2Array([Vector2(-5, -4), Vector2(5, -4), Vector2(5, 4), Vector2(-5, 4)])
		&"missile_vehicle":
			shape = PackedVector2Array([Vector2(0, -6), Vector2(6, 5), Vector2(-6, 5)])
		_:
			shape = PackedVector2Array([Vector2(0, -5), Vector2(5, 4), Vector2(0, 1), Vector2(-5, 4)])
	for i in range(shape.size()):
		shape[i] += point
	if not marker.remembered:
		draw_colored_polygon(shape, Color(0.015, 0.025, 0.03, 0.95))
	shape.append(shape[0])
	draw_polyline(shape, color, 2.0)
	if marker.kind == &"missile_vehicle":
		draw_line(point, point + Vector2(3, -8), color, 2.0)
	if marker.selected:
		draw_arc(point, 9.0, 0, TAU, 20, Color.WHITE, 2.0)


func open_expanded() -> void:
	if expanded_view:
		return
	if _expanded_popup == null:
		_expanded_popup = PopupPanel.new()
		add_child(_expanded_popup)
		var layout := VBoxContainer.new()
		_expanded_popup.add_child(layout)
		_expanded_map = MinimapControl.new()
		_expanded_map.expanded_view = true
		_expanded_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
		layout.add_child(_expanded_map)
		var legend := Label.new()
		legend.name = "Legend"
		legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		layout.add_child(legend)
		var close := Button.new()
		close.name = "Close"
		close.pressed.connect(_expanded_popup.hide)
		layout.add_child(close)
	var viewport_size := get_viewport_rect().size
	var extent := Vector2i(minf(1000, viewport_size.x - 32), minf(800, viewport_size.y - 32))
	_expanded_popup.min_size = Vector2i.ZERO
	_expanded_popup.max_size = extent
	var layout := _expanded_popup.get_child(0) as VBoxContainer
	layout.custom_minimum_size = Vector2(extent)
	(layout.get_node("Legend") as Label).text = GameText.t(&"MINIMAP_LEGEND")
	(layout.get_node("Close") as Button).text = GameText.t(&"MINIMAP_CLOSE")
	_expanded_map.logic_grid = logic_grid
	_expanded_map.set_world_rect(world_rect)
	_expanded_map.set_state(snapshot, camera_controller, selected_entity_ids)
	_expanded_map.set_situation(situation)
	_expanded_popup.popup_centered(extent)

func _get_tooltip(at_position: Vector2) -> String:
	if snapshot == null or not snapshot.growth_mode: return ""
	for region in snapshot.strategic_regions:
		if world_to_minimap(region.position).distance_to(at_position) <= 14.0:
			var amount := region.supply_per_settlement if region.capturable else 12
			return "%s\n+%d / 20s (%.2f / s)\n%s" % [GameText.t(region.display_name_key), amount, amount / 20.0, GameText.t(&"MAP_REGION_CONTESTED") if region.contested else GameText.t(&"GROWTH_POINT_INCOME")]
	return ""

func _update_warning_audio() -> void:
	if expanded_view or snapshot == null or not snapshot.growth_mode: return
	var highest := 0
	for marker in _legion_markers:
		if marker.faction_id != snapshot.observer_faction_id: continue
		if marker.warning > int(_warning_levels.get(marker.label, 0)): highest = maxi(highest, marker.warning)
		_warning_levels[marker.label] = marker.warning
	if highest == 0 or snapshot.tick - _last_sound_tick < 30: return
	_last_sound_tick = snapshot.tick
	if _warning_player == null:
		_warning_player = AudioStreamPlayer.new()
		_warning_player.volume_db = -15
		add_child(_warning_player)
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(6615 * 2)
	for i in range(6615):
		var time := float(i) / 22050.0
		var envelope := sin(PI * time / 0.3)
		var frequency := 880.0 if highest == 2 else 560.0
		var value := int(sin(TAU * frequency * time) * envelope * 11000)
		bytes.encode_s16(i * 2, value)
	sound.data = bytes
	_warning_player.stream = sound
	_warning_player.play()
