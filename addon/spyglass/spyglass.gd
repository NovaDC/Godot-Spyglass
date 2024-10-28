@tool
@icon("res://addon/spyglass/spyglass.svg")
class_name Spyglass
extends Node2D

## Spyglass
## 
## A node that correlates to a in world [Node2D] [CanvasItem], allowing for a [Window] node to
## interact with the [SceneTree] directly as if it were a [CanvasItem] itself - 
## even for native windows.[br]
## [br]
## [br]
## This effectively works by internally mapping a window's position to the in world position of a
## [Node2D], and giving it a hidden [Window] node child, that itself has a hidden [Camera2D].[br]
## Add some transform math into the mix and you have yourself a stripped down [Spyglass].
## This node also add more features,
## allowing for the user to move the window with it reflecting that in the canvas,
## and other odds and ends allowing for a fully realised [CanvasItem] style [Window].
## 
## @experimental

## See [signal Window.about_to_popup]
signal about_to_popup()

## See [signal Window.close_requested]
signal close_requested()

## See [signal Window.dpi_changed]
signal dpi_changed()

## See [signal Window.files_dropped]
signal files_dropped(files: PackedStringArray)

## See [signal Window.focus_entered]
signal window_focus_entered()

## See [signal Window.focus_exited]
signal window_focus_exited()

## See [signal Window.go_back_requested]
signal go_back_requested()

## See [signal Window.mouse_entered]
signal window_mouse_entered()

## See [signal Window.window_mouse_exited]
signal window_mouse_exited()

## See [signal Window.theme_changed]
signal theme_changed()

## See [signal Window.titlebar_changed]
signal titlebar_changed()

## See [signal Window.window_input]
signal window_input(event: InputEvent)

## Emitted when the [member window_screen_rect] is modified.
signal window_rect_changed()

## All cursor types that may appear specifically when the window is being resized.
const WM_HANDLE_CURSOR_RESIZE_TYPES:Array[DisplayServer.CursorShape] = [DisplayServer.CURSOR_VSIZE,
																		DisplayServer.CURSOR_HSIZE,
																		DisplayServer.CURSOR_HSIZE, 
																	DisplayServer.CURSOR_BDIAGSIZE,
																	DisplayServer.CURSOR_FDIAGSIZE,
																	   ]

## All cursor types used when the cursor is actively interacting with the window handles
## [b]except[/b] for when the window is begin resized.[br]
## if a cursor type is used when both resizing and in other contexts,
## it should appear in both [Array]s.
const WM_HANDLE_CURSOR_TYPES:Array[DisplayServer.CursorShape] = [DisplayServer.CURSOR_MOVE]

## A mouse button mask that is used to interact with the window handles.
const WM_HANDLE_MOUSE_BUTTON_MASK:MouseButtonMask = MOUSE_BUTTON_MASK_LEFT


## An additional transform applied to the this node in global world space,
## when positioning this window on the screen.
@export var window_world_transform:Transform2D

## The size of this window in world space.
@export var in_world_size := Vector2.ONE * 300:
	get:
		return in_world_size
	set(_value):
		in_world_size = _value
		item_rect_changed.emit()

## When the [Spyglass] and it's internally used [Camera2D] should update.
## See [Camera2D.process_callback]
@export var process_callback := Camera2D.Camera2DProcessCallback.CAMERA2D_PROCESS_IDLE:
	get:
		return process_callback
	set(_value):
		process_callback = _value
		_sync_camera_settings()


@export_group("Window")
## See [member Window.title].
@export var title := "Spyglass":
	get:
		return title
	set(_value):
		title = _value
		_sync_window_settings()
## See [member Window.transient].
@export var transient := false:
	get:
		return transient
	set(_value):
		transient = _value
		_sync_window_settings()
## See [member Window.transient_to_focused].
@export var transient_to_focused := false:
	get:
		return transient_to_focused
	set(_value):
		transient_to_focused = _value
		_sync_window_settings()
## See [member Window.exclusive].
@export var exclusive := false:
	get:
		return exclusive
	set(_value):
		exclusive = _value
		_sync_window_settings()
## See [member Window.borderless].
@export var borderless := false:
	get:
		return borderless
	set(_value):
		borderless = _value
		_sync_window_settings()
## See [member Window.always_on_top].
@export var always_on_top := false:
	get:
		return always_on_top
	set(_value):
		always_on_top = _value
		_sync_window_settings()
