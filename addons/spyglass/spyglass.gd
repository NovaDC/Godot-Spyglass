@tool
@icon("./icon.svg")
class_name Spyglass
extends Camera2D

## Maps a [Window] accurately into world space, with full control both ways.
##
## A [Camera2D] inheriting node that allows for a attached [member frame_window]
## to have it's screen position and size corelate exactly to
## this nodes global position and camera size.[br]
## This supports both embedded and native windows, and allows for the
## screen offsets to be relative to the virtual screen space or the [member SceneTree.root].[br]
## This also ensure that the positioning and resizing of the window works both ways,
## allowing for full use of the native OS's handles.[br]
## [br]
## [br]
## [b]NOTES:[/b][br]
## [br]
## - Since the [member frame_window] shares the same [World2D] as this node,
## additional efforts must be taken to ensure child nodes of the [member frame_window]
## [i]don't[/i] appear in the [member SceneTree.root] or other viewports,
## such as using [CanvasLayer] nodes or different rendering layers to do this instead.[br]
## [br]
## - As this inherits from (and is a type of) [Camera2D],
## at least one other (properly enabled) [Camera2D] should exist in the tree
## to ensure that the [member SceneTree.root] [Window]
## does not also display the view from this as a camera.[br]
## [br]
## - Due to some native OS's window snapping routines,
## using a [member Camera2D.anchor_mode]
## besides [constant Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT]
## may result in jittering and disjoining the position
## from global space when resizing the window.[br]
## [br]
## - Due to the rendering order of [Window] nodes, a spyglass with a native window,
## when moved via the window itself (as opposed to moving this spyglass in world-space),
## may show the view from its new world position only after the window itself is moved.
## This will likely be seen as a jittering effect when the window is moved at a moderate speed.
## to add or remove a manual delay for window-to-world or world-to-window updates,
## see [member defer_window_updates].[br]
## [br]
## - Disabling [member Camera2D.ignore_rotation] for this node will likely cause visual issues.

## Emitted when [member frame_window] changes to a different value.
signal frame_window_changed()

## Emitted when a custom grab is started.
## [param offset] is the mouse offset from the window in virtual screen space.[br]
## [br]
## See [method start_custom_mouse_grab] for more information.
signal window_custom_grab_started(offset:Vector2i)
## Emitted when a custom grab is ended.[br]
## [br]
## See [method end_custom_mouse_grab] for more information.
signal window_custom_grab_finished()

