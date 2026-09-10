## Reusable panel displaying a single battle character's state.
## Shows name, type, HP bar, status effects, and stat stages.
class_name BattleUnitPanel
extends PanelContainer

const UIStyleRef := preload("res://scripts/ui/ui_style.gd")

## Size presets: STANDARD (default), LARGE (front characters), SMALL (bench).
enum SizeMode {STANDARD, LARGE, SMALL}

## Root VBox holding all rows, kept for size-mode adjustments.
var _vbox: VBoxContainer
## Name label showing the character's display name.
var _name_label: Label
## Type label showing primary (+ secondary) type in type color.
var _type_label: Label
## HP progress bar (0-100, percentage hidden).
var _hp_bar: ProgressBar
## HP text label (e.g., "120/150").
var _hp_label: Label
## Container for status effect badges.
var _status_container: HBoxContainer
## Container for stat stage indicators.
var _stat_container: HBoxContainer
## Portrait display area.
var _portrait_rect: TextureRect
## Cached placeholder texture.
var _placeholder_texture: Texture2D
## True while the panel displays a grayed-out placeholder (identity only).
var _is_hidden: bool = false
## Current size preset; defaults to STANDARD.
var _size_mode: SizeMode = SizeMode.STANDARD


func _ready() -> void:
	_build_ui()


## Switches the panel between STANDARD, LARGE (front), and SMALL (bench) sizes.
## Applies immediately when the UI has been built; otherwise the preset is
## applied once _build_ui() runs.
func set_size_mode(mode: SizeMode) -> void:
	_size_mode = mode
	if _vbox != null:
		_apply_size_mode()


func _build_ui() -> void:
	# Panel styling for visual distinction.
	add_theme_stylebox_override("panel", _create_panel_style())

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 2)
	add_child(_vbox)

	# Portrait (2:3 aspect ratio, keep-aspect centered).
	# The texture is assigned via _load_portrait(); keeping it null here is
	# fine (renders as an empty area until the first update).
	# EXPAND_IGNORE_SIZE lets the size presets (SMALL/STANDARD/LARGE) control
	# the rect via custom_minimum_size instead of the texture's pixel size.
	_portrait_rect = TextureRect.new()
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.custom_minimum_size = Vector2(120, 180)
	_vbox.add_child(_portrait_rect)

	# Row 1: Name + Type
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	_vbox.add_child(header)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 14)
	header.add_child(_name_label)

	_type_label = Label.new()
	_type_label.add_theme_font_size_override("font_size", 12)
	header.add_child(_type_label)

	# Row 2: HP Bar
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(120, 12)
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_vbox.add_child(_hp_bar)

	# Row 3: HP Text
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_vbox.add_child(_hp_label)

	# Row 4: Status Effects
	_status_container = HBoxContainer.new()
	_status_container.add_theme_constant_override("separation", 4)
	_vbox.add_child(_status_container)

	# Row 5: Stat Stages
	_stat_container = HBoxContainer.new()
	_stat_container.add_theme_constant_override("separation", 4)
	_vbox.add_child(_stat_container)

	_apply_size_mode()


## Applies the current size preset: portrait size, fonts, HP bar size,
## status/stat row visibility, and panel margins.
func _apply_size_mode() -> void:
	match _size_mode:
		SizeMode.LARGE:
			_portrait_rect.custom_minimum_size = Vector2(160, 240)
			_name_label.add_theme_font_size_override("font_size", 16)
			_type_label.add_theme_font_size_override("font_size", 14)
			_hp_bar.custom_minimum_size = Vector2(160, 14)
			_hp_label.add_theme_font_size_override("font_size", 13)
			_status_container.show()
			_stat_container.show()
			custom_minimum_size = Vector2(160, 0)
		SizeMode.SMALL:
			_portrait_rect.custom_minimum_size = Vector2(40, 60)
			_name_label.add_theme_font_size_override("font_size", 10)
			_type_label.add_theme_font_size_override("font_size", 9)
			_hp_bar.custom_minimum_size = Vector2(40, 8)
			_hp_label.add_theme_font_size_override("font_size", 9)
			_status_container.hide()
			_stat_container.hide()
			custom_minimum_size = Vector2(0, 0)
		_:
			_portrait_rect.custom_minimum_size = Vector2(120, 180)
			_name_label.add_theme_font_size_override("font_size", 14)
			_type_label.add_theme_font_size_override("font_size", 12)
			_hp_bar.custom_minimum_size = Vector2(120, 12)
			_hp_label.add_theme_font_size_override("font_size", 11)
			_status_container.show()
			_stat_container.show()
			custom_minimum_size = Vector2(160, 0)

	# Panel margins adapt to the size preset.
	add_theme_stylebox_override("panel", _create_panel_style())