## See [member Window.transparent] and [member Viewport.transparent_bg].
## This controls both [member Window.transparent]
## and [member Viewport.transparent_bg] simultaneously.
@export var transparent := false:
	get:
		return transparent
	set(_value):
		transparent = _value
		_sync_window_settings()
## See [member Window.unfocusable].
@export var unfocusable := false:
	get:
		return unfocusable
	set(_value):
		unfocusable = _value
		_sync_window_settings()
## See [member Window.popup_window].
@export var popup_window := false:
	get:
		return popup_window
	set(_value):
		popup_window = _value
		_sync_window_settings()
## See [member Window.extend_to_title].
## [br][br] - NOTE that this does [b]not[/b] extend the size of the window
## to the length fo the title bar's text, but instead extends the window's area to the title bar.
@export var extend_to_title := false:
	get:
		return extend_to_title
	set(_value):
		extend_to_title = _value
		_sync_window_settings()
## See [member Window.force_native].
@export var force_native := true:
	get:
		return force_native
	set(_value):
		force_native = _value
		_sync_window_settings()

@export_group("Positioning")
## Make the position of this node corlate to the center of the window
## instead of the top left corner.
@export var center := false:
	get:
		return center
	set(_value):
		center = _value
		_sync_camera_settings()
## The screen id (see [DisplayServer] to lear more about screen ids) to position this window in.
@export var target_screen_id:int = 0
## See [member Viewport.snap_2d_transforms_to_pixel]
@export var snap_2d_transforms_to_pixel := false:
	get:
		return snap_2d_transforms_to_pixel
	set(_value):
		snap_2d_transforms_to_pixel = _value
		_sync_window_settings()
## See [member Viewport.snap_2d_vertices_to_pixel]
@export var snap_2d_vertices_to_pixel := false:
	get:
		return snap_2d_vertices_to_pixel
	set(_value):
		snap_2d_vertices_to_pixel = _value
		_sync_window_settings()

@export_group("Sizing")
## Wrap the windows size to the size of it's child controlls. Works along side [member wrap_node2d].
## Implicitly makes the window unresizable by its decorations.
@export var wrap_controls := false:
	get:
		return wrap_controls
	set(_value):
		wrap_controls = _value
		_sync_window_settings()
## Wrap the windows size to the size of it's child node2ds. Works along side [member wrap_controls].
## Implicitly makes the window unresizable by its decorations.
@export var wrap_node2d := false:
	get:
		return wrap_node2d
	set(_value):
		wrap_node2d = _value
		_sync_window_settings()
## Makes the window unresizable. See [member Window.unresizable].
@export var force_unresizable := false:
	get:
		return force_unresizable
	set(_value):
		force_unresizable = _value
		_sync_window_settings()
## The min size of the window, in screen space. See [member Window.min_size].
@export var min_screen_size := Vector2i.ZERO:
	get:
		return min_screen_size
	set(_value):
		min_screen_size = _value
		_sync_window_settings()
## The max size of the window, in screen space. See [member Window.max_size].
@export var max_screen_size := Vector2i.ONE * 16384:
	get:
		return max_screen_size
	set(_value):
		max_screen_size = _value
		_sync_window_settings()
## Ensures that the window's size will always leave the title visible.
## See [member Window.keep_title_visible].
@export var keep_title_visible := true:
	get:
		return keep_title_visible
	set(_value):
		keep_title_visible = _value
		_sync_window_settings()

@export_group("Rendering")
## Disables 3d in the viewport. See [member Viewport.disable_3d].
## [br][br] - NOTE since the internally created [Window] has not child [Camera3D],
## there is no support for this window to display [Node3D] nodes in the first place.
## Unless you intent to manually implement this window to interact in a 3D environment yourself,
## there is not point in enabling 3d for this window in the first place.
@export var disable_3d := true:
	get:
		return disable_3d
	set(_value):
		disable_3d = _value
		_sync_window_settings()
## Which canvas layers to show in the window.
@export_flags_2d_render var canvas_cull_mask:int = 0xFFFFFFFF:
	get:
		return canvas_cull_mask
	set(_value):
		canvas_cull_mask = _value
		_sync_window_settings()
		_sync_camera_settings()
@export var debug_rect_color := Color(1, 1, 1, 0.5)
@export_range(0, 10, 0.1) var debug_rect_width:float = 2
@export_range(0, 10, 0.1) var debug_rect_dash:float = 4