## The window to frame this [Spyglass] in.[br]
## If not set (or set to a node thats [method Object.is_queued_for_deletion],
## or the [member SceneTree.root])
## or if not [member Window.visible] the spyglass effect wont be enabled.[br]
## [br]
## - [b]NOTE:[/b] The [Window]'s [member Window.initial_position] will not be accounted for.
## To enforce an additional offset between the spyglass node and
## the [member Window.position] during updates, use [member window_custom_screen_offset].[br]
## - [b]NOTE:[/b] On certain OSes,
## when [member Camera2D.anchor_mode] is not [constant Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT]
## non-embedded windows may jitter and/or become disjointed from this node when resized
## by the OS itself due to automatic window snapping.[br]
@export var frame_window:Window:
	get:
		return frame_window
	set(_value):
		if not (is_node_ready() and is_inside_tree()):
			set_deferred("frame_window", _value)
			return

		if _value != null:
			if _value.is_queued_for_deletion():
				_value = null
			var tree := get_tree()
			if tree != null and tree.root == _value:
				_value = null

		var was := frame_window

		var lis_child:_SpyglassListener = null

		if frame_window != null:
			var lis_children := frame_window.find_children("*", "_SpyglassListener", false, false)
			lis_child = lis_children.pop_back()
			for c in lis_children:
				c.queue_free()
			if frame_window.tree_exiting.is_connected(_refresh_frame_window):
				frame_window.tree_exiting.disconnect(_refresh_frame_window)
			if frame_window.window_input.is_connected(_on_window_or_nonclient_input):
				frame_window.window_input.disconnect(_on_window_or_nonclient_input)
			if frame_window.nonclient_window_input.is_connected(_on_window_or_nonclient_input):
				frame_window.nonclient_window_input.disconnect(_on_window_or_nonclient_input)
			if frame_window.visibility_changed.is_connected(update_spyglass):
				frame_window.visibility_changed.disconnect(update_spyglass)
			if frame_window.about_to_popup.is_connected(update_spyglass):
				frame_window.about_to_popup.disconnect(update_spyglass)
			if frame_window.size_changed.is_connected(_on_window_update_size):
				frame_window.size_changed.disconnect(_on_window_update_size)

		frame_window = _value

		if frame_window != null:
			if lis_child == null or lis_child.is_queued_for_deletion():
				lis_child = _SpyglassListener.new()
			elif lis_child.get_parent() != null:
				lis_child.get_parent().remove_child(lis_child)
			frame_window.add_child(lis_child)
			if not lis_child.window_position_changed.is_connected(_on_window_update_position):
				lis_child.window_position_changed.connect(_on_window_update_position)

			frame_window.world_2d = get_world_2d()
			custom_viewport = frame_window
			make_current()

			if not frame_window.tree_exiting.is_connected(_refresh_frame_window):
				frame_window.tree_exiting.connect(_refresh_frame_window)
			if not frame_window.window_input.is_connected(_on_window_or_nonclient_input):
				frame_window.window_input.connect(_on_window_or_nonclient_input)
			if not frame_window.nonclient_window_input.is_connected(_on_window_or_nonclient_input):
				frame_window.nonclient_window_input.connect(_on_window_or_nonclient_input)
			if not frame_window.visibility_changed.is_connected(update_spyglass):
				frame_window.visibility_changed.connect(update_spyglass)
			if not frame_window.about_to_popup.is_connected(update_spyglass):
				frame_window.about_to_popup.connect(update_spyglass)
			if not frame_window.size_changed.is_connected(_on_window_update_size):
				frame_window.size_changed.connect(_on_window_update_size)

			frame_window.visible = visible

		if was != frame_window:
			frame_window_changed.emit()
			update_spyglass()
		update_configuration_warnings()

## Offsets [member frame_window]'s [member Window.position] from the
## [member Node2D.global_position] of this node in virtual screen coordinates.[br]
## See also [member window_adjusted_screen_rect].
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var window_custom_screen_offset := Vector2i.ZERO:
	get:
		return window_custom_screen_offset
	set(_value):
		window_custom_screen_offset = _value
		update_spyglass()

## When set, the [member frame_window]'s [member Window.position] will
## always be relative to the active [member SceneTree.root].[br]
## This will only apply if [member SceneTree.root] is not also [member frame_window].[br]
## See also [member window_adjusted_screen_rect].
@export var relative_to_root_window := true:
	get:
		return relative_to_root_window
	set(_value):
		var changed:bool = _value != relative_to_root_window
		relative_to_root_window = _value
		update_configuration_warnings()
		if changed:
			update_spyglass()

## When set to a valid input action, [member frame_window] will automatically
## call [method start_custom_mouse_grab] and [method end_custom_mouse_grab]
## as appropriate. These input events will only be read from [member frame_window]
## specific input events ([signal Window.window_input] and [signal Window.nonclient_window_input]).
@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin,loose_mode")
var custom_mouse_grab_action:StringName = "spyglass_grab"

@export_group("Update")
## Allows for the updating of node-to-screen and screen-to-node positions
## to be deferred for a specific amount of frames.[br]
## When set to a positive value, node-to-screen will lag for
## [code]absi(defer_window_updates)[/code] frames.[br]
## When set to a negative value, screen-to-node will lag for
## [code]absi(defer_window_updates)[/code] frames.[br]
## This may only be useful in specific situations and configurations
## where there is a constant amount of lag between the updating of
## a [Window]'s position compared to the updating of the [SceneTree].[br]
## This can also easily cause worse lag if overused.
## This is only expected to be of use for native (non-embedded) windows,
## as embedded windows will always update with their embedder in the right order.
@export_range(-8, 8, 1, "prefer_slider", "suffix:frames") var defer_window_updates:int = 0
## Enable updating the spyglass when the [member frame_window] is moved.
## It's suggested to leave this enabled even if the user is not allow to move the window,
## as this also allows for this spyglass to react to the OS's window position changes as well.[br]
## [b]NOTE:[/b] This will enable updates triggered by [member frame_window]'s movement,
## not when [member relative_to_root_window] would require updates from the root window.
@export var update_on_window_moved := true
## Enable updating the spyglass when the this node's
## [member Node2D.global_transform] changes at all.[br]
## It's suggested to leave this enabled for accuracy.[br]
@export var update_on_transform_changed := true
## Force an update every processed frame.[br]
## It's suggested to leave this disabled unless necessary.[br]
@export var update_on_process := false
## Force an update every physics frame.[br]
## It's suggested to leave this disabled unless necessary.[br]
@export var update_on_physics_process := false
## Force an update every input event.[br]
## It's suggested to leave this disabled unless necessary.[br]
@export var update_on_input := false
## Force an update every input event received in [member frame_window].[br]
## Depending on how inputs are handled between [member frame_window] and it's
## parents, this may be redundant to [member update_on_input].
## It's suggested to leave this disabled unless necessary.[br]
## [b]NOTE:[/b] This will not disable updates triggered by [member custom_mouse_grab_action]
## or any other kinds of custom mouse grabs
## (via [method start_custom_mouse_grab] and [method end_custom_mouse_grab]).
@export var update_on_window_input := false