func _create_panel_style() -> StyleBoxFlat:
	match _size_mode:
		SizeMode.LARGE:
			return UIStyleRef.panel_large()
		SizeMode.SMALL:
			return UIStyleRef.panel_small()
		_:
			return UIStyleRef.panel_standard()


## Builds the UI lazily when _ready() has not run yet (e.g., a freshly
## instantiated panel that has not been added to the tree).
func _ensure_ui() -> void:
	if _name_label == null:
		_build_ui()


## Loads portrait texture for the given path.
## Falls back to placeholder if path is empty or load fails.
## The placeholder itself is loaded lazily so tests that build the UI without
## entering the tree (no _ready()) never crash on a missing resource.
func _load_portrait(portrait_path: String, grayed_out: bool = false) -> void:
	if _placeholder_texture == null:
		_placeholder_texture = load("res://assets/portraits/placeholder.png")
	var texture: Texture2D = _placeholder_texture
	if portrait_path != "":
		var loaded := load(portrait_path)
		if loaded is Texture2D:
			texture = loaded
		else:
			push_warning("BattleUnitPanel: Failed to load portrait: %s" % portrait_path)
	_portrait_rect.texture = texture
	_portrait_rect.modulate = Color.GRAY if grayed_out else Color.WHITE


## Resolves the display name: localized text when a key is set, otherwise the
## raw name as a fallback (defensive for data without a localization key).
func _display_name(key: String, raw: String) -> String:
	return tr(key) if not key.is_empty() else raw


## Updates all display elements from a battle participant's data.
## Also resets any placeholder state from a previous hidden display.
func update_from_participant(p: BattleParticipant) -> void:
	if p == null or p.character_data == null:
		return
	_ensure_ui()

	_is_hidden = false
	# Restore normal panel styling in case the panel was a placeholder.
	add_theme_stylebox_override("panel", _create_panel_style())

	# Name
	_name_label.text = _display_name(p.character_data.name_key, p.character_data.name)
	if p.is_defeated:
		_name_label.add_theme_color_override("font_color", Color.GRAY)
	else:
		_name_label.add_theme_color_override("font_color", Color.WHITE)

	# Type
	_update_type_display(p.character_data)

	# Portrait
	_load_portrait(p.character_data.portrait_path)

	# HP Bar
	if p.is_defeated:
		_hp_bar.value = 0
		_hp_bar.modulate = Color.GRAY
	else:
		var hp_ratio: float = float(p.current_hp) / float(p.max_hp)
		_hp_bar.value = hp_ratio * 100.0
		_hp_bar.modulate = UIStyleRef.hp_color(hp_ratio)

	# HP Text
	if p.is_defeated:
		_hp_label.text = tr("ui.defeated")
		_hp_label.add_theme_color_override("font_color", Color.GRAY)
	else:
		_hp_label.text = "%d/%d" % [p.current_hp, p.max_hp]
		_hp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	# Status Effects
	_update_status_display(p.active_status_effects)

	# Stat Stages
	_update_stat_display(p.stat_stages)