@export_group("Input")
## Enables mouse passthrough for the window. See [member Window.mouse_passthrough].
@export var mouse_passthrough := false:
	get:
		return mouse_passthrough
	set(_value):
		mouse_passthrough = _value
		_sync_window_settings()
## See [member Window.mouse_passthrough_polygon].
@export var mouse_passthrough_polygon := PackedVector2Array():
	get:
		return mouse_passthrough_polygon
	set(_value):
		mouse_passthrough_polygon = _value
		_sync_window_settings()
## See [member Window.handle_input_locally].
@export var handle_input_locally := true:
	get:
		return handle_input_locally
	set(_value):
		handle_input_locally = _value
		_sync_window_settings()
## Enables the window to be grabbed via the interactable area.
## This will not mark any input events handled.
@export var inner_mouse_grab := true
## The antion that, when [member inner_mouse_grab] is enabled, is the action that is used as thew
## action for grabbing the window's body.
@export var inner_mouse_grab_action:StringName = "spyglass_grab"

## The rect of the window (without decoration), in tis Node2D's local space.
## [br][br] - NOTE setting this [b]ONLY[/b] sets it in world rect
## and does not set it's [member window_screen_rect].[br]
## Use [method force_set_local_world_rect] instead to acheave that behaviour.
var local_window_world_rect:Rect2:
	get:
		return Rect2(position - (in_world_size/2 if center else Vector2.ZERO), in_world_size)
	set(_value):
		position = _value.position + (in_world_size/2 if center else Vector2.ZERO)
		in_world_size = _value.size
		item_rect_changed.emit()

## The rect of the window (without decoration), in the world's global space.
## [br][br] - NOTE setting this [b]ONLY[/b] sets it in world rect
## and does not set it's [member window_screen_rect].
## Use [method force_set_global_world_rect] instead to acheave that behaviour.
var global_window_world_rect:Rect2:
	get:
		return Rect2(global_position - (in_world_size/2 if center else Vector2.ZERO), in_world_size)
	set(_value):
		global_position = _value.position + (in_world_size/2 if center else Vector2.ZERO)
		in_world_size = _value.size
		item_rect_changed.emit()

## The rect of the window (without decoration), in metascreen space.
## [br][br] - NOTE setting this [b]ONLY[/b] sets it in screen rect
## and does not set it's [member global_window_world_rect].
## Use [method force_set_screen_rect] instead to acheave that behaviour.
var window_screen_rect:Rect2i:
	get:
		if _window_ref == null:
			return Rect2i()
		var window_pos_offset = _window_ref.position
		var win_pos := Vector2(_window_ref.position)
		if _window_ref.is_embedded():
			var parent_window := get_window()
			var parent_window_transform := parent_window.get_final_transform()
			parent_window_transform = parent_window_transform.translated(parent_window.position)
			win_pos = parent_window_transform * Vector2(win_pos)
		return Rect2i(Vector2i(win_pos), _window_ref.size)
	set(_value):
		if _window_ref == null:
			return
		var val_pos := Vector2(_value.position)
		if _window_ref.is_embedded():
			var parent_window := get_window()
			var parent_window_t := parent_window.get_final_transform().affine_inverse()
			parent_window_t = parent_window_t.translated_local(-parent_window.position)
			val_pos = parent_window_t * Vector2(val_pos)
		_window_ref.position = val_pos
		_window_ref.size = _value.size
		window_rect_changed.emit()

## Enable the spyglass in editor.
## [br][br] - NOTE this feature is experemental and is not to be enabled
## when editing a scene that contains a spyglass,
## instead only to be used when using the scene in editor for a addon.
## Enabling this in a edited scene will cause graphical bugs and possibly crashes,
## and will make it difficult to position this node while editing.
## Only enable this behaviour after a scene is loaded or instantiated.
var use_in_editor := false

var _inner_grabbed = false
var _grab_offset := Vector2i.ZERO
var _window_ref : Window = null
var _camera_ref : Camera2D = null

func _enter_tree() -> void:
	set_notify_transform(true)
	if not window_input.is_connected(_on_window_input):
		window_input.connect(_on_window_input)

func _ready() -> void:
	set_notify_transform(true)
	_ensure_children()
	if not window_input.is_connected(_on_window_input):
		window_input.connect(_on_window_input)