## The screen relative rect of the [member frame_window] [i]after[/i] accounting
## for adjustment.[br]
## [b]NOTE:[/b] For the true virtual screen rect, use [member window_virtual_screen_rect].
var window_adjusted_screen_rect:Rect2i:
	get:
		var rect := get_window_virtual_screen_rect()
		if relative_to_root_window and is_inside_tree():
			var tree := get_tree()
			if tree != null and tree.root != null and tree.root != frame_window:
				rect.position -= tree.root.position
		rect.position -= window_custom_screen_offset
		return rect
	set(_value):
		if relative_to_root_window and is_inside_tree():
			var tree := get_tree()
			if tree != null and tree.root != null and tree.root != frame_window:
				_value.position += tree.root.position
		_value.position += window_custom_screen_offset
		return set_window_virtual_screen_rect(_value)

## The virtual screen relative rect of the [member frame_window].[br]
## [b]NOTE:[/b] To account for [member relative_to_root_window]
## or [member window_custom_screen_offset], use [member window_adjusted_screen_rect].
var window_virtual_screen_rect:Rect2i:
	get = get_window_virtual_screen_rect, set = set_window_virtual_screen_rect

var _latest_transform:Transform2D
var _os_window_moved_instance := false
var _os_window_sized_instance := false

var _is_custom_grabbed := false
var _custom_grab_offset := Vector2i.ZERO

func _notification(what: int) -> void:
	match(what):
		NOTIFICATION_MOVED_IN_PARENT, NOTIFICATION_PARENTED, NOTIFICATION_UNPARENTED:
			if Engine.is_editor_hint():
				notify_property_list_changed()
		NOTIFICATION_READY, NOTIFICATION_WORLD_2D_CHANGED:
			_refresh_frame_window()
			if Engine.is_editor_hint():
				if not child_order_changed.is_connected(notify_property_list_changed):
					child_order_changed.connect(notify_property_list_changed)
			set_notify_transform(true)
			_latest_transform = global_transform
		NOTIFICATION_TRANSFORM_CHANGED when _latest_transform != global_transform:
			if update_on_transform_changed:
				update_spyglass()
			_latest_transform = global_transform
		NOTIFICATION_PROCESS when update_on_process:
			update_spyglass()
		NOTIFICATION_PHYSICS_PROCESS when update_on_physics_process:
			update_spyglass()
		NOTIFICATION_VISIBILITY_CHANGED when frame_window != null:
			frame_window.visible = visible
			update_spyglass()
		NOTIFICATION_WM_POSITION_CHANGED when frame_window != null:
			if relative_to_root_window != frame_window.is_embedded():
				# Avoid unnecessary updates in situations that won't need them
				update_spyglass()

func _input(_event: InputEvent) -> void:
	if update_on_input:
		update_spyglass()

func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name" : "Update/_manual_spyglass_update",
			"type" : TYPE_CALLABLE,
			"hint" : PROPERTY_HINT_TOOL_BUTTON,
			"hint_string" : "Manual Spyglass Update",
			"usage" : PROPERTY_USAGE_EDITOR,
		}
	]

func _get(property: StringName) -> Variant:
	match(property):
		"_manual_spyglass_update":
			return update_spyglass
	return null

