## SettingsScreen script.
## Independent settings screen reachable from the title screen. Provides a
## language selector (English, Japanese, Simplified/Traditional Chinese) and
## master/BGM/SFX volume sliders. All changes apply immediately and persist
## through SaveManager; language is owned by SettingsManager, volumes by
## AudioManager.
extends Control

## Display names for each supported locale, keyed by locale code.
const LOCALE_NAMES: Dictionary = {
	"en": "English",
	"ja": "日本語",
	"zh_CN": "简体中文",
	"zh_TW": "繁體中文",
}

## Language selector.
@onready var language_option: OptionButton = $SettingsPanel/LanguageOption
## Master volume slider (0-100).
@onready var master_slider: HSlider = $SettingsPanel/MasterVolumeSlider
## BGM volume slider (0-100).
@onready var bgm_slider: HSlider = $SettingsPanel/BgmVolumeSlider
## SFX volume slider (0-100).
@onready var sfx_slider: HSlider = $SettingsPanel/SfxVolumeSlider
## Returns to the title screen.
@onready var back_button: Button = $SettingsPanel/BackButton

const UIStyleRef := preload("res://scripts/ui/ui_style.gd")


func _ready() -> void:
	UIStyleRef.apply_button_theme(back_button)
	_populate_language_options()
	_load_volume_settings()
	back_button.grab_focus()

	UIFocusManager.register_focus_group([
		language_option, master_slider, bgm_slider, sfx_slider, back_button,
	])


## Fills the language OptionButton with the supported locales and selects the
## currently active one.
func _populate_language_options() -> void:
	language_option.clear()
	for locale: String in SettingsManager.SUPPORTED_LOCALES:
		language_option.add_item(LOCALE_NAMES.get(locale, locale))
		if locale == SettingsManager.current_locale:
			language_option.selected = language_option.item_count - 1


## Initializes the volume sliders from saved values (defaults to 100%).
func _load_volume_settings() -> void:
	master_slider.value = _percent_from_saved("master_volume")
	bgm_slider.value = _percent_from_saved("bgm_volume")
	sfx_slider.value = _percent_from_saved("sfx_volume")


## Converts a saved 0.0-1.0 volume to a 0-100 slider percentage.
func _percent_from_saved(key: String) -> float:
	var value: float = SaveManager.current_data.get(key, 1.0)
	return clampf(value, 0.0, 1.0) * 100.0


## Applies and persists the selected language.
func _on_language_option_item_selected(index: int) -> void:
	if index < 0 or index >= SettingsManager.SUPPORTED_LOCALES.size():
		return
	var locale: String = SettingsManager.SUPPORTED_LOCALES[index]
	SettingsManager.set_language(locale)


## Applies and persists the master volume.
func _on_master_volume_value_changed(value: float) -> void:
	_apply_volume("master_volume", value)


## Applies and persists the BGM volume.
func _on_bgm_volume_value_changed(value: float) -> void:
	_apply_volume("bgm_volume", value)


## Applies and persists the SFX volume.
func _on_sfx_volume_value_changed(value: float) -> void:
	_apply_volume("sfx_volume", value)


## Applies a volume slider change to the audio bus and persists it.
##
## Parameters:
##   key: Save key ("master_volume", "bgm_volume", or "sfx_volume").
##   percent: Slider value in 0-100 range.
func _apply_volume(key: String, percent: float) -> void:
	var normalized: float = clampf(percent, 0.0, 100.0) / 100.0
	match key:
		"master_volume":
			AudioManager.set_master_volume(normalized)
		"bgm_volume":
			AudioManager.set_bgm_volume(normalized)
		"sfx_volume":
			AudioManager.set_sfx_volume(normalized)
	SaveManager.current_data[key] = normalized
	SaveManager.save_game()


## Returns to the title screen.
func _on_back_button_pressed() -> void:
	GameManager.transition_to_state(GameManager.GameState.TITLE)
