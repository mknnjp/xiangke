## CorpsCreation script.
## Manages the corps settings screen where the player selects 6 characters
## from the full roster to form their corps. On save, the corps is persisted
## and the screen returns to the title screen.
extends Control

## Reference to the character grid container.
@onready var character_grid: GridContainer = $CharacterGrid
## Reference to the save button.
@onready var confirm_button: Button = $ConfirmButton
## Reference to the back button.
@onready var back_button: Button = $BackButton
## Reference to the phase indicator label.
@onready var phase_label: Label = $PhaseLabel
## Reference to the stats preview panel.
@onready var stats_preview: Panel = $StatsPreview
## Reference to the character name in stats preview.
@onready var preview_name: Label = $StatsPreview/MarginContainer/VBoxContainer/NameLabel
## Reference to the character type in stats preview.
@onready var preview_type: Label = $StatsPreview/MarginContainer/VBoxContainer/TypeLabel
## Reference to the HP stat in stats preview.
@onready var preview_hp: Label = $StatsPreview/MarginContainer/VBoxContainer/HPLabel
## Reference to the Attack stat in stats preview.
@onready var preview_attack: Label = $StatsPreview/MarginContainer/VBoxContainer/AttackLabel
## Reference to the Defense stat in stats preview.
@onready var preview_defense: Label = $StatsPreview/MarginContainer/VBoxContainer/DefenseLabel
## Reference to the Speed stat in stats preview.
@onready var preview_speed: Label = $StatsPreview/MarginContainer/VBoxContainer/SpeedLabel
## Reference to the Intelligence stat in stats preview.
@onready var preview_intelligence: Label = $StatsPreview/MarginContainer/VBoxContainer/IntelligenceLabel
## Reference to the Spirit stat in stats preview.
@onready var preview_spirit: Label = $StatsPreview/MarginContainer/VBoxContainer/SpiritLabel
## Reference to the move labels container in stats preview.
@onready var preview_moves_container: VBoxContainer = $StatsPreview/MarginContainer/VBoxContainer/MovesContainer
## Reference to individual move labels.
@onready var preview_move_1: Label = $StatsPreview/MarginContainer/VBoxContainer/MovesContainer/Move1Label
@onready var preview_move_2: Label = $StatsPreview/MarginContainer/VBoxContainer/MovesContainer/Move2Label
@onready var preview_move_3: Label = $StatsPreview/MarginContainer/VBoxContainer/MovesContainer/Move3Label
@onready var preview_move_4: Label = $StatsPreview/MarginContainer/VBoxContainer/MovesContainer/Move4Label
## Reference to the description in stats preview.
@onready var preview_desc: Label = $StatsPreview/MarginContainer/VBoxContainer/DescLabel

## Selected character IDs.
var _selected_ids: Array[String] = []
## All character buttons for focus management.
var _character_buttons: Array[Control] = []

const CustomButtonRef := preload("res://scripts/ui/custom_button.gd")
const UIStyleRef := preload("res://scripts/ui/ui_style.gd")


func _ready() -> void:
	_apply_custom_theme()
	_load_characters()
	_preload_saved_corps()
	_update_ui()
	_setup_preview_colors()
	stats_preview.hide()


## Applies the custom visual theme while keeping node paths and signals.
func _apply_custom_theme() -> void:
	UIStyleRef.apply_button_theme(confirm_button)
	UIStyleRef.apply_button_theme(back_button)
	UIStyleRef.apply_heading(phase_label)
	UIStyleRef.apply_panel_style(stats_preview)


## Pre-selects characters from saved corps data if available.
func _preload_saved_corps() -> void:
	var save_data := SaveManager.current_data
	if save_data.has("corps_characters") and save_data["corps_characters"] is Array:
		var saved_ids: Array = save_data["corps_characters"]
		for char_id in saved_ids:
			if _selected_ids.size() < 6 and DataRegistry.has_character(str(char_id)):
				_selected_ids.append(str(char_id))
	_update_ui()


## Sets up the colors for the stats preview labels.
func _setup_preview_colors() -> void:
	UIStyleRef.apply_preview_colors(preview_name, preview_type,
		[preview_hp, preview_attack, preview_defense, preview_speed, preview_intelligence, preview_spirit],
		[preview_move_1, preview_move_2, preview_move_3, preview_move_4], preview_desc)


