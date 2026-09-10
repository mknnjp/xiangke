## Centralized design tokens and style factory for the custom UI.
## Replaces scattered add_theme_color_override and StyleBoxFlat creation
## with a single source of truth for palette, typography, corners,
## borders, focus ring, and HP/type colors.
class_name UIStyle
extends RefCounted

## Palette: ink background and panel surfaces.
const PANEL_BG := Color(0.15, 0.15, 0.20, 0.92)
const PANEL_BG_HIDDEN := Color(0.12, 0.12, 0.16, 0.92)
const PANEL_BG_DEFEATED := Color(0.13, 0.10, 0.10, 0.92)
const PANEL_BORDER := Color(0.30, 0.30, 0.40)
const PANEL_BORDER_HIDDEN := Color(0.25, 0.25, 0.32)
const PANEL_BORDER_DEFEATED := Color(0.62, 0.22, 0.22)
const ACCENT_GOLD := Color("#FFD700")
const FOCUS_RING := Color("#FFD700")

## Palette: buttons.
const BUTTON_BG := Color(0.18, 0.18, 0.24, 0.95)
const BUTTON_BG_HOVER := Color(0.24, 0.24, 0.32, 0.98)
const BUTTON_BG_PRESSED := Color(0.12, 0.12, 0.17, 0.98)
const BUTTON_BG_DISABLED := Color(0.12, 0.12, 0.15, 0.60)
const BUTTON_BORDER := Color(0.38, 0.38, 0.50)
const BUTTON_BORDER_DISABLED := Color(0.22, 0.22, 0.28)

## Palette: text.
const TEXT_PRIMARY := Color.WHITE
const TEXT_SECONDARY := Color(0.80, 0.80, 0.80)
const TEXT_DIM := Color.GRAY
const TEXT_DEFEATED := Color(0.90, 0.40, 0.40)

## Palette: HP thresholds.
const HP_HIGH := Color("#4CAF50")
const HP_MID := Color("#FFC107")
const HP_LOW := Color("#F44336")

## Typography scale.
const FONT_TITLE := 32
const FONT_HEADING := 20
const FONT_BODY := 16
const FONT_SMALL := 14
const FONT_CAPTION := 12
const FONT_TINY := 11
const FONT_BADGE := 10

## Shape tokens.
const CORNER_RADIUS_PANEL := 6
const CORNER_RADIUS_BUTTON := 8
const BORDER_NORMAL := 1
const BORDER_STRONG := 2
const CONTENT_MARGIN_SMALL := 4
const CONTENT_MARGIN_NORMAL := 6
const CONTENT_MARGIN_LARGE := 8


## Returns the HP color for a 0-1 ratio.
static func hp_color(ratio: float) -> Color:
	if ratio >= 0.5:
		return HP_HIGH
	if ratio >= 0.25:
		return HP_MID
	return HP_LOW


## Builds a flat panel style for the given background and border colors.
static func make_panel_style(bg: Color, border: Color, border_width: int, margin: int, corner_radius: int = CORNER_RADIUS_PANEL) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(margin)
	return style


## Builds the default panel style (STANDARD preset equivalent).
static func panel_standard() -> StyleBoxFlat:
	return make_panel_style(PANEL_BG, PANEL_BORDER, BORDER_NORMAL, CONTENT_MARGIN_NORMAL)


## Builds the large front-row panel style.
static func panel_large() -> StyleBoxFlat:
	return make_panel_style(PANEL_BG, PANEL_BORDER, BORDER_NORMAL, CONTENT_MARGIN_LARGE)


## Builds the small bench panel style.
static func panel_small() -> StyleBoxFlat:
	return make_panel_style(PANEL_BG, PANEL_BORDER, BORDER_NORMAL, CONTENT_MARGIN_SMALL)


