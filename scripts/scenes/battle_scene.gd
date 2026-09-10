extends Control

@onready var battle_log_label: RichTextLabel = $BattleLog
@onready var action_container: VBoxContainer = $ActionContainer
@onready var move_container: VBoxContainer = $MoveContainer
@onready var move_list: VBoxContainer = $MoveContainer/MovePanel/PanelContent/MoveList
@onready var switch_slot: VBoxContainer = $MoveContainer/MovePanel/PanelContent/SwitchSlot
@onready var status_label: Label = $StatusLabel
@onready var player_front_panel: BattleUnitPanel = $PlayerFrontPanel
@onready var enemy_front_panel: BattleUnitPanel = $EnemyFrontPanel
@onready var player_bench_container: HBoxContainer = $PlayerBenchContainer
@onready var enemy_bench_container: HBoxContainer = $EnemyBenchContainer

var _flow_service: BattleFlowService = null
var _is_selecting_switch: bool = false
## Reusable panels for the player's bench row.
var _player_panels: Array[BattleUnitPanel] = []
## Reusable panels for the enemy's bench row.
var _enemy_panels: Array[BattleUnitPanel] = []
## Move option buttons in the order they appear in the list.
var _move_buttons: Array[MoveButton] = []
## The switch (bench) button below the move list.
var _switch_button: Button = null
## Index of the currently focused option; _move_buttons.size() is the switch.
var _focused_option_index: int = -1
## Opponent corps character IDs in corps order (used for hidden slot display).
var _enemy_corps_ids: Array[String] = []
## Per corps index: whether the character has ever appeared on the field.
var _revealed_enemy_slots: Array[bool] = []

const CustomButtonRef := preload("res://scripts/ui/custom_button.gd")
const UIStyleRef := preload("res://scripts/ui/ui_style.gd")


func _ready() -> void:
	_flow_service = BattleFlowService.new()
	add_child(_flow_service)
	_apply_custom_theme()
	_setup_battle()


## Applies the custom visual theme while keeping node paths and signals.
func _apply_custom_theme() -> void:
	UIStyleRef.apply_heading(status_label)
	var move_panel := get_node_or_null("MoveContainer/MovePanel") as PanelContainer
	if move_panel != null:
		UIStyleRef.apply_panel_style(move_panel)


func _setup_battle() -> void:
	var roster: CorpsRoster = GameManager.corps_roster as CorpsRoster
	if roster == null:
		push_error("BattleScene: No corps roster found")
		return

	var battle_ids: Array[String] = roster.battle_characters
	if battle_ids.is_empty():
		push_error("BattleScene: No battle characters selected")
		return

	var player_chars: Array[CharacterData] = []
	for char_id: String in battle_ids:
		var char_data: CharacterData = DataRegistry.get_character(char_id)
		if char_data != null:
			player_chars.append(char_data)
		else:
			push_error("BattleScene: Character data not found: %s" % char_id)

	if player_chars.is_empty():
		push_error("BattleScene: No valid player characters")
		return

	var enemy_ids: Array[String] = _select_enemy_battle_team(roster.opponent_corps)
	var enemy_chars: Array[CharacterData] = []
	for char_id: String in enemy_ids:
		var char_data: CharacterData = DataRegistry.get_character(char_id)
		if char_data != null:
			enemy_chars.append(char_data)

	if enemy_chars.is_empty():
		push_error("BattleScene: No enemy characters loaded")
		return
	var started := _flow_service.start_battle(player_chars, enemy_chars)
	if not started:
		status_label.text = tr("ui.battle_failed")
		return

	# Initialize opponent visibility state from the corps.
	_enemy_corps_ids = roster.opponent_corps.duplicate()
	_revealed_enemy_slots.clear()
	for i in _enemy_corps_ids.size():
		_revealed_enemy_slots.append(false)

	_update_hp_displays()
	_update_log_display()

	var participant := _flow_service.get_active_participant()
	if participant != null:
		status_label.text = tr("ui.turn_format") % tr(participant.character_data.name_key)
	call_deferred("_handle_current_turn")