func _notification(what: int) -> void:
	if (use_in_editor or not Engine.is_editor_hint()):
		if what == NOTIFICATION_TRANSFORM_CHANGED:
			if not (guess_is_using_wm_handles() or _inner_grabbed):
				_sync_rect_from_world()
		elif what == NOTIFICATION_VISIBILITY_CHANGED:
			_sync_window_settings()
			_sync_camera_settings()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
	
	if process_callback == Camera2D.Camera2DProcessCallback.CAMERA2D_PROCESS_IDLE:
		_update()

func _physics_process(_delta: float) -> void:
	if process_callback == Camera2D.Camera2DProcessCallback.CAMERA2D_PROCESS_PHYSICS:
		_update()

func _draw():
	if not Engine.is_editor_hint():
		return
	
	const top_left := Vector2.ZERO
	var bottom_left := in_world_size * Vector2.DOWN
	var top_right := in_world_size * Vector2.RIGHT
	var bottom_right := in_world_size
	
	draw_dashed_line(top_left, top_right, debug_rect_color, debug_rect_width, debug_rect_dash)
	draw_dashed_line(top_right, bottom_right, debug_rect_color, debug_rect_width, debug_rect_dash)
	draw_dashed_line(bottom_right, bottom_left, debug_rect_color, debug_rect_width, debug_rect_dash)
	draw_dashed_line(bottom_left, top_left, debug_rect_color, debug_rect_width, debug_rect_dash)

## Sets the screen rect while also setting the in world rect to match.
func force_set_screen_rect(rect:Rect2i):
	var t := window_world_transform.affine_inverse()
	t *= PerfectPoint.get_screen_metascreen_inverse_transform(target_screen_id)
	window_screen_rect = rect
	global_window_world_rect = t * Rect2(window_screen_rect)
	_camera_ref.global_transform = global_transform






## Sets the global world rect while also setting the in screen rect to match.
func force_set_global_world_rect(rect:Rect2):
	var t := window_world_transform
	t *= PerfectPoint.get_screen_metascreen_transform(target_screen_id)
	
	var wrap_t := window_world_transform.affine_inverse()
	if wrap_controls and wrap_node2d:
		rect.size = wrap_t * PerfectPoint.canvasitem_get_recursive_enclosing_rect(self).size
	elif wrap_node2d:
		rect.size = wrap_t * PerfectPoint.node2d_get_recursive_enclosing_rect(self).size
	elif wrap_controls:
		rect.size = wrap_t * PerfectPoint.control_get_recursive_enclosing_rect(self).size
	rect.size = Vector2(ceil(rect.size))
	
	global_window_world_rect = rect
	window_screen_rect = t * global_window_world_rect
	_camera_ref.global_transform = global_transform

## Sets the local world rect while also setting the in screen rect to match.
func force_set_local_world_rect(rect:Rect2):
	var t := window_world_transform
	t *= PerfectPoint.get_screen_metascreen_transform(target_screen_id)
	
	var wrap_t := window_world_transform.affine_inverse()
	if wrap_controls and wrap_node2d:
		rect.size = wrap_t * PerfectPoint.canvasitem_get_recursive_enclosing_rect(self).size
	elif wrap_node2d:
		rect.size = wrap_t * PerfectPoint.node2d_get_recursive_enclosing_rect(self).size
	elif wrap_controls:
		rect.size = wrap_t * PerfectPoint.control_get_recursive_enclosing_rect(self).size
	rect.size = Vector2(ceil(rect.size))
	
	local_window_world_rect = rect
	window_screen_rect = t * global_window_world_rect
	_camera_ref.global_transform = global_transform