## Builds the hidden (fog-of-war) panel style.
static func panel_hidden(margin: int = CONTENT_MARGIN_NORMAL) -> StyleBoxFlat:
	return make_panel_style(PANEL_BG_HIDDEN, PANEL_BORDER_HIDDEN, BORDER_NORMAL, margin)


## Builds the defeated panel style.
static func panel_defeated(margin: int = CONTENT_MARGIN_NORMAL) -> StyleBoxFlat:
	return make_panel_style(PANEL_BG_DEFEATED, PANEL_BORDER_DEFEATED, BORDER_NORMAL, margin)


## Applies the front-row gold highlight to an existing panel style.
static func apply_front_highlight(style: StyleBoxFlat, is_front: bool) -> void:
	if is_front:
		style.border_color = ACCENT_GOLD
		style.set_border_width_all(BORDER_STRONG)
	else:
		style.border_color = PANEL_BORDER
		style.set_border_width_all(BORDER_NORMAL)


## Builds a button style for the given background and border.
static func make_button_style(bg: Color, border: Color, border_width: int = BORDER_NORMAL) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(CORNER_RADIUS_BUTTON)
	style.set_content_margin_all(CONTENT_MARGIN_NORMAL)
	return style


## Returns the focus ring style used for keyboard focus.
static func focus_style() -> StyleBoxEmpty:
	# Empty focus style: CustomButton draws its own ring in _draw() so the
	# native focus rect never clashes with the custom look.
	return StyleBoxEmpty.new()


## Applies the full custom button theme to a Button control.
## Keeps native signals (pressed, focus_entered, mouse_entered) intact;
## only the visuals change.
static func apply_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", make_button_style(BUTTON_BG, BUTTON_BORDER))
	button.add_theme_stylebox_override("hover", make_button_style(BUTTON_BG_HOVER, ACCENT_GOLD))
	button.add_theme_stylebox_override("pressed", make_button_style(BUTTON_BG_PRESSED, ACCENT_GOLD, BORDER_STRONG))
	button.add_theme_stylebox_override("disabled", make_button_style(BUTTON_BG_DISABLED, BUTTON_BORDER_DISABLED))
	button.add_theme_stylebox_override("focus", focus_style())
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", ACCENT_GOLD)
	button.add_theme_color_override("font_disabled_color", TEXT_DIM)
	button.add_theme_color_override("font_focus_color", TEXT_PRIMARY)


## Applies the selected state to a character grid button.
## Uses border color instead of modulate so focus visuals never clear it.
static func apply_selection(button: Button, selected: bool) -> void:
	var normal_bg: Color = BUTTON_BG_HOVER if selected else BUTTON_BG
	var normal_border: Color = ACCENT_GOLD if selected else BUTTON_BORDER
	var width: int = BORDER_STRONG if selected else BORDER_NORMAL
	button.add_theme_stylebox_override("normal", make_button_style(normal_bg, normal_border, width))
	button.add_theme_stylebox_override("hover", make_button_style(BUTTON_BG_HOVER, ACCENT_GOLD, width))


## Applies the standard panel style to a PanelContainer or Panel.
static func apply_panel_style(panel: Control) -> void:
	panel.add_theme_stylebox_override("panel", panel_standard())


## Applies title typography to a Label.
static func apply_title(label: Label) -> void:
	label.add_theme_font_size_override("font_size", FONT_TITLE)
	label.add_theme_color_override("font_color", TEXT_PRIMARY)


## Applies heading typography to a Label.
static func apply_heading(label: Label) -> void:
	label.add_theme_font_size_override("font_size", FONT_HEADING)
	label.add_theme_color_override("font_color", TEXT_PRIMARY)


## Applies preview text colors used by character select screens.
static func apply_preview_colors(name_label: Label, type_label: Label, stat_labels: Array, move_labels: Array, desc_label: Label) -> void:
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	type_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	for stat_label: Label in stat_labels:
		stat_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	for move_label: Label in move_labels:
		move_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.70))
	desc_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
