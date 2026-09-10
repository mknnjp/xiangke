## MoveButton script.
## A rich Button displaying a move's full battle information: name, type,
## power/accuracy/category, effect badges, type effectiveness, and a flavor
## description tooltip. All content is built from child labels so each
## element can be colored independently; every child ignores mouse input so
## the Button itself handles clicks, hover, focus, and keyboard activation.
class_name MoveButton
extends "res://scripts/ui/custom_button.gd"

## Horizontal padding between the content and the button edge, so the focus
## ring and stylebox edges never overlap the labels.
const _CONTENT_MARGIN_H: float = 10.0
## Vertical padding between the content and the button edge.
const _CONTENT_MARGIN_V: float = 4.0

## Move name label (row 1, left).
var _name_label: Label
## Type name label (row 1, right, type colored).
var _type_label: Label
## Stats label: power, accuracy, damage category (row 2, left).
var _stats_label: Label
## Type effectiveness multiplier label (row 2, right).
var _effect_label: Label
## Container for effect badges (row 3).
var _badges_container: HBoxContainer
## Root layout box filling the button rect (Button is a plain Control, so the
## content must be anchored and sized manually).
var _content_box: VBoxContainer
## True once the UI has been built; prevents duplicate builds on re-entry.
var _ui_built: bool = false


func _ready() -> void:
	super._ready()
	_build_ui()


## Recomputes the button's minimum size from the content and stores it in
## custom_minimum_size. Button's native get_minimum_size() only considers
## stylebox, text, and icon, so a GDScript _get_minimum_size() override is
## never called; custom_minimum_size is the only script-side input the
## native minimum-size path honors.
func _notification(what: int) -> void:
	# Label font metrics only resolve once the theme is available, which is
	# after entering the tree, so refresh on all three notifications to cover
	# first entry and any later theme swap. POST_ENTER_TREE fires after all
	# children have entered the tree, by which point their fonts resolve.
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_THEME_CHANGED \
			or what == NOTIFICATION_POST_ENTER_TREE:
		_refresh_minimum_size()


func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true

	text = ""

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	# Fill the button rect, inset so content clears the focus ring and edges.
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = _CONTENT_MARGIN_H
	vbox.offset_top = _CONTENT_MARGIN_V
	vbox.offset_right = - _CONTENT_MARGIN_H
	vbox.offset_bottom = - _CONTENT_MARGIN_V
	_content_box = vbox

	# Row 1: name + type
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 15)
	header.add_child(_name_label)

	_type_label = Label.new()
	_type_label.add_theme_font_size_override("font_size", 12)
	header.add_child(_type_label)

	# Row 2: stats + effectiveness
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 8)
	vbox.add_child(stats_row)

	_stats_label = Label.new()
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_label.add_theme_font_size_override("font_size", 12)
	stats_row.add_child(_stats_label)

	_effect_label = Label.new()
	_effect_label.add_theme_font_size_override("font_size", 12)
	stats_row.add_child(_effect_label)

	# Row 3: badges
	_badges_container = HBoxContainer.new()
	_badges_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_badges_container)

	_set_children_mouse_filter(vbox, Control.MOUSE_FILTER_IGNORE)


## Recursively sets the mouse filter on all child controls so the Button
## receives every input event itself.
func _set_children_mouse_filter(node: Node, filter: Control.MouseFilter) -> void:
	for child: Node in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = filter
		_set_children_mouse_filter(child, filter)


## Resolves the display name: localized text when a key is set, otherwise the
## raw name as a fallback (defensive for data without a localization key).
func _display_name(key: String, raw: String) -> String:
	return tr(key) if not key.is_empty() else raw


## Updates all display elements from a move's data.
## effectiveness: type effectiveness multiplier against the opponent's front
## character; pass -1.0 to hide the multiplier (unknown target).
func update_from_move(move: MoveData, effectiveness: float) -> void:
	if move == null:
		return
	_ensure_ui()

	var type_color: Color = TypeColors.get_type_color(move.type)
	var type_name: String = TypeColors.get_type_name(move.type)

	# Row 1: name + type
	_name_label.text = _display_name(move.name_key, move.name)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_type_label.text = type_name
	_type_label.add_theme_color_override("font_color", type_color)

	# Row 2: stats + effectiveness
	var cat_name: String = TypeColors.get_category_name(move.damage_category)
	_stats_label.text = tr("ui.move_stats") % [move.power, move.accuracy, cat_name]
	_stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_update_effect_display(effectiveness)

	# Row 3: badges
	_update_badges(move)

	# Tooltip: flavor description.
	tooltip_text = _display_name(move.desc_key, move.description)

	# Content changed; refresh the size hint so an in-tree button reflows
	# immediately (out-of-tree buttons are refreshed on NOTIFICATION_ENTER_TREE).
	_refresh_minimum_size()