func _handle_current_turn() -> void:
	var participant := _flow_service.get_active_participant()
	if participant == null:
		return

	var active_idx := _flow_service.get_active_participant_index()
	var start_logs := _flow_service.process_start_of_turn(active_idx)
	for msg in start_logs:
		_on_log_updated(msg)

	_update_hp_displays()
	_update_log_display()

	var status := _flow_service.evaluate_battle_status()
	if status != BattleState.Status.ACTIVE:
		_on_battle_ended(status)
		return

	# If the active participant was defeated by status effects, skip ahead.
	var active := _flow_service.get_active_participant()
	if active == null or active.is_defeated:
		call_deferred("_advance_turn")
		return

	if participant.team == BattleParticipant.Team.PLAYER:
		status_label.text = tr("ui.turn_format") % tr(participant.character_data.name_key)
		_show_move_selection()
	else:
		# The enemy AI decision and execution live in the Rust battle engine.
		var result := _flow_service.perform_ai_turn()
		status_label.text = result.get("log_message", tr("ui.enemy_acted"))
		_update_hp_displays()
		_update_log_display()
		call_deferred("_advance_turn")


func _show_move_selection() -> void:
	if _flow_service == null:
		return

	var participant := _flow_service.get_active_participant()
	if participant == null or participant.character_data == null:
		return

	_is_selecting_switch = false
	action_container.hide()
	move_container.show()

	_clear_move_options()

	var enemy_front := _flow_service.get_front_participant(BattleParticipant.Team.ENEMY)
	for i in range(participant.character_data.moves.size()):
		var move_id: String = participant.character_data.moves[i]
		var move_data: MoveData = DataRegistry.get_move(move_id)
		if move_data == null:
			continue

		var effectiveness: float = _compute_effectiveness(move_data, enemy_front)
		var btn := MoveButton.new()
		btn.update_from_move(move_data, effectiveness)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.connect("pressed", Callable(self, "_on_move_selected").bind(move_data))
		btn.connect("focus_entered", Callable(self, "_on_move_option_focused")
				.bind(_move_buttons.size()))
		move_list.add_child(btn)
		_move_buttons.append(btn)

	# Switch option: swap the front character with a living benched character.
	var switch_btn := CustomButtonRef.new()
	switch_btn.text = tr("ui.switch_bench")
	switch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	switch_btn.connect("pressed", Callable(self, "_on_switch_selected"))
	switch_btn.connect("focus_entered", Callable(self, "_on_move_option_focused")
			.bind(_move_buttons.size()))
	switch_slot.add_child(switch_btn)
	_switch_button = switch_btn

	_focused_option_index = 0
	if not _move_buttons.is_empty():
		_move_buttons[0].grab_focus()
	_update_move_focus_highlight()


## Frees all move options and resets navigation state.
func _clear_move_options() -> void:
	for child: Node in move_list.get_children():
		move_list.remove_child(child)
		child.queue_free()
	for child: Node in switch_slot.get_children():
		switch_slot.remove_child(child)
		child.queue_free()
	_move_buttons.clear()
	_switch_button = null
	_focused_option_index = -1


## Computes the type effectiveness multiplier of a move against a target.
## Returns -1.0 when the target is unknown so the UI hides the multiplier.
func _compute_effectiveness(move_data: MoveData, target: BattleParticipant) -> float:
	if target == null or target.character_data == null:
		return -1.0
	var chart := TypeChart.new()
	return chart.resolve_type_effectiveness(
		move_data.type,
		target.character_data.type,
		target.character_data.secondary_type)


