## TitleScreen script.
## Controls the title screen UI: displays game title, buttons to reach
## corps settings / battle preparation / settings, and initializes audio on
## first click (required for Web autoplay policy).
extends Control

## Reference to the version label.
@onready var version_label: Label = $VersionLabel
## Reference to the corps settings button.
@onready var corps_settings_button: Button = $CorpsSettingsButton
## Reference to the start button.
@onready var start_button: Button = $StartButton
## Reference to the settings button.
@onready var settings_button: Button = $SettingsButton
## Reference to the hint label shown when no corps has been saved yet.
@onready var start_hint_label: Label = $StartHintLabel

const UIStyleRef := preload("res://scripts/ui/ui_style.gd")


func _ready() -> void:
	_apply_custom_theme()
	version_label.text = "v1.0.0"
	_update_start_button_state()

	# Focus the first actionable button: start when enabled, else corps settings
	if start_button.disabled:
		corps_settings_button.grab_focus()
	else:
		start_button.grab_focus()

	# Register with focus manager if available
	if UIFocusManager:
		UIFocusManager.register_focus_group([corps_settings_button, start_button, settings_button])


## Applies the custom visual theme while keeping node paths and signals.
func _apply_custom_theme() -> void:
	UIStyleRef.apply_button_theme(corps_settings_button)
	UIStyleRef.apply_button_theme(start_button)
	UIStyleRef.apply_button_theme(settings_button)
	var title_label := get_node_or_null("TitleLabel") as Label
	if title_label != null:
		UIStyleRef.apply_title(title_label)


## Returns true if a valid 6-character corps exists in save data.
func _has_saved_corps() -> bool:
	var save_data := SaveManager.current_data
	return save_data.has("corps_characters") \
		and save_data["corps_characters"] is Array \
		and save_data["corps_characters"].size() == 6


## Enables/disables the Start button and hint label based on saved corps.
func _update_start_button_state() -> void:
	var has_corps := _has_saved_corps()
	start_button.disabled = not has_corps
	start_hint_label.visible = not has_corps


## Called when the "Corps Settings" button is pressed.
func _on_corps_settings_button_pressed() -> void:
	# Initialize audio on first user interaction (Web autoplay policy)
	AudioManager.initialize_audio()
	GameManager.transition_to_state(GameManager.GameState.CORPS_SETTINGS)


## Called when the "Start" button is pressed.
func _on_start_button_pressed() -> void:
	# Initialize audio on first user interaction (Web autoplay policy)
	AudioManager.initialize_audio()

	# Load save data
	SaveManager.load_save()

	# Reset battle data but preserve saved corps
	GameManager.corps_roster.battle_characters.clear()
	GameManager.corps_roster.opponent_corps.clear()

	# Restore the saved corps on the roster
	if _has_saved_corps():
		GameManager.corps_roster.restore_from_save(SaveManager.current_data)
	else:
		GameManager.corps_roster.corps_characters.clear()

	# Generate a fresh opponent corps for this battle attempt
	GameManager.corps_roster.generate_opponent_corps()

	# Transition to battle preparation (character select)
	GameManager.transition_to_state(GameManager.GameState.CHARACTER_SELECT)


## Called when the "Settings" button is pressed.
func _on_settings_button_pressed() -> void:
	AudioManager.initialize_audio()
	GameManager.transition_to_state(GameManager.GameState.SETTINGS)