## Builds the UI lazily when _ready() has not run yet (e.g., a freshly
## instantiated button that has not been added to the tree).
func _ensure_ui() -> void:
	if not _ui_built:
		_build_ui()


## Sizes the button to fit its content. Button is a plain Control and does
## not account for children when computing its minimum size, so without this
## the content would overflow and overlap neighboring buttons.
##
## NOTE: a GDScript _get_minimum_size() override is dead code on Button —
## Godot's native Button.get_minimum_size() never calls the script virtual.
## The content size is therefore exposed through custom_minimum_size, which
## the native minimum-size path does honor. Font metrics only resolve inside
## the tree, so callers must refresh after NOTIFICATION_ENTER_TREE /
## NOTIFICATION_THEME_CHANGED (handled in _notification()).
func _refresh_minimum_size() -> void:
	if _content_box == null:
		return
	var content := _content_box.get_combined_minimum_size()
	# get_combined_minimum_size() does not reflect custom_minimum_size, so
	# respect it explicitly.
	content = content.max(_content_box.custom_minimum_size)
	custom_minimum_size = Vector2(
		content.x + _CONTENT_MARGIN_H * 2.0,
		content.y + _CONTENT_MARGIN_V * 2.0)


## Renders the type effectiveness multiplier; -1.0 hides the display.
func _update_effect_display(effectiveness: float) -> void:
	if effectiveness < 0.0:
		_effect_label.text = ""
		return
	_effect_label.text = _format_effectiveness(effectiveness)
	_effect_label.add_theme_color_override("font_color",
		_effectiveness_color(effectiveness))


## Formats the multiplier as ×2.0 / ×1.25 / ×1.0 / ×0.5 / ×0.
func _format_effectiveness(effectiveness: float) -> String:
	if is_zero_approx(effectiveness):
		return "×0"
	var eff_text: String = "%.2f" % effectiveness
	if eff_text.ends_with("0"):
		eff_text = eff_text.substr(0, eff_text.length() - 1)
	return "×" + eff_text


## Colors the multiplier: super effective green, neutral gray, resisted red,
## immune dark red.
func _effectiveness_color(effectiveness: float) -> Color:
	if is_zero_approx(effectiveness):
		return Color("#B71C1C")
	if effectiveness > 1.0:
		return Color("#4CAF50")
	if effectiveness < 1.0:
		return Color("#F44336")
	return Color(0.8, 0.8, 0.8)


## Rebuilds the effect badge row from a move's data, hiding badges that do
## not apply.
func _update_badges(move: MoveData) -> void:
	for child: Node in _badges_container.get_children():
		_badges_container.remove_child(child)
		child.queue_free()

	# Status effect with trigger chance.
	if move.effect != TypeEnums.EffectType.NONE:
		var effect_label: String = TypeColors.get_status_effect_label(move.effect)
		_add_badge("%s %d%%" % [effect_label, move.effect_chance],
			TypeColors.get_status_effect_color(move.effect))

	# Stat stage change (self or target).
	if move.has_stat_mod():
		var stat_name: String = TypeColors.get_stat_name(move.stat_mod_stat)
		var target_suffix: String = "(self)" if \
			move.stat_mod_target == TypeEnums.StatModTarget.SELF else "(target)"
		var stage_str := "%+d" % move.stat_mod_stage
		_add_badge("%s %s %s" % [stat_name, stage_str, target_suffix],
			Color("#81D4FA"))

	# Healing.
	if move.healing > 0:
		_add_badge("Heal %d%%" % move.healing, Color("#81C784"))

	# Recoil.
	if move.recoil > 0:
		_add_badge("Recoil %d%%" % move.recoil, Color("#FF8A65"))

	# Multi-hit.
	if move.hit_count > 1:
		_add_badge("×%d hits" % move.hit_count, Color("#CE93D8"))


## Adds a single badge label to the badge row.
func _add_badge(badge_text: String, color: Color) -> void:
	var badge := Label.new()
	badge.text = badge_text
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", color)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badges_container.add_child(badge)
