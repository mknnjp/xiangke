## Custom button with unique visual identity and focus ring.
## Extends native Button so pressed, focus_entered, mouse_entered/exited,
## disabled, and tooltip_text contracts stay intact; only visuals change.
class_name CustomButton
extends Button

const UIStyleRef := preload("res://scripts/ui/ui_style.gd")

## Extra growth of the focus ring outside the button rect.
const FOCUS_RING_GROW := 2.0
## Focus ring border width.
const FOCUS_RING_WIDTH := 2

## True while the OS cursor hovers the button.
var _is_hovered: bool = false
## Active press tween, killed on re-press to avoid stacking.
var _press_tween: Tween = null


func _ready() -> void:
	UIStyleRef.apply_button_theme(self)
	pivot_offset = size * 0.5
	resized.connect(_on_resized)
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	focus_entered.connect(_on_focus_visual_changed)
	focus_exited.connect(_on_focus_visual_changed)
	resized.connect(queue_redraw)
	# Disabled state changes do not emit a signal; redraw on visibility
	# changes covers most cases, theme handles the rest.
	queue_redraw()


## Draws the gold focus ring on top of the native stylebox.
func _draw() -> void:
	if has_focus() and not disabled:
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.border_color = UIStyleRef.FOCUS_RING
		ring.set_border_width_all(FOCUS_RING_WIDTH)
		ring.set_corner_radius_all(UIStyleRef.CORNER_RADIUS_BUTTON + 2)
		draw_style_box(ring, Rect2(Vector2.ZERO, size).grow(FOCUS_RING_GROW))


## Compatibility hook for UIFocusManager: forces the focus visual state.
func set_focused_visual(highlighted: bool) -> void:
	if highlighted:
		if not has_focus():
			grab_focus()
	else:
		if has_focus():
			release_focus()
	queue_redraw()


func _on_hover_changed(hovered: bool) -> void:
	_is_hovered = hovered
	if hovered and not disabled and is_inside_tree():
		_play_hover_feedback()
	queue_redraw()


func _on_focus_visual_changed() -> void:
	queue_redraw()


## Keeps the press-scale pivot centered on resize.
func _on_resized() -> void:
	pivot_offset = size * 0.5
	queue_redraw()


## Plays a subtle scale punch on hover for tactile custom feel.
func _play_hover_feedback() -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2(1.03, 1.03), 0.06)
	_press_tween.tween_property(self, "scale", Vector2.ONE, 0.08)


## Plays a press punch and confirm sound on click.
func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_play_press_feedback()


## Plays a quick scale punch on press for tactile custom feel.
func _play_press_feedback() -> void:
	if not is_inside_tree():
		return
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	scale = Vector2(0.96, 0.96)
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