func _set(property: StringName, _value: Variant) -> bool:
	match(property):
		"_manual_spyglass_update":
			return true
	return false

func _get_configuration_warnings() -> PackedStringArray:
	var warn := PackedStringArray()
	if frame_window == null:
		warn.append("No frame window. Spyglass will not function.")
	if anchor_mode != ANCHOR_MODE_FIXED_TOP_LEFT:
		const MSG := ("Spyglass may misbehave when anchor_mode is not set to" +
					"ANCHOR_MODE_FIXED_TOP_LEFT on some OSes when using OS resizing methods."
					)
		warn.append(MSG)
	if is_inside_tree() and get_tree() != null:
		var tree := get_tree()
		if relative_to_root_window and tree.root.find_children("*", "Camera2D", true, false).size() <= 1:
			warn.append("Spyglass will not work if its the only Camera2D to display.")
	return warn

func _property_can_revert(property: StringName) -> bool:
	match (property):
		"update_on_process", "update_on_physics_process":
			return true
		"anchor_mode":
			return true
		"window_adjusted_screen_rect":
			return true
		"frame_window" when is_inside_tree():
			return true
	return false

func _property_get_revert(property: StringName) -> Variant:
	match (property):
		"update_on_process":
			return process_callback == CAMERA2D_PROCESS_IDLE
		"update_on_physics_process":
			return process_callback == CAMERA2D_PROCESS_PHYSICS
		"anchor_mode":
			# The only way to know when the anchor mode is changed
			# The property list notification doesn't work for some reason...
			update_configuration_warnings()
			return ANCHOR_MODE_FIXED_TOP_LEFT
		"window_adjusted_screen_rect":
			return window_adjusted_screen_rect
		"frame_window" when is_inside_tree():
			var local_tree := get_tree()
			for immediate_child in find_children("*", "Window", false, false):
				if not immediate_child.is_queued_for_deletion():
					return immediate_child
			for recursive_child in find_children("*", "Window", true, false):
				if not recursive_child.is_queued_for_deletion():
					return recursive_child
			var p := get_parent()
			while p != null and p.get_tree() == local_tree:
				if p is Window and not p.is_queued_for_deletion():
					return p
				p = p.get_parent()
	return null

func _on_window_update_position():
	if update_on_window_moved:
		_os_window_moved_instance = true
		update_spyglass()

func _on_window_update_size():
	_os_window_sized_instance = true
	update_spyglass()
	update_spyglass.call_deferred()

func _on_window_or_nonclient_input(event:InputEvent):
	if InputMap.has_action(custom_mouse_grab_action):
		var mouse_v_screen := DisplayServer.mouse_get_position()
		var mouse_in_v_screen := window_virtual_screen_rect.has_point(mouse_v_screen)
		if mouse_in_v_screen and event.is_action_pressed(custom_mouse_grab_action):
			start_custom_mouse_grab(mouse_v_screen - frame_window.position)
		elif event.is_action_released(custom_mouse_grab_action):
			end_custom_mouse_grab()

	if is_custom_grabbed():
		update_spyglass()
	elif update_on_window_input:
		update_spyglass()

func _refresh_frame_window():
	frame_window = frame_window

## Gets the virtual screen relative rect of the [member frame_window].[br]
## [b]NOTE:[/b] To account for [member relative_to_root_window]
## or [member window_custom_screen_offset], use [member window_adjusted_screen_rect].
func get_window_virtual_screen_rect() -> Rect2i:
	if frame_window == null:
		return Rect2i()

	var int_rect := Rect2i(frame_window.position, frame_window.size)

	if frame_window.is_embedded():
		var closest_parent_window := frame_window.get_parent().get_window()
		var float_rect := closest_parent_window.get_screen_transform() * Rect2(int_rect)
		int_rect = Rect2i(float_rect.position.floor(), float_rect.size.floor())
		if is_inside_tree():
			var tree := get_tree()
			if tree != null and tree.root != null and tree.root != frame_window:
				int_rect.position += tree.root.position

	return int_rect

