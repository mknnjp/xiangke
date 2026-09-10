## SceneTransition node.
## Provides animated scene transitions using a CanvasLayer overlay with
## AnimationPlayer-controlled fade effects.
class_name SceneTransition
extends CanvasLayer

## Total transition duration in seconds.
@export var transition_duration: float = 0.5
## Color of the fade overlay. Default black.
@export var fade_color: Color = Color(0, 0, 0, 1)
## AnimationPlayer reference for playing fade animations.
@export var animation_player: AnimationPlayer
## Accent line color drawn during transitions for custom feel.
@export var accent_color: Color = Color("#FFD700")

## Whether a transition is currently in progress.
var _is_transitioning: bool = false


func _ready() -> void:
	layer = 128 # Ensure overlay renders above all other content
	_ensure_ui_elements()


## Executes a scene transition with fade-out/in animation.
func transition_to(scene_path: String) -> void:
	if _is_transitioning:
		push_warning("SceneTransition: A transition is already in progress")
		return

	_is_transitioning = true

	var duration := transition_duration
	var color := fade_color

	# Validate scene path
	if not scene_path.begins_with("res://"):
		push_error("SceneTransition: Invalid scene path: %s (must be res://)" % scene_path)
		_is_transitioning = false
		return

	# Show overlay and play fade-out
	show()
	_play_fade_out(duration, color)

	# Wait for fade-out to complete
	await get_tree().create_timer(duration * 0.4).timeout

	# Load the new scene
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneTransition: Failed to load scene: %s (error %d)" % [scene_path, err])
		_is_transitioning = false
		return

	# Wait one frame for the new scene to initialize
	await get_tree().process_frame

	# Play fade-in
	_play_fade_in(duration, color)

	# Wait for fade-in to complete
	await get_tree().create_timer(duration * 0.4).timeout

	# Finish transition
	hide()
	_is_transitioning = false


## Plays a fade-out animation (screen to solid color).
func _play_fade_out(duration: float, color: Color) -> void:
	if animation_player and animation_player.has_animation("fade_out"):
		animation_player.play("fade_out")
	else:
		# Fallback: manual tween with a gold accent flash for custom feel.
		var rect := _get_color_rect()
		rect.color = color
		rect.color.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(rect, "color:a", 1.0, duration * 0.5)
		_play_accent_line(duration * 0.5)


## Plays a fade-in animation (solid color to screen).
func _play_fade_in(duration: float, color: Color) -> void:
	if animation_player and animation_player.has_animation("fade_in"):
		animation_player.play("fade_in")
	else:
		# Fallback: manual tween.
		var rect := _get_color_rect()
		rect.color = color
		rect.color.a = 1.0
		var tween := create_tween()
		tween.tween_property(rect, "color:a", 0.0, duration * 0.5)


## Draws a thin gold accent line sweeping across the screen mid-transition.
func _play_accent_line(duration: float) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = accent_color
	line.default_color.a = 0.9
	add_child(line)
	var viewport_size := get_viewport().get_visible_rect().size
	var y := viewport_size.y * 0.5
	line.points = PackedVector2Array([Vector2(-40, y), Vector2(-40, y)])
	var tween := create_tween()
	tween.tween_method(_update_accent_line.bind(line, y), -40.0, viewport_size.x + 40.0, duration)
	tween.tween_callback(line.queue_free)


## Updates the accent line sweep position.
func _update_accent_line(x: float, line: Line2D, y: float) -> void:
	line.points = PackedVector2Array([Vector2(x - 120.0, y), Vector2(x, y)])


## Ensures the overlay UI elements exist.
func _ensure_ui_elements() -> void:
	if not has_node("ColorRect"):
		var rect := ColorRect.new()
		rect.name = "ColorRect"
		rect.color = fade_color
		rect.color.a = 0.0
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(rect)

	hide() # Start hidden


## Gets the overlay ColorRect.
func _get_color_rect() -> ColorRect:
	return $ColorRect as ColorRect