## Shows a grayed-out placeholder for a character that has not appeared on the
## field yet. Displays identity (name and type) but no battle state (HP,
## status effects, stat stages).
func show_hidden_placeholder(char_data: CharacterData) -> void:
	if char_data == null:
		return
	_ensure_ui()
	_is_hidden = true

	_name_label.text = _display_name(char_data.name_key, char_data.name)
	_name_label.add_theme_color_override("font_color", Color.GRAY)

	_update_type_display(char_data)
	_type_label.add_theme_color_override("font_color", Color.GRAY)

	# Portrait (grayed out for hidden)
	_load_portrait(char_data.portrait_path, true)

	_hp_bar.value = 0
	_hp_bar.modulate = Color.GRAY
	_hp_label.text = "???"
	_hp_label.add_theme_color_override("font_color", Color.GRAY)

	# Clear status and stat-stage content.
	for child: Node in _status_container.get_children():
		child.queue_free()
	for child: Node in _stat_container.get_children():
		child.queue_free()

	# Gray panel styling.
	var margin := UIStyleRef.CONTENT_MARGIN_NORMAL
	if _size_mode == SizeMode.SMALL:
		margin = UIStyleRef.CONTENT_MARGIN_SMALL
	elif _size_mode == SizeMode.LARGE:
		margin = UIStyleRef.CONTENT_MARGIN_LARGE
	add_theme_stylebox_override("panel", UIStyleRef.panel_hidden(margin))


## Shows a defeated state for a character that appeared on the field and was
## defeated. Displays identity (name and type) plus a "DEFEATED" marker and a
## red panel border; shows no HP, status, or stat-stage content. Distinct from
## show_hidden_placeholder() so a defeated slot never looks like an unselected
## one.
func show_defeated_placeholder(char_data: CharacterData) -> void:
	if char_data == null:
		return
	_ensure_ui()
	_is_hidden = false

	_name_label.text = _display_name(char_data.name_key, char_data.name)
	_name_label.add_theme_color_override("font_color", Color.GRAY)

	_update_type_display(char_data)
	_type_label.add_theme_color_override("font_color", Color.GRAY)

	# Portrait (grayed out for defeated)
	_load_portrait(char_data.portrait_path, true)

	_hp_bar.value = 0
	_hp_bar.modulate = Color.GRAY
	_hp_label.text = tr("ui.defeated")
	_hp_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))

	# Clear status and stat-stage content.
	for child: Node in _status_container.get_children():
		child.queue_free()
	for child: Node in _stat_container.get_children():
		child.queue_free()

	# Dark panel with a red border to signal defeat.
	var defeat_margin := UIStyleRef.CONTENT_MARGIN_NORMAL
	if _size_mode == SizeMode.SMALL:
		defeat_margin = UIStyleRef.CONTENT_MARGIN_SMALL
	elif _size_mode == SizeMode.LARGE:
		defeat_margin = UIStyleRef.CONTENT_MARGIN_LARGE
	add_theme_stylebox_override("panel", UIStyleRef.panel_defeated(defeat_margin))


func _update_type_display(char_data: CharacterData) -> void:
	var type_text: String = TypeColors.get_type_name(char_data.type)
	var type_color: Color = TypeColors.get_type_color(char_data.type)

	if char_data.has_secondary_type():
		type_text += "+" + TypeColors.get_type_name(char_data.secondary_type)

	_type_label.text = type_text
	_type_label.add_theme_color_override("font_color", type_color)


func _update_status_display(effects: Array[int]) -> void:
	# Clear existing badges.
	for child: Node in _status_container.get_children():
		child.queue_free()

	for effect: int in effects:
		var label_text: String = TypeColors.get_status_effect_label(effect)
		if label_text.is_empty():
			continue
		var badge := Label.new()
		badge.text = label_text
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", TypeColors.get_status_effect_color(effect))
		_status_container.add_child(badge)


func _update_stat_display(stages: Array[int]) -> void:
	# Clear existing indicators.
	for child: Node in _stat_container.get_children():
		child.queue_free()

	for i in range(stages.size()):
		var stage: int = stages[i]
		if stage == 0:
			continue
		var stat_label := Label.new()
		var arrow: String = "↑" if stage > 0 else "↓"
		stat_label.text = "%s%s%d" % [TypeColors.get_stat_name(i), arrow, abs(stage)]
		stat_label.add_theme_font_size_override("font_size", 10)
		if stage > 0:
			stat_label.add_theme_color_override("font_color", Color("#4CAF50"))
		else:
			stat_label.add_theme_color_override("font_color", Color("#F44336"))
		_stat_container.add_child(stat_label)


## Highlights or un-highlights this panel to indicate front character status.
func set_front_highlight(is_front: bool) -> void:
	var style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		style = _create_panel_style()
		add_theme_stylebox_override("panel", style)

	UIStyleRef.apply_front_highlight(style, is_front)