## Sets the virtual-screen relative rect of the [member frame_window].[br]
## [b]NOTE:[/b] To account for [member relative_to_root_window]
## or [member window_custom_screen_offset], use [member window_adjusted_screen_rect].
func set_window_virtual_screen_rect(value:Variant):
	if frame_window == null:
		return

	value = Rect2(value)

	if frame_window.is_embedded():
		if is_inside_tree():
			var tree := get_tree()
			if tree != null and tree.root != null and tree.root != frame_window:
				value.position -= Vector2(tree.root.position)

		var parent_window := frame_window.get_parent().get_window()
		value = parent_window.get_screen_transform().affine_inverse() * value

	value = Rect2i(value.position.floor(), value.size.floor())

	frame_window.position = value.position
	#frame_window.size = value.size

## Gets the screen (a [i]physical[/i] screen, not the virtual screen)
## relative rect of the [member frame_window] relative to the
## provided [param screen_id].[br]
## See [method DisplayServer.screen_get_position] for more information about [param screen_id].[br]
## [b]NOTE:[/b] This will not account for [member relative_to_root_window]
## nor [member window_custom_screen_offset].
func get_window_screen_rect(screen_id:int = 0) -> Rect2i:
	if frame_window == null:
		return Rect2i()
	var rect := window_adjusted_screen_rect
	rect.position -= DisplayServer.screen_get_position(screen_id)
	return rect

## Sets the screen (a [i]physical[/i] screen, not the virtual screen)
## relative rect of the [member frame_window] relative to the
## provided [param screen_id].[br]
## See [method DisplayServer.screen_get_position] for more information about [param screen_id].[br]
## [b]NOTE:[/b] This will not account for [member relative_to_root_window]
## nor [member window_custom_screen_offset].
func set_window_screen_rect(value:Rect2i, screen_id:int = 0):
	if frame_window == null:
		return
	value.position += DisplayServer.screen_get_position(screen_id)
	window_adjusted_screen_rect = value

## Gets a window relative rect of the [member frame_window] relative to the
## provided [param window].[br]
## [b]NOTE:[/b] This will not account for [member relative_to_root_window]
## nor [member window_custom_screen_offset].
func get_window_relative_window_rect(window:Window) -> Rect2i:
	if frame_window == null:
		return Rect2i()
	var rect := window_adjusted_screen_rect
	rect.position -= window.position
	return rect

## Sets the window relative rect of the [member frame_window] relative to the
## provided [param window].[br]
## [b]NOTE:[/b] This will not account for [member relative_to_root_window]
## nor [member window_custom_screen_offset].
func set_window_relative_window_rect(value:Rect2i, window:Window):
	if frame_window == null:
		return
	value.position += window.position
	window_adjusted_screen_rect = value

## Returns the bounds of the spyglass in global space.[br]
## [b]NOTE:[/b] the size and position of this rect is not always the
## [member Node2D.global_position] of this node, nor the size of the [member frame_window].
## This method allows for accurate calculations of the cameras
## true positioning in global world space.
func get_camera_world_rect() -> Rect2:
	if frame_window == null:
		return Rect2()
	var size := frame_window.get_visible_rect().size / zoom
	var pos := global_position
	if anchor_mode == ANCHOR_MODE_DRAG_CENTER:
		pos -= size/2
	return Rect2(pos, size)

## This method typically indicates that the various requirements
## for this spyglass to function are satisfied.[br]
## When [code]false[/code], [member update_spyglass] will not update anything.
func is_spyglass_enabled() -> bool:
	if not is_inside_tree() or not is_node_ready() or frame_window == null:
		return false
	if not enabled or not visible:
		return false
	return enabled and visible and frame_window.visible

## Indicates the control-flow of the positioning of the spyglass when [method update_spyglass]
## is called.[br]
## When [code]true[/code], the position of the [member frame_window] will always effect the
## [member Node2D.global_position] of this node.
## Otherwise, the [member Node2D.global_position] of this node will always effect the
## position of the [member frame_window].[br]
## When inheriting this class, this method should be overridden when another feature that effects
## control flow is added.[br]
## This will always be [code]false[/code] when [method is_spyglass_enabled]
## returns [code]false[/code].
func is_window_controlling() -> bool:
	if not is_spyglass_enabled():
		return false
	if Engine.is_editor_hint() and EditorInterface.get_editor_viewport_2d().is_ancestor_of(self):
		return false
	if is_custom_grabbed():
		return true
	return (_os_window_moved_instance and not _os_window_sized_instance)