## Loads character data from DataRegistry and creates selection buttons.
func _load_characters() -> void:
	var characters := DataRegistry.get_all_characters()
	for char_id in characters.keys():
		var char_data := DataRegistry.get_character(char_id)
		if char_data == null:
			continue

		var btn := CustomButtonRef.new()
		btn.text = tr(char_data.name_key)
		# Store char_id in button metadata for later lookup
		btn.set_meta(&"char_id", char_id)
		btn.connect("pressed", Callable(self, "_on_character_pressed").bind(char_id))
		btn.connect("mouse_entered", Callable(self, "_on_character_hovered").bind(char_id))
		btn.connect("mouse_exited", Callable(self, "_on_character_hover_exit"))
		btn.size_flags_horizontal = Control.SIZE_EXPAND
		character_grid.add_child(btn)
		_character_buttons.append(btn)

	UIFocusManager.register_focus_group(_character_buttons)


## Called when a character button is pressed.
func _on_character_pressed(char_id: String) -> void:
	if _selected_ids.has(char_id):
		_selected_ids.erase(char_id)
	else:
		if _selected_ids.size() >= 6:
			return # Max 6 selected
		_selected_ids.append(char_id)

	_update_ui()


## Called when hovering over a character to show stats preview.
func _on_character_hovered(char_id: String) -> void:
	var char_data := DataRegistry.get_character(char_id)
	if char_data == null:
		return

	preview_name.text = tr(char_data.name_key)
	preview_type.text = tr("ui.type") % _format_type(char_data.type, char_data.secondary_type)
	preview_hp.text = tr("ui.hp") % char_data.hp
	preview_attack.text = tr("ui.attack") % char_data.attack
	preview_defense.text = tr("ui.defense") % char_data.defense
	preview_speed.text = tr("ui.speed") % char_data.speed
	preview_intelligence.text = tr("ui.intelligence") % char_data.intelligence
	preview_spirit.text = tr("ui.spirit") % char_data.spirit

	# Load and display move list
	var move_labels := [preview_move_1, preview_move_2, preview_move_3, preview_move_4]
	for i in range(4):
		if i < char_data.moves.size():
			var move := DataRegistry.get_move(char_data.moves[i])
			if move != null:
				move_labels[i].text = tr("ui.name_type_format") % [tr(move.name_key), TypeColors.get_type_name(move.type)]
				move_labels[i].show()
			else:
				move_labels[i].text = "???"
				move_labels[i].show()
		else:
			move_labels[i].hide()

	preview_desc.text = tr(char_data.desc_key) if char_data.desc_key else ""
	stats_preview.show()


## Formats character types for display.
func _format_type(primary: int, secondary: int) -> String:
	var result: String = TypeColors.get_type_name(primary)
	if secondary >= 0:
		result += "/" + TypeColors.get_type_name(secondary)
	return result


## Called when the mouse exits a character button.
func _on_character_hover_exit() -> void:
	stats_preview.hide()


## Called when the Back button is pressed (returns to title without saving).
func _on_back_pressed() -> void:
	GameManager.transition_to_state(GameManager.GameState.TITLE)


## Called when the Save button is pressed (corps selection complete).
func _on_save_pressed() -> void:
	if _selected_ids.size() != 6:
		return

	# Register corps selection
	GameManager.corps_roster.set_corps_selection(_selected_ids)

	# Persist corps to save data
	var save_data := SaveManager.current_data
	save_data["corps_characters"] = _selected_ids.duplicate()
	SaveManager.save_game(save_data)

	# Return to title (battle preparation can now be started)
	GameManager.transition_to_state(GameManager.GameState.TITLE)


## Updates UI elements based on current selection state.
func _update_ui() -> void:
	phase_label.text = tr("ui.select_corps_count") % _selected_ids.size()
	confirm_button.disabled = _selected_ids.size() != 6

	# Update button visual states — gold border for selected buttons.
	for btn in _character_buttons:
		var char_id: String = btn.get_meta(&"char_id", "")
		if char_id.is_empty():
			continue
		UIStyleRef.apply_selection(btn as Button, _selected_ids.has(char_id))
