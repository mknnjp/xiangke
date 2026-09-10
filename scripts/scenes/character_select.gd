## CharacterSelect script.
## Manages battle preparation: select 3 characters from the saved corps
## for battle deployment. The saved corps is loaded from the roster, which
## is populated by the title screen from save data.
## Displays opponent's corps as read-only.
extends Control

## Reference to the character grid container.
@onready var character_grid: GridContainer = $CharacterGrid
## Reference to the deploy button.
@onready var deploy_button: Button = $DeployButton
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
## Reference to the opponent corps labels container.
@onready var opponent_label_container: VBoxContainer = $OpponentPanel/ScrollContainer/OpponentList

## Selected character IDs (Phase 2: 3 from corps).
var _selected_ids: Array[String] = []
## All character buttons for focus management.
var _character_buttons: Array[Control] = []

const CustomButtonRef := preload("res://scripts/ui/custom_button.gd")
const UIStyleRef := preload("res://scripts/ui/ui_style.gd")


func _ready() -> void:
	_apply_custom_theme()
	_load_characters()
	_load_opponent_display()
	_update_ui()
	_setup_preview_colors()
	stats_preview.hide()


## Applies the custom visual theme while keeping node paths and signals.
func _apply_custom_theme() -> void:
	UIStyleRef.apply_button_theme(deploy_button)
	UIStyleRef.apply_button_theme(back_button)
	UIStyleRef.apply_heading(phase_label)
	UIStyleRef.apply_panel_style(stats_preview)


## Sets up the colors for the stats preview labels.
func _setup_preview_colors() -> void:
	UIStyleRef.apply_preview_colors(preview_name, preview_type,
		[preview_hp, preview_attack, preview_defense, preview_speed, preview_intelligence, preview_spirit],
		[preview_move_1, preview_move_2, preview_move_3, preview_move_4], preview_desc)


## Loads only the corps characters (from CorpsRoster) for Phase 2 selection.
func _load_characters() -> void:
	var corps_ids: Array[String] = GameManager.corps_roster.corps_characters
	for char_id in corps_ids:
		var char_data := DataRegistry.get_character(char_id)
		if char_data == null:
			continue

		var btn := CustomButtonRef.new()
		btn.text = tr(char_data.name_key)
		btn.set_meta(&"char_id", char_id)
		btn.connect("pressed", Callable(self, "_on_character_pressed").bind(char_id))
		btn.connect("mouse_entered", Callable(self, "_on_character_hovered").bind(char_id))
		btn.connect("mouse_exited", Callable(self, "_on_character_hover_exit"))
		btn.size_flags_horizontal = Control.SIZE_EXPAND
		character_grid.add_child(btn)
		_character_buttons.append(btn)

	UIFocusManager.register_focus_group(_character_buttons)


## Loads the opponent corps display (read-only labels).
func _load_opponent_display() -> void:
	var opponent_ids: Array[String] = GameManager.corps_roster.opponent_corps
	# Clear existing opponent labels
	for child in opponent_label_container.get_children():
		child.queue_free()

	for char_id in opponent_ids:
		var char_data := DataRegistry.get_character(char_id)
		if char_data == null:
			continue

		var label := Label.new()
		label.text = tr("ui.name_type_format") % [tr(char_data.name_key), _format_type(char_data.type, char_data.secondary_type)]
		label.add_theme_color_override(&"font_color", Color(0.9, 0.7, 0.7)) # Reddish tint for enemy
		# Labels default to MOUSE_FILTER_IGNORE, which emits no mouse events.
		# STOP enables hover preview reusing the player character handlers.
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.connect("mouse_entered", Callable(self, "_on_character_hovered").bind(char_id))
		label.connect("mouse_exited", Callable(self, "_on_character_hover_exit"))
		opponent_label_container.add_child(label)


## Called when a character button is pressed.
func _on_character_pressed(char_id: String) -> void:
	# Only allow selection from corps_characters
	if not GameManager.corps_roster.corps_characters.has(char_id):
		return

	if _selected_ids.has(char_id):
		_selected_ids.erase(char_id)
	else:
		if _selected_ids.size() >= 3:
			return
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


## Called when the Back button is pressed (returns to title).
func _on_back_pressed() -> void:
	GameManager.transition_to_state(GameManager.GameState.TITLE)


## Called when the Deploy button is pressed.
func _on_deploy_pressed() -> void:
	if _selected_ids.size() != 3:
		return

	# Register battle party selection
	GameManager.corps_roster.set_battle_selection(_selected_ids)

	# Transition to battle
	GameManager.transition_to_state(GameManager.GameState.BATTLE)


## Updates UI elements based on current selection state.
func _update_ui() -> void:
	phase_label.text = tr("ui.select_deploy_count") % _selected_ids.size()
	deploy_button.disabled = _selected_ids.size() != 3

	# Update button visual states — gold border for selected buttons.
	for btn in _character_buttons:
		var char_id: String = btn.get_meta(&"char_id", "")
		if char_id.is_empty():
			continue
		UIStyleRef.apply_selection(btn as Button, _selected_ids.has(char_id))