## Tries to determine weather or not the window's handles are being interacted with.
## Due to the difficulty of checking internally if the window is begin resized in Godot,
## this instead only guesses weather or not the cursor
## is located in the decorated area of the window,
## weather or not the window is resizable, borderless, the appropriate mouse button is pressed,
## and if [param require_cursor_change], also if the cursor is of an expected type.
## [param require_cursor_change] is usually too strict to use, but prevents many possible
## false positives.
## [br][br] - NOTE This function is consitered experimental and may change in the future.
## [br] - NOTE This may not work as expected with embedded windows is some cases.
func guess_is_using_wm_handles(require_cursor_change:bool = false) -> bool:
	if _window_ref.borderless or _window_ref.unfocusable:
		return false
	
	if not _window_ref.mode in [Window.MODE_MAXIMIZED, Window.MODE_WINDOWED]:
		return false
	
	if DisplayServer.mouse_get_button_state() & WM_HANDLE_MOUSE_BUTTON_MASK == 0:
		return false
	
	if require_cursor_change:
		var expected_types = WM_HANDLE_CURSOR_TYPES
		if not _window_ref.unresizable:
			expected_types += WM_HANDLE_CURSOR_RESIZE_TYPES
		if not DisplayServer.cursor_get_shape() in expected_types:
			return false
	
	var in_rect = Rect2i(_window_ref.get_position(), _window_ref.get_size())
	var out_rect_position:= Vector2()
	if not _window_ref.unresizable:
		out_rect_position = _window_ref.get_position_with_decorations()  
	else:
		out_rect_position = Vector2(_window_ref.get_position().x,
									_window_ref.get_position_with_decorations().y)
	if _window_ref.is_embedded():
		out_rect_position -= Vector2.DOWN * _window_ref.get_theme_constant("title_height")
		if not _window_ref.unresizable:
			out_rect_position -= Vector2.ONE * _window_ref.get_theme_constant("resize_margin")
	var out_rect_size:=Vector2()
	if not _window_ref.unresizable:
		out_rect_size = _window_ref.get_size_with_decorations()
	else:
		out_rect_size = _window_ref.get_size()
	if _window_ref.is_embedded() and not _window_ref.unresizable:
		out_rect_size += Vector2.ONE * _window_ref.get_theme_constant("resize_margin")
	var out_rect = Rect2i(floor(out_rect_position),  ceil(out_rect_size))
	
	var cursor_pos:=Vector2i()
	if _window_ref.is_embedded():
		cursor_pos = get_parent().get_window().get_mouse_position()
	else:
		cursor_pos = DisplayServer.mouse_get_position()
	return out_rect.has_point(cursor_pos) and not in_rect.has_point(cursor_pos)


## Returns the internally created [Window] node. Note that modifying this directly
## is not recommended as this is usually done by this [Spyglass] node internally.
## This is mainly used for debugging or for functions that require
## a reference to a [Window] node directly.
## Freeing this node at any point will cause undefined behaviour and most likely many errors.
func get_inner_window() -> Window:
	return _window_ref

## Returns the internally created [Camera2D] node. Note that modifying this directly
## is not recommended as this is usually done by this [Spyglass] node internally.
## This is mainly used for debugging or for functions that require
## a reference to a [Camera2D] node directly.
## Freeing this node at any point will cause undefined behaviour and most likely many errors.
func get_camera_2d() -> Camera2D:
	return _camera_ref


func _sync_rect_from_screen():
	force_set_screen_rect(window_screen_rect)

func _sync_rect_from_world():
	force_set_global_world_rect(global_window_world_rect)

func _ensure_children():
	if _window_ref == null:
		var children = find_children("*", "Window", false, false)
		if children.size() == 1 and get_child_count(true) < 2:
			_window_ref = children[0]
		
	if _window_ref == null:
		_window_ref = Window.new()
	
	if _window_ref.get_parent() != self:
		self.add_child(_window_ref)
		
	if _camera_ref == null:
		var children = _window_ref.find_children("*", "Camera2D", false, false)
		if children.size() == 1 and get_child_count(true) < 2:
			_camera_ref = children[0]
	
	if _camera_ref == null:
		_camera_ref = Camera2D.new()
	
	if _camera_ref.get_parent() != _window_ref:
		_window_ref.add_child(_camera_ref)

	_sync_window_settings()
	_sync_camera_settings()

