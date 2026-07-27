class_name SettingsService
extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULTS := {
	"resolution": "1152x648",
	"fullscreen": false,
	"borderless": false,
	"ui_scale": 1.0,
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"ui_volume": 1.0
}
const RESOLUTIONS := {
	"1152x648": Vector2i(1152, 648),
	"1280x720": Vector2i(1280, 720),
	"1600x900": Vector2i(1600, 900),
	"1920x1080": Vector2i(1920, 1080),
	"2560x1080": Vector2i(2560, 1080)
}

var current: Dictionary = DEFAULTS.duplicate()

func load_and_apply() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		for key: String in DEFAULTS.keys():
			current[key] = config.get_value("settings", key, DEFAULTS[key])
	apply(current)

func apply(settings: Dictionary) -> void:
	_ensure_audio_buses()
	for key: String in DEFAULTS.keys():
		if settings.has(key):
			current[key] = settings[key]
	var resolution: Vector2i = RESOLUTIONS.get(str(current["resolution"]), RESOLUTIONS["1152x648"])
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(current["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, bool(current["borderless"]) and mode == DisplayServer.WINDOW_MODE_WINDOWED)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(resolution)
	_apply_audio("Master", float(current["master_volume"]))
	_apply_audio("Music", float(current["music_volume"]))
	_apply_audio("SFX", float(current["sfx_volume"]))
	_apply_audio("UI", float(current["ui_volume"]))
	var root := Engine.get_main_loop().root as Window
	if root != null:
		root.content_scale_factor = float(current["ui_scale"])

func save() -> void:
	var config := ConfigFile.new()
	for key: String in current.keys():
		config.set_value("settings", key, current[key])
	config.save(SETTINGS_PATH)

func reset() -> void:
	current = DEFAULTS.duplicate()
	apply(current)
	save()

func _apply_audio(bus_name: String, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(linear_volume, 0.0, 1.0)))

func _ensure_audio_buses() -> void:
	for bus_name: String in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
