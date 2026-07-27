class_name SettingsPanel
extends DemoPanelBase

signal settings_applied

var service := SettingsService.new()
var resolution: OptionButton
var fullscreen: CheckButton
var borderless: CheckButton
var ui_scale: HSlider
var master_volume: HSlider
var music_volume: HSlider
var sfx_volume: HSlider
var ui_volume: HSlider

func _ready() -> void:
	service.load_and_apply()
	super._ready()
	_populate_controls()

func build_content() -> void:
	label_node("DisplayHeader", "DISPLAY")
	resolution = OptionButton.new()
	resolution.name = "Resolution"
	content.add_child(resolution)
	fullscreen = CheckButton.new()
	fullscreen.name = "Fullscreen"
	fullscreen.text = "Fullscreen"
	content.add_child(fullscreen)
	borderless = CheckButton.new()
	borderless.name = "Borderless"
	borderless.text = "Borderless window"
	content.add_child(borderless)
	ui_scale = _slider("UIScale", "UI scale")
	label_node("AudioHeader", "AUDIO")
	master_volume = _slider("MasterVolume", "Master")
	music_volume = _slider("MusicVolume", "Music")
	sfx_volume = _slider("SFXVolume", "Effects")
	ui_volume = _slider("UIVolume", "UI")
	var buttons := HBoxContainer.new()
	buttons.name = "Actions"
	content.add_child(buttons)
	var apply_button := Button.new()
	apply_button.name = "Apply"
	apply_button.text = "APPLY"
	apply_button.pressed.connect(_apply_pressed)
	buttons.add_child(apply_button)
	var reset_button := Button.new()
	reset_button.name = "Reset"
	reset_button.text = "RESET"
	reset_button.pressed.connect(_reset_pressed)
	buttons.add_child(reset_button)

func _slider(node_name: String, label_text: String) -> HSlider:
	var row := HBoxContainer.new()
	row.name = "%sRow" % node_name
	content.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 110
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = 0.8 if node_name == "UIScale" else 0.0
	slider.max_value = 1.25 if node_name == "UIScale" else 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	return slider

func _populate_controls() -> void:
	for key: String in service.RESOLUTIONS.keys():
		resolution.add_item(key)
		resolution.set_item_metadata(resolution.item_count - 1, key)
	var resolution_key := str(service.current["resolution"])
	for index in resolution.item_count:
		if str(resolution.get_item_metadata(index)) == resolution_key:
			resolution.select(index)
	fullscreen.button_pressed = bool(service.current["fullscreen"])
	borderless.button_pressed = bool(service.current["borderless"])
	ui_scale.value = float(service.current["ui_scale"])
	master_volume.value = float(service.current["master_volume"])
	music_volume.value = float(service.current["music_volume"])
	sfx_volume.value = float(service.current["sfx_volume"])
	ui_volume.value = float(service.current["ui_volume"])

func _settings_from_controls() -> Dictionary:
	return {
		"resolution": str(resolution.get_selected_metadata()),
		"fullscreen": fullscreen.button_pressed,
		"borderless": borderless.button_pressed,
		"ui_scale": ui_scale.value,
		"master_volume": master_volume.value,
		"music_volume": music_volume.value,
		"sfx_volume": sfx_volume.value,
		"ui_volume": ui_volume.value
	}

func _apply_pressed() -> void:
	service.apply(_settings_from_controls())
	service.save()
	settings_applied.emit()

func _reset_pressed() -> void:
	service.reset()
	_populate_controls()
	settings_applied.emit()