## Displays the living benched characters for the player to choose a switch.
func _show_switch_selection() -> void:
	move_container.hide()
	_is_selecting_switch = true
	status_label.text = tr("ui.choose_switch")

	for child: Node in action_container.get_children():
		child.queue_free()

	var bench := _flow_service.get_bench_participants(BattleParticipant.Team.PLAYER)
	if bench.is_empty():
		status_label.text = tr("ui.no_bench")
		_is_selecting_switch = false
		action_container.hide()
		_show_move_selection()
		return

	for p: BattleParticipant in bench:
		var wrapper := VBoxContainer.new()
		wrapper.size_flags_horizontal = Control.SIZE_EXPAND

		var panel: BattleUnitPanel = preload("res://scenes/battle_unit_panel.tscn").instantiate()
		panel.update_from_participant(p)
		panel.size_flags_horizontal = Control.SIZE_EXPAND
		wrapper.add_child(panel)

		var btn := CustomButtonRef.new()
		btn.text = tr("ui.switch_in")
		btn.size_flags_horizontal = Control.SIZE_EXPAND
		btn.connect("pressed", Callable(self, "_on_switch_target_selected").bind(p.slot_index))
		wrapper.add_child(btn)

		action_container.add_child(wrapper)

	var cancel_btn := CustomButtonRef.new()
	cancel_btn.text = tr("ui.cancel")
	cancel_btn.connect("pressed", Callable(self, "_on_cancel_switch_selection"))
	action_container.add_child(cancel_btn)

	action_container.show()


func _on_move_selected(move_data: MoveData) -> void:
	_is_selecting_switch = false
	# No target selection: the move always hits the opponent's front character.
	var result := _flow_service.execute_player_action(move_data)
	status_label.text = result.get("log_message", tr("ui.action_executed"))
	_update_hp_displays()
	_update_log_display()
	_advance_turn()


func _on_switch_selected() -> void:
	_show_switch_selection()


func _on_switch_target_selected(bench_index: int) -> void:
	_is_selecting_switch = false
	action_container.hide()

	if _flow_service.execute_switch(BattleParticipant.Team.PLAYER, bench_index):
		status_label.text = tr("ui.switched")
	else:
		status_label.text = tr("ui.switch_failed")

	_update_hp_displays()
	_update_log_display()
	_advance_turn()


func _on_cancel_switch_selection() -> void:
	_is_selecting_switch = false
	action_container.hide()
	_show_move_selection()


func _advance_turn() -> void:
	# Ensure both teams have a living front before advancing. This covers
	# defeats caused by status effects (e.g. poison) outside direct attacks.
	_flow_service.replace_front_if_defeated(BattleParticipant.Team.PLAYER)
	_flow_service.replace_front_if_defeated(BattleParticipant.Team.ENEMY)
	_update_hp_displays()
	_update_log_display()

	var current_idx := _flow_service.get_active_participant_index()
	if current_idx >= 0:
		var logs := _flow_service.process_end_of_turn(current_idx)
		for msg in logs:
			_on_log_updated(msg)
		_update_hp_displays()
		_update_log_display()

		var end_status := _flow_service.evaluate_battle_status()
		if end_status != BattleState.Status.ACTIVE:
			_on_battle_ended(end_status)
			return

	var has_next := _flow_service.advance_turn()
	if not has_next:
		_on_battle_ended(_flow_service.get_battle_status())
		return

	var active_idx := _flow_service.get_active_participant_index()
	if active_idx >= 0:
		var logs := _flow_service.process_start_of_turn(active_idx)
		for msg in logs:
			_on_log_updated(msg)

	_update_hp_displays()
	_update_log_display()

	var status := _flow_service.evaluate_battle_status()
	if status != BattleState.Status.ACTIVE:
		_on_battle_ended(status)
		return

	_handle_current_turn()


## Selects the 3 enemy characters to field in battle from the 6-character
## opponent corps. Picks the strongest 3 by combined stats; the strongest is
## the first (initial front).
func _select_enemy_battle_team(opponent_ids: Array[String]) -> Array[String]:
	var ranked: Array[Dictionary] = []
	for char_id: String in opponent_ids:
		var char_data: CharacterData = DataRegistry.get_character(char_id)
		if char_data == null:
			continue
		var total := char_data.hp + char_data.attack + char_data.defense \
				+ char_data.speed + char_data.intelligence + char_data.spirit
		ranked.append({"id": char_id, "total": total})

	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["total"] > b["total"])

	var result: Array[String] = []
	for i in range(min(3, ranked.size())):
		result.append(ranked[i]["id"])
	return result