## Attempts to trigger an update of the spyglass' state.[br]
## Will never take effect when [method is_spyglass_enabled] returns [code]false[/code].[br]
## To determine the control flow of positioning, see [method is_window_controlling].[br]
## When inheriting this class, this method should be overridden when adding/modifying features
## related to positioning or the updating of the window's rect,
## as this is the main method called when the spyglass requires some form of update.
func update_spyglass():
	if not is_spyglass_enabled():
		return
	var f:Callable
	if is_window_controlling():
		if is_custom_grabbed():
			var mouse_pos := DisplayServer.mouse_get_position()
			frame_window.position = Vector2(mouse_pos - get_last_custom_grab_offset())
		f = func ():
			print("position from window")
			var new_pos := Vector2(window_adjusted_screen_rect.position)
			if anchor_mode == ANCHOR_MODE_DRAG_CENTER:
				new_pos += Vector2(window_adjusted_screen_rect.size) / 2
			global_position = new_pos
			align()
			item_rect_changed.emit()
			set_deferred("_os_window_moved_instance", false)
		if defer_window_updates <= -1:
			for _x in range(absi(defer_window_updates)):
				f = f.call_deferred
	else:
		f = func ():
			print("window from position")
			var fpos := global_position
			if anchor_mode == ANCHOR_MODE_DRAG_CENTER:
				fpos -= Vector2(window_adjusted_screen_rect.size) / 2
			var rect := window_adjusted_screen_rect
			rect.position = Vector2i(fpos.floor())
			window_adjusted_screen_rect = rect
			align()
			item_rect_changed.emit()
			set_deferred("_os_window_sized_instance", false)
		if defer_window_updates >= 1:
			for _x in range(absi(defer_window_updates)):
				f = f.call_deferred
	f.call()

## Returns [code]true[/code] when a custom mouse gram is in effect.[br]
## See [method start_custom_mouse_grab] and [method end_custom_mouse_grab]
## for more information about custom mouse grabbing.
func is_custom_grabbed() -> bool:
	return _is_custom_grabbed

## Returns the last custom mouse grab offset.[br]
## This will still return the last offset of the custom mouse grab, even if not grabbed anymore.[br]
## This will return [constant Vector2i.ZERO] when no custom mouse grab has ever been performed.[br]
## See [method start_custom_mouse_grab] and [method end_custom_mouse_grab]
## for more information about custom mouse grabbing.
func get_last_custom_grab_offset() -> Vector2i:
	return _custom_grab_offset

## Grabs the [method frame_window] with the mouse, regardless of the mouse's position.[br]
## This snaps the position of the window to the mouse's position, offset by
## [param window_cursor_offset].[br]
## Where possible, this should be prefered over suing [member frame_window]'s
## [method Window.start_drag] method, as it allows for more accurate spyglass updating.[br]
## While the window will stay relative to the mouse when a custom mouse grab is in effect,
## this is not specifically tied to the mouse's buttons,
## only to the calling of [method start_custom_mouse_grab] and [method end_custom_mouse_grab].
## If a custom mouse grab is not already in effect (see [method is_custom_grabbed])
## this method will start one and return [code]true[/code],
## otherwise this method will return [code]false[/code].
func start_custom_mouse_grab(window_cursor_offset:Vector2i) -> bool:
	if is_custom_grabbed():
		return false
	_is_custom_grabbed = true
	_custom_grab_offset = window_cursor_offset
	window_custom_grab_started.emit(window_cursor_offset)
	return true

## If a custom mouse grab is already in effect (see [method is_custom_grabbed])
## this method will end it and return [code]true[/code],
## otherwise this method will return [code]false[/code].
## for more information about custom mouse grabs, see [method start_custom_mouse_grab].
func end_custom_mouse_grab() -> bool:
	if not is_custom_grabbed():
		return false
	_is_custom_grabbed = false
	window_custom_grab_finished.emit()
	return true

class _SpyglassListener extends Node:
	signal window_position_changed()

	var _last_position := Vector2i.ZERO

	func _notification(what: int) -> void:
		if not is_node_ready():
			return

		if what == NOTIFICATION_WM_POSITION_CHANGED:
			var pos := get_window().position
			if _last_position != pos:
				window_position_changed.emit()
				_last_position = pos