func _sync_window_settings():
	if _window_ref == null and (use_in_editor or not Engine.is_editor_hint()):
		_ensure_children()
		return
	
	if _window_ref != null:
	
		_window_ref.visible = false
	
		_window_ref.wrap_controls = false
		_window_ref.use_xr = false
		_window_ref.own_world_3d = false
		_window_ref.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	
		_window_ref.title = title
		_window_ref.transient = transient
		_window_ref.transient_to_focused = transient_to_focused
		_window_ref.exclusive = exclusive
		_window_ref.borderless = borderless
		_window_ref.always_on_top = always_on_top
		_window_ref.transparent = transparent
		_window_ref.transparent_bg = transparent
		_window_ref.unfocusable = unfocusable
		_window_ref.unresizable = force_unresizable or wrap_controls or wrap_node2d
		_window_ref.popup_window = popup_window
		_window_ref.extend_to_title = extend_to_title
	
		_window_ref.canvas_cull_mask = canvas_cull_mask
		_window_ref.snap_2d_transforms_to_pixel = snap_2d_transforms_to_pixel
		_window_ref.snap_2d_vertices_to_pixel = snap_2d_vertices_to_pixel
		_window_ref.force_native = force_native
	
		_window_ref.handle_input_locally = handle_input_locally
		_window_ref.mouse_passthrough = mouse_passthrough
		_window_ref.mouse_passthrough_polygon = mouse_passthrough_polygon
		_window_ref.keep_title_visible = keep_title_visible
		_window_ref.min_size = min_screen_size
		_window_ref.max_size = max_screen_size
	
		_window_ref.disable_3d = disable_3d
	
		if get_parent() != null and get_parent().get_window() != null:
			_window_ref.world_2d = get_parent().get_window().world_2d
			_window_ref.world_3d = get_parent().get_window().world_3d
	
		if not _window_ref.about_to_popup.is_connected(about_to_popup.emit):
			_window_ref.about_to_popup.connect(about_to_popup.emit)
	
		if not _window_ref.close_requested.is_connected(close_requested.emit):
			_window_ref.close_requested.connect(close_requested.emit)
	
		if not _window_ref.dpi_changed.is_connected(dpi_changed.emit):
			_window_ref.dpi_changed.connect(dpi_changed.emit)
	
		if not _window_ref.files_dropped.is_connected(files_dropped.emit):
			_window_ref.files_dropped.connect(files_dropped.emit)
	
		if not _window_ref.focus_entered.is_connected(window_focus_entered.emit):
			_window_ref.focus_entered.connect(window_focus_entered.emit)
	
		if not _window_ref.focus_exited.is_connected(window_focus_exited.emit):
			_window_ref.focus_exited.connect(window_focus_exited.emit)
	
		if not _window_ref.go_back_requested.is_connected(go_back_requested.emit):
			_window_ref.go_back_requested.connect(go_back_requested.emit)
	
		if not _window_ref.mouse_entered.is_connected(window_mouse_entered.emit):
			_window_ref.mouse_entered.connect(window_mouse_entered.emit)
	
		if not _window_ref.mouse_exited.is_connected(window_mouse_exited.emit):
			_window_ref.mouse_exited.connect(window_mouse_exited.emit)
	
		if not _window_ref.theme_changed.is_connected(theme_changed.emit):
			_window_ref.theme_changed.connect(theme_changed.emit)
	
		if not _window_ref.titlebar_changed.is_connected(titlebar_changed.emit):
			_window_ref.titlebar_changed.connect(titlebar_changed.emit)
	
		if not _window_ref.window_input.is_connected(window_input.emit):
			_window_ref.window_input.connect(window_input.emit)
	
		if is_inside_tree():
			_window_ref.visible = visible and not Engine.is_editor_hint()

func _sync_camera_settings():
	if _camera_ref == null and (use_in_editor or not Engine.is_editor_hint()):
		_ensure_children()
		return
	
	if _camera_ref != null:
		_camera_ref.enabled = true
		_camera_ref.process_callback = process_callback
		_camera_ref.ignore_rotation = false
		_camera_ref.visibility_layer = canvas_cull_mask
		if center:
			_camera_ref.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
		else:
			_camera_ref.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT

func _update():
	if (not use_in_editor) and Engine.is_editor_hint():
		return
	
	if _inner_grabbed and not _window_ref.has_focus():
		_inner_grabbed = false
	
	if guess_is_using_wm_handles():
		_sync_rect_from_screen()

func _on_window_input(event:InputEvent):
	if (not use_in_editor) and Engine.is_editor_hint():
		return
	
	if inner_mouse_grab and event.is_action_pressed(inner_mouse_grab_action):
		if not _inner_grabbed:
			_grab_offset = DisplayServer.mouse_get_position() - window_screen_rect.position
		_inner_grabbed = true
	
	if event.is_action_released(inner_mouse_grab_action):
		_inner_grabbed = false
	
	if _inner_grabbed and event is InputEventMouseMotion:
		force_set_screen_rect(Rect2i(DisplayServer.mouse_get_position() - _grab_offset,
									 window_screen_rect.size))