func _on_battle_ended(status: int) -> void:
	var won: bool = (status == BattleState.Status.VICTORY)
	var data: Dictionary = SaveManager.current_data.duplicate()
	data["last_battle_won"] = won
	data["last_battle_time"] = Time.get_datetime_string_from_system()
	SaveManager.save_game(data)

	await get_tree().create_timer(0.5).timeout
	GameManager.transition_to_state(GameManager.GameState.RESULT)


func _on_log_updated(_message: String) -> void:
	_update_log_display()


func _update_hp_displays() -> void:
	if _flow_service == null:
		return

	_update_player_team()
	_update_enemy_team()


## Updates the player's display: the front character in a large panel and the
## bench characters in a row of small panels.
func _update_player_team() -> void:
	# Front: large panel with the active character.
	var front := _flow_service.get_front_participant(BattleParticipant.Team.PLAYER)
	if front != null:
		player_front_panel.set_size_mode(BattleUnitPanel.SizeMode.LARGE)
		player_front_panel.update_from_participant(front)
		player_front_panel.set_front_highlight(true)

	# Bench: small panels for the remaining living participants.
	var bench: Array[BattleParticipant] = _flow_service.get_bench_participants(
			BattleParticipant.Team.PLAYER)
	_resize_panels(_player_panels, bench.size())

	# Rebuild the bench row with panels in the correct order.
	for child: Node in player_bench_container.get_children():
		player_bench_container.remove_child(child)

	for i in range(bench.size()):
		var p: BattleParticipant = bench[i]
		var panel: BattleUnitPanel = _player_panels[i]
		panel.set_size_mode(BattleUnitPanel.SizeMode.SMALL)
		# Add before updating: add_child() runs _ready()/_build_ui(), which the
		# update methods rely on (labels would be null otherwise).
		player_bench_container.add_child(panel)
		panel.update_from_participant(p)
		panel.set_front_highlight(false)


## Updates the opponent's display: the front character in a large panel and the
## remaining corps members in a row of small panels, one slot per corps member
## in corps order. Slots whose character has never appeared on the field are
## grayed out (identity only, no battle state); the rest are fully displayed.
func _update_enemy_team() -> void:
	# Mark the current front's corps slot as revealed: every path that changes
	# the front funnels through this update. The Rust bridge reports global
	# participant indices in slot_index, so resolve the corps position by id.
	var front := _flow_service.get_front_participant(BattleParticipant.Team.ENEMY)
	var front_corps_idx: int = -1
	if front != null:
		front_corps_idx = _enemy_corps_ids.find(front.character_data.id)
		if front_corps_idx >= 0 and front_corps_idx < _revealed_enemy_slots.size():
			_revealed_enemy_slots[front_corps_idx] = true

	# Front: large panel with the active character.
	if front != null:
		enemy_front_panel.set_size_mode(BattleUnitPanel.SizeMode.LARGE)
		enemy_front_panel.update_from_participant(front)
		enemy_front_panel.set_front_highlight(true)

	# Map corps index -> participant for revealed slots.
	var by_corps: Dictionary = {}
	var all_participants: Array[BattleParticipant] = []
	if front != null:
		all_participants.append(front)
	for p: BattleParticipant in _flow_service.get_bench_participants(BattleParticipant.Team.ENEMY):
		all_participants.append(p)
	for p: BattleParticipant in all_participants:
		var corps_idx: int = _enemy_corps_ids.find(p.character_data.id)
		if corps_idx >= 0:
			by_corps[corps_idx] = p

	# Bench: one slot per corps member except the current front, in corps order.
	var bench_indices: Array[int] = []
	for i in range(_enemy_corps_ids.size()):
		if i != front_corps_idx:
			bench_indices.append(i)

	_resize_panels(_enemy_panels, bench_indices.size())

	# Rebuild the bench row.
	for child: Node in enemy_bench_container.get_children():
		enemy_bench_container.remove_child(child)

	for i in range(bench_indices.size()):
		var corps_idx: int = bench_indices[i]
		var panel: BattleUnitPanel = _enemy_panels[i]
		panel.set_size_mode(BattleUnitPanel.SizeMode.SMALL)
		# Add before updating: add_child() runs _ready()/_build_ui(), which the
		# placeholder/update methods rely on (labels would be null otherwise).
		enemy_bench_container.add_child(panel)
		var p: BattleParticipant = by_corps.get(corps_idx)
		var char_data: CharacterData = DataRegistry.get_character(_enemy_corps_ids[corps_idx])
		if _revealed_enemy_slots[corps_idx] and p != null:
			panel.update_from_participant(p)
			panel.set_front_highlight(false)
		elif _revealed_enemy_slots[corps_idx]:
			# Revealed earlier but no longer among the living participants:
			# the character was defeated (the bridge only reports living
			# bench participants). Render a distinct defeated state so it
			# never looks like an unselected slot.
			panel.show_defeated_placeholder(char_data)
			panel.set_front_highlight(false)
		else:
			panel.show_hidden_placeholder(char_data)
			panel.set_front_highlight(false)


