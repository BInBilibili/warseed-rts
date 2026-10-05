extends CanvasLayer

const SETTINGS_PATH := "user://warseed_settings.cfg"

var _settings := ConfigFile.new()
var _last_visibility := false
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_label = Label.new()
	_label.name = "FpsLabel"
	_label.offset_left = 12.0
	_label.offset_top = 12.0
	_label.offset_right = 120.0
	_label.offset_bottom = 36.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color(0.76, 0.9, 0.84, 1.0))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.add_theme_font_size_override("font_size", 14)
	_label.text = "FPS: 0"
	add_child(_label)
	_settings.load(SETTINGS_PATH)
	_refresh_visibility()


func _process(_delta: float) -> void:
	var show_fps := bool(_settings.get_value("display", "show_fps", false))
	if show_fps != _last_visibility:
		_refresh_visibility()
	if _label.visible:
		_label.text = "FPS: %d" % Engine.get_frames_per_second()


func set_show_fps(enabled: bool) -> void:
	"""Apply a settings-panel change without waiting for a scene reload."""
	_settings.set_value("display", "show_fps", enabled)
	_last_visibility = enabled
	if _label != null:
		_label.visible = enabled


func _refresh_visibility() -> void:
	_last_visibility = bool(_settings.get_value("display", "show_fps", false))
	_label.visible = _last_visibility