## Grows or shrinks a panel array to the target size, freeing any extras.
func _resize_panels(panels: Array[BattleUnitPanel], count: int) -> void:
	while panels.size() < count:
		var panel: BattleUnitPanel = preload("res://scenes/battle_unit_panel.tscn").instantiate()
		panels.append(panel)
	while panels.size() > count:
		var old: BattleUnitPanel = panels.pop_back()
		if old.get_parent() != null:
			old.get_parent().remove_child(old)
		old.queue_free()


func _update_log_display() -> void:
	if _flow_service == null:
		return
	var recent: PackedStringArray = _flow_service.get_recent_log(10)
	battle_log_label.text = "\n".join(recent)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _is_selecting_switch:
			_on_cancel_switch_selection()
		return

	# List navigation only applies while the move selection is visible.
	if not move_container.visible or _is_selecting_switch:
		return
	if _move_buttons.is_empty():
		return

	var step := 0
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		step = -1
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		step = 1
	if step == 0:
		return

	var next_index := _next_list_index(_focused_option_index, step, _move_buttons.size())
	_focus_option(next_index)


## Focuses the option at the given index; _move_buttons.size() is the switch.
func _focus_option(option_index: int) -> void:
	if option_index < 0 or option_index > _move_buttons.size():
		return
	if option_index == _move_buttons.size():
		if _switch_button != null:
			_switch_button.grab_focus()
		return
	_move_buttons[option_index].grab_focus()


## Called when a move option gains focus (mouse click or keyboard).
func _on_move_option_focused(option_index: int) -> void:
	_focused_option_index = option_index
	_update_move_focus_highlight()


## Applies UIFocusManager-style highlighting to the focused option.
## Custom buttons draw their own focus ring on grab_focus; reset modulate
## so selection state never leaks into focus visuals.
func _update_move_focus_highlight() -> void:
	for i in _move_buttons.size():
		_move_buttons[i].modulate = Color(1, 1, 1)
		_move_buttons[i].queue_redraw()
	if _switch_button != null:
		_switch_button.modulate = Color(1, 1, 1)
		_switch_button.queue_redraw()


## Pure list navigation helper: returns the next option index for a step.
## Options 0..move_count-1 are moves in a vertical list; move_count is the
## switch option. step is -1 (previous) or +1 (next); navigation wraps at
## both ends of the list.
static func _next_list_index(from_idx: int, step: int, move_count: int) -> int:
	if move_count <= 0:
		return -1
	var option_count := move_count + 1
	if from_idx < 0 or from_idx >= option_count:
		return 0
	return ((from_idx + step) % option_count + option_count) % option_count
